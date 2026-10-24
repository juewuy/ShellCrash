#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_4_SETBOOT_LOADED" ] && return
__IS_MODULE_4_SETBOOT_LOADED=1

load_lang setboot

allow_autostart() {
    if [ -f /etc/rc.common ] && [ "$(cat /proc/1/comm)" = "procd" ]; then
        /etc/init.d/shellcrash enable
    fi

    ckcmd systemctl && systemctl enable shellcrash.service >/dev/null 2>&1
    grep -q 's6' /proc/1/comm && enable_s6_autostart_marks
    rc-status -r >/dev/null 2>&1 && rc-update add shellcrash default >/dev/null 2>&1
    rm -rf "$CRASHDIR"/.dis_startup
}

disable_autostart() {
    [ -d /etc/rc.d ] && cd /etc/rc.d && rm -rf *shellcrash >/dev/null 2>&1 && cd - >/dev/null
    ckcmd systemctl && systemctl disable shellcrash.service >/dev/null 2>&1
    grep -q 's6' /proc/1/comm && disable_s6_autostart_marks
    rc-status -r >/dev/null 2>&1 && rc-update del shellcrash default >/dev/null 2>&1
    touch "$CRASHDIR"/.dis_startup
}

# 启动设置菜单
setboot() {
    while true; do
        [ -z "$start_old" ] && start_old=OFF

        if [ -z "$start_delay" ] || [ "$start_delay" = 0 ]; then
            delay="$SETBOOT_NOT_SET"
        else
            delay="${start_delay}$SETBOOT_SECOND"
        fi

        check_autostart && auto_set="ON" || auto_set="OFF"
        [ "${BINDIR}" = "$CRASHDIR" ] && mini_clash=OFF || mini_clash=ON
        [ -z "$network_check" ] && network_check=ON
        comp_box "\033[30;47m$SETBOOT_TITLE\033[0m"
        content_line "1) $SETBOOT_ITEM_AUTO     \033[36m$(printf '%-4s' "$auto_set")\033[0m"
        content_line "2) $SETBOOT_ITEM_OLD   \033[36m$(printf '%-4s' "$start_old")\033[0m   $SETBOOT_ITEM_OLD_DESC"
        content_line "3) $SETBOOT_ITEM_DELAY   \033[36m$(printf '%-7s' "$delay")\033[0m $SETBOOT_ITEM_DELAY_DESC"
        content_line "4) $SETBOOT_ITEM_MINI \033[36m$(printf '%-4s' "$mini_clash")\033[0m   $SETBOOT_ITEM_MINI_DESC"
        [ "${BINDIR}" != "$CRASHDIR" ] && content_line "5) $SETBOOT_ITEM_MINI_DIR \033[36m${BINDIR}\033[0m"
        btm_box "6) $SETBOOT_ITEM_NETCHK   \033[36m$(printf '%-4s' "$network_check")\033[0m   $SETBOOT_ITEM_NETCHK_DESC" \
            "7) $SETBOOT_VIEW_LOG" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)

            if check_autostart; then
                # 禁止自启动：删除各系统的启动项
                disable_autostart
                msg_alert "\033[33m$SETBOOT_AUTO_OFF\033[0m"
            else
                # 允许自启动：配置各系统的启动项
                allow_autostart
                msg_alert "\033[32m$SETBOOT_AUTO_ON\033[0m"
            fi
            ;;
        2)
            if [ "$start_old" = "OFF" ] >/dev/null 2>&1; then
                disable_autostart
                start_old=ON
                setconfig start_old "$start_old"
                "$CRASHDIR"/start.sh stop
                msg_alert "\033[33m$SETBOOT_OLDMODE_ON\033[0m"
            else
                if grep -qE 'procd|systemd|s6' /proc/1/comm || rc-status -r >/dev/null 2>&1; then
                    "$CRASHDIR"/start.sh cronset "$SETBOOT_CRON_INIT"
                    start_old=OFF
                    setconfig start_old "$start_old"
                    "$CRASHDIR"/start.sh stop
                    msg_alert "\033[32m$SETBOOT_OLDMODE_OFF\033[0m"
                else
                    msg_alert "\033[31m$SETBOOT_MODE_UNSUPPORTED\033[0m"
                fi
            fi
            ;;
        3)
            comp_box "\033[33m$SETBOOT_DELAY_HINT1\033[0m" \
                "\033[36m$SETBOOT_DELAY_HINT2\033[0m"
            read -r -p "$SETBOOT_DELAY_INPUT> " sec
            case "$sec" in
            [0-9] | [0-9][0-9] | [0-2][0-9][0-9] | 300)
                start_delay=$sec
                setconfig start_delay "$sec"
                msg_alert "\033[32m$SETBOOT_SET_OK\033[0m"
                ;;
            *)
                msg_alert "\033[31m$SETBOOT_DELAY_INVALID\033[0m"
                ;;
            esac
            ;;
        4)
            dir_size=$(df "$CRASHDIR" | awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' | grep Ava | awk '{print $2}')
            if [ "$mini_clash" = "OFF" ]; then
                if [ "$dir_size" -gt 20480 ]; then
                    msg_alert "\033[33m$SETBOOT_MINI_NEEDED_NO\033[0m"
                elif [ "$start_old" != 'ON' ] && [ "$(cat /proc/1/comm)" = "systemd" ]; then
                    msg_alert "\033[33m$SETBOOT_SYSTEMD_WARN\033[0m"
                else
                    [ "$BINDIR" = "$CRASHDIR" ] && BINDIR="$TMPDIR"
                    msg_alert "\033[32m$SETBOOT_MINI_ENABLED\033[0m" \
                        "$SETBOOT_MINI_DIR_HINT\033[0m"
                fi
            else
                if [ "$dir_size" -lt 8192 ]; then
                    comp_box "\033[31m$SETBOOT_MINI_DISABLE_WARN\033[0m" \
                        "$SETBOOT_MINI_DISABLE_CONFIRM"
                    btm_box "1) $SETBOOT_YES" \
                        "0) $SETBOOT_NO_BACK"
                    read -r -p "$COMMON_INPUT> " res
                    if [ "$res" = 1 ]; then
                        BINDIR="$CRASHDIR"
                        msg_alert "\033[33m$SETBOOT_MINI_DISABLED\033[0m"
                    else
                        continue
                    fi
                else
                    rm -rf /tmp/ShellCrash
                    BINDIR="$CRASHDIR"
                    msg_alert "\033[33m$SETBOOT_MINI_DISABLED\033[0m"
                fi
            fi
            sed -i "s#BINDIR=.*#BINDIR=$BINDIR#" "$CRASHDIR"/configs/command.env
            sleep 1
            ;;
        5)
            while true; do
                comp_box "\033[33m$SETBOOT_BINDIR_HINT1\033[0m" \
                    "\033[33m$SETBOOT_BINDIR_HINT2\033[0m"
                btm_box "1) $SETBOOT_BINDIR_TMP" \
                    "2) $SETBOOT_BINDIR_USB" \
                    "3) $SETBOOT_BINDIR_CUSTOM" \
                    "" \
                    "0) $COMMON_BACK"
                read -r -p "$COMMON_INPUT> " num
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
                            comp_box "$SETBOOT_SELECT_INSTALL_DIR"
                            du -hL /mnt |
                                awk '{print NR") "$2"  ($SETBOOT_SPACE_USED$1")"}' |
                                while IFS= read -r line; do
                                    content_line "$line"
                                done
                            content_line ""
                            content_line "0) $COMMON_BACK"
                            separator_line "="
                            read -r -p "$COMMON_INPUT> " num
                            BINDIR=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
                            if [ "$num" = 0 ]; then
                                return 1
                            elif [ -z "$BINDIR" ]; then
                                msg_alert "\033[31m$SETBOOT_INPUT_ERROR\033[0m"
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
                            comp_box "\033[36m$SETBOOT_INPUT_CMD\033[0m" \
                                "$SETBOOT_INPUT_OR_BACK"
                            read -r -p "$SETBOOT_INPUT> " BINDIR
                            if [ "$BINDIR" = 0 ]; then
                                return 1
                            elif [ ! -d "$BINDIR" ]; then
                                msg_alert "\033[31m$SETBOOT_INPUT_ERROR\033[0m"
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
                sed -i "s#BINDIR=.*#BINDIR=$BINDIR#" "$CRASHDIR"/configs/command.env
                break
            done
            ;;
        6)
            comp_box "\033[33m$SETBOOT_NETCHK_HINT1\033[0m" \
                "\033[36m$SETBOOT_NETCHK_HINT2\033[0m" \
                "\033[32m$SETBOOT_NETCHK_HINT3\033[0m"

            if [ "$network_check" = "OFF" ]; then
                content_line "$SETBOOT_NETCHK_OFF_CONFIRM"
            else
                content_line "$SETBOOT_NETCHK_ON_CONFIRM"
            fi
            separator_line "-"
            btm_box "1) $SETBOOT_YES" \
                "0) $SETBOOT_NO_BACK"
            read -r -p "$COMMON_INPUT> " res
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
        7)
            if [ -s "$TMPDIR"/ShellCrash.log ]; then
                line_break
                echo "==========================================================="
                grep -v "$SETBOOT_TASK_WORD" "$TMPDIR"/ShellCrash.log
                echo "==========================================================="
                line_break
                exit
            else
                msg_alert "\033[31m$SETBOOT_LOG_NOT_FOUND\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
