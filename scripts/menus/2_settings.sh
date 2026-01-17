#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_2_SETTINGS_LOADED" ] && return
__IS_MODULE_2_SETTINGS_LOADED=1

load_lang 2_settings

# 功能设置
settings() {
    while true; do
        # 获取设置默认显示
        [ -z "$skip_cert" ] && skip_cert=ON
        [ -z "$sniffer" ] && sniffer=OFF
        [ -z "$dns_mod" ] && dns_mod='redir_host'

        echo "-----------------------------------------------"
        echo -e "\033[30;47m$SET_MENU_TITLE\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 $SET_MENU_REDIR:\t\033[36m$redir_mod\033[0m"
        echo -e " 2 $SET_MENU_DNS:\t\t\033[36m$dns_mod\033[0m"
        echo -e " 3 $SET_MENU_FW_FILTER"
        [ "$disoverride" != "1" ] && {
            echo -e " 4 $SET_MENU_SKIP_CERT:\t\033[36m$skip_cert\033[0m"
            echo -e " 5 $SET_MENU_SNIFFER:\t\033[36m$sniffer\033[0m"
            echo -e " 6 $SET_MENU_ADV_PORT"
        }
        echo -e " 8 $SET_MENU_IPV6:\t\t\033[36m$ipv6_redir\033[0m"
        echo "-----------------------------------------------"
        echo -e " 9 \033[31m$SET_MENU_RESET\033[0m"
        echo -e " 0 $COMMON_BACK"
        echo "-----------------------------------------------"
        read -p "$COMMON_INPUT > " num

        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$USER" != root -a "$USER" != admin ]; then
                echo "-----------------------------------------------"
                read -p "$SET_WARN_NONROOT (1/0) > " res
                [ "$res" = 1 ] && set_redir_mod
            else
                set_redir_mod
            fi
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
            if [ "$skip_cert" = OFF ]; then
                skip_cert=ON
                echo -e "\033[33m$SET_SKIP_CERT_ON\033[0m"
            else
                skip_cert=OFF
                echo -e "\033[33m$SET_SKIP_CERT_OFF\033[0m"
            fi
            setconfig skip_cert $skip_cert
            ;;
        5)
            echo "-----------------------------------------------"
            if [ "$sniffer" = OFF ]; then
                if [ "$crashcore" = clash ]; then
                    rm -rf "$TMPDIR/CrashCore" "$CRASHDIR/CrashCore" "$CRASHDIR/CrashCore.tar.gz"
                    crashcore=meta
                    setconfig crashcore $crashcore
                    echo "$SET_SNIFFER_CORE_SWITCH"
                fi
                sniffer=ON
            elif [ "$crashcore" = clashpre -a "$dns_mod" = redir_host ]; then
                echo -e "\033[31m$SET_SNIFFER_LOCKED\033[0m"
            else
                sniffer=OFF
            fi
            setconfig sniffer $sniffer
            ;;
        6)
            if pidof CrashCore >/dev/null; then
                echo "-----------------------------------------------"
                echo -e "\033[33m$SET_CORE_RUNNING\033[0m"
                read -p "$SET_CORE_STOP_CONFIRM (1/0) > " res
                [ "$res" = 1 ] && "$CRASHDIR/start.sh" stop && set_adv_config
            else
                set_adv_config
            fi
            ;;
        8)
            set_ipv6
            ;;
        9)
            echo "-----------------------------------------------"
            echo -e " 1 $SET_BACKUP"
            echo -e " 2 $SET_RESTORE"
            echo -e " 3 $SET_RESET"
            echo -e " 0 $COMMON_BACK"
            echo "-----------------------------------------------"
            read -p "$COMMON_INPUT > " num
            case "$num" in
                1) cp -f "$CFG_PATH" "$CFG_PATH.bak" && echo -e "\033[32m$SET_BACKUP_OK\033[0m" ;;
                2)
                    if [ -f "$CFG_PATH.bak" ]; then
                        mv -f "$CFG_PATH" "$CFG_PATH.bak2"
                        mv -f "$CFG_PATH.bak" "$CFG_PATH"
                        mv -f "$CFG_PATH.bak2" "$CFG_PATH.bak"
                        echo -e "\033[32m$SET_RESTORE_OK\033[0m"
                    else
                        echo -e "\033[31m$SET_BACKUP_MISS\033[0m"
                    fi
                    ;;
                3)
                    mv -f "$CFG_PATH" "$CFG_PATH.bak"
                    . "$CRASHDIR/init.sh" >/dev/null
                    echo -e "\033[32m$SET_RESET_OK\033[0m"
                    ;;
            esac
            echo -e "\033[33m$SET_NEED_RESTART\033[0m"
            exit 0
            ;;
        *) errornum ;;
        esac
        sleep 1
    done
}

