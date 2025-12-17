# UWE5622 WiFi Driver Integration for OpenWRT - Complete Guide

This guide provides step-by-step instructions to add UWE5622 (AW859A) WiFi support to any OpenWRT version for Orange Pi Zero 3 1GB or similar Allwinner H618 devices.

## Overview

**Hardware**: Orange Pi Zero 3 1GB (Allwinner H618 SoC with UWE5622/Marlin3L WiFi chip)  
**Chip ID**: 0x2355b001 (Marlin3L AB variant)  
**OpenWRT Version Tested**: v24.10.0 (kernel 6.6.73)  
**Status**: ✅ Fully working

## Prerequisites

- OpenWRT build environment set up
- Target: `sunxi/cortexa53`
- Device: `xunlong_orangepi-zero3`

## File Structure

```
openwrt/
├── package/kernel/uwe5622/
│   ├── Makefile
│   ├── files/lib/firmware/
│   │   ├── wcnmodem.bin           (1.7 MB - from Armbian)
│   │   └── wifi_2355b001_1ant.ini (6.6 KB - from Armbian)
│   └── patches/
│       ├── 001-enable-uwe5622-chip-id.patch
│       ├── 002-fix-kernel-6.6-compat.patch
│       ├── 003-fix-strncpy-warning.patch
│       ├── 004-fix-array-size.patch
│       ├── 005-fix-class-create.patch
│       ├── 006-fix-timeval-conversion.patch
│       ├── 007-disable-wifi-warnings.patch
│       ├── 009-fix-cfg80211-buffer-overflow.patch
│       └── 010-fix-genetlink-and-vla.patch
└── target/linux/sunxi/patches-6.6/
    └── 451-arm64-dts-orangepi-zero3-enable-wifi.patch
```

## Step-by-Step Implementation

### Step 1: Create Package Directory

```bash
cd openwrt
mkdir -p package/kernel/uwe5622/files/lib/firmware
mkdir -p package/kernel/uwe5622/patches
```

### Step 2: Create Package Makefile

Create `package/kernel/uwe5622/Makefile`:

```makefile
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2024 OpenWrt.org

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/kernel.mk

PKG_NAME:=uwe5622
PKG_VERSION:=1.0
PKG_RELEASE:=1

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
  DEPENDS:=+kmod-mmc +kmod-cfg80211 @TARGET_sunxi_cortexa53
  FILES:= \
	$(PKG_BUILD_DIR)/unisocwcn/uwe5622_bsp_sdio.ko \
	$(PKG_BUILD_DIR)/unisocwifi/sprdwl_ng.ko
  AUTOLOAD:=$(call AutoProbe,uwe5622_bsp_sdio sprdwl_ng)
endef

define KernelPackage/uwe5622/description
  Kernel driver for UWE5622 (AW859A) wireless chipset.
  This package provides WiFi and Bluetooth support for the Unisoc UWE5622
  chipset found in devices like Orange Pi Zero 3.
  
  Includes:
  - BSP platform driver (uwe5622_bsp_sdio)
  - WiFi driver (sprdwl_ng)
  - Firmware and configuration files
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
	KCFLAGS="-Wno-error=implicit-fallthrough -Wno-error=attribute-warning"

define Build/Compile
	+$(MAKE) $(PKG_JOBS) -C "$(LINUX_DIR)" \
		$(KERNEL_MAKE_FLAGS) \
		M="$(PKG_BUILD_DIR)" \
		NOSTDINC_FLAGS="$(NOSTDINC_FLAGS)" \
		CONFIG_AW_WIFI_DEVICE_UWE5622=y \
		CONFIG_WLAN_UWE5622=y \
		CONFIG_TTY_OVERY_SDIO=y \
		KCFLAGS="-Wno-error=implicit-fallthrough -Wno-error=attribute-warning" \
		modules
endef

define KernelPackage/uwe5622/install
	$(INSTALL_DIR) $(1)/lib/firmware
	$(INSTALL_DATA) ./files/lib/firmware/wcnmodem.bin $(1)/lib/firmware/
	$(INSTALL_DATA) ./files/lib/firmware/wifi_2355b001_1ant.ini $(1)/lib/firmware/
endef

$(eval $(call KernelPackage,uwe5622))
```

