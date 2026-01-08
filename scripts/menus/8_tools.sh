#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_8_TOOLS_LOADED" ] && return
__IS_MODULE_8_TOOLS_LOADED=1

. "$CRASHDIR"/libs/logger.sh
. "$CRASHDIR"/libs/web_get_bin.sh

stop_iptables() {
	iptables -w -t nat -D PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 >/dev/null 2>&1
	ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 >/dev/null 2>&1
}

ssh_tools() {
	while true; do
		[ -n "$(cat /etc/firewall.user 2>&1 | grep '启用外网访问SSH服务')" ] && ssh_ol=禁止 || ssh_ol=开启
		[ -z "$ssh_port" ] && ssh_port=10022
		echo "-----------------------------------------------"
		echo -e "\033[33m此功能仅针对使用Openwrt系统的设备生效，且不依赖服务\033[0m"
		echo -e "\033[31m本功能不支持红米AX6S等镜像化系统设备，请勿尝试！\033[0m"
		echo "-----------------------------------------------"
		echo -e " 1 \033[32m修改\033[0m外网访问端口：\033[36m$ssh_port\033[0m"
		echo -e " 2 \033[32m修改\033[0mSSH访问密码(请连续输入2次后回车)"
		echo -e " 3 \033[33m$ssh_ol\033[0m外网访问SSH"
		echo "-----------------------------------------------"
		echo -e " 0 返回上级菜单 \033[0m"
		echo "-----------------------------------------------"
		read -p "请输入对应数字 > " num
		case "$num" in
		""|0) 
			break
			;;
		1)
			read -p "请输入端口号(1000-65535) > " num
			if [ -z "$num" ]; then
				errornum
			elif [ $num -gt 65535 -o $num -le 999 ]; then
				echo -e "\033[31m输入错误！请输入正确的数值(1000-65535)！\033[0m"
			elif [ -n "$(netstat -ntul | grep :$num)" ]; then
				echo -e "\033[31m当前端口已被其他进程占用，请重新输入！\033[0m"
			else
				ssh_port=$num
				setconfig ssh_port $ssh_port
				sed -i "/启用外网访问SSH服务/d" /etc/firewall.user
				stop_iptables
				echo -e "\033[32m设置成功，请重新开启外网访问SSH功能！！！\033[0m"
			fi
			sleep 1
			;;
		2)
			passwd
			sleep 1
			;;
		3)
			if [ "$ssh_ol" = "开启" ]; then
				iptables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22
				[ -n "$(ckcmd ip6tables)" ] && ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22
				echo "iptables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >>/etc/firewall.user
				[ -n "$(ckcmd ip6tables)" ] && echo "ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >>/etc/firewall.user
				echo "-----------------------------------------------"
				echo -e "已开启外网访问SSH功能！"
			else
				sed -i "/启用外网访问SSH服务/d" /etc/firewall.user
				stop_iptables
				echo "-----------------------------------------------"
				echo -e "已禁止外网访问SSH！"
			fi
			break
			;;
		*)
			errornum
			sleep 1
			break
			;;
		esac
	done
}