set_redir_config() {
    setconfig redir_mod "$redir_mod"
    setconfig dns_mod "$dns_mod"
    echo "-----------------------------------------------"
    echo -e "\033[36m$SET_REDIR_APPLIED $redir_mod\033[0m"
}

# 路由模式设置
set_redir_mod() {
    while true; do
        [ -n "$(ls /dev/net/tun 2>/dev/null)" ] || ip tuntap >/dev/null 2>&1 || modprobe tun 2>/dev/null && sup_tun=1
        [ -z "$firewall_area" ] && firewall_area=1
        [ -z "$redir_mod" ] && redir_mod='Redir'
        firewall_area_dsc=$(echo "$SET_FW_AREA_DESC($bypass_host)" | cut -d'|' -f$firewall_area)
        echo "-----------------------------------------------"
        echo -e "$SET_REDIR_CURRENT \033[47;30m$redir_mod\033[0m ; $SET_CORE_CURRENT \033[47;30m$crashcore\033[0m"
        echo -e "\033[33m$SET_REDIR_RESTART_HINT\033[0m"
        echo "-----------------------------------------------"
        [ $firewall_area -le 3 ] && {
	        echo -e " 1 \033[32m$SET_REDIR_REDIR\033[0m：\t$SET_REDIR_REDIRDES"
	        echo -e " 2 \033[36m$SET_REDIR_MIX\033[0m：\t$SET_REDIR_MIXDES"
	        echo -e " 3 \033[32m$SET_REDIR_TPROXY\033[0m：\t$SET_REDIR_TPROXYDES"
	        echo -e " 4 \033[33m$SET_REDIR_TUN\033[0m：\t$SET_REDIR_TUNDES"
        	echo -e "-----------------------------------------------"
		}
        [ "$firewall_area" = 5 ] && {
            echo -e " 5 \033[32mTCP旁路转发\033[0m：    仅转发TCP流量至旁路由"
            echo -e " 6 \033[36mT&U旁路转发\033[0m：    转发TCP&UDP流量至旁路由"
            echo "-----------------------------------------------"
        }
        echo -e " 7 $SET_FW_AREA:\t\033[47;30m$firewall_area_dsc\033[0m"
        echo -e " 8 $SET_VM_REDIR:\t\033[47;30m$vm_redir\033[0m"
        echo -e " 9 $SET_FW_SWITCH:\t\033[47;30m$firewall_mod\033[0m"
        echo "-----------------------------------------------"
        echo -e " 0 $COMMON_BACK"
        read -p "$COMMON_INPUT > " num

        case "$num" in
        "" | 0)
            break
            ;;
        1)
            redir_mod=Redir
            set_redir_config
            ;;
        2)
            if [ -n "$sup_tun" ]; then
                redir_mod=Mix
                set_redir_config
            else
                echo -e "\033[31m${SET_NO_MOD}TUN$SET_NO_MOD2\033[0m"
                sleep 1
            fi
            ;;
        3)
            if [ "$firewall_mod" = "iptables" ]; then
                if [ -f /etc/init.d/qca-nss-ecm -a "$systype" = "mi_snapshot" ]; then
                    read -p "$XIAOMI_QOS(1/0) > " res
                    [ "$res" = '1' ] && {
                        /data/shellcrash_init.sh tproxyfix
                        redir_mod=Tproxy
                        set_redir_config
                    }
                elif grep -qE '^TPROXY$' /proc/net/ip_tables_targets || modprobe xt_TPROXY >/dev/null 2>&1; then
                    redir_mod=Tproxy
                    set_redir_config
                else
                    echo -e "\033[31m${SET_NO_MOD}iptables-mod-tproxy$SET_NO_MOD2\033[0m"
                    sleep 1
                fi
            elif [ "$firewall_mod" = "nftables" ]; then
                if modprobe nft_tproxy >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q nft_tproxy; then
                    redir_mod=Tproxy
                    set_redir_config
                else
                    echo -e "\033[31m${SET_NO_MOD}nft_tproxy$SET_NO_MOD2\033[0m"
                    sleep 1
                fi
            fi
            ;;
        4)
            if [ -n "$sup_tun" ]; then
                redir_mod=Tun
                set_redir_config
            else
                echo -e "\033[31m$SET_NO_TUN\033[0m"
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
                    redir_mod=Redir
                    setconfig redir_mod $redir_mod
                else
                    echo -e "\033[31m$FW_NO_NFTABLES\033[0m"
                fi
            elif [ "$firewall_mod" = 'nftables' ]; then
                if ckcmd iptables; then
                    firewall_mod=iptables
                    redir_mod=Redir
                    setconfig redir_mod $redir_mod
                else
                     echo -e "\033[31m$FW_NO_IPTABLES\033[0m"
                fi
            else
                iptables -j REDIRECT -h >/dev/null 2>&1 && firewall_mod=iptables
                nft add table inet shellcrash 2>/dev/null && firewall_mod=nftables
                if [ -n "$firewall_mod" ]; then
                    redir_mod=Redir
                    setconfig redir_mod $redir_mod
                    setconfig firewall_mod $firewall_mod
                else
                    echo -e "\033[31m$FW_NO_FIREWALL_BACKEND\033[0m"
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

