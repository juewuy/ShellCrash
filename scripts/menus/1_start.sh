#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_1_START_LOADED" ] && return
__IS_MODULE_1_START_LOADED=1
load_lang 1_start

# ===== 启动完成提示 =====
startover() {
    line_break
    separator_line "="
    content_line "\033[32m$START_SERVICE_OK\033[0m"
    content_line "$START_WEB_HINT \033[4;36mhttp://$host$hostdir\033[0m $START_WEB_HINT2"

    if [ "$firewall_area" = 4 ]; then
        content_line ""
        content_line "$START_PAC_HINT \033[4;32mhttp://$host:$db_port/ui/pac\033[0m"
        content_line "$START_PROXY_HINT IP{\033[36m$host\033[0m} Port{\033[36m$mix_port\033[0m}"
    fi
    separator_line "="
    line_break
    sleep 1
    return 0
}

# ===== 启动核心 =====
start_core() {
    if echo "$crashcore" | grep -q 'singbox'; then
        core_config="$CRASHDIR/jsons/config.json"
    else
        core_config="$CRASHDIR/yamls/config.yaml"
    fi

    if [ ! -s "$core_config" ] && [ -s "$CRASHDIR/configs/providers.cfg" ]; then
        if [ "$crashcore" = singboxr ];then
			CORE_TYPE=singbox
        else
			CORE_TYPE=clash
		fi
        . "$CRASHDIR/menus/providers_$CORE_TYPE.sh" && gen_providers

        line_break
        separator_line "="
        content_line "\033[33m$START_NO_CORE_CFG_TRY_GEN\033[0m"
        separator_line "="
    elif [ -s "$core_config" ] || [ -n "$Url" ] || [ -n "$Https" ]; then
        "$CRASHDIR/start.sh" start

        # 循环检测服务启动状态
        . "$CRASHDIR/libs/start_wait.sh"

        [ -n "$test" ] || pidof CrashCore >/dev/null && {
            # 启动 TG 机器人
            if [ "$bot_tg_service" = ON ]; then
                . "$CRASHDIR/menus/bot_tg_service.sh" && bot_tg_start
            fi
            startover
        }
    else
        line_break
        separator_line "="
        content_line "\033[31m$START_NO_CORE_CFG_IMPORT_FIRST\033[0m"
        separator_line "="
        . "$CRASHDIR/menus/6_core_config.sh" && set_core_config
    fi
}

# ===== 启动服务入口 =====
start_service() {
    if [ "$firewall_area" = 5 ]; then
        "$CRASHDIR/start.sh" start
        line_break
        separator_line "="
        content_line "\033[32m$START_FIREWALL_DONE\033[0m"
        separator_line "="
        line_break
    else
        start_core
    fi
}
