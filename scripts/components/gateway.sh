#!/bin/sh
# Copyright (C) Juewuy

CFG="$CRASHDIR"/configs/gateway.cfg

gateway(){
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用访问与控制菜单：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 配置公网访问防火墙"
	echo -e " 2 配置Telegram专属控制机器人"
	echo -e " 3 配置DDNS自动域名"
	[ "$disoverride" != "1" ] && {
		echo -e " 4 自定义公网入站节点"
		echo -e " 5 配置\033[32m内网穿透\033[0m(WireGuard/Tailscale)"
	}
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		setfirewall
		gateway
		;;
	2)
		settgadvbot
		gateway
		;;
	3)
		setddns
		gateway
		;;
	4)
		setlisteners
		gateway
		;;
	5)
		setendpoints
		gateway
		;;
	*) errornum ;;
	esac
}

setendpoints(){
	setwireguard(){
		echo -----------------------------------------------
		echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译WireGuard模块\n如需使用请先前往自定义内核更新完整版内核文件！"
		echo -----------------------------------------------
		echo -e " 1 设置服务器地址"
		echo -e " 2 设置服务器端口"
		echo -e " 3 设置服务端公钥"
		echo -e " 4 设置本地私钥"
		echo -e " 5 设置本地IPV4地址"
		echo -e " 6 设置本地IPV6地址"
		echo -e " 0 返回上级菜单 \033[0m"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		read -p "请输入相应内容 > " text
		case "$num" in
		0) ;;
		1)
			setconfig wg_server "$text" "$CFG"
			setwireguard
			;;
		2)
			setconfig wg_port "$text" "$CFG"
			setwireguard
			;;
		3)
			setconfig wg_publickey "$text" "$CFG"
			setwireguard
			;;
		4)
			setconfig wg_privatekey "$text" "$CFG"
			setwireguard
			;;
		5)
			setconfig wg_ipv4 "$text" "$CFG"
			setwireguard
			;;
		6)
			setconfig wg_ipv6 "$text" "$CFG"
			setwireguard
			;;
		*) errornum ;;
		esac		
	}
	settailscale(){
		[ -n "$ts_auth_key" ] && ts_auth_key_info='已设置'
		echo -----------------------------------------------
		echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！"
		echo -e "登陆后请前往此处创建秘钥\033[36;4mhttps://login.tailscale.com/admin/settings/keys\033[0m"
		echo -e "通告路由首次启动服务后，需前往\033[36;4mhttps://login.tailscale.com\033[0m允许对应通告，并在客户端启用相关路由"
		echo -----------------------------------------------
		echo -e " 1 启用/关闭Tailscale服务		\033[32m$ts_service\033[0m"
		echo -e " 2 设置秘钥(Auth Key)			\033[32m$ts_auth_key_info\033[0m"
		echo -e " 3 通告路由保留地址(Subnet)	\033[32m$ts_advertise_routes\033[0m"
		echo -e " 4 通告路由全部流量(EXIT NODE)	\033[32m$ts_exit_node_allow\033[0m"
		echo -e " 0 返回上级菜单 \033[0m"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		case "$num" in
		0) ;;
		1)
			[ "ts_service" = ON ] && ts_service=OFF || ts_service=ON
			setconfig ts_service "$ts_service"
			setwireguard
			;;
		2)
			read -p "请输入秘钥(Auth key) > " text
			[ -n "$text" ] && setconfig ts_auth_key "$text" "$CFG"
			setwireguard
			;;
		3)
			[ "ts_advertise_routes" = true ] && ts_advertise_routes=false || ts_advertise_routes=true
			setconfig ts_advertise_routes "$ts_advertise_routes" "$CFG"
			setwireguard
			;;
		4)
			[ "advertise_exit_node" = true ] && advertise_exit_node=false || advertise_exit_node=true
			setconfig advertise_exit_node "$advertise_exit_node" "$CFG"
			setwireguard
			;;
		*) errornum ;;
		esac		
	}
	echo -----------------------------------------------
	echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译WireGuard/Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！"
	echo -----------------------------------------------
	echo -e " 1 配置WireGuard客户端"
	echo -e " 2 配置Tailscale(仅限Singbox内核)"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;	
	1)
		setwireguard
		gateway
		;;
	2)
		settailscale
		gateway
		;;
	*) errornum ;;
	esac
}