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
## For building images for Raspberry Pi Imager tool
##
set -e
#set -x

source /opt/rootwyrm/bin/stdlib.sh
source /etc/os-release

export IMAGE_NAME=$1
export IMAGE_VERSION=$2
export IMAGE_FILE=$3
export PLATFORM=$4
export CHROOT=${CHROOT:-/chroot}
export SHORTREL=$(echo ${IMAGE_VERSION} | cut -d . -f 1,2)
export logfile=/image/${IMAGE_NAME}.log
if [ ! -f $logfile ]; then
	touch $logfile
fi
DISK_SIZE=${DISK_SIZE:-1024}

if [ -f /.dockerenv ]; then
	export DOCKER=true
	source /.dockerenv
fi

## Install host packages
function host_packages()
{
	printf '*** Configuring build host...\n' | tee -a ${logfile}
	echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
	apt-get -q -y update > /dev/null
	apt-get -q -y install apt-utils > /dev/null
	if [ ! -f /opt/rootwyrm/conf/host_${ID}.pkg ]; then
		printf 'Missing host package configuration: host %s.pkg\n' "${ID}"
		exit 255
	else
		printf '*** Installing host packages: ' | tee -a ${logfile}
		for p in `cat /opt/rootwyrm/conf/host_${ID}.pkg | grep -v ^#`; do
			printf '%s ' "$p" | tee -a $logfile
			apt-get install -y -q $p > /dev/null
			CHECK_ERROR $? "apt-get install $p" | tee -a ${logfile}
		done
		printf '\n' | tee -a ${logfile}
	fi
}

## Set up virtual disk
function virtual_disk()
{
	if [ ! -d /image ]; then
		printf 'No /image volume, bailing out!\n'
		exit 255
	fi
	printf 'Creating virtual disk /image/%s %sMB\n' "${IMAGE_FILE}" "$DISK_SIZE" | tee -a ${logfile}
	dd if=/dev/zero of=/image/${IMAGE_FILE} bs=1M count=$DISK_SIZE | tee -a ${logfile}
	CHECK_ERROR $? "create /image/${IMAGE_FILE}"

	## Partition the disk
	if [ ! -f /image/${IMAGE_FILE} ]; then
		printf 'Image file /image/%s missing?\n' "${IMAGE_FILE}"
		exit 255
	fi
	local IMAGE=/image/${IMAGE_FILE}
	## XXX: Raspberry Pi doesn't need the image switching
	parted -s $IMAGE mklabel msdos
	CHECK_ERROR $? "create disk label"
	parted -s $IMAGE mkpart primary fat32 1 513MB
	CHECK_ERROR $? "create fat32 boot partition"
	parted -s $IMAGE -- set 1 boot on
	CHECK_ERROR $? "set first partition bootable"
	parted -s $IMAGE mkpart primary ext4 513MB 100%
	CHECK_ERROR $? "make Alpine Linux root partition"
	printf '================================================================================\n' | tee -a ${logfile}
	printf '>>> Partition information for %s\n' "$IMAGE" | tee -a ${logfile}
	printf '\n' | tee -a ${logfile}
	parted -s $IMAGE print | tee -a ${logfile}
	printf '================================================================================\n' | tee -a ${logfile}

	## Setup loopback devices
	printf '*** Setting up loopback devices...\n' | tee -a ${logfile}
	losetup -f -P --show $IMAGE | tee -a /tmp/loopdev
	CHECK_ERROR $? "loopback device setup"
	export LOOPDEV=$(cat /tmp/loopdev)
	export BOOTPART=${LOOPDEV}p1
	export ROOTPART=${LOOPDEV}p2
	printf '*** Boot partition at %s\n' "$BOOTPART" | tee -a ${logfile}
	printf '*** Root partition at %s\n' "$ROOTPART" | tee -a ${logfile}

	## Format the disks
	printf '>>> Formatting boot partition\n' | tee -a ${logfile}
	mkfs.fat -F 32 -n "BOOT" ${BOOTPART} | tee -a ${logfile}
	CHECK_ERROR $? "format boot partition fat32"
	printf '>>> Formatting root partition\n' | tee -a ${logfile}
	mkfs.ext4 -L "alpine" ${ROOTPART} | tee -a ${logfile}
	CHECK_ERROR $? "format root partition ext4"

	## Mount the disks
	## XXX: do not use tmpfs for CHROOT, now has noexec as default
	if [ ! -d $CHROOT ]; then
		mkdir $CHROOT
	fi
	## Mount the fat32 under the root
	printf '*** Mounting %s to chroot...\n' "${ROOTPART}" | tee -a ${logfile}
	mount -v -o rw,defaults ${ROOTPART} $CHROOT
	CHECK_ERROR $? "mounting root partition"
	mkdir $CHROOT/boot
	CHECK_ERROR $? "mkdir $CHROOT/boot"
	chown 0:0 $CHROOT/boot
	printf '*** Mounting %s to chroot/boot...\n' "${BOOTPART}" | tee -a ${logfile}
	mount -v -t vfat -o rw,defaults ${BOOTPART} $CHROOT/boot
	CHECK_ERROR $? "mounting boot partition"

}

