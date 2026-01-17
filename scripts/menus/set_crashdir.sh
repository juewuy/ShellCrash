#!/bin/sh
# Copyright (C) Juewuy

#. /tmp/SC_tmp/libs/check_dir_avail.sh

cecho() {
    printf '%b\n' "$*"
}
set_usb_dir() {
    while true; do
        cecho "请选择安装目录"
        du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
        read -p "请输入相应数字 > " num
        dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
        if [ -z "$dir" ]; then
            cecho "\033[31m输入错误！请重新设置！\033[0m"
            continue
        fi
        break 1
    done
}
set_xiaomi_dir() {
	cecho "\033[33m检测到当前设备为小米官方系统，请选择安装位置\033[0m"
	[ -d /data ] && cecho " 1 安装到 /data 目录,剩余空间：$(dir_avail /data -h)(支持软固化功能)"
	[ -d /userdisk ] && cecho " 2 安装到 /userdisk 目录,剩余空间：$(dir_avail /userdisk -h)(支持软固化功能)"
	[ -d /data/other_vol ] && cecho " 3 安装到 /data/other_vol 目录,剩余空间：$(dir_avail /data/other_vol -h)(支持软固化功能)"
	cecho " 4 安装到自定义目录(不推荐，不明勿用！)"
	cecho " 0 退出安装"
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
set_asus_usb() {
	while true; do
		echo -e "请选择U盘目录"
		du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print " "NR" "$2"  "$1}'
		read -p "请输入相应数字 > " num
		dir=$(du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print $2}' | sed -n "$num"p)
		if [ ! -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ]; then
			echo -e "\033[31m未找到下载大师自启文件：$dir/asusware.arm/etc/init.d/S50downloadmaster，请检查设置！\033[0m"
			sleep 1
		else
			break
		fi
	done
}
set_asus_dir() {
	cecho "\033[33m检测到当前设备为华硕固件，请选择安装方式\033[0m"
	cecho " 1 基于U盘+下载大师安装(支持所有固件，限ARM设备，须插入U盘或移动硬盘)"
	cecho " 2 基于自启脚本安装(仅支持部分梅林固件)"
	cecho " 0 退出安装"
	echo "-----------------------------------------------"
	read -p "请输入相应数字 > " num
	case "$num" in
	1)
		echo -e "请先在路由器网页后台安装下载大师并启用，之后选择外置存储所在目录！"
		sleep 2
		set_asus_usb
	;;
	2)
		cecho "如开机无法正常自启，请重新使用U盘+下载大师安装！"
		sleep 2
		dir=/jffs
	;;
	*)
		exit 1
	;;
	esac
}
set_cust_dir() {
    while true; do
        echo "-----------------------------------------------"
        echo '可用路径 剩余空间：'
        df -h | awk '{print $6,$4}' | sed 1d
        echo '路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！！！'
        read -p "请输入自定义路径 > " dir
        if [ "$(dir_avail "$dir")" = 0 ] || [ -n "$(echo "$dir" | grep -Eq '^/(tmp|opt|sys)(/|$)')" ]; then
            cecho "\033[31m路径错误！请重新设置！\033[0m"
            continue
        fi
        break 1
    done
}

set_crashdir() {
    while true; do
        echo "-----------------------------------------------"
        cecho "\033[33m注意：安装ShellCrash至少需要预留约1MB的磁盘空间\033[0m"
        case "$systype" in
			Padavan) dir=/etc/storage ;;
			mi_snapshot) set_xiaomi_dir ;;
			asusrouter) set_asus_dir ;;
			ng_snapshot) dir=/tmp/mnt ;;
			*)
				cecho " 1 在\033[32m/etc目录\033[0m下安装(适合root用户)"
				cecho " 2 在\033[32m/usr/share目录\033[0m下安装(适合Linux系统)"
				cecho " 3 在\033[32m当前用户目录\033[0m下安装(适合非root用户)"
				cecho " 4 在\033[32m外置存储\033[0m中安装"
				cecho " 5 手动设置安装目录"
				cecho " 0 退出安装"
				echo "----------------------------------------------"
				read -p "请输入相应数字 > " num
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
					echo "安装已取消"
					exit 1
					;;
				esac
			;;
		esac

        if [ ! -w "$dir" ]; then
            cecho "\033[31m没有$dir目录写入权限！请重新设置！\033[0m"
            sleep 1
        else
            cecho "目标目录\033[32m$dir\033[0m空间剩余：$(dir_avail "$dir" -h)"
            read -p "确认安装？(1/0) > " res
            if [ "$res" = "1" ]; then
                CRASHDIR="$dir"/ShellCrash
                break
            fi
        fi
    done
}