### Step 3: Obtain Firmware Files

Download from Armbian firmware repository:

```bash
cd /tmp
git clone --depth 1 https://github.com/armbian/firmware armbian-firmware

# Copy firmware files
cp armbian-firmware/uwe5622/wcnmodem-38222.bin \
   openwrt/package/kernel/uwe5622/files/lib/firmware/wcnmodem.bin

cp armbian-firmware/uwe5622/wifi_2355b001_1ant.ini \
   openwrt/package/kernel/uwe5622/files/lib/firmware/
```

**Important**: The firmware must be `wcnmodem-38222.bin` (1.7 MB) which contains the "3LAB" tag for Marlin3L AB chips.

### Step 4: Create Kernel Compatibility Patches

Create these patches in `package/kernel/uwe5622/patches/`:

#### 001-enable-uwe5622-chip-id.patch
Enables UWE5622 chip configuration and CONFIG_CHECK_DRIVER_BY_CHIPID.

```patch
--- a/unisocwcn/Makefile
+++ b/unisocwcn/Makefile
@@ -79,9 +79,9 @@ ifeq ($(CONFIG_AW_WIFI_DEVICE_UWE5622),y)
 export CONFIG_WCN_SDIO = y
 #export CONFIG_WCN_USB = y
 # export CONFIG_WCN_GNSS = y
-ccflags-y += -DCONFIG_CHECK_DRIVER_BY_CHIPID
-# ccflags-y += -DCONFIG_UWE5622
+ccflags-y += -DCONFIG_CHECK_DRIVER_BY_CHIPID
+ccflags-y += -DCONFIG_UWE5622
 BSP_CHIP_ID := uwe5622
 WCN_HW_TYPE := sdio
 endif
```

#### 002-fix-kernel-6.6-compat.patch
Fixes kernel 6.6 API compatibility (BIT macro, of_get_named_gpio).

```patch
--- a/unisocwcn/platform/wcn_boot.c
+++ b/unisocwcn/platform/wcn_boot.c
@@ -1379,7 +1379,7 @@ static int marlin_parse_dt(struct device_node **np)
 	struct regmap *pmu_apb_gpr;
 	uint32_t gpio_num[MDBG_GPIO_MAX];
 
-	wcn_gpio[MDBG_GPIO_SPI_EN].gpio = of_get_named_gpio(*np, "enable-gpios", 0);
+	wcn_gpio[MDBG_GPIO_SPI_EN].gpio = of_get_named_gpio_flags(*np, "enable-gpios", 0, NULL);
 	if (!gpio_is_valid(wcn_gpio[MDBG_GPIO_SPI_EN].gpio)) {
 		WCN_INFO("can't get wcn chip_en gpio, ret=%d\n",
 			 wcn_gpio[MDBG_GPIO_SPI_EN].gpio);
 		return -1;
 	}
 
@@ -1388,7 +1388,7 @@ static int marlin_parse_dt(struct device_node **np)
 
 	/* get BT_WAKE_HOST gpio config, */
 	WCN_INFO("wcn config bt wake host\n");
-	wcn_gpio[MDBG_GPIO_BT_WAKE_HOST].gpio = of_get_named_gpio(*np, "bt-wake-host-gpios", 0);
+	wcn_gpio[MDBG_GPIO_BT_WAKE_HOST].gpio = of_get_named_gpio_flags(*np, "bt-wake-host-gpios", 0, NULL);
 	if (!gpio_is_valid(wcn_gpio[MDBG_GPIO_BT_WAKE_HOST].gpio))
 		WCN_ERR("dts node for bt_wake not found\n");
 	else {
@@ -1455,7 +1455,7 @@ static int marlin_parse_dt(struct device_node **np)
 
 	WCN_INFO("marlin2 parse_dt some para not config\n");
 
-	return BIT(wcn_get_chip_model());
+	return 1 << wcn_get_chip_model();
 
 error:
 	marlin_dev->no_power_off = 0;
```

