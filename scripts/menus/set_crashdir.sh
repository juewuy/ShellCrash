#!/bin/sh
# Copyright (C) Juewuy

. /tmp/SC_tmp/libs/check_dir_avail.sh

set_crashdir() {
    set_usb_dir() {
        echo -e "请选择安装目录"
        du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
        read -p "请输入相应数字 > " num
        dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
        if [ -z "$dir" ]; then
            echo -e "\033[31m输入错误！请重新设置！\033[0m"
            set_usb_dir
        fi
    }
    set_asus_dir() {
        echo -e "请选择U盘目录"
        du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print " "NR" "$2"  "$1}'
        read -p "请输入相应数字 > " num
        dir=$(du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print $2}' | sed -n "$num"p)
        if [ ! -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ]; then
            echo -e "\033[31m未找到下载大师自启文件：$dir/asusware.arm/etc/init.d/S50downloadmaster，请检查设置！\033[0m"
            set_asus_dir
        fi
    }
    set_cust_dir() {
        echo "-----------------------------------------------"
        echo "可用路径 剩余空间:"
        df -h | awk '{print $6,$4}' | sed 1d
        echo "路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！！！"
        read -p "请输入自定义路径 > " dir
        if [ "$(dir_avail $dir)" = 0 ] || [ -n "$(echo $dir | grep -E 'tmp|opt|sys')" ]; then
            echo "\033[31m路径错误！请重新设置！\033[0m"
            set_cust_dir
        fi
    }
    echo "-----------------------------------------------"
    if [ -n "$systype" ]; then
        [ "$systype" = "Padavan" ] && dir=/etc/storage
        [ "$systype" = "mi_snapshot" ] && {
            echo -e "\033[33m检测到当前设备为小米官方系统，请选择安装位置\033[0m"
            [ -d /data ] && $echo " 1 安装到 /data 目录,剩余空间：$(dir_avail /data -h)(支持软固化功能)"
            [ -d /userdisk ] && $echo " 2 安装到 /userdisk 目录,剩余空间：$(dir_avail /userdisk -h)(支持软固化功能)"
            [ -d /data/other_vol ] && $echo " 3 安装到 /data/other_vol 目录,剩余空间：$(dir_avail /data/other_vol -h)(支持软固化功能)"
            $echo " 4 安装到自定义目录(不推荐，不明勿用！)"
            echo " 0 退出安装"
            echo "-----------------------------------------------"
            read -p "请输入相应数字 > " num
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
                exit 1
                ;;
            esac
        }
        [ "$systype" = "asusrouter" ] && {
            echo -e "\033[33m检测到当前设备为华硕固件，请选择安装方式\033[0m"
            echo -e " 1 基于USB设备安装(限23年9月之前固件，须插入\033[31m任意\033[0mUSB设备)"
            echo -e " 2 基于自启脚本安装(仅支持梅林及部分非koolshare官改固件)"
            echo -e " 3 基于U盘+下载大师安装(支持所有固件，限ARM设备，须插入U盘或移动硬盘)"
            echo -e " 0 退出安装"
            echo "-----------------------------------------------"
            read -p "请输入相应数字 > " num
            case "$num" in
            1)
                read -p "将脚本安装到USB存储/系统闪存？(1/0) > " res
                [ "$res" = "1" ] && set_usb_dir || dir=/jffs
                usb_status=1
                ;;
            2)
                echo -e "如无法正常开机启动，请重新使用USB方式安装！"
                sleep 2
                dir=/jffs
                ;;
            3)
                echo -e "请先在路由器网页后台安装下载大师并启用，之后选择外置存储所在目录！"
                sleep 2
                set_asus_dir
                ;;
            *)
                exit 1
                ;;
            esac
        }
        [ "$systype" = "ng_snapshot" ] && dir=/tmp/mnt
    else
        echo -e "\033[33m安装ShellCrash至少需要预留约1MB的磁盘空间\033[0m"
        echo -e " 1 在\033[32m/etc目录\033[0m下安装(适合root用户)"
        echo -e " 2 在\033[32m/usr/share目录\033[0m下安装(适合Linux系统)"
        echo -e " 3 在\033[32m当前用户目录\033[0m下安装(适合非root用户)"
        echo -e " 4 在\033[32m外置存储\033[0m中安装"
        echo -e " 5 手动设置安装目录"
        echo -e " 0 退出安装"
        echo "-----------------------------------------------"
        read -p "请输入相应数字 > " num
        #设置目录
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
            echo "-----------------------------------------------"
            echo "可用路径 剩余空间:"
            df -h | awk '{print $6,$4}' | sed 1d
            echo "路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！！！"
            read -p "请输入自定义路径 > " dir
            if [ -z "$dir" ]; then
                echo -e "\033[31m路径错误！请重新设置！\033[0m"
                setdir
            fi
            ;;
        *)
            echo "安装已取消"
            exit 1
            ;;
        esac
    fi

    if [ ! -w $dir ]; then
        echo -e "\033[31m没有$dir目录写入权限！请重新设置！\033[0m" && sleep 1 && setdir
    else
        echo -e "目标目录\033[32m$dir\033[0m空间剩余：$(dir_avail $dir -h)"
        read -p "确认安装？(1/0) > " res
        [ "$res" = "1" ] && CRASHDIR=$dir/ShellCrash || setdir
    fi
}

