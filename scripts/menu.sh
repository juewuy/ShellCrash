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
. "$CRASHDIR"/menus/common.sh
. "$CRASHDIR"/menus/1_start.sh
. "$CRASHDIR"/menus/running_status.sh

# 加载Tui界面
[ -z "$tui_type" ] && tui_type='tui_layout'
[ "$1" = '-l' ] && tui_type='tui_lite'
. "$CRASHDIR"/menus/"$tui_type".sh

# 加载语言
load_lang common
load_lang menu

checkrestart() {
	comp_box "\033[32m$MENU_RESTART_NOTICE\033[0m"
	btm_box "1) 立即重启" \
		"0) 暂不重启"
	read -r -p "$COMMON_INPUT> " res
	if [ "$res" = 1 ]; then
		start_service
	fi
}

# 检查端口冲突
checkport() {
	while true; do
		# Before each round of checks begins, execute netstat only once and cache the results
		# Avoid calling the system command once for each port
		current_listening=$(netstat -ntul 2>&1)

		conflict_found=0

		for portx in $dns_port $mix_port $redir_port $((redir_port + 1)) $db_port; do
			# Use `grep` to search within the cached variables instead of re-running `netstat`
			conflict_line=$(echo "$current_listening" | grep ":$portx ")

			if [ -n "$conflict_line" ]; then

				comp_box "【$portx】：$MENU_PORT_CONFLICT_TITLE" \
					"\033[0m$(echo "$conflict_line" | head -n 1)\033[0m" \
					"\033[36m$MENU_PORT_CONFLICT_HINT\033[0m"

				. "$CRASHDIR"/menus/2_settings.sh && set_adv_config
				. "$CRASHDIR"/libs/get_config.sh

				# Mark conflict and exit the for loop, triggering the while loop to restart the check
				# This replaces the original recursive call to `checkport`
				conflict_found=1
				break
			fi
		done

		# If no conflicts are found after the entire for loop completes,
		# the while loop exits and the function terminates.
		if [ "$conflict_found" -eq 0 ]; then
			break
		fi
	done
}

# 脚本启动前检查
ckstatus() {
	versionsh=$(cat "$CRASHDIR"/version)
	[ -n "$versionsh" ] && versionsh_l=$versionsh
	[ -z "$redir_mod" ] && redir_mod="$MENU_PURE_MOD"

	# 获取本机host地址
	[ -z "$host" ] && host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'lan' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host='$MENU_IP_DF'

	# dashboard目录位置
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
		run="\033[32m$MENU_RUN_ON（$redir_mod$MENU_MOD）\033[0m"
		running_status
	elif [ "$firewall_area" = 5 ] && [ -n "$(ip route list table 100)" ]; then
		run="\033[32m$MENU_RUN_SET（$redir_mod$MENU_MOD）\033[0m"
	else
		run="\033[31m$MENU_RUN_OFF（$redir_mod$MENU_MOD）\033[0m"
		# 检测系统端口占用
		checkport
	fi
	corename=$(echo $crashcore | sed 's/singboxr/SingBoxR/' | sed 's/singbox/SingBox/' | sed 's/clash/Clash/' | sed 's/meta/Mihomo/')
	# [ "$firewall_area" = 5 ] && corename='转发'
	[ -f "$TMPDIR"/debug.log -o -f "$CRASHDIR"/debug.log -a -n "$PID" ] && auto="\033[33m$MENU_AUTOSTART_DEBUG\033[0m"

	# 检查新手引导
	if [ -z "$userguide" ]; then
		userguide=1
		. "$CRASHDIR"/menus/userguide.sh && userguide
		setconfig userguide 1
	fi

	# 检查执行权限
	[ ! -x "$CRASHDIR"/start.sh ] && chmod +x "$CRASHDIR"/start.sh

	# 检查/tmp内核文件
	for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -Ev ".*(zip|7z|tar)$" | grep -iE 'CrashCore|^clash$|^clash-linux.*|^mihomo.*|^sing.*box'); do
		comp_box "$MENU_TMP_CORE_FOUND \033[36m/tmp/$file\033[0m" \
			"$MENU_TMP_CORE_ASK"
		btm_box "1) 立即加载" \
			"0) 暂不加载"
		read -r -p "$COMMON_INPUT> " res
		[ "$res" = 1 ] && {
			zip_type=$(echo "$file" | grep -oE 'tar.gz$|upx$|gz$')
			. "$CRASHDIR"/menus/9_upgrade.sh && setcoretype
			. "$CRASHDIR"/libs/core_tools.sh && core_check "/tmp/$file"
			if [ "$?" = 0 ]; then
				msg_alert "\033[32m$MENU_CORE_LOADED_OK\033[0m"
				switch_core
			else
				rm -rf /tmp/"$file"
				msg_alert "\033[33m$MENU_CORE_LOADED_BAD\033[0m" \
					"\033[33m$MENU_CORE_REMOVED\033[0m"
			fi
		}
	done

	# 检查/tmp配置文件
	for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -iE 'config.yaml$|config.yml$|config.json$'); do
		tmp_file=/tmp/$file
		comp_box "$MENU_TMP_CFG_FOUND\033[36m/tmp/$file\033[0m" \
			"$MENU_TMP_CFG_ASK"
		btm_box "1) 立即加载" \
			"0) 暂不加载"
		read -p "$COMMON_INPUT> " res
		[ "$res" = 1 ] && {
			if [ -n "$(echo /tmp/$file | grep -iE '.json$')" ]; then
				mv -f /tmp/$file "$CRASHDIR"/jsons/config.json
			else
				mv -f /tmp/$file "$CRASHDIR"/yamls/config.yaml
			fi
			msg_alert "\033[32m$MENU_CFG_LOADED_OK\033[0m "
		}
	done

	# 检查禁用配置覆写
	[ "$disoverride" = "1" ] && {
		comp_box "\033[33m$MENU_OVERRIDE_WARN\033[0m" \
			"$MENU_OVERRIDE_ASK"
		btm_box "1) 是" \
			"0) 否"
		read -p "$COMMON_INPUT> " res
		[ "$res" = 1 ] && unset disoverride && setconfig disoverride
	}

	top_box "\033[30;43m$MENU_WELCOME\033[0m\t\t  Ver: $versionsh_l" \
		"$MENU_TG_CHANNEL\033[36;4mhttps://t.me/ShellClash\033[0m"
	separator_line "-"
	content_line "$corename$run\t  $auto"
	if [ -n "$PID" ]; then
		content_line "$MENU_MEM_USED\033[44m$VmRSS\033[0m\t  $MENU_RUNNING_TIME\033[46;30m$day\033[44;37m$time\033[0m"
	fi
	separator_line "="
}

