#
# UWE5622 WiFi driver (in-tree from Armbian)
#

define KernelPackage/uwe5622
  SUBMENU:=Wireless Drivers
  TITLE:=UWE5622 WiFi driver (Armbian in-tree)
  DEPENDS:=@TARGET_sunxi_cortexa53 +kmod-cfg80211 +kmod-mac80211
  KCONFIG:= \
	CONFIG_SPARD_WLAN_SUPPORT=y \
	CONFIG_AW_WIFI_DEVICE_UWE5622=y \
	CONFIG_WLAN_UWE5622=m \
	CONFIG_SPRDWL_NG=m \
	CONFIG_TTY_OVERY_SDIO=m \
	CONFIG_UWE5622_SDIO_SUPPORT=y \
	CONFIG_SC23XX=n \
	CONFIG_WCN_BSP_DRIVER_BUILDIN=y
  FILES:= \
	$(LINUX_DIR)/drivers/net/wireless/uwe5622/unisocwifi/sprdwl_ng.ko \
	$(LINUX_DIR)/drivers/net/wireless/uwe5622/unisocwcn/sdio/uwe5622_bsp_sdio.ko \
	$(LINUX_DIR)/drivers/net/wireless/uwe5622/tty-sdio/sprdbt_tty.ko
  AUTOLOAD:=$(call AutoProbe,uwe5622_bsp_sdio sprdwl_ng sprdbt_tty)
endef

define KernelPackage/uwe5622/description
 Kernel driver for UWE5622 (AW859A) WiFi and Bluetooth chipset
 Built in-tree from Armbian patches for Unisoc Marlin3L AB chip
endef

$(eval $(call KernelPackage,uwe5622))
