#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_7_GATEWAY_LOADED" ] && return
__IS_MODULE_7_GATEWAY_LOADED=1

. "$GT_CFG_PATH"
. "$CRASHDIR"/menus/check_port.sh
. "$CRASHDIR"/libs/gen_base64.sh

# 访问与控制主菜单
gateway() {
    while true; do
        echo "-----------------------------------------------"
        echo -e "\033[30;47m欢迎使用访问与控制菜单：\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 配置\033[33m公网访问防火墙			\033[32m$fw_wan\033[0m"
        echo -e " 2 配置\033[36mTelegram专属控制机器人		\033[32m$bot_tg_service\033[0m"
        echo -e " 3 配置\033[36mDDNS自动域名\033[0m"
        [ "$disoverride" != "1" ] && {
            echo -e " 4 自定义\033[33m公网Vmess入站\033[0m节点		\033[32m$vms_service\033[0m"
            echo -e " 5 自定义\033[33m公网ShadowSocks入站\033[0m节点	\033[32m$sss_service\033[0m"
            echo -e " 6 配置\033[36mTailscale内网穿透\033[0m(限Singbox)	\033[32m$ts_service\033[0m"
            echo -e " 7 配置\033[36mWireguard客户端\033[0m(限Singbox)	\033[32m$wg_service\033[0m"
        }
        echo -e " 0 返回上级菜单"
        echo "-----------------------------------------------"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            echo "-----------------------------------------------"
            if [ -n "$(pidof CrashCore)" ] && [ "$firewall_mod" = 'iptables' ]; then
                read -p "需要先停止服务，是否继续？(1/0) > " res
                [ "$res" = 1 ] && "$CRASHDIR"/start.sh stop && set_fw_wan
            else
                set_fw_wan
            fi
            ;;
        2)
            set_bot_tg
            ;;
        3)
            . "$CRASHDIR"/menus/ddns.sh && ddns_menu
            ;;
        4)
            set_vmess
            ;;
        5)
            set_shadowsocks
            ;;
        6)
            if echo "$crashcore" | grep -q 'sing'; then
                set_tailscale
            else
                echo -e "\033[33m$crashcore内核暂不支持此功能，请先更换内核！\033[0m"
                sleep 1
            fi
            ;;
        7)
            if echo "$crashcore" | grep -q 'sing'; then
                set_wireguard
            else
                echo -e "\033[33m$crashcore内核暂不支持此功能，请先更换内核！\033[0m"
                sleep 1
            fi
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}