#### 003-fix-strncpy-warning.patch
Fixes sizeof in strncpy call.

```patch
--- a/unisocwcn/platform/wcn_parn_parser.c
+++ b/unisocwcn/platform/wcn_parn_parser.c
@@ -186,7 +186,7 @@ void wcn_parn_parser(char *buf, int len)
 	for (i = 0; i < len; i++)
 		WCN_DEBUG("parser buf[%d]:0x%x(%c)\n", i, buf[i], buf[i]);
 
-	strncpy(tmp_str, buf, len);
+	strncpy(tmp_str, buf, sizeof(tmp_str) - 1);
 	tmp_str[len] = '\0';
 	WCN_INFO("tmp_str:%s\n", tmp_str);
```

#### 004-fix-array-size.patch
Changes zero-sized arrays to proper sizes.

```patch
--- a/unisocwcn/platform/rdc_debug.c
+++ b/unisocwcn/platform/rdc_debug.c
@@ -42,7 +42,7 @@ struct rdc_dbg_entry {
 
 struct rdc_dbg_entry dbg_entry;
 
-static unsigned char rx_buf[0];
+static unsigned char rx_buf[1024];
 
 #define RDC_NAME_SIZE 20
```

#### 005-fix-class-create.patch
Removes THIS_MODULE parameter from class_create (kernel 6.6 API change).

```patch
--- a/unisocwcn/platform/wcn_log.c
+++ b/unisocwcn/platform/wcn_log.c
@@ -876,7 +876,7 @@ int mdbg_dev_init(void)
 		return err;
 	}
 
-	mdev_class = class_create(THIS_MODULE, "mdbg");
+	mdev_class = class_create("mdbg");
 	if (IS_ERR(mdev_class)) {
 		unregister_chrdev_region(mdbg_dev, MDBG_DEV_NUM);
 		err = PTR_ERR(mdev_class);
```

#### 006-fix-timeval-conversion.patch
Adds timeval_to_ns_compat macro for kernel 6.6.

```patch
--- a/unisocwcn/sdio/sdiohal_ctl.c
+++ b/unisocwcn/sdio/sdiohal_ctl.c
@@ -22,6 +22,10 @@
 
 #define SPRD_IOCTL_NAME	"sprd_ioctl"
 
+#ifndef timeval_to_ns
+#define timeval_to_ns_compat(tv) (((long long)(tv)->tv_sec * NSEC_PER_SEC) + (tv)->tv_usec * NSEC_PER_USEC)
+#endif
+
 static struct platform_device *sprd_ioctl_pdev;
 
 static long sprd_ioctl_open(struct inode *inode, struct file *filp)
@@ -577,7 +581,7 @@ static unsigned int get_sys_cnt(void)
 	struct timespec64 now;
 
 	ktime_get_real_ts64(&now);
-	return (unsigned int)(timespec64_to_ns(&now) / NSEC_PER_MSEC);
+	return (unsigned int)((now.tv_sec * 1000) + (now.tv_nsec / NSEC_PER_MSEC));
 }
```

#### 007-disable-wifi-warnings.patch
Disables various compiler warnings.

```patch
--- a/unisocwifi/Makefile
+++ b/unisocwifi/Makefile
@@ -21,6 +21,11 @@ WIFI_MODULE_NAME := $(BSP_CHIP_ID)_wifi
 
 KBUILD_CFLAGS += -DCONFIG_SPRD_WLAN_VENDOR_SPECIFIC
 
+ccflags-y += -Wno-vla
+ccflags-y += -Wno-enum-conversion
+ccflags-y += -Wno-unused-variable
+ccflags-y += -Wno-date-time
+
 obj-$(CONFIG_WLAN_UWE5622) += $(WIFI_MODULE_NAME).o
 
 $(WIFI_MODULE_NAME)-y += \
```

#### 009-fix-cfg80211-buffer-overflow.patch
Replaces strncpy with memcpy for flexible array member.

