#!/bin/sh
# Copyright (C) Juewuy

CRASHDIR=$(
    cd $(dirname $0)
    pwd
)
CFG_PATH="$CRASHDIR"/configs/ShellCrash.cfg
#加载执行目录，失败则初始化
. "$CRASHDIR"/libs/get_config.sh
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && . "$CRASHDIR"/init.sh >/dev/null 2>&1
[ ! -f "$TMPDIR" ] && mkdir -p "$TMPDIR"

#通用工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/check_autostart.sh
. "$CRASHDIR"/menus/1_start.sh
. "$CRASHDIR"/menus/running_status.sh
errornum() {
    echo "-----------------------------------------------"
    echo -e "\033[31m请输入正确的字母或数字！\033[0m"
}
checkrestart() {
    echo "-----------------------------------------------"
    echo -e "\033[32m检测到已变更的内容，请重启服务！\033[0m"
    echo "-----------------------------------------------"
    read -p "是否现在重启服务？(1/0) > " res
    [ "$res" = 1 ] && start_service
}

checkport() { #检查端口冲突
    for portx in $dns_port $mix_port $redir_port $((redir_port + 1)) $db_port; do
        if [ -n "$(netstat -ntul 2>&1 | grep ':$portx ')" ]; then
            echo "-----------------------------------------------"
            echo -e "检测到端口【$portx】被以下进程占用！内核可能无法正常启动！\033[33m"
            echo $(netstat -ntul | grep :$portx | head -n 1)
            echo -e "\033[0m-----------------------------------------------"
            echo -e "\033[36m请修改默认端口配置！\033[0m"
            . "$CRASHDIR"/menus/2_settings.sh && set_adv_config
            . "$CRASHDIR"/libs/get_config.sh
            checkport
        fi
    done
}
ckstatus() { #脚本启动前检查
    versionsh=$(cat "$CRASHDIR"/version)
    [ -n "$versionsh" ] && versionsh_l=$versionsh
    [ -z "$redir_mod" ] && redir_mod=纯净模式
    #获取本机host地址
    [ -z "$host" ] && host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    [ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'lan' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
    [ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
    [ -z "$host" ] && host='设备IP地址'
    #dashboard目录位置
    if [ -f /www/clash/index.html ]; then
        dbdir=/www/clash
        hostdir=/clash
    else
        dbdir="$CRASHDIR"/ui
        hostdir=":$db_port/ui"
    fi
    #开机自启检测
    if check_autostart; then
        auto="\033[32m已设置开机启动！\033[0m"
        auto1="\033[36m禁用\033[0mShellCrash开机启动"
    else
        auto="\033[31m未设置开机启动！\033[0m"
        auto1="\033[36m允许\033[0mShellCrash开机启动"
    fi
    #获取运行状态
    PID=$(pidof CrashCore | awk '{print $NF}')
    if [ -n "$PID" ]; then
        run="\033[32m正在运行（$redir_mod）\033[0m"
        running_status
    elif [ "$firewall_area" = 5 ] && [ -n "$(ip route list table 100)" ]; then
        run="\033[32m已设置（$redir_mod）\033[0m"
    else
        run="\033[31m没有运行（$redir_mod）\033[0m"
        #检测系统端口占用
        checkport
    fi
    corename=$(echo $crashcore | sed 's/singboxr/SingBoxR/' | sed 's/singbox/SingBox/' | sed 's/clash/Clash/' | sed 's/meta/Mihomo/')
    [ "$firewall_area" = 5 ] && corename='转发'
    [ -f "$TMPDIR"/debug.log -o -f "$CRASHDIR"/debug.log -a -n "$PID" ] && auto="\033[33m并处于debug状态！\033[0m"
    #输出状态
    echo "-----------------------------------------------"
    echo -e "\033[30;46m欢迎使用ShellCrash！\033[0m		版本：$versionsh_l"
    echo -e "$corename服务$run，$auto"
    if [ -n "$PID" ]; then
        echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
    fi
    echo -e "TG频道：\033[36;4mhttps://t.me/ShellClash\033[0m"
    echo "-----------------------------------------------"
    #检查新手引导
    if [ -z "$userguide" ]; then
        userguide=1
        setconfig userguide 1
        . "$CRASHDIR"/menus/8_tools.sh && userguide
    fi
    #检查执行权限
    [ ! -x "$CRASHDIR"/start.sh ] && chmod +x "$CRASHDIR"/start.sh
    #检查/tmp内核文件
    for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -Ev ".*(zip|7z|tar)$" | grep -iE 'CrashCore|^clash$|^clash-linux.*|^mihomo.*|^sing.*box|meta.*'); do
        echo -e "发现可用的内核文件： \033[36m/tmp/$file\033[0m "
        read -p "是否加载(会停止当前服务)？(1/0) > " res
        [ "$res" = 1 ] && {
			zip_type=$(echo "$file" | grep -oE 'tar.gz$|upx$|gz$')
			. "$CRASHDIR"/menus/9_upgrade.sh && setcoretype
			. "$CRASHDIR"/libs/core_tools.sh && core_check "/tmp/$file"
            if [ "$?" = 0 ]; then
				echo -e "\033[32m内核加载完成！\033[0m "
				switch_core
            else
                echo -e "\033[33m检测到不可用的内核文件！可能是文件受损或CPU架构不匹配！\033[0m"
                rm -rf /tmp/"$file"
                echo -e "\033[33m内核文件已移除，请认真检查后重新上传！\033[0m"       
            fi
			sleep 1
        }
        echo "-----------------------------------------------"
    done
    #检查/tmp配置文件
    for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -iE 'config.yaml$|config.yml$|config.json$'); do
        tmp_file=/tmp/$file
        echo -e "发现内核配置文件： \033[36m/tmp/$file\033[0m "
        read -p "是否加载为$crashcore的配置文件？(1/0) > " res
        [ "$res" = 1 ] && {
            if [ -n "$(echo /tmp/$file | grep -iE '.json$')" ]; then
                mv -f /tmp/$file "$CRASHDIR"/jsons/config.json
            else
                mv -f /tmp/$file "$CRASHDIR"/yamls/config.yaml
            fi
            echo -e "\033[32m配置文件加载完成！\033[0m "
            sleep 1
        }
    done
    #检查禁用配置覆写
    [ "$disoverride" = "1" ] && {
        echo -e "\033[33m你已经禁用了配置文件覆写功能，这会导致大量脚本功能无法使用！\033[0m "
        read -p "是否取消禁用？(1/0) > " res
        [ "$res" = 1 ] && unset disoverride && setconfig disoverride
        echo "-----------------------------------------------"
    }
}

