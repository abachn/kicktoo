#!/bin/bash

dist gentoo

part sda 1 83 100M  # /boot
part sda 2 83 +     # /

luks bootpw    a		# change me 
luks /dev/sda2 root aes sha256

format /dev/sda1 	ext2
format /dev/mapper/root ext4

mountfs /dev/sda1 	 ext2 /boot
mountfs /dev/mapper/root ext4 /  noatime

stage_uri		http://distro.ibiblio.org/pub/linux/distributions/funtoo/gentoo/i686/stage3-i686-current.tar.bz2
tree_type		sync
rootpw 			a
kernel_config_uri	http://www.openchill.org/kconfig.2.6.30
genkernel_opts		--luks # required
kernel_sources          gentoo-sources
timezone                UTC
bootloader 		grub
bootloader_kernel_args	crypt_root=/dev/sda2 # should match root device in luks key
keymap			fr # be-latin1 fr en 
hostname		gentoo-luks-noswap
#extra_packages         openssh vixie-cron syslog-ng
#rcadd			vixie-cron default
#rcadd			syslog-ng default
#rcadd			sshd default
