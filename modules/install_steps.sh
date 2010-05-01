run_pre_install_script() {
	if [ -n "${pre_install_script_uri}" ]; then
		fetch "${pre_install_script_uri}" "${chroot_dir}/var/tmp/pre_install_script" || die "could not fetch pre-install script"
		chmod +x "${chroot_dir}/var/tmp/pre_install_script"
		spawn_chroot "/var/tmp/pre_install_script" || die "error running pre-install script"
		spawn "rm ${chroot_dir}/var/tmp/pre_install_script"
	elif $(isafunc pre_install); then
		pre_install || die "error running pre_install()"
	else
		debug run_pre_install_script "no pre-install script set"
	fi
}

partition() {
	for device in $(set | grep '^partitions_' | cut -d= -f1 | sed -e 's:^partitions_::'); do
		debug partition "device is ${device}"
		local device_temp="partitions_${device}"
		local device="/dev/$(echo "${device}" | sed  -e 's:_:/:g')"
		local device_size="$(get_device_size_in_mb ${device})"
		create_disklabel ${device} || die "could not create disklabel for device ${device}"
		for partition in $(eval echo \${${device_temp}}); do
			debug partition "partition is ${partition}"
			local minor=$(echo ${partition} | cut -d: -f1)
			local type=$(echo ${partition} | cut -d: -f2)
			local size=$(echo ${partition} | cut -d: -f3)
			local devnode=$(format_devnode "${device}" "${minor}")
			debug partition "devnode is ${devnode}"
			if [ "${type}" = "extended" ]; then
				newsize="${device_size}"
			else
				size_devicesize="$(human_size_to_mb ${size} ${device_size})"
				newsize="$(echo ${size_devicesize} | cut -d '|' -f1)"
				[ "${newsize}" = "-1" ] && die "could not translate size '${size}' to a usable value"
				device_size="$(echo ${size_devicesize} | cut -d '|' -f2)"
			fi
		add_partition "${device}" "${minor}" "${newsize}" "${type}" || die "could not add partition ${minor} to device ${device}"
		done
	done
}

setup_mdraid() {
	for array in $(set | grep '^mdraid_' | cut -d= -f1 | sed -e 's:^mdraid_::' | sort); do
		local array_temp="mdraid_${array}"
		local arrayopts=$(eval echo \${${array_temp}})
		local arraynum=$(echo ${array} | sed -e 's:^md::')
		if [ ! -e "/dev/md${arraynum}" ]; then
			spawn "mknod /dev/md${arraynum} b 9 ${arraynum}" || die "could not create device node for mdraid array ${array}"
		fi
		spawn "mdadm --create --run /dev/${array} ${arrayopts}" || die "could not create mdraid array ${array}"
	done
}

setup_lvm() {
	for volgroup in $(set | grep '^lvm_volgroup_' | cut -d= -f1 | sed -e 's:^lvm_volgroup_::' | sort); do
		local volgroup_temp="lvm_volgroup_${volgroup}"
		local volgroup_devices="$(eval echo \${${volgroup_temp}})"
		for device in ${volgroup_devices}; do
			spawn "pvcreate -ffy ${device}" || die "could not run 'pvcreate' on ${device}"
		done
		spawn "vgcreate ${volgroup} ${volgroup_devices}" || die "could not create volume group '${volgroup}' from devices: ${volgroup_devices}"
	done
	for logvol in ${lvm_logvols}; do
		local volgroup="$(echo ${logvol} | cut -d '|' -f1)"
		local size="$(echo ${logvol} | cut -d '|' -f2)"
		local name="$(echo ${logvol} | cut -d '|' -f3)"
		spawn "lvcreate -L${size} -n${name} ${volgroup}" || die "could not create logical volume '${name}' with size ${size} in volume group '${volgroup}'"
	done
}

luks_devices(){
	for device in ${luks}
	do
#		echo $device
		local devicetmp=$(echo ${device} | cut -d: -f1)
		local luks_mapper=$(echo ${device} | cut -d: -f2)
		local cipher=$(echo ${device} | cut -d: -f3)
		local hash=$(echo ${device} | cut -d: -f4)
		local lukscmd=""
#		echo "info $devicetmp $luks_mapper $cipher $hash"
		case ${luks_mapper} in
			swap)
				lukscmd="cryptsetup -c ${cipher} -h ${hash} -d /dev/urandom create ${luks_mapper} ${devicetmp}"
				;;
			root)
				lukscmd="echo ${boot_password} | cryptsetup -c ${cipher}-cbc-essiv:${hash} luksFormat ${devicetmp} && echo ${boot_password} | cryptsetup luksOpen ${devicetmp} ${luks_mapper}"
				;;
		esac
		if [ -n "${lukscmd}" ]; then
#			echo "lukscmd=${lukscmd}"
			spawn "${lukscmd}" || die "could not luks: ${lukscmd}"
		fi
	done
	unset boot_password # we don't need it anymore
}

format_devices() {
	for device in ${format}; do
		local devnode=$(echo ${device} | cut -d: -f1)
		local fs=$(echo ${device} | cut -d: -f2)
		local formatcmd=""
		case "${fs}" in
			swap)
				formatcmd="mkswap ${devnode}"
				;;
			ext2)
				formatcmd="mke2fs ${devnode}"
				;;
			ext3)
				#mkfs.ext3 -j -m 1 -O dir_index,filetype,sparse_super /dev/mapper/root
				formatcmd="mkfs.ext3 -j -m 1 -O dir_index,filetype,sparse_super ${devnode}"
				;;
			ext4)
				#mkfs.ext4dev -j -m 1 -O dir_index,filetype,sparse_super,extents,huge_file /dev/mapper/root
				formatcmd="mkfs.ext4 ${devnode}"
				;;
			xfs)
				formatcmd="mkfs.xfs ${devnode}"
				;;
			reiserfs|reiserfs3)
				formatcmd="mkreiserfs -q ${devnode}"
				;;
			*)
				formatcmd=""
				warn "don't know how to format ${devnode} as ${fs}"
		esac
		if [ -n "${formatcmd}" ]; then
			spawn "${formatcmd}" || die "could not format ${devnode} with command: ${formatcmd}"
		fi
	done
}

mount_local_partitions() {
	if [ -z "${localmounts}" ]; then
		warn "no local mounts specified. this is a bit unusual, but you're the boss"
	else
		rm /tmp/install.mounts 2>/dev/null
		for mount in ${localmounts}
		do
			debug mount_local_partitions "mount is ${mount}"
			local devnode=$(echo ${mount} | cut -d ':' -f1)
			local type=$(echo ${mount} | cut -d ':' -f2)
			local mountpoint=$(echo ${mount} | cut -d ':' -f3)
			local mountopts=$(echo ${mount} | cut -d ':' -f4)
#			[ -n "${type}" ] && type="-t ${type}"
			[ -n "${mountopts}" ] && mountopts="-o ${mountopts}"
			case "${type}" in
				swap)
					spawn "swapon ${devnode}" || warn "could not activate swap ${devnode}"
					;;
				ext2|ext3|ext4|reiserfs|reiserfs3|xfs)
					echo "mount -t ${type} ${devnode} ${chroot_dir}${mountpoint} ${mountopts}" >> /tmp/install.mounts
					;;
			esac
		done
		sort -k5 /tmp/install.mounts | while read mount
		do
			mkdir -p $(echo ${mount} | awk '{ print $5; }')
			spawn "${mount}" || die "could not mount with: ${mount}"
		done
	fi
}

mount_network_shares() {
	if [ -n "${netmounts}" ]; then
		for mount in ${netmounts}; do
			local export=$(echo ${mount} | cut -d '|' -f1)
			local type=$(echo ${mount} | cut -d '|' -f2)
			local mountpoint=$(echo ${mount} | cut -d '|' -f3)
			local mountopts=$(echo ${mount} | cut -d '|' -f4)
			[ -n "${mountopts}" ] && mountopts="-o ${mountopts}"
			case "${type}" in
				nfs)
					spawn "/etc/init.d/nfsmount start"
					mkdir -p ${chroot_dir}${mountpoint}
					spawn "mount -t nfs ${mountopts} ${export} ${chroot_dir}${mountpoint}" || die "could not mount ${type}/${export}"
					;;
				*)
					warn "mounting ${type} is not currently supported"
					;;
			esac
		done
	fi
}

