#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_USERGUIDE_LOADED" ] && return
__IS_MODULE_USERGUIDE_LOADED=1

load_lang userguide

forwhat() {
    while true; do
        comp_box "\033[30;46m$UG_WELCOME\033[0m" \
            "" \
            "\033[33m$UG_CHOOSE_ENV\033[0m" \
            "\033[0m$UG_TIP_CONFIG\033[0m"

        content_line "1) \033[32m$UG_OPTION_1\033[0m"
        content_line "2) \033[36m$UG_OPTION_2\033[0m"
        [ -s "$CRASHDIR"/configs.tar.gz ] && content_line "3) \033[33m$UG_OPTION_3\033[0m"
        separator_line "="
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        "" | 1)
            # 设置运行模式
            redir_mod="Mix"
            content_line "$cputype" | grep -Eq 'linux.*mips.*' && {
                if grep -qE '^TPROXY$' /proc/net/ip_tables_targets || modprobe xt_TPROXY >/dev/null 2>&1; then
                    redir_mod="Tproxy"
                else
                    redir_mod="Redir"
                fi
            }

            [ -z "$crashcore" ] && crashcore=meta
            setconfig crashcore "$crashcore"
            setconfig redir_mod "$redir_mod"
            setconfig dns_mod mix
            setconfig firewall_area '1'
            # 默认启用绕过CN-IP
            setconfig cn_ip_route ON
            # 自动识别IPV6
            [ -n "$(ip a 2>&1 | grep -w 'inet6' | grep -E 'global' | sed 's/.*inet6.//g' | sed 's/scope.*$//g')" ] && {
                setconfig ipv6_redir ON
                setconfig ipv6_support ON
                setconfig ipv6_dns ON
                setconfig cn_ipv6_route ON
            }
            # 设置开机启动
            if [ -f /etc/rc.common ] && [ "$(cat /proc/1/comm)" = "procd" ]; then
                /etc/init.d/shellcrash enable
            fi

            ckcmd systemctl && [ "$(cat /proc/1/comm)" = "systemd" ] && systemctl enable shellcrash.service >/dev/null 2>&1
            rm -rf "$CRASHDIR"/.dis_startup
            autostart=enable
            # 检测IP转发
            if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "0" ]; then
                separator_line "-"
                content_line "\033[33m$UG_IP_FORWARD_WARN\033[0m"
                read -r -p "$COMMON_INPUT_R" res
                [ "$res" = 1 ] && {
                    content_line 'net.ipv4.ip_forward = 1' >>/etc/sysctl.conf
                    sysctl -w net.ipv4.ip_forward=1
                }
            fi
            # 禁止docker启用的net.bridge.bridge-nf-call-iptables
            sysctl -w net.bridge.bridge-nf-call-iptables=0 >/dev/null 2>&1
            sysctl -w net.bridge.bridge-nf-call-ip6tables=0 >/dev/null 2>&1
            break
            ;;
        2)
            setconfig redir_mod "Redir"
            content_line "$cputype" | grep -Eq "linux.*mips.*" && setconfig crashcore "clash"
            setconfig common_ports "OFF"
            setconfig firewall_area '2'
            break
            ;;
        3)
            tar -zxf "$CRASHDIR"/configs.tar.gz -C "$CRASHDIR"/configs
            msg_alert "\033[32m$UG_RESTORE_OK\033[0m"
            line_break
            exit 0
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 新手引导
userguide() {
    . "$CRASHDIR"/libs/check_dir_avail.sh
    forwhat

    # 检测小内存模式
    dir_size=$(dir_avail "$CRASHDIR")
    if [ "$dir_size" -lt 10240 ]; then
        comp_box "\033[33m$UG_ENABLE_LOW_MEM\033[0m"
        read -r -p "$COMMON_INPUT_R" res
        [ "$res" = 1 ] && {
            BINDIR=/tmp/ShellCrash
            sed -i "s#BINDIR=.*#BINDIR=$BINDIR" "$CRASHDIR"/configs/command.env
        }
    fi

    # 启用推荐的自动任务配置
    . "$CRASHDIR"/menus/5_task.sh && task_recom

    # 提示导入订阅或者配置文件
    if [ ! -s "$CRASHDIR"/yamls/config.yaml ] && [ ! -s "$CRASHDIR"/jsons/config.json ]; then
        comp_box "\033[0m$UG_IMPORT_CONFIG\033[0m" \
            "\033[32m$UG_CONFIG_TIP\033[0m" \
            "$UG_CONFIG_RES"
        btm_box "1) 立即导入" \
            "0) 暂不导入"
        read -r -p "$COMMON_INPUT> " res
        [ "$res" = 1 ] && inuserguide=1 && {
            . "$CRASHDIR"/menus/6_core_config.sh && set_core_config
            inuserguide=""
        }
    fi

    # 回到主界面
    msg_alert "\033[36m$UG_FINAL_TIP\033[0m"
    return 0
}