inputport() {
    read -p "$INPUT_PORT(1-65535) > " portx
    . "$CRASHDIR"/menus/check_port.sh # 加载测试函数
    if check_port "$portx"; then
        setconfig "$xport" "$portx"
        echo -e "\033[32m$COMMON_SUCCESS\033[0m"
        return 0
    else
        echo -e "\033[31m$COMMON_FAILED\033[0m"
        sleep 1
        return 1
    fi
}

# 端口设置
set_adv_config() {
    while true; do
        . "$CFG_PATH" >/dev/null
        [ -z "$secret" ] && secret="$COMMON_UNSET"
        [ -z "$table" ] && table=100
        [ -z "$authentication" ] && auth="$COMMON_UNSET" || auth="******"

        echo "-----------------------------------------------"
        echo -e " 1 $ADV_HTTP_PORT:\t\033[36m$mix_port\033[0m"
        echo -e " 2 $ADV_HTTP_AUTH:\t\033[36m$auth\033[0m"
        echo -e " 3 $ADV_REDIR_PORT:\t\033[36m$redir_port,$((redir_port+1))\033[0m"
        echo -e " 4 $ADV_DNS_PORT:\t\033[36m$dns_port\033[0m"
        echo -e " 5 $ADV_PANEL_PORT:\t\033[36m$db_port\033[0m"
        echo -e " 6 $ADV_PANEL_PASS:\t\033[36m$secret\033[0m"
        echo -e " 8 $ADV_HOST:\t\033[36m$host\033[0m"
        echo -e " 9 $ADV_TABLE:\t\033[36m$table,$((table+1))\033[0m"
        echo -e " 0 $COMMON_BACK"
        read -p "$COMMON_INPUT > " num

        case "$num" in
        "" | 0)
            break
        ;;
        1)
            xport=mix_port
            inputport
            [ $? -eq 1 ] && break || continue
        ;;
        2)
            echo "-----------------------------------------------"
            echo -e "$ADV_AUTH_FORMAT_DESC"
            echo -e "$ADV_AUTH_WARN"
            echo -e "$ADV_AUTH_REMOVE_HINT"
            echo "-----------------------------------------------"
            read -p "$ADV_AUTH_INPUT > " input

            if [ "$input" = "0" ]; then
                authentication=""
                setconfig authentication
                echo -e "\033[32m$ADV_AUTH_REMOVED\033[0m"
            else
                if [ "$local_proxy" = "ON" ] && [ "$local_type" = "$LOCAL_TYPE_ENV" ]; then
                    echo "-----------------------------------------------"
                    echo -e "\033[33m$ADV_AUTH_ENV_CONFLICT\033[0m"
                    sleep 1
                else
                    authentication=$(echo "$input" | grep :)
                    if [ -n "$authentication" ]; then
                        setconfig authentication "'$authentication'"
                        echo -e "\033[32m$COMMON_SUCCESS\033[0m"
                    else
                        echo -e "\033[31m$ADV_AUTH_INVALID\033[0m"
                    fi
                fi
            fi
        ;;
        3)
            xport=redir_port
            inputport
            [ $? -eq 1 ] && break || continue
        ;;
        4)
            xport=dns_port
            inputport
            [ $? -eq 1 ] && break || continue
        ;;
        5)
            xport=db_port
            inputport
            [ $? -eq 1 ] && break || continue
        ;;
        6)
            read -p "$ADV_PANEL_PASS_INPUT > " secret
            if [ -n "$secret" ]; then
                [ "$secret" = "0" ] && secret=""
                setconfig secret "$secret"
                echo -e "\033[32m$COMMON_SUCCESS\033[0m"
            fi
        ;;
        8)
            echo "-----------------------------------------------"
            echo -e "\033[33m$ADV_HOST_WARN_LAN\033[0m"
            echo -e "\033[31m$ADV_HOST_WARN_CHANGE\033[0m"
            echo "-----------------------------------------------"
            read -p "$ADV_HOST_INPUT > " host

            if [ "$host" = "0" ]; then
                host=""
                setconfig host "$host"
                echo -e "\033[32m$ADV_HOST_REMOVED\033[0m"
                exit 0
            elif echo "$host" | grep -Eq '\<([1-9]|[1-9][0-9]|1[0-9]{2}|2[01][0-9]|22[0-3])\>(\.\<([0-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\>){2}\.\<([1-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])\>' ; then
                setconfig host "$host"
                echo -e "\033[32m$COMMON_SUCCESS\033[0m"
            else
                host=""
                echo -e "\033[31m$ADV_HOST_INVALID\033[0m"
            fi
            sleep 1
        ;;
        9)
            echo "-----------------------------------------------"
            echo -e "\033[33m$ADV_TABLE_WARN\033[0m"
            read -p "$ADV_TABLE_INPUT > " table
            if [ -n "$table" ]; then
                [ "$table" = "0" ] && table="100"
                setconfig table "$table"
                echo -e "\033[32m$COMMON_SUCCESS\033[0m"
            fi
        ;;
        *)
            errornum
            sleep 1
        ;;
        esac
    done
}

