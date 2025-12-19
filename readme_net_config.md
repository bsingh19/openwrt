# WiFi Readiness Checklist - Orange Pi Zero 3 with UWE5622

## Step-by-Step Verification Process

### Step 1: Check Driver Modules

Verify that WiFi driver modules are loaded:

```bash
lsmod | grep -E "sprdwl|uwe5622"
```

**Expected output:**
```
cfg80211              331776  1 sprdwl_ng
sprdwl_ng             327680  0 
uwe5622_bsp_sdio      188416  1 sprdwl_ng
```

✅ **Success:** All three modules present  
❌ **Failure:** If missing, check `dmesg | grep -i error`

---

### Step 2: Verify Firmware Files

Check that firmware blobs exist:

```bash
ls -lh /lib/firmware/wcnmodem.bin
ls -lh /lib/firmware/wifi_2355b001_1ant.ini
```

**Expected output:**
```
-rw-r--r-- 1 root root 1.7M wcnmodem.bin
-rw-r--r-- 1 root root 6.6K wifi_2355b001_1ant.ini
```

✅ **Success:** Both files present with correct sizes  
❌ **Failure:** Rebuild firmware or check package installation

---

### Step 3: Check Firmware Loading

Verify firmware loaded successfully at boot:

```bash
dmesg | grep -E "WCN|sprdwl|firmware" | tail -20
```

**Expected output should include:**
```
WCN: marlin_request_firmware from /lib/firmware/wcnmodem.bin start!
WCN: marlin_firmware_parse_image imagepack is WCNM type,need parse it
WCN: combin_img 0 marlin_firmware_write finish and successful
wifi ini path = /lib/firmware/wifi_2355b001_1ant.ini
sprdwl:chip_model:0x2355, chip_ver:0x0
sprdwl:fw_ver:38222, fw_std:0x7f, fw_capa:0x120fff
sprdwl:mac_addr:e0:51:d8:21:48:04
unisoc_wifi unisoc_wifi wlan0: mixed HW and IP checksum settings.
```

✅ **Success:** Firmware loaded, wlan0 created  
❌ **Failure:** Check for "imginfo is NULL" or firmware errors

---

### Step 4: Verify wpad Package

Check that wpa_supplicant is installed:

```bash
opkg list-installed | grep wpad
which wpa_supplicant
ls -l /usr/sbin/wpad
```

**Expected output:**
```
wpad-basic-mbedtls - 2024.09.15~5ace39b0-r2
/usr/sbin/wpa_supplicant
lrwxrwxrwx 1 root root 14 /usr/sbin/wpad -> wpad-basic
```

✅ **Success:** wpad-basic-mbedtls installed  
❌ **Failure:** Package missing, need to rebuild firmware

---

### Step 5: Verify wlan0 Interface Exists

Check interface in system:

```bash
ls /sys/class/net/
ls /sys/class/ieee80211/
iw dev
```

**Expected output:**
```
# ls /sys/class/net/
eth0   lo     wlan0

# ls /sys/class/ieee80211/
phy0

# iw dev
phy#0
	Interface wlan0
		ifindex 3
		wdev 0x1
		addr e0:51:d8:21:48:04
		type managed
```

✅ **Success:** wlan0 present, phy0 exists  
❌ **Failure:** Driver or firmware issue

---

### Step 6: Check Network Configuration

**CRITICAL:** Verify network config has no conflicts:

```bash
cat /etc/config/network
```

**WRONG Configuration (causes hangs):**
```
config device
        option name 'br-lan'
        option type 'bridge'
        list ports 'eth0'          # ❌ CONFLICT

config interface 'wan'
        option device 'eth0'        # ❌ SAME DEVICE
        option proto 'dhcp'
```

**CORRECT Configuration:**
```
config interface 'loopback'
        option device 'lo'
        option proto 'static'
        option ipaddr '127.0.0.1'
        option netmask '255.0.0.0'

config globals 'globals'
        option ula_prefix 'fd59:3990:e3a0::/48'

config interface 'wan'
        option device 'eth0'
        option proto 'dhcp'

config interface 'wwan'
        option proto 'dhcp'
```

**Fix if wrong:**
```bash
uci delete network.@device[0]
uci commit network
/etc/init.d/network restart
```

✅ **Success:** No bridge device, eth0 only in wan  
❌ **Failure:** Fix config and restart network

---

### Step 7: Connect Ethernet (REQUIRED)

**⚠️ CRITICAL: Connect ethernet cable before testing WiFi**

Without ethernet connected:
- Network stack becomes unresponsive
- All network commands hang
- System appears frozen

```bash
# After connecting ethernet, verify:
ip addr show eth0
```

**Expected:** eth0 should have IP address from DHCP

