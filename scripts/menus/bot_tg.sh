#!/bin/sh

[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
. "$CRASHDIR"/libs/web_json.sh
. "$CRASHDIR"/libs/web_get_lite.sh
. "$CRASHDIR"/menus/running_status.sh
. "$CRASHDIR"/configs/gateway.cfg
. "$CRASHDIR"/configs/ShellCrash.cfg

TMPDIR='/tmp/ShellCrash'
API="https://api.telegram.org/bot$TG_TOKEN"
STATE_FILE="$TMPDIR/tgbot_state"
LOGFILE="$TMPDIR/tgbot.log"
OFFSET=0

### --- 基础函数 --- ###
web_download(){
	setproxy
	if curl --version >/dev/null 2>&1; then
		curl -kfsSl "$1" -o "$2"
	else
		wget -Y on -q --timeout=3 -O "$2" "$1"
	fi
}
web_upload(){
	curl -ksSfl -X POST --connect-timeout 20 "$API/sendDocument" -F "chat_id=$TG_CHATID" -F "document=@$1" >/dev/null
}
send_msg(){
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
send_menu(){
	#获取运行状态
	PID=$(pidof CrashCore | awk '{print $NF}')
	if [ -n "$PID" ]; then
		run='🟢正在运行'
		running_status
	else
		run='🟡未运行'
	fi
	corename=$(echo $crashcore | sed 's/singboxr/SingBoxR/' | sed 's/singbox/SingBox/' | sed 's/clash/Clash/' | sed 's/meta/Mihomo/')
    TEXT=$(cat <<EOF
*欢迎使用ShellCrash！*_${versionsh_l}_
$corename服务$run
【*$redir_mod*】内存占用：$VmRSS
已运行：$day$time
请选择操作：
EOF
)
    MENU=$(cat <<EOF
{
  "inline_keyboard":[
    [
      {"text":"✈️ 启用劫持","callback_data":"start_redir"},
      {"text":"💧 纯净模式","callback_data":"stop_redir"},
      {"text":"🕹 重启服务","callback_data":"restart"}
    ],
    [
      {"text":"📄 查看日志","callback_data":"readlog"},
	  {"text":"🔃 文件传输","callback_data":"transport"}
    ]
  ]
}
EOF
)
web_json_post "$API/sendMessage" "{\"chat_id\":\"$TG_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\",\"reply_markup\":$MENU}"
}
### --- 文件传输 --- ###
send_transport_menu(){ 
    TEXT='请选择需要上传或下载的具体文件：'
	if echo "$crashcore" | grep -q 'singbox';then
		config_type=json
	else
		config_type=yaml
	fi

	if curl -h >/dev/null 2>&1;then
		CURL_KB=$(cat <<EOF
	[
      {"text":"📥 下载日志","callback_data":"ts_get_log"},
      {"text":"💾 备份设置","callback_data":"ts_get_bak"},
      {"text":"⬇️ 下载配置","callback_data":"ts_get_ccf"}
    ],
EOF
)
	else
		CURL_KB='[{"text":"⚠️ 因当前设备缺少curl应用，仅支持上传功能！","callback_data":"noop"}],'
	fi
    MENU=$(cat <<EOF
{
  "inline_keyboard":[
	$CURL_KB
    [
      {"text":"🪐 上传内核","callback_data":"ts_up_core"},
	  {"text":"🔄 还原设置","callback_data":"ts_up_bak"},
      {"text":"⬆️ 上传配置","callback_data":"ts_up_ccf"}
    ]
  ]
}
EOF
)

web_json_post "$API/sendMessage" "{\"chat_id\":\"$TG_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\",\"reply_markup\":$MENU}"

}
process_file(){
	case "$FILE_TYPE" in
		1)
			. "$CRASHDIR"/libs/core_tools.sh
			core_check "$TMPDIR/$FILE_NAME" && res='成功!即将重启服务！' || res='失败,请仔细检查文件或重试！'
			send_msg "内核更新$res"
			sleep 2
			"$CRASHDIR"/start.sh start
		;;
		2)
			tar -zxf "$TMPDIR/$FILE_NAME" -C "$CRASHDIR"/configs && res='配置文件已还原，请手动重启服务！' || res='解压还原失败,请仔细检查文件或重试！'
			send_msg "$res"
		;;
		3)
			mv -f "$TMPDIR/$FILE_NAME" "$CRASHDIR/${config_type}s/" && res='配置文件已上传，请手动重启服务！' || res='上传失败,请仔细检查文件或重试！'
			send_msg "$res"
		;;
	esac
	rm -f "$TMPDIR/$FILE_NAME"
	send_menu
}
download_file(){
	FILE_NAME=$(echo "$UPDATES" | sed 's/"callback_query".*//g' | grep -o '"file_name":"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//' | grep -E '\.(gz|upx|json|yaml)$')
	if [ -n "$FILE_NAME" ];then
		FILE_PATH=$(web_get_lite "$API/getFile?file_id=$FILE_ID" | grep -o '"file_path":"[^"]*"' | sed 's/.*:"//;s/"$//')
		API_FILE="https://api.telegram.org/file/bot$TG_TOKEN"
		web_download "$API_FILE/$FILE_PATH" "$TMPDIR/$FILE_NAME"
		if [ "$?" = 0 ];then
			process_file
		else
			send_msg "网络错误，上传失败！请重试！"
		fi
	else
		send_msg "文件格式不匹配，上传失败！"
	fi
}
### --- 具体操作函数 --- ###
do_start_fw(){
	[ -z "$redir_mod_bf" ] && redir_mod_bf='Redir模式'
	redir_mod=$redir_mod_bf
	setconfig redir_mod $redir_mod
	"$CRASHDIR"/start.sh start_firewall
    echo "ShellCrash 透明路由*$redir_mod_bf*已启用！" > "$LOGFILE"
}
do_stop_fw(){
	redir_mod_bf=$redir_mod
	redir_mod='纯净模式'
	setconfig redir_mod $redir_mod
	"$CRASHDIR"/start.sh stop_firewall
    echo "ShellCrash 已切换到纯净模式！" > "$LOGFILE"
}
do_restart(){
    "$CRASHDIR"/start.sh restart
    echo "ShellCrash 服务已重启！" > "$LOGFILE"
}
do_set_sub(){
    #echo "$1" "$2" >> "$CRASHDIR"/configs/providers.cfg
    echo "错误，还未完成的功能！" > "$LOGFILE"

}
transport(){ #文件传输
	case "$CALLBACK" in
		"ts_get_log")
			web_upload "$TMPDIR"/ShellCrash.log
			send_menu 
		;;
		"ts_get_bak")
			now=$(date +%Y%m%d_%H%M%S)
			FILE="$TMPDIR/configs_$now.tar.gz"
			tar -zcf "$FILE" -C "$CRASHDIR/configs/" .
			web_upload "$FILE"
			rm -rf "$FILE"
			send_menu 
		;;
		"ts_get_ccf")
			FILE="$TMPDIR/$config_type.tar.gz"
			tar -zcf "$FILE" -C "$CRASHDIR/${config_type}s/" .
			web_upload "$FILE"
			rm -rf "$FILE"
			send_menu 
		;;
		"ts_up_core")
			FILE_TYPE=1
			send_msg  "请发送需要上传的内核，必须是以tar.gz,.gz或.upx结尾的【${corename}】内核！"
		;;
		"ts_up_bak")
			FILE_TYPE=2
			send_msg  "请发送需要还原的备份文件，必须是【.tar.gz】格式！"
		;;
		"ts_up_ccf")
			FILE_TYPE=3
			send_msg  "请发送需要上传的配置文件，必须是【.${config_type}】格式，支持自定义配置文件"
		;;
	esac
}