#工具与优化
tools() {
	while true; do
	    #获取设置默认显示
	    grep -qE "^\s*[^#].*otapredownload" /etc/crontabs/root >/dev/null 2>&1 && mi_update=禁用 || mi_update=启用
	    [ "$mi_mi_autoSSH" = "已配置" ] && mi_mi_autoSSH_type=32m已配置 || mi_mi_autoSSH_type=31m未配置
	    [ -f "$CRASHDIR"/tools/tun.ko ] && mi_tunfix=32mON || mi_tunfix=31mOFF
	
	    echo "-----------------------------------------------"
	    echo -e "\033[30;47m欢迎使用其他工具菜单：\033[0m"
	    echo -e "\033[33m本页工具可能无法兼容全部Linux设备，请酌情使用！\033[0m"
	    echo -e "磁盘占用/所在目录："
	    du -sh "$CRASHDIR"
	    echo "-----------------------------------------------"
	    echo -e " 1 ShellCrash\033[33m测试菜单\033[0m"
	    echo -e " 2 ShellCrash\033[32m新手引导\033[0m"
	    echo -e " 3 \033[36m日志及推送工具\033[0m"
	    [ -f /etc/firewall.user ] && echo -e " 4 \033[32m配置\033[0m外网访问SSH"
	    [ -x /usr/sbin/otapredownload ] && echo -e " 5 \033[33m$mi_update\033[0m小米系统自动更新"
	    [ "$systype" = "mi_snapshot" ] && echo -e " 6 小米设备软固化SSH ———— \033[$mi_mi_autoSSH_type \033[0m"
	    [ "$systype" = "mi_snapshot" ] && echo -e " 8 小米设备Tun模块修复 ———— \033[$mi_tunfix \033[0m"
	    echo "-----------------------------------------------"
	    echo -e " 0 返回上级菜单"
	    echo "-----------------------------------------------"
	    read -p "请输入对应数字 > " num
		case "$num" in
	    ""|0)
			break
	        ;;
	    1)
	        testcommand
			break
	        ;;
	    2)
	        userguide
			break
	        ;;
	    3)
	        log_pusher
	        ;;
	    4)
			ssh_tools
			sleep 1
	        ;;
	    5)
	        if [ -x /usr/sbin/otapredownload ]; then
	            if [ "$mi_update" = "禁用" ]; then
	                grep -q "otapredownload" /etc/crontabs/root &&
	                    sed -i "/^[^\#]*otapredownload/ s/^/#/" /etc/crontabs/root ||
	                    echo "#15 3,4,5 * * * /usr/sbin/otapredownload >/dev/null 2>&1" >>/etc/crontabs/root
	            else
	                grep -q "otapredownload" /etc/crontabs/root &&
	                    sed -i "/^\s*#.*otapredownload/ s/^\s*#//" /etc/crontabs/root ||
	                    echo "15 3,4,5 * * * /usr/sbin/otapredownload >/dev/null 2>&1" >>/etc/crontabs/root
	            fi
	            echo "-----------------------------------------------"
	            echo -e "已\033[33m$mi_update\033[0m小米路由器的自动更新，如未生效，请在官方APP中同步设置！"
	            sleep 1
	        fi
	        ;;
	    6)
	        if [ "$systype" = "mi_snapshot" ]; then
	            mi_autoSSH
	        else
	            echo "不支持的设备！"
	        fi
	        ;;
	    7)
	        echo "-----------------------------------------------"
	        if [ ! -f "$CRASHDIR"/tools/ShellDDNS.sh ]; then
	            echo -e "正在获取在线脚本……"
	            get_bin "$TMPDIR"/ShellDDNS.sh tools/ShellDDNS.sh
	            if [ "$?" = "0" ]; then
	                mv -f "$TMPDIR"/ShellDDNS.sh "$CRASHDIR"/tools/ShellDDNS.sh
	                . "$CRASHDIR"/tools/ShellDDNS.sh
	            else
	                echo -e "\033[31m文件下载失败！\033[0m"
	            fi
	        else
	            . "$CRASHDIR"/tools/ShellDDNS.sh
	        fi
	        sleep 1
	        ;;
	    8)
	        if [ -f "$CRASHDIR"/tools/tun.ko ]; then
	            read -p "是否禁用此功能并移除相关补丁？(1/0) > " res
	            [ "$res" = 1 ] && {
	                rm -rf "$CRASHDIR"/tools/tun.ko
	                echo -e "\033[33m补丁文件已移除，请立即重启设备以防止出错！\033[0m"
	            }
	        elif ckcmd modinfo && [ -z "$(modinfo tun)" ]; then
	            echo -e "\033[33m本功能需要修改系统文件，不保证没有任何风险！\033[0m"
	            echo -e "\033[33m本功能采集的Tun模块并不一定适用于你的设备！\033[0m"
	            sleep 1
	            read -p "我已知晓，出现问题会自行承担！(1/0) > " res
	            if [ "$res" = 1 ]; then
	                echo "-----------------------------------------------"
	                echo "正在连接服务器获取Tun模块补丁文件…………"
	                get_bin "$TMPDIR"/tun.ko bin/fix/tun.ko
	                if [ "$?" = "0" ]; then
	                    mv -f "$TMPDIR"/tun.ko "$CRASHDIR"/tools/tun.ko &&
	                        /data/shellcrash_init.sh tunfix &&
	                        echo -e "\033[32m设置成功！请重启服务！\033[0m"
	                else
	                    echo -e "\033[31m文件下载失败，请重试！\033[0m"
	                fi
	            fi
	        else
	            echo -e "\033[31m当前设备无需设置，请勿尝试！\033[0m"
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

