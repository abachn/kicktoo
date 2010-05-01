dist() {
	distro=$1
}

part() {
	do_part=yes
	local drive=$1
	local minor=$2
	local type=$3
	local size=$4
	
	drive=$(echo ${drive} | sed -e 's:^/dev/::' -e 's:/:_:g')
	local drive_temp="partitions_${drive}"
	local tmppart="${minor}:${type}:${size}"
	if [ -n "$(eval echo \${${drive_temp}})" ]; then
		eval "${drive_temp}=\"$(eval echo \${${drive_temp}}) ${tmppart}\""
	else
		eval "${drive_temp}=\"${tmppart}\""
	fi
	debug part "${drive_temp} is now: $(eval echo \${${drive_temp}})"
}

mdraid() {
	do_raid=yes
	local array=$1
	shift
	local arrayopts=$@

	eval "mdraid_${array}=\"${arrayopts}\""
}

lvm_volgroup() {
	do_lvm=yes
	local volgroup=$1
	shift
	local devices=$@

	eval "lvm_volgroup_${volgroup}=\"${devices}\""
}

lvm_logvol() {
	do_lvm=yes
	local volgroup=$1
	local size=$2
	local name=$3
	
	local tmplogvol="${volgroup}|${size}|${name}"
	if [ -n "${lvm_logvols}" ]; then
		lvm_logvols="${lvm_logvols} ${tmplogvol}"
	else
		lvm_logvols="${tmplogvol}"
	fi
}

luks() {
        do_luks=yes
        if [ "$1" == "bootpw" ] ; then
                boot_password="$2"
                debug luks "Password parsing: $boot_password"
        else
                local device luks_mapper cipher hash
                device=$1;luks_mapper=$2;cipher=$3;hash=$4

                local tmpluks="${device}:${luks_mapper}:${cipher}:${hash}"
                if [ -n "${luks}" ]; then
                        luks="${luks} ${tmpluks}"
                else
                        luks="${tmpluks}"
                fi
                debug luks "device mapper hash/encryption: ${device} ${luks_mapper} ${hash}/${cipher}"
        fi
}

format() {
	do_format=yes
	local device=$1
	local fs=$2
	
	local tmpformat="${device}:${fs}"
	if [ -n "${format}" ]; then
		format="${format} ${tmpformat}"
	else
		format="${tmpformat}"
	fi
}

mountfs() {
	do_localmounts=yes
	local device=$1
	local type=$2
	local mountpoint=$3
	local mountopts=$4
	
	[ -z "${mountopts}" ] && mountopts="defaults"
	[ -z "${mountpoint}" ] && mountpoint="none"
	local tmpmount="${device}:${type}:${mountpoint}:${mountopts}"
	if [ -n "${localmounts}" ]; then
		localmounts="${localmounts} ${tmpmount}"
	else
		localmounts="${tmpmount}"
	fi
}

netmount() {
	do_netmounts=yes
	local export=$1
	local type=$2
	local mountpoint=$3
	local mountopts=$4
	
	[ -z "${mountopts}" ] && mountopts="defaults"
	local tmpnetmount="${export}|${type}|${mountpoint}|${mountopts}"
	if [ -n "${netmounts}" ]; then
		netmounts="${netmounts} ${tmpnetmount}"
	else
		netmounts="${tmpnetmount}"
	fi
}  

bootloader() {
	do_bootloader=yes
	local pkg=$1

	bootloader="${pkg}"
}

bootloader_kernel_args() {
	local kernel_args=$1
	
	bootloader_kernel_args="${kernel_args}"
}

#logger() {
#	local pkg=$1
#	
#	logging_daemon="${pkg}"
#}
#
#cron() {
#	local pkg=$1
#	
#	cron_daemon="${pkg}"
#}

rootpw() {
	do_password=yes
	local pass=$1
	
	root_password="${pass}"
}

rootpw_crypt() {
	do_password=yes
	local pass=$1
	
	root_password_hash="${pass}"
}

stage_uri() {
	do_stage_uri=yes
	local uri=$1
	
	stage_uri="${uri}"
}

stage_path() {
	local path=$1

	stage_path="${path}"
}

config_uri() {
	do_config_uri=yes
	local uri=$1
	
	config_uri="${uri}"
}


tree_type() {
	do_tree=yes
	local type=$1
	local uri=$2
	
	tree_type="${type}"
	portage_snapshot_uri="${uri}"
}

bootloader_install_device() {
	local device=$1
	
	bootloader_install_device="${device}"
}

chroot_dir() {
	local dir=$1
	
	chroot_dir="${dir}"
}

extra_packages() {
	do_xpkg=yes
	local pkg=$@
	
	if [ -n "${extra_packages}" ]; then
	  extra_packages="${extra_packages} ${pkg}"
	else
	  extra_packages="${pkg}"
	fi
}

genkernel_opts() {
	local opts=$@
	
	genkernel_opts="${opts}"
}

kernel_config_uri() {
	do_kernel=yes
	local uri=$1
	
	kernel_config_uri="${uri}"
}

