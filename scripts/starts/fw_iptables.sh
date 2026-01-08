#!/bin/sh
# Copyright (C) Juewuy

start_ipt_route() { #iptables-route通用工具
    #$1:iptables/ip6tables	$2:所在的表(nat/mangle) $3:所在的链(OUTPUT/PREROUTING)	$4:新创建的shellcrash链表	$5:tcp/udp/all
    #区分ipv4/ipv6
    [ "$1" = 'iptables' ] && {
        RESERVED_IP=$reserve_ipv4
        HOST_IP=$host_ipv4
        [ "$3" = 'OUTPUT' ] && HOST_IP="127.0.0.0/8 $local_ipv4"
        [ "$4" = 'shellcrash_vm' ] && HOST_IP="$vm_ipv4"
        iptables -h | grep -q '\-w' && w='-w' || w=''
    }
    [ "$1" = 'ip6tables' ] && {
        RESERVED_IP=$reserve_ipv6
        HOST_IP=$host_ipv6
        [ "$3" = 'OUTPUT' ] && HOST_IP="::1 $host_ipv6"
        ip6tables -h | grep -q '\-w' && w='-w' || w=''
    }
    #创建新的shellcrash链表
    "$1" $w -t "$2" -N "$4"
    #过滤dns
    "$1" $w -t "$2" -A "$4" -p tcp --dport 53 -j RETURN
    "$1" $w -t "$2" -A "$4" -p udp --dport 53 -j RETURN
    #防回环
    "$1" $w -t "$2" -A "$4" -m mark --mark $routing_mark -j RETURN
    [ "$3" = 'OUTPUT' ] && for gid in 453 7890; do
        "$1" $w -t "$2" -A "$4" -m owner --gid-owner $gid -j RETURN
    done
    [ "$firewall_area" = 5 ] && "$1" $w -t "$2" -A "$4" -s $bypass_host -j RETURN
    [ -z "$ports" ] && "$1" $w -t "$2" -A "$4" -p tcp -m multiport --dports "$mix_port,$redir_port,$tproxy_port" -j RETURN
    #跳过目标保留地址及目标本机网段
    for ip in $HOST_IP $RESERVED_IP; do
        "$1" $w -t "$2" -A "$4" -d $ip -j RETURN
    done
    #绕过CN_IP
    [ "$1" = iptables ] && [ "$dns_mod" != "fake-ip" ] && [ "$cn_ip_route" = "ON" ] && [ -f "$BINDIR"/cn_ip.txt ] && "$1" $w -t "$2" -A "$4" -m set --match-set cn_ip dst -j RETURN 2>/dev/null
    [ "$1" = ip6tables ] && [ "$dns_mod" != "fake-ip" ] && [ "$cn_ip_route" = "ON" ] && [ -f "$BINDIR"/cn_ipv6.txt ] && "$1" $w -t "$2" -A "$4" -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
    #局域网mac地址黑名单过滤
    [ "$3" = 'PREROUTING' ] && [ "$macfilter_type" != "白名单" ] && {
        [ -s "$CRASHDIR"/configs/mac ] &&
            for mac in $(cat "$CRASHDIR"/configs/mac); do
                "$1" $w -t "$2" -A "$4" -m mac --mac-source $mac -j RETURN
            done
        [ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
            for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
                "$1" $w -t "$2" -A "$4" -s $ip -j RETURN
            done
    }
    #tcp&udp分别进代理链
    proxy_set() {
        if [ "$3" = 'PREROUTING' ] && [ "$4" != 'shellcrash_vm' ] && [ "$macfilter_type" = "白名单" ] && [ -n "$(cat $CRASHDIR/configs/mac $CRASHDIR/configs/ip_filter 2>/dev/null)" ]; then
            [ -s "$CRASHDIR"/configs/mac ] &&
                for mac in $(cat "$CRASHDIR"/configs/mac); do
                    "$1" $w -t "$2" -A "$4" -p "$5" -m mac --mac-source $mac -j $JUMP
                done
            [ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
                for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
                    "$1" $w -t "$2" -A "$4" -p "$5" -s $ip -j $JUMP
                done
        else
            for ip in $HOST_IP; do #仅限指定网段流量
                "$1" $w -t "$2" -A "$4" -p "$5" -s $ip -j $JUMP
            done
        fi
        #将所在链指定流量指向shellcrash表
        "$1" $w -t "$2" -I "$3" -p "$5" $ports -j "$4"
        [ "$dns_mod" = "mix" -o "$dns_mod" = "fake-ip" ] && [ "$common_ports" = "ON" ] && [ "$1" = iptables ] && "$1" $w -t "$2" -I "$3" -p "$5" -d 28.0.0.0/8 -j "$4"
        [ "$dns_mod" = "mix" -o "$dns_mod" = "fake-ip" ] && [ "$common_ports" = "ON" ] && [ "$1" = ip6tables ] && "$1" $w -t "$2" -I "$3" -p "$5" -d fc00::/16 -j "$4"
    }
    [ "$5" = "tcp" -o "$5" = "all" ] && proxy_set "$1" "$2" "$3" "$4" tcp
    [ "$5" = "udp" -o "$5" = "all" ] && proxy_set "$1" "$2" "$3" "$4" udp
}
start_ipt_dns() { #iptables-dns通用工具
    #$1:iptables/ip6tables	$2:所在的表(OUTPUT/PREROUTING)	$3:新创建的shellcrash表
    #区分ipv4/ipv6
    [ "$1" = 'iptables' ] && {
        HOST_IP="$host_ipv4"
        [ "$2" = 'OUTPUT' ] && HOST_IP="127.0.0.0/8 $local_ipv4"
        [ "$3" = 'shellcrash_vm_dns' ] && HOST_IP="$vm_ipv4"
        iptables -h | grep -q '\-w' && w='-w' || w=''
    }
    [ "$1" = 'ip6tables' ] && {
        HOST_IP=$host_ipv6
        ip6tables -h | grep -q '\-w' && w='-w' || w=''
    }
    "$1" $w -t nat -N "$3"
    #防回环
    "$1" $w -t nat -A "$3" -m mark --mark $routing_mark -j RETURN
    [ "$2" = 'OUTPUT' ] && for gid in 453 7890; do
        "$1" $w -t nat -A "$3" -m owner --gid-owner $gid -j RETURN
    done
    [ "$firewall_area" = 5 ] && {
        "$1" $w -t nat -A "$3" -p tcp -s $bypass_host -j RETURN
        "$1" $w -t nat -A "$3" -p udp -s $bypass_host -j RETURN
    }
    #局域网mac地址黑名单过滤
    [ "$2" = 'PREROUTING' ] && [ "$macfilter_type" != "白名单" ] && {
        [ -s "$CRASHDIR"/configs/mac ] &&
            for mac in $(cat "$CRASHDIR"/configs/mac); do
                "$1" $w -t nat -A "$3" -m mac --mac-source $mac -j RETURN
            done
        [ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
            for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
                "$1" $w -t nat -A "$3" -s $ip -j RETURN
            done
    }
    if [ "$2" = 'PREROUTING' ] && [ "$3" != 'shellcrash_vm_dns' ] && [ "$macfilter_type" = "白名单" ] && [ -n "$(cat $CRASHDIR/configs/mac $CRASHDIR/configs/ip_filter 2>/dev/null)" ]; then
        [ -s "$CRASHDIR"/configs/mac ] &&
            for mac in $(cat "$CRASHDIR"/configs/mac); do
                "$1" $w -t nat -A "$3" -p tcp -m mac --mac-source $mac -j REDIRECT --to-ports "$dns_redir_port"
                "$1" $w -t nat -A "$3" -p udp -m mac --mac-source $mac -j REDIRECT --to-ports "$dns_redir_port"
            done
        [ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
            for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
                "$1" $w -t nat -A "$3" -p tcp -s $ip -j REDIRECT --to-ports "$dns_redir_port"
                "$1" $w -t nat -A "$3" -p udp -s $ip -j REDIRECT --to-ports "$dns_redir_port"
            done
    else
        for ip in $HOST_IP; do #仅限指定网段流量
            "$1" $w -t nat -A "$3" -p tcp -s $ip -j REDIRECT --to-ports "$dns_redir_port"
            "$1" $w -t nat -A "$3" -p udp -s $ip -j REDIRECT --to-ports "$dns_redir_port"
        done
    fi
    [ "$1" = 'ip6tables' ] && { #屏蔽外部请求
        "$1" $w -t nat -A "$3" -p tcp -j RETURN
        "$1" $w -t nat -A "$3" -p udp -j RETURN
    }
    "$1" $w -t nat -I "$2" -p tcp --dport 53 -j "$3"
    "$1" $w -t nat -I "$2" -p udp --dport 53 -j "$3"
}
start_ipt_wan() { #iptables公网防火墙
	ckcmd iptables && iptables -h | grep -q '\-w' && iptable='iptables -w' || iptable=iptables
	ckcmd ip6tables && ip6tables -h | grep -q '\-w' && ip6table='ip6tables -w' || ip6table=ip6tables
	ipt_wan_accept(){
		$iptable -I INPUT -p "$1" -m multiport --dports "$accept_ports" -j ACCEPT
		ckcmd ip6tables && $ip6table -I INPUT -p "$1" -m multiport --dports "$accept_ports" -j ACCEPT
	}
	ipt_wan_reject(){
		$iptable -I INPUT -p "$1" -m multiport --dports "$reject_ports" -j REJECT
		ckcmd ip6tables && $ip6table -I INPUT -p "$1" -m multiport --dports "$reject_ports" -j REJECT
	}
	#端口拦截
	reject_ports="$mix_port,$db_port,$dns_port"
	ipt_wan_reject tcp
	ipt_wan_reject udp
	#端口放行
	[ -f "$CRASHDIR"/configs/gateway.cfg ] && . "$CRASHDIR"/configs/gateway.cfg
	accept_ports=$(echo "$fw_wan_ports,$vms_port,$sss_port" | sed "s/,,/,/g ;s/^,// ;s/,$//")
    [ -n "$accept_ports" ] && {
		ipt_wan_accept tcp
		ipt_wan_accept udp
	}
	#局域网请求放行
	for ip in $host_ipv4; do
		$iptable -I INPUT -s $ip -j ACCEPT
	done
	ckcmd ip6tables && for ip in $host_ipv6; do
		$ip6table -I INPUT -s $ip -j ACCEPT
	done
	#本机请求全放行
	$iptable -I INPUT -i lo -j ACCEPT
	ckcmd ip6tables && $ip6table -I INPUT -i lo -j ACCEPT
}
start_iptables() { #iptables配置总入口
    #启动公网访问防火墙
    [ "$fw_wan" != OFF ] && start_ipt_wan
    #分模式设置流量劫持
    [ "$redir_mod" = "Redir模式" -o "$redir_mod" = "混合模式" ] && {
        JUMP="REDIRECT --to-ports $redir_port" #跳转劫持的具体命令
        [ "$lan_proxy" = true ] && {
            start_ipt_route iptables nat PREROUTING shellcrash tcp #ipv4-局域网tcp转发
            [ "$ipv6_redir" = "ON" ] && {
                if $ip6table -j REDIRECT -h 2>/dev/null | grep -q '\--to-ports'; then
                    start_ipt_route ip6tables nat PREROUTING shellcrashv6 tcp #ipv6-局域网tcp转发
                else
                    logger "当前设备内核缺少ip6tables_REDIRECT模块支持，已放弃启动相关规则！" 31
                fi
            }
        }
        [ "$local_proxy" = true ] && {
            start_ipt_route iptables nat OUTPUT shellcrash_out tcp #ipv4-本机tcp转发
            [ "$ipv6_redir" = "ON" ] && {
                if $ip6table -j REDIRECT -h 2>/dev/null | grep -q '\--to-ports'; then
                    start_ipt_route ip6tables nat OUTPUT shellcrashv6_out tcp #ipv6-本机tcp转发
                else
                    logger "当前设备内核缺少ip6tables_REDIRECT模块支持，已放弃启动相关规则！" 31
                fi
            }
        }
    }
    [ "$redir_mod" = "Tproxy模式" ] && {
        modprobe xt_TPROXY >/dev/null 2>&1
        JUMP="TPROXY --on-port $tproxy_port --tproxy-mark $fwmark" #跳转劫持的具体命令
        if $iptable -j TPROXY -h 2>/dev/null | grep -q '\--on-port'; then
            [ "$lan_proxy" = true ] && start_ipt_route iptables mangle PREROUTING shellcrash_mark all
            [ "$local_proxy" = true ] && {
                if [ -n "$(grep -E '^MARK$' /proc/net/ip_tables_targets)" ]; then
                    JUMP="MARK --set-mark $fwmark" #跳转劫持的具体命令
                    start_ipt_route iptables mangle OUTPUT shellcrash_mark_out all
                    $iptable -t mangle -A PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port
                    $iptable -t mangle -A PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port
                else
                    logger "当前设备内核可能缺少xt_mark模块支持，已放弃启动本机代理相关规则！" 31
                fi
            }
        else
            logger "当前设备内核可能缺少kmod_ipt_tproxy模块支持，已放弃启动相关规则！" 31
        fi
        [ "$ipv6_redir" = "ON" ] && {
            if $ip6table -j TPROXY -h 2>/dev/null | grep -q '\--on-port'; then
                JUMP="TPROXY --on-port $tproxy_port --tproxy-mark $fwmark" #跳转劫持的具体命令
                [ "$lan_proxy" = true ] && start_ipt_route ip6tables mangle PREROUTING shellcrashv6_mark all
                [ "$local_proxy" = true ] && {
                    if [ -n "$(grep -E '^MARK$' /proc/net/ip6_tables_targets)" ]; then
                        JUMP="MARK --set-mark $fwmark" #跳转劫持的具体命令
                        start_ipt_route ip6tables mangle OUTPUT shellcrashv6_mark_out all
                        $ip6table -t mangle -A PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port
                        $ip6table -t mangle -A PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port
                    else
                        logger "当前设备内核可能缺少xt_mark模块支持，已放弃启动本机代理相关规则！" 31
                    fi
                }
            else
                logger "当前设备内核可能缺少kmod_ipt_tproxy或者xt_mark模块支持，已放弃启动相关规则！" 31
            fi
        }
    }
    [ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" -o "$redir_mod" = "T&U旁路转发" -o "$redir_mod" = "TCP旁路转发" ] && {
        JUMP="MARK --set-mark $fwmark" #跳转劫持的具体命令
        [ "$redir_mod" = "Tun模式" -o "$redir_mod" = "T&U旁路转发" ] && protocol=all
        [ "$redir_mod" = "混合模式" ] && protocol=udp
        [ "$redir_mod" = "TCP旁路转发" ] && protocol=tcp
        if $iptable -j MARK -h 2>/dev/null | grep -q '\--set-mark'; then
            [ "$lan_proxy" = true ] && {
                [ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && $iptable -I FORWARD -o utun -j ACCEPT
                start_ipt_route iptables mangle PREROUTING shellcrash_mark $protocol
            }
            [ "$local_proxy" = true ] && start_ipt_route iptables mangle OUTPUT shellcrash_mark_out $protocol
        else
            logger "当前设备内核可能缺少x_mark模块支持，已放弃启动相关规则！" 31
        fi
        [ "$ipv6_redir" = "ON" ] && [ "$crashcore" != clashpre ] && {
            if $ip6table -j MARK -h 2>/dev/null | grep -q '\--set-mark'; then
                [ "$lan_proxy" = true ] && {
                    [ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && $ip6table -I FORWARD -o utun -j ACCEPT
                    start_ipt_route ip6tables mangle PREROUTING shellcrashv6_mark $protocol
                }
                [ "$local_proxy" = true ] && start_ipt_route ip6tables mangle OUTPUT shellcrashv6_mark_out $protocol
            else
                logger "当前设备内核可能缺少xt_mark模块支持，已放弃启动相关规则！" 31
            fi
        }
    }
    [ "$vm_redir" = "ON" ] && [ -n "$$vm_ipv4" ] && {
        JUMP="REDIRECT --to-ports $redir_port"                    #跳转劫持的具体命令
        start_ipt_dns iptables PREROUTING shellcrash_vm_dns       #ipv4-局域网dns转发
        start_ipt_route iptables nat PREROUTING shellcrash_vm tcp #ipv4-局域网tcp转发
    }
    #启动DNS劫持
    [ "$firewall_area" -le 3 ] && {
        [ "$lan_proxy" = true ] && {
            start_ipt_dns iptables PREROUTING shellcrash_dns #ipv4-局域网dns转发
            if $ip6table -j REDIRECT -h 2>/dev/null | grep -q '\--to-ports'; then
                start_ipt_dns ip6tables PREROUTING shellcrashv6_dns #ipv6-局域网dns转发
            else
                $ip6table -I INPUT -p tcp --dport 53 -j REJECT >/dev/null 2>&1
                $ip6table -I INPUT -p udp --dport 53 -j REJECT >/dev/null 2>&1
            fi
        }
        [ "$local_proxy" = true ] && start_ipt_dns iptables OUTPUT shellcrash_dns_out #ipv4-本机dns转发
    }
    #屏蔽QUIC
    [ "$quic_rj" = 'ON' -a "$lan_proxy" = true -a "$redir_mod" != "Redir模式" ] && {
        [ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "ON" ] && {
            set_cn_ip='-m set ! --match-set cn_ip dst'
            set_cn_ip6='-m set ! --match-set cn_ip6 dst'
        }
        [ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && {
            $iptable -I FORWARD -p udp --dport 443 -o utun $set_cn_ip -j REJECT >/dev/null 2>&1
            $ip6table -I FORWARD -p udp --dport 443 -o utun $set_cn_ip6 -j REJECT >/dev/null 2>&1
        }
        [ "$redir_mod" = "Tproxy模式" ] && {
            $iptable -I INPUT -p udp --dport 443 $set_cn_ip -j REJECT >/dev/null 2>&1
            $ip6table -I INPUT -p udp --dport 443 $set_cn_ip6 -j REJECT >/dev/null 2>&1
        }
    }
}
