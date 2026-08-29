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
        [ -z "$udp_buffer" ] && udp_buffer=OFF

        comp_box "\033[30;47m$SET_MENU_TITLE\033[0m"
        content_line "1) $SET_MENU_REDIR\t\033[36m$redir_mod$MENU_MOD\033[0m"
        content_line "2) $SET_MENU_DNS\t\033[36m$dns_mod\033[0m"
        content_line "3) $SET_MENU_FW_FILTER\t$SET_MENU_FW_FILTER_DESC"
        [ "$disoverride" != "1" ] && {
            content_line "4) $SET_MENU_SKIP_CERT\t\033[36m$skip_cert\033[0m"
            content_line "5) $SET_MENU_SNIFFER\t\033[36m$sniffer\033[0m"
            content_line "6) $SET_MENU_ADV_PORT"
        }
        content_line "7) $SET_MENU_IPV6\t\033[36m$ipv6_redir\033[0m"
        content_line "8) $SET_MENU_UDP_BUFFER\t\033[36m$udp_buffer\033[0m"
        btm_box "" \
            "a) \033[31m$SET_MENU_RESET\033[0m" \
            "b) \033[36m$SET_MENU_LANG\033[0m" \
            "c) \033[33m$SET_MENU_UI\033[0m" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$USER" != root ] && [ "$USER" != admin ]; then
                comp_box "$SET_WARN_NONROOT"
                btm_box "1) $SET_YES" \
                    "0) $SET_NO_BACK"
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
                content_line "$SET_SKIP_CERT_NOW\033[33m$SET_DISABLED\033[0m$SET_SKIP_CERT_ENABLE_Q"
            else
                content_line "$SET_SKIP_CERT_NOW\033[33m$SET_ENABLED\033[0m$SET_SKIP_CERT_DISABLE_Q"
            fi
            separator_line "="
            btm_box "1) $SET_YES" \
                "0) $SET_NO_BACK"
            read -r -p "$COMMON_INPUT> " num
            if [ "$num" = 1 ]; then
                if [ "$skip_cert" = OFF ]; then
                    skip_cert=ON
                    msg_alert "\033[33m$SET_SKIP_CERT_ON\033[0m"
                else
                    skip_cert=OFF
                    msg_alert "\033[33m$SET_SKIP_CERT_OFF\033[0m"
                fi
                setconfig skip_cert $skip_cert
            else
                continue
            fi
            ;;
        5)
            if [ "$sniffer" = "OFF" ]; then
                comp_box "$SET_SNIFFER_NOW\033[33m$SET_DISABLED\033[0m$SET_SNIFFER_ENABLE_Q"
                btm_box "1) $SET_YES" \
                    "0) $SET_NO_BACK"
                read -r -p "$COMMON_INPUT> " num
                if [ "$num" = 1 ]; then
                    line_break
                    separator_line "="
                    if [ "$crashcore" = "clash" ]; then
                        rm -rf "$TMPDIR/CrashCore" "$CRASHDIR/CrashCore" "$CRASHDIR/CrashCore.tar.gz"
                        crashcore=meta
                        setconfig crashcore $crashcore
                        top_box "$SET_SNIFFER_CORE_SWITCH" \
                            ""
                    fi
                    sniffer=ON
                else
                    continue
                fi
            elif [ "$crashcore" = clashpre ] && [ "$dns_mod" = redir_host ]; then
                msg_alert "\033[31m$SET_SNIFFER_LOCKED\033[0m"
                continue
            else
                comp_box "$SET_SNIFFER_NOW\033[33m$SET_ENABLED\033[0m$SET_SNIFFER_DISABLE_Q"
                btm_box "1) $SET_YES" \
                    "0) $SET_NO_BACK"
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
            btm_box "\033[32m$COMMON_SUCCESS\033[0m"
            sleep 1
            ;;
        6)
            if pidof CrashCore >/dev/null; then
                comp_box "\033[33m$SET_CORE_RUNNING\033[0m" \
                    "$SET_CORE_STOP_CONFIRM"
                btm_box "1) $SET_YES" \
                    "0) $SET_NO_BACK"
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
        7)
            set_ipv6
            ;;
        8)
            if [ "$udp_buffer" = "ON" ]; then
                udp_buffer=OFF
                msg_alert "\033[33m$SET_UDP_BUFFER_OFF\033[0m" \
                    "$SET_UDP_BUFFER_RESTART"
            else
                udp_buffer=ON
                msg_alert "\033[32m$SET_UDP_BUFFER_ON\033[0m" \
                    "$SET_UDP_BUFFER_RESTART"
            fi
            setconfig udp_buffer "$udp_buffer"
            ;;
        a)
            BACK_TAR="$CRASHDIR/configs.tar.gz"
            comp_box "1) $SET_BACKUP" \
                "2) $SET_RESTORE" \
                "3) $SET_RESET" \
                "" \
                "0) $COMMON_BACK"
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
                separator_line "="
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
                errornum
                continue
                ;;
            esac
            content_line "\033[33m$SET_NEED_RESTART\033[0m"
            separator_line "="
            line_break
            sleep 1
            exit 0
            ;;
        b)
            comp_box "1) 简体中文" \
                "2) English" \
                "" \
                "0) $COMMON_BACK"
            read -r -p "$COMMON_INPUT> " num
            case "$num" in
            "" | 0)
                continue
                ;;
            1)
                echo chs >"$CRASHDIR"/configs/i18n.cfg
                msg_alert "\033[32m切换成功，请重新执行脚本！\033[0m"
                ;;
            2)
                echo en >"$CRASHDIR"/configs/i18n.cfg
                msg_alert "\033[32mLanguage switched successfully! Please re-run the script!\033[0m"
                ;;
            esac
            line_break
            exit 0
            ;;
        c)
            comp_box "1) $SET_TUI_1" \
                "2) $SET_TUI_2" \
                "" \
                "0) $COMMON_BACK"
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
            msg_alert "\033[32m$SET_SWITCH_OK\033[0m"
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_redir_config() {
    setconfig redir_mod "$redir_mod"
    setconfig dns_mod "$dns_mod"
    msg_alert "\033[36m$SET_REDIR_APPLIED $redir_mod $SET_MODE_SUFFIX\033[0m"
}

