#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_SUBCONVERTER" ] && return
__IS_MODULE_SUBCONVERTER=1

[ -z "$rule_link" ] && rule_link=1
[ -z "$server_link" ] && server_link=1

load_lang subconverter

LISTFILE="$CRASHDIR"/configs/servers_"$i18n".list

# Subconverter在线订阅转换
subconverter() {
    while true; do
        comp_box "1) \033[32m$SUBCONVERTER_MENU_GEN\033[0m"\
         "2) $SUBCONVERTER_MENU_EXCLUDE \033[47;30m$exclude\033[0m"\
         "3) $SUBCONVERTER_MENU_INCLUDE \033[47;30m$include\033[0m"\
         "4) $SUBCONVERTER_MENU_RULE"\
         "5) $SUBCONVERTER_MENU_SERVER"\
         "6) $SUBCONVERTER_MENU_UA  \033[32m$user_agent\033[0m"\
         ""\
         "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            providers_link=$(grep -v '\./providers/' "$CRASHDIR"/configs/providers.cfg 2>/dev/null | awk '{print $2}' | tr '\n' '|')
            # vmess分享链接(base64编码的json)的节点名在ps字段中，不能追加#名称
            uri_link=$(grep -v '^#' "$CRASHDIR"/configs/providers_uri.cfg 2>/dev/null | awk '{ print ($2 ~ "^vmess://[A-Za-z0-9+/=_-]+$" ? $2 : $2 "#" $1) }' | tr '\n' '|')
            Url=$(echo "$providers_link|$uri_link" | sed 's/||*/|/g; s/^|//; s/|$//')
            setconfig Url "'$Url'"
            Https=''
            setconfig Https
            # 获取在线文件
            jump_core_config
            ;;
        2)
            gen_link_flt
            ;;
        3)
            gen_link_ele
            ;;
        4)
            gen_link_config
            ;;
        5)
            gen_link_server
            ;;
        6)
            set_sub_ua
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 排除节点正则
gen_link_flt() {
    comp_box "\033[33m$SUBCONVERTER_EXCLUDE_HINT1\033[0m" \
        "$SUBCONVERTER_KEYWORD_SPLIT" \
        "$SUBCONVERTER_REGEX_HINT"
    btm_box "\033[36m$SUBCONVERTER_EXCLUDE_INPUT\033[0m" \
        "$SUBCONVERTER_EXCLUDE_CLEAR" \
        "$SUBCONVERTER_BACK"
    read -r -p "$SUBCONVERTER_INPUT> " res
    case "$res" in
    0)
        return 0
        ;;
    d)
        exclude=''
        ;;
    *)
        exclude="$res"
        ;;
    esac

    if setconfig exclude "'$exclude'"; then
        common_success
    else
        common_failed
    fi
}

# 包含节点正则
gen_link_ele() {
    comp_box "\033[33m$SUBCONVERTER_INCLUDE_HINT1\033[0m" \
        "$SUBCONVERTER_KEYWORD_SPLIT" \
        "$SUBCONVERTER_REGEX_HINT"
    btm_box "\033[36m$SUBCONVERTER_INCLUDE_INPUT\033[0m" \
        "$SUBCONVERTER_INCLUDE_CLEAR" \
        "$SUBCONVERTER_BACK"
    read -r -p "$SUBCONVERTER_INPUT> " res
    case "$res" in
    0)
        return 0
        ;;
    d)
        include=""
        ;;
    *)
        include="$res"
        ;;
    esac

    if setconfig include "'$include'"; then
        common_success
    else
        common_failed
    fi
}

# 选择在线规则模版
gen_link_config() {
    list=$(grep -aE '^5' "$LISTFILE" | awk '{print $2$4}')
    now=$(grep -aE '^5' "$LISTFILE" | sed -n ""$rule_link"p" | awk '{print $2}')
    comp_box "$SUBCONVERTER_RULE_CURRENT\033[33m$now\033[0m"
    list_box "$list"
    content_line ""
    common_back
    read -r -p "$COMMON_INPUT> " num
    totalnum=$(grep -acE '^5' "$CRASHDIR"/configs/servers_"$i18n".list)
    if [ -z "$num" ] || [ "$num" -gt "$totalnum" ]; then
        errornum
    elif [ "$num" = 0 ]; then
        echo
    elif [ "$num" -le "$totalnum" ]; then
        # 将对应标记值写入配置
        rule_link=$num
        if setconfig rule_link "$rule_link"; then
            msg_alert "\033[32m$SUBCONVERTER_SET_OK\033[0m"
        else
            common_failed
        fi
    fi
}

# 选择Subconverter服务器
gen_link_server() {
    list=$(grep -aE '^3|^4' "$LISTFILE" | awk '{print $3"	"$2}')
    now=$(grep -aE '^3|^4' "$LISTFILE" | sed -n ""$server_link"p" | awk '{print $3}')

    comp_box "\033[36m$SUBCONVERTER_SERVER_HINT\033[0m" \
        "\033[32m$SUBCONVERTER_SERVER_THANKS\033[0m" \
        "" \
        "$SUBCONVERTER_SERVER_CURRENT\033[33m$now\033[0m"
    list_box "$list"
    content_line ""
    common_back
    read -r -p "$COMMON_INPUT> " num
    totalnum=$(grep -acE '^3|^4' "$CRASHDIR"/configs/servers_"$i18n".list)
    if [ -z "$num" ] || [ "$num" -gt "$totalnum" ]; then
        errornum
    elif [ "$num" = 0 ]; then
        echo
    elif [ "$num" -le "$totalnum" ]; then
        # 将对应标记值写入配置
        server_link=$num
        if setconfig server_link "$server_link"; then
            content_line "\033[32m$SUBCONVERTER_SET_OK\033[0m"
        else
            common_failed
        fi
    fi
}

set_sub_ua() {
    while true; do
        comp_box "\033[36m$SUBCONVERTER_UA_HINT\033[0m" \
            "" \
            "$SUBCONVERTER_UA_CURRENT$user_agent"
        btm_box "1) $SUBCONVERTER_UA_AUTO"\
         "2) $SUBCONVERTER_UA_NONE"\
         "3) $SUBCONVERTER_UA_CUSTOM"\
         "4) $SUBCONVERTER_UA_CLEAR"\
         ""\
         "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        0)
            break
            ;;
        1)
            user_agent='auto'
            ;;
        2)
            user_agent='none'
            ;;
        3)
            comp_box "\033[33m$SUBCONVERTER_UA_CUSTOM_WARN\033[0m"
            btm_box "\033[36m$SUBCONVERTER_UA_CUSTOM_INPUT\033[0m" \
                "$SUBCONVERTER_BACK"
            read -r -p "$SUBCONVERTER_INPUT> " text
            if [ "$text" = 0 ]; then
                continue
            elif [ -n "$text" ]; then
                user_agent="$text"
            fi
            ;;
        4)
            user_agent=''
            ;;
        *)
            errornum
            continue
            ;;
        esac

        if [ "$num" -ge 1 ] && [ "$num" -le 4 ]; then
            if setconfig user_agent "$user_agent"; then
                common_success
            else
                common_failed
            fi
        fi
        break
    done
}
