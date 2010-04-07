#!/bin/bash

KV="2.6.32.8"

dist exherbo

part sda 1 82 2048M
part sda 2 83 +

format /dev/sda1 swap
format /dev/sda2 ext4

mountfs /dev/sda1 swap
mountfs /dev/sda2 ext4 / noatime

stage_uri 		http://dev.exherbo.org/stages/exherbo-x86-current.tar.xz
kernel_config_uri       http://www.openchill.org/kconfig.2.6.30
#rootpw 			a
bootloader		grub
keymap			fr # be-latin1 en 
hostname		exherbo

pre_setup_fstab(){
	# rewrite install_repo_tree
	spawn_chroot "paludis --regenerate-installable-cache" || die "could not regenerate cache"
	# takes long and always break (for me)
#	spawn_chroot "paludis -i paludis" || die "could not update paludis"
	spawn_chroot "paludis --sync" || die "could not sync exheres tree"
	# often breaks, you might want to run/debug that after reboot
#	spawn_chroot "paludis -i everything --dl-reinstall if-use-changed --dl-upgrade always" || die "could not update stage"
}
post_setup_fstab() {
	fetch "http://www.kernel.org/pub/linux/kernel/v2.6/linux-${KV}.tar.bz2" "${chroot_dir}/usr/src/linux-${KV}.tar.bz2" || die "could not fetch kernel source"
	spawn_chroot "tar xfj /usr/src/linux-${KV}.tar.bz2 -C /usr/src/" || die "could not untar kernel tarball"
	spawn_chroot "ln -sf //usr/src/linux-${KV} /usr/src/linux" || die "could not symlink source"
	fetch "${kernel_config_uri}" "${chroot_dir}/usr/src/linux-${KV}/.config" || die "could not fetch kernel config"
	spawn_chroot "cd /usr/src/linux && yes '' |  make -s oldconfig && make && make modules_install" || die "could not build the kernel"
	# configure_bootloader() expects a kernel name created by genkernel hence the name format
	# you could always rewrite configure_bootloader() to accept another kernel name format
	spawn_chroot "cp /usr/src/linux/arch/${arch}/boot/bzImage /boot/kernel-genkernel-${arch}-${KV}" || die "could not copy the kernel"
}
skip build_kernel
skip install_bootloader
pre_configure_bootloader(){
	spawn_chroot "paludis -i ${bootloader}" || die "could not install bootloader"

}
post_configure_bootloader(){
	for p in ${extra_packages}
	do
		spawn_chroot "paludis -i ${p}" || die "could not install extra packages"
	done
}
skip install_extra_packages
