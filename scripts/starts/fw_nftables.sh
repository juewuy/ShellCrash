#!/bin/sh
# Copyright (C) Juewuy

RESERVED_IP=$(echo $reserve_ipv4 | sed 's/[[:space:]]\+/, /g')
RESERVED_IP6=$(echo "$reserve_ipv6 $host_ipv6" | sed 's/[[:space:]]\+/, /g')

add_ip6_route(){
	#过滤保留地址及本机地址
	nft add rule inet shellcrash $1 ip6 daddr {$RESERVED_IP6} return
	#仅代理本机局域网网段流量
	nft add rule inet shellcrash $1 ip6 saddr != {$HOST_IP6} return
	#绕过CN_IPV6
	[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "ON" -a -f "$BINDIR"/cn_ipv6.txt ] && {
		CN_IP6=$(awk '{printf "%s, ",$1}' "$BINDIR"/cn_ipv6.txt)
		[ -n "$CN_IP6" ] && {
			nft add set inet shellcrash cn_ip6 { type ipv6_addr \; flags interval \; }
			nft add element inet shellcrash cn_ip6 { $CN_IP6 }
			nft add rule inet shellcrash $1 ip6 daddr @cn_ip6 return
		}
	}
}
start_nft_route() { #nftables-route通用工具
    #$1:name  $2:hook(prerouting/output)  $3:type(nat/mangle/filter)  $4:priority(-100/-150)
    [ "$common_ports" = "ON" ] && PORTS=$(echo $multiport | sed 's/,/, /g')
	[ "$1" = 'prerouting' ] && HOST_IP=$(echo $host_ipv4 | sed 's/[[:space:]]\+/, /g')
    [ "$1" = 'output' ] && HOST_IP="127.0.0.0/8, $(echo $local_ipv4 | sed 's/[[:space:]]\+/, /g')"
    [ "$1" = 'prerouting_vm' ] && HOST_IP="$(echo $vm_ipv4 | sed 's/[[:space:]]\+/, /g')"
    #添加新链
    nft add chain inet shellcrash $1 { type $3 hook $2 priority $4 \; }
    [ "$1" = 'prerouting_vm' ] && nft add rule inet shellcrash $1 ip saddr != {$HOST_IP} return #仅代理虚拟机流量
    #过滤dns
    nft add rule inet shellcrash $1 tcp dport 53 return
    nft add rule inet shellcrash $1 udp dport 53 return
    #防回环
    nft add rule inet shellcrash $1 meta mark $routing_mark return
    nft add rule inet shellcrash $1 meta skgid 7890 return
    [ "$firewall_area" = 5 ] && nft add rule inet shellcrash $1 ip saddr $bypass_host return
    [ -z "$ports" ] && nft add rule inet shellcrash $1 tcp dport {"$mix_port, $redir_port, $tproxy_port"} return
    #过滤常用端口
    [ -n "$PORTS" ] && {
        nft add rule inet shellcrash $1 ip daddr != {28.0.0.0/8} tcp dport != {$PORTS} return
		nft add rule inet shellcrash $1 ip daddr != {28.0.0.0/8} udp dport != {$PORTS} return
        nft add rule inet shellcrash $1 ip6 daddr != {fc00::/16} tcp dport != {$PORTS} return
		nft add rule inet shellcrash $1 ip6 daddr != {fc00::/16} udp dport != {$PORTS} return
    }
    #nft add rule inet shellcrash $1 ip saddr 28.0.0.0/8 return
    nft add rule inet shellcrash $1 ip daddr {$RESERVED_IP} return #过滤保留地址
    #过滤局域网设备
    [ "$1" = 'prerouting' ] && {
        [ "$macfilter_type" != "白名单" ] && {
            [ -s "$CRASHDIR"/configs/mac ] && {
                MAC=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/mac)
                nft add rule inet shellcrash $1 ether saddr {$MAC} return
            }
            [ -s "$CRASHDIR"/configs/ip_filter ] && {
                FL_IP=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/ip_filter)
                nft add rule inet shellcrash $1 ip saddr {$FL_IP} return
            }
            nft add rule inet shellcrash $1 ip saddr != {$HOST_IP} return #仅代理本机局域网网段流量
        }
        [ "$macfilter_type" = "白名单" ] && {
            [ -s "$CRASHDIR"/configs/mac ] && MAC=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/mac)
            [ -s "$CRASHDIR"/configs/ip_filter ] && FL_IP=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/ip_filter)
            if [ -n "$MAC" ] && [ -n "$FL_IP" ]; then
                nft add rule inet shellcrash $1 ether saddr != {$MAC} ip saddr != {$FL_IP} return
            elif [ -n "$MAC" ]; then
                nft add rule inet shellcrash $1 ether saddr != {$MAC} return
            elif [ -n "$FL_IP" ]; then
                nft add rule inet shellcrash $1 ip saddr != {$FL_IP} return
            else
                nft add rule inet shellcrash $1 ip saddr != {$HOST_IP} return #仅代理本机局域网网段流量
            fi
        }
    }
    #绕过CN-IP
    [ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "ON" -a -f "$BINDIR"/cn_ip.txt ] && {
        CN_IP=$(awk '{printf "%s, ",$1}' "$BINDIR"/cn_ip.txt)
        [ -n "$CN_IP" ] && {
			nft add set inet shellcrash cn_ip { type ipv4_addr \; flags interval \; }
			nft add element inet shellcrash cn_ip { $CN_IP }
			nft add rule inet shellcrash $1 ip daddr @cn_ip return
		}
	}
    #局域网ipv6支持
    if [ "$ipv6_redir" = "ON" -a "$1" = 'prerouting' -a "$firewall_area" != 5 ]; then
		HOST_IP6=$(echo $host_ipv6 | sed 's/[[:space:]]\+/, /g')
        add_ip6_route "$1"
    elif [ "$ipv6_redir" = "ON" -a "$1" = 'output' -a \( "$firewall_area" = 2 -o "$firewall_area" = 3 \) ]; then
        HOST_IP6="::1, $(echo $host_ipv6 | sed 's/[[:space:]]\+/, /g')"
		add_ip6_route "$1"
    else
        nft add rule inet shellcrash $1 meta nfproto ipv6 return
    fi
	#屏蔽quic
	[ "$quic_rj" = 'ON' -a "$lan_proxy" = true ] && nft add rule inet shellcrash $1 udp dport {443, 8443} return
    #添加通用路由
    nft add rule inet shellcrash "$1" "$JUMP"
    #处理特殊路由
    [ "$redir_mod" = "混合模式" ] && {
        nft add rule inet shellcrash $1 meta l4proto tcp mark set $((fwmark + 1))
        nft add chain inet shellcrash "$1"_mixtcp { type nat hook $2 priority -100 \; }
        nft add rule inet shellcrash "$1"_mixtcp mark $((fwmark + 1)) meta l4proto tcp redirect to $redir_port
    }
    #nft add rule inet shellcrash local_tproxy log prefix \"pre\" level debug
}
start_nft_dns() { #nftables-dns
	[ "$1" = 'prerouting' ] && {
		HOST_IP=$(echo $host_ipv4 | sed 's/[[:space:]]\+/, /g')
		HOST_IP6=$(echo $host_ipv6 | sed 's/[[:space:]]\+/, /g')
	}
    [ "$1" = 'output' ] && HOST_IP="127.0.0.0/8, $(echo $local_ipv4 | sed 's/[[:space:]]\+/, /g')"
    [ "$1" = 'prerouting_vm' ] && HOST_IP="$(echo $vm_ipv4 | sed 's/[[:space:]]\+/, /g')"
    nft add chain inet shellcrash "$1"_dns { type nat hook $2 priority -100 \; }
    #过滤非dns请求
    nft add rule inet shellcrash "$1"_dns udp dport != 53 return
    nft add rule inet shellcrash "$1"_dns tcp dport != 53 return
    #防回环
    nft add rule inet shellcrash "$1"_dns meta mark $routing_mark return
    nft add rule inet shellcrash "$1"_dns meta skgid { 453, 7890 } return
    [ "$firewall_area" = 5 ] && nft add rule inet shellcrash "$1"_dns ip saddr $bypass_host return
    nft add rule inet shellcrash "$1"_dns ip saddr != {$HOST_IP} return                              #屏蔽外部请求
    [ "$1" = 'prerouting' ] && nft add rule inet shellcrash "$1"_dns ip6 saddr != {$HOST_IP6} return #屏蔽外部请求
    #过滤局域网设备
    [ "$1" = 'prerouting' ] && [ -s "$CRASHDIR"/configs/mac ] && {
        MAC=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/mac)
        if [ "$macfilter_type" = "黑名单" ]; then
            nft add rule inet shellcrash "$1"_dns ether saddr {$MAC} return
        else
            nft add rule inet shellcrash "$1"_dns ether saddr != {$MAC} return
        fi
    }
    nft add rule inet shellcrash "$1"_dns udp dport 53 redirect to "$dns_redir_port"
    nft add rule inet shellcrash "$1"_dns tcp dport 53 redirect to "$dns_redir_port"
}
start_nft_wan() { #nftables公网防火墙
	HOST_IP=$(echo $host_ipv4 | sed 's/[[:space:]]\+/, /g')
	HOST_IP6=$(echo $host_ipv6 | sed 's/[[:space:]]\+/, /g')
    nft add chain inet shellcrash input { type filter hook input priority -100 \; }
    nft add rule inet shellcrash input iif lo accept #本机请求全放行
	#端口放行
	[ -f "$CRASHDIR"/configs/gateway.cfg ] && . "$CRASHDIR"/configs/gateway.cfg
	accept_ports=$(echo "$fw_wan_ports,$vms_port,$sss_port" | sed "s/,,/,/g ;s/^,// ;s/,$// ;s/,/, /")
    [ -n "$accept_ports" ] && {
		fw_wan_nfports="{ $(echo "$accept_ports" | sed 's/,/, /g') }"
		nft add rule inet shellcrash input tcp dport $fw_wan_nfports meta mark set 0x67890 accept
		nft add rule inet shellcrash input udp dport $fw_wan_nfports meta mark set 0x67890 accept
	}
	#端口拦截
	reject_ports="{ $mix_port, $db_port }"
	nft add rule inet shellcrash input ip saddr {$HOST_IP} accept
	nft add rule inet shellcrash input ip6 saddr {$HOST_IP6} accept
	nft add rule inet shellcrash input tcp dport $reject_ports reject
	nft add rule inet shellcrash input udp dport $reject_ports reject
	#fw4特殊处理
	nft list chain inet fw4 input >/dev/null 2>&1 && \
    nft list chain inet fw4 input | grep -q '67890' || \
    nft insert rule inet fw4 input meta mark 0x67890 accept 2>/dev/null
}
start_nftables() { #nftables配置总入口
    #初始化nftables
    nft add table inet shellcrash 2>/dev/null
    nft flush table inet shellcrash 2>/dev/null
    #公网访问防火墙
    [ "$fw_wan" != OFF ] && [ "$systype" != 'container' ] && start_nft_wan
    #启动DNS劫持
    [ "$firewall_area" -le 3 ] && {
        [ "$lan_proxy" = true ] && start_nft_dns prerouting prerouting #局域网dns转发
        [ "$local_proxy" = true ] && start_nft_dns output output       #本机dns转发
    }
    #分模式设置流量劫持
    [ "$redir_mod" = "Redir模式" ] && {
        JUMP="meta l4proto tcp redirect to $redir_port" #跳转劫持的具体命令
        [ "$lan_proxy" = true ] && start_nft_route prerouting prerouting nat -100
        [ "$local_proxy" = true ] && start_nft_route output output nat -100
    }
    [ "$redir_mod" = "Tproxy模式" ] && (modprobe nft_tproxy >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q nft_tproxy) && {
        JUMP="meta l4proto {tcp, udp} mark set $fwmark tproxy to :$tproxy_port" #跳转劫持的具体命令
        [ "$lan_proxy" = true ] && start_nft_route prerouting prerouting filter -150
        [ "$local_proxy" = true ] && {
            JUMP="meta l4proto {tcp, udp} mark set $fwmark" #跳转劫持的具体命令
            start_nft_route output output route -150
            nft add chain inet shellcrash mark_out { type filter hook prerouting priority -100 \; }
            nft add rule inet shellcrash mark_out meta mark $fwmark meta l4proto {tcp, udp} tproxy to :$tproxy_port
        }
    }
    [ "$tun_statu" = true ] && {
        [ "$redir_mod" = "Tun模式" ] && JUMP="meta l4proto {tcp, udp} mark set $fwmark" #跳转劫持的具体命令
        [ "$redir_mod" = "混合模式" ] && JUMP="meta l4proto udp mark set $fwmark"         #跳转劫持的具体命令
        [ "$lan_proxy" = true ] && {
            start_nft_route prerouting prerouting filter -150
            #放行流量
            nft list table inet fw4 >/dev/null 2>&1 || nft add table inet fw4
            nft list chain inet fw4 forward >/dev/null 2>&1 || nft add chain inet fw4 forward { type filter hook forward priority filter \; } 2>/dev/null
            nft list chain inet fw4 input >/dev/null 2>&1 || nft add chain inet fw4 input { type filter hook input priority filter \; } 2>/dev/null
            nft list chain inet fw4 forward | grep -q 'oifname "utun" accept' || nft insert rule inet fw4 forward oifname "utun" accept
            nft list chain inet fw4 input | grep -q 'iifname "utun" accept' || nft insert rule inet fw4 input iifname "utun" accept
        }
        [ "$local_proxy" = true ] && start_nft_route output output route -150
    }
    [ "$firewall_area" = 5 ] && {
        [ "$redir_mod" = "T&U旁路转发" ] && JUMP="meta l4proto {tcp, udp} mark set $fwmark" #跳转劫持的具体命令
        [ "$redir_mod" = "TCP旁路转发" ] && JUMP="meta l4proto tcp mark set $fwmark"        #跳转劫持的具体命令
        [ "$lan_proxy" = true ] && start_nft_route prerouting prerouting filter -150
        [ "$local_proxy" = true ] && start_nft_route output output route -150
    }
    [ "$vm_redir" = "ON" ] && [ -n "$$vm_ipv4" ] && {
        start_nft_dns prerouting_vm prerouting
        JUMP="meta l4proto tcp redirect to $redir_port" #跳转劫持的具体命令
        start_nft_route prerouting_vm prerouting nat -100
    }
}