✅ **Success:** Ethernet connected and working  
❌ **Failure:** Cannot proceed without ethernet

---

### Step 8: Bring Up wlan0 Interface

```bash
ip link set wlan0 up
ip link show wlan0
```

**Expected output:**
```
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...
    link/ether e0:51:d8:21:48:04 brd ff:ff:ff:ff:ff:ff
```

✅ **Success:** Interface UP  
❌ **Failure:** "No such device" = network config broken

---

### Step 9: Test WiFi Scanning

```bash
iw dev wlan0 scan | grep -E "^BSS|SSID:|signal:"
```

**Expected output:**
```
BSS 48:a9:8a:80:bd:06(on wlan0)
        SSID: CEMSI
        signal: -31.00 dBm
BSS 00:11:22:33:44:55(on wlan0)
        SSID: AnotherNetwork
        signal: -65.00 dBm
```

✅ **Success:** Networks visible  
❌ **Failure:** Driver/firmware issue

---

### Step 10: Configure WiFi Connection

Create WPA supplicant configuration:

```bash
cat > /tmp/wpa.conf << 'EOF'
network={
    ssid="CEMSI"
    psk="$v7akng9!"
}
EOF
```

✅ **Success:** Config file created  
❌ **Failure:** Check filesystem permissions

---

### Step 11: Start WPA Supplicant

```bash
killall wpad 2>/dev/null
/usr/sbin/wpad wpa_supplicant -B -i wlan0 -c /tmp/wpa.conf -D nl80211

## Debug Mode
/usr/sbin/wpad wpa_supplicant -i wlan0 -c /tmp/wpa.conf -D nl802

```

Wait 10 seconds for connection:
```bash
sleep 10
```

✅ **Success:** No errors  
❌ **Failure:** Check wpad installed

---

### Step 12: Verify WiFi Connection

```bash
iw dev wlan0 link
```

**Expected output:**
```
Connected to 48:a9:8a:80:bd:06 (on wlan0)
	SSID: CEMSI
	freq: 2432
	RX: 1234 bytes (10 packets)
	TX: 567 bytes (8 packets)
	signal: -31 dBm
	rx bitrate: 54.0 MBit/s
	tx bitrate: 135.0 MBit/s
```

✅ **Success:** Connected with signal strength  
❌ **Failure:** Check password, signal strength

---

### Step 13: Get IP Address via DHCP

```bash
udhcpc -i wlan0
ip addr show wlan0
```

**Expected output:**
```
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    link/ether e0:51:d8:21:48:04 brd ff:ff:ff:ff:ff:ff
    inet 172.16.0.228/24 brd 172.16.0.255 scope global wlan0
       valid_lft forever preferred_lft forever
```

✅ **Success:** IP address assigned  
❌ **Failure:** DHCP server issue or network problem

---

### Step 14: Test Internet Connectivity

```bash
ping -c 3 8.8.8.8
```

**Expected output:**
```
PING 8.8.8.8 (8.8.8.8): 56 data bytes
64 bytes from 8.8.8.8: seq=0 ttl=111 time=42.666 ms
64 bytes from 8.8.8.8: seq=1 ttl=111 time=46.843 ms
64 bytes from 8.8.8.8: seq=2 ttl=111 time=46.788 ms

--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
```

✅ **Success:** Internet working via WiFi  
❌ **Failure:** Gateway/routing issue

---

### Step 15: Test DNS Resolution

```bash
ping -c 3 google.com
```

**Expected output:**
```
PING google.com (142.250.xxx.xxx): 56 data bytes
64 bytes from 142.250.xxx.xxx: seq=0 ttl=xxx time=xx.xxx ms
```

✅ **Success:** DNS working  
❌ **Failure:** DNS server issue

---

## Quick Diagnostic Commands

If any step fails, use these diagnostics:

```bash
# Full driver/firmware status
dmesg | grep -E "WCN|sprdwl|unisoc|wifi|error" | tail -50

# Network interfaces
ip link show

# Wireless interfaces
iw dev

# Check for errors
logread | grep -i -E "error|fail|wlan0|wpad"

# PHY device path (should be: platform/unisoc_wifi)
ls -la /sys/class/ieee80211/phy0/device

# Wireless configuration
uci show wireless
cat /etc/config/wireless
```

---

## Common Issues & Solutions

### Issue: "ip link set wlan0 up" hangs

**Cause:** Ethernet not connected or network config conflict  
**Solution:**
1. Connect ethernet cable
2. Check network config: `cat /etc/config/network`
3. Remove conflicting bridge: `uci delete network.@device[0] && uci commit network`
4. Restart: `reboot`

### Issue: "No such device (-19)"

