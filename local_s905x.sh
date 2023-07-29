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
## Actually build our images
## 

set -e

#if [ -z ${GITHUB_WORKSPACE} ]; then
#	printf 'No idea how to continue here.\n'
#	exit 1
#fi
if [ -z ${HOME} ]; then
	printf 'No idea how to continue locally.\n'
	exit 1
fi
export GITHUB_WORKSPACE=$HOME/alpine-imager

#if [ -z $1 ]; then
#	printf 'Did not provide a configuration file?\n'
#	exit 1
#fi
#. $1

DEV_VOLUME=/dev
RUN_VOLUME=/tmp/run
IMAGE_VOLUME=${HOME}/image
ARTIFACT_DIR=${HOME}/artifact
if [ ! -d $IMAGE_VOLUME ]; then
	mkdir $IMAGE_VOLUME
fi
if [ ! -d $ARTIFACT_DIR ]; then
	mkdir $ARTIFACT_DIR
fi


#docker image inspect image_builder > /dev/null
#if [ $? -ne 0 ]; then
#	docker build . -t image_builder
#fi

if [ -z $1 ]; then
	BUILDVER="3.17"
else
	BUILDVER=$1
fi
if [ -z $2 ]; then
	BUILDPLAT="s905x"
else
	BUILDPLAT=$2
fi

sudo rm -rf $HOME/image/*img
sudo rm -rf $HOME/image/*log
docker run --rm \
	--platform linux/arm64/v8 \
	--volume /dev:/dev \
	--tmpfs /run \
	--volume $IMAGE_VOLUME:/image \
	--volume ${GITHUB_WORKSPACE}/script:/opt/rootwyrm/bin \
	--volume ${GITHUB_WORKSPACE}/conf:/opt/rootwyrm/conf \
	--volume ${GITHUB_WORKSPACE}/extern:/opt/rootwyrm/extern \
	--privileged --cap-add=ALL \
	alpine:3.18 \
	/opt/rootwyrm/bin/uboot_run.sh $BUILDVER $BUILDPLAT
#docker run --rm \
#	--volume /dev:/dev \
#	--tmpfs /run \
#	--volume $IMAGE_VOLUME:/image \
#	--volume ${GITHUB_WORKSPACE}/script:/opt/rootwyrm/bin \
#	--volume ${GITHUB_WORKSPACE}/conf:/opt/rootwyrm/conf \
#	--volume ${GITHUB_WORKSPACE}/extern:/opt/rootwyrm/extern \
#	--privileged --cap-add=ALL \
#	debian:stable-slim \
#	/opt/rootwyrm/bin/rpi_imager.sh alpine-rpi4 aarch64 3.17.3 rpi4