#公网防火墙
set_fw_wan() {
	[ -z "$fw_wan" ] && fw_wan=ON
	echo "-----------------------------------------------"
	echo -e "\033[31m注意：\033[0m如在vps运行，还需在vps安全策略对相关端口同时放行"
	[ -n "$fw_wan_ports" ] && 
	echo -e "当前手动放行端口：\033[36m$fw_wan_ports\033[0m"
	[ -n "$vms_port$sss_port" ] && 
	echo -e "当前自动放行端口：\033[36m$vms_port $sss_port\033[0m"
	echo -e "默认拦截端口：\033[33m$dns_port,$mix_port,$db_port\033[0m"
	echo "-----------------------------------------------"
	echo -e " 1 启用/关闭公网防火墙:	\033[36m$fw_wan\033[0m"
	echo -e " 2 添加放行端口(可包含默认拦截端口)"
	echo -e " 3 移除指定手动放行端口"
	echo -e " 4 清空全部手动放行端口"
	echo -e " 0 返回上级菜单"
	echo "-----------------------------------------------"
	read -p "请输入对应数字 > " num
	case $num in
	1)
		if [ "$fw_wan" = ON ];then
			read -p "确认关闭防火墙？这会带来极大的安全隐患！(1/0) > " res
			[ "$res" = 1 ] && fw_wan=OFF || fw_wan=ON
		else
			fw_wan=ON
		fi
		setconfig fw_wan "$fw_wan"
		set_fw_wan
	;;
	2)
		port_count=$(echo "$fw_wan_ports" | awk -F',' '{print NF}' )
		if [ "$port_count" -ge 10 ];then
			echo -e "\033[31m最多支持设置放行10个端口，请先减少一些！\033[0m"
		else
			read -p "请输入要放行的端口号 > " port
			if echo ",$fw_wan_ports," | grep -q ",$port,";then	
				echo -e "\033[31m输入错误！请勿重复添加！\033[0m"
			elif [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
				echo -e "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
			else
				fw_wan_ports=$(echo "$fw_wan_ports,$port" | sed "s/^,//")
				setconfig fw_wan_ports "$fw_wan_ports"
			fi
		fi
		sleep 1
		set_fw_wan
	;;
	3)
		read -p "请输入要移除的端口号 > " port
		if echo ",$fw_wan_ports," | grep -q ",$port,";then	
			if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
				echo -e "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
			else
				fw_wan_ports=$(echo ",$fw_wan_ports," | sed "s/,$port//; s/^,//; s/,$//")
				setconfig fw_wan_ports "$fw_wan_ports"
			fi
		else
			echo -e "\033[31m输入错误！请输入已添加过的端口！\033[0m"
		fi
		sleep 1
		set_fw_wan
	;;
	4)
		fw_wan_ports=''
		setconfig fw_wan_ports
		sleep 1
		set_fw_wan
	;;
	*)
		errornum
	;;
	esac
}
#tg_BOT相关
set_bot_tg_config(){
	setconfig TG_TOKEN "$TOKEN" "$GT_CFG_PATH"
	setconfig TG_CHATID "$chat_ID" "$GT_CFG_PATH"
	#设置机器人快捷命令
	JSON=$(cat <<EOF
{
  "commands": [
    {"command": "crash", "description": "呼出ShellCrash菜单"},
    {"command": "help",  "description": "查看帮助"}
  ]
}
EOF
)
	TEXT='已完成Telegram机器人设置！'
	. "$CRASHDIR"/libs/web_json.sh
	bot_api="https://api.telegram.org/bot$TOKEN"
	web_json_post "$bot_api/setMyCommands" "$JSON"
	web_json_post "$bot_api/sendMessage" '{"chat_id":"'"$chat_ID"'","text":"'"$TEXT"'","parse_mode":"Markdown"}'
	echo -e "\033[32m$TEXT\033[0m"
}
set_bot_tg_init(){
	. "$CRASHDIR"/menus/bot_tg_bind.sh && private_bot && set_bot
	if [ "$?" = 0 ]; then
		set_bot_tg_config
		return 0
	else
		return 1
	fi
}
set_bot_tg_service(){
	if [ "$bot_tg_service" = ON ];then
		bot_tg_service=OFF
		. "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_stop
	else
		bot_tg_service=ON
		[ -n "$(pidof CrashCore)" ] && . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_start
	fi
	setconfig bot_tg_service "$bot_tg_service"
}
set_bot_tg(){
	[ -n "$ts_auth_key" ] && ts_auth_key_info='已设置'
	[ -n "$TG_CHATID" ] && TG_CHATID_info='已绑定'
	echo "-----------------------------------------------"
	echo -e "\033[31m注意：\033[0m由于网络环境原因，此机器人仅限服务启动时运行！"
	echo "-----------------------------------------------"
	echo -e " 1 启用/关闭TG-BOT服务	\033[32m$bot_tg_service\033[0m"
	echo -e " 2 TG-BOT绑定设置	\033[32m$TG_CHATID_info\033[0m"
	echo -e " 0 返回上级菜单 \033[0m"
	echo "-----------------------------------------------"
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		. "$GT_CFG_PATH"
		if [ -n "$TG_CHATID" ];then
			set_bot_tg_service
		else
			echo -e "\033[31m请先绑定TG-BOT！\033[0m"
		fi
		sleep 1
		set_bot_tg
	;;
	2)
		if [ -n "$chat_ID" ] && [ -n "$push_TG" ] && [ "$push_TG" != 'publictoken' ]; then
			read -p "检测到已经绑定了TG推送BOT，是否直接使用？(1/0) > " res
			if [ "$res" = 1 ]; then
				TOKEN="$push_TG"
				set_bot_tg_config
				set_bot_tg
				return
			fi
		fi
		set_bot_tg_init
		set_bot_tg
	;;
	*)
		errornum
	;;
	esac		
}

