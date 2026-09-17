#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_6_CORECONFIG_LOADED" ] && return
__IS_MODULE_6_CORECONFIG_LOADED=1

load_lang 6_core_config

if echo "$crashcore" | grep -q 'singbox'; then
    CONFIG_PATH="$CRASHDIR"/jsons/config.json
    CORE_TYPE=singbox
else
    CONFIG_PATH="$CRASHDIR"/yamls/config.yaml
    CORE_TYPE=clash
fi
URI_EXP='ss|vmess|vless|trojan|tuic|anytls|shadowtls|hysteria(2)?'

# 配置文件主界面
set_core_config() {
    while true; do
        list=$(cat "$CRASHDIR"/configs/providers.cfg "$CRASHDIR"/configs/providers_uri.cfg 2>/dev/null |
            LC_ALL=C awk '{
    f1 = $1
    f2 = $2
    gsub(/\360[\200-\277][\200-\277][\200-\277]/,"",f1)
    if (length(f1) > 12)
        f1 = substr(f1, 1, 8) ".."
    if (length(f2) > 30)
        f2 = substr(f2, 1, 30) "..."
    printf "%-7s \t%-28s\n", f1, f2
}')
        comp_box "\033[30;47m$CORECFG_TITLE\033[0m"
        [ -n "$list" ] && {
            content_line "\033[36m$CORECFG_HINT_SELECT_PROVIDER\033[0m"
            content_line ""
            list_box "$list"
            separator_line "-"
        }
        btm_box "a) $CORECFG_MENU_A" \
            "b) $CORECFG_MENU_B" \
            "c) $CORECFG_MENU_C" \
            "d) $CORECFG_MENU_D" \
            "e) $CORECFG_MENU_E" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT_L> " num
        case "$num" in
        "" | 0)
            break
            ;;
        [1-9] | [1-9][0-9])
            line=$(cat "$CRASHDIR"/configs/providers.cfg "$CRASHDIR"/configs/providers_uri.cfg 2>/dev/null | sed -n "$num p")
            setproviders "$line"
            ;;
        a)
            setproviders
            ;;
        b)
            if [ -s "$CRASHDIR"/configs/providers.cfg ] || [ -s "$CRASHDIR"/configs/providers_uri.cfg ]; then
                if [ "$crashcore" = meta ] || [ "$crashcore" = singboxr ]; then
                    . "$CRASHDIR"/menus/providers.sh
                    providers
                else
                    msg_alert "\033[33m$CORECFG_CORE_ONLY\033[0m"
                fi
            else
                msg_alert "$CORECFG_ADD_PROVIDER_FIRST"
            fi
            ;;
        c)
            if [ -s "$CRASHDIR"/configs/providers.cfg ] || [ -s "$CRASHDIR"/configs/providers_uri.cfg ]; then
                . "$CRASHDIR"/menus/subconverter.sh
                subconverter
            else
                msg_alert "$CORECFG_ADD_PROVIDER_FIRST"
            fi
            ;;
        d)
            comp_box "\033[33m$CORECFG_CLEAR_WARN\033[0m" \
                "" \
                "$CORECFG_CLEAR_CONFIRM"
            btm_box "1) $CORECFG_YES" \
                "0) $CORECFG_NO_BACK"
            read -r -p "$COMMON_INPUT> " res
            [ "$res" = 1 ] && {
                rm -f "$CRASHDIR"/configs/providers.cfg
                rm -f "$CRASHDIR"/configs/providers_uri.cfg
                common_success
            }
            ;;
        e)
            checkcfg=$(cat "$CFG_PATH")
            . "$CRASHDIR"/menus/override.sh && override
            if [ -n "$PID" ]; then
                checkcfg_new=$(cat "$CFG_PATH")
                [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
            fi
            ;;
        *)
            error_letter
            ;;
        esac
    done
}

