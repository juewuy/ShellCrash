#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_DNS_LOADED" ] && return
__IS_MODULE_DNS_LOADED=1

load_lang dns

# DNS 模式设置
set_dns_mod() {
    while true; do
        [ -z "$hosts_opt" ] && hosts_opt=ON
        [ -z "$dns_protect" ] && dns_protect=ON
        [ -z "$ecs_subnet" ] && ecs_subnet=OFF
        comp_box "$DNS_CURRENT_MODE\033[47;30m $dns_mod \033[0m" \
            "\033[33m$DNS_RESTART_NOTICE\033[0m"
        content_line "1) 设为MIX$COMMON_MOD：\t\033[32m$DNS_MODE_MIX_DESC\033[0m"
        content_line "2) 设为Route$COMMON_MOD：\t\033[32m$DNS_MODE_ROUTE_DESC\033[0m"
        content_line "3) 设为Redir$COMMON_MOD：\t\033[33m$DNS_MODE_REDIR_DESC\033[0m"
        content_line ""
        content_line "4) $DNS_MENU_PROTECT：\t \033[36m$dns_protect\033[0m\t$DNS_PROTECT_DESC"
        content_line "5) $DNS_MENU_HOSTS：\t \033[36m$hosts_opt\033[0m\t$DNS_HOSTS_DESC"
        content_line "6) $DNS_MENU_ECS：\t \033[36m$ecs_subnet\033[0m\t$DNS_ECS_DESC"
        content_line "7) $DNS_MENU_REDIR：\033[36m$dns_redir_port\033[0m\t$DNS_REDIR_PORT_DESC"
        [ "$dns_mod" = "mix" ] &&
            content_line "8) \033[33m$DNS_FAKEIP_MENU\033[0m"
        content_line "9) \033[36m$DNS_ADV_MENU\033[0m"
        content_line ""
        content_line "0) $COMMON_BACK"
        separator_line "="
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1 | 2)
            if echo "$crashcore" | grep -q 'singbox' || [ "$crashcore" = meta ]; then
                [ "$num" = 1 ] && dns_mod=mix || dns_mod=route
                setconfig dns_mod "$dns_mod"
                msg_alert "\033[36m$DNS_SET_OK：$dns_mod\033[0m"
            else
                msg_alert "\033[31m$DNS_CORE_UNSUPPORTED\033[0m"
            fi
            ;;
        3)
            dns_mod=redir_host
            setconfig dns_mod "$dns_mod"
            msg_alert "\033[36m$DNS_SET_OK：$dns_mod\033[0m"
            ;;
        4)
            while true; do
                line_break
                separator_line "="
                if [ "$dns_protect" = ON ]; then
                    content_line "当前\033[33m已启用\033[0mDNS防泄漏，是否确认禁用？"
                else
                    content_line "当前\033[33m已禁用\033[0mDNS防泄漏，是否确认启用？"
                fi
                separator_line "="
                btm_box "1) 是" \
                    "2) 重置为默认值" \
                    "0) 否，返回上级菜单"
                read -r -p "$COMMON_INPUT> " num
                case "$num" in
                0)
                    break
                    ;;
                1)
                    if [ "$dns_protect" = ON ]; then
                        dns_protect=OFF
                    else
                        dns_protect=ON
                    fi
                    ;;
                2)
                    dns_protect=ON
                    ;;
                *)
                    errornum
                    continue
                    ;;
                esac
                setconfig dns_protect "$dns_protect"
                common_success
            done
            ;;
        5)
            while true; do
                line_break
                separator_line "="
                if [ "$hosts_opt" = ON ]; then
                    content_line "当前\033[33m已启用\033[0mHosts优化，是否确认禁用："
                else
                    content_line "当前\033[33m已禁用\033[0mHosts优化，是否确认启用："
                fi
                separator_line "="
                btm_box "1) 是" \
                    "2) 重置为默认值" \
                    "0) 否，返回上级菜单"
                read -r -p "$COMMON_INPUT> " num
                case "$num" in
                0)
                    break
                    ;;
                1)
                    if [ "$hosts_opt" = ON ]; then
                        hosts_opt=OFF
                    else
                        hosts_opt=ON
                    fi
                    ;;
                2)
                    hosts_opt=ON
                    ;;
                *)
                    errornum
                    continue
                    ;;
                esac
                setconfig dns_protect "$hosts_opt"
                common_success
            done
            ;;
        6)

            while true; do
                line_break
                separator_line "="
                if [ "$ecs_subnet" = ON ]; then
                    content_line "当前\033[33m已启用\033[0mHosts优化，是否确认禁用："
                else
                    content_line "当前\033[33m已禁用\033[0mHosts优化，是否确认启用："
                fi
                separator_line "="
                btm_box "1) 是" \
                    "2) 重置为默认值" \
                    "0) 否，返回上级菜单"
                read -r -p "$COMMON_INPUT> " num
                case "$num" in
                0)
                    break
                    ;;
                1)
                    if [ "$ecs_subnet" = ON ]; then
                        ecs_subnet=OFF
                    else
                        ecs_subnet=ON
                    fi
                    ;;
                2)
                    ecs_subnet=OFF
                    ;;
                *)
                    errornum
                    continue
                    ;;
                esac
                setconfig dns_protect "$ecs_subnet"
                common_success
            done
            ;;
        7)
            while true; do
                comp_box "\033[31m$DNS_REDIR_WARN\033[0m" \
                    "\033[33m$DNS_REDIR_HINT 127.0.0.1:$dns_port\033[0m" \
                    "" \
                    "请直接输入旁路由IPV4地址" \
                    "或输入 r 重置DNS劫持端口" \
                    "或输入 0 返回上级菜单"
                read -r -p "请输入> " num
                case "$num" in
                0)
                    break
                    ;;
                r)
                    dns_redir_port="$dns_port"
                    setconfig dns_redir_port
                    common_success
                    break
                    ;;
                *)
                    if [ "$num" -ge 1 ] && [ "$num" -lt 65535 ]; then
                        if ckcmd netstat && netstat -ntul | grep -q ":$num "; then
                            dns_redir_port="$num"
                            setconfig dns_redir_port "$dns_redir_port"
                            common_success
                            break
                        else
                            msg_alert
                        fi
                    else
                        errornum
                    fi
                    ;;
                esac
            done
            ;;
        8)
            fake_ip_filter
            ;;
        9)
            set_dns_adv
            ;;
        *)
            errornum
            ;;
        esac
    done
}

