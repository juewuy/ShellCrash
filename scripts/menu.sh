#!/bin/sh
# Copyright (C) Juewuy

CRASHDIR=$(
    cd $(dirname $0)
    pwd
)
CFG_PATH="$CRASHDIR"/configs/ShellCrash.cfg

# 加载执行目录，失败则初始化
. "$CRASHDIR"/libs/get_config.sh
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && . "$CRASHDIR"/init.sh >/dev/null 2>&1
[ ! -f "$TMPDIR" ] && mkdir -p "$TMPDIR"

# 通用工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/check_autostart.sh
. "$CRASHDIR"/libs/i18n.sh
. "$CRASHDIR"/menus/1_start.sh
. "$CRASHDIR"/menus/running_status.sh

# 加载语言
load_lang common
load_lang menu

errornum() {
    echo "-----------------------------------------------"
    echo -e "\033[31m$MENU_ERR_INPUT\033[0m"
}

checkrestart() {
    echo "-----------------------------------------------"
    echo -e "\033[32m$MENU_RESTART_NOTICE\033[0m"
    echo "-----------------------------------------------"
    read -p "$MENU_RESTART_ASK" res
    [ "$res" = 1 ] && start_service
}

checkport() { #检查端口冲突
    for portx in $dns_port $mix_port $redir_port $((redir_port + 1)) $db_port; do
        if [ -n "$(netstat -ntul 2>&1 | grep ":$portx ")" ]; then
            echo "-----------------------------------------------"
            echo -e "【$portx】: $MENU_PORT_CONFLICT_TITLE"
            echo -e "\033[0m$(netstat -ntul | grep ":$portx" | head -n 1)\033[0m"
            echo "-----------------------------------------------"
            echo -e "\033[36m$MENU_PORT_CONFLICT_HINT\033[0m"
            . "$CRASHDIR"/menus/2_settings.sh && set_adv_config
            . "$CRASHDIR"/libs/get_config.sh
            checkport
        fi
    done
}
ckstatus() { #脚本启动前检查
    #检查脚本配置文件
    if [ -f "$CFG_PATH" ]; then
        [ -n "$(awk 'a[$0]++' "$CFG_PATH")" ] && awk '!a[$0]++' "$CFG_PATH" >"$CFG_PATH"
    else
        . "$CRASHDIR"/init.sh >/dev/null 2>&1
    fi

    versionsh=$(cat "$CRASHDIR"/version)
    [ -n "$versionsh" ] && versionsh_l=$versionsh
    [ -z "$redir_mod" ] && redir_mod="纯净模式"
    #获取本机host地址
    [ -z "$host" ] && host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    [ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'lan' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
    [ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
    [ -z "$host" ] && host='$MENU_IP_DF'
    #dashboard目录位置
    if [ -f /www/clash/index.html ]; then
        dbdir=/www/clash
        hostdir=/clash
    else
        dbdir="$CRASHDIR"/ui
        hostdir=":$db_port/ui"
    fi

    if check_autostart; then
        auto="\033[32m$MENU_AUTOSTART_ON\033[0m"
    else
        auto="\033[31m$MENU_AUTOSTART_OFF\033[0m"
    fi

    PID=$(pidof CrashCore | awk '{print $NF}')
    if [ -n "$PID" ]; then
        run="\033[32m$MENU_RUN_ON（$redir_mod）\033[0m"
        running_status
    elif [ "$firewall_area" = 5 ] && [ -n "$(ip route list table 100)" ]; then
        run="\033[32m$MENU_RUN_SET（$redir_mod）\033[0m"
    else
        run="\033[31m$MENU_RUN_OFF（$redir_mod）\033[0m"
        #检测系统端口占用
        checkport
    fi
    corename=$(echo $crashcore | sed 's/singboxr/SingBoxR/' | sed 's/singbox/SingBox/' | sed 's/clash/Clash/' | sed 's/meta/Mihomo/')
    #[ "$firewall_area" = 5 ] && corename='转发'
    [ -f "$TMPDIR"/debug.log -o -f "$CRASHDIR"/debug.log -a -n "$PID" ] && auto="\033[33m$MENU_AUTOSTART_DEBUG\033[0m"
    #输出状态
    echo "-----------------------------------------------"
    echo -e "\033[30;46m$MENU_WELCOME\033[0m		$MENU_VERSION_LABEL$versionsh_l"
    echo -e "$corename $run，$auto"

    if [ -n "$PID" ]; then
        echo -e "$MENU_MEM_USED \033[44m$VmRSS\033[0m，$MENU_RUNNING_TIME \033[46;30m$day\033[44;37m$time\033[0m"
    fi

    echo -e "$MENU_TG_CHANNEL \033[36;4m$MENU_TG_URL\033[0m"
    echo "-----------------------------------------------"
    #检查新手引导
    if [ -z "$userguide" ]; then
		. "$CRASHDIR"/menus/userguide.sh && userguide
        setconfig userguide 1
    fi
    #检查执行权限
    [ ! -x "$CRASHDIR"/start.sh ] && chmod +x "$CRASHDIR"/start.sh
    #检查/tmp内核文件
    for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -Ev ".*(zip|7z|tar)$" | grep -iE 'CrashCore|^clash$|^clash-linux.*|^mihomo.*|^sing.*box|meta.*'); do
        echo -e "$MENU_TMP_CORE_FOUND \033[36m/tmp/$file\033[0m "
        read -p "$MENU_TMP_CORE_ASK(1/0) > " res
        [ "$res" = 1 ] && {
			zip_type=$(echo "$file" | grep -oE 'tar.gz$|upx$|gz$')
			. "$CRASHDIR"/menus/9_upgrade.sh && setcoretype
			. "$CRASHDIR"/libs/core_tools.sh && core_check "/tmp/$file"
            if [ "$?" = 0 ]; then
				echo -e "\033[32m$MENU_CORE_LOADED_OK\033[0m "
				switch_core
            else
                echo -e "\033[33m$MENU_CORE_LOADED_BAD033[0m"
                rm -rf /tmp/"$file"
                echo -e "\033[33m$MENU_CORE_REMOVED\033[0m"       
            fi
			sleep 1
        }
        echo "-----------------------------------------------"
    done
    #检查/tmp配置文件
    for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -iE 'config.yaml$|config.yml$|config.json$'); do
        tmp_file=/tmp/$file
        echo -e "$MENU_TMP_CFG_FOUND \033[36m/tmp/$file\033[0m "
        read -p "$MENU_TMP_CFG_ASK(1/0) > " res
        [ "$res" = 1 ] && {
            if [ -n "$(echo /tmp/$file | grep -iE '.json$')" ]; then
                mv -f /tmp/$file "$CRASHDIR"/jsons/config.json
            else
                mv -f /tmp/$file "$CRASHDIR"/yamls/config.yaml
            fi
            echo -e "\033[32m$MENU_CFG_LOADED_OK\033[0m "
            sleep 1
        }
    done
    #检查禁用配置覆写
    [ "$disoverride" = "1" ] && {
        echo -e "\033[33m$MENU_OVERRIDE_WARN\033[0m "
        read -p "$MENU_OVERRIDE_ASK(1/0) > " res
        [ "$res" = 1 ] && unset disoverride && setconfig disoverride
        echo "-----------------------------------------------"
    }
}

