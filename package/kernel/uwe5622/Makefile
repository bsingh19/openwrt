# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2024 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uwe5622
PKG_VERSION:=1.0
PKG_RELEASE:=2

PKG_BUILD_DIR:=$(KERNEL_BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)
PKG_FLAGS:=nonshared

PKG_MAINTAINER:=OpenWrt Community

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk

define KernelPackage/uwe5622
  SUBMENU:=Wireless Drivers
  TITLE:=UWE5622 (AW859A) WiFi and Bluetooth Driver
  DEPENDS:=+kmod-mmc +kmod-cfg80211 @TARGET_sunxi_cortexa53
  FILES:= \
	$(PKG_BUILD_DIR)/unisocwcn/uwe5622_bsp_sdio.ko \
	$(PKG_BUILD_DIR)/unisocwifi/sprdwl_ng.ko
#	$(PKG_BUILD_DIR)/tty-sdio/sprdbt_tty.ko
  AUTOLOAD:=$(call AutoProbe,uwe5622_bsp_sdio sprdwl_ng)
endef

define KernelPackage/uwe5622/description
  Kernel driver for UWE5622 (AW859A) wireless chipset.
  This package provides WiFi and Bluetooth support for the Unisoc UWE5622
  chipset found in devices like Orange Pi Zero 3.
  
  Includes:
  - BSP platform driver (uwe5622_bsp_sdio)
  - WiFi driver (sprdwl_ng)
  - Bluetooth driver (sprdbt_tty)
endef

NOSTDINC_FLAGS:= \
	$(KERNEL_NOSTDINC_FLAGS) \
	-I$(PKG_BUILD_DIR) \
	-I$(PKG_BUILD_DIR)/unisocwcn/include \
	-I$(STAGING_DIR)/usr/include/mac80211-backport/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211-backport \
	-I$(STAGING_DIR)/usr/include/mac80211/uapi \
	-I$(STAGING_DIR)/usr/include/mac80211 \
	-include backport/backport.h

MAKE_FLAGS+= \
	CONFIG_AW_WIFI_DEVICE_UWE5622=y \
	CONFIG_WLAN_UWE5622=y \
	CONFIG_TTY_OVERY_SDIO=y \
	UNISOC_STA_SOFTAP_SCC_MODE=y \
	KCFLAGS="-Wno-error=implicit-fallthrough -Wno-error=attribute-warning"

define Build/Prepare
	$(INSTALL_DIR) $(PKG_BUILD_DIR)
	$(CP) ./uwe5622-source/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		CONFIG_AW_WIFI_DEVICE_UWE5622=y \
		CONFIG_WLAN_UWE5622=y \
		CONFIG_TTY_OVERY_SDIO=y \
		UNISOC_STA_SOFTAP_SCC_MODE=y \
		KCFLAGS="-Wno-error=implicit-fallthrough -Wno-error=attribute-warning" \
		modules
endef

define KernelPackage/uwe5622/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DATA) ./files/lib/firmware/wcnmodem.bin $(1)/lib/firmware/
	$(INSTALL_DATA) ./files/lib/firmware/wifi_2355b001_1ant.ini $(1)/lib/firmware/
endef

$(eval $(call KernelPackage,uwe5622))
