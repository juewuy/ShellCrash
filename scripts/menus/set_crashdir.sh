#!/bin/sh
# Copyright (C) Juewuy

[ -f /tmp/SC_tmp/libs/check_dir_avail.sh ] && . /tmp/SC_tmp/libs/check_dir_avail.sh

set_usb_dir() {
    while true; do
        comp_box "请选择安装目录："
        du -hL /mnt |
            awk '{print NR") "$2 " " $1}' |
            while IFS= read -r line; do
                content_line "$line"
            done
        separator_line "="
        read -r -p "请输入相应数字> " num
        dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
        if [ -z "$dir" ]; then
            msg_alert "\033[31m输入错误！请重新设置！\033[0m"
            continue
        fi
        break 1
    done
}

set_xiaomi_dir() {
    comp_box "\033[33m检测到当前设备为小米官方系统，请选择安装位置：\033[0m"
    [ -d /data ] && content_line "1) /data目录，剩余空间：$(dir_avail /data -h) （支持软固化功能）"
    [ -d /userdisk ] && content_line "2) /userdisk目录，剩余空间：$(dir_avail /userdisk -h) （支持软固化功能）"
    [ -d /data/other_vol ] && content_line "3) /data/other_vol目录，剩余空间：$(dir_avail /data/other_vol -h) （支持软固化功能）"
    content_line "4) 自定义目录（不推荐，不明勿用！）"
    content_line ""
    content_line "0) 退出安装"
    separator_line "="
    read -r -p "请输入相应数字> " num
    case "$num" in
    1)
        dir=/data
        ;;
    2)
        dir=/userdisk
        ;;
    3)
        dir=/data/other_vol
        ;;
    4)
        set_cust_dir
        ;;
    *)
        line_break
        exit 1
        ;;
    esac
}

set_asus_usb() {
    while true; do
        comp_box "请选择U盘目录："
        du -hL /tmp/mnt |
            awk -F/ 'NF<=4 {print NR") "$2 " " $1}' |
            while IFS= read -r line; do
                content_line "$line"
            done
        separator_line "="
        read -r -p "请输入相应数字> " num
        dir=$(du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print $2}' | sed -n "$num"p)
        if [ ! -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ]; then
            msg_alert "\033[31m未找到下载大师自启文件：$dir/asusware.arm/etc/init.d/S50downloadmaster，请检查设置！\033[0m"
        else
            break
        fi
    done
}

set_asus_dir() {
    separator_line "="
    btm_box "\033[33m检测到当前设备为华硕固件，请选择安装方式\033[0m" \
        "1) 基于U盘+下载大师安装（支持所有固件，限ARM设备，须插入U盘或移动硬盘）" \
        "2) 基于自启脚本安装（仅持部分梅林固件）" \
        "" \
        "0) 退出安装"
    read -r -p "请输入相应数字> " num
    case "$num" in
    1)
        msg_alert -t 2 "请先在路由器网页后台安装下载大师并启用，之后选择外置存储所在目录！"
        set_asus_usb
        ;;
    2)
        msg_alert -t 2 "如开机无法正常自启，请重新使用U盘+下载大师安装！"
        dir=/jffs
        ;;
    *)
        line_break
        exit 1
        ;;
    esac
}

set_cust_dir() {
    while true; do
        comp_box "路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！" \
            "" \
            "可用路径 剩余空间："
        df -h |
            awk '{print $6, $4}' |
            sed '1d' |
            while IFS= read -r line; do
                content_line "$line"
            done
        separator_line "="
        read -r -p "请输入自定义路径> " dir
        if [ "$(dir_avail "$dir")" = 0 ] || [ -n "$(echo "$dir" | grep -Eq '^/(tmp|opt|sys)(/|$)')" ]; then
            msg_alert "\033[31m路径错误！请重新设置！\033[0m"
            continue
        fi
        break 1
    done
}

set_crashdir() {
    while true; do
        top_box "\033[33m注意：安装ShellCrash至少需要预留约1MB的磁盘空间\033[0m"
        case "$systype" in
        Padavan)
            dir=/etc/storage
            ;;
        mi_snapshot)
            set_xiaomi_dir
            ;;
        asusrouter)
            set_asus_dir
            ;;
        ng_snapshot)
            dir=/tmp/mnt
            ;;
        *)
            separator_line "="
            btm_box "1) 在\033[32m/etc目录\033[0m下安装（适合root用户）" \
                "2) 在\033[32m/usr/share目录\033[0m下安装（适合Linux系统）" \
                "3) 在\033[32m当前用户目录\033[0m下安装（适合非root用户）" \
                "4) 在\033[32m外置存储\033[0m中安装" \
                "5) 手动设置安装目录" \
                "" \
                "0) 退出安装"
            read -r -p "请输入相应数字> " num
            # 设置目录
            case "$num" in
            1)
                dir=/etc
                ;;
            2)
                dir=/usr/share
                ;;
            3)
                dir=~/.local/share
                mkdir -p ~/.config/systemd/user
                ;;
            4)
                set_usb_dir
                ;;
            5)
                set_cust_dir
                ;;
            *)
                msg_alert "安装已取消"
                line_break
                exit 1
                ;;
            esac
            ;;
        esac

        if [ ! -w "$dir" ]; then
            msg_alert "\033[31m没有$dir目录写入权限！请重新设置！\033[0m"
        else
            comp_box "目标目录\033[32m$dir\033[0m空间剩余：$(dir_avail "$dir" -h)" \
                "" \
                "是否确认安装？"
            btm_box "1) 是" \
                "0) 否"
            read -r -p "请输入相应数字> " res
            if [ "$res" = "1" ]; then
                CRASHDIR="$dir"/ShellCrash
                break
            fi
        fi
    done
}
