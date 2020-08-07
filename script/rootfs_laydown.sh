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
## Lay down the rootfs
##

. /opt/rootwyrm/bin/stdlib.sh

function retrieve_miniroot()
{
	SHORTREL=$(echo ${IMAGE_VERSION} | cut -d . -f 1,2)
	export MINROOTFS_URL=https://dl-cdn.alpinelinux.org/alpine/v${SHORTREL}/releases/${IMAGE_ARCH}/alpine-minirootfs-${IMAGE_VERSION}-${IMAGE_ARCH}.tar.gz
	printf 'Retrieving from %s\n' "$MINROOTFS_URL" | tee -a ${logfile}
	## XXX We verify before we actually install it.
	curl -L --progress $MINROOTFS_URL > /tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz
	curl -L --silent $MINROOTFS_URL.sha256 > /tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz.sha256
	local origin_sha=$(cat /tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz.sha256 | awk '{print $1}')
	local local_sha=$(sha256sum /tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz | awk '{print $1}')
	printf 'Origin SHA %s\n' $origin_sha >> ${logfile}
	if [[ "$origin_sha" != "$local_sha" ]]; then
		printf 'ORIGIN: %s\n' "$origin_sha"
		printf 'RESULT: %s\n' "$local_sha"
		printf 'SHA256 checksum did not match!\n' | tee -a ${logfile}
		exit 255
	else
		printf 'Verified SHA256 checksum\n' | tee -a ${logfile}
	fi
	## Verify signature
	local ORIGIN_KEY=https://alpinelinux.org/keys/ncopa.asc
	curl -L --silent $ORIGIN_KEY > ncopa.asc
	gpg --import ncopa.asc | tee -a ${logfile} > /dev/null
	curl -L --silent $MINROOTFS_URL.asc > /tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz.asc 
	gpg --verify /tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz.asc /tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz | tee -a ${logfile} > /dev/null
	if [ $? -ne 0 ]; then
		printf 'Failed to verify against signing key, bailing out!\n'
		exit 255
	else
		printf 'GPG signature validated successfully \n'
	fi
}

function build_miniroot()
{
	local tarfile=/tmp/${IMAGE_RELEASE}-${IMAGE_ARCH}.tar.gz
	local SHORTREL=$(echo ${IMAGE_VERSION} | cut -d . -f 1,2)
	printf 'Extracting minirootfs...\n'
	tar xfz $tarfile -C $CHROOT/
	CHECK_ERROR $? "extract minirootfs"

	## Now we need to do our bind mounts.
	mount --bind /proc $CHROOT/proc
	CHECK_ERROR $? "bind mount /proc"
	mount --bind /proc/sys/fs/binfmt_misc $CHROOT/proc/sys/fs/binfmt_misc
	CHECK_ERROR $? "bind mount /proc/sys/fs/binfmt_misc"
	mount --bind /sys $CHROOT/sys
	CHECK_ERROR $? "bind mount /sys"

	## BOOTSTRAP STEP
	local qemubin=$(which qemu-${IMAGE_ARCH}-static)
	cp $qemubin ${CHROOT}${qemubin}
	cp /etc/resolv.conf $CHROOT/etc/resolv.conf
	rm $CHROOT/etc/apk/repositories
	for x in main community; do
		printf 'https://dl-cdn.alpinelinux.org/alpine/v%s/%s\n' "$SHORTREL" "$x" >> $CHROOT/etc/apk/repositories
	done
}

printf '*** Entering rootfs_laydown...\n' | tee -a ${logfile}

retrieve_miniroot
build_miniroot

printf '*** Exiting rootfs_laydown...\n' | tee -a ${logfile}
