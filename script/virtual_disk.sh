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
## Virtual Disk setup
##

. /opt/rootwyrm/bin/stdlib.sh
. /etc/os-release

DISK_SIZE=${DISK_SIZE:-2048}

function create_imagefile()
{
	if [ ! -d /image ]; then
		printf 'No /image volume, bailing out!\n'
		exit 255
	fi
	printf 'Creating virtual disk /image/%s %sMB\n' "${IMAGE_FILE}" "$DISK_SIZE" | tee -a ${logfile}
	dd if=/dev/zero of=/image/${IMAGE_FILE} bs=1M count=$DISK_SIZE | tee -a ${logfile}
	CHECK_ERROR $? "/image/${IMAGE_FILE}"
}

function partition_imagefile()
{
	if [ ! -f /image/${IMAGE_FILE} ]; then
		printf 'Image file /image/%s missing?!\n' "${IMAGE_FILE}"
		exit 255
	fi
	local IMAGE=/image/${IMAGE_FILE}

	## Switch around architectures
	case ${IMAGE_ARCH} in
		arm*|aarch*)
			## Assume RPi or compatible
			parted -s $IMAGE mklabel msdos
			CHECK_ERROR $? "create disk label"
			parted -s $IMAGE mkpart primary fat32 1 513MB
			CHECK_ERROR $? "create fat32 boot partition"
			parted -s $IMAGE -- set 1 boot on
			CHECK_ERROR $? "set first partition bootable"
			parted -s $IMAGE mkpart primary ext4 513MB 100%
			CHECK_ERROR $? "make Linux root partition"
			printf '================================================================================\n' >> ${logfile}
			printf 'Partition information for %s\n' "$IMAGE" >> ${logfile}
			parted -s $IMAGE print >> ${logfile}
			printf '================================================================================\n' >> ${logfile}
			;;
		*)
			## Assume x86 or compatible
			parted -s $IMAGE mklabel msdos
			CHECK_ERROR $? "create disk label"
			parted -s $IMAGE mkpart primary ext2 1 513MB
			CHECK_ERROR $? "create ext2 boot partition"
			parted -s $IMAGE -- set 1 boot on
			CHECK_ERROR $? "set first partition bootable"
			parted -s $IMAGE mkpart primary ext4 513MB 100%
			CHECK_ERROR $? "make Linux root partition"
			printf '================================================================================\n' >> ${logfile}
			printf 'Partition information for %s\n' "$IMAGE" >> ${logfile}
			parted -s $IMAGE print >> ${logfile}
			printf '================================================================================\n' >> ${logfile}
			;;
	esac
}

function loopback_setup()
{
	printf 'Setting up loopback device...'
	local IMAGE=/image/${IMAGE_FILE}
	## XXX Again assuming it's debian or compatible
	losetup -f -P --show $IMAGE | tee -a /tmp/loopdev
	export LOOPDEV=$(cat /tmp/loopdev)
	export BOOTPART=${LOOPDEV}p1
	export ROOTPART=${LOOPDEV}p2

	printf 'Boot partition at %s\n' "$BOOTPART"
	printf 'Root partition at %s\n' "$ROOTPART"
}

function format_virtual()
{
	printf 'Formatting virtual disk...\n'
	## Switch based on arch
	case ${IMAGE_ARCH} in
		arm*|aarch*)
			## boot is fat32
			mkfs.fat -F 32 -n "BOOT" ${BOOTPART} >> ${logfile}
			CHECK_ERROR $? "format boot partition fat32"
			mkfs.ext4 -L "alpine" ${ROOTPART} >> ${logfile}
			CHECK_ERROR $? "format root partition ext4"
			;;
		*)
			mkfs.ext2 -L "boot" ${BOOTPART} >> ${logfile}
			CHECK_ERROR $? "format boot partition ext2"
			mkfs.xfs -L "alpine" ${ROOTPART} >> ${logfile}
			CHECK_ERROR $? "format root partition xfs"
			;;
	esac
}

function mount_virtual()
{
	CHROOT=${CHROOT:-/chroot}
	if [ ! -d $CHROOT ]; then
		mkdir $CHROOT
	fi

	mount -o rw,defaults ${ROOTPART} $CHROOT
	CHECK_ERROR $? "mounting root partition"
	mkdir $CHROOT/boot
	chown 0:0 $CHROOT/boot
	case ${IMAGE_ARCH} in
		arm*|aarch*)
			mount -t vfat -o rw,defaults ${BOOTPART} $CHROOT/boot
			CHECK_ERROR $? "mounting boot partition"
			;;
		*)
			mount -t ext2 -o rw,defaults ${BOOTPART} $CHROOT/boot
			CHECK_ERROR $? "mounting boot partition"
			;;
	esac
}

printf '*** Entering virtual_disk...\n' | tee -a ${logfile}

create_imagefile
partition_imagefile
loopback_setup
format_virtual
mount_virtual

printf '*** Exiting virtual_disk...\n' | tee -a ${logfile}