# 添加/管理提供者
setproviders() {
    case "$(echo "$@" | cut -d ' ' -f 2)" in
    http* | ./providers*)
        set -- $@
        name=$1
        link=$2
        interval=$3
        interval2=$4
        ua=$5
        exclude_w=${6#\#}
        include_w=${7#\#}
        ;;
    *://*)
        set -- $@
        name=$1
        link_uri=$2
        ;;
    *)
        unset name link link_uri interval interval2 ua exclude_w include_w
        ;;
    esac
    last_name="$name"
    [ -z "$interval" ] && interval=3
    [ -z "$interval2" ] && interval2=12
    [ -z "$ua" ] && ua='clash.meta'

    while true; do
        link_info=$(echo "$link$link_uri" | cut -c 1-30)
        comp_box "\033[36m$CORECFG_PROVIDER_SUPPORT\033[0m"

        content_line "1) $CORECFG_SET_NAME	\033[32m$name\033[0m"
        content_line "2) $CORECFG_SET_LINK	\033[36m$link_info\033[0m"
        [ -n "$link" ] &&
            content_line "3) $CORECFG_SET_OVERRIDE"
        content_line ""
        content_line "a) $CORECFG_SAVE_PROVIDER"
        content_line "d) $CORECFG_DEL_PROVIDER"
        content_line ""
        content_line "\033[36m$CORECFG_MORE_CONFIG_HINT\033[0m"
        [ -n "$2" ] &&
            content_line "b) $CORECFG_GEN_LOCAL_ONE"
        echo "$2" | grep -q '://' &&
            content_line "c) $CORECFG_GEN_ONLINE_ONE"
        echo "$link" | grep -q '^http' &&
            content_line "e) $CORECFG_GET_ONLINE_DIRECT"
        echo "$link" | grep -q '^./providers' &&
            content_line "e) $CORECFG_USE_DIRECT"
        btm_box "" \
            "0) $COMMON_BACK"
        read -r -p "$CORECFG_INPUT_ALNUM> " input
        case "$input" in
        "" | 0)
            break
            ;;
        1)
            while true; do
                comp_box "\033[33m$CORECFG_NAME_HINT\033[0m"
                btm_box "\033[36m$CORECFG_INPUT_NAME\033[0m" \
                    "$CORECFG_OR_BACK"
                read -r -p "$CORECFG_INPUT> " text
                text=$(printf "%.12s" "$text" | sed 's/ //g') # 截断12字符+去空格
                if [ "$text" = 0 ]; then
                    break
                elif [ -n "$text" ] && [ -z "$(echo "$text" | grep -E '^[0-9]+$')" ] && ! grep -q "^$text " "$CRASHDIR"/configs/providers.cfg 2>/dev/null; then
                    name="$text"
                    common_success
                    break
                else
                    error_input
                fi
            done
            ;;
        2)
            while true; do
                comp_box "$CORECFG_LINK_HINT1" \
                    "" \
                    "$CORECFG_LINK_HINT2\n$URI_EXP" \
                    "" \
                    "$CORECFG_LINK_HINT3\033[32m$CRASHDIR/providers\033[0m$CORECFG_LINK_HINT4" \
                    "" \
                    "$CORECFG_LINK_HINT5"
                list=$(
                    for f in "$CRASHDIR"/providers/*; do
                        [ "$f" = "$CRASHDIR"/providers/uri_group ] && continue
                        [ -f "$f" ] || continue
                        printf '%s\n' "${f##*/}"
                    done | sort
                )
                if [ -n "$list" ]; then
                    list_box "$list"
                    btm_box "" \
                        "$CORECFG_INPUT0_BACK"
                    read -r -p "$CORECFG_SELECT_FILE_OR_LINK> " text
                else
                    btm_box "\033[36m$CORECFG_INPUT_LINK\033[0m" \
                        "$CORECFG_OR_BACK"
                    read -r -p "$CORECFG_INPUT> " text
                fi
                text=$(echo "$text" | sed 's/ //g') # 去空格
                case "$text" in
                0)
                    break
                    ;;
                http*)
                    # 处理订阅链接
                    text=$(echo "$text" | sed 's/ *(.*)//g; s/#.*//g') # 处理注释及超链接
                    link="$text"
                    link_uri=''
                    common_success
                    break
                    ;;
                [1-9] | [1-9][0-9])
                    # 处理本地文件
                    file=$(printf '%s\n' "$list" | sed -n "${text}p")
                    if [ -s "$CRASHDIR/providers/$file" ]; then
                        link="./providers/$file"
                        [ -z "$name" ] && name="_$(printf "%.12s" "$file" | sed 's/ //g')"
                        link_uri=''
                        common_success
                        break
                    else
                        errornum
                    fi
                    ;;
                *)
                    # 处理分享链接
                    if [ -n "$(echo "$text" | grep -E "^$URI_EXP")" ]; then
                        link_uri=$(echo "$text" | sed 's/#.*//g') # 删除注释
                        link=''
                        [ -z "$name" ] && name=$(printf '%b' "$(printf '%s' "$text" | sed 's/+/ /g; s/%/\\x/g')" | sed 's/.*#//')
                        common_success
                        break
                    else
                        error_input
                    fi
                    ;;
                esac
            done
            ;;
        3)
            custproviders
            ;;
        a)
            saveproviders && common_success
            break
            ;;
        b)
            if [ -n "$name" ] && [ -n "$link" ]; then
                saveproviders
                . "$CRASHDIR/menus/providers_$CORE_TYPE.sh"
                gen_providers "$name" "$link" "$interval" "$interval2" "$ua" "#$exclude_w" "#$include_w"
            else
                msg_alert "\033[31m$CORECFG_FILL_REQUIRED\033[0m"
            fi
            ;;
        c)
            if [ -n "$name" ] && [ -n "$link$link_uri" ]; then
                saveproviders
                [ -n "$link" ] && Url="$link"
                # vmess分享链接(base64编码的json)的节点名在ps字段中，不能追加#名称
                [ -n "$link_uri" ] && Url=$(echo "$name $link_uri" | awk '{ print ($2 ~ "^vmess://[A-Za-z0-9+/=_-]+$" ? $2 : $2 "#" $1) }')
                Https=''
                setconfig Url "'$Url'"
                setconfig Https
                # 获取在线文件
                jump_core_config
            else
                msg_alert "\033[31m$CORECFG_FILL_REQUIRED\033[0m"
            fi
            ;;
        d)
            if [ -n "$name" ] && [ -n "$link" ]; then
                sed -i "/^$name /d" "$CRASHDIR"/configs/providers.cfg 2>/dev/null
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            elif [ -n "$name" ] && [ -n "$link_uri" ]; then
                sed -i "/^$name /d" "$CRASHDIR"/configs/providers_uri.cfg 2>/dev/null
                msg_alert "\033[32m$COMMON_SUCCESS\033[0m"
            fi
            break
            ;;
        e)
            if [ -n "$link" ]; then
                comp_box "\033[31m$CORECFG_DANGER1\033[0m" \
                    "\033[31m$CORECFG_DANGER2\033[0m"
                btm_box "1) $CORECFG_DANGER_CONFIRM" \
                    "0) $COMMON_BACK"
                read -r -p "$COMMON_INPUT> " res
                [ "$res" = "1" ] && {
                    file=$(echo "$CRASHDIR/$link" | sed 's|\./||')
                    if [ -f "$file" ]; then
                        [ -n "$name" ] && saveproviders
                        ln -sf "$file" "$CONFIG_PATH"
                        common_success
                        break
                    elif echo "$link" | grep -q '^http'; then
                        [ -n "$name" ] && saveproviders
                        Https="$link"
                        Url=''
                        setconfig Https "'$Https'"
                        setconfig Url
                        # 获取在线文件
                        jump_core_config
                        break
                    else
                        msg_alert "\033[31m$CORECFG_FILL_REQUIRED\033[0m"
                    fi
                }
            else
                msg_alert "\033[31m$CORECFG_FILL_REQUIRED\033[0m"
            fi
            ;;
        *)
            error_letter
            ;;
        esac
    done
}

