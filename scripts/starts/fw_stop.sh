#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
. "$CRASHDIR"/libs/get_config.sh
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/starts/fw_getlanip.sh && getlanip #获取局域网host地址
#缺省值
[ -z "$common_ports" ] && common_ports='ON'
[ -z "$multiport" ] && multiport='22,80,443,8080,8443'
[ "$common_ports" = "ON" ] && ports="-m multiport --dports $multiport"
[ -f "$CRASHDIR"/configs/gateway.cfg ] && . "$CRASHDIR"/configs/gateway.cfg
accept_ports=$(echo "$fw_wan_ports,$vms_port,$sss_port" | sed "s/,,/,/g ;s/^,// ;s/,$//")
#重置iptables相关规则
ckcmd iptables && {
	ckcmd iptables && iptables -h | grep -q '\-w' && iptable='iptables -w' || iptable=iptables
	#dns
	$iptable -t nat -D PREROUTING -p tcp --dport 53 -j shellcrash_dns 2>/dev/null
	$iptable -t nat -D PREROUTING -p udp --dport 53 -j shellcrash_dns 2>/dev/null
	$iptable -t nat -D OUTPUT -p udp --dport 53 -j shellcrash_dns_out 2>/dev/null
	$iptable -t nat -D OUTPUT -p tcp --dport 53 -j shellcrash_dns_out 2>/dev/null
	#redir
	$iptable -t nat -D PREROUTING -p tcp $ports -j shellcrash 2>/dev/null
	$iptable -t nat -D PREROUTING -p tcp -d 28.0.0.0/8 -j shellcrash 2>/dev/null
	$iptable -t nat -D OUTPUT -p tcp $ports -j shellcrash_out 2>/dev/null
	$iptable -t nat -D OUTPUT -p tcp -d 28.0.0.0/8 -j shellcrash_out 2>/dev/null
	#vm_dns
	$iptable -t nat -D PREROUTING -p tcp --dport 53 -j shellcrash_vm_dns 2>/dev/null
	$iptable -t nat -D PREROUTING -p udp --dport 53 -j shellcrash_vm_dns 2>/dev/null
	#vm_redir
	$iptable -t nat -D PREROUTING -p tcp $ports -j shellcrash_vm 2>/dev/null
	$iptable -t nat -D PREROUTING -p tcp -d 28.0.0.0/8 -j shellcrash_vm 2>/dev/null
	#TPROXY&tun
	$iptable -t mangle -D PREROUTING -p tcp $ports -j shellcrash_mark 2>/dev/null
	$iptable -t mangle -D PREROUTING -p udp $ports -j shellcrash_mark 2>/dev/null
	$iptable -t mangle -D PREROUTING -p tcp -d 28.0.0.0/8 -j shellcrash_mark 2>/dev/null
	$iptable -t mangle -D PREROUTING -p udp -d 28.0.0.0/8 -j shellcrash_mark 2>/dev/null
	$iptable -t mangle -D OUTPUT -p tcp $ports -j shellcrash_mark_out 2>/dev/null
	$iptable -t mangle -D OUTPUT -p udp $ports -j shellcrash_mark_out 2>/dev/null
	$iptable -t mangle -D OUTPUT -p tcp -d 28.0.0.0/8 -j shellcrash_mark_out 2>/dev/null
	$iptable -t mangle -D OUTPUT -p udp -d 28.0.0.0/8 -j shellcrash_mark_out 2>/dev/null
	$iptable -t mangle -D PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port 2>/dev/null
	$iptable -t mangle -D PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port 2>/dev/null
	#tun
	$iptable -D FORWARD -o utun -j ACCEPT 2>/dev/null
	#屏蔽QUIC
	[ "$dns_mod" != "fake-ip" ] && [ "$cn_ip_route" != "OFF" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
	$iptable -D INPUT -p udp --dport 443 $set_cn_ip -j REJECT 2>/dev/null
	$iptable -D FORWARD -p udp --dport 443 -o utun $set_cn_ip -j REJECT 2>/dev/null
	#公网访问
	$iptable -D INPUT -i lo -j ACCEPT 2>/dev/null
	for ip in $host_ipv4; do
		$iptable -D INPUT -s $ip -j ACCEPT 2>/dev/null
	done
	$iptable -D INPUT -p tcp -m multiport --dports "$accept_ports" -j ACCEPT 2>/dev/null
	$iptable -D INPUT -p udp -m multiport --dports "$accept_ports" -j ACCEPT 2>/dev/null
	$iptable -D INPUT -p tcp -m multiport --dports "$mix_port,$db_port,$dns_port" -j REJECT 2>/dev/null
	$iptable -D INPUT -p udp -m multiport --dports "$mix_port,$db_port,$dns_port" -j REJECT 2>/dev/null
	#清理shellcrash自建表
	for text in shellcrash_dns shellcrash shellcrash_out shellcrash_dns_out shellcrash_vm shellcrash_vm_dns; do
		$iptable -t nat -F "$text" 2>/dev/null
		$iptable -t nat -X "$text" 2>/dev/null
	done
	for text in shellcrash_mark shellcrash_mark_out; do
		$iptable -t mangle -F "$text" 2>/dev/null
		$iptable -t mangle -X "$text" 2>/dev/null
	done
}
#重置ipv6规则
ckcmd ip6tables && {
	ckcmd ip6tables && ip6tables -h | grep -q '\-w' && ip6table='ip6tables -w' || ip6table=ip6tables
	#dns
	$ip6table -t nat -D PREROUTING -p tcp --dport 53 -j shellcrashv6_dns 2>/dev/null
	$ip6table -t nat -D PREROUTING -p udp --dport 53 -j shellcrashv6_dns 2>/dev/null
	#redir
	$ip6table -t nat -D PREROUTING -p tcp $ports -j shellcrashv6 2>/dev/null
	$ip6table -t nat -D PREROUTING -p tcp -d fc00::/16 -j shellcrashv6 2>/dev/null
	$ip6table -t nat -D OUTPUT -p tcp $ports -j shellcrashv6_out 2>/dev/null
	$ip6table -t nat -D OUTPUT -p tcp -d fc00::/16 -j shellcrashv6_out 2>/dev/null
	$ip6table -D INPUT -p tcp --dport 53 -j REJECT 2>/dev/null
	$ip6table -D INPUT -p udp --dport 53 -j REJECT 2>/dev/null
	#mark
	$ip6table -t mangle -D PREROUTING -p tcp $ports -j shellcrashv6_mark 2>/dev/null
	$ip6table -t mangle -D PREROUTING -p udp $ports -j shellcrashv6_mark 2>/dev/null
	$ip6table -t mangle -D PREROUTING -p tcp -d fc00::/16 -j shellcrashv6_mark 2>/dev/null
	$ip6table -t mangle -D PREROUTING -p udp -d fc00::/16 -j shellcrashv6_mark 2>/dev/null
	$ip6table -t mangle -D OUTPUT -p tcp $ports -j shellcrashv6_mark_out 2>/dev/null
	$ip6table -t mangle -D OUTPUT -p udp $ports -j shellcrashv6_mark_out 2>/dev/null
	$ip6table -t mangle -D OUTPUT -p tcp -d fc00::/16 -j shellcrashv6_mark_out 2>/dev/null
	$ip6table -t mangle -D OUTPUT -p udp -d fc00::/16 -j shellcrashv6_mark_out 2>/dev/null
	$ip6table -D INPUT -p udp --dport 443 $set_cn_ip -j REJECT 2>/dev/null
	$ip6table -t mangle -D PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port 2>/dev/null
	$ip6table -t mangle -D PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port 2>/dev/null
	#tun
	$ip6table -D FORWARD -o utun -j ACCEPT 2>/dev/null
	#屏蔽QUIC
	[ "$dns_mod" != "fake-ip" ] && [ "$cn_ip_route" != "OFF" ] && set_cn_ip6='-m set ! --match-set cn_ip6 dst'
	$ip6table -D INPUT -p udp --dport 443 $set_cn_ip6 -j REJECT 2>/dev/null
	$ip6table -D FORWARD -p udp --dport 443 -o utun $set_cn_ip6 -j REJECT 2>/dev/null
	#公网访问
	$ip6table -D INPUT -i lo -j ACCEPT 2>/dev/null
	for ip in $host_ipv6; do
		$ip6table -D INPUT -s $ip -j ACCEPT 2>/dev/null
	done
	$ip6table -D INPUT -p tcp -m multiport --dports "$accept_ports" -j ACCEPT 2>/dev/null
	$ip6table -D INPUT -p udp -m multiport --dports "$accept_ports" -j ACCEPT 2>/dev/null
	$ip6table -D INPUT -p tcp -m multiport --dports "$mix_port,$db_port,$dns_port" -j REJECT 2>/dev/null
	$ip6table -D INPUT -p udp -m multiport --dports "$mix_port,$db_port,$dns_port" -j REJECT 2>/dev/null
	#清理shellcrash自建表
	for text in shellcrashv6_dns shellcrashv6 shellcrashv6_out; do
		$ip6table -t nat -F "$text" 2>/dev/null
		$ip6table -t nat -X "$text" 2>/dev/null
	done
	for text in shellcrashv6_mark shellcrashv6_mark_out; do
		$ip6table -t mangle -F "$text" 2>/dev/null
		$ip6table -t mangle -X "$text" 2>/dev/null
	done
	$ip6table -t mangle -F shellcrashv6_mark 2>/dev/null
	$ip6table -t mangle -X shellcrashv6_mark 2>/dev/null
}
#清理ipset规则
ipset destroy cn_ip >/dev/null 2>&1
ipset destroy cn_ip6 >/dev/null 2>&1
#清理路由规则
ip rule del fwmark $fwmark table $table 2>/dev/null
ip route flush table $table 2>/dev/null
ip -6 rule del fwmark $fwmark table $((table + 1)) 2>/dev/null
ip -6 route flush table $((table + 1)) 2>/dev/null
#重置nftables相关规则
ckcmd nft && nft delete table inet shellcrash >/dev/null 2>&1
#还原防火墙文件
[ -s /etc/init.d/firewall.bak ] && mv -f /etc/init.d/firewall.bak /etc/init.d/firewall
#others
[ "$systype" != 'container' ] && sed -i '/shellcrash-dns-repair/d' /etc/resolv.conf >/dev/null 2>&1