#主菜单
main_menu() {
    #############################
    ckstatus
    #############################
    echo -e " 1 \033[32m启动/重启服务\033[0m"
    echo -e " 2 \033[36m功能设置\033[0m"
    echo -e " 3 \033[31m停止服务\033[0m"
    echo -e " 4 \033[33m启动设置\033[0m"
    echo -e " 5 设置\033[32m自动任务\033[0m"
    echo -e " 6 管理\033[36m配置文件\033[0m"
    echo -e " 7 \033[33m访问与控制\033[0m"
    echo -e " 8 \033[0m工具与优化\033[0m"
    echo -e " 9 \033[32m更新与支持\033[0m"
    echo "-----------------------------------------------"
    echo -e " 0 \033[0m退出脚本\033[0m"
    read -p "请输入对应数字 > " num

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
        echo -e "\033[31m$corename服务已停止！\033[0m"
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
		shtype=sh
		ckcmd bash && shtype=bash
		$shtype -x "$CRASHDIR"/menu.sh
    ;;
	-s)
		"$CRASHDIR"/start.sh "$2" "$3" "$4" "$5" "$6"
    ;;
	-i)
		. "$CRASHDIR"/init.sh 2>/dev/null
    ;;
	-st)
		shtype=sh
		ckcmd bash && shtype=bash
		"$shtype" -x "$CRASHDIR"/starts/bfstart.sh
		. "$CRASHDIR"/starts/start_legacy.sh
		start_legacy "$COMMAND" 'shellcrash'
		"$shtype" -x "$CRASHDIR"/starts/afstart.sh
		"$CRASHDIR"/start.sh stop
    ;;
	-d)
		shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
		echo -e "正在测试运行！如发现错误请截图后前往\033[32;4mt.me/ShellClash\033[0m咨询"
		$shtype "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh_bug.log
		$shtype -x "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh.log
		echo -----------------------------------------
		cat "$TMPDIR"/debug_sh_bug.log | grep 'start\.sh' >"$TMPDIR"/sh_bug
		if [ -s "$TMPDIR"/sh_bug ]; then
			while read line; do
				echo -e "发现错误：\033[33;4m$line\033[0m"
				grep -A 1 -B 3 "$line" "$TMPDIR"/debug_sh.log
				echo -----------------------------------------
			done <"$TMPDIR"/sh_bug
			rm -rf "$TMPDIR"/sh_bug
			echo -e "\033[32m测试完成！\033[0m完整执行记录请查看：\033[36m$TMPDIR/debug_sh.log\033[0m"
		else
			echo -e "\033[32m测试完成！没有发现问题，请重新启动服务~\033[0m"
			rm -rf "$TMPDIR"/debug_sh.log
		fi
		"$CRASHDIR"/start.sh stop
    ;;
	-u)
		. "$CRASHDIR"/menus/uninstall.sh && uninstall
    ;;
	*)
		echo -----------------------------------------
		echo "欢迎使用ShellCrash"
		echo -----------------------------------------
		echo " -t 测试模式"
		echo " -h 帮助列表"
		echo " -u 卸载脚本"
		echo " -i 初始化脚本"
		echo " -d 测试运行"
		echo -----------------------------------------
		echo " crash -s start	启动服务"
		echo " crash -s stop	停止服务"
		echo " $CRASHDIR/start.sh init	开机初始化"
		echo -----------------------------------------
		echo "在线求助：t.me/ShellClash"
		echo "官方博客：juewuy.github.io"
		echo "发布页面：github.com/juewuy/ShellCrash"
		echo -----------------------------------------
    ;;
esac
