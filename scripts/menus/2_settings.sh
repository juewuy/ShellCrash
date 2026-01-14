#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_2_SETTINGS_LOADED" ] && return
__IS_MODULE_2_SETTINGS_LOADED=1

# 功能设置
settings() {
    while true; do
        # 获取设置默认显示
        [ -z "$skip_cert" ] && skip_cert=ON
        [ -z "$sniffer" ] && sniffer=OFF
        [ -z "$dns_mod" ] && dns_mod='redir_host'

        echo "-----------------------------------------------"
        echo -e "\033[30;47m欢迎使用功能设置菜单：\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 路由模式设置:	\033[36m$redir_mod\033[0m"
        echo -e " 2 DNS设置：		\033[36m$dns_mod\033[0m"
        echo -e " 3 透明路由\033[32m流量过滤\033[0m"
        [ "$disoverride" != "1" ] && {
            echo -e " 4 跳过证书验证：	\033[36m$skip_cert\033[0m"
            echo -e " 5 启用域名嗅探:	\033[36m$sniffer\033[0m"
            echo -e " 6 自定义\033[32m端口及秘钥\033[0m"
        }
        echo -e " 8 ipv6设置：		\033[36m$ipv6_redir\033[0m"
        echo "-----------------------------------------------"
        echo -e " 9 \033[31m重置/备份/还原\033[0m脚本设置"
        echo -e " 0 返回上级菜单 \033[0m"
        echo "-----------------------------------------------"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$USER" != "root" -a "$USER" != "admin" ]; then
                echo "-----------------------------------------------"
                read -p "非root用户可能无法正确配置其他模式！依然尝试吗？(1/0) > " res
                [ "$res" = 1 ] && set_redir_mod
            else
                set_redir_mod
            fi
            sleep 1
            ;;
        2)
            . "$CRASHDIR"/menus/dns.sh && set_dns_mod
            sleep 1
            ;;
        3)
            . "$CRASHDIR"/menus/fw_filter.sh && set_fw_filter
            sleep 1
            ;;
        4)
            echo "-----------------------------------------------"
            if [ "$skip_cert" = "OFF" ] >/dev/null 2>&1; then
                echo -e "\033[33m已设为开启跳过本地证书验证！！\033[0m"
                skip_cert=ON
            else
                echo -e "\033[33m已设为禁止跳过本地证书验证！！\033[0m"
                skip_cert=OFF
            fi
            setconfig skip_cert $skip_cert
            ;;
        5)
            echo "-----------------------------------------------"
            if [ "$sniffer" = "OFF" ]; then
                if [ "$crashcore" = "clash" ]; then
                    rm -rf ${TMPDIR}/CrashCore
                    rm -rf "$CRASHDIR"/CrashCore
                    rm -rf "$CRASHDIR"/CrashCore.tar.gz
                    crashcore=meta
                    setconfig crashcore $crashcore
                    echo "已将ShellCrash内核切换为Meta内核！域名嗅探依赖Meta或者高版本clashpre内核！"
                fi
                sniffer=ON
            elif [ "$crashcore" = "clashpre" -a "$dns_mod" = "redir_host" ]; then
                echo -e "\033[31m使用clashpre内核且开启redir-host模式时无法关闭！\033[0m"
            else
                sniffer=OFF
            fi
            setconfig sniffer $sniffer
            ;;
        6)
            if [ -n "$(pidof CrashCore)" ]; then
                echo "-----------------------------------------------"
                echo -e "\033[33m检测到服务正在运行，需要先停止服务！\033[0m"
                read -p "是否停止服务？(1/0) > " res
                if [ "$res" = "1" ]; then
                    "$CRASHDIR"/start.sh stop
                    set_adv_config
                fi
            else
                set_adv_config
            fi
            ;;
        8)
            set_ipv6
            ;;
        9)
            echo "-----------------------------------------------"
            echo -e " 1 备份脚本设置"
            echo -e " 2 还原脚本设置"
            echo -e " 3 重置脚本设置"
            echo -e " 0 返回上级菜单"
            echo "-----------------------------------------------"
            read -p "请输入对应数字 > " num
            if [ -z "$num" ]; then
                errornum
            elif [ "$num" = 0 ]; then
                i=
            elif [ "$num" = 1 ]; then
                cp -f "$CFG_PATH" "$CFG_PATH".bak
                echo -e "\033[32m脚本设置已备份！\033[0m"
            elif [ "$num" = 2 ]; then
                if [ -f "$CFG_PATH.bak" ]; then
                    mv -f "$CFG_PATH" "$CFG_PATH".bak2
                    mv -f "$CFG_PATH".bak "$CFG_PATH"
                    mv -f "$CFG_PATH".bak2 "$CFG_PATH".bak
                    echo -e "\033[32m脚本设置已还原！(被覆盖的配置已备份！)\033[0m"
                else
                    echo -e "\033[31m找不到备份文件，请先备份脚本设置！\033[0m"
                fi
            elif [ "$num" = 3 ]; then
                mv -f "$CFG_PATH" "$CFG_PATH".bak
                . "$CRASHDIR"/init.sh >/dev/null
                echo -e "\033[32m脚本设置已重置！(旧文件已备份！)\033[0m"
            fi
            echo -e "\033[33m请重新启动脚本！\033[0m"
            exit 0
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}

