#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_FW_FILTER_LOADED" ] && return
__IS_MODULE_FW_FILTER_LOADED=1

# 流量过滤
set_fw_filter() {
    while true; do
        [ -z "$common_ports" ] && common_ports=ON
        [ -z "$quic_rj" ] && quic_rj=OFF
        [ -z "$cn_ip_route" ] && cn_ip_route=OFF
        touch "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter
        [ -z "$(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null)" ] && mac_return=OFF || mac_return=ON
        line_break
        separator_line "="
        content_line "1) 过滤非常用端口： 	\033[36m$common_ports\033[0m	———用于过滤P2P流量"
        content_line "2) 过滤局域网设备：	\033[36m$mac_return\033[0m	———使用黑/白名单进行过滤"
        content_line "3) 过滤QUIC协议：	\033[36m$quic_rj\033[0m	———优化视频性能"
        content_line "4) 过滤CN_IP(4/6)列表：\033[36m$cn_ip_route\033[0m	———优化性能"
        content_line "5) 自定义透明路由ipv4网段：适合vlan等复杂网络环境"
        content_line "6) 自定义保留地址ipv4网段：需要以保留地址为访问目标的环境"
        content_line ""
        common_back
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$(pidof CrashCore)" ] && [ "$firewall_mod" = 'iptables' ]; then
                comp_box "切换时将停止服务，是否继续："
                content_line "1) 是"
                content_line "0) 否，返回上级菜单"
                separator_line "="
                read -r -p "$COMMON_INPUT> " res
                [ "$res" = 1 ] && "$CRASHDIR"/start.sh stop && set_common_ports
            else
                set_common_ports
            fi
            ;;
        2)
            checkcfg_mac=$(cat "$CRASHDIR"/configs/mac)
            fw_filter_lan
            if [ -n "$PID" ]; then
                checkcfg_mac_new=$(cat "$CRASHDIR"/configs/mac)
                [ "$checkcfg_mac" != "$checkcfg_mac_new" ] && checkrestart
            fi
            ;;
        3)
			if [ "$quic_rj" = "OFF" ]; then
				quic_rj=ON
				msg_alert "\033[33m已禁止QUIC流量通过ShellCrash内核！\033[0m"
			else
				quic_rj=OFF
				msg_alert "\033[33m已取消禁止QUIC协议流量！\033[0m"
			fi
			setconfig quic_rj $quic_rj
            ;;
        4)
            if [ -n "$(ipset -v 2>/dev/null)" ] || [ "$firewall_mod" = 'nftables' ]; then
                if [ "$cn_ip_route" = "OFF" ]; then
                    cn_ip_route=ON
                    msg_alert -t 2 "\033[32m已开启CN_IP绕过内核功能！\033[0m" \
                        "\033[31m注意：此功能会导致全局模式及一切CN相关规则失效！\033[0m"
                else
                    cn_ip_route=OFF
                    msg_alert "\033[33m已禁用CN_IP绕过内核功能！\033[0m"
                fi
                setconfig cn_ip_route $cn_ip_route
            else
                msg_alert "\033[31m当前设备缺少ipset模块或未使用nftables模式，无法启用绕过功能！\033[0m"
            fi
            ;;
        5)
            set_cust_host_ipv4
            ;;
        6)
            set_reserve_ipv4
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_common_ports() {
    while true; do
        [ -z "$multiport" ] && multiport='22,80,443,8080,8443'
        line_break
        separator_line "="
        content_line "\033[31m注意：\n\033[0mMIX模式下，所有fake-ip来源的非常用端口流量不会被过滤"
        if [ -n "$common_ports" ]; then
            content_line ""
            content_line "当前已放行端口：\033[36m$multiport\033[0m"
        fi
        separator_line "="
        content_line "1) 启用/关闭端口过滤:	\033[36m$common_ports\033[0m"
        content_line "2) 添加放行端口"
        content_line "3) 移除指定放行端口"
        content_line "4) 重置默认放行端口"
        content_line "5) 重置为旧版放行端口"
        content_line ""
        common_back
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$common_ports" = ON ]; then
                common_ports=OFF
            else
                common_ports=ON
            fi

            if setconfig common_ports "$common_ports"; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        2)
            while true; do
                port_count=$(echo "$multiport" | awk -F',' '{print NF}')
                if [ "$port_count" -ge 15 ]; then
                    comp_box "\033[31m最多支持设置放行15个端口，请先减少一些！\033[0m"
                else
                    comp_box "当前已放行端口：\033[36m$multiport\033[0m"
                    btm_box "请直接输入要放行的端口号\n（每次只能输入一个端口号，切勿一次添加多个端口号）" \
                        "或输入 0 返回上级菜单"
                    read -r -p "请输入> " port
                    if [ "$port" = 0 ]; then
                        break
                    elif echo ",$multiport," | grep -q ",$port,"; then
                        msg_alert "\033[31m输入错误！请勿重复添加！\033[0m"
                    elif [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                        msg_alert "\033[31m输入错误！请输入正确的数值（1～65535）！\033[0m"
                    else
                        multiport=$(echo "$multiport,$port" | sed "s/^,//")

                        if setconfig multiport "$multiport"; then
                            msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                        else
                            msg_alert "\033[31m$COMMON_FAILED\033[0m"
                        fi
                    fi
                fi
            done
            ;;
        3)
            while true; do
                comp_box "当前已放行端口：\033[36m$multiport\033[0m"
                btm_box "请直接输入要移除的端口号\n（每次只能输入一个端口号，切勿一次添加多个端口号）" \
                    "或输入 0 返回上级菜单"
                read -r -p "请输入> " port
                if [ "$port" = 0 ]; then
                    break
                elif echo ",$multiport," | grep -q ",$port,"; then
                    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                        msg_alert "\033[31m输入错误！请输入正确的数值（1～65535）！\033[0m"
                    else
                        multiport=$(echo ",$multiport," | sed "s/,$port//; s/^,//; s/,$//")
                        if setconfig multiport "$multiport"; then
                            msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                        else
                            msg_alert "\033[31m$COMMON_FAILED\033[0m"
                        fi
                    fi
                else
                    msg_alert "\033[31m输入错误！请输入已添加过的端口！\033[0m"
                fi
            done
            ;;
        4)
            multiport=''
            if setconfig multiport; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        5)
            multiport='22,80,143,194,443,465,587,853,993,995,5222,8080,8443'
            if setconfig multiport "$multiport"; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 自定义ipv4透明路由、保留地址网段
