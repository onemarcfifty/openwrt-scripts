#!/bin/ash

# Install packages
opkg update

The package name has changed
#opkg install wireguard
opkg install wireguard-tools
 
# Configuration parameters
WG_IF="wg0"
WG_PORT="51820"
WG_ADDR="192.168.9.1/24"
WG_ADDR6="fdf1:7610:d152:3a9c::1/64"

# Generate and exchange the keys
umask u=rw,g=,o=
wg genkey | tee wgserver.key | wg pubkey > wgserver.pub
wg genpsk > wg.psk
 
WG_KEY="$(cat wgserver.key)"
WG_PSK="$(cat wg.psk)"
WG_PUB="$(cat wgserver.pub)"

# Configure firewall
uci rename firewall.@zone[0]="lan"
uci rename firewall.@zone[1]="wan"
uci rename firewall.@forwarding[0]="lan_wan"
uci del_list firewall.lan.network="${WG_IF}"
uci add_list firewall.lan.network="${WG_IF}"
uci -q delete firewall.wg
uci set firewall.wg="rule"
uci set firewall.wg.name="Allow-WireGuard"
uci set firewall.wg.src="wan"
uci set firewall.wg.dest_port="${WG_PORT}"
uci set firewall.wg.proto="udp"
uci set firewall.wg.target="ACCEPT"
uci commit firewall
/etc/init.d/firewall restart

# Configure network
uci -q delete network.${WG_IF}
uci set network.${WG_IF}="interface"
uci set network.${WG_IF}.proto="wireguard"
uci set network.${WG_IF}.private_key="${WG_KEY}"
uci set network.${WG_IF}.listen_port="${WG_PORT}"
uci add_list network.${WG_IF}.addresses="${WG_ADDR}"
uci add_list network.${WG_IF}.addresses="${WG_ADDR6}"
 
# Add VPN peers
uci -q delete network.wgclient
uci set network.wgclient="wireguard_${WG_IF}"
uci set network.wgclient.public_key="${WG_PUB}"
uci set network.wgclient.preshared_key="${WG_PSK}"
uci add_list network.wgclient.allowed_ips="${WG_ADDR%.*}.0/${WG_ADDR#*/}"
uci add_list network.wgclient.allowed_ips="${WG_ADDR6%/*}/${WG_ADDR6#*/}"
uci commit network
/etc/init.d/network restart

