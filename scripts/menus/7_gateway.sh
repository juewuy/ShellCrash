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
        comp_box "\033[30;47m访问与控制菜单\033[0m"
        content_line "1) 配置\033[33m公网访问防火墙			\033[32m$fw_wan\033[0m"
        content_line "2) 配置\033[36mTelegram专属控制机器人		\033[32m$bot_tg_service\033[0m"
        content_line "3) 配置\033[36mDDNS自动域名\033[0m"
        [ "$disoverride" != "1" ] && {
            content_line "4) 自定义\033[33m公网Vmess入站\033[0m节点		\033[32m$vms_service\033[0m"
            content_line "5) 自定义\033[33m公网ShadowSocks入站\033[0m节点	\033[32m$sss_service\033[0m"
            content_line "6) 配置\033[36mTailscale内网穿透\033[0m（限Singbox）	\033[32m$ts_service\033[0m"
            content_line "7) 配置\033[36mWireguard客户端\033[0m（限Singbox）	\033[32m$wg_service\033[0m"
        }
        btm_box "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$(pidof CrashCore)" ] && [ "$firewall_mod" = 'iptables' ]; then
                comp_box "\033[33m公网访问防火墙需要先停止服务\033[0m" \
                    "是否确认继续？"
                btm_box "1) 是" \
                    "0) 否，返回上级菜单"
                read -r -p "请输入对应标号> " res
                if [ "$res" = 1 ]; then
                    "$CRASHDIR"/start.sh stop && set_fw_wan
                else
                    continue
                fi
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
                msg_alert "\033[33m$crashcore内核暂不支持此功能，请先更换内核！\033[0m"
            fi
            ;;
        7)
            if echo "$crashcore" | grep -q 'sing'; then
                set_wireguard
            else
                msg_alert "\033[33m$crashcore内核暂不支持此功能，请先更换内核！\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 公网防火墙
set_fw_wan() {
    while true; do
        [ -z "$fw_wan" ] && fw_wan=ON
        line_break
        separator_line "="
        content_line "\033[31m注意：\033[0m如在vps运行，还需在vps安全策略对相关端口同时放行"
        [ -n "$fw_wan_ports" ] &&
            content_line "当前手动放行端口：\033[36m$fw_wan_ports\033[0m"
        [ -n "$vms_port$sss_port" ] &&
            content_line "当前自动放行端口：\033[36m$vms_port $sss_port\033[0m"
        content_line "默认拦截端口：\033[33m$mix_port,$db_port\033[0m"
        separator_line "="
        btm_box "1) 启用/关闭公网防火墙：\033[36m$fw_wan\033[0m" \
            "2) 添加放行端口（可包含默认拦截端口）" \
            "3) 移除指定手动放行端口" \
            "4) 清空全部手动放行端口" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case $num in
        "" | 0)
            break
            ;;
        1)
            if [ "$fw_wan" = ON ]; then
                comp_box "是否确认关闭防火墙？" \
                    "这会带来极大的安全隐患！"
                btm_box "1) 是" \
                    "0) 否，返回上级菜单"
                read -r -p "请输入对应标号> " res
                if [ "$res" = 1 ]; then
                    fw_wan=OFF
                else
                    fw_wan=ON
                fi
            else
                fw_wan=ON
            fi
            setconfig fw_wan "$fw_wan"
            ;;
        2)
            port_count=$(echo "$fw_wan_ports" | awk -F',' '{print NF}')
            if [ "$port_count" -ge 10 ]; then
                msg_alert "\033[31m最多支持设置放行10个端口，请先减少一些！\033[0m"
            else
                line_break
                read -r -p "请输入要放行的端口号> " port
                if echo ",$fw_wan_ports," | grep -q ",$port,"; then
                    msg_alert "\033[31m输入错误！请勿重复添加！\033[0m"
                elif [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                    msg_alert "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
                else
                    fw_wan_ports=$(echo "$fw_wan_ports,$port" | sed "s/^,//")
                    if setconfig fw_wan_ports "$fw_wan_ports"; then
                        common_success
                    else
                        common_faileds
                    fi
                fi
            fi
            ;;
        3)
            while true; do
                comp_box "\033[36m请直接输入要移除的端口号\033[0m" \
                    "或输入 0 返回上级菜单"
                read -r -p "请输入> " port
                if [ "$port" = 0 ]; then
                    break
                elif echo ",$fw_wan_ports," | grep -q ",$port,"; then
                    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                        msg_alert "\033[31m输入错误！\033[0m" \
                            "\033[31m请输入正确的数值(1-65535)！\033[0m"
                    else
                        fw_wan_ports=$(echo ",$fw_wan_ports," | sed "s/,$port//; s/^,//; s/,$//")
                        setconfig fw_wan_ports "$fw_wan_ports"
                        break
                    fi
                else
                    msg_alert "\033[31m输入错误！\033[0m" \
                        "\033[31m请输入已添加过的端口！\033[0m"
                fi
            done
            ;;
        4)
            fw_wan_ports=''
            setconfig fw_wan_ports
            msg_alert "\033[32m操作成功\033[0m"
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# tg_BOT相关
set_bot_tg_config() {
    setconfig TG_TOKEN "$TOKEN" "$GT_CFG_PATH"
    setconfig TG_CHATID "$chat_ID" "$GT_CFG_PATH"
    # 设置机器人快捷命令
    JSON=$(
        cat <<EOF
{
  "commands": [
    {"command": "$my_alias", "description": "呼出ShellCrash菜单"},
    {"command": "help",  "description": "查看帮助"}
  ]
}
EOF
    )
    TEXT="已完成Telegram机器人设置！请使用 /$my_alias 呼出功能菜单！"
    . "$CRASHDIR"/libs/web_json.sh
    bot_api="https://api.telegram.org/bot$TOKEN"
    web_json_post "$bot_api/setMyCommands" "$JSON"
    web_json_post "$bot_api/sendMessage" '{"chat_id":"'"$chat_ID"'","text":"'"$TEXT"'","parse_mode":"Markdown"}'

    comp_box "\033[32m$TEXT\033[0m"
}

