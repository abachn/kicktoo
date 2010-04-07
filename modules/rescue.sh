rescue_dir="/mnt/rescue"

rescue_close() {
	if umount -l -f ${rescue_dir}/dev &>/dev/null; then
		echo "${rescue_dir}/dev umounted"
	fi
	if umount -l -f ${rescue_dir}/sys &>/dev/null; then
		echo "${rescue_dir}/sys umounted"
	fi
	if umount -l -f ${rescue_dir}/proc &>/dev/null; then
		echo "${rescue_dir}/proc umounted"
	fi
	if umount -l -f ${rescue_dir}/boot &>/dev/null; then
		echo "${rescue_dir}/boot umounted"
	fi
	if umount -l -f ${rescue_dir} &>/dev/null; then
		echo "${rescue_dir} umounted"
	fi
	cryptsetup luksClose root &>/dev/null
	if ! test -b /dev/mapper/root ; then
		echo "LUKS box closed!"
	else
		echo "Your box is still opened"
		echo "You might want to 'kicktoo-rescue close' again or reboot if it persists"
		exit 1
	fi
	exit
}

rescue() {
	echo "${1} luks device detected"
	mkdir ${rescue_dir} &>/dev/null
	if [ "${2}" == "luks"  ]; then
		cryptsetup luksOpen ${1} root 
		mount /dev/mapper/root ${rescue_dir}
	else
		mount ${1} ${rescue_dir}
	fi
	mount -t proc proc ${rescue_dir}/proc &>/dev/null
	mount -o rbind /dev ${rescue_dir}/dev &>/dev/null
	mount -o bind /sys ${rescue_dir}/sys  &>/dev/null
	echo "you take care of mounting /boot!"
	echo "Switching environment ..."
	echo
	echo "when done:"
	echo "  # exit                    (exit chroot)"
	echo "  # kicktoo-rescue close    (close luks device)"
	echo
	chroot ${rescue_dir} /bin/bash
}

