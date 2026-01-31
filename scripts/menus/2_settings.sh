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
        [ -z "$sniffer" ] && {
            sniffer=OFF
            echo "$crashcore" | grep -q 'singbox' && sniffer=ON
        }
        [ -z "$dns_mod" ] && dns_mod='redir_host'

        line_break
        separator_line "="
        content_line "\033[30;47m$SET_MENU_TITLE\033[0m"
        separator_line "="
        content_line "1) $SET_MENU_REDIR\t\033[36m$redir_mod$MENU_MOD\033[0m"
        content_line "2) $SET_MENU_DNS\t\033[36m$dns_mod\033[0m"
        content_line "3) $SET_MENU_FW_FILTER"
        [ "$disoverride" != "1" ] && {
            content_line "4) $SET_MENU_SKIP_CERT\t\033[36m$skip_cert\033[0m"
            content_line "5) $SET_MENU_SNIFFER\t\033[36m$sniffer\033[0m"
            content_line "6) $SET_MENU_ADV_PORT"
        }
        content_line "8) $SET_MENU_IPV6\t\033[36m$ipv6_redir\033[0m"
        separator_line "-"
        content_line "a) \033[31m$SET_MENU_RESET\033[0m"
        content_line "b) \033[36m$SET_MENU_LANG\033[0m"
        content_line "c) \033[33m$SET_MENU_UI\033[0m"
        content_line "0) $COMMON_BACK"
        separator_line "="
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$USER" != root ] && [ "$USER" != admin ]; then
                line_break
                separator_line "="
                content_line "$SET_WARN_NONROOT"
                separator_line "="
                content_line "1) 是"
                content_line "0) 否，返回上级菜单"
                separator_line "="
                read -r -p "$COMMON_INPUT> " res
                if [ "$res" = 1 ]; then
                    set_redir_mod
                else
                    continue
                fi
            else
                set_redir_mod
            fi
            ;;
        2)
            . "$CRASHDIR"/menus/dns.sh && set_dns_mod
            ;;
        3)
            . "$CRASHDIR"/menus/fw_filter.sh && set_fw_filter
            ;;
        4)
            line_break
            separator_line "="
            if [ "$skip_cert" = "OFF" ]; then
                content_line "当前\033[33m已禁用\033[0m跳过本地证书验证，是否确认启用："
            else
                content_line "当前\033[33m已启用\033[0m跳过本地证书验证，是否确认禁用："
            fi
            separator_line "="
            content_line "1) 是"
            content_line "0) 否，返回上级菜单"
            separator_line "="
            read -r -p "$COMMON_INPUT> " num

            if [ "$num" = 1 ]; then
                line_break
                separator_line "="
                if [ "$skip_cert" = OFF ]; then
                    skip_cert=ON
                    content_line "\033[33m$SET_SKIP_CERT_ON\033[0m"
                else
                    skip_cert=OFF
                    content_line "\033[33m$SET_SKIP_CERT_OFF\033[0m"
                fi
                setconfig skip_cert $skip_cert
                separator_line "="
            else
                continue
            fi
            sleep 1
            ;;
        5)
            line_break
            separator_line "="
            if [ "$sniffer" = "OFF" ]; then
                content_line "当前\033[33m已禁用\033[0m域名嗅探，是否确认启用："
                separator_line "="
                content_line "1) 是"
                content_line "0) 否，返回上级菜单"
                separator_line "="
                read -r -p "$COMMON_INPUT> " num

                if [ "$num" = 1 ]; then
                    line_break
                    separator_line "="
                    if [ "$crashcore" = "clash" ]; then
                        rm -rf "$TMPDIR/CrashCore" "$CRASHDIR/CrashCore" "$CRASHDIR/CrashCore.tar.gz"
                        crashcore=meta
                        setconfig crashcore $crashcore
                        line_break
                        content_line "$SET_SNIFFER_CORE_SWITCH"
                        content_line ""
                    fi
                    sniffer=ON
                else
                    continue
                fi
            elif [ "$crashcore" = clashpre ] && [ "$dns_mod" = redir_host ]; then
                content_line "\033[31m$SET_SNIFFER_LOCKED\033[0m"
                separator_line "="
                sleep 1
                continue
            else
                content_line "当前\033[33m已启用\033[0m域名嗅探，是否确认禁用："
                separator_line "="
                content_line "1) 是"
                content_line "0) 否，返回上级菜单"
                separator_line "="
                read -r -p "$COMMON_INPUT> " num
                if [ "$num" = 1 ]; then
                    sniffer=OFF
                    line_break
                    separator_line "="
                else
                    continue
                fi
            fi
            setconfig sniffer "$sniffer"
            content_line "\033[32m操作成功\033[0m"
            separator_line "="
            sleep 1
            ;;
        6)
            if pidof CrashCore >/dev/null; then
                line_break
                separator_line "="
                content_line "\033[33m$SET_CORE_RUNNING\033[0m"
                content_line "$SET_CORE_STOP_CONFIRM"
                separator_line "="
                content_line "1) 是"
                content_line "0) 否，返回上级菜单"
                separator_line "="
                read -r -p "$COMMON_INPUT> " res
                if [ "$res" = 1 ]; then
                    "$CRASHDIR/start.sh" stop && set_adv_config
                else
                    continue
                fi
            else
                set_adv_config
            fi
            ;;
        8)
            set_ipv6
            ;;
        a)
			BACK_TAR="$CRASHDIR/configs.tar.gz"
            line_break
            separator_line "="
            content_line "1) $SET_BACKUP"
            content_line "2) $SET_RESTORE"
            content_line "3) $SET_RESET"
            content_line "0) $COMMON_BACK"
            separator_line "="
            read -r -p "$COMMON_INPUT> " num
            case "$num" in
            "" | 0)
                continue
                ;;
            1)
                line_break
                separator_line "="
                if tar -zcf "$BACK_TAR" -C "$CRASHDIR/configs/" .; then
                    content_line "\033[32m$SET_BACKUP_OK $BACK_TAR\033[0m"
                else
                    content_line "\033[31m$SET_BACKUP_FAIL\033[0m"
                fi
				sleep 1
				continue
                ;;
            2)
                line_break
                separator_line "="
                if [ -f "$BACK_TAR" ]; then
					tar -zcf "$TMPDIR/configs.tar.gz" -C "$CRASHDIR/configs/" .
					rm -rf "$CRASHDIR/configs/*"
                    tar -zxf "$BACK_TAR" -C "$CRASHDIR"/configs
					mv -f "$TMPDIR/configs.tar.gz" "$BACK_TAR"
                    content_line "\033[32m$SET_RESTORE_OK $BACK_TAR\033[0m"
                else
                    content_line "\033[31m$SET_BACKUP_MISS\033[0m"
                fi
                ;;
            3)
                line_break
                separator_line "="
                if tar -zcf "$BACK_TAR" -C "$CRASHDIR/configs/" .; then
					rm -rf "$CRASHDIR/configs"
                    . "$CRASHDIR/init.sh" >/dev/null
                    content_lin e"\033[32m$SET_RESET_OK\033[0m"
                else
                    content_lin e"\033[32m$SET_RESET_FAIL\033[0m"
                fi
                ;;
            *)
                errornub
                sleep 1
                continue
                ;;
            esac
            content_line "\033[33m$SET_NEED_RESTART\033[0m"
            sleep 1
            exit 0
            ;;
        b)
            line_break
            separator_line "="
            content_line "1) 简体中文"
            content_line "2) English"
            content_line "0) $COMMON_BACK"
            separator_line "="
            read -r -p "$COMMON_INPUT> " num
            case "$num" in
            "" | 0)
                continue
                ;;
            1)
                line_break
                separator_line "="
                echo chs >"$CRASHDIR"/configs/i18n.cfg
                content_line "\033[32m切换成功！请重新运行脚本！\033[0m"
                ;;
            2)
                line_break
                separator_line "="
                echo en >"$CRASHDIR"/configs/i18n.cfg
                content_line "\033[32mLanguage switched successfully! Please re-run the script!\033[0m"
                ;;
            esac
            separator_line "="
            line_break
            sleep 1
            exit 0
            ;;
        c)
            line_break
            separator_line "="
            content_line "1) New Design by Sofia-Riese"
            content_line "2) TUI-lite"
            content_line "0) $COMMON_BACK"
            separator_line "="
            read -r -p "$COMMON_INPUT> " num
            case "$num" in
            "" | 0)
                continue
                ;;
            1)
                setconfig tui_type 'tui_layout'
                . "$CRASHDIR"/menus/tui_layout.sh
                ;;
            2)
                setconfig tui_type 'tui_lite'
                . "$CRASHDIR"/menus/tui_lite.sh
                ;;
            esac
            line_break
            separator_line "="
            content_line "\033[32m切换成功！\033[0m"
            separator_line "="
            sleep 1
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}

