#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)

reserve_ipv4='0.0.0.0/8 127.0.0.0/8'
reserve_ipv6='::/128 ::1/128 fe80::/10 ff00::/8'
host_ipv4='192.168.1.0/24'
local_ipv4='192.168.1.1'
host_ipv6='2001:db8:1::/64 fd00::/8 fe80::/10'
common_ports=OFF
ports=
PORTS=
mix_port=7890
redir_port=7892
tproxy_port=7893
dns_redir_port=1053
routing_mark=7894
fwmark=7892
firewall_area=3
macfilter_type='黑名单'
cn_ip_route=OFF
dns_mod=route
ipv6_redir=ON
quic_rj=OFF
lan_proxy=true
local_proxy=true
redir_mod=Tproxy
tun_statu=false
vm_redir=OFF
fw_wan=ON
fw_wan_ports=
vms_port=
sss_port=
db_port=9090
systype=linux
CRASHDIR=/nonexistent
BINDIR=/nonexistent

nft() {
    if [ "$1" = list ] && [ "$2" = set ]; then
        return 1
    fi
    printf '%s' "$1"
    shift
    printf ' %s' "$@"
    printf '\n'
}

modprobe() {
    return 0
}

. "$ROOT/scripts/starts/fw_nftables.sh"
rules=$(start_nftables || :)

require_rule() {
    if ! printf '%s\n' "$rules" | grep -Fq "$1"; then
        echo "missing generated rule: $1" >&2
        exit 1
    fi
}

require_rule 'add set inet shellcrash lan_ip6'
require_rule 'flags interval ; auto-merge'
require_rule 'add element inet shellcrash lan_ip6'
require_rule 'add rule inet shellcrash prerouting ip6 daddr @lan_ip6 return'
require_rule 'add rule inet shellcrash prerouting ip6 saddr != @lan_ip6 return'
require_rule 'add rule inet shellcrash prerouting_dns ip6 saddr != @lan_ip6 return'
require_rule 'add rule inet shellcrash input ip6 saddr @lan_ip6 accept'
require_rule 'add rule inet shellcrash output ip6 daddr @lan_ip6 return'

if printf '%s\n' "$rules" | grep -Fq 'add rule inet shellcrash output ip6 saddr'; then
    echo 'output must not depend on a dynamic IPv6 source prefix' >&2
    exit 1
fi

echo 'nftables IPv6 rule generation tests passed'
