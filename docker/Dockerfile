FROM	debian:stable-slim
## This is to speed up the image creation, since the initial steps can
## be quite slow.

LABEL	maintainer="Phil Jaenke"

VOLUME	[ "/run" ]

RUN	mkdir -p /opt/rootwyrm && \
	apt-get -q -y update && \
	apt-get -q -y upgrade > /dev/null 2>&1 ; \
	apt-get -q -y install apt-utils > /dev/null 2>&1 ; \
	apt-get -q -y --no-recommends install apt-utils udev curl gpg parted dosfstools xfsprogs qemu-user qemu-user-static wget