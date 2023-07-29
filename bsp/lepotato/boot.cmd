################################################################################
# WARNING: do not modify this file! It will be overwritten on upgrade!
# Changing values in this file incorrectly may result in hardware damage!
################################################################################

## Set addresses; per Libre, same as s805x
setenv fdtoverlay_addr_r "0x01000000"	# fdtoverlay_addr_r 16MB
setenv loadaddr_r "0x01000000"			# loadaddr 16MB
setenv splash_addr_r "0x01000000"		# splashimage 16MB
setenv fastboot_buf_addr "0x01000000"	# FASTBOOT_BUF_ADDR 16MB
setenv sys_load_addr "0x01000000"		# SYS_LOAD_ADDR 16MB
setenv text_base_r "0x01000000"			# TEXT_BASE 16MB
# XXX: pxefile_addr_r not usable; ethernet disabled by default
setenv pxefile_addr_r "0x01080000"		# pxefile_addr_r 16MB + 512K
setenv pre_con_buf_addr "0x08000000"	# PRE_CON_BUF_ADDR 128MB
# XXX: script shared with PRE_CON_BUF
setenv scriptaddr "0x08000000"			# scriptaddr 128MB
setenv fdt_addr_r "0x08008000"			# fdt_addr_r 128MB + 32K
setenv kernel_addr_r "0x08080000"		# kernel_addr_r 128MB + 512K
setenv initrd_addr_r "0x13000000"		# ramdisk_addr_r 256MB + 48MB = 304MB
setenv custom_init_sp_addr "0x20000000"	# CUSTOM_SYS_INIT_SP_ADDR 512MB

#Size
#0x00010000 ENV_SIZE 64K
#0x07000000 FASTBOOT_BUF_SIZE 128MB - 16MB = 112MB
#0x02000000 kernel_comp_size 32MB
#0x00008000 PRE_CON_BUF_SZ 32K
#0x01000000 STACK_SIZE 16MB
#0x08000000 SYS_BOOTM_LEN 128MB
#0x02000000 SYS_MALLOC 32MB
#0x00001000 SYS_MALLOC_F 4KB

setenv display_autodetect "true"
setenv maxcpus "4"
setenv hdmimode "1080p60hz"
setenv monitor_onoff "false"
setenv voutmode "hdmi"

setenv rootfstype "ext4"

echo "U-boot fdtfile: ${fdtfile}"

if test -e ${devtype} ${devnum} ${prefix}bootenv.txt; then
	load ${devtype} ${devnum} ${scriptaddr} ${prefix}bootenv.txt
	env import -t ${scriptaddr} ${filesize}
fi

## To make life easier, get our partuuids.
if test "${devtype}" = "mmc"; then
	part uuid mmc ${devnum}1 bootuuid
	part uuid mmc ${devnum}2 rootuuid
fi
## Get the partition UUID we loaded from, we need it later.
#if test "${devtype}" = "mmc"; then part uuid mmc ${devnum}:1 partuuid; fi
if test "${console}" = "display"; then setenv consoleargs "console=tty1"; fi

## We only use a 6.x+ kernel for Alpine
## NYI: console settings
## NYI: boot logo?

setenv consoleargs "splash=verbose ${consoleargs}"
setenv bootargs "root=${rootuuid} rootwait rootfstype=${rootfstype} ${consoleargs} consoleblank=0 coherent_pool=2M loglevel=${verbosity} ubootpart=${bootuuid} usb-storage.quirks=${usbstoragequirks} ${usbhidquirks} ${extraargs} ${extraboardargs}"
## Test if user plans to run docker
if test "${docker_host}" = "on"; then
	setenv bootargs "${bootargs} cgroup_enable=memory swapaccount=1"
fi

## Debug
echo "bootargs: ${bootargs}"

## Our kernel and file locations are fixed
load ${devtype} ${devnum} ${initrd_addr_r} ${prefix}initrd-lts
load ${devtype} ${devnum} ${kernel_addr_r} ${prefix}linux-lts
load ${devtype} ${devnum} ${fdt_addr_r} ${prefix}dtbs-lts/amlogic/meson-gxl-s905x-libretech-cc.dtb
fdt addr ${fdt_addr_r}
fdt resize 65536
## XXX: we don't have any overlays ourselves
for overlay_user in ${overlay_users}; do
	if load ${devtype} ${devnum} ${scriptaddr} ${prefix}overlay-user/${overlay_user}.dtbo; then
		echo "Applying user DT overlay ${overlay_user}.dtbo"
		fdt apply ${scriptaddr} || setenv overlay_error "true"
	fi
done

booti ${kernel_addr_r} ${ramdisk_addr_r} ${fdt_addr_r}