set_firewall_area() {
    [ -z "$vm_redir" ] && vm_redir='OFF'
    echo "-----------------------------------------------"
    echo -e "\033[33m$FW_AREA_NOTE\033[0m"
    echo "-----------------------------------------------"
    echo -e " 1 \033[32m$FW_AREA_LAN\033[0m"
    echo -e " 2 \033[36m$FW_AREA_LOCAL\033[0m"
    echo -e " 3 \033[32m$FW_AREA_BOTH\033[0m"
    echo -e " 4 $FW_AREA_NONE"
    echo -e " 0 $COMMON_BACK"
    echo "-----------------------------------------------"
    read -p "$COMMON_INPUT > " num

    case "$num" in
    [1-4])
        [ $firewall_area -ge 4 ] && {
            redir_mod=Redir
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
	[ -z "$vm_ipv4" ] && vm_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'brd' | grep -E 'docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | sed 's/.*inet.//g' | sed 's/ br.*$//g' | sed 's/metric.*$//g' | tr '\n' ' ')
    echo "-----------------------------------------------"
    echo -e "$VM_DETECT_DESC\033[32m$vm_ipv4\033[0m"
    echo "-----------------------------------------------"
    echo -e " 1 \033[32m$VM_ENABLE_AUTO\033[0m"
    echo -e " 2 \033[36m$VM_ENABLE_MANUAL\033[0m"
    echo -e " 3 \033[31m$VM_DISABLE\033[0m"
    echo -e " 0 $COMMON_BACK"
    echo "-----------------------------------------------"
    read -p "$COMMON_INPUT > " num

    case "$num" in
	1)
		if [ -n "$vm_ipv4" ]; then
			vm_redir=ON
		else
			echo -e "\033[33m$VM_NO_NET_DETECTED\033[0m"
		fi
	;;
    2) 
		echo -e "$VM_INPUT_DESC"
		echo -e "\033[32m10.88.0.0/16 172.17.0.0/16\033[0m"
		read -p "$VM_INPUT_NET > " text
		[ -n "$text" ] && vm_ipv4="$text" && vm_redir=ON
	;;
    3)
		vm_redir=OFF
		vm_ipv4=''
	;;
    *) ;;
    esac
	case "$num" in
	1-3) 
		setconfig vm_redir "$vm_redir"
		setconfig vm_ipv4 "'$vm_ipv4'"
	;;
	esac
}

# ipv6设置
set_ipv6() {
    while true; do
        [ -z "$ipv6_redir" ] && ipv6_redir=OFF
        [ -z "$ipv6_dns" ] && ipv6_dns=ON

        echo "-----------------------------------------------"
        echo -e " 1 $IPV6_REDIR:\t\033[36m$ipv6_redir\033[0m"
        [ "$disoverride" != "1" ] && echo -e " 2 $IPV6_DNS:\t\033[36m$ipv6_dns\033[0m"
        echo -e " 0 $COMMON_BACK"
        echo "-----------------------------------------------"
        read -p "$COMMON_INPUT > " num

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
            [ "$ipv6_dns" = OFF ] && ipv6_dns=ON || ipv6_dns=OFF
            setconfig ipv6_dns "$ipv6_dns"
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}
