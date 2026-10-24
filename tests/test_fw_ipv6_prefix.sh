#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/starts/fw_getlanip.sh"

assert_equal() {
    if [ "$1" != "$2" ]; then
        echo "expected: [$1]" >&2
        echo "actual:   [$2]" >&2
        exit 1
    fi
}

route_output='default via fe80::1 dev eth0
default from 240e:1234:5600::/56 via fe80::1 dev pppoe-wan
2408:8266:501:2443::/64 dev enp2s0 proto kernel
2606:4700::/48 via fe80::2 dev eth0
unreachable 240e:1234:5600::/48 dev lo'
actual=$(printf '%s\n' "$route_output" | ipv6_route_prefixes | sort -u)
expected='2408:8266:501:2443::/64
240e:1234:5600::/56'
assert_equal "$expected" "$actual"

# OpenWrt prefers the LAN assignment over the wider delegated prefix.
systype=mi_snapshot
lan_ifaces='br-lan'
ubus() {
    printf '%s\n' '{ "l3_device": "br-lan" }'
}
ip() {
    case "$*" in
    '-6 route show dev br-lan')
        echo 'default from 240e:1234:5600::/56 via fe80::1 dev br-lan'
        echo '240e:1234:5600:1::/64 dev br-lan proto static'
        ;;
    '-6 route show default') echo 'default from 240e:1234:5600::/56 via fe80::1 dev pppoe-wan' ;;
    esac
}
actual=$(get_ipv6_prefixes)
assert_equal '240e:1234:5600:1::/64' "$actual"

# OpenWrt falls back to source-specific routes when its LAN route is hidden.
lan_ifaces=
ubus() {
    return 0
}
ip() {
    case "$*" in
    '-6 route show default') echo 'default from 240e:1234:5600::/56 via fe80::1 dev pppoe-wan' ;;
    esac
}
actual=$(get_ipv6_prefixes)
assert_equal '240e:1234:5600::/56' "$actual"

# Standard Linux uses the directly connected route on the discovered LAN.
systype=container
lan_ifaces='enp2s0'
ip() {
    case "$*" in
    '-6 route show dev enp2s0') echo '2408:8266:501:2443::/64 dev enp2s0 proto kernel metric 256' ;;
    esac
}
actual=$(get_ipv6_prefixes)
assert_equal '2408:8266:501:2443::/64' "$actual"

# BusyBox based router firmware does not need route protocol metadata.
systype=Padavan
lan_ifaces='br0'
ip() {
    case "$*" in
    '-6 route show dev br0') echo '2001:db8:abcd:1::/64 dev br0 metric 256' ;;
    esac
}
actual=$(get_ipv6_prefixes)
assert_equal '2001:db8:abcd:1::/64' "$actual"

ts_service=ON
wg_service=OFF
build_host_ipv6 '2408:8266:501:2443::/64 invalid-value'
assert_equal '2408:8266:501:2443::/64 fd00::/8 fd7a:115c:a1e0::/48 fe80::/10' "$host_ipv6"

echo 'IPv6 prefix tests passed'