set_redir_config() {
    setconfig redir_mod $redir_mod
    setconfig dns_mod $dns_mod
    echo "-----------------------------------------------"
    echo -e "\033[36m已设为 $redir_mod ！！\033[0m"
}

# 路由模式设置
set_redir_mod() {
    while true; do
        [ -n "$(ls /dev/net/tun 2>/dev/null)" ] || ip tuntap >/dev/null 2>&1 || modprobe tun 2>/dev/null && sup_tun=1
        [ -z "$firewall_area" ] && firewall_area=1
        [ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod='Redir模式'
        [ -z "$redir_mod" ] && redir_mod='纯净模式'
        firewall_area_dsc=$(echo "仅局域网 仅本机 局域网+本机 纯净模式 主-旁转发($bypass_host)" | cut -d' ' -f$firewall_area)
        echo "-----------------------------------------------"
        echo -e "当前路由模式为：\033[47;30m$redir_mod\033[0m；ShellCrash核心为：\033[47;30m $crashcore \033[0m"
        echo -e "\033[33m切换模式后需要手动重启服务以生效！\033[0m"
        echo "-----------------------------------------------"
        [ $firewall_area -le 3 ] && {
            echo -e " 1 \033[32mRedir模式\033[0m：    Redir转发TCP，不转发UDP"
            echo -e " 2 \033[36m混合模式\033[0m：     Redir转发TCP，Tun转发UDP"
            echo -e " 3 \033[32mTproxy模式\033[0m：   Tproxy转发TCP&UDP"
            echo -e " 4 \033[33mTun模式\033[0m：      Tun转发TCP&UDP(占用高不推荐)"
            echo "-----------------------------------------------"
        }
        [ "$firewall_area" = 5 ] && {
            echo -e " 5 \033[32mTCP旁路转发\033[0m：    仅转发TCP流量至旁路由"
            echo -e " 6 \033[36mT&U旁路转发\033[0m：    转发TCP&UDP流量至旁路由"
            echo "-----------------------------------------------"
        }
        echo -e " 7 设置路由劫持范围：	\033[47;30m$firewall_area_dsc\033[0m"
        echo -e " 8 容器/虚拟机劫持：	\033[47;30m$vm_redir\033[0m"
        echo -e " 9 切换防火墙应用：	\033[47;30m$firewall_mod\033[0m"
        echo "-----------------------------------------------"
        echo " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            redir_mod=Redir模式
            set_redir_config
            ;;
        2)
            if [ -n "$sup_tun" ]; then
                redir_mod=混合模式
                set_redir_config
            else
                echo -e "\033[31m设备未检测到Tun内核模块，请尝试其他模式或者安装相关依赖！\033[0m"
                sleep 1
            fi
            ;;
        3)
            if [ "$firewall_mod" = "iptables" ]; then
                if [ -f /etc/init.d/qca-nss-ecm -a "$systype" = "mi_snapshot" ]; then
                    read -p "xiaomi设备的QOS服务与本模式冲突，是否禁用相关功能？(1/0) > " res
                    [ "$res" = '1' ] && {
                        /data/shellcrash_init.sh tproxyfix
                        redir_mod=Tproxy模式
                        set_redir_config
                    }
                elif grep -qE '^TPROXY$' /proc/net/ip_tables_targets || modprobe xt_TPROXY >/dev/null 2>&1; then
                    redir_mod=Tproxy模式
                    set_redir_config
                else
                    echo -e "\033[31m设备未检测到iptables-mod-tproxy模块，请尝试其他模式或者安装相关依赖！\033[0m"
                    sleep 1
                fi
            elif [ "$firewall_mod" = "nftables" ]; then
                if modprobe nft_tproxy >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q nft_tproxy; then
                    redir_mod=Tproxy模式
                    set_redir_config
                else
                    echo -e "\033[31m设备未检测到nft_tproxy内核模块，请尝试其他模式或者安装相关依赖！\033[0m"
                    sleep 1
                fi
            fi
            ;;
        4)
            if [ -n "$sup_tun" ]; then
                redir_mod=Tun模式
                set_redir_config
            else
                echo -e "\033[31m设备未检测到Tun内核模块，请尝试其他模式或者安装相关依赖！\033[0m"
                sleep 1
            fi
            ;;
        5)
            redir_mod='TCP旁路转发'
            set_redir_config
            ;;
        6)
            redir_mod='T&U旁路转发'
            set_redir_config
            ;;
        7)
            set_firewall_area
            ;;
        8)
            set_firewall_vm
            ;;
        9)
            if [ "$firewall_mod" = 'iptables' ]; then
                if nft add table inet shellcrash 2>/dev/null; then
                    firewall_mod=nftables
                    redir_mod=Redir模式
                    setconfig redir_mod $redir_mod
                else
                    echo -e "\033[31m当前设备未安装nftables或者nftables版本过低(<1.0.2),无法切换！\033[0m"
                fi
            elif [ "$firewall_mod" = 'nftables' ]; then
                if ckcmd iptables; then
                    firewall_mod=iptables
                    redir_mod=Redir模式
                    setconfig redir_mod $redir_mod
                else
                    echo -e "\033[31m当前设备未安装iptables,无法切换！\033[0m"
                fi
            else
                iptables -j REDIRECT -h >/dev/null 2>&1 && firewall_mod=iptables
                nft add table inet shellcrash 2>/dev/null && firewall_mod=nftables
                if [ -n "$firewall_mod" ]; then
                    redir_mod=Redir模式
                    setconfig redir_mod $redir_mod
                    setconfig firewall_mod $firewall_mod
                else
                    echo -e "\033[31m检测不到可用的防火墙应用(iptables/nftables),无法切换！\033[0m"
                fi
            fi
            sleep 1
            setconfig firewall_mod $firewall_mod
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}