fetch_stage_tarball() {
	debug fetch_stage_tarball "fetching stage tarball"
	if [ -n ${stage_uri} ] ; then
		fetch "${stage_uri}" "${chroot_dir}/$(get_filename_from_uri ${stage_uri})" || die "Could not fetch stage tarball"
	fi
}

unpack_stage_tarball() {
	debug unpack_stage_tarball "unpacking stage tarball"
	if [ -n ${stage_uri} ] ; then
		local extension=${stage_uri##*.}
		local tarball=$(get_filename_from_uri ${stage_uri})

		if [ "$extension" == "bz2" ] ; then
			spawn "tar xjpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar stage tarball"
		elif [ "$extension" == "gz" ] ; then
			spawn "tar xzpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar stage tarball"
		elif [ "$extension" == "xz" ] ; then
			spawn "unxz ${chroot_dir}/$(get_filename_from_uri ${stage_uri})" || die "Could not unxz tarball"
			spawn "tar xpf ${chroot_dir}/${tarball%.*} -C ${chroot_dir}" || die "Could not untar stage tarball"
		elif [ "$extension" == "lzma" ] ; then
			spawn "unlzma ${chroot_dir}/$(get_filename_from_uri ${stage_uri})" || die "Could not unlzma tarball"
			spawn "tar xpf ${chroot_dir}/${tarball%.*} -C ${chroot_dir}" || die "Could not untar stage tarball"
		fi
	elif [ -n ${stage_path} ] ; then
		spawn "cp ${stage_path} ${chroot_dir}" || die "Could not copy stage tarball"
		local stage_name="$(basename ${stage_path})"
		local extension=${stage_name##*.}

		if [ "$extension" == "bz2" ] ; then
			spawn "tar xjpf ${chroot_dir}/${stage_name} -C ${chroot_dir}" || die "Could not untar stage tarball"
		elif [ "$extension" == "gz" ] ; then
			spawn "tar xzpf ${chroot_dir}/${stage_name%.*} -C ${chroot_dir}" || die "Could not untar stage tarball"
		elif [ "$extension" == "xz" ] ; then
			spawn "unxz ${chroot_dir}/${stage_name}" || die "Could not unxz tarball"
			spawn "tar xpf ${chroot_dir}/${stage_name%.*} -C ${chroot_dir}" || die "Could not untar stage tarball"
		elif [ "$extension" == "lzma" ] ; then
			spawn "unlzma ${chroot_dir}/${stage_name}" || die "Could not unlzma tarball"
			spawn "tar xpf ${chroot_dir}/${stage_name%.*} -C ${chroot_dir}" || die "Could not untar stage tarball"
		fi
	fi
}

prepare_chroot() {
	debug prepare_chroot "copying /etc/resolv.conf into chroot"
	spawn "cp /etc/resolv.conf ${chroot_dir}/etc/resolv.conf" || die "could not copy /etc/resolv.conf into chroot"
	debug prepare_chroot "mounting proc"
	spawn "mount -t proc none ${chroot_dir}/proc" || die "could not mount proc"
	debug prepare_chroot "bind-mounting /dev"
	spawn "mount -o rbind /dev ${chroot_dir}/dev/" || die "could not rbind-mount /dev"
	if [ "$(uname -r | cut -d. -f 2)" = "6" ]; then
		debug prepare_chroot "bind-mounting /sys"
		[ -d ${chroot_dir}/sys ] || mkdir ${chroot_dir}/sys
		spawn "mount -o bind /sys ${chroot_dir}/sys" || die "could not bind-mount /sys"
	else
		debug prepare_chroot "kernel is not 2.6...not bind-mounting /sys"
	fi
}

setup_fstab() {
        echo -e "none\t/proc\tproc\tdefaults\t0 0\nnone\t/dev/shm\ttmpfs\tdefaults\t0 0" > ${chroot_dir}/etc/fstab
        for mount in ${localmounts}; do
                debug setup_fstab "mount is ${mount}"
                local devnode=$(echo ${mount} | cut -d ':' -f1)
                local type=$(echo ${mount} | cut -d ':' -f2)
                local mountpoint=$(echo ${mount} | cut -d ':' -f3)
                local mountopts=$(echo ${mount} | cut -d ':' -f4)
                if [ "${mountpoint}" == "/" ]; then
                        local dump_pass="0 1"
                elif [ "${mountpoint}" == "/boot" -o "${mountpoint}" == "/boot/" ]; then
                        local dump_pass="1 2"
                else
                        local dump_pass="0 0"
                fi
                echo -e "${devnode}\t${mountpoint}\t${type}\t${mountopts}\t${dump_pass}" >> ${chroot_dir}/etc/fstab
        done
        for mount in ${netmounts}; do
                local export=$(echo ${mount} | cut -d '|' -f1)
                local type=$(echo ${mount} | cut -d '|' -f2)
                local mountpoint=$(echo ${mount} | cut -d '|' -f3)
                local mountopts=$(echo ${mount} | cut -d '|' -f4)
                echo -e "${export}\t${mountpoint}\t${type}\t${mountopts}\t0 0" >> ${chroot_dir}/etc/fstab
        done
}

fetch_repo_tree() {
        debug fetch_repo_tree "tree_type is ${tree_type}"
        if [ "${tree_type}" = "sync" ]; then
                spawn_chroot "emerge --sync" || die "could not sync portage tree"
        elif [ "${tree_type}" = "snapshot" ]; then
                fetch "${portage_snapshot_uri}" "${chroot_dir}/$(get_filename_from_uri ${portage_snapshot_uri})" || die "could not fetch portage snapshot"
        elif [ "${tree_type}" = "webrsync" ]; then
                spawn_chroot "emerge-webrsync" || die "could not emerge-webrsync"
        elif [ "${tree_type}" = "none" ]; then
                warn "'none' specified...skipping"
        else
                die "Unrecognized tree_type: ${tree_type}"
        fi
}

unpack_repo_tree() {
	debug unpack_repo_tree "extracting tree"
	if [ "${tree_type}" = "snapshot" ] ; then
		spawn "tar xjf ${chroot_dir}/$(get_filename_from_uri ${portage_snapshot_uri}) -C ${chroot_dir}/usr" || die "could not unpack portage snapshot"
	fi
}

fetch_config_tarball() {
	debug fetch_config_tarball "fetching config tarball"
	if [ -n ${config_uri} ] ; then
		fetch "${config_uri}" "${chroot_dir}/$(get_filename_from_uri ${config_uri})" || die "Could not fetch config tarball"
	fi
}

unpack_config_tarball() {
	debug unpack_config_tarball "unpacking config tarball"
	if [ -n ${config_uri} ] ; then
		local extension=${config_uri##*.}
		local tarball=$(get_filename_from_uri ${config_uri})

		if [ "$extension" == "bz2" ] ; then
			spawn "tar xjpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar config tarball"
		elif [ "$extension" == "gz" ] ; then
			spawn "tar xzpf ${chroot_dir}/${tarball} -C ${chroot_dir}" || die "Could not untar config tarball"
		elif [ "$extension" == "xz" ] ; then
			spawn "unxz ${chroot_dir}/$(get_filename_from_uri ${config_uri})" || die "Could not unxz tarball"
			spawn "tar xpf ${chroot_dir}/${tarball%.*} -C ${chroot_dir}" || die "Could not untar config tarball"
		elif [ "$extension" == "lzma" ] ; then
			spawn "unlzma ${chroot_dir}/$(get_filename_from_uri ${config_uri})" || die "Could not unlzma tarball"
			spawn "tar xpf ${chroot_dir}/${tarball%.*} -C ${chroot_dir}" || die "Could not untar config tarball"
		fi
	fi
}

install_cryptsetup() {
	spawn_chroot "emerge cryptsetup" || die "could not emerge cryptsetup"
}

build_kernel() {
	if [ "${kernel_sources}" = "none" ]; then
		debug build_kernel "kernel_sources is 'none'...skipping kernel build"
	else
		spawn_chroot "emerge ${kernel_sources}" || die "could not emerge kernel sources"
		spawn_chroot "emerge genkernel" || die "could not emerge genkernel"
		if [ -n "${kernel_config_uri}" ]; then
			fetch "${kernel_config_uri}" "${chroot_dir}/tmp/kconfig" || die "could not fetch kernel config"
			spawn_chroot "genkernel --kernel-config=/tmp/kconfig ${genkernel_opts} all" || die "could not build custom kernel"
		else
			spawn_chroot "genkernel ${genkernel_opts} all" || die "could not build generic kernel"
		fi
	fi
}

#install_logging_daemon() {
#	if [ "${logging_daemon}" = "none" ]; then
#		debug install_logging_daemon "logging_daemon is 'none'...skipping"
#	else
#		spawn_chroot "emerge ${logging_daemon}" || die "could not emerge logging daemon"
#	fi
#}
#
#install_cron_daemon() {
#	if [ "${cron_daemon}" = "none" ]; then
#		debug install_cron_daemon "cron_daemon is 'none'...skipping"
#	else
#		spawn_chroot "emerge ${cron_daemon}" || die "could not emerge cron daemon"
#	fi
#}

setup_network_post() {
	if [ -n "${net_devices}" ]; then
		for net_device in ${net_devices}; do
			local device="$(echo ${net_device} | cut -d '|' -f1)"
			local ipdhcp="$(echo ${net_device} | cut -d '|' -f2)"
			local gateway="$(echo ${net_device} | cut -d '|' -f3)"
			if [ "${ipdhcp}" = "dhcp" ] || [ "${ipdhcp}" = "DHCP" ]; then
				echo "config_${device}=( \"dhcp\" )" >> ${chroot_dir}/etc/conf.d/net
			else
				echo -e "config_${device}=( \"${ipdhcp}\" )\nroutes_${device}=( \"default via ${gateway}\" )" >> ${chroot_dir}/etc/conf.d/net
			fi
			if [ ! -e "${chroot_dir}/etc/init.d/net.${device}" ]; then
				spawn_chroot "ln -s net.lo /etc/init.d/net.${device}" || die "could not create symlink for device ${device}"
			fi
			spawn_chroot "rc-update add net.${device} default" || die "could not add net.${device} to the default runlevel"
		done
	fi
}

setup_root_password() {
        if [ -n "${root_password_hash}" ]; then
                spawn_chroot "echo 'root:${root_password_hash}' | chpasswd -e" || die "could not set root password"
        elif [ -n "${root_password}" ]; then
                spawn_chroot "echo 'root:${root_password}' | chpasswd --md5" || die "could not set root password"
        fi
}

setup_timezone() {
        if detect_baselayout2 ; then
                spawn_chroot "echo \"clock=\"${timezone}\" > /etc/conf.d/hwclock\"" || die "could not adjust clock config in /etc/conf.d/hwclock"
        else
                if [ -e "${chroot_dir}/etc/localtime" ] ; then
                        spawn "rm ${chroot_dir}/etc/localtime 2>/dev/null"
                fi
                spawn "ln -s ../usr/share/zoneinfo/${timezone} ${chroot_dir}/etc/localtime" || die "could not set timezone"
                spawn "/bin/sed -i 's:#TIMEZONE=\"Factory\":TIMEZONE=\"${timezone}\":' ${chroot_dir}/etc/conf.d/clock" || die "could not adjust TIMEZONE config in /etc/conf.d/clock"
        fi
}

setup_keymap(){
        if detect_baselayout2 ; then
                debug setup_keymap "Setting keymap=${keymap} to /etc/conf.d/keymaps"
                spawn "/bin/sed -i 's:keymap=\"us\":keymap=\"${keymap}\":' ${chroot_dir}/etc/conf.d/keymaps" || die "could not adjust keymap config in /etc/conf.d/keymaps"
        else
                debug set_keymap "Setting KEYMAP=${keymap} to /etc/conf.d/keymaps"
                spawn "/bin/sed -i 's:KEYMAP=\"us\":KEYMAP=\"${keymap}\":' ${chroot_dir}/etc/conf.d/keymaps" || die "could not adjust KEYMAP config in /etc/conf.d/keymaps"
        fi
}

setup_host() {
        if detect_baselayout2 ; then
                debug setup_host "Setting hostname=${hostname} to /etc/conf.d/hostname"
                spawn "/bin/sed -i 's:hostname=\"localhost\":hostname=\"${hostname}\":' ${chroot_dir}/etc/conf.d/hostname" || die "could not adjust hostname config in /etc/conf.d/hostname"
        else
                debug setup_host "Setting HOSTNAME=${hostname} to /etc/conf.d/hostname"
                spawn "/bin/sed -i 's:HOSTNAME=\"localhost\":HOSTNAME=\"${hostname}\":' ${chroot_dir}/etc/conf.d/hostname" || die "could not adjust HOSTNAME config in /etc/conf.d/hostname"
        fi
}

install_bootloader() {
	if [ "${bootloader}" = "none" ]; then
		debug install_bootloader "bootloader is 'none'...skipping"
	else
		spawn_chroot "emerge ${bootloader}" || die "could not emerge bootloader"
	fi
}

configure_bootloader() {
	if [ "${bootloader}" = "none" ]; then
		debug configure_bootloader "bootloader is 'none'...skipping configuration"
	else
		if detect_grub2; then
			bootloader="grub2"
		fi
		if $(isafunc configure_bootloader_${bootloader}); then
			configure_bootloader_${bootloader} || die "could not configure bootloader ${bootloader}"
		else
			die "I don't know how to configure ${bootloader}"
		fi
	fi
}

install_extra_packages() {
	local o
	local p
	if [ -z "${extra_packages}" ]; then
		debug install_extra_packages "no extra packages specified"
	else
		local o
		for o in ${extra_packages}
		do
			spawn_chroot "emerge ${o}" || die "could not emerge extra packages"
		done
	fi
}

add_and_remove_services() {
        if [ -n "${services_add}" ]; then
                for service_add in ${services_add}; do
                        local service="$(echo ${service_add} | cut -d '|' -f1)"
                        local runlevel="$(echo ${service_add} | cut -d '|' -f2)"
                        spawn_chroot "rc-update add ${service} ${runlevel}" || die "could not add service ${service} to the ${runlevel} runlevel"
                done
        fi
        if [ -n "${services_del}" ]; then
                for service_del in ${services_del}; do
                        service="$(echo ${service_del} | cut -d '|' -f1)"
                        runlevel="$(echo ${service_del} | cut -d '|' -f2)"
                        spawn_chroot "rc-update del ${service} ${runlevel}"
                done
        fi
}

run_post_install_script() {
	if [ -n "${post_install_script_uri}" ]; then
		fetch "${post_install_script_uri}" "${chroot_dir}/var/tmp/post_install_script" || die "could not fetch post-install script"
		chmod +x "${chroot_dir}/var/tmp/post_install_script"
		spawn_chroot "/var/tmp/post_install_script" || die "error running post-install script"
		spawn "rm ${chroot_dir}/var/tmp/post_install_script"
	elif $(isafunc post_install); then
		post_install || die "error running post_install()"
	else
		debug run_post_install_script "no post-install script set"
	fi
}

finishing_cleanup() {
	spawn "cp ${logfile} ${chroot_dir}/root/$(basename ${logfile})" || warn "could not copy install logfile into chroot"
	for mnt in $(awk '{ print $2; }' /proc/mounts | grep ^${chroot_dir} | sort -r); do
		# HACK: patching the fact that we get /mnt/gentoo/boot umounted twice :(
		#       we just remove the warning in case of /mnt/gentoo/boot
		if [ "${mnt}" == "${chroot_dir}/boot"  ]; then
			spawn "umount ${mnt}" &>/dev/null
		else
			spawn "umount ${mnt}" || warn "  could not unmount ${mnt}"
		fi
	done
	for swap in $(awk '/^\// { print $1; }' /proc/swaps); do
		spawn "swapoff ${swap}" || warn "  could not deactivate swap on ${swap}"
	done
}

failure_cleanup() {
	spawn "mv ${logfile} ${logfile}.failed" || warn "could not move ${logfile} to ${logfile}.failed"
	for mnt in $(awk '{ print $2; }' /proc/mounts | grep ^${chroot_dir} | sort -r); do
		spawn "umount ${mnt}" || warn "  could not unmount ${mnt}.. "
	done
	for swap in $(awk '/^\// { print $1; }' /proc/swaps); do
		spawn "swapoff ${swap}" || warn "  could not deactivate swap on ${swap}"
	done
	for array in $(set | grep '^mdraid_' | cut -d= -f1 | sed -e 's:^mdraid_::' | sort); do
		spawn "mdadm --manage --stop /dev/${array}" || die "could not stop mdraid array ${array}"
	done
}