```patch
--- a/unisocwifi/cfg80211.c
+++ b/unisocwifi/cfg80211.c
@@ -5076,8 +5076,9 @@ static int sprdwl_cfg80211_add_key(struct wiphy *wiphy,
 		return -ENOMEM;
 	}
 
-	strncpy(subcmd->mac, mac_addr, ETH_ALEN);
-	strncpy(subcmd->keyseq, params->seq, params->seq_len);
+	memcpy(subcmd->mac, mac_addr, ETH_ALEN);
+	if (params->seq && params->seq_len > 0)
+		memcpy(subcmd->keyseq, params->seq, params->seq_len);
 	subcmd->pairwise = pairwise;
 	subcmd->cypher_type = params->cipher;
 	subcmd->key_index = key_index;
```

#### 010-fix-genetlink-and-vla.patch
Defines GENL_HDRLEN and fixes VLA issues.

```patch
--- a/unisocwifi/npi.c
+++ b/unisocwifi/npi.c
@@ -13,6 +13,10 @@
 #include "cfg80211.h"
 #include "cmdevt.h"
 
+#ifndef GENL_HDRLEN
+#define GENL_HDRLEN NLMSG_ALIGN(sizeof(struct genlmsghdr))
+#endif
+
 #define SPRDWL_NPI_CMD_MAX (__SPRDWL_NPI_CMD_MAX - 1)
 
 static struct genl_family sprdwl_genl_family;
--- a/unisocwifi/cmdevt.c
+++ b/unisocwifi/cmdevt.c
@@ -724,7 +724,8 @@ int sprdwl_send_data2mgmt(struct sprdwl_priv *priv, struct sprdwl_vif *vif,
 	u16 data_len;
 	u16 len;
 	unsigned char *info;
-	u8 data[len];
+	u8 *data;
+	data = kmalloc(1024, GFP_KERNEL);
 
 	if (!vif->ctx_id) {
 		wiphy_err(priv->wiphy, "%s ctx_id is 0, drop it\n", __func__);
```

### Step 5: Create Device Tree Patch

Create `target/linux/sunxi/patches-6.6/451-arm64-dts-orangepi-zero3-enable-wifi.patch`:

```patch
--- a/arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dts
+++ b/arch/arm64/boot/dts/allwinner/sun50i-h618-orangepi-zero3.dts
@@ -52,6 +52,13 @@
 		};
 	};
 
+	wifi_pwrseq: wifi-pwrseq {
+		compatible = "mmc-pwrseq-simple";
+		reset-gpios = <&pio 6 18 GPIO_ACTIVE_LOW>; /* PG18 */
+		post-power-on-delay-ms = <200>;
+		power-off-delay-us = <500000>;
+	};
+
 	reg_vcc5v: vcc5v {
 		/* board wide 5V supply directly from the USB-C socket */
 		compatible = "regulator-fixed";
@@ -124,6 +131,23 @@
 	status = "okay";
 };
 
+&mmc1 {
+	vmmc-supply = <&reg_dldo1>;
+	vqmmc-supply = <&reg_aldo1>;
+	mmc-pwrseq = <&wifi_pwrseq>;
+	bus-width = <4>;
+	non-removable;
+	status = "okay";
+
+	sdio_wifi: sdio-wifi@1 {
+		compatible = "unisoc,uwe5622";
+		reg = <1>;
+		interrupt-parent = <&pio>;
+		interrupts = <6 15 IRQ_TYPE_LEVEL_HIGH>; /* PG15 */
+		interrupt-names = "host-wake";
+	};
+};
+
 &mmc2 {
 	vmmc-supply = <&reg_dldo1>;
 	vqmmc-supply = <&reg_aldo1>;
```

### Step 6: Update Device Configuration

Edit `target/linux/sunxi/image/cortexa53.mk` and add `kmod-uwe5622` to Orange Pi Zero 3:

