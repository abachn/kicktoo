#!/bin/bash

dist funtoo

chroot_dir /mnt/funtoo

part sda 1 83 100M
part sda 2 82 2048M
part sda 3 83 +

format /dev/sda1 ext2
format /dev/sda2 swap
format /dev/sda3 ext4

mountfs /dev/sda1 ext2 /boot
mountfs /dev/sda2 swap
mountfs /dev/sda3 ext4 / noatime

stage_uri 		http://pong/pong-stage4-2009.10.11-custom.tar.gz
#stage_path		/tmp/bebop_funto-i686-startkde.tar.lzma
kernel_config_uri 	http://www.openchill.org/kconfig.2.6.30 # bebop-zen-sources.config
kernel_sources          gentoo-sources
bootloader 		grub

#
# the commented functions are the ones that actually run
#

#skip prepare_chroot
skip install_repo_tree
#skip setup_fstab
skip install_cryptsetup
#skip build_kernel
skip install_logging_daemon
skip install_cron_daemon
skip setup_network_post
skip setup_root_password
skip setup_timezone
skip setup_keymap
skip setup_host
skip install_bootloader
#skip configure_bootloader
skip install_extra_packages
skip add_and_remove_services
skip run_post_install_script
