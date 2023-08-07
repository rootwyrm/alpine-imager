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
if [ ! -z $DEBUG ]; then
  set -x
fi
## This is the main script for the alpine-imager system. It relies on stubs
## which contain functions in order to handle numerous BSPs including those 
## that require custom compiles.

## Load standard library
. /opt/rootwyrm/bin/stdlib.sh

## Load dockerenv if present
if [ -f /.dockerenv ]; then
  . /.dockerenv
fi

printf '################################################################################\n'
printf '## Alpine Imager\n'
printf '## Commit %s\n' "$(git rev-parse HEAD)"
printf '################################################################################\n'

## Sanity check early
if [ -z $1 ]; then
  printf '!!! ALPINE_VERSION not provided!\n'
  exit 1
fi
## Platform here means BSP
if [ -z $2 ]; then
  printf '!!! ALPINE_PLATFORM not provided!\n'
  exit 1
fi
if [ -z $3 ]; then
  printf '!!! IMAGE_FILE not provided!\n'
  exit 1
fi
export ALPINE_VERSION=$1
export ALPINE_PLATFORM=$2
export IMAGE_FILE=$3

## Load function scripts
for x in $(ls /opt/rootwyrm/bin/func*); do
  printf '*** Loading %s\n' "$x"
  . $x
done

## Prepare the host
printf '>>> Preparing host... '
for x in $(cat /opt/rootwyrm/conf/host/alpine.3.18.pkg); do
  printf '%s ' $x
  apk add -q --no-cache $x
  CHECK_ERROR $? "host_prepare $x"
done

export CHROOT=/chroot
## Load the BSP configuration
bsp_load
virtual_disk_create
virtual_disk_filesystem
rootfs_retrieve
rootfs_laydown
prep_fstab
software_prep_bootable
software_prep_base
software_prep_cloudinit
software_prep_openrc

