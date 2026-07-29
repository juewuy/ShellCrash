#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_8_TOOLS_LOADED" ] && return
__IS_MODULE_8_TOOLS_LOADED=1

. "$CRASHDIR"/libs/logger.sh
. "$CRASHDIR"/libs/web_get_bin.sh
load_lang 8_tools

stop_iptables() {
    iptables -w -t nat -D PREROUTING -p tcp -m multiport --dports "$ssh_port" -j REDIRECT --to-ports 22 >/dev/null 2>&1
    ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports "$ssh_port" -j REDIRECT --to-ports 22 >/dev/null 2>&1
}

ssh_tools() {
    while true; do
        [ -n "$(cat /etc/firewall.user 2>&1 | grep '启用外网访问SSH服务')" ] && ssh_ol=$TOOLS_SSH_DISABLE || ssh_ol=$TOOLS_SSH_ENABLE
        [ -z "$ssh_port" ] && ssh_port=10022
        comp_box "\033[33m$TOOLS_SSH_ONLY_OPENWRT\033[0m" \
            "\033[31m$TOOLS_SSH_UNSUPPORTED_SYSTEM\033[0m"
        btm_box "${TOOLS_SSH_PORT_ITEM_PREFIX}\033[36m$ssh_port\033[0m${TOOLS_SSH_PORT_ITEM_SUFFIX}" \
            "$TOOLS_SSH_PASS_ITEM" \
            "${TOOLS_SSH_TOGGLE_ITEM_PREFIX}\033[33m$ssh_ol\033[0m${TOOLS_SSH_TOGGLE_ITEM_SUFFIX}" \
            "" \
            "0) $COMMON_BACK \033[0m"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            line_break
            read -r -p "$TOOLS_PROMPT_PORT" num
            if [ -z "$num" ]; then
                errornum
            elif [ "$num" -gt 65535 ] || [ "$num" -le 999 ]; then
                msg_alert "\033[31m$TOOLS_ERR_PORT\033[0m"
            elif [ -n "$(netstat -ntul | grep :$num)" ]; then
                msg_alert "\033[31m$TOOLS_ERR_PORT_OCCUPIED\033[0m"
            else
                ssh_port=$num
                setconfig ssh_port "$ssh_port"
                sed -i "/启用外网访问SSH服务/d" /etc/firewall.user
                stop_iptables

                msg_alert "\033[32m$TOOLS_SSH_SET_OK"
            fi
            ;;
        2)
            passwd
            sleep 1
            ;;
        3)
            if [ "$ssh_ol" = "$TOOLS_SSH_ENABLE" ]; then
                iptables -w -t nat -A PREROUTING -p tcp -m multiport --dports "$ssh_port" -j REDIRECT --to-ports 22
                [ -n "$(ckcmd ip6tables)" ] && ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports "$ssh_port" -j REDIRECT --to-ports 22
                echo "iptables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >>/etc/firewall.user
                [ -n "$(ckcmd ip6tables)" ] && echo "ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >>/etc/firewall.user
                comp_box "$TOOLS_SSH_ENABLED"
            else
                sed -i "/启用外网访问SSH服务/d" /etc/firewall.user
                stop_iptables
                comp_box "$TOOLS_SSH_DISABLED"
            fi
            break
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 工具与优化
tools() {
    while true; do
        # 获取设置默认显示
        grep -qE "^\s*[^#].*otapredownload" /etc/crontabs/root >/dev/null 2>&1 && mi_update=$TOOLS_DISABLE || mi_update=$TOOLS_ENABLE
        [ "$mi_mi_autoSSH" = "$TOOLS_CONFIGURED" ] && mi_mi_autoSSH_type=32m$TOOLS_CONFIGURED || mi_mi_autoSSH_type=31m$COMMON_UNSET
        [ -f "$CRASHDIR"/tools/tun.ko ] && mi_tunfix=32mON || mi_tunfix=31mOFF
        comp_box "\033[30;47m$TOOLS_TITLE\033[0m" \
            "" \
            "\033[33m$TOOLS_WARN_COMPAT\033[0m" \
            "$TOOLS_DISK_USAGE" \
            "$(du -sh "$CRASHDIR")"
        content_line "$TOOLS_MENU_TEST_ITEM"
        content_line "$TOOLS_MENU_GUIDE_ITEM"
        content_line "$TOOLS_MENU_LOG_ITEM"
        [ -f /etc/firewall.user ] && content_line "$TOOLS_MENU_SSH_ITEM"
        [ -x /usr/sbin/otapredownload ] && content_line "${TOOLS_MENU_MI_UPDATE_ITEM_PREFIX}\033[33m$mi_update\033[0m${TOOLS_MENU_MI_UPDATE_ITEM_SUFFIX}"
        [ "$systype" = "mi_snapshot" ] && content_line "${TOOLS_MENU_MI_AUTO_SSH_ITEM_PREFIX}\033[$mi_mi_autoSSH_type \033[0m${TOOLS_MENU_MI_AUTO_SSH_ITEM_SUFFIX}"
        [ "$systype" = "mi_snapshot" ] && content_line "${TOOLS_MENU_MI_TUN_FIX_ITEM_PREFIX}\033[$mi_tunfix \033[0m${TOOLS_MENU_MI_TUN_FIX_ITEM_SUFFIX}"
        btm_box "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            testcommand
            ;;
        2)
            . "$CRASHDIR"/menus/userguide.sh && userguide
            break
            ;;
        3)
            log_pusher
            ;;
        4)
            ssh_tools
            sleep 1
            ;;
        5)
            if [ -x /usr/sbin/otapredownload ]; then
                if [ "$mi_update" = "$TOOLS_DISABLE" ]; then
                    grep -q "otapredownload" /etc/crontabs/root &&
                        sed -i "/^[^\#]*otapredownload/ s/^/#/" /etc/crontabs/root ||
                        echo "#15 3,4,5 * * * /usr/sbin/otapredownload >/dev/null 2>&1" >>/etc/crontabs/root
                else
                    grep -q "otapredownload" /etc/crontabs/root &&
                        sed -i "/^\s*#.*otapredownload/ s/^\s*#//" /etc/crontabs/root ||
                        echo "15 3,4,5 * * * /usr/sbin/otapredownload >/dev/null 2>&1" >>/etc/crontabs/root
                fi
                [ "$mi_update" = "$TOOLS_DISABLE" ] && mi_update=$TOOLS_ENABLE || mi_update=$TOOLS_DISABLE
                msg_alert "\033[32m${TOOLS_MI_UPDATE_MSG_PREFIX}\033[33m$mi_update\033[0m${TOOLS_MI_UPDATE_MSG_SUFFIX}\033[0m"
            fi
            ;;
        6)
            if [ "$systype" = "mi_snapshot" ]; then
                mi_autoSSH
            else
                msg_alert "\033[31m$TOOLS_UNSUPPORTED_DEVICE"
            fi
            ;;
        7)
            line_break
            separator_line "="
            if [ ! -f "$CRASHDIR"/tools/ShellDDNS.sh ]; then
                content_line "$TOOLS_FETCHING_SCRIPT"
                get_bin "$TMPDIR"/ShellDDNS.sh tools/ShellDDNS.sh
                if [ "$?" = "0" ]; then
                    mv -f "$TMPDIR"/ShellDDNS.sh "$CRASHDIR"/tools/ShellDDNS.sh
                    . "$CRASHDIR"/tools/ShellDDNS.sh
                else
                    content_line "\033[31m$TOOLS_DOWNLOAD_FAIL\033[0m"
                    separator_line "="
                fi
            else
                . "$CRASHDIR"/tools/ShellDDNS.sh
            fi
            sleep 1
            ;;
        8)
            if [ -f "$CRASHDIR"/tools/tun.ko ]; then
                comp_box "$TOOLS_DISABLE_FIX_CONFIRM"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                [ "$res" = 1 ] && {
                    rm -rf "$CRASHDIR"/tools/tun.ko
                    msg_alert "\033[33m$TOOLS_PATCH_REMOVED\033[0m"
                }
            elif ckcmd modinfo && [ -z "$(modinfo tun)" ]; then
                comp_box "\033[33m$TOOLS_TUN_WARN1\033[0m" \
                    "\033[33m$TOOLS_TUN_WARN2\033[0m"
                btm_box "$TOOLS_ACCEPT_RISK" \
                    "0) $COMMON_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    line_break
                    separator_line "="
                    content_line "$TOOLS_TUN_CONNECTING"
                    get_bin "$TMPDIR"/tun.ko bin/fix/tun.ko
                    if [ "$?" = "0" ]; then
                        mv -f "$TMPDIR"/tun.ko "$CRASHDIR"/tools/tun.ko &&
                            /data/shellcrash_init.sh tunfix &&
                            content_line "\033[32m$TOOLS_TUN_OK\033[0m"
                    else
                        content_line "\033[31m$TOOLS_TUN_FAIL\033[0m"
                    fi
                    separator_line "="
                else
                    continue
                fi
            else
                msg_alert "\033[31m$TOOLS_DEVICE_NOT_NEED\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

