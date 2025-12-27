#!/bin/sh
# Copyright (C) Juewuy

check_network() { #检查是否联网
    for text in 223.5.5.5 1.2.4.8 dns.alidns.com doh.pub; do
        ping -c 3 $text >/dev/null 2>&1 && return 0
        sleep 5
    done
    logger "当前设备无法连接网络，已停止启动！" 33
    exit 1
}