## Retrieve and validate the minrootfs tarball
function rootfs_retrieve()
{
	export MINROOTFS_URL=https://dl-cdn.alpinelinux.org/alpine/v${SHORTREL}/releases/aarch64/alpine-minirootfs-${IMAGE_VERSION}-aarch64.tar.gz
	printf '*** Retrieving miniroot from %s\n' "$MINROOTFS_URL" | tee -a ${logfile}
	curl -L --progress-bar $MINROOTFS_URL -o /tmp/$IMAGE_VERSION-aarch64.tar.gz
	curl -L --progress-bar $MINROOTFS_URL.sha256 -o /tmp/$IMAGE_VERSION-aarch64.tar.gz.sha256
	
	## Validate signature
	local origin_sha=$(cat /tmp/${IMAGE_VERSION}-aarch64.tar.gz.sha256 | awk '{print $1}')
	local local_sha=$(sha256sum /tmp/${IMAGE_VERSION}-aarch64.tar.gz | awk '{print $1}')
	printf '!!! Validating sha256sum of files...' | tee -a ${logfile}
	if [[ "$origin_sha" != "$local_sha" ]]; then
		printf '\nORIGIN %s\n' "$origin_sha"
		printf 'RESULT: %s\n' "$local_sha"
		printf 'FAIL! SHA256 checksum did not match!\n' | tee -a ${logfile}
		exit 255
	else
		printf 'OK!\n' | tee -a ${logfile}
		## Provide additional evidence.
		printf '!!! SHA256 ORIGIN: %s\n' "$origin_sha" | tee -a ${logfile}
		printf '!!! SHA256 LOCAL : %s\n' "$local_sha" | tee -a ${logfile}
	fi

	## Verify the signature
	local ORIGIN_KEY=https://alpinelinux.org/keys/ncopa.asc
	printf '!!! Validating signing key...' | tee -a ${logfile}
	curl -L --silent $ORIGIN_KEY > /tmp/ncopa.asc
	gpg --import /tmp/ncopa.asc | tee -a ${logfile}
	curl -L --silent $MINROOTFS_URL.asc > /tmp/${IMAGE_VERSION}-aarch64.tar.gz.asc
	gpg --verify /tmp/${IMAGE_VERSION}-aarch64.tar.gz.asc /tmp/${IMAGE_VERSION}-aarch64.tar.gz | tee -a ${logfile}
	if [ $? -ne 0 ]; then
		printf '!!! Failed to verify against signing key, refusing!\n'
		exit 255
	else
		printf 'GPG signatures verified\n' | tee -a ${logfile}
	fi
}

## Lay down the minrootfs on our chroot
function rootfs_laydown()
{
	printf '>>> Laying down Alpine Linux %s...\n' "${IMAGE_VERSION}"
	local tarfile=/tmp/${IMAGE_VERSION}-aarch64.tar.gz
	local shortrel=$(echo ${IMAGE_VERSION} | cut -d . -f 1,2)
	tar xfz $tarfile -C $CHROOT/
	CHECK_ERROR $? "extract minrootfs"

	## Do our bind mounts, or apk doesn't work.
	printf '*** Performing vital bind mounts...' | tee -a ${logfile}
	mount --bind /proc $CHROOT/proc
	CHECK_ERROR $? "bind mount /proc"
	printf '/proc ' | tee -a ${logfile}
	mount --bind /proc/sys/fs/binfmt_misc $CHROOT/proc/sys/fs/binfmt_misc
	CHECK_ERROR $? "bind mount /proc/sys/fs/binfmt_misc"
	printf '/proc/sys/fs/binfmt_misc ' | tee -a ${logfile}
	mount --bind /sys $CHROOT/sys
	CHECK_ERROR $? "bind mount /sys"
	printf '/sys' | tee -a ${logfile}
	printf '\n'

	## qemu bootstrap, extremely critical!
	local qemubin=$(which qemu-aarch64-static)
	cp $qemubin ${CHROOT}${qemubin}
	## FYI: quad9 is usually unavailable from Github actions
	cp /etc/resolv.conf ${CHROOT}/etc/resolv.conf
	printf '>>> Setting up repositories in chroot...\n' | tee -a ${logfile}
	if [ -f ${CHROOT}/etc/apk/repositories ]; then
		rm $CHROOT/etc/apk/repositories
	fi
	for x in main community; do
		printf 'https://dl-cdn.alpinelinux.org/alpine/v%s/%s\n' "$shortrel" "$x" >> $CHROOT/etc/apk/repositories
	done
}

