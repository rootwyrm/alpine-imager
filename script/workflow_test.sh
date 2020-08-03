#!/bin/bash
# XXX: this is a script to test if critical workflow pieces are available

OUTDIR=${GITHUB_WORKSPACE}/images
CHROOT=${GITHUB_WORKSPACE}/chroot

mkdir $CHROOT
mkdir $OUTDIR

curl -L http://dl-cdn.alpinelinux.org/alpine/v3.12/releases/x86_64/alpine-minirootfs-3.12.0-x86_64.tar.gz | tar xfz - -C chroot/

chroot ${CHROOT} /bin/echo "[1] Chroot Successful"
mount --bind /proc ${CHROOT}/proc
echo "Bind mount /proc successful"
mount --bind /dev ${CHROOT}/dev
echo "Bind mount /dev successful"

exit 0
