#!/bin/bash

dist funtoo

part sda 1 83 100M
part sda 2 82 2048M
part sda 3 83 +

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext4 / noatime

stage_uri 		http://dev.funtoo.org/linux/~funtoo/i686/stage3-i686-current.tar.bz2
tree_type		snapshot http://dev.funtoo.org/linux/~funtoo/snapshots/portage-current.tar.bz2
kernel_config_uri       http://www.openchill.org/kconfig.2.6.30
kernel_sources          gentoo-sources
timezone		UTC
rootpw 			a
bootloader 		grub
keymap			fr # be-latin1 en
hostname		~funtoo
#extra_packages         vixie-cron syslog-ng openssh
#rcadd			vixie-cron default
#rcadd			syslog-ng default
#rcadd			sshd default

# MUST HAVE for funtoo based installation
post_unpack_repo_tree(){
        spawn_chroot "cd /usr/portage && git checkout funtoo.org" || die "could not checkout funtoo git repo"
}

# MUST HAVE
post_build_kernel() {
        spawn_chroot "cat /etc/pam.d/chpasswd | grep -v password > /etc/pam.d/chpasswd.tmp" 
	spawn_chroot "echo password include system-auth >> /etc/pam.d/chpasswd.tmp"
        spawn_chroot "mv /etc/pam.d/chpasswd.tmp /etc/pam.d/chpasswd"
}
skip setup_root_password