set_redir_config() {
    setconfig redir_mod "$redir_mod"
    setconfig dns_mod "$dns_mod"
    line_break
    separator_line "="
    content_line "\033[36m$SET_REDIR_APPLIED $redir_mod\033[0m"
    separator_line "="
    sleep 1
}

# 路由模式设置
set_redir_mod() {
    while true; do
        [ -n "$(ls /dev/net/tun 2>/dev/null)" ] || ip tuntap >/dev/null 2>&1 || modprobe tun 2>/dev/null && sup_tun=1
        [ -z "$firewall_area" ] && firewall_area=1
        [ "$firewall_area" = 4 ] && redir_mod="$MENU_PURE_MOD"
        [ -z "$redir_mod" ] && redir_mod='Redir'
        firewall_area_dsc=$(echo "$SET_FW_AREA_DESC($bypass_host)" | cut -d'|' -f$firewall_area)
        line_break
        separator_line "="
        content_line "\033[33m$SET_REDIR_RESTART_HINT\033[0m"
        content_line "$SET_REDIR_CURRENT\033[47;30m$redir_mod$MENU_MOD\033[0m；  $SET_CORE_CURRENT\033[47;30m$crashcore\033[0m"
        separator_line "="
        [ "$firewall_area" -le 3 ] && {
            content_line "1) \033[32m$SET_REDIR_REDIR\033[0m：\t$SET_REDIR_REDIRDES"
            content_line "2) \033[36m$SET_REDIR_MIX\033[0m：\t$SET_REDIR_MIXDES"
            content_line "3) \033[32m$SET_REDIR_TPROXY\033[0m：$SET_REDIR_TPROXYDES"
            content_line "4) \033[33m$SET_REDIR_TUN\033[0m：\t$SET_REDIR_TUNDES"
            content_line ""
        }
        [ "$firewall_area" = 5 ] && {
            content_line "5) \033[32mTCP旁路转发\033[0m：    仅转发TCP流量至旁路由"
            content_line "6) \033[36mT&U旁路转发\033[0m：    转发TCP&UDP流量至旁路由"
            content_line ""
        }
        content_line "7) $SET_FW_AREA：\t\033[47;30m$firewall_area_dsc\033[0m"
        content_line "8) $SET_VM_REDIR：\t\033[47;30m$vm_redir\033[0m"
        content_line "9) $SET_FW_SWITCH：\t\033[47;30m$firewall_mod\033[0m"
        content_line ""
        content_line "0 $COMMON_BACK"
        separator_line "="
        read -r -p "$COMMON_INPUT> " num

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
                line_break
                separator_line "="
                content_line "\033[31m${SET_NO_MOD}TUN\033[0m"
                content_line "\033[31m$SET_NO_MOD2\033[0m"
                separator_line "="
                sleep 1
            fi
            ;;
        3)
            if [ "$firewall_mod" = "iptables" ]; then
                if [ -f /etc/init.d/qca-nss-ecm ] && [ "$systype" = "mi_snapshot" ]; then
                    read -r -p "$XIAOMI_QOS(1/0)> " res
                    [ "$res" = '1' ] && {
                        /data/shellcrash_init.sh tproxyfix
                        redir_mod=Tproxy
                        set_redir_config
                    }
                elif grep -qE '^TPROXY$' /proc/net/ip_tables_targets || modprobe xt_TPROXY >/dev/null 2>&1; then
                    redir_mod=Tproxy
                    set_redir_config
                else
                    line_break
                    separator_line "="
                    content_line "\033[31m${SET_NO_MOD}iptables-mod-tproxy\033[0m"
                    content_line "\033[31m$SET_NO_MOD2\033[0m"
                    separator_line "="
                    sleep 1
                fi
            elif [ "$firewall_mod" = "nftables" ]; then
                if modprobe nft_tproxy >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q nft_tproxy; then
                    redir_mod=Tproxy
                    set_redir_config
                else
                    line_break
                    separator_line "="
                    content_line "\033[31m${SET_NO_MOD}nft_tproxy\033[0m"
                    content_line "\033[31m$SET_NO_MOD2\033[0m"
                    separator_line "="
                    sleep 1
                fi
            fi
            ;;
        4)
            if [ -n "$sup_tun" ]; then
                redir_mod=Tun
                set_redir_config
            else
                line_break
                separator_line "="
                content_line "\033[31m$SET_NO_TUN\033[0m"
                separator_line "="
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
                    line_break
                    separator_line "="
                    content_line "\033[31m$FW_NO_NFTABLES\033[0m"
                    separator_line "="
                fi
            elif [ "$firewall_mod" = 'nftables' ]; then
                if ckcmd iptables; then
                    firewall_mod=iptables
                    redir_mod=Redir
                    setconfig redir_mod $redir_mod
                else
                    line_break
                    separator_line "="
                    content_line "\033[31m$FW_NO_IPTABLES\033[0m"
                    separator_line "="
                fi
            else
                iptables -j REDIRECT -h >/dev/null 2>&1 && firewall_mod=iptables
                nft add table inet shellcrash 2>/dev/null && firewall_mod=nftables
                if [ -n "$firewall_mod" ]; then
                    redir_mod=Redir
                    setconfig redir_mod $redir_mod
                    setconfig firewall_mod "$firewall_mod"
                else
                    line_break
                    separator_line "="
                    content_line "\033[31m$FW_NO_FIREWALL_BACKEND\033[0m"
                    separator_line "="
                fi
            fi
            sleep 1
            setconfig firewall_mod "$firewall_mod"
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}