## Now comes the fun parts...
## Actually prepare the Alpine image for Raspberry Pi imager.
function prep_fstab()
{
	if [ ! -z $BOOTUUID ]; then
		printf '>>> boot UUID %s\n' "$BOOTUUID" | tee -a ${logfile}
	else
		printf '>>> Rediscovering boot UUID... ' | tee -a ${logfile}
		export BOOTUUID=$(blkid -s UUID -o value ${BOOTPART})
		if [[ $BOOTUUID == "" ]]; then
			printf 'failed!\n' | tee -a ${logfile}; exit 255
		fi
		printf '%s\n' "$BOOTUUID" | tee -a ${logfile}
	fi
	if [ ! -z $ROOTUUID ]; then
		printf '>>> root UUID %s\n' "$BOOTUUID" | tee -a ${logfile}
	else
		printf '>>> Rediscovering root UUID... ' | tee -a ${logfile}
		export ROOTUUID=$(blkid -s UUID -o value ${ROOTPART})
		if [[ $ROOTUUID == "" ]]; then
			printf 'failed!\n' | tee -a ${logfile}; exit 255
		fi
		printf '%s\n' "$ROOTUUID" | tee -a ${logfile}
	fi

	#XXX: No arch switching here
	local fstab=${CHROOT}/etc/fstab
	echo "UUID=${ROOTUUID}	/	ext4	defaults	0 0" > $fstab
	echo "UUID=${BOOTUUID}		/media/mmcblk0p1	vfat	defaults	0 0" >>  $fstab
	echo "## DO NOT MODIFY THIS SECTION" >> $fstab
	echo "/media/mmcblk0p1	/boot	none	defaults,bind	0 0" >> $fstab
	echo "## ADD ANY CUSTOM ENTRIES AFTER THIS POINT" >> $fstab
	echo "" >> $fstab
	echo "/dev/usbdisk	/media/usb	vfat	noauto	0 0" >> $fstab
}

## Prep our setup to actually be bootable
function prep_bootable()
{
	printf '>>> Updating apk repositories...\n' | tee -a ${logfile}
	chroot ${CHROOT} /sbin/apk update | tee -a ${logfile}
	CHECK_ERROR $? prep_bootable_apk_update
	printf '>>> Installing late-breaking security fixes...\n' | tee -a ${logfile}
	chroot ${CHROOT} /sbin/apk upgrade | tee -a ${logfile}
	printf 'apk upgrade %s\n' "$?"
	CHECK_ERROR $? prep_bootable_apk_upgrade
	printf '>>> Installing kernels... \n'
	## Have to install _both_ kernels...
	for k in linux-rpi linux-rpi4; do
		printf '%s\n' "$k"
		chroot ${CHROOT} /sbin/apk -q add $k | tee -a ${logfile}
		CHECK_ERROR $? apk_add_$k
	done
	BOOTPKG=${BOOTPKG:-raspberrypi-bootloader}
	chroot ${CHROOT} /sbin/apk -q --no-cache add raspberrypi-bootloader | tee -a ${logfile}
	chroot ${CHROOT} /sbin/apk -q --no-cache add raspberrypi-bootloader-debug | tee -a ${logfile}
	CHECK_ERROR $? apk_add_$BOOTPKG
	## temp debug
	echo "TEMP DEBUG" | tee -a ${logfile}
	ls -l ${CHROOT}/boot | tee -a ${logfile}

	if [ ! -d ${CHROOT}/boot/overlays ]; then
		mkdir ${CHROOT}/boot/overlays
		chown 0:0 ${CHROOT}/boot/overlays
	fi

	## XXX: no more need for the dtbsd packages or fixup

	printf '>>> Creating /boot/cmdline.txt\n' | tee -a ${logfile}
	printf 'modules=loop,squashfs,sd-mod,usb-storage quiet console=tty1 root=/dev/mmcblk0p2 waitroot\n' > ${CHROOT}/boot/cmdline.txt
	printf '>>> Creating /boot/config.txt\n'
	cat << EOF > ${CHROOT}/boot/config.txt
### This file may be overwritten on upgrade! Make your changes to
### usercfg.txt instead!
## https://www.raspberrypi.com/documentation/computers/config_txt.html
[pi02]
kernel=vmlinuz-rpi
initramfs initramfs-rpi
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
}

