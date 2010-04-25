#!/bin/bash

dist funtoo

part sda 1 82 2048M
part sda 2 83 +

format /dev/sda1 swap
format /dev/sda2 ext4

mountfs /dev/sda1 swap
mountfs /dev/sda2 ext4 / noatime

stage_uri		http://distro.ibiblio.org/pub/linux/distributions/funtoo/~funtoo/i686/stage3-i686-current.tar.bz2
tree_type		snapshot http://distro.ibiblio.org/pub/linux/distributions/funtoo/~funtoo/snapshots/portage-current.tar.bz2
kernel_config_uri       http://www.openchill.org/kconfig.2.6.30
kernel_sources		gentoo-sources
timezone		UTC
rootpw 			a
bootloader 		grub
keymap			fr # be-latin1 en
hostname		~funtoo-noboot
#extra_packages         openssh vixie-cron syslog-ng
#rcadd			sshd default
#rcadd			vixie-cron default
#rcadd			syslog-ng default

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
