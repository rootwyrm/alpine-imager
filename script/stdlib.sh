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

[ -f /.dockerenv ]; . /.dockerenv
. /etc/os-release

function CHECK_ERROR()
{
	if [ -z $1 ]; then
		printf "Hit CHECK_ERROR erroneously?"
		exit 1
	fi
	if [[ $1 -ne 0 ]]; then
		set -e
		printf '[ERROR] %s\n' "$2"
		#cleanup
		exit $1
	fi
}

## ARGS: configfile (full path)
function CHECK_CONFIG_EXISTS()
{
	if [ -z $1 ] || [ ! -f $1 ]; then
		printf 'Configuration file %s not found or specified!\n' "$1"
		exit 1
	fi
}

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|,$s\]$s\$|]|" \
        -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
        -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" $1 | \
   sed -ne "s|,$s}$s\$|}|" \
        -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
        -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
      if(length($2)== 0){  vname[indent]= ++idx[indent] };
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, vname[indent], $3);
      }
   }'
}

## Interpret latest-releases.yaml and export variables
function latest-releases() {
	if [ -z $1 ]; then
		if [ -z $ALPINE_RELEASE ]; then
			printf 'No release provided!\n'
			exit 1
		fi
	fi

	MAJOR=$1
	curl -L --progress-bar https://dl-cdn.alpinelinux.org/alpine/v${MAJOR}/releases/aarch64/latest-releases.yaml -o latest-releases.yaml

	## Assume order changes so we have to parse out minrootfs
	minrootprefix=$(parse_yaml latest-releases.yaml | grep flavor | grep "alpine-minirootfs" | cut -d _ -f 1)
	
	## Load variables
	parse_yaml latest-releases.yaml | grep ^${minrootprefix} | sed -e 's/^'${minrootprefix}'_//g' > /tmp/env

	export ALPINE_VERSION=$(grep ^version /tmp/env | cut -d = -f 2 | sed -e 's/"//g')
	export ALPINE_FILE=$(grep ^file /tmp/env | cut -d = -f 2 | sed -e 's/"//g')
	export ALPINE_SHA256=$(grep ^sha256 /tmp/env | cut -d = -f 2 | sed -e 's/"//g')
	export ALPINE_SHA512=$(grep ^sha512 /tmp/env | cut -d = -f 2 | sed -e 's/"//g')
}