set_bot_tg_init() {
    . "$CRASHDIR"/menus/bot_tg_bind.sh && private_bot && set_bot
    if [ "$?" = 0 ]; then
        set_bot_tg_config
        return 0
    else
        return 1
    fi
}

set_bot_tg_service() {
    if [ "$bot_tg_service" = ON ]; then
        bot_tg_service=OFF
        . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_stop
    else
        bot_tg_service=ON
        [ -n "$(pidof CrashCore)" ] && . "$CRASHDIR"/menus/bot_tg_service.sh && 
            bot_tg_start && bot_tg_cron
    fi
    setconfig bot_tg_service "$bot_tg_service"
}

set_bot_tg() {
    while true; do
        [ -n "$ts_auth_key" ] && ts_auth_key_info='已设置'
        [ -n "$TG_CHATID" ] && TG_CHATID_info='已绑定'
        comp_box "\033[31m注意：\033[0m由于网络环境原因，此机器人仅限服务启动时运行！"
        btm_box "1) 启用／关闭TG-BOT服务	\033[32m$bot_tg_service\033[0m" \
            "2) TG-BOT绑定设置	\033[32m$TG_CHATID_info\033[0m" \
			"3) 启动时推送菜单	\033[32m$TG_menupush\033[0m" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            . "$GT_CFG_PATH"
            if [ -n "$TG_CHATID" ]; then
                set_bot_tg_service
            else
                msg_alert "\033[31m请先绑定TG-BOT！\033[0m"
            fi
            ;;
        2)
            if [ -n "$chat_ID" ] && [ -n "$push_TG" ] && [ "$push_TG" != 'publictoken' ]; then
                comp_box "检测到已经绑定了TG推送BOT" \
                    "是否直接使用？"
                btm_box "1) 是" \
                    "0) 否"
                read -r -p "请输入对应标号> " res
                if [ "$res" = 1 ]; then
                    TOKEN="$push_TG"
                    set_bot_tg_config
                    continue
                fi
            fi
            set_bot_tg_init
            ;;
        3)
            if [ "$TG_menupush" = ON ];then
                TG_menupush=OFF
            else
                TG_menupush=ON
            fi
            setconfig TG_menupush "$TG_menupush" "$GT_CFG_PATH"
            set_bot_tg
	;;
        *)
            errornum
            ;;
        esac
    done
}