inputport() {
    line_break
    read -r -p "$INPUT_PORT（1～65535）> " portx
    . "$CRASHDIR"/menus/check_port.sh # 加载测试函数
    line_break
    separator_line "="
    if check_port "$portx"; then
        setconfig "$xport" "$portx"
        content_line "\033[32m$COMMON_SUCCESS\033[0m"
        separator_line "="
        sleep 1
        return 0
    else
        content_line "\033[31m$COMMON_FAILED\033[0m"
        separator_line "="
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

        line_break
        separator_line "="
        content_line "1) $ADV_HTTP_PORT：\t\033[36m$mix_port\033[0m"
        content_line "2) $ADV_HTTP_AUTH：\t\033[36m$auth\033[0m"
        content_line "3) $ADV_REDIR_PORT：\t\033[36m$redir_port,$((redir_port + 1))\033[0m"
        content_line "4) $ADV_DNS_PORT：\t\t\033[36m$dns_port\033[0m"
        content_line "5) $ADV_PANEL_PORT：\t\t\033[36m$db_port\033[0m"
        content_line "6) $ADV_PANEL_PASS：\t\t\033[36m$secret\033[0m"
        content_line "8) $ADV_HOST：\t\033[36m$host\033[0m"
        content_line "9) $ADV_TABLE：\t\t\033[36m$table,$((table + 1))\033[0m"
        content_line "0) $COMMON_BACK"
        separator_line "="
        read -r -p "$COMMON_INPUT> " num

        case "$num" in
        "" | 0)
            break
            ;;
        1)
            xport=mix_port
            inputport
            if [ $? -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        2)
            line_break
            separator_line "="
            content_line "$ADV_AUTH_FORMAT_DESC"
            content_line "$ADV_AUTH_WARN"
            content_line "$ADV_AUTH_REMOVE_HINT"
            separator_line "="
            read -r -p "$ADV_AUTH_INPUT> " input

            line_break
            separator_line "="
            if [ "$input" = "0" ]; then
                authentication=""
                setconfig authentication
                content_line "\033[32m$ADV_AUTH_REMOVED\033[0m"
            else
                if [ "$local_proxy" = "ON" ] && [ "$local_type" = "$LOCAL_TYPE_ENV" ]; then
                    content_line "\033[33m$ADV_AUTH_ENV_CONFLICT\033[0m"
                else
                    authentication=$(echo "$input" | grep :)
                    if [ -n "$authentication" ]; then
                        setconfig authentication "'$authentication'"
                        content_line "\033[32m$COMMON_SUCCESS\033[0m"
                    else
                        content_line "\033[31m$ADV_AUTH_INVALID\033[0m"
                    fi
                fi
            fi
            separator_line "="
            sleep 1
            ;;
        3)
            xport=redir_port
            inputport
            if [ $? -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        4)
            xport=dns_port
            inputport
            if [ $? -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        5)
            xport=db_port
            inputport
            if [ $? -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        6)
            line_break
            read -r -p "$ADV_PANEL_PASS_INPUT> " secret
            if [ -n "$secret" ]; then
                [ "$secret" = "0" ] && secret=""
                setconfig secret "$secret"
                line_break
                separator_line "="
                content_line "\033[32m$COMMON_SUCCESS\033[0m"
                separator_line "="
            fi
            ;;
        8)
            line_break
            separator_line "="
            content_line "\033[33m$ADV_HOST_WARN_LAN\033[0m"
            content_line "\033[31m$ADV_HOST_WARN_CHANGE\033[0m"
            separator_line "="
            read -r -p "$ADV_HOST_INPUT> " host

            line_break
            separator_line "="
            if [ "$host" = "0" ]; then
                host=""
                setconfig host "$host"
                content_line "\033[32m$ADV_HOST_REMOVED\033[0m"
                separator_line "="
                sleep 1
                exit 0
            elif echo "$host" | grep -Eq '\<([1-9]|[1-9][0-9]|1[0-9]{2}|2[01][0-9]|22[0-3])\>(\.\<([0-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\>){2}\.\<([1-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])\>'; then
                setconfig host "$host"
                content_line "\033[32m$COMMON_SUCCESS\033[0m"
            else
                host=""
                content_line "\033[31m$ADV_HOST_INVALID\033[0m"
            fi
            separator_line "="
            sleep 1
            ;;
        9)
            line_break
            separator_line "="
            content_line "\033[33m$ADV_TABLE_WARN\033[0m"
            separator_line "="
            read -r -p "$ADV_TABLE_INPUT> " table
            if [ -n "$table" ]; then
                [ "$table" = "0" ] && table="100"
                setconfig table "$table"

                line_break
                separator_line "="
                content_line "\033[32m$COMMON_SUCCESS\033[0m"
                separator_line "="
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
    while true; do
        [ -z "$vm_redir" ] && vm_redir='OFF'
        line_break
        separator_line "="
        content_line "\033[33m$FW_AREA_NOTE_1\033[0m"
        content_line "\033[33m$FW_AREA_NOTE_2\033[0m"
        content_line ""
        content_line "当前路由劫持范围：$firewall_area_dsc"
        separator_line "="
        content_line "1) \033[32m$FW_AREA_LAN\033[0m"
        content_line "2) \033[36m$FW_AREA_LOCAL\033[0m"
        content_line "3) \033[32m$FW_AREA_BOTH\033[0m"
        content_line "4) $FW_AREA_NONE"
        content_line "0) $COMMON_BACK"
        separator_line "="
        read -r -p "$COMMON_INPUT> " num

        case "$num" in
        "" | 0)
            break
            ;;
        [1-4])
            if [ "$firewall_area" -ge 4 ]; then
                redir_mod=''
            else
                redir_mod=Redir
            fi
            firewall_area="$num"
            setconfig firewall_area "$firewall_area"
            setconfig redir_mod "$redir_mod"

            case "$firewall_area" in
            1) firewall_area_dsc="$FW_AREA_LAN" ;;
            2) firewall_area_dsc="$FW_AREA_LOCAL" ;;
            3) firewall_area_dsc="$FW_AREA_BOTH" ;;
            4) firewall_area_dsc="$FW_AREA_NONE" ;;
            esac

            line_break
            separator_line "="
            content_line "\033[32m操作成功\033[0m"
            separator_line "="
            sleep 1
            ;;
        5)
            line_break
            separator_line "="
            content_line "\033[31m注意：\033[0m"
            content_line "此功能存在多种风险如无网络基础请勿尝试！"
            content_line "如需代理UDP，请确保旁路由运行了支持UDP代理的模式！"
            content_line "如使用systemd方式启动，内核依然会空载运行，建议使用保守模式！"
            content_line "\033[33m说明：\033[0m"
            content_line "此功能不启动内核仅配置防火墙转发，且子设备无需额外设置网关DNS"
            content_line "支持防火墙分流及设备过滤，支持部分定时任务，但不支持ipv6"
            separator_line "="
            read -r -p "请直接输入旁路由IPV4地址> " bypass_host
            [ -n "$bypass_host" ] && {
                firewall_area=$num
                setconfig firewall_area "$firewall_area"
                setconfig bypass_host "$bypass_host"
                redir_mod=TCP旁路转发
                setconfig redir_mod $redir_mod
            }
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}

