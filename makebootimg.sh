#!/bin/bash
# YuYiKernel for Samsung Galaxy Note 3 build script by bo1318
# This build script is for Marshmallow


# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

# build or package
FLAG=true

for V in `ls $RDIR/ramdisk/`
do
	if [ -d $RDIR/ramdisk/$V ] ; then
	    if [ $FLAG == true ] ; then
	        sh $RDIR/build.sh $V
	        FLAG=false
	    else
	        sh $RDIR/build.sh $V p
	    fi
	fi
done;

for ZIP in `find $RDIR/ramdisk/ -type f -name "*.zip"`
do
	java -jar $RDIR/tools/crypt/ZipCenOp.jar e $ZIP
done;
