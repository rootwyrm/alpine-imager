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
## Actual release train.
##

source /opt/rootwyrm/bin/stdlib.sh
source /etc/os-release

export IMAGE_NAME=$1
export IMAGE_ARCH=$2
export IMAGE_VERSION=$3
export IMAGE_FILE=$4
export CHROOT=${CHROOT:-/chroot}

export logfile=/image/${IMAGE_FILE}.log
if [ -f $logfile ]; then
	rm $logfile
fi

printf '################################################################################\n' | tee -a ${logfile}
printf 'Image creation starting at %s\n' "$(date)" | tee -a ${logfile}
printf ' Alpine %s for %s\n' "${IMAGE_VERSION}" "${IMAGE_ARCH}" | tee -a ${logfile}
printf '################################################################################\n' | tee -a ${logfile}

printf 'Setting up host environment...\n'
/opt/rootwyrm/bin/host_setup.sh
CHECK_ERROR $? "host_setup.sh"
/opt/rootwyrm/bin/virtual_disk.sh $IMAGE_FILE
CHECK_ERROR $? "virtual_disk.sh"
## Need to reimport these
export LOOPDEV=$(cat /tmp/loopdev)
export BOOTPART=${LOOPDEV}p1
export ROOTPART=${LOOPDEV}p2
## We need to do this out-of-line.
export BOOTUUID=$(blkid -s UUID -o value $BOOTPART)
export ROOTUUID=$(blkid -s UUID -o value $ROOTPART)
/opt/rootwyrm/bin/rootfs_laydown.sh
/opt/rootwyrm/bin/alpine_prep.sh

## XXX temporary cleanup portion
umount -f /chroot/proc/sys/fs/binfmt_misc
umount -f /chroot/proc
umount -f /chroot/sys
umount -f /chroot/boot
umount -f /chroot
losetup -d $LOOPDEV

printf '################################################################################\n' | tee -a ${logfile}
printf 'Image creation completed at %s!\n' "$(date)" | tee -a ${logfile}
printf ' /image/%s\n' "${IMAGE_FILE}" | tee -a ${logfile}
printf '################################################################################\n' | tee -a ${logfile}
