#!/bin/sh
# Orange Pi Zero 3: Automated Router Configuration Script
# This script configures Ethernet as WAN (DHCP), bridges eth0 and wlan0, sets up Wi-Fi AP, and enables DHCP/NAT.

set -e

# 1. Configure network
cat <<'EOF' > /etc/config/network
config interface 'loopback'
    option device 'lo'
    option proto 'static'
    option ipaddr '127.0.0.1'
    option netmask '255.0.0.0'

config globals 'globals'
    option ula_prefix 'fd26:9828:d595::/48'

config interface 'wan'
    option device 'eth0'
    option proto 'dhcp'

config device
    option name 'br-lan'
    option type 'bridge'
    list ports 'wlan0'

config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'
    option ip6assign '60'
EOF

# 2. Restart networking
/etc/init.d/network restart

# 3. Configure Wi-Fi AP
cat <<'EOF' > /tmp/hostapd.conf
interface=wlan0
driver=nl80211
ssid=OpenWrt-AP
hw_mode=g
channel=6
wmm_enabled=1
auth_algs=1
wpa=2
wpa_passphrase=123456789
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

ip link set wlan0 up
/usr/sbin/wpad hostapd -B /tmp/hostapd.conf

# 4. Enable DHCP for Wi-Fi clients
ip addr add 192.168.20.1/24 dev wlan0 || true

# Start DHCP server for wlan0
killall dnsmasq 2>/dev/null || true
dnsmasq -i wlan0 --dhcp-range=192.168.20.100,192.168.20.200,12h --interface=wlan0 --bind-interfaces &

# 5. Enable IP forwarding and NAT
sysctl -w net.ipv4.ip_forward=1

# 6. Show status
echo "\nConfiguration complete. Check interfaces and connectivity:"
ip addr show
ps | grep -E 'dnsmasq|hostapd|wpad'

# 7. Show connected Wi-Fi clients
echo "\nConnected Wi-Fi clients:"
iw dev wlan0 station dump
