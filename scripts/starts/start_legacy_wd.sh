#!/bin/sh
# Copyright (C) Juewuy

[ -z "$CRASHDIR" ] && CRASHDIR=$(cd "$(dirname "$0")"/.. && pwd)
SERVICE_NAME="$1"

. "$CRASHDIR"/libs/check_process.sh

#当启动失败后禁止开机自启动
[ -f "$CRASHDIR"/.start_error ] && [ ! -f /tmp/ShellCrash/crash_start_time ] && exit 1

if check_daemon_process "$SERVICE_NAME"; then
    exit 0
fi

#如果没有进程则拉起
cleanup_daemon_state "$SERVICE_NAME" "false"

if [ "$SERVICE_NAME" = "shellcrash" ]; then
    if ! "$CRASHDIR"/start.sh start; then
        [ -f "$CRASHDIR"/libs/logger.sh ] && . "$CRASHDIR"/libs/logger.sh && logger "守护进程：启动 $SERVICE_NAME 失败" 31
        exit 1
    fi
else
    if [ -f "$CRASHDIR/starts/start_legacy.sh" ]; then
        . "$CRASHDIR"/starts/start_legacy.sh
        killall bot_tg.sh 2>/dev/null
        if ! start_legacy "$CRASHDIR/menus/bot_tg.sh" "$SERVICE_NAME"; then
            [ -f "$CRASHDIR"/libs/logger.sh ] && . "$CRASHDIR"/libs/logger.sh && logger "守护进程：启动 $SERVICE_NAME 失败" 31
            exit 1
        fi
    fi
fi