main_menu() {
    ckstatus

    echo -e " 1 \033[32m$MENU_MAIN_1\033[0m"
    echo -e " 2 \033[36m$MENU_MAIN_2\033[0m"
    echo -e " 3 \033[31m$MENU_MAIN_3\033[0m"
    echo -e " 4 \033[33m$MENU_MAIN_4\033[0m"
    echo -e " 5 \033[32m$MENU_MAIN_5\033[0m"
    echo -e " 6 \033[36m$MENU_MAIN_6\033[0m"
    echo -e " 7 \033[33m$MENU_MAIN_7\033[0m"
    echo -e " 8 $MENU_MAIN_8"
    echo -e " 9 \033[32m$MENU_MAIN_9\033[0m"
    echo "-----------------------------------------------"
    echo -e " 0 $MENU_MAIN_0"

    read -p "$MENU_MAIN_PROMPT" num

    case "$num" in
    0)
        exit
	;;
    1)
        start_service
        exit
	;;
    2)
        checkcfg=$(cat "$CFG_PATH")
        . "$CRASHDIR"/menus/2_settings.sh && settings
        if [ -n "$PID" ]; then
            checkcfg_new=$(cat "$CFG_PATH")
            [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
        fi
        main_menu
	;;
    3)
        [ "$bot_tg_service" = ON ] && . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_stop
		"$CRASHDIR"/start.sh stop
        sleep 1
        echo "-----------------------------------------------"
        echo -e "\033[31m$corename$MENU_SERVICE_STOPPED\033[0m"
        main_menu
	;;
    4)
        . "$CRASHDIR"/menus/4_setboot.sh && setboot
        main_menu
	;;
    5)
        . "$CRASHDIR"/menus/5_task.sh && task_menu
        main_menu
	;;
    6)
        . "$CRASHDIR"/menus/6_core_config.sh && set_core_config
        main_menu
	;;
    7)
		GT_CFG_PATH="$CRASHDIR"/configs/gateway.cfg
		touch "$GT_CFG_PATH"
        checkcfg=$(cat "$CFG_PATH" "$GT_CFG_PATH")
        . "$CRASHDIR"/menus/7_gateway.sh && gateway
        if [ -n "$PID" ]; then
            checkcfg_new=$(cat "$CFG_PATH" "$GT_CFG_PATH")
            [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
        fi
        main_menu
	;;
    8)
        . "$CRASHDIR"/menus/8_tools.sh && tools
        main_menu
	;;
    9)
        checkcfg=$(cat "$CFG_PATH")
        . "$CRASHDIR"/menus/9_upgrade.sh && upgrade
        if [ -n "$PID" ]; then
            checkcfg_new=$(cat "$CFG_PATH")
            [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
        fi
        main_menu
	;;
    *)
        errornum
        exit
	;;
    esac
}