mi_autoSSH() {
    echo "-----------------------------------------------"
    echo -e "\033[33m本功能使用软件命令进行固化不保证100%成功！\033[0m"
    echo -e "\033[33m如有问题请加群反馈：\033[36;4mhttps://t.me/ShellClash\033[0m"
    read -p "请输入需要还原的SSH密码(不影响当前密码,回车可跳过) > " mi_mi_autoSSH_pwd
    mi_mi_autoSSH=已配置
    cp -f /etc/dropbear/dropbear_rsa_host_key "$CRASHDIR"/configs/dropbear_rsa_host_key 2>/dev/null
    cp -f /etc/dropbear/authorized_keys "$CRASHDIR"/configs/authorized_keys 2>/dev/null
    ckcmd nvram && {
        nvram set ssh_en=1
        nvram set telnet_en=1
        nvram set uart_en=1
        nvram set boot_wait=on
        nvram commit
    }
    echo -e "\033[32m设置成功！\033[0m"
    setconfig mi_mi_autoSSH $mi_mi_autoSSH
    setconfig mi_mi_autoSSH_pwd $mi_mi_autoSSH_pwd
    sleep 1
}

#日志菜单
log_pusher() {
	while true; do
	    [ -n "$push_TG" ] && stat_TG=32mON || stat_TG=33mOFF
	    [ -n "$push_Deer" ] && stat_Deer=32mON || stat_Deer=33mOFF
	    [ -n "$push_bark" ] && stat_bark=32mON || stat_bark=33mOFF
	    [ -n "$push_Po" ] && stat_Po=32mON || stat_Po=33mOFF
	    [ -n "$push_PP" ] && stat_PP=32mON || stat_PP=33mOFF
	    [ -n "$push_SynoChat" ] && stat_SynoChat=32mON || stat_SynoChat=33mOFF
	    [ -n "$push_Gotify" ] && stat_Gotify=32mON || stat_Gotify=33mOFF
	    [ "$task_push" = 1 ] && stat_task=32mON || stat_task=33mOFF
	    [ -n "$device_name" ] && device_s=32m$device_name || device_s=33m未设置
	    echo "-----------------------------------------------"
	    echo -e " 1 Telegram推送	——\033[$stat_TG\033[0m"
	    echo -e " 2 PushDeer推送	——\033[$stat_Deer\033[0m"
	    echo -e " 3 Bark推送-IOS	——\033[$stat_bark\033[0m"
	    echo -e " 4 Passover推送	——\033[$stat_Po\033[0m"
	    echo -e " 5 PushPlus推送	——\033[$stat_PP\033[0m"
	    echo -e " 6 SynoChat推送	——\033[$stat_SynoChat\033[0m"
	    echo -e " 7 Gotify推送	——\033[$stat_Gotify\033[0m"
	    echo "-----------------------------------------------"
	    echo -e " a 查看\033[36m运行日志\033[0m"
	    echo -e " b 推送任务日志	——\033[$stat_task\033[0m"
	    echo -e " c 设置设备名称	——\033[$device_s\033[0m"
	    echo -e " d 清空日志文件"
	    echo "-----------------------------------------------"
		echo -e " 0 返回上级菜单"
		echo "-----------------------------------------------"
	    read -p "请输入对应数字 > " num
	    case "$num" in
		""|0)
			break
			;;
	    1)
	        echo "-----------------------------------------------"
	        if [ -n "$push_TG" ]; then
	            read -p "确认关闭TG日志推送？(1/0) > " res
	            [ "$res" = 1 ] && {
	                push_TG=
	                chat_ID=
	                setconfig push_TG
	                setconfig chat_ID
	            }
	        else
	            #echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
	            . "$CRASHDIR"/menus/bot_tg_bind.sh
	            chose_bot() {
	                echo "-----------------------------------------------"
	                echo -e " 1 使用公共机器人	——不依赖内核服务"
	                echo -e " 2 使用私人机器人	——需要额外申请"
	                echo "-----------------------------------------------"
	                read -p "请输入对应数字 > " num
	                case $num in
	                1)
	                    public_bot
	                    set_bot && tg_push_token || chose_bot
	            	;;
	                2)
	                    private_bot
	                    set_bot && tg_push_token || chose_bot
	            	;;
	                *)
	                    errornum
	            	;;
	                esac
	            }
	            chose_bot
	        fi
	        sleep 1
			;;
	    2)
	        echo "-----------------------------------------------"
	        if [ -n "$push_Deer" ]; then
	            read -p "确认关闭PushDeer日志推送？(1/0) > " res
	            [ "$res" = 1 ] && {
	                push_Deer=
	                setconfig push_Deer
	            }
	        else
	            #echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
	            echo -e "请先前往 \033[32;4mhttp://www.pushdeer.com/official.html\033[0m 扫码安装快应用或下载APP"
	            echo -e "打开快应用/APP，并完成登陆"
	            echo -e "\033[33m切换到「设备」标签页，点击右上角的加号，注册当前设备\033[0m"
	            echo -e "\033[36m切换到「秘钥」标签页，点击右上角的加号，创建一个秘钥，并复制\033[0m"
	            echo "-----------------------------------------------"
	            read -p "请输入你复制的秘钥 > " url
	            if [ -n "$url" ]; then
	                push_Deer=$url
	                setconfig push_Deer $url
	                logger "已完成PushDeer日志推送设置！" 32
	            else
	                echo -e "\033[31m输入错误，请重新输入！\033[0m"
	            fi
	            sleep 1
	        fi
			;;
	    3)
	        echo "-----------------------------------------------"
	        if [ -n "$push_bark" ]; then
	            read -p "确认关闭Bark日志推送？(1/0) > " res
	            [ "$res" = 1 ] && {
	                push_bark=
	                bark_param=
	                setconfig push_bark
	                setconfig bark_param
	            }
	        else
	            #echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
	            echo -e "\033[33mBark推送仅支持IOS系统，其他平台请使用其他推送方式！\033[0m"
	            echo -e "\033[32m请安装Bark-IOS客户端，并在客户端中找到专属推送链接\033[0m"
	            echo "-----------------------------------------------"
	            read -p "请输入你的Bark推送链接 > " url
	            if [ -n "$url" ]; then
	                push_bark=$url
	                setconfig push_bark $url
	                logger "已完成Bark日志推送设置！" 32
	            else
	                echo -e "\033[31m输入错误，请重新输入！\033[0m"
	            fi
	            sleep 1
	        fi
			;;
	    4)
	        echo "-----------------------------------------------"
	        if [ -n "$push_Po" ]; then
	            read -p "确认关闭Pushover日志推送？(1/0) > " res
	            [ "$res" = 1 ] && {
	                push_Po=
	                push_Po_key=
	                setconfig push_Po
	                setconfig push_Po_key
	            }
	        else
	            #echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
	            echo -e "请先通过 \033[32;4mhttps://pushover.net/\033[0m 注册账号并获取\033[36mUser Key\033[0m"
	            echo "-----------------------------------------------"
	            read -p "请输入你的User Key > " key
	            if [ -n "$key" ]; then
	                echo "-----------------------------------------------"
	                echo -e "\033[33m请检查注册邮箱，完成账户验证\033[0m"
	                read -p "我已经验证完成(1/0) > "
	                echo "-----------------------------------------------"
	                echo -e "请通过 \033[32;4mhttps://pushover.net/apps/build\033[0m 生成\033[36mAPI Token\033[0m"
	                echo "-----------------------------------------------"
	                read -p "请输入你的API Token > " Token
	                if [ -n "$Token" ]; then
	                    push_Po=$Token
	                    push_Po_key=$key
	                    setconfig push_Po $Token
	                    setconfig push_Po_key $key
	                    logger "已完成Passover日志推送设置！" 32
	                else
	                    echo -e "\033[31m输入错误，请重新输入！\033[0m"
	                fi
	            else
	                echo -e "\033[31m输入错误，请重新输入！\033[0m"
	            fi
	        fi
	        sleep 1
			;;
	    5)
	        echo "-----------------------------------------------"
	        if [ -n "$push_PP" ]; then
	            read -p "确认关闭PushPlus日志推送？(1/0) > " res
	            [ "$res" = 1 ] && {
	                push_PP=
	                setconfig push_PP
	            }
	        else
	            #echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
	            echo -e "请先通过 \033[32;4mhttps://www.pushplus.plus/push1.html\033[0m 注册账号并获取\033[36mtoken\033[0m"
	            echo "-----------------------------------------------"
	            read -p "请输入你的token > " Token
	            if [ -n "$Token" ]; then
	                push_PP=$Token
	                setconfig push_PP $Token
	                logger "已完成PushPlus日志推送设置！" 32
	            else
	                echo -e "\033[31m输入错误，请重新输入！\033[0m"
	            fi
	        fi
	        sleep 1
			;;
	    6)
	        echo "-----------------------------------------------"
	        if [ -n "$push_SynoChat" ]; then
	            read -p "确认关闭SynoChat日志推送？(1/0) > " res
	            [ "$res" = 1 ] && {
	                push_SynoChat=
	                setconfig push_SynoChat
	            }
	        else
	            echo "-----------------------------------------------"
	            read -p "请输入你的Synology DSM主页地址 > " URL
	            echo "-----------------------------------------------"
	            read -p "请输入你的Synology Chat Token > " TOKEN
	            echo "-----------------------------------------------"
	            echo -e '请通过"你的群晖地址/webapi/entry.cgi?api=SYNO.Chat.External&method=user_list&version=2&token=你的TOKEN"获取user_id'
	            echo "-----------------------------------------------"
	            read -p "请输入你的user_id > " USERID
	            if [ -n "$URL" ]; then
	                push_SynoChat=$USERID
	                setconfig push_SynoChat $USERID
	                setconfig push_ChatURL $URL
	                setconfig push_ChatTOKEN $TOKEN
	                setconfig push_ChatUSERID $USERID
	                logger "已完成SynoChat日志推送设置！" 32
	            else
	                echo -e "\033[31m输入错误，请重新输入！\033[0m"
	                setconfig push_ChatURL
	                setconfig push_ChatTOKEN
	                setconfig push_ChatUSERID
	                push_SynoChat=
	                setconfig push_SynoChat
	            fi
	        fi
	        sleep 1
			;;
	    # 在menu.sh的case $num in代码块中添加
	    7)
	        echo "-----------------------------------------------"
	        if [ -n "$push_Gotify" ]; then
	            read -p "确认关闭Gotify日志推送？(1/0) > " res
	            [ "$res" = 1 ] && {
	                push_Gotify=
	                setconfig push_Gotify
	            }
	        else
	            echo -e "请先通过Gotify服务器获取推送URL"
	            echo -e "格式示例: https://gotify.example.com/message?token=你的应用令牌"
	            echo "-----------------------------------------------"
	            read -p "请输入你的Gotify推送URL > " url
	            if [ -n "$url" ]; then
	                push_Gotify=$url
	                setconfig push_Gotify "$url"
	                logger "已完成Gotify日志推送设置！" 32
	            else
	                echo -e "\033[31m输入错误，请重新输入！\033[0m"
	            fi
	        fi
	        sleep 1
			;;
		a)
			if [ -s "$TMPDIR"/ShellCrash.log ]; then
				echo "-----------------------------------------------"
				cat "$TMPDIR"/ShellCrash.log
				exit 0
			else
				echo -e "\033[31m未找到相关日志！\033[0m"
			fi
			sleep 1
			break
			;;
	    b)
	        [ "$task_push" = 1 ] && task_push='' || task_push=1
	        setconfig task_push $task_push
	        sleep 1
			;;
	    c)
	        read -p "请输入本设备自定义推送名称 > " device_name
	        setconfig device_name $device_name
	        sleep 1
			;;
	    d)
	        echo -e "\033[33m运行日志及任务日志均已清空！\033[0m"
	        rm -rf "$TMPDIR"/ShellCrash.log
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

