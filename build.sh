#!/usr/bin/env bash

WORKDIR="$(pwd)"

# Clang
CLANG_DLINK="https://github.com/ZyCromerZ/Clang/releases/download/19.0.0git-20240429-release/Clang-19.0.0git-20240429.tar.gz"
CLANG_DIR="$WORKDIR/Clang/bin"

# Kernel Source
KERNEL_NAME="XKernel"
KERNEL_GIT="https://github.com/XeroMz69/Fire-Kernel-Tree.git"
KERNEL_BRANCH="main"
KERNEL_DIR="$WORKDIR/$KERNEL_NAME"

# Anykernel3
ANYKERNEL3_GIT="https://github.com/osm0sis/AnyKernel3.git"
ANYKERNEL3_BRANCH="main"

# Magiskboot
MAGISKBOOT_DLINK="https://github.com/xiaoxindada/magiskboot_ndk_on_linux/releases/download/Magiskboot-27001-63/magiskboot.7z"
MAGISKBOOT="$WORKDIR/magiskboot/magiskboot"
ORIGIN_BOOTIMG_DLINK="https://github.com/Jiovanni-dump/redmi_earth_dump/blob/missi_phone_global-user-13-TP1A.220624.014-V14.0.4.0.TCVMIXM-release-keys/boot.img"

# Build
DEVICE_CODENAME="fire"
DEVICE_DEFCONFIG="fire_defconfig"
DEVICE_DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$DEVICE_DEFCONFIG"

IMAGE_GZ="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"
IMAGE_GZ_DTB="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/mediatek/mt6768.dtb"
DTBO_EARTH="$KERNEL_DIR/out/arch/arm64/boot/dts/mediatek/earth.dtbo"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"

MAKE_BOOTIMG="false"
PERMISSIVE_BOOTIMG="false"

export KBUILD_BUILD_USER="Xero"
export KBUILD_BUILD_HOST="AYD"

cd $WORKDIR

# Download Clang
echo "Work on $WORKDIR"
echo "Cloning Toolchain $CLANG_DLINK"

mkdir -p Clang
aria2c -s16 -x16 -k1M $CLANG_DLINK -o Clang.tar.gz
tar -C Clang/ -zxvf Clang.tar.gz
rm -rf Clang.tar.gz

# CLANG LLVM Versions
CLANG_VERSION="$($CLANG_DIR/clang --version | head -n 1)"
LLD_VERSION="$($CLANG_DIR/ld.lld --version | head -n 1)"

echo "Cloning Kernel Source "
git clone --depth=1 $KERNEL_GIT -b $KERNEL_BRANCH $KERNEL_DIR
cd $KERNEL_DIR
KERNEL_HEAD_HASH=$(git log --pretty=format:'%H' -1)

# Patching the KernelSU
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
echo "
CONFIG_KPROBES=y
CONFIG_HAVE_KPROBES=y
CONFIG_KPROBE_EVENTS=y
" >> $DEVICES_DEFCONFIG

# Build Kernel
echo "Started Compilation"

mkdir -p $WORKDIR/out

args="PATH=$CLANG_DIR:$PATH \
ARCH=arm64 \
SUBARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
CC=clang \
NM=llvm-nm \
CXX=clang++ \
AR=llvm-ar \
LD=ld.lld \
STRIP=llvm-strip \
OBJCOPY=llvm-objcopy \
OBJDUMP=llvm-objdump \
OBJSIZE=llvm-size \
READELF=llvm-readelf \
HOSTAR=llvm-ar \
HOSTLD=ld.lld \
HOSTCC=clang \
HOSTCXX=clang++ \
LLVM=1 \
LTO=full"


# LINUX KERNEL VERSION
rm -rf out
make O=out $args $DEVICE_DEFCONFIG
make clean
make mrproper
KERNEL_VERSION=$(make O=out $args kernelversion | grep "4.19")
echo "LINUX KERNEL VERSION : $KERNEL_VERSION"
make O=out $args -j"$(nproc --all)" | tee "$WORKDIR/out/build.log"

echo "Checking builds"
if [ ! -e $IMAGE_GZ_DTB ]; then
    echo -e "Build Failed!"
    exit 1
fi

cp $IMAGE_GZ $WORKDIR/out
cp $IMAGE_GZ_DTB $WORKDIR/out
cp $DTBO $WORKDIR/out
cp $DTBO_EARTH $WORKDIR/out
cp $DTB $WORKDIR/out

# Make boot.img
if [ $MAKE_BOOTIMG = "true" ]; then
    # Setup magiskboot
    cd $WORKDIR && mkdir magiskboot
    aria2c -s16 -x16 -k1M $MAGISKBOOT_DLINK -o magiskboot.7z
    7z e magiskboot.7z out/x86_64/magiskboot -omagiskboot/
    rm -rf magiskboot.7z

    # Download original boot.img
    aria2c -s16 -x16 -k1M $ORIGIN_BOOTIMG_DLINK -o magiskboot/boot.img
    cd $WORKDIR/magiskboot

    # Packing
    $MAGISKBOOT unpack -h boot.img
    cp $IMAGE ./Image.gz-dtb
    $MAGISKBOOT split Image.gz-dtb
    cp $DTB ./dtb
    $MAGISKBOOT repack boot.img
    mv new-boot.img $WORKDIR/out/$ZIP_NAME.img

    # SElinux Permissive
    if [ $PERMISSIVE_BOOTIMG = "true" ]; then
        sed -i '/cmdline=/ s/$/ androidboot.selinux=permissive/' header
        $MAGISKBOOT repack boot.img
        mv new-boot.img $WORKDIR/out/$ZIP_NAME-Permissive.img
    fi
fi

cd $WORKDIR/out

echo "Done!"
