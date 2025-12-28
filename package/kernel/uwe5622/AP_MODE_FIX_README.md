# UWE5622 AP Mode Fix for OpenWrt

## Problem Summary
AP mode on Orange Pi Zero 3 with UWE5622 wireless chipset causes networking to become unresponsive. The interface appears to start but no traffic flows.

## Root Causes Identified

### 1. DFS_MASTER Support Disabled
- The 11h.o module (DFS/radar detection) was disabled in the driver Makefile
- Critical netif_wake_queue() calls were wrapped in #ifdef DFS_MASTER blocks
- Without this, the network queue never gets woken up after AP starts

### 2. STA_SOFTAP_SCC_MODE Not Enabled  
- Single-Channel Concurrent (SCC) mode was not enabled
- Caused channel conflicts when running AP mode
- Driver advertised 2 different channels but couldn't handle it properly

### 3. Network Queue Management Bug
- In cfg80211.c start_ap function, network queue wake was conditional on DFS_MASTER
- This left the queue in stopped state, blocking all traffic

### 4. Interface Combination Misconfiguration
- Driver claimed support for 2 different channels
- Hardware only supports single channel operation (SCC mode)
- Caused confusion in channel management

## Fixes Applied

### Patch 011-enable-dfs-master-support.patch
- Enables DFS_MASTER support in driver Makefile
- Uncomments the 11h.o module compilation
- Adds -DDFS_MASTER to ccflags

### Patch 012-fix-ap-netif-queue-wake.patch
- Removes #ifdef DFS_MASTER guards from critical networking code
- Ensures netif_carrier_on() and netif_wake_queue() are ALWAYS called
- Fixes both start_ap and change_beacon functions
- Guarantees network interface is operational after AP starts

### Patch 013-fix-interface-combination-scc.patch
- Changes num_different_channels from 2 to 1
- Properly reflects single-channel concurrent operation capability
- Prevents channel conflict issues

### Makefile Changes
- Added UNISOC_STA_SOFTAP_SCC_MODE=y to enable SCC mode
- Added -DDFS_MASTER to KCFLAGS for proper DFS support
- Applied to both MAKE_FLAGS and Build/Compile sections

## Building and Installation

### Clean and Rebuild
```bash
cd /home/dhillon/openwrt

# Clean the package
make package/kernel/uwe5622/clean

# Rebuild with new patches
make package/kernel/uwe5622/compile V=s

# If successful, build the full image
make -j$(nproc) V=s
```

### Manual Package Update (without full rebuild)
```bash
# Copy the new kernel modules to the device
scp bin/targets/sunxi/cortexa53/packages/kmod-uwe5622_*.ipk root@192.168.1.1:/tmp/

# On the device:
opkg remove kmod-uwe5622
opkg install /tmp/kmod-uwe5622_*.ipk
reboot
```

## Testing AP Mode

### 1. Basic AP Configuration
```bash
# Edit /etc/config/wireless
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.channel='6'
uci set wireless.default_radio0.mode='ap'
uci set wireless.default_radio0.ssid='OpenWrt-Test'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='testpassword123'
uci commit wireless
wifi reload
```

### 2. Verify Network Interface Status
```bash
# Check interface is up
ip link show wlan0

# Should show: 
# wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP>

# Check carrier is on
cat /sys/class/net/wlan0/carrier
# Should return: 1

# Check queue state
cat /sys/class/net/wlan0/tx_queue_len
# Should return: 1000 (or similar non-zero value)
```

### 3. Monitor Driver Logs
```bash
# Watch for errors
dmesg -w | grep -i "sprdwl\|uwe5622"

# Should NOT see:
# - "failed to start AP"
# - queue-related errors
# - channel conflict messages
```

### 4. Test Client Connection
```bash
# From a client device, connect to the AP
# Then on the router, check:

# Active stations
iw dev wlan0 station dump

# Traffic stats
ifconfig wlan0

# RX/TX packets should be incrementing
```