#测试菜单
testcommand(){
	echo "$crashcore" | grep -q 'singbox' && config_path=${JSONSDIR}/config.json || config_path=${YAMLSDIR}/config.yaml
	echo "-----------------------------------------------"
	echo -e "\033[30;47m这里是测试命令菜单\033[0m"
	echo -e "\033[33m如遇问题尽量运行相应命令后截图提交issue或TG讨论组\033[0m"
	echo "-----------------------------------------------"
	echo " 1 Debug模式运行内核"
	echo " 2 查看系统DNS端口(:53)占用 "
	echo " 3 测试ssl加密(aes-128-gcm)跑分"
	echo " 4 查看ShellCrash相关路由规则"
	echo " 5 查看内核配置文件前40行"
	echo " 6 测试代理服务器连通性(google.tw)"
	echo "-----------------------------------------------"
	echo " 0 返回上级目录！"
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
		main_menu
		;;
	1)
		debug
		testcommand
	    ;;
	2)
		echo "-----------------------------------------------"
		netstat -ntulp |grep 53
		echo "-----------------------------------------------"
		echo -e "可以使用\033[44m netstat -ntulp |grep xxx \033[0m来查询任意(xxx)端口"
		exit;
	    ;;
	3)
		echo "-----------------------------------------------"
		openssl speed -multi 4 -evp aes-128-gcm
		echo "-----------------------------------------------"
		exit;
	    ;;
	4)
		if [ "$firewall_mod" = "nftables" ];then
			nft list table inet shellcrash | sed '/set cn_ip {/,/}/d;/set cn_ip6 {/,/}/d;/^[[:space:]]*}/d'
		else
			[ "$firewall_area" = 1 -o "$firewall_area" = 3 -o "$firewall_area" = 5 -o "$vm_redir" = "ON" ] && {
				echo "----------------Redir+DNS---------------------"
				iptables -t nat -L PREROUTING --line-numbers
				iptables -t nat -L shellcrash_dns --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Redir模式|混合模式')" ] && iptables -t nat -L shellcrash --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
					echo "----------------Tun/Tproxy-------------------"
					iptables -t mangle -L PREROUTING --line-numbers
					iptables -t mangle -L shellcrash_mark --line-numbers
				}
			}
			[ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && {
				echo "-------------OUTPUT-Redir+DNS----------------"
				iptables -t nat -L OUTPUT --line-numbers
				iptables -t nat -L shellcrash_dns_out --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Redir模式|混合模式')" ] && iptables -t nat -L shellcrash_out --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
					echo "------------OUTPUT-Tun/Tproxy---------------"
					iptables -t mangle -L OUTPUT --line-numbers
					iptables -t mangle -L shellcrash_mark_out --line-numbers
				}
			}
			[ "$ipv6_redir" = "ON" ] && {
				[ "$firewall_area" = 1 -o "$firewall_area" = 3 ] && {
					ip6tables -t nat -L >/dev/null 2>&1 && {
						echo "-------------IPV6-Redir+DNS-------------------"
						ip6tables -t nat -L PREROUTING --line-numbers
						ip6tables -t nat -L shellcrashv6_dns --line-numbers
						[ -n "$(echo $redir_mod | grep -E 'Redir模式|混合模式')" ] && ip6tables -t nat -L shellcrashv6 --line-numbers
					}
					[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
						echo "-------------IPV6-Tun/Tproxy------------------"
						ip6tables -t mangle -L PREROUTING --line-numbers
						ip6tables -t mangle -L shellcrashv6_mark --line-numbers
					}
				}
			}
			[ "$vm_redir" = "ON" ] && {
						echo "-------------vm-Redir-------------------"
						iptables -t nat -L shellcrash_vm --line-numbers
						iptables -t nat -L shellcrash_vm_dns --line-numbers
			}
			echo "----------------本机防火墙---------------------"
			iptables -L INPUT --line-numbers
		fi
		exit;
	    ;;
	5)
		echo "-----------------------------------------------"
		sed -n '1,40p' ${config_path}
		echo "-----------------------------------------------"
		exit;
		;;
	6)
		echo "注意：依赖curl(不支持wget)，且测试结果不保证一定准确！"
		delay=`curl -kx ${authentication}@127.0.0.1:$mix_port -o /dev/null -s -w '%{time_starttransfer}' 'https://google.tw' & { sleep 3 ; kill $! >/dev/null 2>&1 & }` > /dev/null 2>&1
		delay=`echo |awk "{print $delay*1000}"` > /dev/null 2>&1
		echo "-----------------------------------------------"
		if [ `echo ${#delay}` -gt 1 ];then
			echo -e "\033[32m连接成功！响应时间为："$delay" ms\033[0m"
		else
			echo -e "\033[31m连接超时！请重试或检查节点配置！\033[0m"
		fi
		main_menu
		;;
	*)
		errornum
		main_menu
	    ;;
	esac
}
debug(){
	echo "$crashcore" | grep -q 'singbox' && config_tmp="$TMPDIR"/jsons || config_tmp="$TMPDIR"/config.yaml
	echo "-----------------------------------------------"
	echo -e "\033[36m注意：Debug运行均会停止原本的内核服务\033[0m"
	echo -e "后台运行日志地址：\033[32m$TMPDIR/debug.log\033[0m"
	echo -e "如长时间运行后台监测，日志等级推荐error！防止文件过大！"
	echo -e "你也可以通过：\033[33mcrash -s debug 'warning'\033[0m 命令使用其他日志等级"
	echo "-----------------------------------------------"
	echo -e " 1 仅测试\033[32m$config_tmp\033[0m配置文件可用性"
	echo -e " 2 前台运行\033[32m$config_tmp\033[0m配置文件,不配置防火墙劫持(\033[33m使用Ctrl+C手动停止\033[0m)"
	echo -e " 3 后台运行完整启动流程,并配置防火墙劫持,日志等级:\033[31merror\033[0m"
	echo -e " 4 后台运行完整启动流程,并配置防火墙劫持,日志等级:\033[32minfo\033[0m"
	echo -e " 5 后台运行完整启动流程,并配置防火墙劫持,日志等级:\033[33mdebug\033[0m"
	echo -e " 6 后台运行完整启动流程,并配置防火墙劫持,且将错误日志打印到闪存：\033[32m$CRASHDIR/debug.log\033[0m"
	echo "-----------------------------------------------"
	echo -e " 8 后台运行完整启动流程,输出执行错误并查找上下文,之后关闭进程"
	[ -s "$TMPDIR"/jsons/inbounds.json ] && echo -e " 9 将\033[32m$config_tmp\033[0m下json文件合并为$TMPDIR/debug.json"
	echo "-----------------------------------------------"
	echo " 0 返回上级目录！"
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		"$CRASHDIR"/start.sh stop
		"$CRASHDIR"/start.sh bfstart
		if echo "$crashcore" | grep -q 'singbox' ;then
			"$TMPDIR"/CrashCore run -D "$BINDIR" -C "$TMPDIR"/jsons &
			{ sleep 4 ; kill $! >/dev/null 2>&1 & }
			wait
		else
			"$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml
		fi
		rm -rf "$TMPDIR"/CrashCore
		echo "-----------------------------------------------"
		exit
	;;
	2)
		"$CRASHDIR"/start.sh stop
		"$CRASHDIR"/start.sh bfstart
		$COMMAND
		rm -rf "$TMPDIR"/CrashCore
		echo "-----------------------------------------------"
		exit
	;;
	3)
		"$CRASHDIR"/start.sh debug error
		main_menu
	;;
	4)
		"$CRASHDIR"/start.sh debug info
		main_menu
	;;
	5)
		"$CRASHDIR"/start.sh debug debug
		main_menu
	;;
	6)
		echo -e "频繁写入闪存会导致闪存寿命降低，如非遇到会导致设备死机或重启的bug，请勿使用此功能！"
		read -p "是否继续？(1/0) > " res
		[ "$res" = 1 ] && "$CRASHDIR"/start.sh debug debug flash
		main_menu
	;;
	8)
		$0 -d
		main_menu
	;;
	9)
		. "$CRASHDIR"/libs/core_webget.sh && core_find && "$TMPDIR"/CrashCore merge "$TMPDIR"/debug.json -C "$TMPDIR"/jsons && echo -e "\033[32m合并成功！\033[0m"
		[ "$TMPDIR" = "$BINDIR" ] && rm -rf "$TMPDIR"/CrashCore
		main_menu
	;;
	*)
		errornum
	;;
	esac
}

