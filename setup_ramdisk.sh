#!/bin/bash
# idleKernel for Samsung Galaxy Note 3 ramdisk setup script by jcadduono
# This script is for Note 5 Touchwiz ports only

# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

[ -z $VARIANT ] && \
# device variant/carrier, possible options:
# Chinese variants:
#	ctc = N9009  (China Telecom)
VARIANT=ctc

RAMDISK_NAME=$1

############## SCARY NO-TOUCHY STUFF ###############

if ! [ -d $RDIR"/$RAMDISK_NAME/variant/$VARIANT/" ] ; then
	echo "Device variant/carrier $VARIANT not found in $RAMDISK_NAME/variant!"
	exit -1
fi

CLEAN_RAMDISK()
{
	[ -d $RDIR/build/ramdisk ] && {
		echo "Removing old ramdisk..."
		rm -rf $RDIR/build/ramdisk
	}
}

SET_PERMISSIONS()
{
	echo "Setting ramdisk file permissions..."
	cd $RDIR/build/ramdisk
	# set all directories to 0755 by default
	find -type d -exec chmod 0755 {} \;
	# set all files to 0644 by default
	find -type f -exec chmod 0644 {} \;
	# scripts should be 0750
	find -name "*.rc" -exec chmod 0750 {} \;
	find -name "*.sh" -exec chmod 0750 {} \;
	# init and everything in /sbin should be 0750
	chmod -Rf 0750 init sbin
	chmod 0771 carrier data
}

SETUP_RAMDISK()
{
	echo "Building ramdisk structure..."
	cd $RDIR
	mkdir -p build/ramdisk
	cp -fr $RAMDISK_NAME/common/* build/ramdisk
	cp -fr $RAMDISK_NAME/variant/$VARIANT/* build/ramdisk
	cd $RDIR/build/ramdisk
	mkdir -p dev proc sys system kmod carrier data oem 
	echo "Copying kernel modules to ramdisk..."
	find $RDIR/build -name *.ko -not -path */ramdisk/* -exec cp {} kmod \;
}

CLEAN_RAMDISK
SETUP_RAMDISK
SET_PERMISSIONS

echo "Done setting up ramdisk."