### 5. Test Network Traffic
```bash
# From connected client, test connectivity:
ping -c 4 192.168.1.1

# Test internet (if WAN is configured):
ping -c 4 8.8.8.8

# Test bandwidth:
iperf3 -s  # On router

iperf3 -c 192.168.1.1  # From client
```

## Expected Behavior After Fix

### Before Fix
- AP mode starts but no traffic flows
- Client can associate but cannot communicate
- Network interface appears up but packets don't move
- System may become unresponsive

### After Fix  
- AP starts normally with proper logging
- Network queue is active (netif_carrier_on + netif_wake_queue)
- Clients can connect and communicate immediately
- Traffic flows bidirectionally
- System remains responsive

## Troubleshooting

### If AP Still Doesn't Work

1. **Check Patches Applied**
```bash
cd /home/dhillon/openwrt/build_dir/target-*/linux-*/uwe5622-*
grep -r "DFS_MASTER" unisocwifi/Makefile
grep -r "11h.o" unisocwifi/Makefile
```

2. **Verify Kernel Module Loaded**
```bash
lsmod | grep -E "sprdwl|uwe5622"
# Should show:
# sprdwl_ng
# uwe5622_bsp_sdio
```

3. **Check Firmware Loading**
```bash
dmesg | grep firmware
# Should show wcnmodem.bin and wifi_2355b001_1ant.ini loaded
```

4. **Monitor hostapd**
```bash
logread -f | grep hostapd
# Watch for authentication and association events
```

5. **Check Channel Configuration**
```bash
iw dev wlan0 info
# Verify channel matches your configuration (e.g., channel 6)
```

### Common Issues

**Issue**: Module fails to load
- **Solution**: Check kernel version compatibility, rebuild against correct kernel headers

**Issue**: Firmware not found
- **Solution**: Verify files in /lib/firmware/: wcnmodem.bin, wifi_2355b001_1ant.ini

**Issue**: Channel conflicts
- **Solution**: Set explicit channel in /etc/config/wireless, avoid AUTO

**Issue**: Clients can't obtain IP
- **Solution**: Check DHCP configuration in /etc/config/dhcp

## Technical Details

### DFS_MASTER Support
- Enables Dynamic Frequency Selection for 5GHz operation
- Required for proper channel management
- Includes CAC (Channel Availability Check) functionality
- Handles radar detection events

### STA_SOFTAP_SCC_MODE  
- Single Channel Concurrent mode
- Allows STA and AP to operate on same channel
- Reduces channel switching overhead
- Improves concurrent operation stability

### Network Queue Management
The fix ensures that when AP mode starts:
1. netif_carrier_on() - Marks link as up
2. netif_wake_queue() - Enables packet transmission
3. Both are called unconditionally (not just with DFS_MASTER)

This is critical because OpenWrt's network stack waits for these signals before routing traffic to the interface.

## Additional Optimization (Optional)

For better performance, consider:

1. **Enable RX NAPI** (already disabled, but can test):
```makefile
# In patches/011-enable-dfs-master-support.patch, uncomment:
ccflags-y += -DRX_NAPI
```

2. **Adjust TX Queue Length**:
```bash
ifconfig wlan0 txqueuelen 2000
```

3. **Set Optimal Channel**:
- 2.4GHz: Channels 1, 6, or 11 (non-overlapping)
- 5GHz: Channels 36-48, 149-165 (non-DFS for testing)

## Firmware Source
- wcnmodem.bin: From Armbian OS
- wifi_2355b001_1ant.ini: From Armbian OS
- Compatible with UWE5622/AW859A chipset

## Driver Source
- Repository: https://github.com/Ran-Thegoth/uwe5622.git
- Commit: ca207454402d215d676dc0eeba54c2b99245bff9
- Verified on: Orange Pi Zero 3 (Allwinner H618 SoC)

## References
- OpenWrt wireless documentation: https://openwrt.org/docs/guide-user/network/wifi/basic
- cfg80211 subsystem documentation
- Unisoc UWE5622 datasheet

## Credits
Analysis and fixes developed for OpenWrt community use on Orange Pi Zero 3 platform.
