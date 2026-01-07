#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_4_SETBOOT_LOADED" ] && return
__IS_MODULE_4_SETBOOT_LOADED=1

allow_autostart(){
	[ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ] && /etc/init.d/shellcrash enable
	ckcmd systemctl && systemctl enable shellcrash.service >/dev/null 2>&1
	grep -q 's6' /proc/1/comm && touch /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
	rc-status -r >/dev/null 2>&1 && rc-update add shellcrash default >/dev/null 2>&1
	rm -rf "$CRASHDIR"/.dis_startup
}
disable_autostart(){
	[ -d /etc/rc.d ] && cd /etc/rc.d && rm -rf *shellcrash >/dev/null 2>&1 && cd - >/dev/null
	ckcmd systemctl && systemctl disable shellcrash.service >/dev/null 2>&1
	grep -q 's6' /proc/1/comm && rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
	rc-status -r >/dev/null 2>&1 && rc-update del shellcrash default >/dev/null 2>&1
	touch "$CRASHDIR"/.dis_startup
}

setboot() { #启动设置菜单
    [ -z "$start_old" ] && start_old=OFF
    [ -z "$start_delay" -o "$start_delay" = 0 ] && delay=未设置 || delay="${start_delay}秒"
    check_autostart && auto_set="\033[33m禁止" || auto_set="\033[32m允许"
    [ "${BINDIR}" = "$CRASHDIR" ] && mini_clash=OFF || mini_clash=ON
    [ -z "$network_check" ] && network_check=ON
    echo "-----------------------------------------------"
    echo -e "\033[30;47m欢迎使用启动设置菜单：\033[0m"
    echo "-----------------------------------------------"
    echo -e " 1 ${auto_set}\033[0mShellCrash开机启动"
    echo -e " 2 使用保守模式:	\033[36m$start_old\033[0m	————基于定时任务(每分钟检测)"
    echo -e " 3 设置自启延时:	\033[36m$delay\033[0m	————用于解决自启后服务受限"
    echo -e " 4 启用小闪存模式:	\033[36m$mini_clash\033[0m	————用于闪存空间不足的设备"
    [ "${BINDIR}" != "$CRASHDIR" ] && echo -e " 5 设置小闪存目录:	\033[36m${BINDIR}\033[0m"
    echo -e " 6 自启网络检查:	\033[36m$network_check\033[0m	————禁用则跳过自启时网络检查"
    echo "-----------------------------------------------"
    echo -e " 0 \033[0m返回上级菜单\033[0m"
    read -p "请输入对应数字 > " num
    echo "-----------------------------------------------"
    case "$num" in
    0) ;;
    1)
        if check_autostart; then
            # 禁止自启动：删除各系统的启动项
			disable_autostart
            echo -e "\033[33m已禁止ShellCrash开机启动！\033[0m"
        else
            # 允许自启动：配置各系统的启动项
			allow_autostart
            echo -e "\033[32m已设置ShellCrash开机启动！\033[0m"
        fi
        setboot
	;;
    2)
        if [ "$start_old" = "OFF" ] >/dev/null 2>&1; then
            echo -e "\033[33m改为使用保守模式启动服务！！\033[0m"
            disable_autostart
            start_old=ON
            setconfig start_old "$start_old"
            "$CRASHDIR"/start.sh stop
        else
            if grep -qE 'procd|systemd|s6' /proc/1/comm || rc-status -r >/dev/null 2>&1; then
                echo -e "\033[32m改为使用系统守护进程启动服务！！\033[0m"
                "$CRASHDIR"/start.sh cronset "ShellCrash初始化"
                start_old=OFF
                setconfig start_old "$start_old"
                "$CRASHDIR"/start.sh stop

            else
                echo -e "\033[31m当前设备不支持以其他模式启动！！\033[0m"
            fi
        fi
        sleep 1
        setboot
	;;
    3)
        echo -e "\033[33m如果你的设备启动后可以正常使用，则无需设置！！\033[0m"
        echo -e "\033[36m推荐设置为30~120秒之间，请根据设备问题自行试验\033[0m"
        read -p "请输入启动延迟时间(0~300秒) > " sec
        case "$sec" in
        [0-9] | [0-9][0-9] | [0-2][0-9][0-9] | 300)
            start_delay=$sec
            setconfig start_delay $sec
            echo -e "\033[32m设置成功！\033[0m"
    	;;
        *)
            echo -e "\033[31m输入有误，或超过300秒，请重新输入！\033[0m"
    	;;
        esac
        sleep 1
        setboot
	;;
    4)
        dir_size=$(df "$CRASHDIR" | awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' | grep Ava | awk '{print $2}')
        if [ "$mini_clash" = "OFF" ]; then
            if [ "$dir_size" -gt 20480 ]; then
                echo -e "\033[33m您的设备空间充足(>20M)，无需开启！\033[0m"
            elif [ "$start_old" != 'ON' -a "$(cat /proc/1/comm)" = "systemd" ]; then
                echo -e "\033[33m不支持systemd启动模式，请先启用保守模式！\033[0m"
            else
                [ "$BINDIR" = "$CRASHDIR" ] && BINDIR="$TMPDIR"
                echo -e "\033[32m已经启用小闪存功能！\033[0m"
                echo -e "如需更换目录，请使用【设置小闪存目录】功能\033[0m"
            fi
        else
            if [ "$dir_size" -lt 8192 ]; then
                echo -e "\033[31m您的设备剩余空间不足8M，停用后可能无法正常运行！\033[0m"
                read -p "确认停用此功能？(1/0) > " res
                [ "$res" = 1 ] && BINDIR="$CRASHDIR" && echo -e "\033[33m已经停用小闪存功能！\033[0m"
            else
                rm -rf /tmp/ShellCrash
                BINDIR="$CRASHDIR"
                echo -e "\033[33m已经停用小闪存功能！\033[0m"
            fi
        fi
        setconfig BINDIR "$BINDIR" "$CRASHDIR"/configs/command.env
        sleep 1
        setboot
	;;
    5)
        echo -e "\033[33m如设置到内存，则每次开机后都自动重新下载相关文件\033[0m"
        echo -e "\033[33m请确保安装源可用裸连，否则会导致启动失败\033[0m"
        echo " 1 使用内存(/tmp)"
        echo " 2 选择U盘目录"
        echo " 3 自定义目录"
        read -p "请输入相应数字 > " num
        case "$num" in
        1)
            BINDIR="$TMPDIR"
    	;;
        2)
            set_usb_dir() {
                echo "请选择安装目录"
                du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
                read -p "请输入相应数字 > " num
                BINDIR=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
                if [ -z "$BINDIR" ]; then
                    echo "\033[31m输入错误！请重新设置！\033[0m"
                    set_usb_dir
                fi
            }
            set_usb_dir
    	;;
        3)
            input_dir() {
                read -p "请输入自定义目录 > " BINDIR
                if [ ! -d "$BINDIR" ]; then
                    echo "\033[31m输入错误！请重新设置！\033[0m"
                    input_dir
                fi
            }
            input_dir
    	;;
        *)
            errornum
    	;;
        esac
        setconfig BINDIR "$BINDIR" "$CRASHDIR"/configs/command.env
        setboot
	;;
    6)
        echo -e "\033[33m如果你的设备启动后可以正常使用，则无需变更设置！！\033[0m"
        echo -e "\033[36m禁用时，如果使用了小闪存模式或者rule-set等在线规则，则可能会因无法联网而导致启动失败！\033[0m"
        echo -e "\033[32m启用时，会导致部分性能较差或者拨号较慢的设备可能会因查询超时导致启动失败！\033[0m"
        read -p "是否切换？(1/0) > " res
        [ "$res" = '1' ] && {
            if [ "$network_check" = "OFF" ]; then
                network_check=ON
            else
                network_check=OFF
            fi
            setconfig network_check "$network_check"
        }
        sleep 1
        setboot
	;;
    *)
        errornum
	;;
    esac

}
