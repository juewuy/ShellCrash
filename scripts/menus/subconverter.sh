#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_SUBCONVERTER" ] && return
__IS_MODULE_SUBCONVERTER=1

[ -z "$rule_link" ] && rule_link=1
[ -z "$server_link" ] && server_link=1

# Subconverter在线订阅转换
subconverter() {
    while true; do
        [ -z "$exclude" ] && exclude="未设置"
        [ -z "$include" ] && include="未设置"
        line_break
        separator_line "="
        content_line "1) \033[32m生成\033[0m包含全部节点／订阅的配置文件"
        content_line "2) 设置\033[31m排除节点正则\033[0m \033[47;30m$exclude\033[0m"
        content_line "3) 设置\033[32m包含节点正则\033[0m \033[47;30m$include\033[0m"
        content_line "4) 选择\033[33m在线规则模版\033[0m"
        content_line "5) 选择\033[0mSubconverter服务器\033[0m"
        content_line "6) 自定义浏览器UA  \033[32m$user_agent\033[0m"
        content_line ""
        common_back
        read -r -p "请输入对应数字> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            providers_link=$(grep -v '\./providers/' "$CRASHDIR"/configs/providers.cfg 2>/dev/null | awk '{print $2}' | tr '\n' '|')
            uri_link=$(grep -v '^#' "$CRASHDIR"/configs/providers_uri.cfg 2>/dev/null | awk '{ print ($1=="vmess" ? $2 : $2 "#" $1) }' | tr '\n' '|')
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
    comp_box "\033[33m当前过滤关键字：\033[47;30m$exclude\033[0m" \
        "" \
        "\033[33m匹配关键字的节点会在导入时被【屏蔽】！\033[0m" \
        "多个关键字可以用\033[30;47m | \033[0m号分隔" \
        "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
    btm_box "\033[36m请直接输入节点过滤关键字\033[0m" \
        "或输入 d \033[31m清空\033[0m节点过滤关键字" \
        "或输入 0 返回上级菜单"
    read -r -p "请输入> " res
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
    comp_box "\033[33m当前筛选关键字：\033[47;30m$include\033[0m" \
        "" \
        "\033[33m仅有匹配关键字的节点才会被【导入】！！！\033[0m" \
        "多个关键字可以用\033[30;47m | \033[0m号分隔" \
        "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
    btm_box "\033[36m请直接输入节点匹配关键字\033[0m" \
        "或输入 d \033[31m清空\033[0m节点匹配关键字" \
        "或输入 0 返回上级菜单"
    read -r -p "请输入> " res
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

    if setconfig exclude "'$include'"; then
        common_success
    else
        common_failed
    fi
}

# 选择在线规则模版
gen_link_config() {
    list=$(grep -aE '^5' "$CRASHDIR"/configs/servers.list | awk '{print $2$4}')
    now=$(grep -aE '^5' "$CRASHDIR"/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $2}')
    comp_box "当前使用规则为：\033[33m$now\033[0m"
    list_box "$list"
    content_line ""
    common_back
    read -r -p "请输入对应数字> " num
    totalnum=$(grep -acE '^5' "$CRASHDIR"/configs/servers.list)
    if [ -z "$num" ] || [ "$num" -gt "$totalnum" ]; then
        errornum
    elif [ "$num" = 0 ]; then
        echo
    elif [ "$num" -le "$totalnum" ]; then
        # 将对应标记值写入配置
        rule_link=$num
        if setconfig rule_link "$rule_link"; then
            msg_alert "\033[32m设置成功！返回上级菜单\033[0m"
        else
            common_failed
        fi
    fi
}

# 选择Subconverter服务器
gen_link_server() {
    list=$(grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | awk '{print $3"	"$2}')
    now=$(grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')

    comp_box "\033[36m以下为互联网采集的第三方服务器，具体安全性请自行斟酌！\033[0m" \
        "\033[32m感谢以下作者的无私奉献！！！\033[0m" \
        "" \
        "当前使用后端为：\033[33m$now\033[0m"
    list_box "$list"
    content_line ""
    common_back
    read -r -p "请输入对应数字> " num
    totalnum=$(grep -acE '^3|^4' "$CRASHDIR"/configs/servers.list)
    if [ -z "$num" ] || [ "$num" -gt "$totalnum" ]; then
        errornum
    elif [ "$num" = 0 ]; then
        echo
    elif [ "$num" -le "$totalnum" ]; then
        # 将对应标记值写入配置
        server_link=$num
        if setconfig server_link "$server_link"; then
            content_line "\033[32m设置成功！返回上级菜单\033[0m"
        else
            common_failed
        fi
    fi
}

set_sub_ua() {
    while true; do
        comp_box "\033[36m无法正确获取配置文件时可尝试使用\033[0m" \
            "" \
            "当前UA：$user_agent"
        content_line "1) 使用自动UA（默认）"
        content_line "2) 不使用UA"
        content_line "3) 使用自定义UA"
        content_line "4) 清空UA"
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应数字> " num
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
            comp_box "\033[33m注意：\n自定义UA不可包含空格或特殊符号！\033[0m"
            btm_box "\033[36m请直接输入自定义UA\033[0m" \
                "或输入 0 返回上级菜单"
            read -r -p "请输入> " text
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
