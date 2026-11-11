#!/bin/sh

. ${CRASHDIR}/configs/ShellCrash.cfg
. "$CRASHDIR"/libs/set_proxy.sh
OFFSET=0
API="https://api.telegram.org/bot$TGBOT_TOKEN"
STATE_FILE="/tmp/ShellCrash/tgbot_state"
LOGFILE="/tmp/ShellCrash/tgbot.log"

### --- 基础函数 --- ###
setconfig() {
	#参数1代表变量名，参数2代表变量值
	configpath=${CRASHDIR}/configs/ShellCrash.cfg
	grep -q "${1}=" "$configpath" && sed -i "s#${1}=.*#${1}=${2}#g" $configpath || sed -i "\$a\\${1}=${2}" $configpath
}
setproxy(){
	[ -n "$(pidof CrashCore)" ] && {
		[ -n "$authentication" ] && auth="$authentication@"
		[ -z "$mix_port" ] && mix_port=7890
		export https_proxy="http://${auth}127.0.0.1:$mix_port"
	}
}
webget() {
	setproxy
	if curl --version >/dev/null 2>&1; then
		curl -kfsSl --connect-timeout 3 $1 2>/dev/null
	else
		wget_proxy on -q --timeout=3 -O - $1
	fi
}
webpost() {
	setproxy
	if curl --version >/dev/null 2>&1; then
		curl -kfsSl -X POST --connect-timeout 3 -H "Content-Type: application/json; charset=utf-8" "$1" -d "$2" >/dev/null 2>&1
	else
		wget_proxy on -q --timeout=3 --method=POST --header="Content-Type: application/json; charset=utf-8" --body-data="$2" "$1"
	fi
}
send_msg() {
    TEXT="$1"
	webpost "$API/sendMessage" "{\"chat_id\":\"$TGBOT_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\"}"
}
send_help(){
    TEXT=$(cat <<EOF
进群讨论：
https://t.me/+RKujv98Gbx5zGY-P
项目地址：
https://github.com/juewuy/ShellCrash
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

webpost "$API/sendMessage" "{\"chat_id\":\"$TGBOT_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\",\"reply_markup\":$MENU}"

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
		UPDATES=$(webget "$API/getUpdates?timeout=25&offset=$OFFSET")

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

### --- 初始设置 --- ###
set_botmenu(){
	curl -s -X POST "https://api.telegram.org/bot$TOKEN/setMyCommands" \
	  -H "Content-Type: application/json" \
	  -d '{
			"commands": [
			  {"command": "crash", "description": "呼出ShellCrash菜单"},
			  {"command": "help",  "description": "查看帮助"}
			]
		  }'
}
set_token(){
	echo -----------------------------------------------
	echo -e "请先通过 \033[32;4mhttps://t.me/BotFather\033[0m 申请TG机器人并获取其\033[36mAPI TOKEN\033[0m"
	echo -----------------------------------------------
	read -p "请输入你获取到的API TOKEN > " TOKEN
	echo -----------------------------------------------
	echo -e "请向\033[32m你申请的机器人\033[31m而不是BotFather\033[0m，发送任意几条消息！"
	echo -----------------------------------------------
	read -p "我已经发送完成(1/0) > " res
	if [ "$res" = 1 ]; then
		url_tg=https://api.telegram.org/bot${TOKEN}/getUpdates
		[ -n "$authentication" ] && auth="$authentication@"
		export https_proxy="http://${auth}127.0.0.1:$mix_port"
		chat=$(webget $url_tg | tail -n -1)
		[ -n "$chat" ] && chat_ID=$(echo $chat | grep -oE '"id":.*,"is_bot":false' | sed s'/"id"://'g | sed s'/,"is_bot":false//'g)
		[ -z "$chat_ID" ] && {
			echo -e "\033[31m无法获取对话ID，请确认使用的不是已经被绑定的机器人，或手动输入ChatID！\033[0m"
			echo -e "通常访问 $url_tg 即可看到ChatID，也可以尝试其他方法\033[0m"
			read -p "请手动输入ChatID > " chat_ID
		}
		if [ -n "$chat_ID" ]; then
			TGBOT_TOKEN=$TOKEN
			setconfig TGBOT_TOKEN $TOKEN
			setconfig TGBOT_CHATID $chat_ID
			set_botmenu
			echo -e "\033[32m已完成Telegram机器人设置！\033[0m"
		else
			echo -e "\033[31m无法获取对话ID，请重新配置！\033[0m"
		fi
	fi
}

case "$1" in
init)
	set_token
;;
*)
	polling
;;
esac
