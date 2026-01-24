#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_6_CORECONFIG_LOADED" ] && return
__IS_MODULE_6_CORECONFIG_LOADED=1

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
        format_box "\033[30;47m配置文件管理\033[0m"
        [ -s "$CRASHDIR"/configs/providers.cfg ] || [ -s "$CRASHDIR"/configs/providers_uri.cfg ] && {
            echo -e "\033[36m输入数字可管理对应提供者\033[0m"
            cat "$CRASHDIR"/configs/providers.cfg "$CRASHDIR"/configs/providers_uri.cfg 2>/dev/null |
                awk '{print " " NR ") " $1 "  \t\t" substr($2,1,30) "..."}'
            separator_line "-"
        }
        content_line "a) \033[32m添加提供者\033[0m(支持订阅/分享链接及本地文件)"
        content_line "b) \033[36m本地生成配置文件\033[0m(By Providers,推荐！)"
        content_line "c) \033[33m在线生成配置文件\033[0m(By Subconverter)"
        content_line "d) \033[31m清空提供者列表\033[0m"
        content_line "e) \033[36m自定义配置文件\033[0m"

        common_back
        read -r -p "$COMMON_INPUT_L > " num
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
                    error_report "\033[33m仅限Mihomo/singboxr内核使用,请更换内核！\033[0m"
                fi
            else
                error_report "请先添加提供者！"
            fi
            ;;
        c)
            if [ -s "$CRASHDIR"/configs/providers.cfg ] || [ -s "$CRASHDIR"/configs/providers_uri.cfg ]; then
                . "$CRASHDIR"/menus/subconverter.sh
                subconverter
            else
                error_report "请先添加提供者！"
            fi
            ;;
        d)
            separator_line "="
            content_line "\033[33m警告：这将删除所有提供者且无法还原！\033[0m"
            separator_line "-"
            read -r -p "确认清空提供者列表？(1/0) > " res
            [ "$res" = 1 ] && {
                rm -f "$CRASHDIR"/configs/providers.cfg
                rm -f "$CRASHDIR"/configs/providers_uri.cfg
                common_success
            }
            ;;
        e)
            checkcfg=$(cat $CFG_PATH)
            override
            if [ -n "$PID" ]; then
                checkcfg_new=$(cat $CFG_PATH)
                [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
            fi
            ;;

        *)
            error_letter
            break
            ;;
        esac
    done
}

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
        set -- $line
        name=$1
        link_uri=$2
        ;;
    esac
	last_name="$name"
    [ -z "$interval" ] && interval=3
    [ -z "$interval2" ] && interval2=12
    [ -z "$ua" ] && ua='clash.meta'
    while true; do
        link_info=$(echo "$link$link_uri" | cut -c 1-30)
        format_box "\033[36m支持添加订阅链接/分享链接/本地文件作为提供者\033[0m"
        content_line "1) 设置\033[36m名称或代号\033[0m	\033[32m$name\033[0m"
        content_line "2) 设置\033[32m链接或路径\033[0m：	\033[36m$link_info...\033[0m"
        [ -n "$link" ] && {
            separator_line '-'
            content_line "3) 设置\033[33m健康检查间隔\033[0m：\t\033[47;30m$interval\033[0m"
            content_line "4) 设置\033[36m自动更新间隔\033[0m：\t\033[47;30m$interval2\033[0m"
            content_line "5) 设置\033[31m排除节点正则\033[0m：\t\033[47;30m$exclude_w\033[0m"
            content_line "6) 设置\033[32m包含节点正则\033[0m：\t\033[47;30m$include_w\033[0m"
            echo "$link" | grep -q '^http' &&
                content_line "7) 设置\033[33m虚拟浏览器UA\033[0m：\t\033[47;30m$ua\033[0m"
        }
        separator_line "-"
        content_line "a) \033[36m保存此提供者\033[0m"
        [ -n "$link" ] &&
            content_line "b) \033[32m本地生成\033[0m仅包含此提供者的配置文件"
        echo "$link$link_uri" | grep -q '://' &&
            content_line "c) \033[33m在线生成\033[0m仅包含此提供者的配置文件"
        [ -n "$link" ] &&
            content_line "e) 直接使用此配置文件(不经过转换)"
        content_line "d) \033[31m删除此提供者\033[0m"
        common_back
        read -r -p "请输入对应数字> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            separator_line "="
            content_line "注意：名称或代号不可重复,且不支持纯数字！"
            separator_line "-"
            read -p "请输入具体名称或代号 > " text
            text=$(echo $text | sed 's/ //g') #去空格
            if [ -n "$text" ] && [ -z "$(echo "$text" | grep -E '^[0-9]+$')" ] && ! grep -q "$text" "$CRASHDIR"/configs/providers.cfg; then
                name="$text"
            else
                error_input
            fi
            ;;
        2)
            separator_line "="
            content_line "\033[33m订阅链接\033[0m: https/http开头的clash配置文件订阅链接"
            content_line "\033[36m分享链接\033[0m: $URI_EXP"
            content_line "\033[33m本地文件\033[0m: 必须放在此目录下:\033[32m$CRASHDIR/providers\033[0m"
			content_line "\033[36m Base64 \033[0m: 请直接写入本地文件"
            separator_line "-"
			list=$(
				for f in "$CRASHDIR"/providers/*; do
					[ "$f" = "$CRASHDIR"/providers/uri_group ] && continue
					[ -f "$f" ] || continue
					printf '%s\n' "${f##*/}"
				done | sort -V
			)
			if [ -n "$list" ];then
				i=1
				printf '%s\n' "$list" | while IFS= read -r f; do
					content_line "$i) $f"
					i=$((i+1))
				done
				separator_line "-"
				read -r -p "请选择对应文件或输入具体链接 > " text
			else
				read -r -p "请输入具体链接 > " text
			fi
            text=$(echo "$text" | sed 's/ //g') #去空格
			case "$text" in
            http*)
				#处理订阅链接
                text=$(echo "$text" | sed 's/ *(.*)//g; s/#.*//g') #处理注释及超链接
                link="$text"
				common_success
				;;
			[1-9] | [1-9][0-9])
				#处理本地文件
				file=$(printf '%s\n' "$list" | sed -n "${text}p")
				if [ -s "$CRASHDIR/providers/$file" ]; then
					link="$file"
					common_success
				else
					errornum
				fi
				;;
			*)
				#处理分享链接
				if [ -n "$(echo $text | grep -E "^$URI_EXP")" ]; then
					link_uri=$(echo "$text" | sed 's/#.*//g') # 删除注释
					[ -z "$name" ] && name=$(echo "$text" | grep -o '#.*$' | cut -c2-)
					common_success
				else
					error_input
				fi
				;;
			esac
            ;;
        3)
            read -p "请输入健康检查间隔(单位:分钟) > " num
            if [ -n "$num" ]; then
                interval="$num"
            else
                errornum
            fi
            ;;
        4)
            read -p "请输入自动更新间隔(单位:小时) > " num
            if [ -n "$num" ]; then
                interval2="$num"
            else
                errornum
            fi
            ;;
        5)
            read -p "请输入需要排除的节点关键字(支持正则,不支持空格,输入0删除) > " text
			text=$(echo "$text" | sed 's/ //g') #去空格
            case "$text" in
			0)
                exclude_w=''
				;;
			*)
                exclude_w="$text"
				;;
            esac
            ;;
        6)
            read -p "请输入需要筛选使用的节点关键字(支持正则,不支持空格,输入0删除) > " text
			text=$(echo "$text" | sed 's/ //g') #去空格
            case "$text" in
			0)
                include_w=''
				;;
			*)
                include_w="$text"
				;;
            esac
            ;;
        7)
            read -p "请输入浏览器UA(输入0重置) > " text
            case "$text" in
			0)
                include_w='clash.meta'
				;;
			*)
                include_w="$text"
				;;
            esac
            ;;
        a)
            addproviders && common_success
            break
            ;;
        b)
            if [ -n "$name" ] && [ -n "$link" ]; then
                addproviders
                . "$CRASHDIR/menus/providers_$CORE_TYPE.sh"
                gen_providers "$name" "$link" "$interval" "$interval2" "$ua" "#$exclude_w" "#$include_w"
            else
                content_line "\033[31m$请先完成必填选项！\033[0m"
            fi
            ;;
        c)
            if [ -n "$name" ] && [ -n "$link$link_uri" ]; then
                addproviders
                Url="$link$link_uri"
                Https=''
                setconfig Url "'$Url'"
                setconfig Https
                # 获取在线文件
                jump_core_config
            else
                content_line "\033[31m请先完成必填选项！\033[0m"
            fi
            ;;
        d)
            if [ -n "$name" ] && [ -n "$link" ]; then
                sed -i "/^$name /d" "$CRASHDIR"/configs/providers.cfg
                content_line "\033[32m$COMMON_SUCCESS\033[0m"
            elif [ -n "$name" ] && [ -n "$link_uri" ]; then
                sed -i "/^$name /d" "$CRASHDIR"/configs/providers_uri.cfg
                content_line "\033[32m$COMMON_SUCCESS\033[0m"
            fi
            break
            ;;
        e)
            if [ -n "$link" ]; then
                content_line "注意：\033[31m此功能不兼容“跳过证书验证”功能\033[0m"
                content_line "\033[31m请确认你完全理解自己在做什么\033[0m"
                read -p "我确认遇到问题可以自行解决(1/0) > " res
                [ "$res" = "1" ] && {
                    if [ -s "$CRASHDIR/$link" ]; then
                        [ -n "$name" ] && addproviders
                        ln -sf "$CRASHDIR/$link" "$CONFIG_PATH"
                    elif [ -n "$link" ]; then
                        [ -n "$name" ] && addproviders
                        Https="$link"
                        Url=''
                        setconfig Https "'$Https'"
                        setconfig Url
                        # 获取在线文件
                        jump_core_config
                    fi
                }
            else
                content_line "\033[31m$请先完成必填选项！\033[0m"
            fi
            ;;
        *)
            error_letter
            break
            ;;
        esac
    done
}

addproviders() {
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
        error_report "\033[31m请先完成必填选项！\033[0m"
        return 1
    fi
}
# 调用工具在线获取配置文件
jump_core_config() {
    . "$CRASHDIR"/starts/core_config.sh && get_core_config
    if [ "$?" = 0 ]; then
        if [ "$inuserguide" != 1 ]; then
            read -p "是否启动服务以使配置文件生效？(1/0) > " res
            [ "$res" = 1 ] && start_core || main_menu
            exit
        fi
    fi
}
