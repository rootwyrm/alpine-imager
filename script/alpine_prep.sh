#!/bin/bash
################################################################################
# 
# Copyright (c) 2020-* Phillip R. Jaenke <prj@rootwyrm.com>. 
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, 
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice, 
#    this list of conditions and the following disclaimer in the documentation 
#    and/or other materials provided with the distribution.
# 3. All advertising materials mentioning features or use of this software 
#    must display the following acknowledgement:
#    This product includes software developed by Phillip R. Jaenke.
# 4. Neither the name of the copyright holder nor the names of its contributors 
#    may be used to endorse or promote products derived from this software 
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDER "AS IS" AND ANY EXPRESS OR 
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO 
# EVENT SHALL COPYRIGHT HOLDER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; 
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. 
#
################################################################################
##
## Prepare the Alpine chroot
##

source /opt/rootwyrm/bin/stdlib.sh
source /etc/os-release

if [ -f /opt/rootwyrm/conf/overlay.conf ]; then
	source /opt/rootwyrm/conf/overlay.conf
fi

function prep_fstab()
{
	if [ ! -z $BOOTUUID ]; then
		printf 'boot UUID %s\n' "$BOOTUUID" | tee -a ${logfile}
	else
		export BOOTUUID=$(blkid -s UUID -o value ${BOOTPART})
		printf 'Rediscovering boot UUID...\n' | tee -a ${logfile}
		printf 'boot UUID %s\n' "$BOOTUUID" | tee -a ${logfile}
	fi
	if [ ! -z $ROOTUUID ]; then
		printf 'root UUID %s\n' "$ROOTUUID" | tee -a ${logfile}
	else
		export ROOTUUID=$(blkid -s UUID -o value ${ROOTPART})
		printf 'Rediscovering root UUID...\n' | tee -a ${logfile}
		printf 'root UUID %s\n' "$ROOTUUID" | tee -a ${logfile}
	fi
	#sed -i -E '1 i UUID='${ROOTUUID}'\t/\text4\tdefaults\t0 0' ${CHROOT}/etc/fstab

	## Switch around architecture
	local FSTAB=${CHROOT}/etc/fstab
	echo "UUID=${ROOTUUID}	/	ext4	defaults	0 0" > $FSTAB
	echo "UUID=${BOOTUUID}		/media/mmcblk0p1	vfat	defaults	0 0" >> $FSTAB
	echo "## DO NOT MODIFY THIS SECTION" >> $FSTAB
	echo "/media/mmcblk0p1	/boot	none	defaults,bind	0 0" >> $FSTAB
	case ${PLATFORM} in
		rpi)
			echo "/media/mmcblk0p1/dtbs-rpi/overlays	/boot/overlays	none	defaults,bind	0 0" >> $FSTAB
			;;
		rpi4)
			echo "/media/mmcblk0p1/dtbs-rpi4/overlays	/boot/overlays	none	defaults,bind	0 0" >> $FSTAB
			;;
		*)
			## Do nothing
			;;
	esac
	echo "## ADD ANY CUSTOM ENTRIES AFTER THIS POINT" >> $FSTAB
	echo "" >> $FSTAB
	echo "/dev/usbdisk    /media/usb      vfat    noauto  0 0" >> $FSTAB
	#overlay     /media/mmcblk0p1    lowerdir=/media/mmcblk0p1/dtbs-lts:/media/mmcblk0p1/dtbs-rpi:/media/mmcblk0p1/dtbs-rpi4,upperdir=/media/mmcblk0p1/upper,workdir=/media/mmcblk0p1/work   0 0
}