```makefile
define Device/xunlong_orangepi-zero3
  DEVICE_VENDOR := Xunlong
  DEVICE_MODEL := Orange Pi Zero 3
  SOC := sun50i-h618
  DEVICE_PACKAGES := kmod-uwe5622
endef
TARGET_DEVICES += xunlong_orangepi-zero3
```

### Step 7: Build

```bash
cd openwrt

# Update feeds
./scripts/feeds update -a
./scripts/feeds install -a

# Configure
make menuconfig
# Select: Target System -> Allwinner
# Select: Subtarget -> Cortex-A53 based boards
# Select: Target Profile -> Xunlong Orange Pi Zero 3

# Build
make -j$(nproc)
```

### Step 8: Flash and Test

Flash the image:
```bash
# Decompress
gunzip bin/targets/sunxi/cortexa53/openwrt-sunxi-cortexa53-xunlong_orangepi-zero3-squashfs-sdcard.img.gz

# Flash to SD card (replace /dev/sdX with your SD card device)
sudo dd if=bin/targets/sunxi/cortexa53/openwrt-sunxi-cortexa53-xunlong_orangepi-zero3-squashfs-sdcard.img \
        of=/dev/sdX bs=4M status=progress
sudo sync
```

Boot and test:
```bash
# Check driver status
dmesg | grep -E "WCN|sprdwl|wifi"

# Bring up interface
ip link set wlan0 up

# Scan for networks
iw dev wlan0 scan | grep -E "^BSS|SSID:|signal:"
```

## Expected Results

Successful boot log should show:
```
WCN: marlin_get_wcn_chipid: chipid: 0x2355b001
WCN: marlin_request_firmware from /lib/firmware/wcnmodem.bin start!
WCN: marlin_firmware_parse_image imagepack is WCNM type,need parse it
wifi ini path = /lib/firmware/wifi_2355b001_1ant.ini
sprdwl:fw_ver:38222, fw_std:0x7f, fw_capa:0x120fff
sprdwl:mac_addr:e0:51:d8:21:48:04
unisoc_wifi unisoc_wifi wlan0: mixed HW and IP checksum settings.
```

## Troubleshooting

### Firmware parsing fails
- Ensure you're using `wcnmodem-38222.bin` from Armbian (has "3LAB" tag)
- Check CONFIG_CHECK_DRIVER_BY_CHIPID is enabled in patch 001

### No wlan0 interface
- Verify device tree patch applied: `ls /sys/bus/sdio/devices/`
- Check kernel modules loaded: `lsmod | grep uwe5622`

### Compilation errors
- Apply all 9 patches in order
- Ensure kernel version compatibility (tested on 6.6.73)

## Files to Package for Distribution

Create a zip file with:
```
uwe5622-openwrt/
├── README.md (this file)
├── package/
│   └── kernel/
│       └── uwe5622/
│           ├── Makefile
│           ├── files/
│           │   └── lib/firmware/
│           │       ├── wcnmodem.bin
│           │       └── wifi_2355b001_1ant.ini
│           └── patches/
│               ├── 001-enable-uwe5622-chip-id.patch
│               ├── 002-fix-kernel-6.6-compat.patch
│               ├── 003-fix-strncpy-warning.patch
│               ├── 004-fix-array-size.patch
│               ├── 005-fix-class-create.patch
│               ├── 006-fix-timeval-conversion.patch
│               ├── 007-disable-wifi-warnings.patch
│               ├── 009-fix-cfg80211-buffer-overflow.patch
│               └── 010-fix-genetlink-and-vla.patch
└── target/
    └── linux/
        └── sunxi/
            ├── patches-6.6/
            │   └── 451-arm64-dts-orangepi-zero3-enable-wifi.patch
            └── image/
                └── cortexa53.mk.patch
```

## Credits

- Driver source: https://github.com/Ran-Thegoth/uwe5622
- Firmware source: Armbian firmware repository
- Tested on: OpenWRT v24.10.0, Orange Pi Zero 3 1GB

## License

GPL-2.0 (matching OpenWRT and driver licenses)

---

**Status**: ✅ Production Ready  
**Last Updated**: December 17, 2025  
**Maintainer**: OpenWrt Community