set_cust_host_ipv4() {
    while true; do
        [ -z "$replace_default_host_ipv4" ] && replace_default_host_ipv4="OFF"
        . "$CRASHDIR"/starts/fw_getlanip.sh && getlanip
        comp_box "当前默认透明路由的网段为：\033[32m$host_ipv4\033[0m" \
            "当前已添加的自定义网段为：\033[36m$cust_host_ipv4\033[0m"
        content_line "1) 移除所有自定义网段"
        content_line "2) 使用自定义网段覆盖默认网段	\033[36m$replace_default_host_ipv4\033[0m"
        common_back
        read -r -p "请输入对应的序号或需要额外添加的网段> " text
        case "$text" in
        "" | 0)
            break
            ;;
        1)
            unset cust_host_ipv4
            if setconfig cust_host_ipv4; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        2)
            if [ "$replace_default_host_ipv4" = "OFF" ]; then
                replace_default_host_ipv4="ON"
            else
                replace_default_host_ipv4="OFF"
            fi

            if setconfig replace_default_host_ipv4 "$replace_default_host_ipv4"; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        *)
            if echo "$text" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}' && [ -z "$(echo $cust_host_ipv4 | grep "$text")" ]; then
                cust_host_ipv4="$cust_host_ipv4 $text"
                if setconfig cust_host_ipv4 "'$cust_host_ipv4'"; then
                    msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                else
                    msg_alert "\033[31m$COMMON_FAILED\033[0m"
                fi
            else
                msg_alert "\033[31m请输入正确的网段地址！\033[0m"
            fi
            ;;
        esac
    done
}
set_reserve_ipv4() {
    while true; do
        [ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
        comp_box "\033[33m注意：地址必须是空格分隔，错误的设置可能导致网络回环或启动报错，请务必谨慎！\033[0m" \
            "" \
            "当前网段：" \
            "\033[36m$reserve_ipv4\033[0m"
		btm_box "请直接输入自定义保留地址ipv4网段" \
            "或输入 1 重置默认网段" \
            "或输入 0 返回上级菜单"
		read -r -p "请输入> " text
        case "$text" in
        "" | 0)
            break
            ;;
        1)
            unset reserve_ipv4
            if setconfig reserve_ipv4; then
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        *)
            if echo "$text" | grep -Eq "(((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9]))( +|$)+"; then
                reserve_ipv4="$text"
				if setconfig reserve_ipv4 "'$reserve_ipv4'"; then
					msg_alert "已将保留地址网段设为：\033[32m$reserve_ipv4\033[0m"
				else
					msg_alert "\033[31m$COMMON_FAILED\033[0m"
				fi
            else
                msg_alert "\033[31m输入有误，请重新输入！\033[0m"
            fi
            ;;
        esac 
	done
}
# 局域网设备过滤
fw_filter_lan() {
    get_devinfo() {
        dev_ip=$(cat "$dhcpdir" | grep " $dev " | awk '{print $3}') && [ -z "$dev_ip" ] && dev_ip=$dev
        dev_mac=$(cat "$dhcpdir" | grep " $dev " | awk '{print $2}') && [ -z "$dev_mac" ] && dev_mac=$dev
        dev_name=$(cat "$dhcpdir" | grep " $dev " | awk '{print $4}') && [ -z "$dev_name" ] && dev_name='未知设备'
    }

    add_mac() {
        while true; do
            comp_box "手动输入mac地址时仅支持\033[32mxx:xx:xx:xx:xx:xx\033[0m的形式"
            content_line "已添加的mac地址："
            content_line ""
            if [ -s "$CRASHDIR/configs/mac" ]; then
                while IFS= read -r line; do
                    content_line "$line"
                done <"$CRASHDIR/configs/mac"
            else
                content_line "暫未添加任何mac地址"
            fi

            separator_line "="
            content_line "序号   \033[33m设备IP       设备mac地址       设备名称\033[0m"
            if [ -s "$dhcpdir" ]; then
                awk '{print NR") "$3,$2,$4}' "$dhcpdir" |
                    while IFS= read -r line; do
                        content_line "$line"
                    done
            else
                content_line "无纪录"
            fi

            content_line ""
            common_back
            read -r -p "请输入对应序号或直接输入mac地址> " num
            if [ -z "$num" ] || [ "$num" = 0 ]; then
                i=
                break
            elif echo "$num" | grep -aEq '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$'; then
                if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$num")" ]; then
                    echo "$num" | grep -oE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$' >>"$CRASHDIR"/configs/mac
                else
                    msg_alert "\033[31m已添加的设备，请勿重复添加！\033[0m"
                fi
            elif [ "$num" -le $(cat $dhcpdir 2>/dev/null | awk 'END{print NR}') ]; then
                macadd=$(cat "$dhcpdir" | awk '{print $2}' | sed -n "$num"p)
                if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$macadd")" ]; then
                    echo "$macadd" >>"$CRASHDIR"/configs/mac
                else
                    msg_alert "\033[31m已添加的设备，请勿重复添加！\033[0m"
                fi
            else
                msg_alert "\033[31m输入有误，请重新输入！\033[0m"
            fi
        done
    }

    add_ip() {
        while true; do
            comp_box "手动输入时仅支持 \033[32m192.168.1.0/24\033[0m 或 \033[32m192.168.1.0\033[0m 的形式" \
                "不支持ipv6地址过滤，可能导致过滤失败，建议使用mac地址过滤"
            content_line "已添加的IP地址（段）："
            content_line ""
            if [ -s "$CRASHDIR/configs/ip_filter" ]; then
                while IFS= read -r line; do
                    content_line "$line"
                done <"$CRASHDIR/configs/ip_filter"
            else
                content_line "暫未添加任何IP地址（段）"
            fi

            separator_line "="
            content_line "\033[33m序号   设备IP     设备名称\033[32m"
            if [ -s "$dhcpdir" ]; then
                awk '{print NR") "$3, $4}' "$dhcpdir" |
                    while IFS= read -r line; do
                        content_line "$line"
                    done
            else
                content_line "无纪录"
            fi

            content_line ""
            common_back
            read -r -p "请输入对应序号或直接输入IP地址段> " num
            if [ -z "$num" ] || [ "$num" = 0 ]; then
                i=
                break
            elif echo "$num" | grep -aEq '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$'; then
                if [ -z "$(cat "$CRASHDIR"/configs/ip_filter | grep -E "$num")" ]; then
                    echo "$num" | grep -oE '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$' >>"$CRASHDIR"/configs/ip_filter
                else
                    msg_alert "\033[31m已添加的地址，请勿重复添加！\033[0m"
                fi
            elif [ "$num" -le "$(cat "$dhcpdir" 2>/dev/null | awk 'END{print NR}')" ]; then
                ipadd=$(cat "$dhcpdir" | awk '{print $3}' | sed -n "$num"p)
                if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$ipadd")" ]; then
                    echo "$ipadd" >>"$CRASHDIR"/configs/ip_filter
                else
                    msg_alert "\033[31m已添加的地址，请勿重复添加！\033[0m"
                fi
            else
                msg_alert "\033[31m输入有误，请重新输入！\033[0m"
            fi
        done
    }

    del_all() {
        while true; do
            if [ -z "$(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null)" ]; then
                msg_alert "\033[31m列表中没有需要移除的设备！\033[0m"
                break
            else
                comp_box "请选择需要移除的设备："
                content_line "      \033[32m设备IP             \033[36m设备mac地址     \033[35m设备名称\033[0m"
                i=1
                for dev in $(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null); do
                    get_devinfo
                    content_line "$(printf "%s) \033[32m%-18s \033[36m%-18s \033[35m%s\033[0m" \
                        "$i" "$dev_ip" "$dev_mac" "$dev_name")"
                    i=$((i + 1))
                done
                content_line ""
                common_back
                read -r -p "$COMMON_INPUT> " num
                mac_filter_rows=$(cat "$CRASHDIR"/configs/mac 2>/dev/null | wc -l)
                ip_filter_rows=$(cat "$CRASHDIR"/configs/ip_filter 2>/dev/null | wc -l)
                if [ -z "$num" ] || [ "$num" -le 0 ]; then
                    n=
                    break
                elif [ "$num" -le "$mac_filter_rows" ]; then
                    sed -i "${num}d" "$CRASHDIR"/configs/mac
                    msg_alert "\033[32m对应设备已移除！\033[0m"
                elif [ "$num" -le $((mac_filter_rows + ip_filter_rows)) ]; then
                    num=$((num - mac_filter_rows))
                    sed -i "${num}d" "$CRASHDIR"/configs/ip_filter
                    msg_alert "\033[32m对应设备已移除！\033[0m"
                else
                    msg_alert "\033[31m输入有误，请重新输入！\033[0m"
                fi
            fi
        done
    }

    while true; do
        [ -z "$dhcpdir" ] && [ -f /var/lib/dhcp/dhcpd.leases ] && dhcpdir='/var/lib/dhcp/dhcpd.leases'
        [ -z "$dhcpdir" ] && [ -f /var/lib/dhcpd/dhcpd.leases ] && dhcpdir='/var/lib/dhcpd/dhcpd.leases'
        [ -z "$dhcpdir" ] && [ -f /tmp/dhcp.leases ] && dhcpdir='/tmp/dhcp.leases'
        [ -z "$dhcpdir" ] && [ -f /tmp/dnsmasq.leases ] && dhcpdir='/tmp/dnsmasq.leases'
        [ -z "$dhcpdir" ] && dhcpdir='/dev/null'
        [ -z "$macfilter_type" ] && macfilter_type='黑名单'
        if [ "$macfilter_type" = "黑名单" ]; then
            fw_filter_lan_over='白名单'
            fw_filter_lan_scrip='不'
        else
            fw_filter_lan_over='黑名单'
            fw_filter_lan_scrip=''
        fi

        comp_box "\033[30;47m请在此添加或移除设备\033[0m" \
            "" \
            "当前过滤方式为：\033[33m$macfilter_type模式\033[0m" \
            "仅列表内设备流量\033[36m$fw_filter_lan_scrip经过\033[0m内核"
        if [ -n "$(cat "$CRASHDIR"/configs/mac)" ]; then
            content_line "当前已过滤设备为："
            content_line ""
            content_line "  \033[36m设备mac/ip地址\033[0m     \033[35m设备名称\033[0m"
            for dev in $(cat "$CRASHDIR"/configs/mac 2>/dev/null); do
                get_devinfo
                content_line "$(printf "\033[36m%-20s \033[35m%s\033[0m" \
                    "$dev_mac" "$dev_name")"
            done
            for dev in $(cat "$CRASHDIR"/configs/ip_filter 2>/dev/null); do
                get_devinfo
                content_line "$(printf "\033[36m%-20s \033[35m%s\033[0m" \
                    "$dev_ip" "$dev_name")"
            done
            separator_line "="
        fi
        content_line "1) 切换为\033[33m$fw_filter_lan_over模式\033[0m"
        content_line "2) \033[32m添加指定设备（mac地址）\033[0m"
        content_line "3) \033[32m添加指定设备（IP地址／网段）\033[0m"
        content_line "4) \033[36m移除指定设备\033[0m"
        content_line "9) \033[31m清空整个列表\033[0m"
        content_line ""
        common_back
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            macfilter_type=$fw_filter_lan_over
            if setconfig macfilter_type $macfilter_type; then
                msg_alert "\033[32m已切换为$macfilter_type模式！\033[0m"
            else
                msg_alert "\033[31m$COMMON_FAILED\033[0m"
            fi
            ;;
        2)
            add_mac
            ;;
        3)
            add_ip
            ;;
        4)
            del_all
            ;;
        9)
            : >"$CRASHDIR"/configs/mac
            : >"$CRASHDIR"/configs/ip_filter
            msg_alert "\033[31m设备列表已清空！\033[0m"
            ;;
        *)
            errornum
            ;;
        esac
    done
}
