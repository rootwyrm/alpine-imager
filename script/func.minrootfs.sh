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

# This function set is for filesystem retrieval and laydown functions

. /opt/rootwyrm/bin/stdlib.sh

function rootfs_retrieve()
{
	latest-releases $ALPINE_VERSION
	case ${ALPINE_VERSION} in
		edge)
			MINROOTFS_URL=https://dl-cdn.alpinelinux.org/alpine/${ALPINE_VERSION}/releases/aarch64/${ALPINE_FILE}
			;;
		*)
			MINROOTFS_URL=https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/aarch64/${ALPINE_FILE}
			;;
	esac

	printf '>>> Retrieving miniroot from %s\n' "$MINROOTFS_URL" | tee -a ${logfile}
	#curl -L --progress-bar $MINROOTFS_URL -o /tmp/$ALPINE_VERSION-aarch64.tar.gz
	curl -L $MINROOTFS_URL -o /tmp/$ALPINE_VERSION-aarch64.tar.gz
	CHECK_ERROR $? minrootfs_retrieve
	curl -L --progress-bar $MINROOTFS_URL.sha256 -o /tmp/$ALPINE_VERSION-aarch64.tar.gz.sha256
	CHECK_ERROR $? minrootfs_retrieve_sha256

	## Validate signatures
	local origin_sha=$(cat /tmp/${ALPINE_VERSION}-aarch64.tar.gz.sha256 | awk '{print $1}')
	local local_sha=$(sha256sum /tmp/${ALPINE_VERSION}-aarch64.tar.gz | awk '{print $1}')

	printf '>>> Validating sha256 of files...' | tee -a ${logfile}
	if [[ "$origin_sha" != "$local_sha" ]]; then
		printf '\nORIGIN %s\n' "$origin_sha" | tee -a ${logfile}
		printf 'RESULT: %s\n' "$local_sha" | tee -a ${logfile}
		printf 'FAIL! SHA256 checksum did not match!\n' | tee -a ${logfile}
		exit 100
	else
		printf 'OK!\n' | tee -a ${logfile}
		## Provide evidence
		printf '=== ORIGIN SHA256: %s\n' "$origin_sha" | tee -a ${logfile}
		printf '=== LOCAL  SHA256: %s\n' "$local_sha" | tee -a ${logfile}
	fi

	## Verify GPG signature
	printf '>>> Validating signing key...' | tee -a ${logfile}
	local ORIGIN_KEY=https://alpinelinux.org/keys/ncopa.asc
	curl -L --silent $ORIGIN_KEY > /tmp/ncopa.asc
	CHECK_ERROR $? retrieve_signing_key
	gpg --import /tmp/ncopa.asc ; CHECK_ERROR $? gpg_import_ncopa | tee -a ${logfile}
	curl -L --silent $MINROOTFS_URL.asc > /tmp/${ALPINE_VERSION}-aarch64.tar.gz.asc
	gpg --verify /tmp/${ALPINE_VERSION}-aarch64.tar.gz.asc /tmp/${ALPINE_VERSION}-aarch64.tar.gz
	if [ $? -ne 0 ]; then
		printf '!!! SIGNATURE VERIFICATION FAILED!\n' 
		exit 100
	else
		printf 'GPG signatures OK\n' | tee -a ${logfile}
	fi
}

function rootfs_laydown()
{
	printf '>>> Extracting minirootfs to %s\n' "${CHROOT}" | tee -a ${logfile}
	tar -xzf /tmp/${ALPINE_VERSION}-aarch64.tar.gz -C ${CHROOT}
	CHECK_ERROR $? minrootfs_extract

	## Do vital bind mounts
	printf '>>> Performing vital bind mounts... '
	mount -o bind /proc ${CHROOT}/proc
	CHECK_ERROR $? minrootfs_bind_proc
	printf '/proc '
	mount -o bind /sys ${CHROOT}/sys
	CHECK_ERROR $? minrootfs_bind_sys
	printf '/sys '
	mount -o bind /dev ${CHROOT}/dev
	CHECK_ERROR $? minrootfs_bind_dev
	printf '/dev '
	printf '\n' 

	## We need to setup resolv.conf very early
	## XXX: quad9 is unavailable from Github Actions
	cp /etc/resolv.conf ${CHROOT}/etc/resolv.conf
	printf '>>> Setting up repositories in chroot... '
	if [ -f ${CHROOT}/etc/apk/repositories ]; then
		rm ${CHROOT}/etc/apk/repositories
	fi
	for x in main community; do
		printf 'http://dl-cdn.alpinelinux.org/alpine/v%s/%s\n' "$ALPINE_VERSION" "$x" >> ${CHROOT}/etc/apk/repositories
		printf '%s ' "$x"
	done
	printf '\n'
}

## Prepare the fstab for the actual booting image
function prep_fstab()
{
	if [ ! -z $BOOTUUID ]; then
		printf '>>> Boot UUID %s\n' "${BOOTUUID}"
	else
		printf '>>> Rediscovering boot UUID... '
		BOOTUUID=$(blkid -s UUID -o value ${BOOTDEV})
		printf '%s\n' "${BOOTUUID}"
	fi

	if [ ! -z $ROOTUUID ]; then
		printf '>>> Root UUID %s\n' "${ROOTUUID}"
	else
		printf '>>> Rediscovering root UUID... '
		ROOTUUID=$(blkid -s UUID -o value ${ROOTDEV})
		printf '%s\n' "${ROOTUUID}"
	fi

	## XXX: no arch unique stuff here.
	local fstab=${CHROOT}/etc/fstab
	echo "UUID=${ROOTUUID} / ext4 defaults 0 1" > $fstab
	echo "UUID=${BOOTUUID} /boot vfat defaults 0 2" >> $fstab
}