fake_ip_filter() {
    while true; do
        comp_box "\033[32m$DNS_FAKEIP_DESC\033[0m" \
            "\033[31m$DNS_FAKEIP_TIP\033[0m" \
            "\033[36m$DNS_FAKEIP_EXAMPLE\033[0m"
        if [ -s "$CRASHDIR/configs/fake_ip_filter" ]; then
            content_line "\033[33m$DNS_FAKEIP_EXIST\033[0m"
            content_line ""
            awk '{print NR") "$1}' "$CRASHDIR/configs/fake_ip_filter" |
                while IFS= read -r line; do
                    content_line "$line"
                done
        else
            content_line "\033[33m$DNS_FAKEIP_EMPTY\033[0m"
        fi
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "$DNS_FAKEIP_EDIT> " input
        case "$input" in
        "" | 0)
            break
            ;;
        *)
            if [ "$input" -ge 1 ] 2>/dev/null; then
                if sed -i "${input}d" "$CRASHDIR/configs/fake_ip_filter"; then
                    msg_alert "\033[32m移除成功\033[0m"
                else
                    msg_alert "\033[31m移除失败\033[0m"
                fi
            else
                comp_box "请确认需要添加的地址：\033[32m$input\033[0m"
                btm_box "1) 确认无误" \
                    "0) 返回上级菜单"
                read -r -p "$COMMON_INPUT>" res
                if [ "$res" = 1 ]; then
                    if echo "$input" >>"$CRASHDIR/configs/fake_ip_filter"; then
                        msg_alert "\033[32m添加成功\033[0m"
                    else
                        msg_alert "\033[31m添加失败\033[0m"
                    fi
                else
                    break
                fi
            fi
            ;;
        esac
    done
}

