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

# Functions for disk setup

function virtual_disk_create()
{
  DISK_SIZE=${DISK_SIZE:-1024}
  if [ ! -d /image ]; then
    printf '!!! No /image volume, bailing out!\n'
    exit 255
  fi
  printf '>>> Creating virtual disk /image/%s\n' "${IMAGE_FILE}"

  dd if=/dev/zero of=/image/${IMAGE_FILE} bs=1M count=${DISK_SIZE} 
  CHECK_ERROR $? "create /image/${IMAGE_FILE}"
  case $DISK_SCHEME in
    mbr)
      virtual_disk_partition_mbr
      ;;
    gpt)
      virtual_disk_partition_gpt
      ;;
    *)
      printf '!!! Unknown disk scheme %s, bailing out!\n' "${DISK_SCHEME}"
      exit 255
      ;;
  esac
}

## GPT partitioning; not yet implemented
function virtual_disk_partition_gpt()
{
  echo "NYI"
}

## MBR partitioning
function virtual_disk_partition_mbr()
{
  printf '>>> Partitioning virtual disk /image/%s as MBR\n' "${IMAGE_FILE}"
  local IMAGE=/image/${IMAGE_FILE}
  parted -s $IMAGE mklabel msdos
  CHECK_ERROR $? "create disk label"
  # PARTITION_OFFSET is in megabytes
  if [ -z $PARTITION_OFFSET ]; then
    local PARTITION_OFFSET=1
  fi
  local BOOT_END=$((${PARTITION_OFFSET} + 256))
  parted -s $IMAGE mkpart primary fat32 ${PARTITION_OFFSET}M ${BOOT_END}M 
  CHECK_ERROR $? "create partition 1"
  parted -s $IMAGE -- set 1 boot on
  CHECK_ERROR $? "set partition 1 bootable"
  local EXT4_START=$((${BOOT_END} + 1))
  parted -s $IMAGE mkpart primary ext4 ${EXT4_START}M 100%
  CHECK_ERROR $? "create partition 2"

  printf '================================================================================\n'
  printf '>>> Partition information for %s\n' "${IMAGE_FILE}"
  parted -s $IMAGE print
  printf '================================================================================\n'
}

function virtual_disk_filesystem()
{
  printf '>>> Setting up loopback devices...\n'
  ## NYI: hack for now, prefer to use losetup -J | jq .loopdevices[].name off back-file
  losetup -f -P --show /image/$IMAGE_FILE | tee /tmp/loopdev
  CHECK_ERROR $? "setup loopback device"
  export LOOPDEV=$(cat /tmp/loopdev)
  export BOOTPART=${LOOPDEV}p1
  export ROOTPART=${LOOPDEV}p2
  printf '>>> Boot partition at %s\n' "${BOOTPART}"
  printf '>>> Root partition at %s\n' "${ROOTPART}"

  printf '>>> Creating boot filesystem...\n'
  mkfs.vfat -F 32 -n "BOOT" ${BOOTPART}
  CHECK_ERROR $? "create boot filesystem"
  printf '>>> Creating root filesystem...\n'
  mkfs.ext4 -F -L "alpine" ${ROOTPART}
  CHECK_ERROR $? "create root filesystem"

  if [ ! -d ${CHROOT} ]; then
    mkdir ${CHROOT}
  fi
  ## Mount root before the boot; boot goes under it
  printf '>>> Mounting root filesystem...\n'
  mount -v -o rw,defaults ${ROOTPART} ${CHROOT}
  CHECK_ERROR $? "mount root filesystem"
  mkdir $CHROOT/boot
  CHECK_ERROR $? "create boot mountpoint"
  chown 0:0 $CHROOT/boot
  printf '>>> Mounting boot filesystem...\n'
  mount -v -t vfat -o rw,defaults ${BOOTPART} ${CHROOT}/boot
  CHECK_ERROR $? "mount boot filesystem"

  ## Get our blkids here
  export BOOTUUID=$(blkid -s UUID -o value ${BOOTPART})
  export ROOTUUID=$(blkid -s UUID -o value ${ROOTPART})
}