# 路由模式设置
set_redir_mod() {
    while true; do
        [ -n "$(ls /dev/net/tun 2>/dev/null)" ] || ip tuntap >/dev/null 2>&1 || modprobe tun 2>/dev/null && sup_tun=1
        [ -z "$firewall_area" ] && firewall_area=1
        [ "$firewall_area" = 4 ] && redir_mod="$MENU_PURE_MOD"
        [ -z "$redir_mod" ] && redir_mod='Redir'
        [ -z "$vm_redir" ] && vm_redir='OFF'
        firewall_area_dsc=$(echo "$SET_FW_AREA_DESC($bypass_host)" | cut -d'|' -f$firewall_area)
        comp_box "\033[33m$SET_REDIR_RESTART_HINT\033[0m" \
            "$SET_REDIR_CURRENT\033[47;30m$redir_mod$MENU_MOD\033[0m；  $SET_CORE_CURRENT\033[47;30m$crashcore\033[0m"
        [ "$firewall_area" -le 3 ] && {
            content_line "1) $SET_SET_TO\033[32m$SET_REDIR_REDIR\033[0m：\t$SET_REDIR_REDIRDES"
            content_line "2) $SET_SET_TO\033[36m$SET_REDIR_MIX\033[0m：\t$SET_REDIR_MIXDES"
            content_line "3) $SET_SET_TO\033[32m$SET_REDIR_TPROXY\033[0m：\t$SET_REDIR_TPROXYDES"
            content_line "4) $SET_SET_TO\033[33m$SET_REDIR_TUN\033[0m：\t$SET_REDIR_TUNDES"
            content_line ""
        }
        [ "$firewall_area" = 5 ] && {
            content_line "5) \033[32m$SET_BYPASS_TCP\033[0m：    $SET_BYPASS_TCP_DESC"
            content_line "6) \033[36m$SET_BYPASS_TU\033[0m：    $SET_BYPASS_TU_DESC"
            content_line ""
        }
        btm_box "7) $SET_FW_AREA：\t\033[47;30m$firewall_area_dsc\033[0m" \
            "8) $SET_VM_REDIR：\t\033[47;30m$vm_redir\033[0m" \
            "9) $SET_FW_SWITCH：\t\033[47;30m$firewall_mod\033[0m" \
            "" \
            "0) $COMMON_BACK"
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
                msg_alert "\033[31m${SET_NO_MOD}TUN\033[0m" \
                    "\033[31m$SET_NO_MOD2\033[0m"
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
                    msg_alert "\033[31m${SET_NO_MOD}iptables-mod-tproxy\033[0m" \
                        "\033[31m$SET_NO_MOD2\033[0m"
                fi
            elif [ "$firewall_mod" = "nftables" ]; then
                if modprobe nft_tproxy >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q nft_tproxy; then
                    redir_mod=Tproxy
                    set_redir_config
                else
                    msg_alert "\033[31m${SET_NO_MOD}nft_tproxy\033[0m" \
                        "\033[31m$SET_NO_MOD2\033[0m"
                fi
            fi
            ;;
        4)
            if [ -n "$sup_tun" ]; then
                redir_mod=Tun
                set_redir_config
            else
                msg_alert "\033[31m$SET_NO_TUN\033[0m"
            fi
            ;;
        5)
            redir_mod='$SET_BYPASS_TCP'
            set_redir_config
            ;;
        6)
            redir_mod='$SET_BYPASS_TU'
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
                    msg_alert "\033[31m$FW_NO_NFTABLES\033[0m"
                fi
            elif [ "$firewall_mod" = 'nftables' ]; then
                if ckcmd iptables; then
                    firewall_mod=iptables
                    redir_mod=Redir
                    setconfig redir_mod $redir_mod
                else
                    msg_alert "\033[31m$FW_NO_IPTABLES\033[0m"
                fi
            else
                iptables -j REDIRECT -h >/dev/null 2>&1 && firewall_mod=iptables
                nft add table inet shellcrash 2>/dev/null && firewall_mod=nftables
                if [ -n "$firewall_mod" ]; then
                    redir_mod=Redir
                    setconfig redir_mod $redir_mod
                    setconfig firewall_mod "$firewall_mod"
                else
                    msg_alert "\033[31m$FW_NO_FIREWALL_BACKEND\033[0m"
                fi
            fi
            setconfig firewall_mod "$firewall_mod"
            ;;
        *)
            errornum
            ;;
        esac
    done
}

