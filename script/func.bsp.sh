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

# This function set is for board support packages

## Load the BSP configuration
function bsp_load()
{
  if [ -d /opt/rootwyrm/conf/bsp/${ALPINE_PLATFORM} ]; then
    printf '>>> Building BSP %s\n' "${ALPINE_PLATFORM}" 
    ## Load board configuration
    if [ -f /opt/rootwyrm/conf/bsp/${ALPINE_PLATFORM}/board.conf ]; then
      printf '>>> Loading BSP configuration for %s\n' "${ALPINE_PLATFORM}"
      . /opt/rootwyrm/conf/bsp/${ALPINE_PLATFORM}/board.conf
      if [ ! -z $DEBUG ]; then
        cat /opt/rootwyrm/conf/bsp/${ALPINE_PLATFORM}/board.conf
      fi
    fi
  else
    printf '>>> ERROR: BSP %s not found!\n' "${ALPINE_PLATFORM}" 
    exit 255
  fi
}

function bsp_uboot()
{
  ## uboot is a bit of a pain
  if [ -z $UBOOT_URL ]; then
    ## Retrieve the requested u-boot URL
    printf '>>> Retrieving u-boot image file from %s\n' "${UBOOT_URL}" | tee -a ${logfile}
    curl -o u-boot.bin $UBOOT_URL
    if [ $? -ne 0 ]; then
      printf '>>> ERROR: Failed to retrieve u-boot image file!\n' | tee -a ${logfile}
      exit 255
    fi
  fi

  if [ -f /opt/rootwyrm/conf/bsp/${IMAGE_BSP}/u-boot.sh ]; then
    /opt/rootwyrm/conf/bsp/${IMAGE_BSP}/u-boot.sh
    if [ $? -ne 0 ]; then
      printf '>>> ERROR: u-boot.sh failed for %s!\n' "${ALPINE_PLATFORM}" | tee -a ${logfile}
      exit 255
    else
      printf '>>> ERROR: u-boot.sh not found for %s!\n' "${ALPINE_PLATFORM}" | tee -a ${logfile}
      exit 255
    fi
  fi
}