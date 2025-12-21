#!/bin/sh

. "$CRASHDIR"/configs/ShellCrash.cfg
. "$CRASHDIR"/configs/gateway.cfg
. "$CRASHDIR"/libs/web_json.sh

OFFSET=0
API="https://api.telegram.org/bot$TG_TOKEN"
STATE_FILE="/tmp/ShellCrash/tgbot_state"
LOGFILE="/tmp/ShellCrash/tgbot.log"

### --- 基础函数 --- ###
send_msg() {
    TEXT="$1"
	web_json_post "$API/sendMessage" "{\"chat_id\":\"$TG_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\"}"
}
send_help(){
    TEXT=$(cat <<EOF
进群讨论：
https://t.me/+6AElkMDzwPxmMmM1
项目地址：
https://github.com/juewuy/ShellClash
相关教程：
https://juewuy.github.io
请喝咖啡：
https://juewuy.github.io/yOF4Yf06Q/
友情机场： 
https://dler.pro/auth/register?affid=89698
https://pub.bigmeok.me?code=2PuWY9I7
EOF
)
	send_msg "$TEXT"
}
send_menu() {
	#获取运行状态
	PID=$(pidof CrashCore | awk '{print $NF}')
	if [ -n "$PID" ]; then
		run=正在运行
		VmRSS=$(cat /proc/$PID/status | grep -w VmRSS | awk 'unit="MB" {printf "%.2f %s\n", $2/1000, unit}')
		start_time=$(cat /tmp/ShellCrash/crash_start_time)
		if [ -n "$start_time" ]; then
			time=$(($(date +%s) - start_time))
			day=$((time / 86400))
			[ "$day" = "0" ] && day='' || day="$day天"
			time=$(date -u -d @${time} +%H小时%M分%S秒)
		fi
	corename=$(echo $crashcore | sed 's/singboxr/SingBoxR/' | sed 's/singbox/SingBox/' | sed 's/clash/Clash/' | sed 's/meta/Mihomo/')
	else
		run=未运行
	fi
    TEXT=$(cat <<EOF
*欢迎使用ShellCrash！*                版本：$versionsh_l
$corename服务$run               【*$redir_mod*】
内存占用：$VmRSS                    已运行：$day$time
请选择操作：
EOF
)

    MENU=$(cat <<'EOF'
{
  "inline_keyboard":[
    [
      {"text":"▶ 启用劫持","callback_data":"start_redir"},
      {"text":"■ 纯净模式","callback_data":"stop_redir"},
      {"text":"🔄 重启内核","callback_data":"restart"}
    ],
    [
      {"text":"🌀 热更新订阅","callback_data":"refresh"},
      {"text":"📝 添加订阅","callback_data":"set_sub"}
    ]
  ]
}
EOF
)

web_json_post "$API/sendMessage" "{\"chat_id\":\"$TG_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\",\"reply_markup\":$MENU}"

}

### --- 具体操作函数 --- ###
do_start_fw() {
	[ -z "$redir_mod_bf" ] && redir_mod_bf='Redir模式'
	redir_mod=$redir_mod_bf
	setconfig redir_mod $redir_mod
	"$CRASHDIR"/start.sh start_firewall
    echo "ShellCrash 透明路由*$redir_mod_bf*已启用！" > "$LOGFILE"
}
do_stop_fw() {
	redir_mod_bf=$redir_mod
	redir_mod='纯净模式'
	setconfig redir_mod $redir_mod
	"$CRASHDIR"/start.sh stop_firewall
    echo "ShellCrash 已切换到纯净模式！" > "$LOGFILE"
}
do_restart() {
    "$CRASHDIR"/start.sh restart
    echo "ShellCrash 服务已重启！" > "$LOGFILE"
}
do_refresh() {
    "$CRASHDIR"/start.sh hotupdate
	echo "ShellCrash 已完成热更新订阅！" > "$LOGFILE"
}
do_set_sub() {
    #echo "$1" "$2" >> "$CRASHDIR"/configs/providers.cfg
    echo "错误，还未完成的功能！" > "$LOGFILE"

}

### --- 轮询主进程 --- ###
polling(){
	while true; do
		UPDATES=$(web_json_get "$API/getUpdates?timeout=25&offset=$OFFSET")

		echo "$UPDATES" | grep -q '"update_id"' || continue

		OFFSET=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n1 | cut -d: -f2)
		OFFSET=$((OFFSET + 1))
		
		### --- 处理按钮事件 --- ###
		CALLBACK=$(echo "$UPDATES" | grep -o '"data":"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')

		case "$CALLBACK" in
			"start_redir")
				if [ "$redir_mod" = '纯净模式' ];then
					do_start_fw
					send_msg  "已切换到$redir_mod_bf！"
				else
					send_msg  "当前已经是$redir_mod！"
				fi
				send_menu 
				continue
				;;
			"stop_redir")
				if [ "$redir_mod" != '纯净模式' ];then
					do_stop_fw
					send_msg  "已切换到纯净模式"
				else
					send_msg  "当前已经是纯净模式！"
				fi
				send_menu 
				continue
				;;
			"restart")
				do_restart
				send_msg  "🔄 服务已重启"
				sleep 10
				send_menu 
				continue
				;;
			"refresh")
				do_refresh
				send_msg  "🌀 刷新完成：\n$(cat "$LOGFILE")"
				send_menu 
				continue
				;;
			"set_sub")
				echo "await_sub" > "$STATE_FILE"
				send_msg  "✏ 请输入新的订阅链接："
				continue
				;;
		esac


		### --- 处理订阅输入 --- ###
		TEXT=$(echo "$UPDATES" | grep -o '"text":"[^"]*"' | tail -n1 | sed 's/.*"text":"//;s/"$//')

		if [ "$(cat "$STATE_FILE" 2>/dev/null)" = "await_sub" ]; then
			echo "" > "$STATE_FILE"
			do_set_sub "$TEXT"
			send_msg  "订阅更新完成：\n$(cat "$LOGFILE")"
			send_menu 
			continue
		fi


		### 处理命令 ###
		case "$TEXT" in
		/crash)
			send_menu
		;;
		/help)
			send_help
		;;
		esac

	done
}
send_menu
polling

