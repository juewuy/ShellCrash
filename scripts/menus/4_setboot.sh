#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_4_SETBOOT_LOADED" ] && return
__IS_MODULE_4_SETBOOT_LOADED=1

allow_autostart() {
    if [ -f /etc/rc.common ] && [ "$(cat /proc/1/comm)" = "procd" ]; then
        /etc/init.d/shellcrash enable
    fi

    ckcmd systemctl && systemctl enable shellcrash.service >/dev/null 2>&1
    grep -q 's6' /proc/1/comm && touch /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
    rc-status -r >/dev/null 2>&1 && rc-update add shellcrash default >/dev/null 2>&1
    rm -rf "$CRASHDIR"/.dis_startup
}

disable_autostart() {
    [ -d /etc/rc.d ] && cd /etc/rc.d && rm -rf *shellcrash >/dev/null 2>&1 && cd - >/dev/null
    ckcmd systemctl && systemctl disable shellcrash.service >/dev/null 2>&1
    grep -q 's6' /proc/1/comm && rm -rf /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
    rc-status -r >/dev/null 2>&1 && rc-update del shellcrash default >/dev/null 2>&1
    touch "$CRASHDIR"/.dis_startup
}

# 启动设置菜单
setboot() {
    while true; do
        [ -z "$start_old" ] && start_old=OFF

        if [ -z "$start_delay" ] || [ "$start_delay" = 0 ]; then
            delay=未设置
        else
            delay="${start_delay}秒"
        fi

        check_autostart && auto_set="ON" || auto_set="OFF"
        [ "${BINDIR}" = "$CRASHDIR" ] && mini_clash=OFF || mini_clash=ON
        [ -z "$network_check" ] && network_check=ON
        comp_box "\033[30;47m启动设置菜单\033[0m"
        content_line "1) 开机自启动：     \033[36m$(printf '%-4s' "$auto_set")\033[0m"
        content_line "2) 使用保守模式：   \033[36m$(printf '%-4s' "$start_old")\033[0m   ———基于定时任务(每分钟检测)"
        content_line "3) 设置自启延时：   \033[36m$(printf '%-7s' "$delay")\033[0m ———用于解决自启后服务受限"
        content_line "4) 启用小闪存模式： \033[36m$(printf '%-4s' "$mini_clash")\033[0m   ———用于闪存空间不足的设备"
        [ "${BINDIR}" != "$CRASHDIR" ] && content_line "5) 设置小闪存目录： \033[36m${BINDIR}\033[0m"
        btm_box "6) 自启网络检查：   \033[36m$(printf '%-4s' "$network_check")\033[0m   ———禁用则跳过自启时网络检查" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)

            if check_autostart; then
                # 禁止自启动：删除各系统的启动项
                disable_autostart
                msg_alert "\033[33m已禁止ShellCrash开机自启动！\033[0m"
            else
                # 允许自启动：配置各系统的启动项
                allow_autostart
                msg_alert "\033[32m已设置ShellCrash开机自启动！\033[0m"
            fi
            ;;
        2)
            if [ "$start_old" = "OFF" ] >/dev/null 2>&1; then
                disable_autostart
                start_old=ON
                setconfig start_old "$start_old"
                "$CRASHDIR"/start.sh stop
                msg_alert "\033[33m改为使用保守模式启动服务！\033[0m"
            else
                if grep -qE 'procd|systemd|s6' /proc/1/comm || rc-status -r >/dev/null 2>&1; then
                    "$CRASHDIR"/start.sh cronset "ShellCrash初始化"
                    start_old=OFF
                    setconfig start_old "$start_old"
                    "$CRASHDIR"/start.sh stop
                    msg_alert "\033[32m改为使用系统守护进程启动服务！\033[0m"
                else
                    msg_alert "\033[31m当前设备不支持以其他模式启动！\033[0m"
                fi
            fi
            ;;
        3)
            comp_box "\033[33m如果你的设备启动后可以正常使用，则无需设置！\033[0m" \
                "\033[36m推荐设置为30～120秒之间，请根据设备问题自行试验\033[0m"
            read -r -p "请输入启动延迟时间（0～300秒）> " sec
            case "$sec" in
            [0-9] | [0-9][0-9] | [0-2][0-9][0-9] | 300)
                start_delay=$sec
                setconfig start_delay "$sec"
                msg_alert "\033[32m设置成功！\033[0m"
                ;;
            *)
                msg_alert "\033[31m输入有误，或超过300秒，请重新输入！\033[0m"
                ;;
            esac
            ;;
        4)
            dir_size=$(df "$CRASHDIR" | awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' | grep Ava | awk '{print $2}')
            if [ "$mini_clash" = "OFF" ]; then
                if [ "$dir_size" -gt 20480 ]; then
                    msg_alert "\033[33m您的设备空间充足（>20M），无需开启！\033[0m"
                elif [ "$start_old" != 'ON' ] && [ "$(cat /proc/1/comm)" = "systemd" ]; then
                    msg_alert "\033[33m不支持systemd启动模式，请先启用保守模式！\033[0m"
                else
                    [ "$BINDIR" = "$CRASHDIR" ] && BINDIR="$TMPDIR"
                    msg_alert "\033[32m已经启用小闪存功能！\033[0m" \
                        "如需更换目录，请使用【设置小闪存目录】功能\033[0m"
                fi
            else
                if [ "$dir_size" -lt 8192 ]; then
                    comp_box "\033[31m您的设备剩余空间不足8M，停用后可能无法正常运行！\033[0m" \
                        "是否确认停用此功能？"
                    btm_box "1) 是" \
                        "0) 否，返回上级菜单"
                    read -r -p "请输入对应标号> " res
                    if [ "$res" = 1 ]; then
                        BINDIR="$CRASHDIR"
                        msg_alert "\033[33m已经停用小闪存功能！\033[0m"
                    else
                        continue
                    fi
                else
                    rm -rf /tmp/ShellCrash
                    BINDIR="$CRASHDIR"
                    msg_alert "\033[33m已经停用小闪存功能！\033[0m"
                fi
            fi
            setconfig BINDIR "$BINDIR" "$CRASHDIR"/configs/command.env
            sleep 1
            ;;
        5)
            while true; do
                comp_box "\033[33m如设置到内存，则每次开机后都自动重新下载相关文件\033[0m" \
                    "\033[33m请确保安装源可用裸连，否则会导致启动失败\033[0m"
                btm_box "1) 使用内存（/tmp）" \
                    "2) 选择U盘目录" \
                    "3) 自定义目录" \
                    "" \
                    "0) 返回上级菜单"
                read -r -p "请输入对应标号> " num
                case "$num" in
                "" | 0)
                    break
                    ;;
                1)
                    BINDIR="$TMPDIR"
                    ;;
                2)
                    set_usb_dir() {
                        while true; do
                            comp_box "请选择安装目录："
                            du -hL /mnt |
                                awk '{print NR") "$2"  （已占用的储存空间："$1"）"}' |
                                while IFS= read -r line; do
                                    content_line "$line"
                                done
                            content_line ""
                            content_line "0) 返回上级菜单"
                            separator_line "="
                            read -r -p "请输入对应标号> " num
                            BINDIR=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
                            if [ "$num" = 0 ]; then
                                return 1
                            elif [ -z "$BINDIR" ]; then
                                msg_alert "\033[31m输入错误！请重新设置！\033[0m"
                            else
                                return 0
                            fi
                        done
                    }
                    set_usb_dir
                    if [ $? -eq 1 ]; then
                        continue
                    fi
                    ;;
                3)
                    input_dir() {
                        while true; do
                            comp_box "\033[36m请直接输入命令语句\033[0m" \
                                "或输入 0 返回上级菜单"
                            read -r -p "请输入> " BINDIR
                            if [ "$BINDIR" = 0 ]; then
                                return 1
                            elif [ ! -d "$BINDIR" ]; then
                                msg_alert "\033[31m输入错误！请重新设置！\033[0m"
                            fi
                            return 0
                        done
                    }
                    input_dir
                    if [ $? -eq 1 ]; then
                        continue
                    fi
                    ;;
                *)
                    errornum
                    continue
                    ;;
                esac
                setconfig BINDIR "$BINDIR" "$CRASHDIR"/configs/command.env
                break
            done
            ;;
        6)
            comp_box "\033[33m如果你的设备启动后可以正常使用，则无需变更设置！\033[0m" \
                "\033[36m禁用时，如果使用了小闪存模式或者rule-set等在线规则，则可能会因无法联网而导致启动失败！\033[0m" \
                "\033[32m启用时，会导致部分性能较差或者拨号较慢的设备可能会因查询超时导致启动失败！\033[0m"

            if [ "$network_check" = "OFF" ]; then
                content_line "当前\033[33m已禁用\033[0m自启网络检查，是否确认启用？"
            else
                content_line "当前\033[33m已启用\033[0m自启网络检查，是否确认禁用？"
            fi
            separator_line "-"
            btm_box "1) 是" \
                "0) 否，返回上级菜单"
            read -r -p "请输入对应标号> " res
            if [ "$res" = '1' ]; then
                if [ "$network_check" = "OFF" ]; then
                    network_check=ON
                else
                    network_check=OFF
                fi
                if setconfig network_check "$network_check"; then
                    common_success
                else
                    common_failed
                fi
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
