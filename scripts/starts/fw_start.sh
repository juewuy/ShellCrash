#!/bin/sh
# Copyright (C) Juewuy

#获取局域网host地址
. "$CRASHDIR"/starts/fw_getlanip.sh && getlanip
#缺省值
[ -z "$macfilter_type" ] && macfilter_type='黑名单'
[ -z "$common_ports" ] && common_ports='ON'
[ -z "$multiport" ] && multiport='22,80,443,8080,8443'
[ "$common_ports" = "ON" ] && ports="-m multiport --dports $multiport"
[ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod='Redir模式'
[ -z "$dns_mod" ] && dns_mod='redir_host'
[ -z "$redir_mod" ] && firewall_area='4'

#设置策略路由
[ "$firewall_area" != 4 ] && {
	[ "$redir_mod" = "Tproxy模式" ] && ip route add local default dev lo table $table 2>/dev/null
	[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && {
		i=1
		while [ -z "$(ip route list | grep utun)" -a "$i" -le 29 ]; do
			sleep 1
			i=$((i + 1))
		done
		if [ -z "$(ip route list | grep utun)" ]; then
			logger "找不到tun模块，放弃启动tun相关防火墙规则！" 31
		else
			ip route add default dev utun table $table && tun_statu=true
		fi
	}
	[ "$firewall_area" = 5 ] && ip route add default via $bypass_host table $table 2>/dev/null
	[ "$redir_mod" != "Redir模式" ] && ip rule add fwmark $fwmark table $table 2>/dev/null
}
#添加ipv6路由
[ "$ipv6_redir" = "ON" -a "$firewall_area" -le 3 ] && {
	[ "$redir_mod" = "Tproxy模式" ] && ip -6 route add local default dev lo table $((table + 1)) 2>/dev/null
	[ -n "$(ip route list | grep utun)" ] && ip -6 route add default dev utun table $((table + 1)) 2>/dev/null
	[ "$redir_mod" != "Redir模式" ] && ip -6 rule add fwmark $fwmark table $((table + 1)) 2>/dev/null
}
#判断代理用途
[ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && local_proxy=true
[ "$firewall_area" = 1 -o "$firewall_area" = 3 -o "$firewall_area" = 5 ] && lan_proxy=true
#防火墙配置
[ "$firewall_mod" = 'iptables' ] && . "$CRASHDIR"/starts/fw_iptables.sh && start_iptables
[ "$firewall_mod" = 'nftables' ] && . "$CRASHDIR"/starts/fw_nftables.sh && start_nftables
#修复部分虚拟机dns查询失败的问题
[ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && [ -z "$(grep '127.0.0.1' /etc/resolv.conf 2>/dev/null)" ] && [ "$systype" != 'container' ] && {
	line=$(grep -n 'nameserver' /etc/resolv.conf | awk -F: 'FNR==1{print $1}')
	sed -i "$line i\nameserver 127.0.0.1 #shellcrash-dns-repair" /etc/resolv.conf >/dev/null 2>&1
}
#移除openwrt-dnsmasq的DNS重定向
[ "$(uci get dhcp.@dnsmasq[0].dns_redirect 2>/dev/null)" = 1 ] && {
		uci del dhcp.@dnsmasq[0].dns_redirect
		uci commit dhcp.@dnsmasq[0]
}