## Install the core packages we literally cannot function without.
function prep_core()
{
	printf 'Updating apk repositories...\n'
	chroot ${CHROOT} /sbin/apk update
	CHECK_ERROR $? prep_core_apk_update
	printf 'Installing the latest security fixes...\n'
	chroot ${CHROOT} /sbin/apk upgrade
	CHECK_ERROR $? prep_core_apk_upgrade
	case ${PLATFORM} in
		rpi)
			BOOTPKG=${BOOTPKG:-raspberrypi-bootloader}
			KERNEL=${KERNEL:-linux-rpi}
			;;
		rpi4)
			BOOTPKG=${BOOTPKG:-raspberrypi-bootloader}
			KERNEL=${KERNEL:-linux-rpi4}
			;;
		aarch64)
			BOOTPKG=${BOOTPKG:-grub2}
			KERNEL=${KERNEL:-linux-lts}
			;;
	esac

	printf 'Installing kernel and bootloader... \n'
	for p in $KERNEL ; do
		printf 'KERNEL: %s \n' $p
		chroot ${CHROOT} /sbin/apk -q add $p
		CHECK_ERROR $? apk_add_$p
	done
	for p in $BOOTPKG ; do
		printf 'BOOT COMPONENT: %s \n' $p
		chroot ${CHROOT} /sbin/apk -q add $p
		CHECK_ERROR $? apk_add_$p
	done

	## Rewritten for platform
	if [ ! -d ${CHROOT}/boot/overlays ]; then
		mkdir ${CHROOT}/boot/overlays
		chown 0:0 ${CHROOT}/boot/overlays
	fi

	case ${PLATFORM} in
		rpi)
			DTBS="dtbsd-bcrm dtbs-rpi"
			;;
		rpi4)
			DTBS="dtbsd-bcrm dtbs-rpi4"
			;;
		aarch64)
			;;
	esac
	for dtb_dir in $DTBS; do
		if [ -d ${CHROOT}/boot/$dtb_dir ]; then
			printf 'Relocating DTBs from %s ' $dtb_dir
			for dtb in `ls ${CHROOT}/boot/$dtb_dir/*dtb`; do
				mv $dtb ${CHROOT}/boot/${dtb##*/}
				printf '.'
			done
			printf 'Complete\n'
		fi
		if [ -d ${CHROOT}/boot/$dtb_dir/overlays ]; then
			printf 'Relocating %s overlays ' "$dtb_dir"
			for dtbo in `ls ${CHROOT}/boot/$dtb_dir/overlays/*dtbo`; do
				mv $dtbo ${CHROOT}/boot/overlays/${dtbo##*/}
				printf '.'
			done
			printf 'Complete\n'
		fi
	done

	printf 'Installing base software components... '
	for bp in alpine-base openrc busybox-initscripts wpa_supplicant \
        wpa_supplicant-openrc openssh openssh-server openssh-server-common \
        openssh-keygen sudo openssh-client e2fsprogs e2fsprogs-extra \
		openntpd util-linux ; do
		printf '%s ' $bp
		chroot ${CHROOT} /sbin/apk add -q $bp
		CHECK_ERROR $? apk_add_$bp
	done
	printf '\n'
}

## Actually make the system bootable
function prep_bootable()
{
	case ${IMAGE_ARCH} in
		arm*|aarch*)
			## First create the cmdline.txt
			printf 'Creating /boot/cmdline.txt\n'
			printf 'modules=loop,squashfs,sd-mod,usgb-storage quiet console=tty1 root=/dev/mmcblk0p2\n' > ${CHROOT}/boot/cmdline.txt
			## Now our config.txt
			printf 'Creating /boot/config.txt\n'
			cat << EOF > ${CHROOT}/boot/config.txt
## This file may be overwritten on upgrade! Make your changes to
## usercfg.txt instead!
[pi3]
kernel=vmlinuz-rpi
initramfs initramfs-rpi
[pi3+]
kernel=vmlinuz-rpi
initramfs initramfs-rpi
[pi4]
enable_gic=1
kernel=vmlinuz-rpi4
initramfs initramfs-rpi4
[all]
arm_64bit=1
include usercfg.txt
EOF
			;;
		*)
			## XXX: Not Yet Implemented
			echo "" > /dev/null
	esac
	## Prepare the network correctly.
	printf 'Creating DHCP network configuration\n'
	cat << EOF > ${CHROOT}/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0 
iface eth0 inet dhcp
iface eth0 inet6 manual
	pre-up echo 1 > /proc/sys/net/ipv6/conf/eth0/accept_ra

auto wlan0
iface wlan0 inet manual
	up ip link set $IFACE up
	down ip link set $IFACE down
EOF

	## Fix SSH
	sed -i -E 's/^.?PermitRootLogin.*/PermitRootLogin prohibit-password/' $CHROOT/etc/ssh/sshd_config
	printf 'NOTICE: sshd will permit root login only with an authorized key!\n'
}