kernel_sources() {
	do_kernel=yes
	local pkg=$1

	kernel_sources="${pkg}"
}

timezone() {
	do_tz=yes
	local tz=$1
	
	timezone="${tz}"
}

keymap() {
	do_keymap=yes
	local kbd=$1

	keymap="${kbd}"
}

hostname() {
	local host=$1

	hostname="${host}"
}

rcadd() {
	do_services=yes
	local service=$1
	local runlevel=$2
	
	local tmprcadd="${service}|${runlevel}"
	if [ -n "${services_add}" ]; then
		services_add="${services_add} ${tmprcadd}"
	else
		services_add="${tmprcadd}"
	fi
}

rcdel() {
	local service=$1
	local runlevel=$2
	
	local tmprcdel="${service}|${runlevel}"
	if [ -n "${services_del}" ]; then
		services_del="${services_del} ${tmprcdel}"
	else
		services_del="${tmprcdel}"
	fi
}

net() {
	do_postnet=yes
	local device=$1
	local ipdhcp=$2
	local gateway=$3
	
	local tmpnet="${device}|${ipdhcp}|${gateway}"
	if [ -n "${net_devices}" ]; then
		net_devices="${net_devices} ${tmpnet}"
	else
		net_devices="${tmpnet}"
	fi
}

logfile() {
	local file=$1
	
	logfile=${file}
}

skip() {
	local func=$1
	eval "skip_${func}=1"
}

server() {
	server=$1
	server_init
}

use_linux32() {
	linux32="linux32"
}

sanity_check_config() {
        local fatal=0

        debug sanity_check_config "$(set | grep '^[a-z]')"

        if [ -z "${chroot_dir}" ]; then
                error "  chroot_dir is not defined (this can only happen if you set it to a blank string)"
#                fatal=1
        fi
        if [ -z "${stage_uri}" ] && [ -z "${stage_path}" ]; then
                warn "  you must specify a stage_uri or a stage_path argument"
#                fatal=1
        fi
        if [ -z "${tree_type}" ] && [ "${distro}" == "gentoo" ]; then
                warn "  tree_type not set..." #defaulting to sync"
#                tree_type="sync"
#       elif [ -z "${tree_type}" ] && [ "${distro}" == "funtoo" ]; then
#               warn "funtoo tree_type not set...defaulting to current snapshot"
#               tree_type="snapshot"
#               portage_snapshot_uri="http://www.funtoo.org/linux/funtoo/snapshots/portage-current.tar.bz2"
        elif [ -z "${tree_type}" ] && [ "${distro}" == "exherbo" ]; then
                warn "  exherbo tree_type not set..." #defaulting to sync"
#                tree_type="sync"
        fi
        if [ "${tree_type}" = "snapshot" -a -z "${portage_snapshot_uri}" ]; then
                warn "  you must specify a portage snapshot URI with tree_type snapshot"
#                fatal=1
        fi
        if [ -z "${root_password}" -a -z "${root_password_hash}" ]; then
                warn "  you should specify a root password"
        fi
        if [ -z "${timezone}" ]; then
                warn "  tz=${timezone} timezone not set..." # assuming UTC"
#                timezone="UTC"
        fi
        if [ -z "${keymap}" ]; then
                warn "  keymap not set..." #assuming KEYMAP=us"
#                keymap="us"
        fi
        if [ -z "${hostname}" ]; then
                warn "  hostname not set...assuming default"
        fi
        if [ -z "${kernel_sources}" ]; then
                warn "  kernel_sources not set..." # assuming gentoo-sources"
#                kernel_sources="gentoo-sources"
        fi
#       if [ -z "${logging_daemon}" ]; then
#               warn "logging_daemon not set...assuming syslog-ng"
#               logging_daemon="syslog-ng"
#       fi
#       if [ -z "${cron_daemon}" ]; then
#               warn "cron_daemon not set...assuming vixie-cron"
#               cron_daemon="vixie-cron"
#       fi
        if [ -z "${bootloader}" ]; then
                warn "  bootloader not set..." #assuming grub"
#                bootloader="grub"
        fi

	## extra checks
        if [ "${do_part}" == "yes" ] ; then
		if ! sanity_check_config_partition; then
	                fatal=1
		fi
        fi
	if [ "${do_bootloader}" == "yes" ] ; then
	        if ! sanity_check_config_bootloader; then
        	        fatal=1
		fi
        fi

#       if [ "${distro}" == "gentoo" ] || [ "${distro}" == "funtoo" ]; then
#               if ping -c 1 dev.funtoo.org &>/dev/null ; then
#                       true
#               else
#                       warn "dev.funtoo.org is _not_ online..."
#                       fatal=1
#               fi
#       fi
#       if [ "${distro}" == "exherbo" ]; then
#               if ping -c 1 dev.exherbo.org &>/dev/null ; then
#                       true
#               else
#                       warn "dev.exherbo.org is _not_ online..."
#                       fatal=1
#               fi
#       fi

        debug sanity_check_config "$(set | grep '^[a-z]')"

        [ "${fatal}" = "1" ] && exit 1
}

