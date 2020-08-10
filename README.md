# alpine-imager
Alpine Linux images for Raspberry Pi, VMware, Xen, and other systems

# How to Use
* Grab the appropriate image from releases. This uses a rolling release model.
* Write the image to your media using your favorite tool.
* Boot right into a ready to use and fully upgradeable system (it even resizes the root filesystem.)

# First Time Login
ssh is enabled by default for non-root users. The default non-root user is `alpi` and the password is `Linux!${MAJOR_VERSION}`; so for 3.11.6 it would be `Linux!311`. The `alpi` user is already installed in the `sudoers` file as well.

The default root password is always `Alp!n3` - you should change it as soon as you log in.

# I Want To Build Them Myself
Well have at it - this repo is licensed under the BSD 3-Clause. You're free and welcome to do so. Note that you'll need a very specifically configured Ubuntu 18.04 or later system, which will also need further specific tweaks. 

# Why do this?
Because I use Alpine on some of my Raspberry Pi4s and taking an hour to manually install it to disk with the insistence that it's "not actually supported" is not only obnoxious, but absolutely and utterly stupid.

# Caveats
* BSPs are by request because I generally don't any to test with. If you need a BSP image, please open an issue with the details of the BSP (a link to the vendor's support page or tech specs page is best.) Once a BSP is officially added, it will be continuously built.
* Images for the Ampere eMAG / Lenovo HR330A/HR350A are missing due to lack of a test system. If you want to test, please reach out directly.
* Support for UEFI RPi is _extremely_ experimental, which is to say, it's not even in the public version. (This is for _your_ sanity as much as mine. The UEFI component itself is alpha.)

