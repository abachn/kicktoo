#!/bin/bash

dist gentoo

part sda 1 83 100M
part sda 2 82 2048M
part sda 3 83 +

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext4 / noatime

stage_uri		http://distro.ibiblio.org/pub/linux/distributions/funtoo/gentoo/i686/stage3-i686-current.tar.bz2
tree_type		sync
kernel_config_uri       http://www.openchill.org/kconfig.2.6.30
kernel_sources		gentoo-sources
timezone		UTC
rootpw 			a
bootloader 		grub
keymap			fr # be-latin1 en
hostname		gentoo
#extra_packages         openssh vixie-cron syslog-ng
#rcadd			sshd default
#rcadd			vixie-cron default
#rcadd			syslog-ng default