#新手引导
userguide(){
	. "$CRASHDIR"/libs/check_dir_avail.sh
	forwhat(){
		echo "-----------------------------------------------"
		echo -e "\033[30;46m 欢迎使用ShellCrash新手引导！ \033[0m"
		echo "-----------------------------------------------"
		echo -e "\033[33m请先选择你的使用环境： \033[0m"
		echo -e "\033[0m(你之后依然可以在设置中更改各种配置)\033[0m"
		echo "-----------------------------------------------"
		echo -e " 1 \033[32m路由设备配置局域网透明代理\033[0m"
		echo -e " 2 \033[36mLinux设备仅配置本机代理\033[0m"
		[ -f "$CFG_PATH.bak" ] && echo -e " 3 \033[33m还原之前备份的设置\033[0m"
		echo "-----------------------------------------------"
		read -p "请输入对应数字 > " num
		case "$num" in
		1)
			#设置运行模式
			redir_mod="混合模式"
			[ -n "$(echo $cputype | grep -E "linux.*mips.*")" ] && {
				if grep -qE '^TPROXY$' /proc/net/ip_tables_targets || modprobe xt_TPROXY >/dev/null 2>&1; then
					redir_mod="Tproxy模式"
				else
					redir_mod="Redir模式"
				fi
			}
			[ -z "$crashcore" ] && crashcore=meta
			setconfig crashcore "$crashcore"
			setconfig redir_mod "$redir_mod"
			setconfig dns_mod mix
			setconfig firewall_area '1'
			#默认启用绕过CN-IP
			setconfig cn_ip_route ON
			#自动识别IPV6
			[ -n "$(ip a 2>&1 | grep -w 'inet6' | grep -E 'global' | sed 's/.*inet6.//g' | sed 's/scope.*$//g')" ] && {
				setconfig ipv6_redir ON
				setconfig ipv6_support ON
				setconfig ipv6_dns ON
				setconfig cn_ipv6_route ON
			}
			#设置开机启动
			[ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ] && /etc/init.d/shellcrash enable
			ckcmd systemctl && [ "$(cat /proc/1/comm)" = "systemd" ] && systemctl enable shellcrash.service > /dev/null 2>&1
			rm -rf "$CRASHDIR"/.dis_startup
			autostart=enable
			#检测IP转发
			if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "0" ];then
				echo "-----------------------------------------------"
				echo -e "\033[33m检测到你的设备尚未开启ip转发，局域网设备将无法正常连接网络，是否立即开启？\033[0m"
				read -p "是否开启？(1/0) > " res
				[ "$res" = 1 ] && {
					echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
					sysctl -w net.ipv4.ip_forward=1
				} && echo "已成功开启ipv4转发，如未正常开启，请手动重启设备！" || echo "开启失败！请自行谷歌查找当前设备的开启方法！"
			fi
			#禁止docker启用的net.bridge.bridge-nf-call-iptables
			sysctl -w net.bridge.bridge-nf-call-iptables=0 > /dev/null 2>&1
			sysctl -w net.bridge.bridge-nf-call-ip6tables=0 > /dev/null 2>&1
			;;
		2)
			setconfig redir_mod "Redir模式"
			[ -n "$(echo $cputype | grep -E "linux.*mips.*")" ] && setconfig crashcore "clash"
			setconfig common_ports "OFF"
			setconfig firewall_area '2'
		    ;;
		3)
			mv -f $CFG_PATH.bak $CFG_PATH
			echo -e "\033[32m脚本设置已还原！\033[0m"
			echo -e "\033[33m请重新启动脚本！\033[0m"
			exit 0
			;;
		*)
			errornum
			forwhat
			;;
		esac
	}
	forwhat
	#检测小内存模式
	dir_size=$(dir_avail "$CRASHDIR")
	if [ "$dir_size" -lt 10240 ];then
		echo "-----------------------------------------------"
		echo -e "\033[33m检测到你的安装目录空间不足10M，是否开启小闪存模式？\033[0m"
		echo -e "\033[0m开启后核心及数据库文件将被下载到内存中，这将占用一部分内存空间\033[0m"
		echo -e "\033[0m每次开机后首次运行服务时都会自动的重新下载相关文件\033[0m"
		echo "-----------------------------------------------"
		read -p "是否开启？(1/0) > " res
		[ "$res" = 1 ] && {
			BINDIR=/tmp/ShellCrash
			setconfig BINDIR /tmp/ShellCrash "$CRASHDIR"/configs/command.env
		}
	fi
	#启用推荐的自动任务配置
	. "$CRASHDIR"/menus/5_task.sh && task_recom
	#小米设备软固化
	if [ "$systype" = "mi_snapshot" ];then
		echo "-----------------------------------------------"
		echo -e "\033[33m检测到为小米路由设备，启用软固化可防止路由升级后丢失SSH\033[0m"
		read -p "是否启用软固化功能？(1/0) > " res
		[ "$res" = 1 ] && mi_autoSSH
	fi
	#提示导入订阅或者配置文件
	[ ! -s "$CRASHDIR"/yamls/config.yaml -a ! -s "$CRASHDIR"/jsons/config.json ] && {
		echo "-----------------------------------------------"
		echo -e "\033[32m是否导入配置文件？\033[0m(这是运行前的最后一步)"
		echo -e "\033[0m你必须拥有一份配置文件才能运行服务！\033[0m"
		echo "-----------------------------------------------"
		read -p "现在开始导入？(1/0) > " res
		[ "$res" = 1 ] && inuserguide=1 && {
			. "$CRASHDIR"/menus/6_core_config.sh && set_core_config
			inuserguide=""
		}
	}
	#回到主界面
	echo "-----------------------------------------------"
	echo -e "\033[36m很好！现在只需要执行启动就可以愉快的使用了！\033[0m"
	echo "-----------------------------------------------"
	read -p "立即启动服务？(1/0) > " res
	[ "$res" = 1 ] && start_core && sleep 2
	main_menu
}
