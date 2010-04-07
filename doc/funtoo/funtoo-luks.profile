#!/bin/bash

dist funtoo

part sda 1 83 100M  # /boot
part sda 2 82 2048M # swap
part sda 3 83 +     # /

luks bootpw    a
luks /dev/sda2 swap aes sha256
luks /dev/sda3 root aes sha256

format /dev/sda1 	ext2
format /dev/mapper/swap swap
format /dev/mapper/root ext4

mountfs /dev/sda1 	 ext2 /boot
mountfs /dev/mapper/swap swap
mountfs /dev/mapper/root ext4 /  noatime

stage_uri 		http://dev.funtoo.org/linux/funtoo/i686/stage3-i686-current.tar.bz2
tree_type		snapshot http://dev.funtoo.org/linux/funtoo/snapshots/portage-current.tar.bz2
rootpw 			a
kernel_config_uri	http://www.openchill.org/kconfig.2.6.30
genkernel_opts		--luks # required
kernel_sources          gentoo-sources
timezone                UTC
bootloader 		grub
bootloader_kernel_args	crypt_root=/dev/sda3 # should match root device in luks key
keymap			fr # be-latin1 en
hostname		funtoo-luks
#extra_packages         vixie-cron syslog-ng openssh
#rcadd			vixie-cron default
#rcadd			syslog-ng default
#rcadd			sshd default

# MUST HAVE
post_unpack_repo_tree(){
        # git style Funtoo portage
        spawn_chroot "cd /usr/portage && git checkout funtoo.org" || die "could not checkout funtoo git repo"
}

# MUST HAVE
post_install_cryptsetup() {
	# this tells where to find the swap to encrypt
        cat >> ${chroot_dir}/etc/conf.d/dmcrypt <<EOF
swap=swap
source='/dev/sda2'
EOF
        # this will activate the encrypted swap on boot
        cat >> ${chroot_dir}/etc/conf.d/local <<EOF
swapon /dev/sda2
EOF

}

# MUST HAVE
post_build_kernel() {
        spawn_chroot "cat /etc/pam.d/chpasswd | grep -v password > /etc/pam.d/chpasswd.tmp" 
	spawn_chroot "echo password include system-auth >> /etc/pam.d/chpasswd.tmp"
        spawn_chroot "mv /etc/pam.d/chpasswd.tmp /etc/pam.d/chpasswd"
}
skip setup_root_password
