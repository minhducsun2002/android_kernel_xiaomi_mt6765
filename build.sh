#!/usr/bin/env bash
ENVFILE=build-linaro-7.5.env;

source $ENVFILE;

JOBS=$(nproc --all); # used in make -jN

error() {
    echo -e "\033[0;31m==>\033[0m ERROR: $@" >&2;
}

warning() {
    echo -e "\033[0;36m==>\033[0m $@" >&2;
}

info() {
    echo -e "\033[0;32m==>\033[0m $@";
}

debug() {
    if [[ ! $DEBUG -eq 0 ]]; then
        echo -e "\033[0;34m==>\033[0m $@" >&2;
    fi
}

is_sourced() {
    if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
        return 1;
    else
        return 0;
    fi
}

export ARCH=$KERNEL_ARCH;

if ! is_sourced; then
    [[ -z "${DEVICE+x}" ]] && { error "You should set DEVICE variable in the $ENVFILE"; exit 1; }
    [[ -z "${KERNEL_DEFCONFIG+x}" ]] && { error "You should set KERNEL_DEFCONFIG variable in the $ENVFILE"; exit 1; }
    # [[ -z "${ANYKERNEL_DIR+x}" ]] && { error "You should set ANYKERNEL_DIR variable in the $ENVFILE"; exit 1; }
    [[ -z "${CROSS_COMPILE+x}" ]] && { error "You should set CROSS_COMPILE variable in the $ENVFILE"; exit 1; }

    [[ -z "${DEBUG+x}" ]] && export DEBUG=0;
    [[ -z "${KERNEL+x}" ]] && export KERNEL=$(dirname $(realpath "$0"));
    [[ -z "${KERNEL_ARCH+x}" ]] && {
        for arch in arm64 arm; do
            if [[ -d "$KERNEL"/arch/"$arch"/configs/"$KERNEL_DEFCONFIG" ]]; then
                export KERNEL_ARCH="$arch";
            fi
        done
    }

    [[ -z "${KERNEL_ARCH+x}" ]] && export KERNEL_ARCH=arm;
    [[ -z "${KERNEL_IMAGE+x}" ]] && export KERNEL_IMAGE=zImage-dtb;
    [[ -z "${KERNEL_OUTPUT+x}" ]] && export KERNEL_OUTPUT=$KERNEL/out;
    [[ -z "${RUN_MENUCONFIG+x}" ]] && export RUN_MENUCONFIG=0;
    [[ -z "${PACK_MODULES+x}" ]] && export PACK_MODULES=0;
    [[ -z "${MODULES_DIR+x}" ]] && export MODULES_DIR=vendor/lib/modules;
    [[ -z "${DO_MODULES_STRIP+x}" ]] && export DO_MODULES_STRIP=1;

    local DEFCONFIG="$KERNEL"/arch/"$KERNEL_ARCH"/configs/"$KERNEL_DEFCONFIG";
    if [[ ! -f $DEFCONFIG ]]; then
        error "Config \"$KERNEL_DEFCONFIG\" doesn't exists! ($DEFCONFIG)";
        error "      (Wrong KERNEL_ARCH? [$KERNEL_ARCH])";
        error "      (Wrong path to kernel? [$KERNEL])";
        error "      (Wrong defconfig? [$KERNEL_DEFCONFIG])";
        exit 2;
    fi

    if [[ ! -f ${CROSS_COMPILE}as ]]; then
        error "Check your CROSS_COMPILE variable in the $ENVFILE";
        exit 3;
    fi

fi

cleanup() {
    if [[ -d $KERNEL_OUTPUT ]]; then
        make O=$KERNEL_OUTPUT mrproper;
    fi
}

prepare() {
    info "Prepare environment before compilation...";

    cleanup;

    make O=$KERNEL_OUTPUT $KERNEL_DEFCONFIG;

    if [[ ! $RUN_MENUCONFIG -eq 0 ]]; then
        make O=$KERNEL_OUTPUT menuconfig;
    fi
}

prepare_modules() {
    info "Prepare environment for Linux modules...";

    cleanup;

    make O=$KERNEL_OUTPUT $KERNEL_DEFCONFIG;
    make O=$KERNEL_OUTPUT scripts prepare modules_prepare;
}

