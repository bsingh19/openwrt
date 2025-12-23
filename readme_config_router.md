# Orange Pi Zero 3: Ethernet-to-WiFi Router Setup Guide

This guide explains how to configure your Orange Pi Zero 3 running OpenWrt to use Ethernet as the internet source, set up Wi-Fi in AP mode, enable DHCP for Wi-Fi clients, and bridge Ethernet and Wi-Fi so wireless devices can access the internet.

---

## 1. Connect Ethernet and Verify DHCP

1. Plug in the Ethernet cable to the Orange Pi.
2. Ensure the network config uses DHCP for Ethernet:

```bash
cat /etc/config/network
```

```bash
# Disable Wi-Fi
uci set wireless.@wifi-device[0].disabled='1'
uci commit wireless
wifi reload
```

**Correct config for WAN (Ethernet):**
```
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
    list ports 'eth0'                 
    list ports 'wlan0'                
                                      
config interface 'lan'       
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'
    option ip6assign '60'
```

3. Restart networking:
```bash
# DNS MASQ should be running
/etc/init.d/dnsmasq status

# Restart 
/etc/init.d/network restart
```

4. Check IP address:
```bash
ip addr show eth0
```

**Expected:** eth0 has a valid IP from your router.

---

## 2. Test Internet Connectivity

1. Ping a public IP:
```bash
ping -c 3 8.8.8.8
```
2. Ping a domain (DNS test):
```bash
ping -c 3 google.com
```

**Success:** Replies received.

---

## 3. Configure Wi-Fi in AP Mode

1. Create hostapd config:
```bash
cat > /tmp/hostapd.conf << 'EOF'
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
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
```

2. Bring up Wi-Fi interface:
```bash
ip link set wlan0 up
```

3. Start hostapd:
```bash
/usr/sbin/wpad hostapd -B /tmp/hostapd.conf
```

---

## 4. Enable DHCP Server for Wi-Fi Clients

1. Assign IP to wlan0:
```bash
ip addr add 192.168.20.1/24 dev wlan0
```

2. Start DHCP server:
```bash
dnsmasq -i wlan0 --dhcp-range=192.168.20.100,192.168.20.200,12h --interface=wlan0 --bind-interfaces
```

---

## 5. Bridge Ethernet and Wi-Fi (LAN Bridging)

1. Create a bridge device:
```bash
uci set network.lan=device
uci set network.lan.ifname='eth0 wlan0'
uci set network.lan.proto='dhcp'
uci commit network
/etc/init.d/network restart
```

2. Alternatively, edit /etc/config/network:
```
config device
    option name 'br-lan'
    option type 'bridge'
    list ports 'eth0'
    list ports 'wlan0'

config interface 'lan'
    option device 'br-lan'
    option proto 'dhcp'
```

---

## 6. Enable IP Forwarding and NAT (if needed)

1. Enable IP forwarding:
```bash
echo 1 > /proc/sys/net/ipv4/ip_forward
```

2. Set up NAT (if not using bridge):
```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

---

## 7. Connect and Test

1. Connect a device to the Wi-Fi AP.
2. Check it receives an IP in the 192.168.20.x range.
3. Test internet access from the Wi-Fi client:
```bash
ping -c 3 8.8.8.8
ping -c 3 google.com
```

---

## Troubleshooting
- If Wi-Fi clients do not get IPs, check dnsmasq logs: `logread | grep dnsmasq`
- If clients cannot reach the internet, verify bridge config and NAT rules.
- Ensure both eth0 and wlan0 are UP and part of the bridge.

---

## Summary
This setup turns your Orange Pi Zero 3 into a simple router: Ethernet provides internet, Wi-Fi AP shares it, and DHCP/NAT/bridge ensure clients can connect and browse.