main_menu() {
	while true; do
		ckstatus

		content_line "1) \033[32m$MENU_MAIN_1\033[0m"
		content_line "2) \033[36m$MENU_MAIN_2\033[0m"
		content_line "3) \033[31m$MENU_MAIN_3\033[0m"
		content_line "4) \033[33m$MENU_MAIN_4\033[0m"
		content_line "5) \033[32m$MENU_MAIN_5\033[0m"
		content_line "6) \033[36m$MENU_MAIN_6\033[0m"
		content_line "7) \033[33m$MENU_MAIN_7\033[0m"
		content_line "8) $MENU_MAIN_8"
		content_line "9) \033[32m$MENU_MAIN_9\033[0m"
		content_line "0) $MENU_MAIN_0"
		separator_line "="
		read -r -p "$MENU_MAIN_PROMPT" num

		case "$num" in
		"" | 0)
			line_break
			exit 0
			;;
		1)
			start_service
			line_break
			exit
			;;
		2)
			checkcfg=$(cat "$CFG_PATH")
			. "$CRASHDIR"/menus/2_settings.sh && settings
			if [ -n "$PID" ]; then
				checkcfg_new=$(cat "$CFG_PATH")
				[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
			fi
			;;
		3)
			[ "$bot_tg_service" = ON ] && . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_stop
			"$CRASHDIR"/start.sh stop
			sleep 1
			msg_alert "\033[31m$corename$MENU_SERVICE_STOPPED\033[0m"
			;;
		4)
			. "$CRASHDIR"/menus/4_setboot.sh && setboot
			;;
		5)
			. "$CRASHDIR"/menus/5_task.sh && task_menu
			;;
		6)
			. "$CRASHDIR"/menus/6_core_config.sh && set_core_config
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
			;;
		8)
			. "$CRASHDIR"/menus/8_tools.sh && tools
			;;
		9)
			checkcfg=$(cat "$CFG_PATH")
			. "$CRASHDIR"/menus/9_upgrade.sh && upgrade
			if [ -n "$PID" ]; then
				checkcfg_new=$(cat "$CFG_PATH")
				[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
			fi
			;;
		*)
			errornum
			;;
		esac
	done
}

case "$1" in
"")
	main_menu
	;;
-l)
	main_menu
	;;
-t)
	shtype=sh
	[ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
	"$shtype" -x "$CRASHDIR"/menu.sh -l
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
	comp_box "$MENU_TEST_RUNNING_1" \
		"$MENU_TEST_RUNNING_2\033[36;4mhttps://t.me/ShellClash\033[0m"
	"$shtype" "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh_bug.log
	"$shtype" -x "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh.log
	cat "$TMPDIR"/debug_sh_bug.log | grep 'start\.sh' >"$TMPDIR"/sh_bug
	if [ -s "$TMPDIR"/sh_bug ]; then
		line_break
		echo "==========================================================="
		while read line; do
			echo -e "$MENU_ERROR_FOUND\033[33;4m$line\033[0m"
			grep -A 1 -B 3 "$line" "$TMPDIR"/debug_sh.log
			echo "==========================================================="
		done <"$TMPDIR"/sh_bug
		rm -rf "$TMPDIR"/sh_bug
		comp_box "\033[32m$MENU_TEST_DONE_FAIL\033[0m" \
			"$MENU_TEST_LOG_HINT\033[36m$TMPDIR/debug_sh.log\033[0m"
	else
		rm -rf "$TMPDIR"/debug_sh.log
		comp_box "\033[32m$MENU_TEST_DONE_OK\033[0m"
		line_break
	fi
	"$CRASHDIR"/start.sh stop
	;;
-u)
	. "$CRASHDIR"/menus/uninstall.sh && uninstall
	;;
*)
	comp_box "$MENU_WELCOME"
	content_line "-t $MENU_CLI_TEST"
	content_line "-h $MENU_CLI_HELP"
	content_line "-u $MENU_CLI_UNINSTALL"
	content_line "-i $MENU_CLI_INIT"
	content_line "-d $MENU_CLI_DEBUG"
	separator_line "-"
	content_line "crash -s start	$MENU_CLI_START"
	content_line "crash -s stop	$MENU_CLI_STOP"
	content_line "$CRASHDIR/start.sh init $MENU_CLI_BOOT_INIT"
	separator_line "-"
	content_line "$MENU_HELP_ONLINE\033[36mhttps://t.me/ShellClash\033[0m"
	content_line "$MENU_HELP_BLOG\033[36mhttps://juewuy.github.io\033[0m"
	content_line "$MENU_HELP_GITHUB\033[36mhttps://github.com/juewuy/ShellCrash\033[0m"
	separator_line "="
	line_break
	;;
esac
