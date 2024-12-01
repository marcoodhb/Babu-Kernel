#!/usr/bin/env bash

WORKDIR="$(pwd)"

# Clang
CLANG_DLINK="https://github.com/ZyCromerZ/Clang/releases/download/19.0.0git-20240429-release/Clang-19.0.0git-20240429.tar.gz"
CLANG_DIR="$WORKDIR/Clang/bin"

# Kernel Source
KERNEL_NAME="SigmaKernel"
KERNEL_GIT="https://github.com/XeroMz69/Bumi-Kernel-Tree.git"
KERNEL_BRANCH="ksu"
KERNEL_DIR="$WORKDIR/$KERNEL_NAME"

# Anykernel3
ANYKERNEL3_GIT="https://github.com/osm0sis/AnyKernel3.git"
ANYKERNEL3_BRANCH="main"

# Magiskboot
MAGISKBOOT_DLINK="https://github.com/xiaoxindada/magiskboot_ndk_on_linux/releases/download/Magiskboot-27001-63/magiskboot.7z"
MAGISKBOOT="$WORKDIR/magiskboot/magiskboot"
ORIGIN_BOOTIMG_DLINK="https://github.com/Jiovanni-dump/redmi_earth_dump/blob/missi_phone_global-user-13-TP1A.220624.014-V14.0.4.0.TCVMIXM-release-keys/boot.img"

# Build
DEVICE_CODENAME="earth"
DEVICE_DEFCONFIG="earth_defconfig"
DEVICE_DEFCONFIG_FILE="$KERNEL_DIR/arch/arm64/configs/$DEVICE_DEFCONFIG"

IMAGE_GZ="$KERNEL_DIR/out/arch/arm64/boot/Image.gz"
IMAGE_GZ_DTB="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/mediatek/mt6768.dtb"
DTBO_EARTH="$KERNEL_DIR/out/arch/arm64/boot/dts/mediatek/earth.dtbo"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"

MAKE_BOOTIMG="false"
PERMISSIVE_BOOTIMG="false"

export KBUILD_BUILD_USER="Xero"
export KBUILD_BUILD_HOST="XeroMz"

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
KERNEL_VERSION=$(make O=out $args kernelversion | grep "4.19")
echo "LINUX KERNEL VERSION : $KERNEL_VERSION"
make O=out $args -j"$(nproc --all)" | tee "$WORKDIR/out/build.log"

echo "Checking builds"
if [ ! -e $IMAGE_GZ_DTB ]; then
    echo -e "Build Failed!"
    exit 1
fi

echo "Packing Kernel"
ZIP_NAME="Sigma-AnyKernel3"
cd $WORKDIR
unzip $ZIP_NAME.zip
cd $WORKDIR/Sigma-AnyKernel3
cp $IMAGE_GZ_DTB .
cp $DTB $WORKDIR/Sigma-AnyKernel3/dtb
cp $DTBO .
Build Configs
# Pack File
time=$(TZ='Asia/Jakarta' date +"%Y-%m-%d %H:%M:%S")
find ./ * -exec touch -m -d "$time" {} \;
zip -r9 $ZIP_NAME.zip *
cp *.zip $WORKDIR/out

cp $IMAGE_GZ $WORKDIR/out
cp $IMAGE_GZ_DTB $WORKDIR/out
cp $DTBO $WORKDIR/out
cp $DTBO_EARTH $WORKDIR/out
cp $DTB $WORKDIR/out

cd $WORKDIR/out

echo "Done!"
