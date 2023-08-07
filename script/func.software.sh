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

# Software setup functions

function software_prep_bootable()
{
  printf '>>> Updating apk repositories...\n'
  chroot ${CHROOT} /sbin/apk update --no-cache
  CHECK_ERROR $? "apk update"
  printf '>>> Installing late-breaking security fixes...\n'
  chroot ${CHROOT} /sbin/apk upgrade --no-cache
  CHECK_ERROR $? "apk upgrade security update"

  ## Special handler for Raspberry Pi
  if [ $ALPINE_PLATFORM == "rpi" ]; then
    printf '>>> Installing Raspberry Pi kernels ...\n'
    chroot ${CHROOT} /sbin/apk add --no-cache linux-rpi linux-rpi4
    CHECK_ERROR $? "apk add linux-rpi set"
    printf '>>> Installing Raspberry Pi userland tools...\n'
    chroot ${CHROOT} /sbin/apk add --no-cache raspberrypi-userland raspberrypi-utils raspberrypi-utils-raspinfo libcamera-raspberrypi
    CHECK_ERROR $? "apk add raspberrypi userland"
  elif [ -z $KERNEL ]; then
    printf '!!! FATAL: kernel not set!\n'
    exit 10
  fi

  ## Install firmware before kernel
  if [ -f /opt/rootwyrm/conf/bsp/${IMAGE_BSP}/firmware.list ]; then
    printf '>>> Installing firmware set...\n'
    chroot ${CHROOT} /sbin/apk add -q --no-cache $(cat /opt/rootwyrm/conf/bsp/${IMAGE_BSP}/firmware.list)
    CHECK_ERROR $? "apk add firmware set"
  elif [[ ${ALPINE_PLATFORM} == "rpi" ]]; then
    printf '>>> Installing Raspberry Pi firmware...\n'
    for fw in raspberrypi-bootloader; do
      chroot ${CHROOT} /sbin/apk add -q --no-cache $fw
      CHECK_ERROR $? "apk add $fw"
    done
  else
    ## Install the default firmware set
    printf '>>> Installing default firmware set...\n'
    for fw in atmel atusb brcm cadence cavium cis cpia2 cypress dabusb edgeport go7007 keyspan keyspan_pda libertas mediatek meson microchip moxa mrvl mwl8k mwlwifi nxp ositech rockchip rsi rtl8192e rtl_bt rtl_nic rtlwifi rtw88 rtw89 sxg ti ti-connectivity ti-keystone ttusb-budget vicam; do
      chroot ${CHROOT} /sbin/apk add -q --no-cache linux-firmware-${fw}
      CHECK_ERROR $? "apk add linux-firmware-${fw}"
    done
  fi
  printf '>>> Installing kernel...\n'
  chroot ${CHROOT} /sbin/apk add -q --no-cache ${KERNEL}  
  CHECK_ERROR $? "apk add ${KERNEL}"

  ## Call our own function based on bootloader
  case $LOADER in
    grub)
      software_bootloader_grub
      ;;
    syslinux)
      software_bootloader_syslinux
      ;;
    rpi)
      software_bootloader_rpi
      ;;
    *)
      printf '!!! FATAL: unknown bootloader %s!\n' ${LOADER}
      exit 10
      ;;
  esac
}

function software_bootloader_grub()
{
  echo "NYI"
}

## syslinux/extlinux is used by default for BSPs
function software_bootloader_syslinux()
{
  if [ ! -f /opt/rootwyrm/conf/bsp/${ALPINE_PLATFORM}/extlinux.conf ]; then
    printf '!!! extlinux not supported for this BSP?\n'
    exit 1
  fi
  mkdir -p ${CHROOT}/boot/extlinux/
  cp /opt/rootwyrm/conf/bsp/${ALPINE_PLATFORM}/extlinux.conf ${CHROOT}/boot/extlinux/extlinux.conf
  CHECK_ERROR $? "copy extlinux.conf to target"
}

function software_bootloader_rpi()
{
  printf '>>> Installing Raspberry Pi bootloader...\n'
  chroot ${CHROOT} /sbin/apk add -q --no-cache raspberrypi-bootloader
  CHECK_ERROR $? "apk add raspberrypi-bootloader"
  printf '>>> Creating /boot/cmdline.txt\n'
  cat << EOF > ${CHROOT}/boot/cmdline.txt
modules=loop,squashfs,sd-mod,usb-storage quiet console=tty1 root=/dev/mmcblk0p2 waitroot
EOF
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

function software_prep_base()
{
  printf '>>> Installing Alpine base software...\n'
  if [ -f /opt/rootwyrm/conf/alpine/${ALPINE_VERSION}/apk ]; then
    chroot ${CHROOT} /sbin/apk add -q --no-cache $(cat /opt/rootwyrm/conf/alpine/${ALPINE_VERSION}/apk)
    CHECK_ERROR $? "apk add base set"
  else
    printf '!!! FATAL: base apk set not found!\n'
    exit 10
  fi
}

function software_prep_cloudinit()
{
  printf '>>> Installing cloud-init... '
  for ci in cloud-init cloud-init-openrc py3-pyserial py3-netifaces e2fsprogs-extra; do
    printf '%s ' "$ci"
    chroot ${CHROOT} /sbin/apk add -q --no-cache $ci
    CHECK_ERROR $? apk_add_$ci
  done
  printf '\n'

  printf '>>> Updating cloud-init datasource...\n'
  cat << EOF > ${CHROOT}/etc/cloud/cloud.cfg.d/00_datasource.cfg
datasource_list: [ NoCloud, None ]
datasource:
  NoCloud:
    fs_label: BOOT
EOF
  cat << EOF > ${CHROOT}/boot/meta-data
dsmode: local
instance-id: alpine-imager
EOF
}

function software_prep_openrc()
{
  if [ -f /opt/rootwyrm/conf/alpine/${ALPINE_VERSION}/rc ]; then
    mapfile -t openrc < /opt/rootwyrm/conf/alpine/${ALPINE_VERSION}/rc
    for rc in ${openrc[@]}; do
      stage=$(echo $rc | cut -d , -f 1)
      init=$(echo $rc | cut -d , -f 2)
      chroot ${CHROOT} /sbin/rc-update add $init $stage
    done
  else
    printf '!!! FATAL: openrc configuration not found!\n'
    exit 10
  fi
}