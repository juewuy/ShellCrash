#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_DNS_LOADED" ] && return
__IS_MODULE_DNS_LOADED=1

load_lang dns

set_dns_mod() { # DNS 模式设置
    [ -z "$hosts_opt" ] && hosts_opt=ON
    [ -z "$dns_protect" ] && dns_protect=ON
    [ -z "$ecs_subnet" ] && ecs_subnet=OFF

    echo "-----------------------------------------------"
    echo -e "$DNS_CURRENT_MODE \033[47;30m $dns_mod \033[0m"
    echo -e "\033[33m$DNS_RESTART_NOTICE\033[0m"
    echo "-----------------------------------------------"
    echo -e " 1 MIX$COMMON_MOD：\t\033[32m$DNS_MODE_MIX_DESC\033[0m"
    echo -e " 2 Route$COMMON_MOD：\t\033[32m$DNS_MODE_ROUTE_DESC\033[0m"
    echo -e " 3 Redir$COMMON_MOD：\t\033[33m$DNS_MODE_REDIR_DESC\033[0m"
    echo "-----------------------------------------------"
	echo -e " 4 $DNS_MENU_PROTECT：\t\033[36m$dns_protect\033[0m\t$DNS_PROTECT_DESC"
	echo -e " 5 $DNS_MENU_HOSTS：\t\033[36m$hosts_opt\033[0m\t$DNS_HOSTS_DESC"
	echo -e " 6 $DNS_MENU_ECS：\t\033[36m$ecs_subnet\033[0m\t$DNS_ECS_DESC"
	echo -e " 7 $DNS_MENU_REDIR：\033[36m$dns_redir_port\033[0m\t$DNS_REDIR_PORT_DESC"
    [ "$dns_mod" = "mix" ] && 
        echo -e " 8 \033[33m$DNS_FAKEIP_MENU\033[0m"
    echo -e " 9 \033[36m$DNS_ADV_MENU\033[0m"
    echo "-----------------------------------------------"
    echo " 0 $COMMON_BACK"
    read -p "$COMMON_INPUT > " num
    case "$num" in
        0) ;;
        1|2)
            if echo "$crashcore" | grep -q 'singbox' || [ "$crashcore" = meta ]; then
                [ "$num" = 1 ] && dns_mod=mix || dns_mod=route
                setconfig dns_mod "$dns_mod"
                echo "-----------------------------------------------"
                echo -e "\033[36m$DNS_SET_OK: $dns_mod\033[0m"
            else
                echo -e "\033[31m$DNS_CORE_UNSUPPORTED\033[0m"
                sleep 1
            fi
            set_dns_mod
        ;;
        3)
            dns_mod=redir_host
            setconfig dns_mod "$dns_mod"
            echo -e "\033[36m$DNS_SET_OK: $dns_mod\033[0m"
            set_dns_mod
        ;;
        4)
            [ "$dns_protect" = ON ] && dns_protect=OFF || dns_protect=ON
            setconfig dns_protect "$dns_protect"
            set_dns_mod
        ;;
        5)
            [ "$hosts_opt" = ON ] && hosts_opt=OFF || hosts_opt=ON
            setconfig hosts_opt "$hosts_opt"
            set_dns_mod
        ;;
        6)
            [ "$ecs_subnet" = ON ] && ecs_subnet=OFF || ecs_subnet=ON
            setconfig ecs_subnet "$ecs_subnet"
            set_dns_mod
        ;;
        7)
            echo "-----------------------------------------------"
            echo -e "\033[31m$DNS_REDIR_WARN\033[0m"
            echo -e "\033[33m$DNS_REDIR_HINT 127.0.0.1:$dns_port\033[0m"
            echo "-----------------------------------------------"

            read -p "$DNS_REDIR_INPUT" num

            if [ "$num" = 0 ]; then
                dns_redir_port="$dns_port"
                setconfig dns_redir_port
            elif [ "$num" -ge 1 ] && [ "$num" -lt 65535 ]; then
                if ckcmd netstat && netstat -ntul | grep -q ":$num "; then
                    dns_redir_port="$num"
                    setconfig dns_redir_port "$dns_redir_port"
                else
                    echo -e "\033[33m$DNS_REDIR_NO_SERVICE\033[0m"
                fi
            else
                errornum
            fi
            sleep 1
            set_dns_mod
        ;;
        8)
            fake_ip_filter
            set_dns_mod
        ;;
        9)
            set_dns_adv
            set_dns_mod
        ;;
        *)
            errornum
        ;;
    esac
}

