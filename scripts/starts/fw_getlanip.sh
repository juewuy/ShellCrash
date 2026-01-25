
getlanip() { #获取局域网host地址
    i=1
    while [ "$i" -le "20" ]; do
        host_ipv4=$(ip route show scope link | grep -Ev 'wan|utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | awk '{print $1}') #ipv4局域网网段
        [ "$ipv6_redir" = "ON" ] && host_ipv6=$(ip -6 route show default | awk '{print $3}' | tr '\n' ' ' | sed 's/ $//') #ipv6公网地址段
        [ -f "$TMPDIR"/ShellCrash.log ] && break
        [ -n "$host_ipv4" -a "$ipv6_redir" != "ON" ] && break
        [ -n "$host_ipv4" -a -n "$host_ipv6" ] && break
        sleep 1 && i=$((i + 1))
    done
	#tailscale
	[ "$ts_service" = ON ] && {
		ts_host_ipv4=' 100.64.0.0/10'
		ts_host_ipv6=' fd7a:115c:a1e0::/48'
	}
    #添加自定义ipv4局域网网段
    if [ "$replace_default_host_ipv4" == "ON" ]; then
        host_ipv4="$cust_host_ipv4"
    else
        host_ipv4=$(echo $host_ipv4 $cust_host_ipv4$ts_host_ipv4| tr '\n' ' ' | sed 's/ $//')
    fi
    #缺省配置
    [ -z "$host_ipv4" ] && {
		host_ipv4='192.168.0.0/16 10.0.0.0/12 172.16.0.0/12'
		logger "无法获取本地LAN-IPV4网段，请前往流量过滤设置界面设置自定义网段！" 31
	}
    host_ipv6="fe80::/10 fd00::/8 $host_ipv6$ts_host_ipv6"
    #获取本机出口IP地址
    local_ipv4=$(ip route 2>&1 | grep -Ev 'utun|iot|docker|linkdown' | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
    [ -z "$local_ipv4" ] && local_ipv4=$(ip route 2>&1 | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
    #保留地址
    [ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
    [ -z "$reserve_ipv6" ] && reserve_ipv6="::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 100::/64 2001::/32 2001:20::/28 2001:db8::/32 2002::/16 fe80::/10 ff00::/8"
}