# alpine-imager
Alpine Linux images for Raspberry Pi, VMware, Xen, and other systems

# How to Use
* Grab the appropriate image from releases. 
* Write the image to your media using your favorite tool.
* Boot right into a ready to use system; no `setup-alpine` or torturous error-prone manual process required.

# First Time Login
The default non-root user is `alpi` and the password is `Alpi!`MAJOR-RELEASE. So for '3.12.3 it would be `Alpi!312`. root login is disabled by default.

# I Want To Build Them Myself
Well have at it - this repo is licensed under the BSD 3-Clause. You're free and welcome to do so. Note that you'll need a very specifically configured Ubuntu 18.04 or later system, which will also need further specific tweaks. 

# Why do this?
Because I use Alpine on some of my Raspberry Pi4s and taking an hour to manually install it to disk with the insistence that it's "not actually supported" is not only obnoxious, but absolutely and utterly stupid.