fake_ip_filter() {
    echo -e "\033[32m$DNS_FAKEIP_DESC\033[0m"
    echo -e "\033[31m$DNS_FAKEIP_TIP\033[0m"
    echo -e "\033[36m$DNS_FAKEIP_EXAMPLE\033[0m"
    echo "-----------------------------------------------"
    if [ -s "$CRASHDIR/configs/fake_ip_filter" ]; then
        echo -e "\033[33m$DNS_FAKEIP_EXIST\033[0m"
        awk '{print NR" "$1}' "$CRASHDIR/configs/fake_ip_filter"
    else
        echo -e "\033[33m$DNS_FAKEIP_EMPTY\033[0m"
    fi
    echo "-----------------------------------------------"
    read -p "$DNS_FAKEIP_EDIT > " input
    case "$input" in
        0|'') ;;
        *)
            if [ "$input" -ge 1 ] 2>/dev/null; then
                sed -i "${input}d" "$CRASHDIR/configs/fake_ip_filter"
                echo -e "\033[32m$COMMON_REMOVE_OK\033[0m"
            else
                echo -e "$COMMON_YOUR_INPUT \033[32m$input\033[0m"
                read -p "$COMMON_CONFIRM" res
                [ "$res" = 1 ] && echo "$input" >>"$CRASHDIR/configs/fake_ip_filter"
            fi
            sleep 1
            fake_ip_filter
        ;;
    esac
}

set_dns_adv() { # DNS详细设置
    echo "-----------------------------------------------"
    echo -e "DIRECT-DNS ：\033[32m$dns_nameserver\033[0m"
    echo -e "PROXY-DNS  ：\033[36m$dns_fallback\033[0m"
    echo -e "DEFAULT-DNS：\033[33m$dns_resolver\033[0m"

    echo -e "$DNS_ADV_SPLIT"
    echo -e "\033[33m$DNS_ADV_CERT\033[0m"
    echo -e "\033[31m$DNS_ADV_SINGBOX_LIMIT\033[0m"

    echo "-----------------------------------------------"
    echo -e " 1 $DNS_ADV_EDIT_DIRECT"
    echo -e " 2 $DNS_ADV_EDIT_PROXY"
    echo -e " 3 $DNS_ADV_EDIT_DEFAULT"
    echo -e " 4 \033[32m$DNS_ADV_AUTO_ENCRYPT\033[0m"
    echo -e " 9 \033[33m$DNS_ADV_RESET\033[0m"
    echo -e " 0 $COMMON_BACK"
    echo "-----------------------------------------------"

    read -p "$COMMON_INPUT > " num

    case "$num" in
        0) ;;
        1)
            read -p "$DNS_INPUT_NEW" dns_nameserver
            dns_nameserver=$(echo "$dns_nameserver" | sed 's#|#,\ #g')
            [ -n "$dns_nameserver" ] && setconfig dns_nameserver "'$dns_nameserver'"
            echo -e "\033[32m$COMMON_SUCCESS\033[0m"
            sleep 1
            set_dns_adv
        ;;
        2)
            read -p "$DNS_INPUT_NEW" dns_fallback
            dns_fallback=$(echo "$dns_fallback" | sed 's#|#,\ #g')
            [ -n "$dns_fallback" ] && setconfig dns_fallback "'$dns_fallback'"
            echo -e "\033[32m$COMMON_SUCCESS\033[0m"
            sleep 1
            set_dns_adv
        ;;
        3)
            read -p "$DNS_INPUT_NEW" text
            if echo "$text" | grep -qE '://.*::'; then
                echo -e "\033[31m$DNS_IPV6_NOT_SUPPORT\033[0m"
            else
                dns_resolver=$(echo "$text" | sed 's#|#,\ #g')
                setconfig dns_resolver "'$dns_resolver'"
                echo -e "\033[32m$COMMON_SUCCESS\033[0m"
            fi
            sleep 1
            set_dns_adv
        ;;
        4)
            if echo "$crashcore" | grep -qE 'meta|singbox'; then
                dns_nameserver='https://dns.alidns.com/dns-query, https://doh.pub/dns-query'
                dns_fallback='https://cloudflare-dns.com/dns-query, https://dns.google/dns-query, https://doh.opendns.com/dns-query'
                dns_resolver='https://223.5.5.5/dns-query, 2400:3200::1'
                setconfig dns_nameserver "'$dns_nameserver'"
                setconfig dns_fallback "'$dns_fallback'"
                setconfig dns_resolver "'$dns_resolver'"
                echo -e "\033[32m$DNS_ENCRYPT_OK\033[0m"
            else
                echo -e "\033[31m$DNS_CORE_REQUIRE\033[0m"
            fi
            sleep 1
            set_dns_adv
        ;;
        9)
            setconfig dns_nameserver
            setconfig dns_fallback
            setconfig dns_resolver
            . "$CRASHDIR/libs/get_config.sh"
            echo -e "\033[32m$COMMON_SUCCESS\033[0m"
            sleep 1
            set_dns_adv
        ;;
        *)
            errornum
            sleep 1
        ;;
    esac
}
