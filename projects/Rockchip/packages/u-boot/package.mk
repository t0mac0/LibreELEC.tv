################################################################################
#      This file is part of LibreELEC - https://libreelec.tv
#      Copyright (C) 2017 Team LibreELEC
#
#  LibreELEC is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  LibreELEC is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with LibreELEC.  If not, see <http://www.gnu.org/licenses/>.
################################################################################

PKG_NAME="u-boot"
PKG_VERSION="1e744e7"
PKG_ARCH="arm aarch64"
PKG_LICENSE="GPL"
PKG_SITE="http://www.denx.de/wiki/U-Boot"
PKG_URL="https://github.com/rockchip-linux/u-boot/archive/$PKG_VERSION.tar.gz"
PKG_SOURCE_DIR="u-boot-$PKG_VERSION*"
PKG_DEPENDS_TARGET="toolchain dtc:host"
PKG_SECTION="tools"
PKG_SHORTDESC="u-boot: Universal Bootloader project"
PKG_LONGDESC="Das U-Boot is a cross-platform bootloader for embedded systems, used as the default boot loader by several board vendors. It is intended to be easy to port and to debug, and runs on many supported architectures, including PPC, ARM, MIPS, x86, m68k, NIOS, and Microblaze."

PKG_IS_ADDON="no"
PKG_AUTORECONF="no"

if [ "$UBOOT_SOC" = "rk3328" ]; then
  PKG_DEPENDS_TARGET="$PKG_DEPENDS_TARGET rkbin"
  PKG_NEED_UNPACK="$(get_pkg_directory rkbin)"
fi

pre_configure_target() {
  if [ -z "$UBOOT_CONFIG" ]; then
    echo "Please add UBOOT_CONFIG to your project or device options file, aborting."
    exit 1
  elif [ -z "$UBOOT_SOC" ]; then
    echo "Please add UBOOT_SOC to your project or device options file, aborting."
    exit 1
  fi
}

make_target() {
  CROSS_COMPILE="$TARGET_PREFIX" CFLAGS="" LDFLAGS="" ARCH=arm make mrproper
  CROSS_COMPILE="$TARGET_PREFIX" CFLAGS="" LDFLAGS="" ARCH=arm make $UBOOT_CONFIG
  CROSS_COMPILE="$TARGET_PREFIX" CFLAGS="" LDFLAGS="" ARCH=arm make HOSTCC="$HOST_CC" HOSTSTRIP="true"
}

makeinstall_target() {
  mkdir -p $INSTALL/usr/share/bootloader
    cp -PRv $PKG_DIR/scripts/update.sh $INSTALL/usr/share/bootloader

 if [ "$UBOOT_SOC" = "rk3288" ]; then
    tools/mkimage \
      -n $UBOOT_SOC \
      -T rksd \
      -d spl/u-boot-spl-dtb.bin \
      idbloader.img
    cat u-boot-dtb.bin >> idbloader.img

    cp -PRv idbloader.img $INSTALL/usr/share/bootloader
  elif [ "$UBOOT_SOC" = "rk3328" ]; then
    $PKG_DIR/tools/loaderimage --pack --uboot u-boot-dtb.bin uboot.img

    dd if=$(get_build_dir rkbin)/rk33/rk3328_ddr_786MHz_v1.06.bin of=ddr.bin bs=4 skip=1
    tools/mkimage \
      -n $UBOOT_SOC \
      -T rksd \
      -d ddr.bin \
      idbloader.img
    cat $(get_build_dir rkbin)/rk33/rk3328_miniloader_v2.43.bin >> idbloader.img

    cat >trust.ini <<EOF
[VERSION]
MAJOR=1
MINOR=2
[BL30_OPTION]
SEC=0
[BL31_OPTION]
SEC=1
PATH=$(get_build_dir rkbin)/rk33/rk3328_bl31_v1.10.bin
ADDR=0x10000
[BL32_OPTION]
SEC=1
PATH=$(get_build_dir rkbin)/rk33/rk3328_bl32_v1.01.bin
ADDR=0x08400000
[BL33_OPTION]
SEC=0
[OUTPUT]
PATH=trust.img
EOF
    $PKG_DIR/tools/trust_merger trust.ini

    cp -PRv idbloader.img $INSTALL/usr/share/bootloader
    cp -PRv uboot.img $INSTALL/usr/share/bootloader
    cp -PRv trust.img $INSTALL/usr/share/bootloader
  fi
}