# DNS详细设置
set_dns_adv() {
    while true; do
        comp_box "\033[31m$DNS_ADV_SINGBOX_LIMIT\033[0m" \
            "$DNS_ADV_SPLIT" \
            "\033[33m$DNS_ADV_CERT\033[0m" \
            "" \
            "DIRECT-DNS：" \
            "\033[32m$dns_nameserver\033[0m" \
            "" \
            "PROXY-DNS：" \
            "\033[36m$dns_fallback\033[0m" \
            "" \
            "DEFAULT-DNS：" \
            "\033[33m$dns_resolver\033[0m" \
            ""
        btm_box "1) $DNS_ADV_EDIT_DIRECT" \
            "2) $DNS_ADV_EDIT_PROXY" \
            "3) $DNS_ADV_EDIT_DEFAULT" \
            "4) \033[32m$DNS_ADV_AUTO_ENCRYPT\033[0m" \
            "9) \033[33m$DNS_ADV_RESET\033[0m" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            comp_box "当前DIRECT-DNS：\033[32m$dns_nameserver\033[0m"
            btm_box "\033[36m请直接输入新的DIRECT-DNS地址\033[0m" \
                "或输入 r 重置DIRECT-DNS地址" \
                "或输入 0 返回上级菜单"
            read -r -p "请输入> " res
            case "$res" in
            0)
                continue
                ;;
            r)
                dns_nameserver="127.0.0.1"
                setconfig dns_nameserver "'$dns_nameserver'"
                common_success
                ;;
            *)
                dns_nameserver=$(echo "$res" | sed 's#|#,\ #g')
                if [ -n "$dns_nameserver" ]; then
                    setconfig dns_nameserver "'$dns_nameserver'"
                    common_success
                else
                    common_failed
                fi
                ;;
            esac
            ;;
        2)
            comp_box "当前PROXY-DNS：\033[32m$dns_fallback\033[0m"
            btm_box "\033[36m请直接输入新的PROXY-DNS地址\033[0m" \
                "或输入 r 重置PROXY-DNS地址" \
                "或输入 0 返回上级菜单"
            read -r -p "请输入> " res
            case "$res" in
            0)
                continue
                ;;
            r)
                dns_fallback="1.1.1.1, 8.8.8.8"
                setconfig dns_fallback "'$dns_fallback'"
                common_success
                ;;
            *)
                dns_fallback=$(echo "$res" | sed 's#|#,\ #g')
                if [ -n "$dns_fallback" ]; then
                    setconfig dns_fallback "'$dns_fallback'"
                    common_success
                else
                    common_failed
                fi
                ;;
            esac
            ;;
        3)
            comp_box "当前DEFAULT-DNS：\033[32m$dns_resolver\033[0m"
            btm_box "\033[36m请直接输入新的DEFAULT-DNS地址\033[0m" \
                "或输入 r 重置DEFAULT-DNS地址" \
                "或输入 0 返回上级菜单"
            separator_line "="
            read -r -p "请输入> " res
            case "$res" in
            0)
                continue
                ;;
            "r")
                dns_resolver="223.5.5.5, 2400:3200::1"
                setconfig dns_resolver "'$dns_resolver'"
                common_failed
                ;;
            *)
                if echo "$res" | grep -qE '://.*::'; then
                    msg_alert "\033[31m$DNS_IPV6_NOT_SUPPORT\033[0m"
                else
                    dns_resolver=$(echo "$res" | sed 's#|#,\ #g')
                    setconfig dns_resolver "'$dns_resolver'"
                    msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
                fi
                ;;
            esac
            ;;
        4)
            line_break
            separator_line "="
            if echo "$crashcore" | grep -qE 'meta|singbox'; then
                dns_nameserver='https://dns.alidns.com/dns-query, https://doh.pub/dns-query'
                dns_fallback='https://cloudflare-dns.com/dns-query, https://dns.google/dns-query, https://doh.opendns.com/dns-query'
                dns_resolver='https://223.5.5.5/dns-query, 2400:3200::1'
                setconfig dns_nameserver "'$dns_nameserver'"
                setconfig dns_fallback "'$dns_fallback'"
                setconfig dns_resolver "'$dns_resolver'"
                content_line "\033[32m$DNS_ENCRYPT_OK\033[0m"
            else
                content_line "\033[31m$DNS_CORE_REQUIRE\033[0m"
            fi
            separator_line "="
            ;;
        9)
            setconfig dns_nameserver
            setconfig dns_fallback
            setconfig dns_resolver
            . "$CRASHDIR/libs/get_config.sh"
            common_success
            ;;
        *)
            errornum
            ;;
        esac
    done
}