**Cause:** wlan0 interface not created  
**Solution:**
1. Check driver loaded: `lsmod | grep sprdwl`
2. Check firmware: `dmesg | grep firmware`
3. Verify interface exists: `ls /sys/class/net/wlan0`

### Issue: Scanning works but connection fails

**Cause:** Wrong password or signal too weak  
**Solution:**
1. Verify password in `/tmp/wpa.conf`
2. Check signal: `iw dev wlan0 scan | grep -A5 "SSID: CEMSI"`
3. Try closer to router

### Issue: Connected but no IP

**Cause:** DHCP not responding  
**Solution:**
1. Check connection: `iw dev wlan0 link`
2. Manually run DHCP: `udhcpc -i wlan0 -v`
3. Check router DHCP settings

---

## Final Verification Checklist

- [x] Driver modules loaded (sprdwl_ng, uwe5622_bsp_sdio, cfg80211)
- [x] Firmware files present (wcnmodem.bin, wifi_2355b001_1ant.ini)
- [x] Firmware loaded successfully at boot
- [x] wpad-basic-mbedtls package installed
- [x] wlan0 interface exists in /sys/class/net/
- [x] Network config has no eth0 conflicts
- [x] Ethernet cable connected
- [x] wlan0 interface brought UP
- [x] WiFi scanning works
- [x] WPA supplicant connects
- [x] IP address obtained via DHCP
- [x] Internet connectivity verified
- [x] DNS resolution works

**If all checkboxes passed: WiFi is fully operational! ✅**

---

## Build System Verification

To ensure firmware includes everything:

```bash
# On build machine
cd /home/dhillon/openwrt

# Check device profile includes packages
grep -A5 "Device/xunlong_orangepi-zero3" target/linux/sunxi/image/cortexa53.mk

# Should show:
# DEVICE_PACKAGES := kmod-uwe5622 wpad-basic-mbedtls

# Check .config has wpad enabled
grep "CONFIG_PACKAGE_wpad-basic-mbedtls" .config

# Should show:
# CONFIG_PACKAGE_wpad-basic-mbedtls=y

# Check wpad package built
ls -lh bin/packages/aarch64_cortex-a53/base/wpad-basic-mbedtls*.ipk

# Check firmware includes WiFi driver
ls -lh bin/packages/aarch64_cortex-a53/kernel/kmod-uwe5622*.ipk
```

---

## Emergency Recovery

If system becomes unresponsive:

1. **Power cycle** the Orange Pi Zero 3
2. **Connect ethernet cable** before boot completes
3. **Access via SSH** over ethernet
4. **Fix network config:**
   ```bash
   uci delete network.@device[0]
   uci commit network
   reboot
   ```

---

## Performance Expectations

When fully working:

- **Signal strength:** -30 to -70 dBm (good to excellent)
- **Link speed:** Up to 135 Mbps @ 40MHz channel
- **Latency:** 40-50ms to internet
- **Throughput:** 10-50 Mbps typical (depends on signal)
- **Frequency:** 2.4GHz only (5GHz not supported by UWE5622)


# AP Mode

```bash
# 1. Stop any running wpa_supplicant
killall wpad 2>/dev/null

# 2. Create hostapd config
cat > /tmp/hostapd.conf << 'EOF'
interface=wlan0
driver=nl80211
ssid=OpenWrt-Test
hw_mode=g
channel=6
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=testpassword123
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# 3. Bring up wlan0
ip link set wlan0 up

# 4. Start hostapd
/usr/sbin/wpad hostapd -B /tmp/hostapd.conf

# 5. Assign IP to wlan0
ip addr add 192.168.10.1/24 dev wlan0

# 6. Start DHCP server (if dnsmasq not running)
dnsmasq -i wlan0 --dhcp-range=192.168.10.100,192.168.10.200,12h

# If not then Check if hostapd process is running
ps | grep hostapd

# Check recent hostapd logs (not just errors)
logread | grep hostapd | tail -30

# Try starting hostapd in foreground to see errors
killall wpad 2>/dev/null
/usr/sbin/wpad hostapd /tmp/hostapd.conf

## Properly with DHCP:

# Run hostapd in background
/usr/sbin/wpad hostapd -B /tmp/hostapd.conf

# Configure IP and DHCP
ip addr add 192.168.10.1/24 dev wlan0

# Stop existing dnsmasq
/etc/init.d/dnsmasq stop

# Start dnsmasq for wlan0
dnsmasq -i wlan0 --dhcp-range=192.168.10.100,192.168.10.200,12h --interface=wlan0 --bind-interfaces

# Enable IP forwarding (for internet sharing)
echo 1 > /proc/sys/net/ipv4/ip_forward

# NAT for internet sharing (if you want to share eth0 internet)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```