function prep_openrc()
{
	printf 'Configuring openrc...\n'
	printf '[openrc] boot\n'
	for svc in bootmisc hostname loadkmap modules networking syslog urandom; do
		chroot ${CHROOT} /sbin/rc-update add $svc boot
	done
	case ${IMAGE_ARCH} in
		arm*|aarch*)
			chroot ${CHROOT} /sbin/rc-update add swclock boot
			;;
		*)
			chroot ${CHROOT} /sbin/rc-update add hwclock boot
			;;
	esac
	printf '[openrc] sysinit\n'
	for svc in devfs dmesg hwdrivers mdev; do
		chroot ${CHROOT} /sbin/rc-update add $svc sysinit
	done
	printf '[openrc] shutdown\n'
	for svc in killprocs mount-ro savecache; do
		chroot ${CHROOT} /sbin/rc-update add $svc shutdown
	done
	printf '[openrc] default\n'
	for svc in openntpd sshd wpa_supplicant; do
		chroot ${CHROOT} /sbin/rc-update add $svc default
	done
}

function prep_users()
{
	SHORTVER=$(echo ${IMAGE_VERSION} | cut -d . -f 1,2 | sed -e 's/\.//')
	ROOT_PASSWD=${ROOT_PASSWD:-'Alp!n3'}
	printf 'Setting root password to %s\n' "${ROOT_PASSWD}" | tee -a ${logfile}
	echo -e "${ROOT_PASSWD}\n${ROOT_PASSWD}" | chroot ${CHROOT} /usr/bin/passwd -a sha512 root
	CHECK_ERROR $? "root password"
	if [ $(grep alpi /etc/passwd > /dev/null ; echo $?) -ne 0 ]; then
		printf 'Adding alpi user\n' | tee -a ${logfile}
		chroot ${CHROOT} /usr/sbin/adduser -D -h /home/alpi -g "AlPi Default User" -s /bin/sh alpi
		CHECK_ERROR $? "create alpi user"
	fi
	ALPI_PASSWD=${ALPI_PASSWD:-Linux!${SHORTVER}}
	printf 'Setting alpi password to %s\n' ${ALPI_PASSWD} | tee -a ${logfile}
	echo -e "${ALPI_PASSWD}\n${ALPI_PASSWD}" | chroot ${CHROOT} /usr/bin/passwd -a sha512 alpi
	CHECK_ERROR $? "alpi password"

	## Add alpi to sudoers
	sed -i -E '/root ALL/ i alpi\tALL=(ALL)\tALL' ${CHROOT}/etc/sudoers
	CHECK_ERROR $? "alpi sudoer"
	printf 'Added alpi to /etc/sudoers\n' | tee -a ${logfile}
}

## The Special Sauce
function prep_rootwyrm()
{
	local extern=/opt/rootwyrm/extern
	## Do NOT forget growpart
	if [ ! -f $CHROOT/usr/bin/growpart ]; then
		if [ ! -f $extern/growpart ]; then
			printf 'growpart is missing from extern!\n'
			exit 255
		else
			cp $extern/growpart ${CHROOT}/usr/bin/
			chown 0:0 ${CHROOT}/usr/bin/growpart
			chmod +x ${CHROOT}/usr/bin/growpart
		fi
	fi
	## Install our special sauce
	sed -i -E 's/^.?rc_verbose/rc_verbose=yes/' $CHROOT/etc/rc.conf
	if [ -f $extern/growfs ]; then
		cp $extern/growfs $CHROOT/etc/local.d/00-growfs.start
		chown 0:0 $CHROOT/etc/local.d/00-growfs.start
		chmod +x $CHROOT/etc/local.d/00-growfs.start
		echo "growfs enabled" > $CHROOT/boot/growfs
	fi
	chroot ${CHROOT} /sbin/rc-update add local default
}

function prep_additional_packages()
{
	if [ -f /opt/rootwyrm/conf/alpine.pkg ]; then
		printf 'Adding additional packages...\n'
	fi
	for ap in `cat /opt/rootwyrm/conf/alpine.pkg`; do
		pkg=$(echo $ap | cut -d : -f 1)
		openrc=$(echo $ap | cut -d : -f 2)
		runlevel=$(echo $ap | cut -d : -f 2)
		chroot ${CHROOT} /sbin/apk add $pkg
		if [ ! -z $openrc ]; then
			chroot ${CHROOT} /sbin/rc-update add $openrc $runlevel
		fi
	done
	## Update rc-update to prevent a known issue
	chroot $CHROOT /sbin/rc-update --update
}

printf '*** Entering alpine_prep %s %s...\n' "${IMAGE_VERSION}" "${IMAGE_ARCH}" | tee -a ${logfile}

prep_core
prep_bootable
prep_openrc
prep_users
prep_rootwyrm
prep_additional_packages
prep_fstab
cat $CHROOT/etc/fstab

printf '*** Exiting alpine_prep...\n' | tee -a ${logfile}

