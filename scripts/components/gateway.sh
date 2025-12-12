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
		setendpoints
		;;
	2)
		settailscale
		setendpoints
		;;
	*) errornum ;;
	esac
}