# 自定义入站
set_vmess() {
    while true; do
        echo "-----------------------------------------------"
        echo -e "\033[31m注意：\033[0m设置的端口会添加到公网访问防火墙并自动放行！\n      脚本只提供基础功能，更多需求请用自定义配置文件功能！"
        echo -e "      \033[31m切勿用于搭建违法翻墙节点，违者后果自负！\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 \033[32m启用/关闭\033[0mVmess入站	\033[32m$vms_service\033[0m"
        echo "-----------------------------------------------"
        echo -e " 2 设置\033[36m监听端口\033[0m：	\033[36m$vms_port\033[0m"
        echo -e " 3 设置\033[33mWS-path(可选)\033[0m：	\033[33m$vms_ws_path\033[0m"
        echo -e " 4 设置\033[36m秘钥-uuid\033[0m：	\033[36m$vms_uuid\033[0m"
        echo -e " 5 一键生成\033[32m随机秘钥\033[0m"
        echo -e " 6 设置\033[36m混淆host(可选)\033[0m：	\033[33m$vms_host\033[0m"
        gen_base64 1 >/dev/null 2>&1 &&
            echo -e " 7 一键生成\033[32m分享链接\033[0m"
        echo -e " 0 返回上级菜单 \033[0m"
        echo "-----------------------------------------------"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$vms_service" = ON ]; then
                vms_service=OFF
                setconfig vms_service "$vms_service"
            else
                if [ -n "$vms_port" ] && [ -n "$vms_uuid" ]; then
                    vms_service=ON
                    setconfig vms_service "$vms_service"
                else
                    echo -e "\033[31m请先完成必选设置！\033[0m"
                    sleep 1
                fi
            fi
            ;;
        2)
            read -p "请输入端口号(输入0删除) > " text
            if [ "$text" = 0 ]; then
                vms_port=''
                setconfig vms_port "" "$GT_CFG_PATH"
            elif check_port "$text"; then
                vms_port="$text"
                setconfig vms_port "$text" "$GT_CFG_PATH"
            else
                sleep 1
            fi
            ;;
        3)
            read -p "请输入ws-path路径(输入0删除) > " text
            if [ "$text" = 0 ]; then
                vms_ws_path=''
                setconfig vms_ws_path "" "$GT_CFG_PATH"
            elif echo "$text" | grep -qE '^/'; then
                vms_ws_path="$text"
                setconfig vms_ws_path "$text" "$GT_CFG_PATH"
            else
                echo -e "\033[31m不是合法的path路径，必须以【/】开头！\033[0m"
                sleep 1
            fi
            ;;
        4)
            read -p "请输入UUID(输入0删除) > " text
            if [ "$text" = 0 ]; then
                vms_uuid=''
                setconfig vms_uuid "" "$GT_CFG_PATH"
            elif echo "$text" | grep -qiE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
                vms_uuid="$text"
                setconfig vms_uuid "$text" "$GT_CFG_PATH"
            else
                echo -e "\033[31m不是合法的UUID格式，请重新输入或使用随机生成功能！\033[0m"
                sleep 1
            fi
            ;;
        5)
            vms_uuid=$(cat /proc/sys/kernel/random/uuid)
            setconfig vms_uuid "$vms_uuid" "$GT_CFG_PATH"
            sleep 1
            ;;
        6)
            read -p "请输入免流混淆host(输入0删除) > " text
            if [ "$text" = 0 ]; then
                vms_host=''
                setconfig vms_host "" "$GT_CFG_PATH"
            else
                vms_host="$text"
                setconfig vms_host "$text" "$GT_CFG_PATH"
            fi
            ;;
        7)
            read -p "请输入本机公网IP(4/6)或域名 > " host_wan
            if [ -n "$host_wan" ] && [ -n "$vms_port" ] && [ -n "$vms_uuid" ]; then
                [ -n "$vms_ws_path" ] && vms_net=ws
                vms_json=$(
                    cat <<EOF
{
  "v": "2",
  "ps": "ShellCrash_vms_in",
  "add": "$host_wan",
  "port": "$vms_port",
  "id": "$vms_uuid",
  "aid": "0",
  "type": "auto",
  "net": "$vms_net",
  "path": "$vms_ws_path",
  "host": "$vms_host"
}
EOF
                )
                vms_link="vmess://$(gen_base64 "$vms_json")"
                echo "-----------------------------------------------"
                echo -e "你的分享链接是(请勿随意分享给他人):\n\033[32m$vms_link\033[0m"
            else
                echo -e "\033[31m请先完成必选设置！\033[0m"
            fi
            sleep 1
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}