# 自定义入站
set_vmess() {
    while true; do
        comp_box "\033[31m注意：\033[0m" \
            "设置的端口会添加到公网访问防火墙并自动放行！" \
            "脚本只提供基础功能，更多需求请用自定义配置文件功能！" \
            "\033[31m切勿用于搭建违法翻墙节点，违者后果自负！\033[0m"
        content_line "1) \033[32m启用/关闭\033[0mVmess入站	\033[32m$vms_service\033[0m"
        content_line "2) 设置\033[36m监听端口\033[0m：	\033[36m$vms_port\033[0m"
        content_line "3) 设置\033[33mWS-path（可选）\033[0m：	\033[33m$vms_ws_path\033[0m"
        content_line "4) 设置\033[36m秘钥-uuid\033[0m：	\033[36m$vms_uuid\033[0m"
        content_line "5) 一键生成\033[32m随机秘钥\033[0m"
        gen_base64 1 >/dev/null 2>&1 &&
            content_line "6) 设置\033[36m混淆host（可选）\033[0m：	\033[33m$vms_host\033[0m"
        btm_box "7) 一键生成\033[32m分享链接\033[0m" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
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
                    msg_alert "\033[31m请先完成必选设置！\033[0m"
                fi
            fi
            ;;
        2)
            line_break
            read -r -p "请输入端口号（输入0删除）> " text
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
            line_break
            read -r -p "请输入ws-path路径（输入0删除）> " text
            if [ "$text" = 0 ]; then
                vms_ws_path=''
                setconfig vms_ws_path "" "$GT_CFG_PATH"
            elif echo "$text" | grep -qE '^/'; then
                vms_ws_path="$text"
                setconfig vms_ws_path "$text" "$GT_CFG_PATH"
            else
                msg_alert "\033[31m不是合法的path路径，必须以【/】开头！\033[0m"
            fi
            ;;
        4)
            line_break
            read -r -p "请输入UUID（输入0删除）> " text
            if [ "$text" = 0 ]; then
                vms_uuid=''
                setconfig vms_uuid "" "$GT_CFG_PATH"
            elif echo "$text" | grep -qiE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'; then
                vms_uuid="$text"
                setconfig vms_uuid "$text" "$GT_CFG_PATH"
            else
                msg_alert "\033[31m不是合法的UUID格式，请重新输入或使用随机生成功能！\033[0m"
            fi
            ;;
        5)
            vms_uuid=$(cat /proc/sys/kernel/random/uuid)
            setconfig vms_uuid "$vms_uuid" "$GT_CFG_PATH"
            sleep 1
            ;;
        6)
            line_break
            read -r -p "请输入免流混淆host（输入0删除）> " text
            if [ "$text" = 0 ]; then
                vms_host=''
                setconfig vms_host "" "$GT_CFG_PATH"
            else
                vms_host="$text"
                setconfig vms_host "$text" "$GT_CFG_PATH"
            fi
            ;;
        7)
            line_break
            read -r -p "请输入本机公网IP(4/6)或域名> " host_wan
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
                line_break
                echo -e "你的分享链接是（请勿随意分享给他人）：\n\033[32m$vms_link\033[0m"
                sleep 1
            else
                msg_alert "\033[31m请先完成必选设置！\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_shadowsocks() {
    while true; do
        comp_box "\033[31m注意：\033[0m" \
            "设置的端口会添加到公网访问防火墙并自动放行！" \
            "脚本只提供基础功能，更多需求请用自定义配置文件功能！" \
            "\033[31m切勿用于搭建违法翻墙节点，违者后果自负！\033[0m"
        content_line "1) \033[32m启用/关闭\033[0mShadowSocks入站	\033[32m$sss_service\033[0m"
        content_line "2) 设置\033[36m监听端口\033[0m：	\033[36m$sss_port\033[0m"
        content_line "3) 选择\033[33m加密协议\033[0m：	\033[33m$sss_cipher\033[0m"
        content_line "4) 设置\033[36mpassword\033[0m：	\033[36m$sss_pwd\033[0m"
        gen_base64 1 >/dev/null 2>&1 &&
            content_line "5) 一键生成分享链接"
        btm_box "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ "$sss_service" = ON ]; then
                sss_service=OFF
                setconfig sss_service "$sss_service"
            else
                if [ -n "$sss_port" ] && [ -n "$sss_cipher" ] && [ -n "$sss_pwd" ]; then
                    sss_service=ON
                    setconfig sss_service "$sss_service"
                else
                    msg_alert "\033[31m请先完成必选设置！\033[0m"
                fi
            fi
            ;;
        2)
            line_break
            read -r -p "请输入端口号（输入0删除）> " text
            if [ "$text" = 0 ]; then
                sss_port=''
                setconfig sss_port "" "$GT_CFG_PATH"
            elif check_port "$text"; then
                sss_port="$text"
                setconfig sss_port "$text" "$GT_CFG_PATH"
            else
                sleep 1
            fi
            ;;
        3)
            comp_box "请选择要使用的加密协议："
            content_line "1) \033[32mxchacha20-ietf-poly1305\033[0m"
            content_line "2) \033[32mchacha20-ietf-poly1305\033[0m"
            content_line "3) \033[32maes-128-gcm\033[0m"
            content_line "4) \033[32maes-256-gcm\033[0m"
            gen_random 1 >/dev/null && {
                content_line ""
                content_line "   - - - - - - -\033[31m注意\033[0m- - - - - - -"
                content_line "   2022系列加密必须使用随机生成的password！"
                content_line "5) \033[32m2022-blake3-chacha20-poly1305\033[0m"
                content_line "6) \033[32m2022-blake3-aes-128-gcm\033[0m"
                content_line "7) \033[32m2022-blake3-aes-256-gcm\033[0m"
            }
            btm_box "" \
                "0) 返回上级菜单"
            read -r -p "请输入对应标号> " num
            case "$num" in
            0) ;;
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
                errornum
                ;;
            esac
            setconfig sss_cipher "$sss_cipher" "$GT_CFG_PATH"
            setconfig sss_pwd "$sss_pwd" "$GT_CFG_PATH"
            ;;
        4)
            if echo "$sss_cipher" | grep -q '2022-blake3'; then
                msg_alert "\033[31m注意：\033[0m2022系列加密必须使用脚本随机生成的password！"
            else
                line_break
                read -r -p "请输入秘钥（输入0删除）> " text
                [ "$text" = 0 ] && sss_pwd='' || sss_pwd="$text"
                setconfig sss_pwd "$text" "$GT_CFG_PATH"
            fi
            ;;
        5)
            line_break
            read -r -p "请输入本机公网IP(4/6)或域名> " text
            if [ -n "$text" ] && [ -n "$sss_port" ] && [ -n "$sss_cipher" ] && [ -n "$sss_pwd" ]; then
                ss_link="ss://$(gen_base64 "$sss_cipher":"$sss_pwd")@${text}:${sss_port}#ShellCrash_ss_in"
                line_break
                echo -e "你的分享链接是（请勿随意分享给他人）：\n\033[32m$ss_link\033[0m"
                sleep 1
            else
                msg_alert "\033[31m请先完成必选设置！\033[0m"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 自定义端点