## Install our software
function prep_software()
{
	printf '>>> Installing base software components...\n'
	for bp in alpine-base alpine-baselayout-data alpine-conf busybox-openrc \
		wpa_supplicant wpa_supplicant-openrc \
		openssh openssh-server openssh-server-common openssh-keygen \
		openssh-client-default openssh-keysign \
		doas e2fsprogs e2fsprogs-extra chrony chrony-openrc \
		util-linux haveged ca-certificates bash bash-completion \
		libcamera-raspberrypi bluez bluez-deprecated \
		cloud-utils cloud-utils-growpart; do
		printf '%s ' "$bp"
		chroot ${CHROOT} /sbin/apk add -q --no-cache $bp
		CHECK_ERROR $? apk_add_$bp
	done
	printf '\n'
	printf '>>> Installing cloud-init...\n'
	chroot ${CHROOT} /sbin/apk add -q --no-cache cloud-init
	printf '>>> Installing cloud-init supporting components...\n'
	for ci in \
		cloud-init-openrc py3-pyserial py3-netifaces e2fsprogs-extra; do
		printf '%s ' "$ci"
		chroot ${CHROOT} /sbin/apk add -q --no-cache $ci
		CHECK_ERROR $? apk_add_$ci
	done
	printf '\n'
	## Give users pretty shell by default
	mv ${CHROOT}/etc/profile.d/color_prompt.sh.disabled ${CHROOT}/etc/profile.d/color_prompt.sh
	chmod +x ${CHROOT}/etc/profile.d/color_prompt.sh
	## XXX: late breaking 3.18 change
	case $SHORTREL in
		3.17*)
			chmod +x ${CHROOT}/etc/profile.d/bash_completion.sh
			;;
		3.18*)
			chmod +x ${CHROOT}/etc/bash/bash_completion.sh
			chroot ${CHROOT} ln -s /etc/bash/bash_completion.sh /etc/profile.d/bash_completion.sh
			;;
	esac
}

function prep_configuration()
{
		printf '>>> Setting network to DHCP defaults...\n' | tee -a ${logfile}
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

	printf '>>> Configuring openrc...\n' | tee -a ${logfile}
	printf '>>> [openrc] boot\n'
	for svc in bootmisc hostname loadkmap modules networking syslog swclock haveged; do
		chroot ${CHROOT} /sbin/rc-update add $svc boot | tee -a ${logfile}
	done
	printf '>>> [openrc] sysinit\n'
	for svc in devfs dmesg hwdrivers mdev; do
		chroot ${CHROOT} /sbin/rc-update add $svc sysinit | tee -a ${logfile}
	done
	printf '>>> [openrc] shutdown\n'
	for svc in killprocs mount-ro savecache; do
		chroot ${CHROOT} /sbin/rc-update add $svc shutdown | tee -a ${logfile}
	done
	printf '>>> [openrc] default\n'
	for svc in chronyd sshd wpa_supplicant ; do
		chroot ${CHROOT} /sbin/rc-update add $svc default | tee -a ${logfile}
	done
	printf '>>> Enabling cloud-init\n'
	chroot ${CHROOT} /sbin/setup-cloud-init

	## Now we have to configure it.
	cat << EOF > ${CHROOT}/etc/cloud/cloud.cfg.d/00_datasource.cfg
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: BOOT
EOF
}

## Finalize by cleaning up and being a good steward of resources
function finalize()
{
	printf '*** Flushing and unmounting chroot\n' | tee -a ${logfile}
	sync
	cd /
	umount ${CHROOT}/proc/sys/fs/binfmt_misc
	umount ${CHROOT}/proc
	umount ${CHROOT}/sys
	umount ${CHROOT}/boot
	umount ${CHROOT}
	losetup -d $LOOPDEV
}

printf '################################################################################\n'
printf '*** Beginning build for Raspberry Pi Imager...\n'
printf '################################################################################\n'
host_packages
virtual_disk
rootfs_retrieve
rootfs_laydown
prep_fstab
prep_bootable
prep_software
prep_configuration
finalize