mi_autoSSH() {
    comp_box "\033[33m$TOOLS_AUTO_SSH_WARN1\033[0m" \
        "\033[33m$TOOLS_AUTO_SSH_WARN2\033[36;4mhttps://t.me/ShellClash\033[0m"
    btm_box "$TOOLS_AUTO_SSH_PWD_HINT1" \
        "$TOOLS_AUTO_SSH_PWD_HINT2"
    read -r -p "$TOOLS_AUTO_SSH_INPUT" mi_mi_autoSSH_pwd
    mi_mi_autoSSH=$TOOLS_CONFIGURED
    cp -f /etc/dropbear/dropbear_rsa_host_key "$CRASHDIR"/configs/dropbear_rsa_host_key 2>/dev/null
    cp -f /etc/dropbear/authorized_keys "$CRASHDIR"/configs/authorized_keys 2>/dev/null
    ckcmd nvram && {
        nvram set ssh_en=1
        nvram set telnet_en=1
        nvram set uart_en=1
        nvram set boot_wait=on
        nvram commit
    }
    setconfig mi_mi_autoSSH $mi_mi_autoSSH
    setconfig mi_mi_autoSSH_pwd "$mi_mi_autoSSH_pwd"
    msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
}

# 日志菜单
log_pusher() {
    while true; do
        [ -n "$push_TG" ] && stat_TG=32mON || stat_TG=33mOFF
        [ -n "$push_Deer" ] && stat_Deer=32mON || stat_Deer=33mOFF
        [ -n "$push_bark" ] && stat_bark=32mON || stat_bark=33mOFF
        [ -n "$push_Po" ] && stat_Po=32mON || stat_Po=33mOFF
        [ -n "$push_PP" ] && stat_PP=32mON || stat_PP=33mOFF
        [ -n "$push_SynoChat" ] && stat_SynoChat=32mON || stat_SynoChat=33mOFF
        [ -n "$push_Gotify" ] && stat_Gotify=32mON || stat_Gotify=33mOFF
        [ "$task_push" = 1 ] && stat_task=32mON || stat_task=33mOFF
        [ -n "$device_name" ] && device_s=32m$device_name || device_s=33m$COMMON_UNSET
        comp_box "${TOOLS_LOG_TG_PREFIX}\033[$stat_TG\033[0m${TOOLS_LOG_TG_SUFFIX}" \
            "${TOOLS_LOG_DEER_PREFIX}\033[$stat_Deer\033[0m${TOOLS_LOG_DEER_SUFFIX}" \
            "${TOOLS_LOG_BARK_PREFIX}\033[$stat_bark\033[0m${TOOLS_LOG_BARK_SUFFIX}" \
            "${TOOLS_LOG_PO_PREFIX}\033[$stat_Po\033[0m${TOOLS_LOG_PO_SUFFIX}" \
            "${TOOLS_LOG_PP_PREFIX}\033[$stat_PP\033[0m${TOOLS_LOG_PP_SUFFIX}" \
            "${TOOLS_LOG_SYNO_PREFIX}\033[$stat_SynoChat\033[0m${TOOLS_LOG_SYNO_SUFFIX}" \
            "${TOOLS_LOG_GOTIFY_PREFIX}\033[$stat_Gotify\033[0m${TOOLS_LOG_GOTIFY_SUFFIX}" \
            "" \
            "$TOOLS_LOG_VIEW" \
            "${TOOLS_LOG_TASK_PREFIX}\033[$stat_task\033[0m${TOOLS_LOG_TASK_SUFFIX}" \
            "${TOOLS_LOG_DEVICE_PREFIX}\033[$device_s\033[0m${TOOLS_LOG_DEVICE_SUFFIX}" \
            "$TOOLS_LOG_CLEAR" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$push_TG" ]; then
                comp_box "$TOOLS_CONFIRM_CLOSE_TG"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    push_TG=
                    chat_ID=
                    setconfig push_TG
                    setconfig chat_ID
                else
                    continue
                fi
            else
                # echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
                . "$CRASHDIR"/menus/bot_tg_bind.sh
                chose_bot() {
                    comp_box "$TOOLS_BOT_PUBLIC" \
                        "$TOOLS_BOT_PRIVATE" \
                        "" \
                        "0) $COMMON_BACK"
                    read -r -p "$COMMON_INPUT> " num
                    case "$num" in
                    0)
                        return 0
                        ;;
                    1)
                        public_bot
                        set_bot && tg_push_token || chose_bot
                        ;;
                    2)
                        private_bot
                        set_bot && tg_push_token || chose_bot
                        ;;
                    *)
                        errornum
                        ;;
                    esac
                }
                chose_bot
            fi
            ;;
        2)
            if [ -n "$push_Deer" ]; then
                comp_box "$TOOLS_CONFIRM_CLOSE_DEER"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    push_Deer=
                    push_Deer_url=
                    setconfig push_Deer
                    setconfig push_Deer_url
                else
                    continue
                fi
            else
                # echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
                comp_box "$TOOLS_PUSHDEER_SELECT_SERVER" \
                    "$TOOLS_PUSHDEER_OFFICIAL" \
                    "$TOOLS_PUSHDEER_CUSTOM" \
                    "" \
                    "0) $COMMON_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" num
                case "$num" in
                0)
                    continue
                    ;;
                2)
                    comp_box "$TOOLS_PUSHDEER_CUSTOM_URL_HINT" \
                        "$TOOLS_PUSHDEER_CUSTOM_URL_EXAMPLE"
                    btm_box "\033[36m$TOOLS_PUSHDEER_CUSTOM_URL_INPUT\033[0m" \
                        "$TOOLS_OR_BACK"
                    read -r -p "$TOOLS_AUTO_SSH_INPUT" url
                    if [ "$url" = 0 ]; then
                        continue
                    elif [ -z "$url" ]; then
                        msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                        continue
                    fi
                    push_Deer_url=${url%/}
                    setconfig push_Deer_url "${url%/}"
                    ;;
                1)
                    push_Deer_url=
                    setconfig push_Deer_url
                    ;;
                *)
                    errornum
                    continue
                    ;;
                esac
                comp_box "$TOOLS_PUSHDEER_INSTALL1" \
                    "$TOOLS_PUSHDEER_INSTALL2" \
                    "$TOOLS_PUSHDEER_INSTALL3" \
                    "$TOOLS_PUSHDEER_INSTALL4"
                btm_box "\033[36m$TOOLS_PUSHDEER_SECRET_HINT\033[0m" \
                    "$TOOLS_OR_BACK"
                read -r -p "$TOOLS_AUTO_SSH_INPUT" url
                if [ "$url" = 0 ]; then
                    continue
                elif [ -n "$url" ]; then
                    push_Deer=$url
                    setconfig push_Deer "$url"
                    logger "$TOOLS_PUSHDEER_OK" 32
                else
                    msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                fi
            fi
            ;;
        3)
            if [ -n "$push_bark" ]; then
                comp_box "$TOOLS_CONFIRM_CLOSE_BARK"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    push_bark=
                    bark_param=
                    setconfig push_bark
                    setconfig bark_param
                else
                    continue
                fi
            else
                # echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
                comp_box "\033[33m$TOOLS_BARK_WARN\033[0m" \
                    "\033[32m$TOOLS_BARK_INSTALL\033[0m"
                btm_box "\033[36m$TOOLS_BARK_URL_HINT\033[0m" \
                    "$TOOLS_OR_BACK"
                read -r -p "$TOOLS_AUTO_SSH_INPUT" url
                if [ "$url" = 0 ]; then
                    continue
                elif [ -n "$url" ]; then
                    push_bark=$url
                    setconfig push_bark "$url"
                    logger "$TOOLS_BARK_OK" 32
                else
                    msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                fi
            fi
            ;;
        4)
            if [ -n "$push_Po" ]; then
                comp_box "$TOOLS_CONFIRM_CLOSE_PO"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    push_Po=
                    push_Po_key=
                    setconfig push_Po
                    setconfig push_Po_key
                else
                    continue
                fi
            else
                # echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
                comp_box "$TOOLS_PUSHOVER_REG" \
                    "" \
                    "\033[36m$TOOLS_PUSHOVER_USERKEY_HINT\033[0m" \
                    "$TOOLS_OR_BACK"
                read -r -p "$TOOLS_AUTO_SSH_INPUT" key
                if [ "$key" = 0 ]; then
                    continue
                elif [ -n "$key" ]; then
                    comp_box "\033[33m$TOOLS_PUSHOVER_VERIFY\033[0m"
                    btm_box "$TOOLS_PUSHOVER_VERIFIED" \
                        "0) $COMMON_BACK"
                    read -r -p "$TOOLS_PUSHOVER_VERIFY_PROMPT" res
                    if [ "$res" = 1 ]; then
                        comp_box "$TOOLS_PUSHOVER_TOKEN_BUILD"
                        read -r -p "$TOOLS_PUSHOVER_TOKEN_HINT> " Token
                        if [ -n "$Token" ]; then
                            push_Po=$Token
                            push_Po_key=$key
                            setconfig push_Po "$Token"
                            setconfig push_Po_key "$key"
                            logger "$TOOLS_PUSHOVER_OK" 32
                        else
                            msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                        fi
                    else
                        continue
                    fi
                else
                    msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                fi
            fi
            ;;
        5)
            if [ -n "$push_PP" ]; then
                comp_box "$TOOLS_CONFIRM_CLOSE_PP"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    push_PP=
                    setconfig push_PP
                else
                    continue
                fi
            else
                # echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
                comp_box "$TOOLS_PUSHPLUS_REG"
                btm_box "\033[36m$TOOLS_PUSHPLUS_TOKEN_HINT\033[0m" \
                    "$TOOLS_OR_BACK"
                read -r -p "$TOOLS_AUTO_SSH_INPUT" Token
                if [ "$Token" = 0 ]; then
                    continue
                elif [ -n "$Token" ]; then
                    push_PP=$Token
                    setconfig push_PP "$Token"
                    logger "$TOOLS_PUSHPLUS_OK" 32
                else
                    msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                fi
            fi
            ;;
        6)
            if [ -n "$push_SynoChat" ]; then
                comp_box "$TOOLS_CONFIRM_CLOSE_SYNO"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    push_SynoChat=
                    setconfig push_SynoChat
                else
                    continue
                fi
            else
                line_break
                read -r -p "$TOOLS_SYNOCHAT_URL_HINT> " URL
                read -r -p "$TOOLS_SYNOCHAT_TOKEN_HINT> " TOKEN
                comp_box "$TOOLS_SYNOCHAT_USERID_HINT"
                read -r -p "$TOOLS_SYNOCHAT_USERID_INPUT" USERID
                if [ -n "$URL" ]; then
                    push_SynoChat=$USERID
                    setconfig push_SynoChat "$USERID"
                    setconfig push_ChatURL "$URL"
                    setconfig push_ChatTOKEN "$TOKEN"
                    setconfig push_ChatUSERID "$USERID"
                    logger "$TOOLS_SYNOCHAT_OK" 32
                else
                    setconfig push_ChatURL
                    setconfig push_ChatTOKEN
                    setconfig push_ChatUSERID
                    push_SynoChat=
                    setconfig push_SynoChat

                    msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                fi
            fi
            ;;
        # 在menu.sh的case $num in代码块中添加
        7)
            if [ -n "$push_Gotify" ]; then
                comp_box "$TOOLS_CONFIRM_CLOSE_GOTIFY"
                btm_box "$TOOLS_YES" \
                    "$TOOLS_NO_BACK"
                read -r -p "$TOOLS_SELECT_PROMPT" res
                if [ "$res" = 1 ]; then
                    push_Gotify=
                    setconfig push_Gotify
                else
                    continue
                fi
            else
                comp_box "$TOOLS_GOTIFY_REG" \
                    "$TOOLS_GOTIFY_FORMAT"
                btm_box "\033[36m$TOOLS_GOTIFY_URL_HINT\033[0m" \
                    "$TOOLS_OR_BACK"
                read -r -p "$TOOLS_AUTO_SSH_INPUT" url
                if [ "$url" = 0 ]; then
                    continue
                elif [ -n "$url" ]; then
                    push_Gotify=$url
                    setconfig push_Gotify "$url"
                    logger "$TOOLS_GOTIFY_OK" 32
                else
                    msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
                fi
            fi
            ;;
        a)
            if [ -s "$TMPDIR"/ShellCrash.log ]; then
                line_break
                echo "==========================================================="
                cat "$TMPDIR"/ShellCrash.log
                echo "==========================================================="
                exit
            else
                msg_alert "\033[31m$TOOLS_LOG_NOT_FOUND\033[0m"
            fi
            ;;
        b)
            [ "$task_push" = 1 ] && task_push='' || task_push=1
            setconfig task_push "$task_push"
            sleep 1
            ;;
        c)
            comp_box "$TOOLS_DEVICE_NAME_HINT" \
                "$TOOLS_DEVICE_NAME_BACK"
            read -r -p "$TOOLS_AUTO_SSH_INPUT" device_name
            if [ -n "$device_name" ]; then
                setconfig device_name "$device_name"
            fi
            ;;
        d)
            rm -rf "$TMPDIR"/ShellCrash.log
            msg_alert "\033[33m$TOOLS_LOG_CLEARED\033[0m"
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 测试菜单
testcommand() {
    while true; do
        comp_box "\033[30;47m$TOOLS_TEST_MENU_TITLE\033[0m" \
            "\033[33m$TOOLS_TEST_MENU_HINT\033[0m"
        btm_box "$TOOLS_TEST_ITEM_1" \
            "$TOOLS_TEST_ITEM_2" \
            "$TOOLS_TEST_ITEM_3" \
            "$TOOLS_TEST_ITEM_4" \
            "$TOOLS_TEST_ITEM_5" \
            "$TOOLS_TEST_ITEM_6" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        0)
            break
            ;;
        1)
            debug
            ;;
        2)
            line_break
            echo "==========================================================="
            if ckcmd netstat;then
                netstat -ntulp | grep 53
			elif ckcmd ss;then
                ss -ntulp | grep 53
			else
                echo -e "Neither net-tools nor iproute2 is installed. Please install one of these packages and try again."
            fi
            echo
            echo -e "$TOOLS_NETSTAT_HINT"
            echo "==========================================================="
			sleep 2
            ;;
        3)
            line_break
            openssl speed -multi 4 -evp aes-128-gcm
            ;;
        4)
            line_break
            if [ "$firewall_mod" = "nftables" ]; then
                nft list table inet shellcrash | sed '/set cn_ip {/,/}/d;/set cn_ip6 {/,/}/d;/^[[:space:]]*}/d'
            else
                [ "$firewall_area" = 1 -o "$firewall_area" = 3 -o "$firewall_area" = 5 -o "$vm_redir" = "ON" ] && {
                    echo "----------------Redir+DNS---------------------"
                    iptables -t nat -L PREROUTING --line-numbers
                    iptables -t nat -L shellcrash_dns --line-numbers
                    [ -n "$(echo $redir_mod | grep -E 'Redir|Mix')" ] && iptables -t nat -L shellcrash --line-numbers
                    [ -n "$(echo "$redir_mod" | grep -E 'Tproxy|Mix|Tun')" ] && {
                        echo "----------------Tun/Tproxy-------------------"
                        iptables -t mangle -L PREROUTING --line-numbers
                        iptables -t mangle -L shellcrash_mark --line-numbers
                    }
                }
                [ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && {
                    echo "-------------OUTPUT-Redir+DNS----------------"
                    iptables -t nat -L OUTPUT --line-numbers
                    iptables -t nat -L shellcrash_dns_out --line-numbers
                    [ -n "$(echo "$redir_mod" | grep -E 'Redir|Mix')" ] && iptables -t nat -L shellcrash_out --line-numbers
                    [ -n "$(echo "$redir_mod" | grep -E 'Tproxy|Mix|Tun')" ] && {
                        echo "------------OUTPUT-Tun/Tproxy---------------"
                        iptables -t mangle -L OUTPUT --line-numbers
                        iptables -t mangle -L shellcrash_mark_out --line-numbers
                    }
                }
                [ "$ipv6_redir" = "ON" ] && {
                    [ "$firewall_area" = 1 -o "$firewall_area" = 3 ] && {
                        ip6tables -t nat -L >/dev/null 2>&1 && {
                            echo "-------------IPV6-Redir+DNS-------------------"
                            ip6tables -t nat -L PREROUTING --line-numbers
                            ip6tables -t nat -L shellcrashv6_dns --line-numbers
                            [ -n "$(echo "$redir_mod" | grep -E 'Redir|Mix')" ] && ip6tables -t nat -L shellcrashv6 --line-numbers
                        }
                        [ -n "$(echo "$redir_mod" | grep -E 'Tproxy|Mix|Tun')" ] && {
                            echo "-------------IPV6-Tun/Tproxy------------------"
                            ip6tables -t mangle -L PREROUTING --line-numbers
                            ip6tables -t mangle -L shellcrashv6_mark --line-numbers
                        }
                    }
                }
                [ "$vm_redir" = "ON" ] && {
                    echo "-------------vm-Redir-------------------"
                    iptables -t nat -L shellcrash_vm --line-numbers
                    iptables -t nat -L shellcrash_vm_dns --line-numbers
                }
                echo "$TOOLS_FW_TITLE"
                iptables -L INPUT --line-numbers
            fi
            ;;
        5)
            echo "$crashcore" | grep -q 'singbox' && config_path="$CRASHDIR"/jsons/config.json || config_path="$CRASHDIR"/yamls/config.yaml
            line_break
            sed -n '1,40p' "$config_path"
            ;;
        6)
            comp_box "\033[33m$TOOLS_PROXY_NOTE\033[0m"
            delay=$(
                curl -kx ${authentication}@127.0.0.1:$mix_port -o /dev/null -s -w '%{time_starttransfer}' 'https://google.tw' &
                {
                    sleep 3
                    kill $! >/dev/null 2>&1 &
                }
            ) >/dev/null 2>&1
            delay=$(echo | awk "{print $delay*1000}") >/dev/null 2>&1
            line_break
            separator_line "="
            if [ $(echo ${#delay}) -gt 1 ]; then
                content_line "\033[32m$TOOLS_PROXY_OK$delay ms\033[0m"
            else
                content_line "\033[31m$TOOLS_PROXY_TIMEOUT\033[0m"
            fi
            separator_line "="
            ;;
        *)
            errornum
            ;;
        esac
    done
}

debug() {
	rm -f "$CRASHDIR"/\.start_error #移除自启失败标记
    echo "$crashcore" | grep -q 'singbox' && config_tmp="$TMPDIR"/jsons || config_tmp="$TMPDIR"/config.yaml
    comp_box "\033[36m$TOOLS_DEBUG_WARN1\033[0m" \
        "${TOOLS_DEBUG_WARN2_PREFIX}\033[32m$TMPDIR/debug.log\033[0m${TOOLS_DEBUG_WARN2_SUFFIX}" \
        "$TOOLS_DEBUG_WARN3" \
        "$TOOLS_DEBUG_WARN4"
    content_line "${TOOLS_DEBUG_ITEM_1_PREFIX}\033[32m$config_tmp\033[0m${TOOLS_DEBUG_ITEM_1_SUFFIX}"
    content_line "${TOOLS_DEBUG_ITEM_2_PREFIX}\033[32m$config_tmp\033[0m${TOOLS_DEBUG_ITEM_2_SUFFIX}"
    content_line "$TOOLS_DEBUG_ITEM_3"
    content_line "$TOOLS_DEBUG_ITEM_4"
    content_line "$TOOLS_DEBUG_ITEM_5"
    content_line "${TOOLS_DEBUG_ITEM_6_PREFIX}\033[32m$CRASHDIR/debug.log\033[0m${TOOLS_DEBUG_ITEM_6_SUFFIX}"
    content_line ""
    content_line "$TOOLS_DEBUG_ITEM_8"
    [ -s "$TMPDIR"/jsons/inbounds.json ] && content_line "${TOOLS_DEBUG_ITEM_9_PREFIX}\033[32m$config_tmp\033[0m${TOOLS_DEBUG_ITEM_9_SUFFIX}\033[32m$TMPDIR/debug.json\033[0m"
    btm_box "" \
        "0) $COMMON_BACK"
    read -r -p "$COMMON_INPUT> " num
    case "$num" in
    0) ;;
    1)
        "$CRASHDIR"/start.sh stop
        "$CRASHDIR"/starts/bfstart.sh
        if echo "$crashcore" | grep -q 'singbox'; then
            "$TMPDIR"/CrashCore run -D "$BINDIR" -C "$TMPDIR"/jsons &
            {
                sleep 4
                kill $! >/dev/null 2>&1 &
            }
            wait
        else
            "$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml
        fi
        rm -rf "$TMPDIR"/CrashCore
        line_break
        exit
        ;;
    2)
        "$CRASHDIR"/start.sh stop
        "$CRASHDIR"/start.sh bfstart
        $COMMAND
        rm -rf "$TMPDIR"/CrashCore
        line_break
        exit
        ;;
    3)
        "$CRASHDIR"/start.sh debug error
        main_menu
        ;;
    4)
        "$CRASHDIR"/start.sh debug info
        main_menu
        ;;
    5)
        "$CRASHDIR"/start.sh debug debug
        main_menu
        ;;
    6)
        comp_box "\033[33m$TOOLS_FLASH_WARN\033[0m" \
            "$TOOLS_FLASH_CONFIRM"
        btm_box "$TOOLS_YES" \
            "$TOOLS_NO"
        read -r -p "$TOOLS_SELECT_PROMPT" res
        if [ "$res" = 1 ]; then
            "$CRASHDIR"/start.sh debug debug flash
        fi
        main_menu
        ;;
    8)
        $0 -d
        main_menu
        ;;
    9)
        . "$CRASHDIR"/libs/core_tools.sh && core_find && "$TMPDIR"/CrashCore merge "$TMPDIR"/debug.json -C "$TMPDIR"/jsons && line_break
        comp_box "\033[32m$TOOLS_MERGE_OK\033[0m"
        [ "$TMPDIR" = "$BINDIR" ] && rm -rf "$TMPDIR"/CrashCore
        debug
        ;;
    *)
        errornum
        ;;
    esac
}
