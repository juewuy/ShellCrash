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
		echo -e " 4 自定义\033[32m公网Vmess入站\033[0m节点"
		echo -e " 5 自定义\033[32m公网ShadowSocks入站\033[0m节点"
		echo -e " 6 配置\033[32mTailscale内网穿透\033[0m(限Singbox)"
		echo -e " 7 配置\033[32mWireguard客户端\033[0m"
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
		set_vmess
		gateway
	;;
	5)
		set_shadowsocks
		gateway
	;;
	6)
		if echo "$crashcore" | grep -q 'sing';then
			set_tailscale
		else
			echo -e "\033[33m$crashcore内核暂不支持此功能，请先更换内核！\033[0m"
			sleep 1
			checkupdate && setcore
		fi
		gateway
	;;
	7)
		set_wireguard
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
set_vmess(){
	echo -----------------------------------------------
	echo -e "\033[31m注意：\033[0m启动内核服务后会自动开放相应端口公网访问，请谨慎使用！"
	echo -----------------------------------------------
	echo -e " 1 \033[32m启用/关闭\033[0mVmess入站	\033[32m$vms_service\033[0m"
	echo -----------------------------------------------
	echo -e " 2 设置\033[36m监听端口\033[0m：	\033[36m$vms_port\033[0m"
	echo -e " 3 设置\033[33mWS-path(可选)\033[0m：	\033[33m$vms_ws_path\033[0m"
	echo -e " 4 设置\033[36m秘钥-uuid\033[0m：	\033[36m$vms_uuid\033[0m"
	echo -e " 5 一键生成\033[32m随机秘钥\033[0m"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		if [ -n "$vms_port" ] && [ -n "$vms_uuid" ];then
			[ "$vms_service" = ON ] && vms_service=OFF || vms_service=ON
			setconfig vms_service "$vms_service"
		else
			echo -e "\033[31m请先完成必选设置！\033[0m"
			sleep 1
		fi
		set_vmess
	;;
	2)
		read -p "请输入端口号(输入0删除) > " text
		[ "$text" = 0 ] && unset vms_port
		if sh "$CRASHDIR"/libs/check_port.sh "$text"; then
			vms_port="$text"
			setconfig vms_port "$text" "$CFG"
		else
			sleep 1
		fi
		set_vmess
	;;
	3)
		read -p "请输入ws-path路径(输入0删除) > " text
		[ "$text" = 0 ] && unset vms_ws_path
		if echo "$text" |grep -qE '^/';then
			vms_ws_path="$text"
			setconfig vms_ws_path "$text" "$CFG"
		else
			echo -e "\033[31m不是合法的path路径，必须以【/】开头！\033[0m"
			sleep 1
		fi
		set_vmess
	;;
	4)
		read -p "请输入UUID(输入0删除) > " text
		[ "$text" = 0 ] && unset vms_uuid
		if echo "$text" |grep -qiE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';then
			vms_uuid="$text"
			setconfig vms_uuid "$text" "$CFG"
		else
			echo -e "\033[31m不是合法的UUID格式，请重新输入或使用随机生成功能！\033[0m"
			sleep 1
		fi
		set_vmess
	;;
	5)
		vms_uuid=$(cat /proc/sys/kernel/random/uuid)
		setconfig vms_uuid "$vms_uuid" "$CFG"
		sleep 1
		set_vmess
	;;
	*) errornum ;;
	esac		
}
set_tailscale(){
	[ -n "$ts_auth_key" ] && ts_auth_key_info='*********'
	echo -----------------------------------------------
	echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！"
	echo -e "创建秘钥:\033[32;4mhttps://login.tailscale.com/admin/settings/keys\033[0m"
	echo -e "访问非本机目标需允许通告:\033[32;4mhttps://login.tailscale.com\033[0m"
	echo -e "访问非本机目标需在终端设置使用Subnet或EXIT-NODE模式"
	echo -----------------------------------------------
	echo -e " 1 \033[32m启用/关闭\033[0mTailscale服务	\033[32m$ts_service\033[0m"
	echo -e " 2 设置\033[36m秘钥\033[0m(Auth Key)		$ts_auth_key_info"
	echo -e " 3 通告路由\033[33m内网地址\033[0m(Subnet)	\033[36m$ts_subnet\033[0m"
	echo -e " 4 通告路由\033[31m全部流量\033[0m(EXIT-NODE)	\033[36m$ts_exit_node\033[0m"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		if [ -n "$ts_auth_key" ];then
			[ "$ts_service" = ON ] && ts_service=OFF || ts_service=ON
			setconfig ts_service "$ts_service"
		else
			echo -e "\033[31m请先设置秘钥！\033[0m"
			sleep 1
		fi
		set_tailscale
	;;
	2)
		read -p "请输入秘钥(输入0删除) > " text
		[ "$text" = 0 ] && unset ts_auth_key ts_auth_key_info || ts_auth_key="$text"
		[ -n "$ts_auth_key" ] && setconfig ts_auth_key "$ts_auth_key" "$CFG"
		set_tailscale
	;;
	3)
		[ "$ts_subnet" = true ] && ts_subnet=false || ts_subnet=true
		setconfig ts_subnet "$ts_subnet" "$CFG"
		set_tailscale
	;;
	4)
		[ "$ts_exit_node" = true ] && ts_exit_node=false || ts_exit_node=true
		setconfig ts_exit_node "$ts_exit_node" "$CFG"
		set_tailscale
	;;
	*) errornum ;;
	esac		
}
set_wireguard(){
	[ -n "$wg_public_key" ] && wgp_key_info='*********' || unset wgp_key_info
	[ -n "$wg_private_key" ] && wgv_key_info='*********' || unset wgv_key_info
	[ -n "$wg_pre_shared_key" ] && wgpsk_key_info='*********' || unset wgpsk_key_info
	echo -----------------------------------------------
	echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译WireGuard模块\n如需使用请先前往自定义内核更新完整版内核文件！"
	echo -----------------------------------------------
	echo -e " 1 \033[32m启用/关闭\033[0mWireguard服务	\033[32m$wg_service\033[0m"
	echo -----------------------------------------------
	echo -e " 2 设置\033[36mEndpoint地址\033[0m：		\033[36m$wg_server\033[0m"
	echo -e " 3 设置\033[36mEndpoint端口\033[0m：		\033[36m$wg_port\033[0m"
	echo -e " 4 设置\033[36m公钥-PublicKey\033[0m：		\033[36m$wgp_key_info\033[0m"
	echo -e " 5 设置\033[36m密钥-PresharedKey\033[0m：	\033[36m$wgpsk_key_info\033[0m"
	echo -----------------------------------------------
	echo -e " 6 设置\033[33m私钥-PrivateKey\033[0m：	\033[33m$wgv_key_info\033[0m"
	echo -e " 7 设置\033[33m组网IPV4地址\033[0m：		\033[33m$wg_ipv4\033[0m"
	echo -e " 8 可选\033[33m组网IPV6地址\033[0m：	\033[33m$wg_ipv6\033[0m"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		if [ -n "$wg_server" ] && [ -n "$wg_port" ] && [ -n "$wg_public_key" ] && [ -n "$wg_pre_shared_key" ] && [ -n "$wg_private_key" ] && [ -n "$wg_ipv4" ];then
			[ "$wg_service" = ON ] && wg_service=OFF || wg_service=ON
			setconfig wg_service "$wg_service"
		else
			echo -e "\033[31m请先完成必选设置！\033[0m"
			sleep 1
		fi
		set_wireguard
	;;
	[1-8])
		read -p "请输入相应内容(回车或0删除) > " text
		[ "$text" = 0 ] && text=''
		case "$num" in
		2)
			wg_server="$text"
			setconfig wg_server "$text" "$CFG"
		;;
		3)
			wg_port="$text"
			setconfig wg_port "$text" "$CFG"
		;;
		4)
			wg_public_key="$text"
			setconfig wg_public_key "$text" "$CFG"
		;;
		5)
			wg_pre_shared_key="$text"
			setconfig wg_pre_shared_key "$text" "$CFG"
		;;
		6)
			wg_private_key="$text"
			setconfig wg_private_key "$text" "$CFG"
		;;
		7)
			wg_ipv4="$text"
			setconfig wg_ipv4 "$text" "$CFG"
		;;
		8)
			wg_ipv6="$text"
			setconfig wg_ipv6 "$text" "$CFG"
		;;

		esac
		set_wireguard
	;;
	*) errornum ;;
	esac		
}

