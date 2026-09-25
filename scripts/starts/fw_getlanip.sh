ipv6_route_prefixes() {
    awk '
    function is_global_prefix(value) {
        return value ~ /^[23][0-9A-Fa-f]*:/ && value ~ /\/[0-9]+$/
    }
    $1 == "default" {
        for (i = 1; i < NF; i++) {
            if ($i == "from" && is_global_prefix($(i + 1)))
                print $(i + 1)
        }
        next
    }
    is_global_prefix($1) {
        via = 0
        for (i = 1; i <= NF; i++) {
            if ($i == "via")
                via = 1
        }
        if (!via)
            print $1
    }'
}

get_lan_ifaces() {
    ip route show scope link 2>/dev/null |
        grep -Ev 'default|ppp|wan|utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet|wgs|multicast|anycast' |
        awk '{for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); break}}' |
        grep -v '^lo$' |
        sort -u
}

get_openwrt_lan_ifaces() {
    if command -v ubus >/dev/null 2>&1; then
        ubus -S call network.interface.lan status 2>/dev/null |
            awk -F '"' '$2 == "l3_device" {print $4}'
    fi
    printf '%s\n' $lan_ifaces
}

get_ipv6_prefixes_openwrt() {
    ipv6_prefixes=$(
        for ipv6_iface in $(get_openwrt_lan_ifaces | sort -u); do
            ip -6 route show dev "$ipv6_iface" 2>/dev/null |
                grep -v '^default' |
                ipv6_route_prefixes
        done
    )
    # Some OpenWrt variants do not expose the LAN route through BusyBox ip.
    # In that case, use netifd's source-specific default route as a fallback.
    [ -n "$ipv6_prefixes" ] || ipv6_prefixes=$(
        ip -6 route show default 2>/dev/null | ipv6_route_prefixes
    )
    printf '%s\n' "$ipv6_prefixes" | sort -u
}

get_ipv6_prefixes_linux() {
    ipv6_prefixes=$(
        for ipv6_iface in $lan_ifaces; do
            ip -6 route show dev "$ipv6_iface" 2>/dev/null | grep -v '^default'
        done | ipv6_route_prefixes | sort -u
    )
    # A host may use one interface for both its uplink and LAN, or may not
    # have an IPv4 LAN route. Fall back to directly connected global routes.
    [ -n "$ipv6_prefixes" ] || ipv6_prefixes=$(
        ip -6 route show 2>/dev/null |
            grep -Ev 'unreachable|prohibit|blackhole|ppp|wan|utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet|wgs|multicast|anycast' |
            ipv6_route_prefixes |
            sort -u
    )
    printf '%s\n' "$ipv6_prefixes"
}

get_ipv6_prefixes_router() {
    # Padavan/Asuswrt and other BusyBox based firmware do not consistently
    # expose route protocol metadata. Only depend on route shape and devices.
    ipv6_prefixes=$(
        for ipv6_iface in $lan_ifaces; do
            ip -6 route show dev "$ipv6_iface" 2>/dev/null |
                grep -v '^default' |
                ipv6_route_prefixes
        done
    )
    [ -n "$ipv6_prefixes" ] || ipv6_prefixes=$(
        ip -6 route show default 2>/dev/null | ipv6_route_prefixes
    )
    printf '%s\n' "$ipv6_prefixes" | sort -u
}

get_ipv6_prefixes_fallback() {
    # Generic fallback for systems unknown to ShellCrash. Avoid fixed field
    # positions and route protocol names, which differ across ip variants.
    ip -6 route show 2>/dev/null | ipv6_route_prefixes | sort -u
}

get_ipv6_platform() {
    case "$systype" in
    mi_snapshot | ng_snapshot)
        echo openwrt
        return
        ;;
    Padavan | asusrouter)
        echo router
        return
        ;;
    container)
        echo linux
        return
        ;;
    esac

    if [ -f /etc/openwrt_release ] || { [ -f /etc/rc.common ] && command -v uci >/dev/null 2>&1; }; then
        echo openwrt
    elif [ "$(uname -s 2>/dev/null)" = Linux ]; then
        echo linux
    else
        echo fallback
    fi
}