set_shadowsocks(){
	echo "-----------------------------------------------"
	echo -e "\033[31m注意：\033[0m设置的端口会添加到公网访问防火墙并自动放行！\n      脚本只提供基础功能，更多需求请用自定义配置文件功能！"
	echo -e "      \033[31m切勿用于搭建违法翻墙节点，违者后果自负！\033[0m"
	echo "-----------------------------------------------"
	echo -e " 1 \033[32m启用/关闭\033[0mShadowSocks入站	\033[32m$sss_service\033[0m"
	echo "-----------------------------------------------"
	echo -e " 2 设置\033[36m监听端口\033[0m：	\033[36m$sss_port\033[0m"
	echo -e " 3 选择\033[33m加密协议\033[0m：	\033[33m$sss_cipher\033[0m"
	echo -e " 4 设置\033[36mpassword\033[0m：	\033[36m$sss_pwd\033[0m"
	gen_base64 1 >/dev/null 2>&1 &&
	echo -e " 5 一键生成分享链接"
	echo -e " 0 返回上级菜单 \033[0m"
	echo "-----------------------------------------------"
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		if [ "$sss_service" = ON ];then
			sss_service=OFF
			setconfig sss_service "$sss_service"
		else
			if [ -n "$sss_port" ] && [ -n "$sss_cipher" ] && [ -n "$sss_pwd" ];then
				sss_service=ON
				setconfig sss_service "$sss_service"
			else
				echo -e "\033[31m请先完成必选设置！\033[0m"
				sleep 1
			fi
		fi
		set_shadowsocks
	;;
	2)
		read -p "请输入端口号(输入0删除) > " text
		if [ "$text" = 0 ];then
			sss_port=''
			setconfig sss_port "" "$GT_CFG_PATH"
		elif check_port "$text"; then
			sss_port="$text"
			setconfig sss_port "$text" "$GT_CFG_PATH"
		else
			sleep 1
		fi
		set_shadowsocks
	;;
	3)
		echo "-----------------------------------------------"
		echo -e " 1 \033[32mxchacha20-ietf-poly1305\033[0m"
		echo -e " 2 \033[32mchacha20-ietf-poly1305\033[0m"
		echo -e " 3 \033[32maes-128-gcm\033[0m"
		echo -e " 4 \033[32maes-256-gcm\033[0m"
		gen_random 1 >/dev/null && {
			echo "-----------------------------------------------"
			echo -e "\033[31m注意：\033[0m2022系列加密必须使用随机生成的password！"
			echo -e " 5 \033[32m2022-blake3-chacha20-poly1305\033[0m"
			echo -e " 6 \033[32m2022-blake3-aes-128-gcm\033[0m"
			echo -e " 7 \033[32m2022-blake3-aes-256-gcm\033[0m"
		}
		echo "-----------------------------------------------"
		echo -e " 0 返回上级菜单"
		read -p "请选择要使用的加密协议 > " num
		case "$num" in
		1)
			sss_cipher=xchacha20-ietf-poly1305
			sss_pwd=$(gen_random 16)
		;;
		2)
			sss_cipher=chacha20-ietf-poly1305
			sss_pwd=$(gen_random 16)
		;;
		3)
			sss_cipher=aes-128-gcm
			sss_pwd=$(gen_random 16)
		;;
		4)
			sss_cipher=aes-256-gcm
			sss_pwd=$(gen_random 16)
		;;
		5)
			sss_cipher=2022-blake3-chacha20-poly1305
			sss_pwd=$(gen_random 32)
		;;
		6)
			sss_cipher=2022-blake3-aes-128-gcm
			sss_pwd=$(gen_random 16)
		;;
		7)
			sss_cipher=2022-blake3-aes-256-gcm
			sss_pwd=$(gen_random 32)
		;;
		*)
		;;
		esac
		setconfig sss_cipher "$sss_cipher" "$GT_CFG_PATH"
		setconfig sss_pwd "$sss_pwd" "$GT_CFG_PATH"
		set_shadowsocks
	;;
	4)
		if echo "$sss_cipher" |grep -q '2022-blake3';then
			echo -e "\033[31m注意：\033[0m2022系列加密必须使用脚本随机生成的password！"
			sleep 1
		else
			read -p "请输入秘钥(输入0删除) > " text
			[ "$text" = 0 ] && sss_pwd='' || sss_pwd="$text"
			setconfig sss_pwd "$text" "$GT_CFG_PATH"
		fi
		set_shadowsocks
	;;
	5)
		read -p "请输入本机公网IP(4/6)或域名 > " text
		if [ -n "$text" ] && [ -n "$sss_port" ] && [ -n "$sss_cipher" ] && [ -n "$sss_pwd" ];then
			ss_link="ss://$(gen_base64 "$sss_cipher":"$sss_pwd")@${text}:${sss_port}#ShellCrash_ss_in"
			echo "-----------------------------------------------"
			echo -e "你的分享链接是(请勿随意分享给他人):\n\033[32m$ss_link\033[0m"
		else
			echo -e "\033[31m请先完成必选设置！\033[0m"
		fi
		sleep 1
		set_shadowsocks
	;;
	*) errornum ;;
	esac		
}
#自定义端点
set_tailscale(){
	[ -n "$ts_auth_key" ] && ts_auth_key_info='*********'
	echo "-----------------------------------------------"
	echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！"
	echo -e "创建秘钥:\033[32;4mhttps://login.tailscale.com/admin/settings/keys\033[0m"
	echo -e "访问非本机目标需允许通告:\033[32;4mhttps://login.tailscale.com\033[0m"
	echo -e "访问非本机目标需在终端设置使用Subnet或EXIT-NODE模式"
	echo "-----------------------------------------------"
	echo -e " 1 \033[32m启用/关闭\033[0mTailscale服务	\033[32m$ts_service\033[0m"
	echo -e " 2 设置\033[36m秘钥\033[0m(Auth Key)		$ts_auth_key_info"
	echo -e " 3 通告路由\033[33m内网地址\033[0m(Subnet)	\033[36m$ts_subnet\033[0m"
	echo -e " 4 通告路由\033[31m全部流量\033[0m(EXIT-NODE)	\033[36m$ts_exit_node\033[0m"
	echo -e " 5 设置\033[36m设备名称\033[0m(可选)		$ts_hostname"
	echo -e " 0 返回上级菜单 \033[0m"
	echo "-----------------------------------------------"
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
		setconfig ts_auth_key "$ts_auth_key" "$GT_CFG_PATH"
		set_tailscale
	;;
	3)
		[ "$ts_subnet" = true ] && ts_subnet=false || ts_subnet=true
		setconfig ts_subnet "$ts_subnet" "$GT_CFG_PATH"
		set_tailscale
	;;
	4)
		[ "$ts_exit_node" = true ] && ts_exit_node=false || {
			ts_exit_node=true
			echo -e "\033[31m注意：\033[0m目前exitnode的官方DNS有bug，要么启用域名嗅探并禁用TailscaleDNS，\n要么必须在网页设置Globalname servers为分配的本设备子网IP且启用override"
			sleep 3
		}
		setconfig ts_exit_node "$ts_exit_node" "$GT_CFG_PATH"
		set_tailscale
	;;
	5)
		read -p "请输入希望在Tailscale显示的设备名称 > " ts_hostname
		setconfig ts_hostname "$ts_hostname" "$GT_CFG_PATH"
		set_tailscale
	;;
	*) errornum ;;
	esac		
}
set_wireguard(){
	[ -n "$wg_public_key" ] && wgp_key_info='*********' || unset wgp_key_info
	[ -n "$wg_private_key" ] && wgv_key_info='*********' || unset wgv_key_info
	[ -n "$wg_pre_shared_key" ] && wgpsk_key_info='*********' || unset wgpsk_key_info
	echo "-----------------------------------------------"
	echo -e "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译WireGuard模块\n如需使用请先前往自定义内核更新完整版内核文件！"
	echo "-----------------------------------------------"
	echo -e " 1 \033[32m启用/关闭\033[0mWireguard服务	\033[32m$wg_service\033[0m"
	echo "-----------------------------------------------"
	echo -e " 2 设置\033[36mEndpoint地址\033[0m：		\033[36m$wg_server\033[0m"
	echo -e " 3 设置\033[36mEndpoint端口\033[0m：		\033[36m$wg_port\033[0m"
	echo -e " 4 设置\033[36m公钥-PublicKey\033[0m：		\033[36m$wgp_key_info\033[0m"
	echo -e " 5 设置\033[36m密钥-PresharedKey\033[0m：	\033[36m$wgpsk_key_info\033[0m"
	echo "-----------------------------------------------"
	echo -e " 6 设置\033[33m私钥-PrivateKey\033[0m：	\033[33m$wgv_key_info\033[0m"
	echo -e " 7 设置\033[33m组网IPV4地址\033[0m：		\033[33m$wg_ipv4\033[0m"
	echo -e " 8 可选\033[33m组网IPV6地址\033[0m：	\033[33m$wg_ipv6\033[0m"
	echo -e " 0 返回上级菜单 \033[0m"
	echo "-----------------------------------------------"
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
			setconfig wg_server "$text" "$GT_CFG_PATH"
		;;
		3)
			wg_port="$text"
			setconfig wg_port "$text" "$GT_CFG_PATH"
		;;
		4)
			wg_public_key="$text"
			setconfig wg_public_key "$text" "$GT_CFG_PATH"
		;;
		5)
			wg_pre_shared_key="$text"
			setconfig wg_pre_shared_key "$text" "$GT_CFG_PATH"
		;;
		6)
			wg_private_key="$text"
			setconfig wg_private_key "$text" "$GT_CFG_PATH"
		;;
		7)
			wg_ipv4="$text"
			setconfig wg_ipv4 "$text" "$GT_CFG_PATH"
		;;
		8)
			wg_ipv6="$text"
			setconfig wg_ipv6 "$text" "$GT_CFG_PATH"
		;;

		esac
		set_wireguard
	;;
	*) errornum ;;
	esac		
}

