#!/bin/sh
# for alpine

apk --no-cache update 
apk --no-cache upgrade
apk --no-cache -q add bash curl ca-certificates-bundle coreutils dosfstools u-boot-tools losetup file udev parted e2fsprogs wget gpg gpg-agent blkid git lsblk findmnt e2fsprogs-extra squashfs-tools
apk --no-cache --no-script -q add grub grub-efi
### Stupid debian extraction step...
#apk --no-cache add btrfs-progs linux-firmware-intel
#apk --no-cache add linux-lts
#echo btrfs >> /etc/modules
ls -l /opt/rootwyrm/bin/
/opt/rootwyrm/bin/uboot_imager.sh 3.18 s905x

#cd /chroot
#for i in /proc /sys /dev; do mount -o bind $i .$i; done
#chroot /chroot /usr/sbin/grub-install
#chroot /chroot /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg
