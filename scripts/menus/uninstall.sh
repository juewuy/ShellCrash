#!/bin/sh
# Copyright (C) Juewuy

# 卸载
uninstall() {
    format_box "\033[31m警告：\033[0m" \
        "\033[31m该操作不可逆！\033" \
        "是否确认卸载ShellCrash："
    content_line "1) 是"
    content_line "0) 否"
    separator_line "="
    read -r -p "$COMMON_INPUT> " res
    if [ "$res" = '1' ]; then
        # 停止服务
        "$CRASHDIR"/start.sh stop 2>/dev/null
        "$CRASHDIR"/start.sh cronset "clash服务" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "订阅链接" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "ShellCrash初始化" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "task.sh" 2>/dev/null

        # 移除安装目录
        if [ -n "$CRASHDIR" ] && [ "$CRASHDIR" != '/' ]; then
            format_box "是否保留脚本配置及订阅文件："
            content_line "1) 是"
            content_line "0) 否"
            separator_line "="
            read -r -p "$COMMON_INPUT> " res
            if [ "$res" = '1' ]; then
                mv -f "$CRASHDIR"/configs /tmp/ShellCrash/configs_bak
                mv -f "$CRASHDIR"/yamls /tmp/ShellCrash/yamls_bak
                mv -f "$CRASHDIR"/jsons /tmp/ShellCrash/jsons_bak
                rm -rf "$CRASHDIR"/*
                mv -f /tmp/ShellCrash/configs_bak "$CRASHDIR"/configs
                mv -f /tmp/ShellCrash/yamls_bak "$CRASHDIR"/yamls
                mv -f /tmp/ShellCrash/jsons_bak "$CRASHDIR"/jsons
            else
                rm -rf "$CRASHDIR"
            fi
        else
            error_report "\033[31m环境变量配置有误，请尝试手动移除安装目录！\033[0m"
        fi

        # 移除其他内容
        sed -i "/alias $my_alias=*/"d /etc/profile 2>/dev/null
        sed -i '/alias crash=*/'d /etc/profile 2>/dev/null
        sed -i '/export CRASHDIR=*/'d /etc/profile 2>/dev/null
        sed -i '/export crashdir=*/'d /etc/profile 2>/dev/null
        [ -w ~/.zshrc ] && {
            sed -i "/alias $my_alias=*/"d ~/.zshrc 2>/dev/null
            sed -i '/export CRASHDIR=*/'d ~/.zshrc 2>/dev/null
        }
        sed -i '/all_proxy/'d /etc/profile 2>/dev/null
        sed -i '/ALL_PROXY/'d /etc/profile 2>/dev/null
        sed -i "/启用外网访问SSH服务/d" /etc/firewall.user 2>/dev/null
        sed -i '/ShellCrash初始化/'d /etc/storage/started_script.sh 2>/dev/null
        sed -i '/ShellCrash初始化/'d /jffs/.asusrouter 2>/dev/null
        [ "$BINDIR" != "$CRASHDIR" ] && rm -rf "$BINDIR"
        rm -rf /etc/init.d/shellcrash
        rm -rf /etc/systemd/system/shellcrash.service
        rm -rf /usr/lib/systemd/system/shellcrash.service
        rm -rf /www/clash
        rm -rf /tmp/ShellCrash
        rm -rf /usr/bin/crash
        sed -i '/0:7890/d' /etc/passwd 2>/dev/null
        userdel -r shellcrash 2>/dev/null
        nvram set script_usbmount="" 2>/dev/null
        nvram commit 2>/dev/null
        format_box "\033[36m已卸载ShellCrash相关文件！有缘再会！\033[0m" \
            "\033[33m请手动关闭当前窗口以重置环境变量！\033[0m"
        line_break
        sleep 1
        exit 0
    else
        format_box "\033[31m操作已取消！\033[0m"
        sleep 1
    fi
}
