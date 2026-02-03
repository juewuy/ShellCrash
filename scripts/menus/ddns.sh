#! /bin/bash
# Copyright (C) Juewuy

ddns_menu() {
    top_box "\033[30;46m欢迎使用DDNS！\033[0m"
    load_ddns
}

add_ddns() {
    cat >>"$ddns_dir" <<EOF

config service '$service'
	option enabled '1'
	option force_unit 'hours'
	option lookup_host '$domain'
	option service_name '$service_name'
	option domain '$domain'
	option username '$username'
	option use_https '0'
	option use_ipv6 '$use_ipv6'
	option password '$password'
	option ip_source 'web'
	option check_unit 'minutes'
	option check_interval '$check_interval'
	option force_interval '$force_interval'
	option interface 'wan'
	option bind_network 'wan'
EOF
    /usr/lib/ddns/dynamic_dns_updater.sh -S "$service" start >/dev/null 2>&1 &
    sleep 3
    msg_alert "服务已经添加！"
}

set_ddns() {
    while true; do
        line_break
        read -r -p "请输入你的域名> " str
        [ -z "$str" ] && domain="$domain" || domain="$str"
        echo ""
        read -r -p "请输入用户名或邮箱> " str
        [ -z "$str" ] && username="$username" || username="$str"
        echo ""
        read -r -p "请输入密码或令牌秘钥> " str
        [ -z "$str" ] && password="$password" || password="$str"
        echo ""
        read -r -p "请输入检测更新间隔(单位:分钟；默认为10)> " check_interval
        [ -z "$check_interval" ] || [ "$check_interval" -lt 1 -o "$check_interval" -gt 1440 ] && check_interval=10
        echo ""
        read -r -p "请输入强制更新间隔(单位:小时；默认为24)> " force_interval
        [ -z "$force_interval" ] || [ "$force_interval" -lt 1 -o "$force_interval" -gt 240 ] && force_interval=24

        comp_box "请核对如下信息：" \
            "" \
            "服务商：		\033[32m$service\033[0m" \
            "域名：			\033[32m$domain\033[0m" \
            "用户名：		\033[32m$username\033[0m" \
            "检测间隔：		\033[32m$check_interval\033[0m"
        btm_box "是否确认添加："
        btm_box "1) 是" \
            "0) 否，重新輸入"
        read -r -p "$COMMON_INPUT> " res
        if [ "$res" = 1 ]; then
            add_ddns
            break
        fi
    done
}

set_ddns_service() {
    while true; do
        services_dir=/etc/ddns/"$serv"
        [ -s "$services_dir" ] || services_dir=/usr/share/ddns/list
        comp_box "\033[32m请选择服务提供商：\033[0m"

        # cat "$services_dir" | grep -v '^#' | awk '{print NR") " $1}'
        awk '!/^#/ {print NR") " $1}' "$services_dir" |
            while IFS= read -r line; do
                content_line "$line"
            done

        nr=$(cat "$services_dir" | grep -v '^#' | wc -l)
        common_back
        read -r -p "请输入对应数字> " num
        if [ -z "$num" ] || [ "$num" = 0 ]; then
            i=
            break
        elif [ "$num" -gt 0 ] && [ "$num" -lt "$nr" ]; then
            service_name=$(cat "$services_dir" | grep -v '^#' | awk '{print $1}' | sed -n "$num"p | sed 's/"//g')
            service=$(echo "$service_name" | sed 's/\./_/g')
            set_ddns
            break
        else
            msg_alert "\033[33m输入错误，请重新输入！\033[0m"
        fi
    done
}

set_ddns_type() {
    while true; do
        comp_box "\033[32m请选择网络模式：\033[0m"
        btm_box "1) \033[36mIPV4\033[0m" \
            "2) \033[36mIPV6\033[0m" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "请输入对应数字> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            use_ipv6=0
            serv=services
            set_ddns_service
            break
            ;;
        2)
            use_ipv6=1
            serv=services_ipv6
            set_ddns_service
            break
            ;;
        *)
            msg_alert "\033[33m输入错误，请重新输入！\033[0m"
            ;;
        esac
    done
}

rev_ddns_service() {
    while true; do
        enabled=$(uci get ddns."$service".enabled)
        [ "$enabled" = 1 ] && enabled_b="停用" || enabled_b="启用"
        comp_box "1) \033[32m立即更新\033[0m" \
            "2) 编辑当前服务" \
            "3) $enabled_b当前服务" \
            "4) 移除当前服务" \
            "5) 查看运行日志" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应数字> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            /usr/lib/ddns/dynamic_dns_updater.sh -S "$service" start >/dev/null 2>&1 &
            sleep 3
            break
            ;;
        2)
            domain=$(uci get ddns."$service".domain 2>/dev/null)
            username=$(uci get ddns."$service".username 2>/dev/null)
            password=$(uci get ddns."$service".password 2>/dev/null)
            service_name=$(uci get ddns."$service".service_name 2>/dev/null)
            uci delete ddns."$service"
            set_ddns
            break
            ;;
        3)
            [ "$enabled" = 1 ] && uci set ddns."$service".enabled='0' || uci set ddns."$service".enabled='1' && sleep 3
            uci commit ddns."$service"
            break
            ;;
        4)
            uci delete ddns."$service"
            uci commit ddns."$service"
            break
            ;;
        5)
            line_break
            echo "==========================================================="
            cat /var/log/ddns/"$service".log 2>/dev/null
            echo "==========================================================="
            break
            ;;
        *)
            msg_alert "\033[33m输入错误，请重新输入！\033[0m"
            ;;
        esac
    done
}

load_ddns() {
    while true; do
        ddns_dir=/etc/config/ddns
        tmp_dir="$TMPDIR"/ddns
        [ ! -f "$ddns_dir" ] && {
            btm_box "\033[31m本脚本依赖OpenWrt内置的DDNS服务,当前设备无法运行,已退出！\033[0m"
            sleep 1
            return 1
        }
        nr=0
        cat "$ddns_dir" | grep 'config service' | awk '{print $3}' | sed "s/'//g" | sed 's/"//g' >"$tmp_dir"
        separator_line "="
        content_line "    列表      域名       启用     IP地址"
        content_line ""
        [ -s "$tmp_dir" ] && for service in $(cat "$tmp_dir"); do
            # echo $service >>$tmp_dir
            nr=$((nr + 1))
            enabled=$(uci get ddns."$service".enabled 2>/dev/null)
            domain=$(uci get ddns."$service".domain 2>/dev/null)
            local_ip=$(sed '1!G;h;$!d' /var/log/ddns/"$service".log 2>/dev/null | grep -E 'Registered IP' | tail -1 | awk -F "'" '{print $2}' | tr -d "'\"")
            content_line "$nr)   $domain  $enabled   $local_ip"
        done
        content_line "$((nr + 1))) 添加DDNS服务"
        content_line "0) 退出"
        separator_line "="
        read -r -p "请输入对应序号> " num
        if [ -z "$num" ] || [ "$num" = 0 ]; then
            i=
            rm -rf "$tmp_dir"
            break
        elif [ "$num" -gt $nr ]; then
            set_ddns_type
        elif [ "$num" -gt 0 ] && [ "$num" -le $nr ]; then
            service=$(cat "$tmp_dir" | sed -n "$num"p)
            rev_ddns_service
        else
            msg_alert "\033[33m请输入正确数字！\033[0m"
        fi
    done
}
