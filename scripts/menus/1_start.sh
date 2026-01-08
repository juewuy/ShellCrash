#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_1_START_LOADED" ] && return
__IS_MODULE_1_START_LOADED=1

#启动相关
startover() {
    echo -ne "                                   \r"
    echo -e "\033[32m服务已启动！\033[0m"
    echo -e "请使用 \033[4;36mhttp://$host$hostdir\033[0m 管理内置规则"
    if [ "$redir_mod" = "纯净模式" ]; then
        echo "-----------------------------------------------"
        echo -e "其他设备可以使用PAC配置连接：\033[4;32mhttp://$host:$db_port/ui/pac\033[0m"
        echo -e "或者使用HTTP/SOCK5方式连接：IP{\033[36m$host\033[0m}Port{\033[36m$mix_port\033[0m}"
    fi
    return 0
}
start_core() {
    if echo "$crashcore" | grep -q 'singbox'; then
        core_config="$CRASHDIR"/jsons/config.json
    else
        core_config="$CRASHDIR"/yamls/config.yaml
    fi
    echo "-----------------------------------------------"
    if [ ! -s $core_config -a -s "$CRASHDIR"/configs/providers.cfg ]; then
        echo -e "\033[33m没有找到${crashcore}配置文件，尝试生成providers配置文件！\033[0m"
        [ "$crashcore" = singboxr ] && coretype=singbox
        [ "$crashcore" = meta -o "$crashcore" = clashpre ] && coretype=clash
        . "$CRASHDIR"/menus/6_core_config.sh && gen_${coretype}_providers
    elif [ -s $core_config -o -n "$Url" -o -n "$Https" ]; then
        "$CRASHDIR"/start.sh start
        #设置循环检测以判定服务启动是否成功
		. "$CRASHDIR"/libs/start_wait.sh
        [ -n "$test" -o -n "$(pidof CrashCore)" ] && {
			#启动TG机器人
			[ "$bot_tg_service" = ON ] && . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_start
			startover
		}
    else
        echo -e "\033[31m没有找到${crashcore}配置文件，请先导入配置文件！\033[0m"
        . "$CRASHDIR"/menus/6_core_config.sh && set_core_config
    fi
}
start_service() {
    if [ "$firewall_area" = 5 ]; then
        "$CRASHDIR"/start.sh start
        echo -e "\033[32m已完成防火墙设置！\033[0m"
    else
        start_core
    fi
}