set_tailscale() {
    while true; do
        [ -n "$ts_auth_key" ] && ts_auth_key_info='*********'
        comp_box "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译Tailscale模块\n如需使用请先前往自定义内核更新完整版内核文件！" \
            "创建秘钥:\033[32;4mhttps://login.tailscale.com/admin/settings/keys\033[0m" \
            "访问非本机目标需允许通告:\033[32;4mhttps://login.tailscale.com\033[0m" \
            "访问非本机目标需在终端设置使用Subnet或EXIT-NODE模式"
        btm_box "1) \033[32m启用/关闭\033[0mTailscale服务	\033[32m$ts_service\033[0m" \
            "2) 设置\033[36m秘钥\033[0m（Auth Key）		$ts_auth_key_info" \
            "3) 通告路由\033[33m内网地址\033[0m（Subnet）	\033[36m$ts_subnet\033[0m" \
            "4) 通告路由\033[31m全部流量\033[0m（EXIT-NODE）	\033[36m$ts_exit_node\033[0m" \
            "5) 设置\033[36m设备名称\033[0m（可选）		$ts_hostname" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$ts_auth_key" ]; then
                [ "$ts_service" = ON ] && ts_service=OFF || ts_service=ON
                setconfig ts_service "$ts_service"
            else
                msg_alert "\033[31m请先设置秘钥！\033[0m"
            fi
            ;;
        2)
            line_break
            read -r -p "请输入秘钥（输入0删除）> " text
            [ "$text" = 0 ] && unset ts_auth_key ts_auth_key_info || ts_auth_key="$text"
            setconfig ts_auth_key "$ts_auth_key" "$GT_CFG_PATH"
            ;;
        3)
            [ "$ts_subnet" = true ] && ts_subnet=false || ts_subnet=true
            setconfig ts_subnet "$ts_subnet" "$GT_CFG_PATH"
            ;;
        4)
            if [ "$ts_exit_node" = true ]; then
                ts_exit_node=false
            else
                ts_exit_node=true
                msg_alert -t 3 "\033[31m注意：\033[0m目前exitnode的官方DNS有bug，要么启用域名嗅探并禁用TailscaleDNS，\n要么必须在网页设置Globalname servers为分配的本设备子网IP且启用override"
            fi
            setconfig ts_exit_node "$ts_exit_node" "$GT_CFG_PATH"
            ;;
        5)
            comp_box "\033[36m请直接输入希望在Tailscale显示的设备名称\033[0m" \
                "或输入 0 返回上级菜单"
            read -r -p "请输入> " ts_hostname
            if [ "$ts_hostname" != 0 ]; then
                setconfig ts_hostname "$ts_hostname" "$GT_CFG_PATH"
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

