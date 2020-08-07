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
## Set up the host or docker
##

set -e

. /opt/rootwyrm/bin/stdlib.sh
. /etc/os-release
if [ -f /.dockerenv ]; then
	export CONTAINER=1
	. /.dockerenv
fi

function host_packages() {
	echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
	apt-get -q -y update > /dev/null
	apt-get -q -y upgrade > /dev/null
	apt-get -q -y install apt-utils > /dev/null
	if [ ! -f /opt/rootwyrm/conf/host_${ID}.pkg ]; then
		printf 'Missing host package configuration host_%s.pkg\n' "${ID}"
		exit 255
	else
		printf 'Installing packages... ' | tee -a $logfile
		for p in `cat /opt/rootwyrm/conf/host_${ID}.pkg | grep -v ^#`; do
			printf '%s ' "$p" | tee -a $logfile
			apt-get install -y -q $p > /dev/null
			CHECK_ERROR $? "apt-get install $p" | tee -a $logfile
		done
		printf '\n' | tee -a $logfile
	fi
}

## Perform any necessary configuration steps

printf '*** Entering host_setup...\n' | tee -a ${logfile}

host_packages

printf '*** Exiting host_setup...\n' | tee -a ${logfile}
