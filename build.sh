#!/usr/bin/env bash

DEVICE=cactus
JOBS=$(nproc --all) # make -j$JOBS
RUN_MENUCONFIG=0
KERNEL_DEFCONFIG=cactus_defconfig


ANYKERNEL_DIR=${HOME}/xiaomi-mt6765/AnyKernel3-cactus
CROSS_COMPILE=${HOME}/xiaomi-mt6765/gcc-linaro-7.5.0-2019.12-x86_64_arm-linux-gnueabihf/bin/arm-linux-gnueabihf-
KERNEL=$(dirname $(realpath "$0"))
KERNEL_ARCH=arm
KERNEL_IMAGE=zImage-dtb
KERNEL_OUTPUT=${KERNEL}/out

error() {
    echo -e "\033[0;31m==>\033[0m ERROR: $1";
}

warning() {
    echo -e "\033[0;36m==>\033[0m $1";
}

info() {
    echo -e "\033[0;32m==>\033[0m $1";
}

export ARCH=$KERNEL_ARCH;
export CROSS_COMPILE;

TIME='00s';

DEFCONFIG="$KERNEL"/arch/"$KERNEL_ARCH"/configs/"$KERNEL_DEFCONFIG";
if [[ ! -f $DEFCONFIG ]]; then
    error "Config $KERNEL_DEFCONFIG doesn't exists! ($DEFCONFIG)";
    exit 1;
fi

if [[ ! -f ${CROSS_COMPILE}as ]]; then
    error "Check your CROSS_COMPILE variable at the top of $0";
    exit 2;
fi

prepare() {
    info "Prepare environment before compilation...";

    if [[ -d $KERNEL_OUTPUT ]]; then
        make O=$KERNEL_OUTPUT mrproper;
    else
        mkdir $KERNEL_OUTPUT;
    fi

    make O=$KERNEL_OUTPUT $KERNEL_DEFCONFIG;

    if [[ ! $RUN_MENUCONFIG -eq 0 ]]; then
        make O=$KERNEL_OUTPUT menuconfig;
    fi
}

build() {
    info "Build kernel...";

    START_TIME=$(date +%s);
    make O=$KERNEL_OUTPUT -j$JOBS;
    END_TIME=$(date +%s);

    DIFF_TIME=$(($END_TIME - $START_TIME));

    if [[ ( $DIFF_TIME < 60 ) ]]; then
        TIME=$(date +'%Ss' --date @$DIFF_TIME --utc);
    elif [[ ( $DIFF_TIME < 3600 ) ]]; then
        TIME=$(date +'%Mm %Ss' --date @$DIFF_TIME --utc);
    else
        TIME=$(date +'%Hh %Mm %Ss' --date @$DIFF_TIME --utc);
    fi
}

package() {
    info "Compilation finished in the $TIME";

    IMAGE="$KERNEL_OUTPUT"/arch/"$KERNEL_ARCH"/boot/"$KERNEL_IMAGE";
    if [[ ! -f $IMAGE ]]; then
        error "Kernel image doesn't exists! ($IMAGE)";
        exit 3;
    fi

    if [[ -d $ANYKERNEL_DIR ]]; then
        info "AnyKernel3 found at $ANYKERNEL_DIR";

        ARCHIVE=AnyKernel3-"$DEVICE"-$(date +'%d_%m_%Y-%H_%M_%S').zip;

        cp $IMAGE $ANYKERNEL_DIR/;

        if [[ -d $ANYKERNEL_DIR/modules ]]; then
            rm -rf $ANYKERNEL_DIR/modules;
        fi

        mkdir -p $ANYKERNEL_DIR/modules/vendor/system/lib/modules;

        find $KERNEL_OUTPUT/ -name "*.ko" -exec ${CROSS_COMPILE}strip --strip-unneeded '{}' \;
        find $KERNEL_OUTPUT/ -name "*.ko" -exec cp '{}' $ANYKERNEL_DIR/modules/vendor/system/lib/modules;

        _PWD=$PWD;
        cd $ANYKERNEL_DIR;
        zip -r $ARCHIVE META-INF/ modules/ tools/ LICENSE anykernel.sh $KERNEL_IMAGE;
        cp $ARCHIVE $KERNEL/;
        rm -rf modules/ $KERNEL_IMAGE;
        cd $_PWD;

        info "$ARCHIVE saved to $KERNEL/$ARCHIVE"; 
    fi

    info "Done!";
}

prepare;
build;
package;
