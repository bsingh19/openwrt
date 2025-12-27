# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
# Based on Armbian uwe5622 driver integration
# https://github.com/armbian/build/blob/main/extensions/uwe5622-allwinner.sh

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uwe5622
PKG_VERSION:=1.0
PKG_RELEASE:=2

PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=https://github.com/Ran-Thegoth/uwe5622.git
PKG_SOURCE_VERSION:=ca207454402d215d676dc0eeba54c2b99245bff9
PKG_MIRROR_HASH:=de27a8f18e28e8a339c448f222a0206d450f69280568e05f8eb495fd65c2c396

PKG_LICENSE:=GPL-2.0
PKG_LICENSE_FILES:=

PKG_MAINTAINER:=OpenWrt Community

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/uwe5622
  SUBMENU:=Wireless Drivers
  TITLE:=UWE5622 (AW859A) WiFi and Bluetooth Driver
  DEPENDS:=+kmod-mmc +kmod-cfg80211 +kmod-mac80211 @TARGET_sunxi_cortexa53
  FILES:= \
	$(PKG_BUILD_DIR)/unisocwcn/uwe5622_bsp_sdio.ko \
	$(PKG_BUILD_DIR)/unisocwifi/sprdwl_ng.ko \
	$(PKG_BUILD_DIR)/tty-sdio/sprdbt_tty.ko
  AUTOLOAD:=$(call AutoProbe,uwe5622_bsp_sdio sprdwl_ng sprdbt_tty)
endef

define KernelPackage/uwe5622/description
  Kernel driver for UWE5622 (AW859A) wireless chipset (Armbian port).
  This package provides WiFi (including AP mode) and Bluetooth support 
  for the Unisoc UWE5622 chipset found in devices like Orange Pi Zero 3.
  
  Includes:
  - BSP platform driver (uwe5622_bsp_sdio) - SDIO interface
  - WiFi driver (sprdwl_ng) - Station, AP, and P2P modes
  - Bluetooth driver (sprdbt_tty) - BT over SDIO
  
  Based on Armbian driver implementation with AP mode patches.
endef

NOSTDINC_FLAGS:= \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(PKG_BUILD_DIR) \
	-I$(PKG_BUILD_DIR)/unisocwcn/include

# Enable specific driver features for AP mode support
MAKE_FLAGS+= \
	CONFIG_AW_WIFI_DEVICE_UWE5622=y \
	CONFIG_WLAN_UWE5622=y \
	CONFIG_TTY_OVERY_SDIO=y \
	CONFIG_SPRD_WLAN_VENDOR_SPECIFIC=y \
	KCFLAGS="-Wno-error=implicit-fallthrough -Wno-error=attribute-warning -Wno-error=misleading-indentation"

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		CONFIG_AW_WIFI_DEVICE_UWE5622=y \
		CONFIG_WLAN_UWE5622=y \
		CONFIG_TTY_OVERY_SDIO=y \
		CONFIG_SPRD_WLAN_VENDOR_SPECIFIC=y \
		KCFLAGS="-Wno-error=implicit-fallthrough -Wno-error=attribute-warning -Wno-error=misleading-indentation" \
		modules
endef

define KernelPackage/uwe5622/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/lib/firmware/uwe5622
	
	# Install firmware files
	$(INSTALL_DATA) ./files/lib/firmware/wcnmodem.bin $(1)/lib/firmware/
	$(INSTALL_DATA) ./files/lib/firmware/wifi_2355b001_1ant.ini $(1)/lib/firmware/
	
	# Install init script for WiFi/BT initialization
	$(INSTALL_BIN) ./files/etc/init.d/uwe5622 $(1)/etc/init.d/
endef

$(eval $(call KernelPackage,uwe5622))