case "$1" in
	"")
		main_menu
    ;;
	-t)
		shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
		$shtype -x "$CRASHDIR"/menu.sh
    ;;
	-s)
		"$CRASHDIR"/start.sh $2 $3 $4 $5 $6
    ;;
	-i)
		. "$CRASHDIR"/init.sh 2>/dev/null
    ;;
	-st)
		shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
		$shtype -x "$CRASHDIR"/start.sh $2 $3 $4 $5 $6
    ;;
	-d)
		shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
		echo -e "$MENU_TEST_RUNNING\033[32;4mt.me/ShellClash\033[0m"
		$shtype "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh_bug.log
		$shtype -x "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh.log
		echo -----------------------------------------
		cat "$TMPDIR"/debug_sh_bug.log | grep 'start\.sh' >"$TMPDIR"/sh_bug
		if [ -s "$TMPDIR"/sh_bug ]; then
			while read line; do
				echo -e "$MENU_ERROR_FOUND\033[33;4m$line\033[0m"
				grep -A 1 -B 3 "$line" "$TMPDIR"/debug_sh.log
				echo -----------------------------------------
			done <"$TMPDIR"/sh_bug
			rm -rf "$TMPDIR"/sh_bug
			echo -e "\033[32m$MENU_TEST_DONE_FAIL\033[0m$MENU_TEST_LOG_HINT\033[36m$TMPDIR/debug_sh.log\033[0m"
		else
			echo -e "\033[32m$MENU_TEST_DONE_OK\033[0m"
			rm -rf "$TMPDIR"/debug_sh.log
		fi
		"$CRASHDIR"/start.sh stop
    ;;
	-u)
		. "$CRASHDIR"/menus/uninstall.sh && uninstall
    ;;
	*)
		echo -----------------------------------------
		echo "$MENU_CLI_WELCOME"
		echo -----------------------------------------
		echo " -t $MENU_CLI_TEST"
		echo " -h $MENU_CLI_HELP"
		echo " -u $MENU_CLI_UNINSTALL"
		echo " -i $MENU_CLI_INIT"
		echo " -d $MENU_CLI_DEBUG"
		echo -----------------------------------------
		echo " crash -s start	$MENU_CLI_START"
		echo " crash -s stop	$MENU_CLI_STOP"
		echo " $CRASHDIR/start.sh init	$MENU_CLI_BOOT_INIT"
		echo -----------------------------------------
		echo "$MENU_HELP_ONLINE t.me/ShellClash"
		echo "$MENU_HELP_BLOG juewuy.github.io"
		echo "$MENU_HELP_GITHUB github.com/juewuy/ShellCrash"
		echo -----------------------------------------
    ;;
esac