### --- 轮询主进程 --- ###
polling(){
	while true; do
		UPDATES=$(web_get_lite "$API/getUpdates?timeout=25&offset=$OFFSET")

		echo "$UPDATES" | grep -q '"update_id"' || {
			sleep 10 #防止网络不佳时疯狂请求
			continue
		}
		
		OFFSET=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n1 | cut -d: -f2)
		OFFSET=$((OFFSET + 1))
		
		### --- 校验ChatID --- ###
		CHATID=$(echo "$UPDATES" | grep -o '"id":[0-9]*' | tail -n1 | cut -d: -f2)
		[ "$CHATID" != "$TG_CHATID" ] && continue
		
		### --- 处理按钮事件 --- ###
		CALLBACK=$(echo "$UPDATES" | grep -o '"data":"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')
		FILE_ID=$(echo "$UPDATES" | sed 's/"callback_query".*//g' | grep -o '"file_id":"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')
		
		[ -n "$FILE_ID" ] && {
			download_file
			continue
		}
		[ -n "$CALLBACK" ] && case "$CALLBACK" in
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
			"readlog")
				send_msg  "📄 日志内容如下(已过滤任务日志)：\n\`\`\`$(grep -v '任务' $TMPDIR/ShellCrash.log |tail -n 20)\`\`\`"
				sleep 3
				send_menu 
				continue
			;;
			"transport")
				send_transport_menu
				continue
			;;
			"set_sub")
				echo "await_sub" > "$STATE_FILE"
				send_msg  "✏ 请输入新的订阅链接："
				continue
			;;
			ts_*)
				transport
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

#send_menu

polling

