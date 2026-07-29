#!/bin/sh
# Copyright (C) Juewuy

. "$CRASHDIR"/libs/check_cmd.sh

load_lang check_port

_get_netstat_cmd() {
    local cmd=netstat
    ckcmd ss && cmd=ss

    case "$1" in
    tcp) echo "$cmd -ntl" ;;
    udp) echo "$cmd -nul" ;;
    *) echo "$cmd -ntul" ;;
    esac
}

check_port() {
    local port="$1"
    local protocol="${2:-all}"

    if [ "$port" -gt 65535 ] || [ "$port" -le 1 ]; then
        msg_alert "\033[31m$CHECK_PORT_RANGE_ERR\033[0m"
        return 1
    fi

    local check_cmd
    check_cmd=$(_get_netstat_cmd "$protocol")

    if $check_cmd 2>/dev/null | grep -q ":${port}[[:space:]]"; then
        msg_alert "\033[31m$CHECK_PORT_OCCUPIED_ERR\033[0m"
        return 1
    fi

    return 0
}

check_port_with_info() {
    local port="$1"
    local protocol="${2:-all}"
    local check_cmd
    check_cmd=$(_get_netstat_cmd "$protocol")

    local conflict_line
    conflict_line=$($check_cmd 2>/dev/null | grep ":${port}[[:space:]]" | head -n 1)

    if [ -n "$conflict_line" ]; then
        echo "$conflict_line"
        return 1
    fi

    return 0
}
