#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_USERGUIDE_LOADED" ] && return
__IS_MODULE_USERGUIDE_LOADED=1

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
	return 0
}
