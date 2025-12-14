#!/bin/sh
# Copyright (C) Juewuy

CFG="$CRASHDIR"/configs/gateway.cfg
. "$CFG"

gateway(){
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用访问与控制菜单：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 配置公网访问防火墙"
	echo -e " 2 配置Telegram专属控制机器人"
	echo -e " 3 配置DDNS自动域名"
	[ "$disoverride" != "1" ] && {
		echo -e " 4 自定义公网入站节点"
		echo -e " 5 配置\033[32m内网穿透\033[0m(Tailscale,仅限Singbox)"
	}
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		set_pub_fw
		gateway
		;;
	2)
		set_bot_tg
		gateway
		;;
	3)
		set_ddns
		gateway
		;;
	4)
		set_listeners
		gateway
		;;
	5)
		if echo "$crashcore" | grep -q 'sing';then
			setendpoints
		else
			echo -e "\033[33m$crashcore内核暂不支持此功能，请先更换内核！\033[0m"
			sleep 1
			checkupdate && setcore
		fi
		gateway
		;;
	*) errornum ;;
	esac
}
set_pub_fw() { #公网防火墙设置
	[ -z "$public_support" ] && public_support=未开启
	[ -z "$public_mixport" ] && public_mixport=未开启
	echo -----------------------------------------------
	echo -e " 1 公网访问Dashboard面板:	\033[36m$public_support\033[0m"
	echo -e " 2 公网访问Socks/Http代理:	\033[36m$public_mixport\033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case $num in
	1)
		if [ "$public_support" = "未开启" ]; then
			public_support=已开启
		else
			public_support=未开启
		fi
		setconfig public_support $public_support
		setfirewall
		;;
	2)
		if [ "$public_mixport" = "未开启" ]; then
			if [ "$mix_port" = "7890" -o -z "$authentication" ]; then
				echo -----------------------------------------------
				echo -e "\033[33m为了安全考虑，请先修改默认Socks/Http端口并设置代理密码\033[0m"
				sleep 1
				setport
			else
				public_mixport=已开启
			fi
		else
			public_mixport=未开启
		fi
		setconfig public_mixport $public_mixport
		setfirewall
		;;
	3)
		set_cust_host_ipv4
		setfirewall
		;;
	*)
		errornum
		;;
	esac
}
set_bot_tg_init(){
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
			setconfig TG_TOKEN $TOKEN "$CFG"
			setconfig TG_CHATID $chat_ID "$CFG"
			#设置机器人快捷命令
			curl -s -X POST "https://api.telegram.org/bot$TOKEN/setMyCommands" \
			  -H "Content-Type: application/json" \
			  -d '{
					"commands": [
					  {"command": "crash", "description": "呼出ShellCrash菜单"},
					  {"command": "help",  "description": "查看帮助"}
					]
				  }'
			echo -e "\033[32m已完成Telegram机器人设置！\033[0m"
			return 0
		else
			echo -e "\033[31m无法获取对话ID，请重新配置！\033[0m"
			return 1
		fi
	fi
}
set_bot_tg_service(){
	if [ "$bot_tg_service" = ON ];then
		bot_tg_service=OFF
		PID=$(pidof bot_tg.sh) && [ -n "$PID" ] && kill -9 $PID >/dev/null 2>&1
	else
		bot_tg_service=ON
		[ -z "$(pidof bot_tg.sh)" ] && "$CRASHDIR"/components/bot_tg.sh &
	fi
	setconfig bot_tg_service "$bot_tg_service"
}
set_bot_tg(){
	[ -n "$ts_auth_key" ] && ts_auth_key_info='已设置'
	echo -----------------------------------------------
	echo -e "\033[31m注意：\033[0m由于网络环境原因，此机器人仅限服务启动时运行！"
	echo -e "此机器人与推送机器人互不影响，请尽量不要设置成同一机器人"
	echo -----------------------------------------------
	echo -e " 1 启用/关闭TG-BOT服务	\033[32m$bot_tg_service\033[0m"
	echo -e " 2 TG-BOT绑定设置"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		. "$CFG"
		if [ -n "$TG_CHATID" ];then
			set_bot_tg_service
		else
			set_bot_tg_init && set_bot_tg_service
		fi
	;;
	2)
		set_bot_tg_init && set_bot_tg_service
	;;
	*)
		errornum
	;;
	esac		
}
set_ddns(){
	echo
}
setendpoints(){
	settailscale(){
		[ -n "$ts_auth_key" ] && ts_auth_key_info='已设置'
		echo -----------------------------------------------
		echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！"
		echo -e "创建秘钥:\033[32;4mhttps://login.tailscale.com/admin/settings/keys\033[0m"
		echo -e "访问非本机目标需允许通告:\033[32;4mhttps://login.tailscale.com\033[0m"
		echo -e "访问非本机目标需在终端设置使用Subnet或EXIT-NODE模式"
		echo -----------------------------------------------
		echo -e " 1 启用/关闭Tailscale服务	\033[32m$ts_service\033[0m"
		echo -e " 2 设置秘钥(Auth Key)		\033[32m$ts_auth_key_info\033[0m"
		echo -e " 3 通告路由内网地址(Subnet)	\033[32m$ts_subnet\033[0m"
		echo -e " 4 通告路由全部流量(EXIT-NODE)	\033[32m$ts_exit_node\033[0m"
		echo -e " 0 返回上级菜单 \033[0m"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		case "$num" in
		0) ;;
		1)
			[ "$ts_service" = ON ] && ts_service=OFF || ts_service=ON
			setconfig ts_service "$ts_service"
			settailscale
			;;
		2)
			read -p "请输入秘钥(输入0删除) > " text
			[ "$text" = 0 ] && unset ts_auth_key ts_auth_key_info || ts_auth_key="$text"
			[ -n "$ts_auth_key" ] && setconfig ts_auth_key "$ts_auth_key" "$CFG"
			settailscale
			;;
		3)
			[ "$ts_subnet" = true ] && ts_subnet=false || ts_subnet=true
			setconfig ts_subnet "$ts_subnet" "$CFG"
			settailscale
			;;
		4)
			[ "$ts_exit_node" = true ] && ts_exit_node=false || ts_exit_node=true
			setconfig ts_exit_node "$ts_exit_node" "$CFG"
			settailscale
			;;
		*) errornum ;;
		esac		
	}
	settailscale
}