build() {
    info "Build kernel...";

    local START_TIME=$(date +%s);
    make O=$KERNEL_OUTPUT -j$JOBS;
    local END_TIME=$(date +%s);

    local DIFF_TIME=$(( $END_TIME - $START_TIME ));

    local TIME="00s";

    if [[ ( $DIFF_TIME < 3600 ) ]]; then
        TIME=$(date +'%Mm %Ss' --date @$DIFF_TIME --utc);
    else
        TIME=$(date +'%Hh %Mm %Ss' --date @$DIFF_TIME --utc);
    fi

    info "Compilation finished in the $TIME";
}

package() {
    IMAGE="$KERNEL_OUTPUT"/arch/"$KERNEL_ARCH"/boot/"$KERNEL_IMAGE";
    if [[ ! -f $IMAGE ]]; then
        error "Kernel image doesn't exists! ($IMAGE)";
        exit 4;
    fi

    if [[ -d $ANYKERNEL_DIR ]]; then
        info "AnyKernel3 found at $ANYKERNEL_DIR";

        local ARCHIVE=AnyKernel3-"$DEVICE"-$(date +'%d_%m_%Y-%H_%M_%S').zip;
        if [[ -z "$ARCHIVE_FORMAT" ]]; then
            ARCHIVE=$ARCHIVE_FORMAT;
        fi

        cp $IMAGE $ANYKERNEL_DIR/;

        if [[ -d $ANYKERNEL_DIR/modules ]]; then
            rm -rf $ANYKERNEL_DIR/modules;
        fi

        mkdir -p $ANYKERNEL_DIR/modules/$MODULES_DIR;
        touch $ANYKERNEL_DIR/modules/$MODULES_DIR/placeholder;

        if [[ ! $PACK_MODULES -eq 0 ]]; then
            find $KERNEL_OUTPUT/ -name "*.ko" -exec cp '{}' $ANYKERNEL_DIR/modules/$MODULES_DIR \;

            if [[ ! $DO_MODULES_STRIP -eq 0 ]]; then
                find $ANYKERNEL_DIR/modules -name "*.ko" -exec ${CROSS_COMPILE}strip --strip-unneeded '{}' \;
            fi
        fi

        local old_pwd=$PWD;
        cd $ANYKERNEL_DIR;
        zip -r $ARCHIVE META-INF/ modules/ tools/ LICENSE anykernel.sh $KERNEL_IMAGE;
        cp $ARCHIVE $KERNEL/;
        rm -rf modules/ $KERNEL_IMAGE;
        cd $old_pwd;

        info "$ARCHIVE saved to $KERNEL/$ARCHIVE";
    fi
}


if ! is_sourced; then

for dir in arch block crypto Documentation drivers firmware fs include init ipc kernel lib mm net scripts security sound tools usr virt Kbuild Kconfig Makefile; do
    if [[ ! -d "$KERNEL"/"$dir" && ! -f "$KERNEL"/"$dir" ]]; then
        error "Script $0 must be places in the root of kernel source.";
        exit 5;
    fi
done

usage() {
    echo "";
    echo "$0 - simple script to build Linux kernel";
    echo "";
    echo "Usage: $0 [cleanup|prepare|prepare_modules|build|package|help]";
    echo "       cleanup - do \`make mrproper\` in the kernel root"
    echo "       prepare - build defconfig and call menuconfig, if RUN_MENUCONFIG=1";
    echo "       prepare_modules - prepare for building kernel modules";
    echo "       build - build kernel";
    echo "       package - pack kernel to .zip";
    echo "       help - print this message";
    echo "If no one command specified, then run \"prepare\", \"build\" and \"package\"";
    echo "";
    exit 0;
}

case "$1" in
    cleanup)
        info "Cleanup...";
        cleanup;
        ;;
    prepare)
        prepare;
        ;;
    prepare_modules)
        prepare_modules;
        ;;
    build)
        build;
        ;;
    package)
        package;
        ;;
    "")
        prepare;
        build;
        package;
        ;;
    usage|help|-h|--help)
        usage;
        ;;
    *)
        echo "";
        error "Unknown command: $1";
        usage;
        ;;
esac

info "Done!";

fi