set_firewall_vm() {
    [ -z "$vm_ipv4" ] && vm_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'brd' | grep -E 'docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | sed 's/.*inet.//g' | sed 's/ br.*$//g' | sed 's/metric.*$//g' | tr '\n' ' ')
    line_break
    separator_line "="
    content_line "$VM_DETECT_DESC\033[32m$vm_ipv4\033[0m"
    separator_line "="
    content_line "1) \033[32m$VM_ENABLE_AUTO\033[0m"
    content_line "2) \033[36m$VM_ENABLE_MANUAL\033[0m"
    content_line "3) \033[31m$VM_DISABLE\033[0m"
    content_line "0) $COMMON_BACK"
    separator_line "="
    read -r -p "$COMMON_INPUT> " num

    case "$num" in
    1)
        line_break
        separator_line "="
        if [ -n "$vm_ipv4" ]; then
            vm_redir=ON
            content_line "\033[32m操作成功\033[0m"
        else
            content_line "\033[33m$VM_NO_NET_DETECTED\033[0m"
        fi
        separator_line "="
        sleep 1
        ;;
    2)
        line_break
        separator_line "="
        content_line "$VM_INPUT_DESC_1"
        content_line "$VM_INPUT_DESC_2 \033[32m10.88.0.0/16 172.17.0.0/16\033[0m"
        content_line ""
        content_line "Tips：直接回车确认可返回上级菜单"
        separator_line "="
        read -r -p "$VM_INPUT_NET> " text
        [ -n "$text" ] && vm_ipv4="$text" && vm_redir=ON
        ;;
    3)
        vm_redir=OFF
        vm_ipv4=''

        line_break
        separator_line "="
        content_line "\033[32m操作成功\033[0m"
        separator_line "="
        sleep 1
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

        line_break
        separator_line "="
        content_line "1) $IPV6_REDIR：\t\033[36m$ipv6_redir\033[0m"
        [ "$disoverride" != "1" ] && content_line "2) $IPV6_DNS：\t\033[36m$ipv6_dns\033[0m"
        content_line "0) $COMMON_BACK"
        separator_line "="
        read -r -p "$COMMON_INPUT> " num

        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$ipv6_redir" = "OFF" ]; then
                ipv6_support=ON
                ipv6_redir=ON
            else
                ipv6_redir=OFF
            fi
            setconfig ipv6_redir $ipv6_redir
            setconfig ipv6_support "$ipv6_support"

            line_break
            separator_line "="
            content_line "\033[32m操作成功\033[0m"
            separator_line "="
            sleep 1
            ;;
        2)
            [ "$ipv6_dns" = OFF ] && ipv6_dns=ON || ipv6_dns=OFF
            setconfig ipv6_dns "$ipv6_dns"

            line_break
            separator_line "="
            content_line "\033[32m操作成功\033[0m"
            separator_line "="
            sleep 1
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}
