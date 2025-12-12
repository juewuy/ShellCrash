#!/bin/sh
# Copyright (C) Juewuy

CFG="$CRASHDIR"/config/gateway.cfg

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
	genendpoints(){
		cat >"$CRASHDIR"/yamls/wireguard.yaml <<EOF




EOF
	}
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
		echo -----------------------------------------------
		echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！"
		echo -e "登陆后请前往此处创建秘钥\033[36;4mhttps://login.tailscale.com/admin/settings/keys\033[0m"
		echo -----------------------------------------------
		echo -e " 1 设置秘钥"
		echo -e " 2 使用代理出站"
		echo -e " 0 返回上级菜单 \033[0m"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		read -p "请输入相应内容 > " text
		case "$num" in
		0) ;;
		1)
			setconfig ts_auth_key "$text" "$CFG"
			setwireguard
			;;
		2)
			setconfig ts_proxy_type "$text" "$CFG"
			setwireguard
			;;
		*) errornum ;;
		esac		
	}
	echo -----------------------------------------------
	echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译WireGuard/Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！"
	echo -e "\033[33m配置完成后请手动生成配置文件！相关文件会在内核启动时自动加载！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 生成内核配置文件"
	echo -e " 2 配置WireGuard客户端"
	echo -e " 3 配置Tailscale(仅限Singbox内核)"
	echo -e " 4 移除内核配置文件"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		genendpoints
		gateway
		;;	
	2)
		setwireguard
		gateway
		;;
	3)
		settailscale
		gateway
		;;
	4)
		delendpoints
		gateway
		;;	
	*) errornum ;;
	esac
}