inputport() {
    local protocol="${1:-all}"
    line_break
    read -r -p "$INPUT_PORT（1～65535）> " portx
    . "$CRASHDIR"/menus/check_port.sh

    if ! check_port "$portx" "$protocol"; then
        msg_alert "\033[31m$COMMON_FAILED\033[0m"
        return 1
    fi

    local ports_to_check=""
    [ "$xport" != "mix_port" ] && ports_to_check="$ports_to_check|$mix_port"
    [ "$xport" != "redir_port" ] && ports_to_check="$ports_to_check|$redir_port"
    [ "$xport" != "dns_port" ] && ports_to_check="$ports_to_check|$dns_port"
    [ "$xport" != "db_port" ] && ports_to_check="$ports_to_check|$db_port"

    if echo "$ports_to_check|" | grep -q "|$portx|"; then
        msg_alert "\033[31m$CHECK_PORT_DUP_ERR\033[0m"
        return 1
    fi

    setconfig "$xport" "$portx"
    msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
    return 0
}

# 端口设置
set_adv_config() {
    while true; do
        . "$CFG_PATH" >/dev/null
        [ -z "$secret" ] && secret="$COMMON_UNSET"
        [ -z "$table" ] && table=100
        [ -z "$authentication" ] && auth="$COMMON_UNSET" || auth="******"
        comp_box "1) $ADV_HTTP_PORT：\t\033[36m$mix_port\033[0m" \
            "2) $ADV_HTTP_AUTH：\t\033[36m$auth\033[0m" \
            "3) $ADV_REDIR_PORT：\t\033[36m$redir_port,$((redir_port + 1))\033[0m" \
            "4) $ADV_DNS_PORT：\t\t\033[36m$dns_port\033[0m" \
            "5) $ADV_PANEL_PORT：\t\t\033[36m$db_port\033[0m" \
            "6) $ADV_PANEL_PASS：\t\t\033[36m$secret\033[0m" \
            "8) $ADV_HOST：\t\033[36m$host\033[0m" \
            "9) $ADV_TABLE：\t\t\033[36m$table,$((table + 1))\033[0m" \
            "" \
            "0) $COMMON_BACK"
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
            comp_box "$ADV_AUTH_FORMAT_DESC" \
                "$ADV_AUTH_WARN" \
                "$ADV_AUTH_REMOVE_HINT"
            read -r -p "$ADV_AUTH_INPUT> " input
            if [ "$input" = "0" ]; then
                authentication=""
                setconfig authentication
                msg_alert "\033[32m$ADV_AUTH_REMOVED\033[0m"
            else
                if [ "$local_proxy" = "ON" ] && [ "$local_type" = "$LOCAL_TYPE_ENV" ]; then
                    msg_alert "\033[33m$ADV_AUTH_ENV_CONFLICT\033[0m"
                else
                    authentication=$(echo "$input" | grep :)
                    if [ -n "$authentication" ]; then
                        setconfig authentication "'$authentication'"
                        msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                    else
                        msg_alert "\033[31m$ADV_AUTH_INVALID\033[0m"
                    fi
                fi
            fi
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
            inputport tcp
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
                if setconfig secret "$secret"; then
                    common_success
                else
                    common_failed
                fi
            fi
            ;;
        8)
            comp_box "\033[33m$ADV_HOST_WARN_LAN\033[0m" \
                "\033[31m$ADV_HOST_WARN_CHANGE\033[0m"
            read -r -p "$ADV_HOST_INPUT> " host
            if [ "$host" = "0" ]; then
                host=""
                setconfig host "$host"
                msg_alert "\033[32m$ADV_HOST_REMOVED\033[0m"
                line_break
                exit 0
            elif echo "$host" | grep -Eq '\<([1-9]|[1-9][0-9]|1[0-9]{2}|2[01][0-9]|22[0-3])\>(\.\<([0-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\>){2}\.\<([1-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])\>'; then
                if setconfig host "$host"; then
                    common_success
                else
                    common_failed
                fi
            else
                host=""
                msg_alert "\033[31m$ADV_HOST_INVALID\033[0m"
            fi
            ;;
        9)
            comp_box "\033[33m$ADV_TABLE_WARN\033[0m"
            read -r -p "$ADV_TABLE_INPUT> " table
            if [ -n "$table" ]; then
                [ "$table" = "0" ] && table="100"
                if setconfig table "$table"; then
                    common_success
                else
                    common_failed
                fi
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_firewall_area() {
    while true; do
        comp_box "\033[33m$FW_AREA_NOTE_1\033[0m" \
            "\033[33m$FW_AREA_NOTE_2\033[0m" \
            "" \
            "$SET_FW_AREA_CURRENT$firewall_area_dsc"
        btm_box "1) \033[32m$FW_AREA_LAN\033[0m" \
            "2) \033[36m$FW_AREA_LOCAL\033[0m" \
            "3) \033[32m$FW_AREA_BOTH\033[0m" \
            "4) $FW_AREA_NONE" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        [1-4])
            if [ "$firewall_area" -ge 4 ]; then
                redir_mod=''
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

            common_success
            ;;
        5)
            comp_box "\033[31m$SET_WARN\033[0m" \
                "$SET_BYPASS_WARN_1" \
                "$SET_BYPASS_WARN_2" \
                "$SET_BYPASS_WARN_3" \
                "\033[33m$SET_DESC\033[0m" \
                "$SET_BYPASS_DESC_1" \
                "$SET_BYPASS_DESC_2"
            read -r -p "$SET_INPUT_BYPASS_IPV4> " bypass_host
            [ -n "$bypass_host" ] && {
                firewall_area=$num
                setconfig firewall_area "$firewall_area"
                setconfig bypass_host "$bypass_host"
                redir_mod=$SET_BYPASS_TCP
                setconfig redir_mod $redir_mod
            }
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_firewall_vm() {
    [ -z "$vm_ipv4" ] && vm_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'brd' | grep -E 'docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | sed 's/.*inet.//g' | sed 's/ br.*$//g' | sed 's/metric.*$//g' | tr '\n' ' ')
    comp_box "$VM_DETECT_DESC\033[32m$vm_ipv4\033[0m"
    btm_box "1) \033[32m$VM_ENABLE_AUTO\033[0m" \
        "2) \033[36m$VM_ENABLE_MANUAL\033[0m" \
        "3) \033[31m$VM_DISABLE\033[0m" \
        "" \
        "0) $COMMON_BACK"
    read -r -p "$COMMON_INPUT> " num
    case "$num" in
    1)
        if [ -n "$vm_ipv4" ]; then
            vm_redir=ON
            common_success
        else
            msg_alert "\033[33m$VM_NO_NET_DETECTED\033[0m"
			set_firewall_vm
			return
        fi

        ;;
    2)
        comp_box "$VM_INPUT_DESC_1" \
            "$VM_INPUT_DESC_2 \033[32m10.88.0.0/16 172.17.0.0/16\033[0m" \
            "" \
            "$SET_TIPS_ENTER_BACK"
        read -r -p "$VM_INPUT_NET> " text
        [ -n "$text" ] && vm_ipv4="$text" && vm_redir=ON
        ;;
    3)
        vm_redir=OFF
        vm_ipv4=''
        ;;
    *) return ;;
    esac
	common_success
	setconfig vm_redir "$vm_redir"
	setconfig vm_ipv4 "'$vm_ipv4'"
}

# ipv6设置
set_ipv6() {
    while true; do
        [ -z "$ipv6_redir" ] && ipv6_redir=OFF
        [ -z "$ipv6_dns" ] && ipv6_dns=ON

        top_box "1) $IPV6_REDIR：\t\033[36m$ipv6_redir\033[0m"
        [ "$disoverride" != "1" ] && content_line "2) $IPV6_DNS：\t\033[36m$ipv6_dns\033[0m"
        btm_box "" \
            "0) $COMMON_BACK"
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
            common_success
            ;;
        2)
            [ "$ipv6_dns" = OFF ] && ipv6_dns=ON || ipv6_dns=OFF
            if setconfig ipv6_dns "$ipv6_dns"; then
                common_success
            else
                common_failed
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