get_ipv6_prefixes() {
    [ -n "$lan_ifaces" ] || lan_ifaces=$(get_lan_ifaces)
    case "$(get_ipv6_platform)" in
    openwrt) get_ipv6_prefixes_openwrt ;;
    router) get_ipv6_prefixes_router ;;
    linux) get_ipv6_prefixes_linux ;;
    *) get_ipv6_prefixes_fallback ;;
    esac
}

build_host_ipv6() {
    host_ipv6="fe80::/10 fd00::/8 $1"
    [ "$ts_service" = ON ] && host_ipv6="$host_ipv6 fd7a:115c:a1e0::/48"
    if [ "$wg_service" = ON ]; then
        [ -f "$CRASHDIR"/configs/gateway.cfg ] && . "$CRASHDIR"/configs/gateway.cfg
        [ -n "$wg_ipv6" ] && host_ipv6="$host_ipv6 $wg_ipv6"
    fi
    # Only pass prefix-shaped values to firewall generators and keep the
    # result stable so the watcher can compare it cheaply.
    host_ipv6=$(printf '%s\n' "$host_ipv6" |
        tr ' ' '\n' |
        awk '/^[0-9A-Fa-f:]+\/[0-9]+$/ {print}' |
        sort -u |
        tr '\n' ' ' |
        sed 's/ $//')
}

getlanip() { #获取局域网host地址
    i=1
    while [ "$i" -le "20" ]; do
        #ipv4局域网网段
        host_ipv4=$(ip route show scope link | grep -Ev 'default|wan|utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet|wgs|multicast|anycast' | awk '{print $1}')
        #ipv6局域网网段
        if [ "$ipv6_redir" = "ON" ]; then
            lan_ifaces=$(get_lan_ifaces)
            detected_host_ipv6=$(get_ipv6_prefixes)
        fi
        [ -f "$TMPDIR"/ShellCrash.log ] && break
        [ -n "$host_ipv4" ] && [ "$ipv6_redir" != "ON" ] && break
        [ -n "$host_ipv4" ] && [ -n "$detected_host_ipv6" ] && break
        sleep 1 && i=$((i + 1))
    done
    #Tailscale
    [ "$ts_service" = ON ] && ts_host_ipv4=' 100.64.0.0/10'
    #Wireguard
    if [ "$wg_service" = ON ]; then
        . "$CRASHDIR"/configs/gateway.cfg
        wg_host_ipv4=" $wg_ipv4"
    fi
    #添加自定义ipv4局域网网段
    if [ "$replace_default_host_ipv4" = "ON" ]; then
        host_ipv4="$cust_host_ipv4"
    else
        host_ipv4=$(echo "$host_ipv4 $cust_host_ipv4$ts_host_ipv4$wg_host_ipv4" | tr '\n' ' ' | sed 's/ $//')
    fi
    #缺省配置
    [ -z "$host_ipv4" ] && {
        host_ipv4='192.168.0.0/16 10.0.0.0/12 172.16.0.0/12'
        logger "无法获取本地LAN-IPV4网段，请前往流量过滤设置界面设置自定义网段！" 31
    }
    build_host_ipv6 "$detected_host_ipv6"
    #获取本机出口IP地址
    local_ipv4=$(ip route 2>&1 | grep -Ev 'utun|iot|docker|linkdown' | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
    [ -z "$local_ipv4" ] && local_ipv4=$(ip route 2>&1 | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
    #保留地址
    [ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
    [ -z "$reserve_ipv6" ] && reserve_ipv6="::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 100::/64 2001::/32 2001:20::/28 2001:db8::/32 2002::/16 fe80::/10 ff00::/8"
}
