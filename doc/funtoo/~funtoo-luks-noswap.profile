#!/bin/bash

dist funtoo

part sda 1 83 100M  # /boot
part sda 2 83 +     # /

luks bootpw    a
luks /dev/sda2 root aes sha256

format /dev/sda1 	ext2
format /dev/mapper/root ext4

mountfs /dev/sda1 	 ext2 /boot
mountfs /dev/mapper/root ext4 /  noatime

stage_uri 		http://dev.funtoo.org/linux/~funtoo/i686/stage3-i686-current.tar.bz2
tree_type		snapshot http://dev.funtoo.org/linux/~funtoo/snapshots/portage-current.tar.bz2
rootpw 			a
kernel_config_uri	http://www.openchill.org/kconfig.2.6.30
genkernel_opts		--luks # required
kernel_sources          gentoo-sources
timezone                UTC
bootloader 		grub
bootloader_kernel_args	crypt_root=/dev/sda2 # should match root device in luks key
keymap			fr # be-laint1 en
hostname		~funtoo-luks-noswap
#extra_packages         vixie-cron syslog-ng openssh
#rcadd			vixie-cron default
#rcadd			syslog-ng default
#rcadd			sshd

# MUST HAVE: funtoo portage
post_unpack_repo_tree() {
	spawn_chroot "cd /usr/portage && git checkout funtoo.org" || die "Cannot git checkout funtoo.org"
}

# MUST HAVE
post_build_kernel() {
        spawn_chroot "cat /etc/pam.d/chpasswd | grep -v password > /etc/pam.d/chpasswd.tmp" 
	spawn_chroot "echo password include system-auth >> /etc/pam.d/chpasswd.tmp"
        spawn_chroot "mv /etc/pam.d/chpasswd.tmp /etc/pam.d/chpasswd"
}
skip setup_root_password