set_adv_config() { #端口设置
    . "$CFG_PATH" >/dev/null
    [ -z "$secret" ] && secret=未设置
    [ -z "$table" ] && table=100
    [ -z "$authentication" ] && auth=未设置 || auth=******
    inputport() {
        read -p "请输入端口号(1-65535) > " portx
		. "$CRASHDIR"/menus/check_port.sh #加载测试函数
        if check_port "$portx"; then
            setconfig "$xport" "$portx"
            echo -e "\033[32m设置成功！！！\033[0m"
			set_adv_config
		else
			sleep 1
		fi	
    }
    echo "-----------------------------------------------"
    echo -e " 1 修改Http/Sock5端口：	\033[36m$mix_port\033[0m"
    echo -e " 2 设置Http/Sock5密码：	\033[36m$auth\033[0m"
    echo -e " 3 修改Redir/Tproxy端口：\033[36m$redir_port,$((redir_port + 1))\033[0m"
    echo -e " 4 修改DNS监听端口：	\033[36m$dns_port\033[0m"
    echo -e " 5 修改面板访问端口：	\033[36m$db_port\033[0m"
    echo -e " 6 设置面板访问密码：	\033[36m$secret\033[0m"
    echo -e " 8 自定义本机host地址：	\033[36m$host\033[0m"
    echo -e " 9 自定义路由表：	\033[36m$table,$((table + 1))\033[0m"
    echo -e " 0 返回上级菜单"
    read -p "请输入对应数字 > " num
    case "$num" in
    0) ;;
    1)
        xport=mix_port
        inputport
	;;
    2)
        echo "-----------------------------------------------"
        echo -e "格式必须是\033[32m 用户名:密码 \033[0m的形式，注意用小写冒号分隔！"
        echo -e "请尽量不要使用特殊符号！避免产生未知错误！"
        echo "输入 0 删除密码"
        echo "-----------------------------------------------"
        read -p "请输入Http/Sock5用户名及密码 > " input
        if [ "$input" = "0" ]; then
            authentication=""
            setconfig authentication
            echo 密码已移除！
        else
            if [ "$local_proxy" = "ON" -a "$local_type" = "环境变量" ]; then
                echo "-----------------------------------------------"
                echo -e "\033[33m请先禁用本机劫持功能或使用增强模式！\033[0m"
                sleep 1
            else
                authentication=$(echo $input | grep :)
                if [ -n "$authentication" ]; then
                    setconfig authentication "'$authentication'"
                    echo -e "\033[32m设置成功！！！\033[0m"
                else
                    echo -e "\033[31m输入有误，请重新输入！\033[0m"
                fi
            fi
        fi
        set_adv_config
	;;
    3)
        xport=redir_port
        inputport
	;;
    4)
        xport=dns_port
        inputport
	;;
    5)
        xport=db_port
        inputport
	;;
    6)
        read -p "请输入面板访问密码(输入0删除密码) > " secret
        if [ -n "$secret" ]; then
            [ "$secret" = "0" ] && secret=""
            setconfig secret $secret
            echo -e "\033[32m设置成功！！！\033[0m"
        fi
        set_adv_config
	;;
    8)
        echo "-----------------------------------------------"
        echo -e "\033[33m如果你的局域网网段不是192.168.x或172.16.x或10.x开头，请务必修改！\033[0m"
        echo -e "\033[31m设置后如本机host地址有变动，请务必重新修改！\033[0m"
        echo "-----------------------------------------------"
        read -p "请输入自定义host地址(输入0移除自定义host) > " host
        if [ "$host" = "0" ]; then
            host=""
            setconfig host "$host"
            echo -e "\033[32m已经移除自定义host地址，请重新运行脚本以自动获取host！！！\033[0m"
            exit 0
        elif [ -n "$(echo $host | grep -E -o '\<([1-9]|[1-9][0-9]|1[0-9]{2}|2[01][0-9]|22[0-3])\>(\.\<([0-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\>){2}\.\<([1-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])\>')" ]; then
            setconfig host "$host"
            echo -e "\033[32m设置成功！！！\033[0m"
        else
            host=""
            echo -e "\033[31m输入错误，请仔细核对！！！\033[0m"
        fi
        sleep 1
        set_adv_config
	;;
    9)
        echo "-----------------------------------------------"
        echo -e "\033[33m仅限Tproxy、Tun或混合模式路由表出现冲突时才需要设置！\033[0m"
        read -p "请输入路由表地址(不明勿动！建议102-125之间) > " table
        if [ -n "$table" ]; then
            [ "$table" = "0" ] && table="100"
            setconfig table "$table"
            echo -e "\033[32m设置成功！！！\033[0m"
        fi
        set_adv_config
	;;
    *)
        errornum
	;;
    esac
}
set_firewall_area() { #路由范围设置
    [ -z "$vm_redir" ] && vm_redir='OFF'
    echo "-----------------------------------------------"
    echo -e "\033[31m注意：\033[0m基于桥接网卡的Docker/虚拟机流量，请单独启用！"
    echo -e "\033[33m如你使用了第三方DNS如smartdns等，请勿启用本机劫持或使用shellcrash用户执行！\033[0m"
    echo "-----------------------------------------------"
    echo -e " 1 \033[32m仅劫持局域网流量\033[0m"
    echo -e " 2 \033[36m仅劫持本机流量\033[0m"
    echo -e " 3 \033[32m劫持局域网+本机流量\033[0m"
    echo -e " 4 不配置流量劫持(纯净模式)\033[0m"
    #echo -e " 5 \033[33m转发局域网流量到旁路由设备\033[0m"
    echo -e " 0 返回上级菜单"
    echo "-----------------------------------------------"
    read -p "请输入对应数字 > " num
    case "$num" in
    0) ;;
    [1-4])
        [ $firewall_area -ge 4 ] && {
            redir_mod=Redir模式
            setconfig redir_mod $redir_mod
        }
        [ "$num" = 4 ] && {
            redir_mod=纯净模式
            setconfig redir_mod $redir_mod
        }
        firewall_area=$num
        setconfig firewall_area $firewall_area
	;;
    5)
        echo "-----------------------------------------------"
        echo -e "\033[31m注意：\033[0m此功能存在多种风险如无网络基础请勿尝试！"
        echo -e "\033[33m说明：\033[0m此功能不启动内核仅配置防火墙转发，且子设备无需额外设置网关DNS"
        echo -e "\033[33m说明：\033[0m支持防火墙分流及设备过滤，支持部分定时任务，但不支持ipv6！"
        echo -e "\033[31m注意：\033[0m如需代理UDP，请确保旁路由运行了支持UDP代理的模式！"
        echo -e "\033[31m注意：\033[0m如使用systemd方式启动，内核依然会空载运行，建议使用保守模式！"
        echo "-----------------------------------------------"
        read -p "请输入旁路由IPV4地址 > " bypass_host
        [ -n "$bypass_host" ] && {
            firewall_area=$num
            setconfig firewall_area $firewall_area
            setconfig bypass_host $bypass_host
            redir_mod=TCP旁路转发
            setconfig redir_mod $redir_mod
        }
	;;
    *) errornum ;;
    esac
    sleep 1
}
set_firewall_vm(){
	if [ -n "$vm_ipv4" ]; then
		vm_des='当前劫持'
	else
		vm_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'brd' | grep -E 'docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | sed 's/.*inet.//g' | sed 's/ br.*$//g' | sed 's/metric.*$//g' | tr '\n' ' ')
		vm_des='当前获取到'
	fi
	echo "-----------------------------------------------"
	echo -e "$vm_des的容器/虚拟机网段为：\033[32m$vm_ipv4\033[0m"
	echo -e "如未包含容器网段，请先运行容器再运行脚本或者手动设置网段"
	echo "-----------------------------------------------"
	echo -e " 1 \033[32m启用劫持并使用默认网段\033[0m"
	echo -e " 2 \033[36m启用劫持并自定义网段\033[0m"
	echo -e " 3 \033[31m禁用劫持\033[0m"
	echo -e " 0 返回上级菜单"
	echo "-----------------------------------------------"
	read -p "请输入对应数字 > " num
	case "$num" in
	1)
		if [ -n "$vm_ipv4" ]; then
			vm_redir=ON
		else
			echo -e "\033[33m请先运行容器再运行脚本或者手动设置网段\033[0m"
		fi
	;;
	2)
		echo -e "多个网段请用空格连接，可运行容器后使用【ip route】命令查看网段地址"
		echo -e "示例：\033[32m10.88.0.0/16 172.17.0.0/16\033[0m"
		read -p "请输入自定义网段 > " text
		[ -n "$text" ] && vm_ipv4=$text && vm_redir=ON
	;;
	3)
		vm_redir=OFF
		unset vm_ipv4
	;;
	*) ;;
	esac
	setconfig vm_redir $vm_redir
	setconfig vm_ipv4 "'$vm_ipv4'"
}

# ipv6设置
set_ipv6() {
    while true; do
        [ -z "$ipv6_redir" ] && ipv6_redir=OFF
        [ -z "$ipv6_dns" ] && ipv6_dns=ON
        echo "-----------------------------------------------"
        echo -e " 1 ipv6透明路由:  \033[36m$ipv6_redir\033[0m  ——劫持ipv6流量"
        [ "$disoverride" != "1" ] && echo -e " 2 ipv6-DNS解析:  \033[36m$ipv6_dns\033[0m  ——决定内置DNS是否返回ipv6地址"
        echo -e " 0 返回上级菜单"
        echo "-----------------------------------------------"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$ipv6_redir" = "OFF" ]; then
                ipv6_support=ON
                ipv6_redir=ON
                sleep 2
            else
                ipv6_redir=OFF
            fi
            setconfig ipv6_redir $ipv6_redir
            setconfig ipv6_support $ipv6_support
            ;;
        2)
            [ "$ipv6_dns" = "OFF" ] && ipv6_dns=ON || ipv6_dns=OFF
            setconfig ipv6_dns $ipv6_dns
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}
