#!/bin/bash
# idleKernel for Samsung Galaxy Note 3 build script by jcadduono
# This build script is for Marshmallow Touchwiz ports only

################### BEFORE STARTING ################
#
# download a working toolchain and extract it somewhere and configure this file
# to point to the toolchain's root directory.
# I highly recommend Christopher83's Linaro GCC 4.9.x Cortex-A15 toolchain.
# Download it here: http://forum.xda-developers.com/showthread.php?t=2098133
#
# once you've set up the config section how you like it, you can simply run
# ./build.sh
# while inside the /idleKernel-note3/ directory.
#
###################### CONFIG ######################

# whick ramdisk do you want to use
RAMDISK_TYPE=$1

# second input parameter: build or only package
# build mode:(b = build and package boot.img, p = only package boot.img)
INPUT_MODE_PARAM=$2
[ -z $INPUT_MODE_PARAM ] && INPUT_MODE_PARAM=b

# the directory of selected ramdisk
RAMDISK_NAME=ramdisk/$RAMDISK_TYPE

# flash script of ramdisk
RAMDISK_ZIP=$RAMDISK_TYPE".zip"

# root directory of idleKernel git repo (default is this script's location)
RDIR=$(pwd)

# overlocking(0:normal;1:overlock)
OVERLOCK=0
if [ $OVERLOCK == "0" ]; then
 cp -rf $RDIR/overlock/normal/* $RDIR
fi

if [ $OVERLOCK == "1" ]; then
 cp -rf $RDIR/overlock/over/* $RDIR
fi

# device variant/carrier, possible options:
# Chinese variants:
#	ctc = N9009  (China Telecom)
# ONLY CTC WORKS FOR NOW
[ -z $VARIANT ] && VARIANT=ctc

SECFUNC_PRINT_HELP()
{
	echo -e '\E[33m'
	echo "The Usage Of The Script"
	echo "$0 \$1 \$2"
	echo "  \$1 : device variant/carrier, possible options"
	echo "      mysmooth"
	echo -e '\E[0m'
}

if [ "$RAMDISK_TYPE" == "" ]; then
	SECFUNC_PRINT_HELP;
	exit -1;
fi

# version number
[ -z $VER ] && VER=$(cat $RDIR/VERSION)

# kernel version string appended to 3.4.x-YuYiKernel-Lollipop-h3gduosctc-V0.1
# (shown in Settings -> About device)
KERNEL_VERSION=$VER

[ -z $PERMISSIVE ] && \
# should we boot with SELinux mode set to permissive? (1 = permissive, 0 = enforcing)
PERMISSIVE=1

[ $PERMISSIVE -eq 1 ] && SELINUX="never_enforce" || SELINUX="always_enforce"

# output directory of flashable kernel
OUT_DIR=$RDIR/ramdisk

# output filename of flashable kernel
OUT_NAME=$RAMDISK_TYPE-$KERNEL_VERSION
TEMP_OUT_NAME=$OUT_NAME

# should we make a TWRP flashable zip? (1 = yes, 0 = no)
MAKE_ZIP=1

# should we make an Odin flashable tar.md5? (1 = yes, 0 = no)
MAKE_TAR=0

# directory containing cross-compile arm-cortex_a15 toolchain
TOOLCHAIN=/opt/toolchains/arm-eabi-4.7

# amount of cpu threads to use in kernel make process
THREADS=4

############## SCARY NO-TOUCHY STUFF ###############

export ARCH=arm
export CROSS_COMPILE=$TOOLCHAIN/bin/arm-eabi-
export LOCALVERSION=-$KERNEL_VERSION

if ! [ -d $RDIR"/$RAMDISK_NAME/variant/$VARIANT/" ] ; then
	echo "Device variant/carrier $VARIANT not found in $RAMDISK_NAME/variant!"
	exit -1
fi

# kernel for system(0:SAMSUNG, 1:CM etc.)
KERNEL_TYPE=1
CMDLINE="console=null androidboot.hardware=qcom user_debug=31 msm_rtb.filter=0x3F ehci-hcd.park=3 androidboot.selinux=permissive"

if [ $KERNEL_TYPE == "1" ]; then
	sed -i -e 's/CONFIG_USB_ANDROID_SAMSUNG_MTP=y/# CONFIG_USB_ANDROID_SAMSUNG_MTP is not set/g' $RDIR"/arch/arm/configs/msm8974_sec_defconfig"
else
	CMDLINE="quiet console=null androidboot.selinux=permissive androidboot.hardware=qcom user_debug=23 msm_rtb.filter=0x37 ehci-hcd.park=3"
	sed -i -e 's/# CONFIG_USB_ANDROID_SAMSUNG_MTP is not set/CONFIG_USB_ANDROID_SAMSUNG_MTP=y/g'  $RDIR"/arch/arm/configs/msm8974_sec_defconfig"
fi

KDIR=$RDIR/build/arch/arm/boot

CLEAN_BUILD()
{
	echo "Cleaning build..."
	cd $RDIR
	rm -rf build
	echo "Removing old boot.img..."
	rm -f /$RAMDISK_NAME/$RAMDISK_ZIP/boot.img
	echo "Removing old zip/tar.md5 files..."
	find $OUT_DIR/ -name $TEMP_OUT_NAME"*.zip" -delete;
	find $OUT_DIR/ -name $TEMP_OUT_NAME"*.tar.md5" -delete;
}

CLEAN_FOR_PACKAGE()
{
	echo "Cleaning for package..."
	cd $RDIR
	echo "Removing old boot.img..."
	rm -f /$RAMDISK_NAME/$RAMDISK_ZIP/boot.img
	echo "Removing old zip/tar.md5 files..."
	find $OUT_DIR/ -name $TEMP_OUT_NAME"*.zip" -delete;
	find $OUT_DIR/ -name $TEMP_OUT_NAME"*.tar.md5" -delete;
}

BUILD_KERNEL()
{
	echo "Creating kernel config..."
	cd $RDIR
	mkdir -p build
	make -C $RDIR O=build msm8974_sec_defconfig \
		VARIANT_DEFCONFIG=msm8974_sec_h3g_chnctc_defconfig \
		SELINUX_DEFCONFIG=selinux_defconfig
	echo "Starting build..."
	make -C $RDIR O=build -j"$THREADS"
}

BUILD_RAMDISK()
{
	VARIANT=$VARIANT $RDIR/setup_ramdisk.sh $RAMDISK_NAME
	cd $RDIR/build/ramdisk
	echo "Building ramdisk.img..."
	find | fakeroot cpio -o -H newc | gzip -9 > $KDIR/ramdisk.cpio.gz
	cd $RDIR
}

BUILD_BOOT_IMG()
{
	echo "Generating boot.img..."
	$RDIR/scripts/mkqcdtbootimg/mkqcdtbootimg --kernel $KDIR/zImage \
		--ramdisk $KDIR/ramdisk.cpio.gz \
		--dt_dir $KDIR \
		--cmdline "$CMDLINE" \
		--base 0x00000000 \
		--pagesize 2048 \
		--ramdisk_offset 0x02900000 \
		--tags_offset 0x02700000 \
		--output $RDIR/$RAMDISK_NAME/$RAMDISK_ZIP/boot.img 
		echo -n "SEANDROIDENFORCE" >> $RDIR/$RAMDISK_NAME/$RAMDISK_ZIP/boot.img 
}

CURR_TIME=`date +%Y%m%d%I%M%S`
OUT_NAME=$OUT_NAME-$CURR_TIME

CREATE_ZIP()
{
	echo "Compressing to TWRP flashable zip file..."
	cd $RDIR/$RAMDISK_NAME/$RAMDISK_ZIP
	7z a -mx9 $OUT_DIR/$OUT_NAME.zip *
	zipinfo -t $OUT_DIR/$OUT_NAME.zip
	echo "Crypting zip file..."
	java -jar $RDIR/tools/crypt/ZipCenOp.jar e $OUT_DIR/$OUT_NAME.zip
	cd $RDIR
}

CREATE_TAR()
{
	echo "Compressing to Odin flashable tar.md5 file..."
	cd $RDIR/$RAMDISK_NAME/$RAMDISK_ZIP
	tar -H ustar -c boot.img > $OUT_DIR/$OUT_NAME.tar
	cd $OUT_DIR
	md5sum -t $OUT_NAME.tar >> $OUT_NAME.tar
	mv $OUT_NAME.tar $OUT_NAME.tar.md5
	cd $RDIR
}

DO_BUILD()
{
	echo "Starting build for $OUT_NAME, SELINUX = $SELINUX..."
	CLEAN_BUILD && BUILD_KERNEL && BUILD_RAMDISK && BUILD_BOOT_IMG || {
		echo "Error!"
		exit -1
	}
	if [ $MAKE_ZIP -eq 1 ]; then CREATE_ZIP; fi
	if [ $MAKE_TAR -eq 1 ]; then CREATE_TAR; fi
}

DO_PACKAGE()
{
	echo "Starting package for $OUT_NAME, SELINUX = $SELINUX..."
	CLEAN_FOR_PACKAGE && BUILD_RAMDISK && BUILD_BOOT_IMG || {
		echo "Error!"
		exit -1
	}
	if [ $MAKE_ZIP -eq 1 ]; then CREATE_ZIP; fi
	if [ $MAKE_TAR -eq 1 ]; then CREATE_TAR; fi
}

FUNC_USETIME() {
    let "OK_TIME=$END_TIME-$START_TIME"
    let "OK_TIME_1=$OK_TIME/60"
    let "OK_TIME_2=$OK_TIME%60"
    echo -e "\n\e[1;32mAll done in $OK_TIME_1 minutes $OK_TIME_2 seconds\e[0m"
}

FUNC_RUN() {
    START_TIME=`date +%s`
    if [ $INPUT_MODE_PARAM == "b" ]; then DO_BUILD; fi
	if [ $INPUT_MODE_PARAM == "p" ]; then DO_PACKAGE; fi
    END_TIME=`date +%s`
    FUNC_USETIME
}

FUNC_RUN