set_wireguard() {
    while true; do

        if [ -n "$wg_public_key" ]; then
            wgp_key_info='*********'
        else
            unset wgp_key_info
        fi

        if [ -n "$wg_private_key" ]; then
            wgv_key_info='*********'
        else
            unset wgv_key_info
        fi

        if [ -n "$wg_pre_shared_key" ]; then
            wgpsk_key_info='*********'
        else
            unset wgpsk_key_info
        fi
        comp_box "\033[31m注意：\033[0m脚本默认内核为了节约内存没有编译WireGuard模块\n如需使用请先前往自定义内核更新完整版内核文件！"
        btm_box "1) \033[32m启用/关闭\033[0mWireguard服务	\033[32m$wg_service\033[0m" \
            "" \
            "2) 设置\033[36mEndpoint地址\033[0m：		\033[36m$wg_server\033[0m" \
            "3) 设置\033[36mEndpoint端口\033[0m：		\033[36m$wg_port\033[0m" \
            "4) 设置\033[36m公钥-PublicKey\033[0m：		\033[36m$wgp_key_info\033[0m" \
            "5) 设置\033[36m密钥-PresharedKey\033[0m：	\033[36m$wgpsk_key_info\033[0m" \
            "" \
            "6) 设置\033[33m私钥-PrivateKey\033[0m：	\033[33m$wgv_key_info\033[0m" \
            "7) 设置\033[33m组网IPV4地址\033[0m：		\033[33m$wg_ipv4\033[0m" \
            "8) 可选\033[33m组网IPV6地址\033[0m：	\033[33m$wg_ipv6\033[0m" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$wg_server" ] && [ -n "$wg_port" ] && [ -n "$wg_public_key" ] && [ -n "$wg_pre_shared_key" ] && [ -n "$wg_private_key" ] && [ -n "$wg_ipv4" ]; then
                [ "$wg_service" = ON ] && wg_service=OFF || wg_service=ON
                setconfig wg_service "$wg_service"
            else
                msg_alert "\033[31m请先完成必选设置！\033[0m"
            fi
            ;;
        [1-8])
            line_break
            read -r -p "请输入相应内容（回车或0删除）> " text
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
            ;;
        *)
            errornum
            ;;
        esac
    done
}