# 保存
saveproviders() {
    [ -n "$name" ] && {
        [ -s "$CRASHDIR"/configs/providers.cfg ] && sed -i "/^$last_name /d" "$CRASHDIR"/configs/providers.cfg
        [ -s "$CRASHDIR"/configs/providers_uri.cfg ] && sed -i "/^$last_name /d" "$CRASHDIR"/configs/providers_uri.cfg
    }
    if [ -n "$name" ] && [ -n "$link" ]; then
        echo "$name $link $interval $interval2 $ua #$exclude_w #$include_w" >>"$CRASHDIR"/configs/providers.cfg
        return 0
    elif [ -n "$name" ] && [ -n "$link_uri" ]; then
        echo "$name $link_uri" >>"$CRASHDIR"/configs/providers_uri.cfg
        return 0
    else
        msg_alert "\033[31m$CORECFG_FILL_REQUIRED\033[0m"
        return 1
    fi
}

# 本地生成覆写
custproviders() {
    while true; do
        top_box "1) $CORECFG_INTERVAL1\033[47;30m$interval\033[0m $CORECFG_MIN" \
            "2) $CORECFG_INTERVAL2\033[47;30m$interval2\033[0m $CORECFG_HOUR"
        echo "$link" | grep -q '^http' &&
            content_line "3) $CORECFG_SET_UA\033[47;30m$ua\033[0m"
        btm_box "4) $CORECFG_SET_EXCLUDE\033[47;30m$exclude_w\033[0m" \
            "5) $CORECFG_SET_INCLUDE\033[47;30m$include_w\033[0m" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            while true; do
                comp_box "$CORECFG_CUR_INTERVAL$interval $CORECFG_MIN"
                btm_box "\033[36m$CORECFG_INPUT_INTERVAL1\033[0m" \
                    "$CORECFG_RESET_INTERVAL1" \
                    "$CORECFG_OR_BACK"
                read -r -p "$CORECFG_INPUT> " num
                if [ "$num" = "r" ]; then
                    interval=3
                elif [ -n "$num" ] && [ "$num" -eq "$num" ] 2>/dev/null; then
                    interval="$num"
                else
                    errornum
                    continue
                fi
                common_success
                break
            done
            ;;
        2)
            while true; do
                comp_box "$CORECFG_CUR_INTERVAL$interval $CORECFG_MIN"
                btm_box "\033[36m$CORECFG_INPUT_INTERVAL2\033[0m" \
                    "$CORECFG_RESET_INTERVAL2" \
                    "$CORECFG_OR_BACK"
                read -r -p "$CORECFG_INPUT> " num
                if [ "$num" = "r" ]; then
                    interval2=12
                elif [ -n "$num" ] && [ "$num" -eq "$num" ] 2>/dev/null; then
                    interval2="$num"
                else
                    errornum
                    continue
                fi
                common_success
                break
            done
            ;;
        3)
            if [ -z "$ua" ]; then
                comp_box "$CORECFG_CUR_UA_NONE"
            else
                comp_box "$CORECFG_CUR_UA$ua"
            fi
            btm_box "\033[36m$CORECFG_INPUT_UA\033[0m" \
                "$CORECFG_RESET_UA" \
                "$CORECFG_OR_BACK"
            read -r -p "$CORECFG_INPUT> " text
            case "$text" in
            0)
                continue
                ;;
            r)
                ua='clash.meta'
                ;;
            *)
                ua="$text"
                ;;
            esac
            common_success
            ;;
        4)
            if [ -z "$exclude_w" ]; then
                comp_box "$CORECFG_CUR_EXCLUDE_NONE"
            else
                comp_box "$CORECFG_CUR_EXCLUDE$exclude_w"
            fi

            btm_box "\033[36m$CORECFG_INPUT_EXCLUDE\033[0m" \
                "$CORECFG_CLEAR_EXCLUDE" \
                "$CORECFG_OR_BACK"
            read -r -p "$CORECFG_INPUT> " text
            text=$(echo "$text" | sed 's/ //g') # 去空格
            case "$text" in
            0)
                continue
                ;;
            c)
                exclude_w=''
                ;;
            *)
                exclude_w="$text"
                ;;
            esac
            common_success
            ;;
        5)
            if [ -z "$include_w" ]; then
                comp_box "$CORECFG_CUR_INCLUDE_NONE"
            else
                comp_box "$CORECFG_CUR_INCLUDE$include_w"
            fi
            btm_box "\033[36m$CORECFG_INPUT_INCLUDE\033[0m" \
                "$CORECFG_CLEAR_INCLUDE" \
                "$CORECFG_OR_BACK"
            read -r -p "$CORECFG_INPUT> " text
            text=$(echo "$text" | sed 's/ //g') # 去空格
            case "$text" in
            0)
                continue
                ;;
            c)
                include_w=''
                ;;
            *)
                include_w="$text"
                ;;
            esac
            common_success
            ;;
        *)
            error_letter
            ;;
        esac
    done
}

# 调用工具在线获取配置文件
jump_core_config() {
    . "$CRASHDIR"/starts/core_config.sh && get_core_config
    if [ "$?" = 0 ]; then
        if [ "$inuserguide" != 1 ]; then
            comp_box "$CORECFG_START_APPLY"
            btm_box "1) $CORECFG_YES" \
                "0) $CORECFG_NO"
            read -r -p "$COMMON_INPUT> " res
            if [ "$res" = 1 ]; then
                start_core
            else
                main_menu
            fi
            exit
        fi
    fi
}
