#!/bin/sh
# Copyright (C) Juewuy
# 进程检测公共函数库

PIDFILE_DIR="/tmp/ShellCrash"

_get_pidfile_path() {
    echo "$PIDFILE_DIR/$1.pid"
}

check_crashcore_running() {
    local PID
    PID=$(pidof CrashCore 2>/dev/null | awk '{print $NF}')
    if [ -n "$PID" ]; then
        echo "$PID"
        return 0
    else
        return 1
    fi
}

#$1=PID文件路径
check_pidfile_process() {
    local PIDFILE="$1"
    local PID

    [ ! -f "$PIDFILE" ] && return 1

    PID=$(cat "$PIDFILE" 2>/dev/null)

    [ -z "$PID" ] && return 1
    [ "$PID" -eq "$PID" ] 2>/dev/null || return 1

    if kill -0 "$PID" 2>/dev/null; then
        return 0
    else
        rm -f "$PIDFILE"
        return 1
    fi
}

#$1=服务名称
check_daemon_process() {
    local service_name="$1"
    local PIDFILE

    case "$service_name" in
        shellcrash)
            check_crashcore_running >/dev/null 2>&1
            return $?
            ;;
        *)
            PIDFILE=$(_get_pidfile_path "$service_name")
            check_pidfile_process "$PIDFILE"
            return $?
            ;;
    esac
}

#$1=服务名称,$2="false"表示已知未运行（可选）
cleanup_daemon_state() {
    local service_name="$1"
    local is_not_running="$2"
    local PIDFILE

    case "$service_name" in
        shellcrash)
            PIDFILE=$(_get_pidfile_path "$service_name")
            if [ "$is_not_running" = "false" ]; then
                rm -f "$PIDFILE" 2>/dev/null
            elif ! check_crashcore_running >/dev/null 2>&1; then
                rm -f "$PIDFILE" 2>/dev/null
            fi
            ;;
        *)
            PIDFILE=$(_get_pidfile_path "$service_name")
            if [ "$is_not_running" = "false" ]; then
                rm -f "$PIDFILE" 2>/dev/null
            elif ! check_pidfile_process "$PIDFILE"; then
                rm -f "$PIDFILE" 2>/dev/null
            fi
            ;;
    esac
}
