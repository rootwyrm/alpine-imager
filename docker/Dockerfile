FROM	ubuntu:18.04
## This is to speed up the image creation, since the initial steps can
## be quite slow.

LABEL	maintainer="Phil Jaenke"

VOLUME	[ "/run" ]

RUN	mkdir -p /opt/rootwyrm && \
	apt-get -q -y update && \
	apt-get -q -y upgrade > /dev/null 2>&1 ; \
	apt-get -q -y install apt-utils > /dev/null 2>&1 ; \
	apt-get -q -y install udev curl gpg parted dosfstools xfsprogs qemu-user qemu-user-static > /dev/null 2>&1 ; \
	apt-get -q -y install gcc ubuntu-dev-tools > /dev/null 2>&1
