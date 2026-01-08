#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_FW_FILTER_LOADED" ] && return
__IS_MODULE_FW_FILTER_LOADED=1

set_fw_filter(){ #流量过滤
	[ -z "$common_ports" ] && common_ports=ON
	[ -z "$quic_rj" ] && quic_rj=OFF
    [ -z "$cn_ip_route" ] && cn_ip_route=OFF	
	touch "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter
	[ -z "$(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null)" ] && mac_return=OFF || mac_return=ON
	echo "-----------------------------------------------"
    echo -e " 1 过滤非常用端口： 	\033[36m$common_ports\033[0m	————用于过滤P2P流量"
    echo -e " 2 过滤局域网设备：	\033[36m$mac_return\033[0m	————使用黑/白名单进行过滤"
    echo -e " 3 过滤QUIC协议:	\033[36m$quic_rj\033[0m	————优化视频性能"
    echo -e " 4 过滤CN_IP(6)列表:	\033[36m$cn_ip_route\033[0m	————优化性能，不兼容Fake-ip"
	echo -e " 5 自定义透明路由ipv4网段:	适合vlan等复杂网络环境"
	echo -e " 6 自定义保留地址ipv4网段:	需要以保留地址为访问目标的环境"
    echo "-----------------------------------------------"
    echo -e " 0 返回上级菜单 \033[0m"
    echo "-----------------------------------------------"
    read -p "请输入对应数字 > " num
    case "$num" in
    0)
	;;
    1)
        echo "-----------------------------------------------"
        if [ -n "$(pidof CrashCore)" ] && [ "$firewall_mod" = 'iptables' ]; then
            read -p "切换时将停止服务，是否继续？(1/0) > " res
            [ "$res" = 1 ] && "$CRASHDIR"/start.sh stop && set_common_ports
        else
            set_common_ports
        fi
        set_fw_filter
	;;
    2)
        checkcfg_mac=$(cat "$CRASHDIR"/configs/mac)
        fw_filter_lan
        if [ -n "$PID" ]; then
            checkcfg_mac_new=$(cat "$CRASHDIR"/configs/mac)
            [ "$checkcfg_mac" != "$checkcfg_mac_new" ] && checkrestart
        fi
        set_fw_filter
	;;
    3)
        echo "-----------------------------------------------"
        if [ -n "$(echo "$redir_mod" | grep -oE '混合|Tproxy|Tun')" ]; then
            if [ "$quic_rj" = "OFF" ]; then
                echo -e "\033[33m已禁止QUIC流量通过ShellCrash内核！！\033[0m"
                quic_rj=ON
            else
                echo -e "\033[33m已取消禁止QUIC协议流量！！\033[0m"
                quic_rj=OFF
            fi
            setconfig quic_rj $quic_rj
        else
            echo -e "\033[33m当前模式默认不会代理UDP流量，无需设置！！\033[0m"
        fi
        sleep 1
        set_fw_filter
	;;
    4)
        if [ -n "$(ipset -v 2>/dev/null)" ] || [ "$firewall_mod" = 'nftables' ]; then
            if [ "$cn_ip_route" = "OFF" ]; then
                echo -e "\033[32m已开启CN_IP绕过内核功能！！\033[0m"
                echo -e "\033[31m注意！！！此功能会导致全局模式及一切CN相关规则失效！！！\033[0m"
                cn_ip_route=ON
                sleep 2
            else
                echo -e "\033[33m已禁用CN_IP绕过内核功能！！\033[0m"
                cn_ip_route=OFF
            fi
            setconfig cn_ip_route $cn_ip_route
        else
            echo -e "\033[31m当前设备缺少ipset模块或未使用nftables模式，无法启用绕过功能！！\033[0m"
            sleep 1
        fi
        set_fw_filter
	;;
    5)
        set_cust_host_ipv4
        set_fw_filter
	;;
    6)
        [ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
        echo -e "当前网段：\033[36m$reserve_ipv4\033[0m"
        echo -e "\033[33m地址必须是空格分隔，错误的设置可能导致网络回环或启动报错，请务必谨慎！\033[0m"
        read -p "请输入 > " text
        if [ -n "$(
            echo $text | grep -E "(((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9]))( +|$)+"
        )" ]; then
            reserve_ipv4="$text"
            echo -e "已将保留地址网段设为：\033[32m$reserve_ipv4\033[0m"
            setconfig reserve_ipv4 "'$reserve_ipv4'"
        else
            echo -e "\033[31m输入有误，操作已取消！\033[0m"
        fi
        sleep 1
        set_fw_filter
	;;
    *)
        errornum
	;;
    esac
}
set_common_ports() {
	[ -z "$multiport" ] && multiport='22,80,443,8080,8443'
	echo "-----------------------------------------------"
	echo -e "\033[31m注意：\033[0mMIX模式下，所有fake-ip来源的非常用端口流量不会被过滤"
	[ -n "$common_ports" ] && 
	echo -e "当前放行端口：\033[36m$multiport\033[0m"
	echo "-----------------------------------------------"
	echo -e " 1 启用/关闭端口过滤:	\033[36m$common_ports\033[0m"
	echo -e " 2 添加放行端口"
	echo -e " 3 移除指定放行端口"
	echo -e " 4 重置默认放行端口"
	echo -e " 5 重置为旧版放行端口"
	echo -e " 0 返回上级菜单"
	echo "-----------------------------------------------"
	read -p "请输入对应数字 > " num
	case $num in
	1)
		if [ "$common_ports" = ON ];then
			common_ports=OFF
		else
			common_ports=ON
		fi
		setconfig common_ports "$common_ports"
		set_common_ports
	;;
	2)
		port_count=$(echo "$multiport" | awk -F',' '{print NF}' )
		if [ "$port_count" -ge 15 ];then
			echo -e "\033[31m最多支持设置放行15个端口，请先减少一些！\033[0m"
		else
			read -p "请输入要放行的端口号 > " port
			if echo ",$multiport," | grep -q ",$port,";then	
				echo -e "\033[31m输入错误！请勿重复添加！\033[0m"
			elif [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
				echo -e "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
			else
				multiport=$(echo "$multiport,$port" | sed "s/^,//")
				setconfig multiport "$multiport"
			fi
		fi
		sleep 1
		set_common_ports
	;;
	3)
		read -p "请输入要移除的端口号 > " port
		if echo ",$multiport," | grep -q ",$port,";then	
			if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
				echo -e "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
			else
				multiport=$(echo ",$multiport," | sed "s/,$port//; s/^,//; s/,$//")
				setconfig multiport "$multiport"
			fi
		else
			echo -e "\033[31m输入错误！请输入已添加过的端口！\033[0m"
		fi
		sleep 1
		set_common_ports
	;;
	4)
		multiport=''
		setconfig multiport
		sleep 1
		set_common_ports
	;;
	5)
		multiport='22,80,143,194,443,465,587,853,993,995,5222,8080,8443'
		setconfig multiport "$multiport"
		sleep 1
		set_common_ports
	;;
	*)
		errornum
	;;
	esac
}
set_cust_host_ipv4() { #自定义ipv4透明路由网段
	[ -z "$replace_default_host_ipv4" ] && replace_default_host_ipv4="OFF"
	echo "-----------------------------------------------"
	echo -e "当前默认透明路由的网段为: \033[32m$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'br' | grep -v 'iot' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/br.*$//g' | sed 's/metric.*$//g' | tr '\n' ' ' && echo) \033[0m"
	echo -e "当前已添加的自定义网段为:\033[36m$cust_host_ipv4\033[0m"
	echo "-----------------------------------------------"
	echo -e " 1 移除所有自定义网段"
	echo -e " 2 使用自定义网段覆盖默认网段	\033[36m$replace_default_host_ipv4\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应的序号或需要额外添加的网段 > " text
	case "$text" in
	2)
		if [ "$replace_default_host_ipv4" == "OFF" ]; then
			replace_default_host_ipv4="ON"
		else
			replace_default_host_ipv4="OFF"
		fi
		setconfig replace_default_host_ipv4 "$replace_default_host_ipv4"
		set_cust_host_ipv4
		;;
	1)
		unset cust_host_ipv4
		setconfig cust_host_ipv4
		set_cust_host_ipv4
		;;
	0) ;;
	*)
		if [ -n "$(echo $text | grep -Eo '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}'$)" -a -z "$(echo $cust_host_ipv4 | grep "$text")" ]; then
			cust_host_ipv4="$cust_host_ipv4 $text"
			setconfig cust_host_ipv4 "'$cust_host_ipv4'"
		else
			echo "-----------------------------------------------"
			echo -e "\033[31m请输入正确的网段地址！\033[0m"
		fi
		sleep 1
		set_cust_host_ipv4
		;;
	esac
}
fw_filter_lan() { #局域网设备过滤
    get_devinfo() {
        dev_ip=$(cat $dhcpdir | grep " $dev " | awk '{print $3}') && [ -z "$dev_ip" ] && dev_ip=$dev
        dev_mac=$(cat $dhcpdir | grep " $dev " | awk '{print $2}') && [ -z "$dev_mac" ] && dev_mac=$dev
        dev_name=$(cat $dhcpdir | grep " $dev " | awk '{print $4}') && [ -z "$dev_name" ] && dev_name='未知设备'
    }
    add_mac() {
        echo "-----------------------------------------------"
        echo 已添加的mac地址：
        cat "$CRASHDIR"/configs/mac 2>/dev/null
        echo "-----------------------------------------------"
        echo -e "\033[33m序号   设备IP       设备mac地址       设备名称\033[32m"
        cat $dhcpdir | awk '{print " "NR" "$3,$2,$4}'
        echo -e "\033[0m-----------------------------------------------"
        echo -e "手动输入mac地址时仅支持\033[32mxx:xx:xx:xx:xx:xx\033[0m的形式"
        echo -e " 0 或回车 结束添加"
        echo "-----------------------------------------------"
        read -p "请输入对应序号或直接输入mac地址 > " num
        if [ -z "$num" -o "$num" = 0 ]; then
            i=
        elif [ -n "$(echo $num | grep -aE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$')" ]; then
            if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$num")" ]; then
                echo $num | grep -oE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$' >>"$CRASHDIR"/configs/mac
            else
                echo "-----------------------------------------------"
                echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
            fi
            add_mac
        elif [ $num -le $(cat $dhcpdir 2>/dev/null | awk 'END{print NR}') ]; then
            macadd=$(cat $dhcpdir | awk '{print $2}' | sed -n "$num"p)
            if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$macadd")" ]; then
                echo $macadd >>"$CRASHDIR"/configs/mac
            else
                echo "-----------------------------------------------"
                echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
            fi
            add_mac
        else
            echo "-----------------------------------------------"
            echo -e "\033[31m输入有误，请重新输入！\033[0m"
            add_mac
        fi
    }
    add_ip() {
        echo "-----------------------------------------------"
        echo "已添加的IP地址(段)："
        cat "$CRASHDIR"/configs/ip_filter 2>/dev/null
        echo "-----------------------------------------------"
        echo -e "\033[33m序号   设备IP     设备名称\033[32m"
        cat $dhcpdir | awk '{print " "NR" "$3,$4}'
        echo -e "\033[0m-----------------------------------------------"
        echo -e "手动输入时仅支持\033[32m 192.168.1.0/24\033[0m 或 \033[32m192.168.1.0\033[0m 的形式"
        echo -e "不支持ipv6地址过滤，如有需求请使用mac地址过滤"
        echo -e " 0 或回车 结束添加"
        echo "-----------------------------------------------"
        read -p "请输入对应序号或直接输入IP地址段 > " num
        if [ -z "$num" -o "$num" = 0 ]; then
            i=
        elif [ -n "$(echo $num | grep -aE '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$')" ]; then
            if [ -z "$(cat "$CRASHDIR"/configs/ip_filter | grep -E "$num")" ]; then
                echo $num | grep -oE '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$' >>"$CRASHDIR"/configs/ip_filter
            else
                echo "-----------------------------------------------"
                echo -e "\033[31m已添加的地址，请勿重复添加！\033[0m"
            fi
            add_ip
        elif [ $num -le $(cat $dhcpdir 2>/dev/null | awk 'END{print NR}') ]; then
            ipadd=$(cat $dhcpdir | awk '{print $3}' | sed -n "$num"p)
            if [ -z "$(cat "$CRASHDIR"/configs/mac | grep -E "$ipadd")" ]; then
                echo $ipadd >>"$CRASHDIR"/configs/ip_filter
            else
                echo "-----------------------------------------------"
                echo -e "\033[31m已添加的地址，请勿重复添加！\033[0m"
            fi
            add_ip
        else
            echo "-----------------------------------------------"
            echo -e "\033[31m输入有误，请重新输入！\033[0m"
            add_ip
        fi
    }
    del_all() {
        echo "-----------------------------------------------"
        if [ -z "$(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null)" ]; then
            echo -e "\033[31m列表中没有需要移除的设备！\033[0m"
            sleep 1
        else
            echo -e "请选择需要移除的设备：\033[36m"
            echo -e "\033[33m      设备IP       设备mac地址       设备名称\033[0m"
            i=1
            for dev in $(cat "$CRASHDIR"/configs/mac "$CRASHDIR"/configs/ip_filter 2>/dev/null); do
                get_devinfo
                echo -e " $i \033[32m$dev_ip \033[36m$dev_mac \033[32m$dev_name\033[0m"
                i=$((i + 1))
            done
            echo "-----------------------------------------------"
            echo -e "\033[0m 0 或回车 结束删除"
            read -p "请输入需要移除的设备的对应序号 > " num
            mac_filter_rows=$(cat "$CRASHDIR"/configs/mac 2>/dev/null | wc -l)
            ip_filter_rows=$(cat "$CRASHDIR"/configs/ip_filter 2>/dev/null | wc -l)
            if [ -z "$num" ] || [ "$num" -le 0 ]; then
                n=
            elif [ $num -le $mac_filter_rows ]; then
                sed -i "${num}d" "$CRASHDIR"/configs/mac
                echo "-----------------------------------------------"
                echo -e "\033[32m对应设备已移除！\033[0m"
                del_all
            elif [ $num -le $((mac_filter_rows + ip_filter_rows)) ]; then
                num=$((num - mac_filter_rows))
                sed -i "${num}d" "$CRASHDIR"/configs/ip_filter
                echo "-----------------------------------------------"
                echo -e "\033[32m对应设备已移除！\033[0m"
                del_all
            else
                echo "-----------------------------------------------"
                echo -e "\033[31m输入有误，请重新输入！\033[0m"
                del_all
            fi
        fi
    }
    echo "-----------------------------------------------"
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
    ######
    echo -e "\033[30;47m请在此添加或移除设备\033[0m"
    echo -e "当前过滤方式为：\033[33m$fw_filter_lan_type模式\033[0m"
    echo -e "仅列表内设备流量\033[36m$fw_filter_lan_scrip经过\033[0m内核"
    if [ -n "$(cat "$CRASHDIR"/configs/mac)" ]; then
        echo "-----------------------------------------------"
        echo -e "当前已过滤设备为：\033[36m"
        echo -e "\033[33m 设备mac/ip地址       设备名称\033[0m"
        for dev in $(cat "$CRASHDIR"/configs/mac 2>/dev/null); do
            get_devinfo
            echo -e "\033[36m$dev_mac \033[0m$dev_name"
        done
        for dev in $(cat "$CRASHDIR"/configs/ip_filter 2>/dev/null); do
            get_devinfo
            echo -e "\033[32m$dev_ip  \033[0m$dev_name"
        done
        echo "-----------------------------------------------"
    fi
    echo -e " 1 切换为\033[33m$fw_filter_lan_over模式\033[0m"
    echo -e " 2 \033[32m添加指定设备(mac地址)\033[0m"
    echo -e " 3 \033[32m添加指定设备(IP地址/网段)\033[0m"
    echo -e " 4 \033[36m移除指定设备\033[0m"
    echo -e " 9 \033[31m清空整个列表\033[0m"
    echo -e " 0 返回上级菜单"
    read -p "请输入对应数字 > " num
    case "$num" in
    0) ;;
    1)
        macfilter_type=$fw_filter_lan_over
        setconfig macfilter_type $macfilter_type
        echo "-----------------------------------------------"
        echo -e "\033[32m已切换为$fw_filter_lan_type模式！\033[0m"
        fw_filter_lan
	;;
    2)
        add_mac
        fw_filter_lan
	;;
    3)
        add_ip
        fw_filter_lan
	;;
    4)
        del_all
        fw_filter_lan
	;;
    9)
        : >"$CRASHDIR"/configs/mac
        : >"$CRASHDIR"/configs/ip_filter
        echo "-----------------------------------------------"
        echo -e "\033[31m设备列表已清空！\033[0m"
        fw_filter_lan
	;;
    *)
        errornum
	;;
    esac
}
