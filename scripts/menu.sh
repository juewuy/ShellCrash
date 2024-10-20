#!/bin/sh
# Copyright (C) Juewuy

CRASHDIR=$(
	cd $(dirname $0)
	pwd
)
CFG_PATH=${CRASHDIR}/configs/ShellCrash.cfg
YAMLSDIR=${CRASHDIR}/yamls
JSONSDIR=${CRASHDIR}/jsons
#加载执行目录，失败则初始化
source ${CRASHDIR}/configs/command.env 2>/dev/null
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && source ${CRASHDIR}/init.sh >/dev/null 2>&1
[ ! -f ${TMPDIR} ] && mkdir -p ${TMPDIR}
[ -n "$(tar --help 2>&1 | grep -o 'no-same-owner')" ] && tar_para='--no-same-owner' #tar命令兼容

#读取配置相关
setconfig() {
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath=${CFG_PATH} || configpath="${3}"
	grep -q "${1}=" "$configpath" && sed -i "s#${1}=.*#${1}=${2}#g" $configpath || sed -i "\$a\\${1}=${2}" $configpath
}
ckcmd() {
	command -v sh >/dev/null 2>&1 && command -v $1 >/dev/null 2>&1 || type $1 >/dev/null 2>&1
}

#脚本启动前检查
ckstatus() {
	#检查/读取脚本配置文件
	if [ -f $CFG_PATH ]; then
		[ -n "$(awk 'a[$0]++' $CFG_PATH)" ] && awk '!a[$0]++' $CFG_PATH >$CFG_PATH #检查重复行并去除
		source $CFG_PATH 2>/dev/null
	else
		source ${CRASHDIR}/init.sh >/dev/null 2>&1
	fi
	versionsh=$(cat ${CRASHDIR}/init.sh | grep -E ^version= | head -n 1 | sed 's/version=//')
	[ -n "$versionsh" ] && versionsh_l=$versionsh
	#服务器缺省地址
	[ -z "$mix_port" ] && mix_port=7890
	[ -z "$redir_port" ] && redir_port=7892
	[ -z "$fwmark" ] && fwmark=$redir_port
	[ -z "$db_port" ] && db_port=9999
	[ -z "$dns_port" ] && dns_port=1053
	[ -z "$multiport" ] && multiport='22,80,143,194,443,465,587,853,993,995,5222,8080,8443'
	[ -z "$redir_mod" ] && redir_mod=纯净模式
	#检查mac地址记录
	[ ! -f ${CRASHDIR}/configs/mac ] && touch ${CRASHDIR}/configs/mac
	#获取本机host地址
	[ -z "$host" ] && host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'lan' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host='设备IP地址'
	#dashboard目录位置
	if [ -f /www/clash/index.html ]; then
		dbdir=/www/clash
		hostdir=/clash
	else
		dbdir=${CRASHDIR}/ui
		hostdir=":$db_port/ui"
	fi
	#开机自启检测
	if [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
		[ -n "$(find /etc/rc.d -name '*shellcrash')" ] && autostart=enable || autostart=disable
	elif ckcmd systemctl; then
		[ "$(systemctl is-enabled shellcrash.service 2>&1)" = enabled ] && autostart=enable || autostart=disable
	else
		[ -f ${CRASHDIR}/.dis_startup ] && autostart=disable || autostart=enable
	fi
	#开机自启描述
	if [ "$autostart" = "enable" ]; then
		auto="\033[32m已设置开机启动！\033[0m"
		auto1="\033[36m禁用\033[0mShellCrash开机启动"
	else
		auto="\033[31m未设置开机启动！\033[0m"
		auto1="\033[36m允许\033[0mShellCrash开机启动"
	fi
	#获取运行状态
	PID=$(pidof CrashCore | awk '{print $NF}')
	if [ -n "$PID" ]; then
		run="\033[32m正在运行（$redir_mod）\033[0m"
		VmRSS=$(cat /proc/$PID/status | grep -w VmRSS | awk 'unit="MB" {printf "%.2f %s\n", $2/1000, unit}')
		#获取运行时长
		touch ${TMPDIR}/crash_start_time #用于延迟启动的校验
		start_time=$(cat ${TMPDIR}/crash_start_time)
		if [ -n "$start_time" ]; then
			time=$(($(date +%s) - start_time))
			day=$((time / 86400))
			[ "$day" = "0" ] && day='' || day="$day天"
			time=$(date -u -d @${time} +%H小时%M分%S秒)
		fi
	elif [ "$firewall_area" = 5 ] && [ -n "$(ip route list table 100)" ]; then
		run="\033[32m已设置（$redir_mod）\033[0m"
	else
		run="\033[31m没有运行（$redir_mod）\033[0m"
		#检测系统端口占用
		checkport
	fi
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && corename=SingBox || corename=Clash
	[ "$firewall_area" = 5 ] && corename='转发'
	[ -f ${TMPDIR}/debug.log -o -f ${CRASHDIR}/debug.log -a -n "$PID" ] && auto="\033[33m并处于debug状态！\033[0m"
	#输出状态
	echo -----------------------------------------------
	echo -e "\033[30;46m欢迎使用ShellCrash！\033[0m		版本：$versionsh_l"
	echo -e "$corename服务"$run"，"$auto""
	if [ -n "$PID" ]; then
		echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
	fi
	echo -e "TG频道：\033[36;4mhttps://t.me/ShellClash\033[0m"
	echo -----------------------------------------------
	#检查新手引导
	if [ -z "$userguide" ]; then
		setconfig userguide 1
		source ${CRASHDIR}/webget.sh && userguide
	fi
	#检查执行权限
	[ ! -x ${CRASHDIR}/start.sh ] && chmod +x ${CRASHDIR}/start.sh
	#检查/tmp内核文件
	for file in $(ls -F /tmp | grep -v [/$] | grep -v ' ' | grep -Ev ".*(gz|zip|7z|tar)$" | grep -iE 'CrashCore|^clash$|^clash-linux.*|^mihomo.*|^sing.*box|^clash.meta.*'); do
		file=/tmp/$file
		chmod +x $file
		echo -e "发现可用的内核文件： \033[36m$file\033[0m "
		read -p "是否加载(会停止当前服务)？(1/0) > " res
		[ "$res" = 1 ] && {
			${CRASHDIR}/start.sh stop
			core_v=$($file -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
			[ -z "$core_v" ] && core_v=$($file version 2>/dev/null | grep -Eo 'version .*' | sed 's/version //')
			if [ -n "$core_v" ]; then
				source ${CRASHDIR}/webget.sh && setcoretype &&
					mv -f $file ${TMPDIR}/CrashCore &&
					tar -zcf ${BINDIR}/CrashCore.tar.gz ${tar_para} -C ${TMPDIR} CrashCore &&
					echo -e "\033[32m内核加载完成！\033[0m " &&
					setconfig crashcore $crashcore &&
					setconfig core_v $core_v &&
					switch_core
				sleep 1
			else
				echo -e "\033[33m检测到不可用的内核文件！可能是文件受损或CPU架构不匹配！\033[0m"
				rm -rf $file
				echo -e "\033[33m内核文件已移除，请认真检查后重新上传！\033[0m"
				sleep 2
			fi
		}
		echo -----------------------------------------------
	done
	#检查/tmp配置文件
	for file in $(ls -F /tmp | grep -v [/$] | grep -v ' ' | grep -iE '.yaml$|.yml$|config.json$'); do
		file=/tmp/$file
		echo -e "发现内核配置文件： \033[36m$file\033[0m "
		read -p "是否加载为$crashcore的配置文件？(1/0) > " res
		[ "$res" = 1 ] && {
			if [ -n "$(echo $file | grep -iE '.json$')" ]; then
				mv -f $file ${CRASHDIR}/jsons/config.json
			else
				mv -f $file ${CRASHDIR}/yamls/config.yaml
			fi
			echo -e "\033[32m配置文件加载完成！\033[0m "
			sleep 1
		}
	done
	#检查禁用配置覆写
	[ "$disoverride" = "1" ] && {
		echo -e "\033[33m你已经禁用了配置文件覆写功能，这会导致大量脚本功能无法使用！\033[0m "
		read -p "是否取消禁用？(1/0) > " res
		[ "$res" = 1 ] && unset disoverride && setconfig disoverride
		echo -----------------------------------------------
	}
}

errornum() {
	echo -----------------------------------------------
	echo -e "\033[31m请输入正确的字母或数字！\033[0m"
}
startover() {
	echo -e "\033[32m服务已启动！\033[0m"
	echo -e "请使用 \033[4;36mhttp://$host$hostdir\033[0m 管理内置规则"
	if [ "$redir_mod" = "纯净模式" ]; then
		echo -----------------------------------------------
		echo -e "其他设备可以使用PAC配置连接：\033[4;32mhttp://$host:$db_port/ui/pac\033[0m"
		echo -e "或者使用HTTP/SOCK5方式连接：IP{\033[36m$host\033[0m}端口{\033[36m$mix_port\033[0m}"
	fi
	return 0
}
start_core() {
	if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
		core_config=${CRASHDIR}/jsons/config.json
	else
		core_config=${CRASHDIR}/yamls/config.yaml
	fi
	echo -----------------------------------------------
	if [ ! -s $core_config -a -s $CRASHDIR/configs/providers.cfg ]; then
		echo -e "\033[33m没有找到${crashcore}配置文件，尝试生成providers配置文件！\033[0m"
		[ "$crashcore" = singboxp ] && coretype=singbox
		[ "$crashcore" = meta -o "$crashcore" = clashpre ] && coretype=clash
		source ${CRASHDIR}/webget.sh && gen_${coretype}_providers
	elif [ -s $core_config -o -n "$Url" -o -n "$Https" ]; then
		${CRASHDIR}/start.sh start
		#设置循环检测以判定服务启动是否成功
		i=1
		while [ -z "$test" -a "$i" -lt 10 ]; do
			sleep 1
			if curl --version >/dev/null 2>&1; then
				test=$(curl -s http://127.0.0.1:${db_port}/configs | grep -o port)
			else
				test=$(wget -q -O - http://127.0.0.1:${db_port}/configs | grep -o port)
			fi
			i=$((i + 1))
		done
		[ -n "$test" -o -n "$(pidof CrashCore)" ] && startover
	else
		echo -e "\033[31m没有找到${crashcore}配置文件，请先导入配置文件！\033[0m"
		source ${CRASHDIR}/webget.sh && set_core_config
	fi
}
start_service() {
	if [ "$firewall_area" = 5 ]; then
		${CRASHDIR}/start.sh start
		echo -e "\033[32m已完成防火墙设置！\033[0m"
	else
		start_core
	fi
}
checkrestart() {
	echo -----------------------------------------------
	echo -e "\033[32m检测到已变更的内容，请重启服务！\033[0m"
	echo -----------------------------------------------
	read -p "是否现在重启服务？(1/0) > " res
	[ "$res" = 1 ] && start_service
}
#功能相关
log_pusher() { #日志菜单
	[ -n "$push_TG" ] && stat_TG=32m已启用 || stat_TG=33m未启用
	[ -n "$push_Deer" ] && stat_Deer=32m已启用 || stat_Deer=33m未启用
	[ -n "$push_bark" ] && stat_bark=32m已启用 || stat_bark=33m未启用
	[ -n "$push_Po" ] && stat_Po=32m已启用 || stat_Po=33m未启用
	[ -n "$push_PP" ] && stat_PP=32m已启用 || stat_PP=33m未启用
	[ "$task_push" = 1 ] && stat_task=32m已启用 || stat_task=33m未启用
	[ -n "$device_name" ] && device_s=32m$device_name || device_s=33m未设置
	echo -----------------------------------------------
	echo -e " 1 查看\033[36m运行日志\033[0m"
	echo -e " 2 Telegram推送	——\033[$stat_TG\033[0m"
	echo -e " 3 PushDeer推送	——\033[$stat_Deer\033[0m"
	echo -e " 4 Bark推送-IOS	——\033[$stat_bark\033[0m"
	echo -e " 5 Passover推送	——\033[$stat_Po\033[0m"
	echo -e " 6 PushPlus推送	——\033[$stat_PP\033[0m"
	echo -e " 7 推送任务日志	——\033[$stat_task\033[0m"
	echo -e " 8 设置设备名称	——\033[$device_s\033[0m"
	echo -e " 9 清空日志文件"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case $num in
	1)
		if [ -s ${TMPDIR}/ShellCrash.log ]; then
			echo -----------------------------------------------
			cat ${TMPDIR}/ShellCrash.log
			exit 0
		else
			echo -e "\033[31m未找到相关日志！\033[0m"
		fi
		sleep 1
		;;
	2)
		echo -----------------------------------------------
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
				if curl --version >/dev/null 2>&1; then
					chat=$(curl -kfsSl $url_tg 2>/dev/null | tail -n -1)
				else
					chat=$(wget -Y on -q -O - $url_tg | tail -n -1)
				fi
				[ -n "$chat" ] && chat_ID=$(echo $chat | grep -oE '"id":.*,"is_bot":false' | sed s'/"id"://'g | sed s'/,"is_bot":false//'g)
				if [ -n "$chat_ID" ]; then
					push_TG=$TOKEN
					setconfig push_TG $TOKEN
					setconfig chat_ID $chat_ID
					${CRASHDIR}/start.sh logger "已完成Telegram日志推送设置！" 32
				else
					echo -e "\033[31m无法获取对话ID，请重新配置！\033[0m"
				fi
			fi
			sleep 1
		fi
		log_pusher
		;;
	3)
		echo -----------------------------------------------
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
			echo -----------------------------------------------
			read -p "请输入你复制的秘钥 > " url
			if [ -n "$url" ]; then
				push_Deer=$url
				setconfig push_Deer $url
				${CRASHDIR}/start.sh logger "已完成PushDeer日志推送设置！" 32
			else
				echo -e "\033[31m输入错误，请重新输入！\033[0m"
			fi
			sleep 1
		fi
		log_pusher
		;;
	4)
		echo -----------------------------------------------
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
			echo -----------------------------------------------
			read -p "请输入你的Bark推送链接 > " url
			if [ -n "$url" ]; then
				push_bark=$url
				setconfig push_bark $url
				${CRASHDIR}/start.sh logger "已完成Bark日志推送设置！" 32
			else
				echo -e "\033[31m输入错误，请重新输入！\033[0m"
			fi
			sleep 1
		fi
		log_pusher
		;;
	5)
		echo -----------------------------------------------
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
			echo -----------------------------------------------
			read -p "请输入你的User Key > " key
			if [ -n "$key" ]; then
				echo -----------------------------------------------
				echo -e "\033[33m请检查注册邮箱，完成账户验证\033[0m"
				read -p "我已经验证完成(1/0) > "
				echo -----------------------------------------------
				echo -e "请通过 \033[32;4mhttps://pushover.net/apps/build\033[0m 生成\033[36mAPI Token\033[0m"
				echo -----------------------------------------------
				read -p "请输入你的API Token > " Token
				if [ -n "$Token" ]; then
					push_Po=$Token
					push_Po_key=$key
					setconfig push_Po $Token
					setconfig push_Po_key $key
					${CRASHDIR}/start.sh logger "已完成Passover日志推送设置！" 32
				else
					echo -e "\033[31m输入错误，请重新输入！\033[0m"
				fi
			else
				echo -e "\033[31m输入错误，请重新输入！\033[0m"
			fi
		fi
		sleep 1
		log_pusher
		;;
	6)
		echo -----------------------------------------------
		if [ -n "$push_PP" ]; then
			read -p "确认关闭PushPlus日志推送？(1/0) > " res
			[ "$res" = 1 ] && {
				push_PP=
				setconfig push_PP
			}
		else
			#echo -e "\033[33m详细设置指南请参考 https://juewuy.github.io/ \033[0m"
			echo -e "请先通过 \033[32;4mhttps://www.pushplus.plus/push1.html\033[0m 注册账号并获取\033[36mtoken\033[0m"
			echo -----------------------------------------------
			read -p "请输入你的token > " Token
			if [ -n "$Token" ]; then
				push_PP=$Token
				setconfig push_PP $Token
				${CRASHDIR}/start.sh logger "已完成PushPlus日志推送设置！" 32
			else
				echo -e "\033[31m输入错误，请重新输入！\033[0m"
			fi
		fi
		sleep 1
		log_pusher
		;;
	7)
		[ "$task_push" = 1 ] && task_push='' || task_push=1
		setconfig task_push $task_push
		sleep 1
		log_pusher
		;;
	8)
		read -p "请输入本设备自定义推送名称 > " device_name
		setconfig device_name $device_name
		sleep 1
		log_pusher
		;;
	9)
		echo -e "\033[33m运行日志及任务日志均已清空！\033[0m"
		rm -rf ${TMPDIR}/ShellCrash.log
		sleep 1
		log_pusher
		;;
	*) errornum ;;
	esac
}
setport() { #端口设置
	source $CFG_PATH >/dev/null
	[ -z "$secret" ] && secret=未设置
	[ -z "$authentication" ] && auth=未设置 || auth=******
	inputport() {
		read -p "请输入端口号(1-65535) > " portx
		if [ -z "$portx" ]; then
			setport
		elif [ $portx -gt 65535 -o $portx -le 1 ]; then
			echo -e "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
			inputport
		elif [ -n "$(echo "|$mix_port|$redir_port|$dns_port|$db_port|" | grep "|$portx|")" ]; then
			echo -e "\033[31m输入错误！请不要输入重复的端口！\033[0m"
			inputport
		elif [ -n "$(netstat -ntul | grep ":$portx ")" ]; then
			echo -e "\033[31m当前端口已被其他进程占用，请重新输入！\033[0m"
			inputport
		else
			setconfig $xport $portx
			echo -e "\033[32m设置成功！！！\033[0m"
			setport
		fi
	}
	echo -----------------------------------------------
	echo -e " 1 修改Http/Sock5端口：	\033[36m$mix_port\033[0m"
	echo -e " 2 设置Http/Sock5密码：	\033[36m$auth\033[0m"
	echo -e " 3 修改静态路由端口：	\033[36m$redir_port\033[0m"
	echo -e " 4 修改DNS监听端口：	\033[36m$dns_port\033[0m"
	echo -e " 5 修改面板访问端口：	\033[36m$db_port\033[0m"
	echo -e " 6 设置面板访问密码：	\033[36m$secret\033[0m"
	echo -e " 7 修改默认端口过滤：	\033[36m$multiport\033[0m"
	echo -e " 8 自定义本机host地址：	\033[36m$host\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 1 ]; then
		xport=mix_port
		inputport
	elif [ "$num" = 2 ]; then
		echo -----------------------------------------------
		echo -e "格式必须是\033[32m 用户名:密码 \033[0m的形式，注意用小写冒号分隔！"
		echo -e "请尽量不要使用特殊符号！避免产生未知错误！"
		echo "输入 0 删除密码"
		echo -----------------------------------------------
		read -p "请输入Http/Sock5用户名及密码 > " input
		if [ "$input" = "0" ]; then
			authentication=""
			setconfig authentication
			echo 密码已移除！
		else
			if [ "$local_proxy" = "已开启" -a "$local_type" = "环境变量" ]; then
				echo -----------------------------------------------
				echo -e "\033[33m请先禁用本机代理功能或使用增强模式！\033[0m"
				sleep 1
			else
				authentication=$(echo $input | grep :)
				if [ -n "$authentication" ]; then
					setconfig authentication \'$authentication\'
					echo -e "\033[32m设置成功！！！\033[0m"
				else
					echo -e "\033[31m输入有误，请重新输入！\033[0m"
				fi
			fi
		fi
		setport
	elif [ "$num" = 3 ]; then
		xport=redir_port
		inputport
	elif [ "$num" = 4 ]; then
		xport=dns_port
		inputport
	elif [ "$num" = 5 ]; then
		xport=db_port
		inputport
	elif [ "$num" = 6 ]; then
		read -p "请输入面板访问密码(输入0删除密码) > " secret
		if [ -n "$secret" ]; then
			[ "$secret" = "0" ] && secret=""
			setconfig secret $secret
			echo -e "\033[32m设置成功！！！\033[0m"
		fi
		setport
	elif [ "$num" = 7 ]; then
		echo -----------------------------------------------
		echo -e "需配合\033[32m仅代理常用端口\033[0m功能使用"
		echo -e "多个端口请用小写逗号分隔，例如：\033[33m143,80,443\033[0m"
		echo -e "输入 0 重置为默认端口"
		echo -----------------------------------------------
		read -p "请输入需要指定代理的端口 > " multiport
		if [ -n "$multiport" ]; then
			[ "$multiport" = "0" ] && multiport=""
			common_ports=已开启
			setconfig multiport $multiport
			setconfig common_ports $common_ports
			echo -e "\033[32m设置成功！！！\033[0m"
		fi
		setport
	elif [ "$num" = 8 ]; then
		echo -----------------------------------------------
		echo -e "\033[33m如果你的局域网网段不是192.168.x或127.16.x或10.x开头，请务必修改！\033[0m"
		echo -e "\033[31m设置后如本机host地址有变动，请务必重新修改！\033[0m"
		echo -----------------------------------------------
		read -p "请输入自定义host地址(输入0移除自定义host) > " host
		if [ "$host" = "0" ]; then
			host=""
			setconfig host $host
			echo -e "\033[32m已经移除自定义host地址，请重新运行脚本以自动获取host！！！\033[0m"
			exit 0
		elif [ -n "$(echo $host | grep -E -o '\<([1-9]|[1-9][0-9]|1[0-9]{2}|2[01][0-9]|22[0-3])\>(\.\<([0-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\>){2}\.\<([1-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])\>')" ]; then
			setconfig host $host
			echo -e "\033[32m设置成功！！！\033[0m"
		else
			host=""
			echo -e "\033[31m输入错误，请仔细核对！！！\033[0m"
		fi
		sleep 1
		setport
	fi
}
setdns() { #DNS设置
	[ -z "$dns_nameserver" ] && dns_nameserver='114.114.114.114, 223.5.5.5'
	[ -z "$dns_fallback" ] && dns_fallback='1.0.0.1, 8.8.4.4'
	[ -z "$hosts_opt" ] && hosts_opt=已开启
	[ -z "$dns_redir" ] && dns_redir=未开启
	[ -z "$dns_no" ] && dns_no=未禁用
	echo -----------------------------------------------
	echo -e "当前基础DNS：\033[32m$dns_nameserver\033[0m"
	echo -e "PROXY-DNS：\033[36m$dns_fallback\033[0m"
	echo -e "多个DNS地址请用\033[30;47m“|”\033[0m或者\033[30;47m“, ”\033[0m分隔输入"
	echo -e "\033[33m必须拥有本地根证书文件才能使用dot/doh类型的加密dns\033[0m"
	echo -e "\033[33m注意singbox内核只有首个dns会被加载！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 修改\033[32m基础DNS\033[0m"
	echo -e " 2 修改\033[36mPROXY-DNS\033[0m"
	echo -e " 3 \033[33m重置\033[0m默认DNS配置"
	echo -e " 4 一键配置\033[32m加密DNS\033[0m"
	echo -e " 5 hosts优化：  	\033[36m$hosts_opt\033[0m	————调用本机hosts并劫持NTP服务"
	echo -e " 6 Dnsmasq转发：	\033[36m$dns_redir\033[0m	————不推荐使用"
	echo -e " 7 禁用DNS劫持：	\033[36m$dns_no\033[0m	————搭配第三方DNS使用"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 1 ]; then
		read -p "请输入新的DNS > " dns_nameserver
		dns_nameserver=$(echo $dns_nameserver | sed 's#|#\,\ #g')
		if [ -n "$dns_nameserver" ]; then
			setconfig dns_nameserver \'"$dns_nameserver"\'
			echo -e "\033[32m设置成功！！！\033[0m"
		fi
		setdns

	elif [ "$num" = 2 ]; then
		read -p "请输入新的DNS > " dns_fallback
		dns_fallback=$(echo $dns_fallback | sed 's/|/\,\ /g')
		if [ -n "$dns_fallback" ]; then
			setconfig dns_fallback \'"$dns_fallback"\'
			echo -e "\033[32m设置成功！！！\033[0m"
		fi
		setdns

	elif [ "$num" = 3 ]; then
		dns_nameserver=""
		dns_fallback=""
		setconfig dns_nameserver
		setconfig dns_fallback
		echo -e "\033[33mDNS配置已重置！！！\033[0m"
		setdns

	elif [ "$num" = 4 ]; then
		echo -----------------------------------------------
		openssldir="$(openssl version -d 2>&1 | awk -F '"' '{print $2}')"
		if [ -s "$openssldir/certs/ca-certificates.crt" -o -s "/etc/ssl/certs/ca-certificates.crt" ]; then
			dns_nameserver='https://223.5.5.5/dns-query, https://doh.pub/dns-query, tls://dns.rubyfish.cn:853'
			dns_fallback='tls://1.0.0.1:853, tls://8.8.4.4:853, https://doh.opendns.com/dns-query'
			setconfig dns_nameserver \'"$dns_nameserver"\'
			setconfig dns_fallback \'"$dns_fallback"\'
			echo -e "\033[32m已设置加密DNS，如出现DNS解析问题，请尝试重置DNS配置！\033[0m"
		else
			echo -e "\033[31m找不到根证书文件，无法启用加密DNS，Linux系统请自行搜索安装OpenSSL的方式！\033[0m"
		fi
		sleep 2
		setdns

	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		if [ "$hosts_opt" = "已启用" ]; then
			hosts_opt=未启用
			echo -e "\033[32m已禁用hosts优化功能！！！\033[0m"
		else
			hosts_opt=已启用
			echo -e "\033[33m已启用hosts优化功能！！！\033[0m"
		fi
		sleep 1
		setconfig hosts_opt $hosts_opt
		setdns

	elif [ "$num" = 6 ]; then
		echo -----------------------------------------------
		if [ "$dns_redir" = "未开启" ]; then
			echo -e "\033[31m将使用OpenWrt中Dnsmasq插件自带的DNS转发功能转发DNS请求至内核！\033[0m"
			echo -e "\033[33m启用后将禁用本插件自带的iptables转发功能\033[0m"
			dns_redir=已开启
			echo -e "\033[32m已启用Dnsmasq转发DNS功能！！！\033[0m"
			sleep 1
		else
			uci del dhcp.@dnsmasq[-1].server
			uci set dhcp.@dnsmasq[0].noresolv=0
			uci commit dhcp
			/etc/init.d/dnsmasq restart
			echo -e "\033[33m禁用成功！！如有报错请重启设备！\033[0m"
			dns_redir=未开启
		fi
		sleep 1
		setconfig dns_redir $dns_redir
		setdns

	elif [ "$num" = 7 ]; then
		echo -----------------------------------------------
		if [ "$dns_no" = "未禁用" ]; then
			echo -e "\033[31m仅限搭配其他DNS服务(比如dnsmasq、smartDNS)时使用！\033[0m"
			dns_no=已禁用
			echo -e "\033[32m已禁用DNS劫持！！！\033[0m"
		else
			dns_no=未禁用
			echo -e "\033[33m已启用DNS劫持！！！\033[0m"
		fi
		sleep 1
		setconfig dns_no $dns_no
		setdns
	fi
}
setipv6() { #ipv6设置
	[ -z "$ipv6_redir" ] && ipv6_redir=未开启
	[ -z "$ipv6_dns" ] && ipv6_dns=已开启
	[ -z "$cn_ipv6_route" ] && cn_ipv6_route=未开启
	echo -----------------------------------------------
	echo -e " 1 ipv6透明代理:  \033[36m$ipv6_redir\033[0m  ——代理ipv6流量"
	[ "$disoverride" != "1" ] && echo -e " 2 ipv6-DNS解析:  \033[36m$ipv6_dns\033[0m  ——决定内置DNS是否返回ipv6地址"
	echo -e " 3 CNV6绕过内核:  \033[36m$cn_ipv6_route\033[0m  ——优化性能，不兼容fake-ip"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case $num in
	0) ;;
	1)
		if [ "$ipv6_redir" = "未开启" ]; then
			ipv6_support=已开启
			ipv6_redir=已开启
			sleep 2
		else
			ipv6_redir=未开启
		fi
		setconfig ipv6_redir $ipv6_redir
		setconfig ipv6_support $ipv6_support
		setipv6
		;;
	2)
		[ "$ipv6_dns" = "未开启" ] && ipv6_dns=已开启 || ipv6_dns=未开启
		setconfig ipv6_dns $ipv6_dns
		setipv6
		;;
	3)
		if [ "$ipv6_redir" = "未开启" ]; then
			ipv6_support=已开启
			ipv6_redir=已开启
			setconfig ipv6_redir $ipv6_redir
			setconfig ipv6_support $ipv6_support
		fi
		if [ -n "$(ipset -v 2>/dev/null)" ] || [ "$firewall_mod" = nftables ]; then
			[ "$cn_ipv6_route" = "未开启" ] && cn_ipv6_route=已开启 || cn_ipv6_route=未开启
			setconfig cn_ipv6_route $cn_ipv6_route
		else
			echo -e "\033[31m当前设备缺少ipset模块或防火墙未使用nftables，无法启用绕过功能！！\033[0m"
			sleep 1
		fi
		setipv6
		;;
	*)
		errornum
		;;
	esac
}
setfirewall() { #防火墙设置
	set_cust_host_ipv4() {
		[ -z "$replace_default_host_ipv4" ] && replace_default_host_ipv4="未启用"

		echo -----------------------------------------------
		echo -e "当前默认透明路由的网段为: \033[32m$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'br' | grep -v 'iot' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/br.*$//g' | sed 's/metric.*$//g' | tr '\n' ' ' && echo) \033[0m"
		echo -e "当前已添加的自定义网段为:\033[36m$cust_host_ipv4\033[0m"
		echo -----------------------------------------------
		echo -e " 1 移除所有自定义网段"
		echo -e " 2 使用自定义网段覆盖默认网段	\033[36m$replace_default_host_ipv4\033[0m"
		echo -e " 0 返回上级菜单"
		read -p "请输入对应的序号或需要额外添加的网段 > " text
		case $text in
		2)
			if [ "$replace_default_host_ipv4" == "未启用" ]; then
				replace_default_host_ipv4="已启用"
			else
				replace_default_host_ipv4="未启用"
			fi
			setconfig replace_default_host_ipv4 "$replace_default_host_ipv4"
			set_cust_host_ipv4
			;;
		1)
			unset cust_host_ipv4
			setconfig cust_host_ipv4
			set_cust_host_ipv4
			;;
		0) ;;
		*)
			if [ -n "$(echo $text | grep -Eo '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}'$)" -a -z "$(echo $cust_host_ipv4 | grep "$text")" ]; then
				cust_host_ipv4="$cust_host_ipv4 $text"
				setconfig cust_host_ipv4 "'$cust_host_ipv4'"
			else
				echo -----------------------------------------------
				echo -e "\033[31m请输入正确的网段地址！\033[0m"
			fi
			sleep 1
			set_cust_host_ipv4
			;;
		esac
	}
	[ -z "$public_support" ] && public_support=未开启
	[ -z "$public_mixport" ] && public_mixport=未开启
	[ -z "$ipv6_dns" ] && ipv6_dns=已开启
	[ -z "$cn_ipv6_route" ] && cn_ipv6_route=未开启
	echo -----------------------------------------------
	echo -e " 1 公网访问Dashboard面板:	\033[36m$public_support\033[0m"
	echo -e " 2 公网访问Socks/Http代理:	\033[36m$public_mixport\033[0m"
	echo -e " 3 自定义透明路由ipv4网段:	适合vlan等复杂网络环境"
	echo -e " 4 自定义保留地址ipv4网段:	需要以保留地址为访问目标的环境"
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
	4)
		[ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
		echo -e "当前网段：\033[36m$reserve_ipv4\033[0m"
		echo -e "\033[33m地址必须是空格分隔，错误的设置可能导致网络回环或启动报错，请务必谨慎！\033[0m"
		read -p "请输入 > " text
		if [ -n "$(
			echo $text | grep -E "(((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])/(3[0-2]|[1-2]?[0-9]))( +|$)+"
		)" ]; then
			reserve_ipv4="$text"
			echo -e "已将保留地址网段设为：\033[32m$reserve_ipv4\033[0m"
			setconfig reserve_ipv4 "\'$reserve_ipv4\'"
		else
			echo -e "\033[31m输入有误，操作已取消！\033[0m"
		fi
		sleep 1
		setfirewall
		;;
	*)
		errornum
		;;
	esac
}
checkport() { #自动检查端口冲突
	for portx in $dns_port $mix_port $redir_port $db_port; do
		if [ -n "$(netstat -ntul 2>&1 | grep ':$portx ')" ]; then
			echo -----------------------------------------------
			echo -e "检测到端口【$portx】被以下进程占用！内核可能无法正常启动！\033[33m"
			echo $(netstat -ntul | grep :$portx | head -n 1)
			echo -e "\033[0m-----------------------------------------------"
			echo -e "\033[36m请修改默认端口配置！\033[0m"
			setport
			source $CFG_PATH >/dev/null
			checkport
		fi
	done
}
macfilter() { #局域网设备过滤
	get_devinfo() {
		dev_ip=$(cat $dhcpdir | grep $dev | awk '{print $3}') && [ -z "$dev_ip" ] && dev_ip=$dev
		dev_mac=$(cat $dhcpdir | grep $dev | awk '{print $2}') && [ -z "$dev_mac" ] && dev_mac=$dev
		dev_name=$(cat $dhcpdir | grep $dev | awk '{print $4}') && [ -z "$dev_name" ] && dev_name='未知设备'
	}
	add_mac() {
		echo -----------------------------------------------
		echo 已添加的mac地址：
		cat ${CRASHDIR}/configs/mac 2>/dev/null
		echo -----------------------------------------------
		echo -e "\033[33m序号   设备IP       设备mac地址       设备名称\033[32m"
		cat $dhcpdir | awk '{print " "NR" "$3,$2,$4}'
		echo -e "\033[0m-----------------------------------------------"
		echo -e "手动输入mac地址时仅支持\033[32mxx:xx:xx:xx:xx:xx\033[0m的形式"
		echo -e " 0 或回车 结束添加"
		echo -----------------------------------------------
		read -p "请输入对应序号或直接输入mac地址 > " num
		if [ -z "$num" -o "$num" = 0 ]; then
			i=
		elif [ -n "$(echo $num | grep -aE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$')" ]; then
			if [ -z "$(cat ${CRASHDIR}/configs/mac | grep -E "$num")" ]; then
				echo $num | grep -oE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$' >>${CRASHDIR}/configs/mac
			else
				echo -----------------------------------------------
				echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
			fi
			add_mac
		elif [ $num -le $(cat $dhcpdir 2>/dev/null | awk 'END{print NR}') ]; then
			macadd=$(cat $dhcpdir | awk '{print $2}' | sed -n "$num"p)
			if [ -z "$(cat ${CRASHDIR}/configs/mac | grep -E "$macadd")" ]; then
				echo $macadd >>${CRASHDIR}/configs/mac
			else
				echo -----------------------------------------------
				echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
			fi
			add_mac
		else
			echo -----------------------------------------------
			echo -e "\033[31m输入有误，请重新输入！\033[0m"
			add_mac
		fi
	}
	add_ip() {
		echo -----------------------------------------------
		echo "已添加的IP地址(段)："
		cat ${CRASHDIR}/configs/ip_filter 2>/dev/null
		echo -----------------------------------------------
		echo -e "\033[33m序号   设备IP     设备名称\033[32m"
		cat $dhcpdir | awk '{print " "NR" "$3,$4}'
		echo -e "\033[0m-----------------------------------------------"
		echo -e "手动输入时仅支持\033[32m 192.168.1.0/24\033[0m 或 \033[32m192.168.1.0\033[0m 的形式"
		echo -e "不支持ipv6地址过滤，如有需求请使用mac地址过滤"
		echo -e " 0 或回车 结束添加"
		echo -----------------------------------------------
		read -p "请输入对应序号或直接输入IP地址段 > " num
		if [ -z "$num" -o "$num" = 0 ]; then
			i=
		elif [ -n "$(echo $num | grep -aE '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$')" ]; then
			if [ -z "$(cat ${CRASHDIR}/configs/ip_filter | grep -E "$num")" ]; then
				echo $num | grep -oE '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$' >>${CRASHDIR}/configs/ip_filter
			else
				echo -----------------------------------------------
				echo -e "\033[31m已添加的地址，请勿重复添加！\033[0m"
			fi
			add_ip
		elif [ $num -le $(cat $dhcpdir 2>/dev/null | awk 'END{print NR}') ]; then
			ipadd=$(cat $dhcpdir | awk '{print $3}' | sed -n "$num"p)
			if [ -z "$(cat ${CRASHDIR}/configs/mac | grep -E "$ipadd")" ]; then
				echo $ipadd >>${CRASHDIR}/configs/ip_filter
			else
				echo -----------------------------------------------
				echo -e "\033[31m已添加的地址，请勿重复添加！\033[0m"
			fi
			add_ip
		else
			echo -----------------------------------------------
			echo -e "\033[31m输入有误，请重新输入！\033[0m"
			add_ip
		fi
	}
	del_all() {
		echo -----------------------------------------------
		if [ -z "$(cat ${CRASHDIR}/configs/mac ${CRASHDIR}/configs/ip_filter 2>/dev/null)" ]; then
			echo -e "\033[31m列表中没有需要移除的设备！\033[0m"
			sleep 1
		else
			echo -e "请选择需要移除的设备：\033[36m"
			echo -e "\033[33m      设备IP       设备mac地址       设备名称\033[0m"
			i=1
			for dev in $(cat ${CRASHDIR}/configs/mac ${CRASHDIR}/configs/ip_filter 2>/dev/null); do
				get_devinfo
				echo -e " $i \033[32m$dev_ip \033[36m$dev_mac \033[32m$dev_name\033[0m"
				i=$((i + 1))
			done
			echo -----------------------------------------------
			echo -e "\033[0m 0 或回车 结束删除"
			read -p "请输入需要移除的设备的对应序号 > " num
			mac_filter_rows=$(cat ${CRASHDIR}/configs/mac 2>/dev/null | wc -l)
			ip_filter_rows=$(cat ${CRASHDIR}/configs/ip_filter 2>/dev/null | wc -l)
			if [ -z "$num" ] || [ "$num" -le 0 ]; then
				n=
			elif [ $num -le $mac_filter_rows ]; then
				sed -i "${num}d" ${CRASHDIR}/configs/mac
				echo -----------------------------------------------
				echo -e "\033[32m对应设备已移除！\033[0m"
				del_all
			elif [ $num -le $((mac_filter_rows + ip_filter_rows)) ]; then
				num=$((num - mac_filter_rows))
				sed -i "${num}d" ${CRASHDIR}/configs/ip_filter
				echo -----------------------------------------------
				echo -e "\033[32m对应设备已移除！\033[0m"
				del_all
			else
				echo -----------------------------------------------
				echo -e "\033[31m输入有误，请重新输入！\033[0m"
				del_all
			fi
		fi
	}
	echo -----------------------------------------------
	[ -z "$dhcpdir" ] && [ -f /var/lib/dhcp/dhcpd.leases ] && dhcpdir='/var/lib/dhcp/dhcpd.leases'
	[ -z "$dhcpdir" ] && [ -f /var/lib/dhcpd/dhcpd.leases ] && dhcpdir='/var/lib/dhcpd/dhcpd.leases'
	[ -z "$dhcpdir" ] && [ -f /tmp/dhcp.leases ] && dhcpdir='/tmp/dhcp.leases'
	[ -z "$dhcpdir" ] && [ -f /tmp/dnsmasq.leases ] && dhcpdir='/tmp/dnsmasq.leases'
	[ -z "$dhcpdir" ] && dhcpdir='/dev/null'
	[ -z "$macfilter_type" ] && macfilter_type='黑名单'
	if [ "$macfilter_type" = "黑名单" ]; then
		macfilter_over='白名单'
		macfilter_scrip='不'
	else
		macfilter_over='黑名单'
		macfilter_scrip=''
	fi
	######
	echo -e "\033[30;47m请在此添加或移除设备\033[0m"
	echo -e "当前过滤方式为：\033[33m$macfilter_type模式\033[0m"
	echo -e "仅列表内设备流量\033[36m$macfilter_scrip经过\033[0m内核"
	if [ -n "$(cat ${CRASHDIR}/configs/mac)" ]; then
		echo -----------------------------------------------
		echo -e "当前已过滤设备为：\033[36m"
		echo -e "\033[33m 设备mac/ip地址       设备名称\033[0m"
		for dev in $(cat ${CRASHDIR}/configs/mac 2>/dev/null); do
			get_devinfo
			echo -e "\033[36m$dev_mac \033[0m$dev_name"
		done
		for dev in $(cat ${CRASHDIR}/configs/ip_filter 2>/dev/null); do
			get_devinfo
			echo -e "\033[32m$dev_ip  \033[0m$dev_name"
		done
		echo -----------------------------------------------
	fi
	echo -e " 1 切换为\033[33m$macfilter_over模式\033[0m"
	echo -e " 2 \033[32m添加指定设备(mac地址)\033[0m"
	echo -e " 3 \033[32m添加指定设备(IP地址/网段)\033[0m"
	echo -e " 4 \033[36m移除指定设备\033[0m"
	echo -e " 9 \033[31m清空整个列表\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	1)
		macfilter_type=$macfilter_over
		setconfig macfilter_type $macfilter_type
		echo -----------------------------------------------
		echo -e "\033[32m已切换为$macfilter_type模式！\033[0m"
		macfilter
		;;
	2)
		add_mac
		macfilter
		;;
	3)
		add_ip
		macfilter
		;;
	4)
		del_all
		macfilter
		;;
	9)
		: >${CRASHDIR}/configs/mac
		: >${CRASHDIR}/configs/ip_filter
		echo -----------------------------------------------
		echo -e "\033[31m设备列表已清空！\033[0m"
		macfilter
		;;
	*)
		errornum
		;;
	esac
}
setboot() { #启动相关设置
	[ -z "$start_old" ] && start_old=未开启
	[ -z "$start_delay" -o "$start_delay" = 0 ] && delay=未设置 || delay=${start_delay}秒
	[ "$autostart" = "enable" ] && auto_set="\033[33m禁止" || auto_set="\033[32m允许"
	[ "${BINDIR}" = "${CRASHDIR}" ] && mini_clash=未开启 || mini_clash=已开启
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用启动设置菜单：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 ${auto_set}\033[0mShellCrash开机启动"
	echo -e " 2 使用保守模式:	\033[36m$start_old\033[0m	————基于定时任务(每分钟检测)"
	echo -e " 3 设置自启延时:	\033[36m$delay\033[0m	————用于解决自启后服务受限"
	echo -e " 4 启用小闪存模式:	\033[36m$mini_clash\033[0m	————用于闪存空间不足的设备"
	[ "${BINDIR}" != "${CRASHDIR}" ] && echo -e " 5 设置小闪存目录:	\033[36m${BINDIR}\033[0m"
	echo -----------------------------------------------
	echo -e " 0 \033[0m返回上级菜单\033[0m"
	read -p "请输入对应数字 > " num
	echo -----------------------------------------------
	case "$num" in
	0) ;;
	1)
		if [ "$autostart" = "enable" ]; then
			[ -d /etc/rc.d ] && cd /etc/rc.d && rm -rf *shellcrash >/dev/null 2>&1 && cd - >/dev/null
			ckcmd systemctl && systemctl disable shellcrash.service >/dev/null 2>&1
			touch ${CRASHDIR}/.dis_startup
			autostart=disable
			echo -e "\033[33m已禁止ShellCrash开机启动！\033[0m"
		elif [ "$autostart" = "disable" ]; then
			[ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ] && /etc/init.d/shellcrash enable
			ckcmd systemctl && systemctl enable shellcrash.service >/dev/null 2>&1
			rm -rf ${CRASHDIR}/.dis_startup
			autostart=enable
			echo -e "\033[32m已设置ShellCrash开机启动！\033[0m"
		fi
		setboot
		;;
	2)
		if [ "$start_old" = "未开启" ] >/dev/null 2>&1; then
			echo -e "\033[33m改为使用保守模式启动服务！！\033[0m"
			[ -d /etc/rc.d ] && cd /etc/rc.d && rm -rf *shellcrash >/dev/null 2>&1 && cd - >/dev/null
			ckcmd systemctl && systemctl disable shellcrash.service >/dev/null 2>&1
			start_old=已开启
			setconfig start_old $start_old
			${CRASHDIR}/start.sh stop
		else
			if [ "$(cat /proc/1/comm)" = "procd" -o "$(cat /proc/1/comm)" = "systemd" ]; then
				echo -e "\033[32m改为使用系统守护进程启动服务！！\033[0m"
				${CRASHDIR}/start.sh cronset "ShellCrash初始化"
				start_old=未开启
				setconfig start_old $start_old
				${CRASHDIR}/start.sh stop

			else
				echo -e "\033[31m当前设备不支持以其他模式启动！！\033[0m"
			fi
		fi
		sleep 1
		setboot
		;;
	3)
		echo -e "\033[33m如果你的设备启动后可以正常使用，则无需设置！！\033[0m"
		echo -e "\033[36m推荐设置为30~120秒之间，请根据设备问题自行试验\033[0m"
		read -p "请输入启动延迟时间(0~300秒) > " sec
		case "$sec" in
		[0-9] | [0-9][0-9] | [0-2][0-9][0-9] | 300)
			start_delay=$sec
			setconfig start_delay $sec
			echo -e "\033[32m设置成功！\033[0m"
			;;
		*)
			echo -e "\033[31m输入有误，或超过300秒，请重新输入！\033[0m"
			;;
		esac
		sleep 1
		setboot
		;;
	4)
		dir_size=$(df ${CRASHDIR} | awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' | grep Ava | awk '{print $2}')
		if [ "$mini_clash" = "未开启" ]; then
			if [ "$dir_size" -gt 20480 ]; then
				echo -e "\033[33m您的设备空间充足(>20M)，无需开启！\033[0m"
			elif [ "start_old" != '已开启' -a "$(cat /proc/1/comm)" = "systemd" ]; then
				echo -e "\033[33m不支持systemd启动模式，请先启用保守模式！\033[0m"
			else
				[ "$BINDIR" = "$CRASHDIR" ] && BINDIR="$TMPDIR"
				echo -e "\033[32m已经启用小闪存功能！\033[0m"
				echo -e "如需更换目录，请使用【设置小闪存目录】功能\033[0m"
			fi
		else
			if [ "$dir_size" -lt 8192 ]; then
				echo -e "\033[31m您的设备剩余空间不足8M，停用后可能无法正常运行！\033[0m"
				read -p "确认停用此功能？(1/0) > " res
				[ "$res" = 1 ] && BINDIR="$CRASHDIR" && echo -e "\033[33m已经停用小闪存功能！\033[0m"
			else
				rm -rf /tmp/ShellCrash
				BINDIR="$CRASHDIR"
				echo -e "\033[33m已经停用小闪存功能！\033[0m"
			fi
		fi
		setconfig BINDIR ${BINDIR} ${CRASHDIR}/configs/command.env
		sleep 1
		setboot
		;;
	5)
		echo -e "\033[33m如设置到内存，则每次开机后都自动重新下载相关文件\033[0m"
		echo -e "\033[33m请确保安装源可用裸连，否则会导致启动失败\033[0m"
		echo " 1 使用内存(/tmp)"
		echo " 2 选择U盘目录"
		echo " 3 自定义目录"
		read -p "请输入相应数字 > " num
		case "$num" in
		1)
			BINDIR="$TMPDIR"
			;;
		2)
			set_usb_dir() {
				echo "请选择安装目录"
				du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
				read -p "请输入相应数字 > " num
				BINDIR=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
				if [ -z "$BINDIR" ]; then
					echo "\033[31m输入错误！请重新设置！\033[0m"
					set_usb_dir
				fi
			}
			set_usb_dir
			;;
		3)
			input_dir() {
				read -p "请输入自定义目录 > " BINDIR
				if [ ! -d "$BINDIR" ]; then
					echo "\033[31m输入错误！请重新设置！\033[0m"
					input_dir
				fi
			}
			input_dir
			;;
		*)
			errornum
			;;
		esac
		setconfig BINDIR ${BINDIR} ${CRASHDIR}/configs/command.env
		setboot
		;;
	*)
		errornum
		;;
	esac

}
set_firewall_area() { #防火墙模式设置
	[ -z "$vm_redir" ] && vm_redir='未开启'
	echo -----------------------------------------------
	echo -e "\033[31m注意：\033[0m基于桥接网卡的Docker/虚拟机流量，请单独启用6！"
	echo -e "\033[33m如你使用了第三方DNS如smartdns等，请勿启用本机代理或使用shellcrash用户执行！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 \033[32m仅劫持局域网流量\033[0m"
	echo -e " 2 \033[36m仅劫持本机流量\033[0m"
	echo -e " 3 \033[32m劫持局域网+本机流量\033[0m"
	echo -e " 4 不配置流量劫持(纯净模式)\033[0m"
	#echo -e " 5 \033[33m转发局域网流量到旁路由设备\033[0m"
	echo -e " 6 劫持容器/虚拟机流量： 	\033[36m$vm_redir\033[0m"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case $num in
	0) ;;
	[1-4])
		[ $firewall_area -ge 4 ] && {
			redir_mod=Redir模式
			setconfig redir_mod $redir_mod
		}
		[ "$num" = 4 ] && {
			redir_mod=纯净模式
			setconfig redir_mod $redir_mod
		}
		firewall_area=$num
		setconfig firewall_area $firewall_area
		;;
	5)
		echo -----------------------------------------------
		echo -e "\033[31m注意：\033[0m此功能存在多种风险如无网络基础请勿尝试！"
		echo -e "\033[33m说明：\033[0m此功能不启动内核仅配置防火墙转发，且子设备无需额外设置网关DNS"
		echo -e "\033[33m说明：\033[0m支持防火墙分流及设备过滤，支持部分定时任务，但不支持ipv6！"
		echo -e "\033[31m注意：\033[0m如需代理UDP，请确保旁路由运行了支持UDP代理的模式！"
		echo -e "\033[31m注意：\033[0m如使用systemd方式启动，内核依然会空载运行，建议使用保守模式！"
		echo -----------------------------------------------
		read -p "请输入旁路由IPV4地址 > " bypass_host
		[ -n "$bypass_host" ] && {
			firewall_area=$num
			setconfig firewall_area $firewall_area
			setconfig bypass_host $bypass_host
			redir_mod=TCP旁路转发
			setconfig redir_mod $redir_mod
		}
		;;
	6)
		if [ -n "$vm_ipv4" ]; then
			vm_des='当前劫持'
		else
			vm_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'brd' | grep -E 'docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | sed 's/.*inet.//g' | sed 's/ br.*$//g' | sed 's/metric.*$//g' | tr '\n' ' ')
			vm_des='当前获取到'
		fi
		echo -----------------------------------------------
		echo -e "$vm_des的容器/虚拟机网段为：\033[32m$vm_ipv4\033[0m"
		echo -e "如未包含容器网段，请先运行容器再运行脚本或者手动设置网段"
		echo -----------------------------------------------
		echo -e " 1 \033[32m启用劫持并使用默认网段\033[0m"
		echo -e " 2 \033[36m启用劫持并自定义网段\033[0m"
		echo -e " 3 \033[31m禁用劫持\033[0m"
		echo -e " 0 返回上级菜单"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		case $num in
		1)
			vm_redir=已开启
			;;
		2)
			echo -e "多个网段请用空格连接，可运行容器后使用【ip route】命令查看网段地址"
			echo -e "示例：\033[32m10.88.0.0/16 172.17.0.0/16\033[0m"
			read -p "请输入自定义网段 > " text
			[ -n "$text" ] && vm_ipv4=$text
			vm_redir=已开启
			;;
		3)
			vm_redir=未开启
			unset vm_ipv4
			;;
		*) ;;
		esac
		setconfig vm_redir $vm_redir
		setconfig vm_ipv4 "\'$vm_ipv4\'"
		set_firewall_area
		;;
	*) errornum ;;
	esac
	sleep 1
}
set_redir_mod() { #代理模式设置
	set_redir_config() {
		setconfig redir_mod $redir_mod
		setconfig dns_mod $dns_mod
		echo -----------------------------------------------
		echo -e "\033[36m已设为 $redir_mod ！！\033[0m"
	}
	[ -n "$(ls /dev/net/tun 2>/dev/null)" ] || ip tuntap >/dev/null 2>&1 && sup_tun=1
	[ -z "$firewall_area" ] && firewall_area=1
	[ -z "$firewall_mod" ] && firewall_mod=未设置
	firewall_area_dsc=$(echo "仅局域网 仅本机 局域网+本机 纯净模式 主-旁转发($bypass_host)" | cut -d' ' -f$firewall_area)
	echo -----------------------------------------------
	echo -e "当前代理模式为：\033[47;30m$redir_mod\033[0m；ShellCrash核心为：\033[47;30m $crashcore \033[0m"
	echo -e "\033[33m切换模式后需要手动重启服务以生效！\033[0m"
	echo -----------------------------------------------
	[ $firewall_area -le 3 ] && {
		echo -e " 1 \033[32mRedir模式\033[0m：    Redir转发TCP，不转发UDP"
		echo -e " 2 \033[36m混合模式\033[0m：     Redir转发TCP，Tun转发UDP"
		echo -e " 3 \033[32mTproxy模式\033[0m：   Tproxy转发TCP&UDP"
		echo -e " 4 \033[33mTun模式\033[0m：      Tun转发TCP&UDP(占用高不推荐)"
		echo -----------------------------------------------
	}
	[ "$firewall_area" = 5 ] && {
		echo -e " 5 \033[32mTCP旁路转发\033[0m：    仅转发TCP流量至旁路由"
		echo -e " 6 \033[36mT&U旁路转发\033[0m：    转发TCP&UDP流量至旁路由"
		echo -----------------------------------------------
	}
	echo -e " 7 设置劫持范围：\033[47;30m$firewall_area_dsc\033[0m"
	echo -e " 8 切换防火墙应用：\033[47;30m$firewall_mod\033[0m"
	echo -e " 9 ipv6设置：\033[47;30m$ipv6_redir\033[0m"
	echo " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	0) ;;
	1)
		redir_mod=Redir模式
		set_redir_config
		set_redir_mod
		;;
	2)
		if [ -n "$sup_tun" ]; then
			redir_mod=混合模式
			set_redir_config
		else
			echo -e "\033[31m设备未检测到Tun内核模块，请尝试其他模式或者安装相关依赖！\033[0m"
			sleep 1
		fi
		set_redir_mod
		;;
	3)
		if [ "$firewall_mod" = "iptables" ]; then
			if [ -f /etc/init.d/qca-nss-ecm -a "$systype" = "mi_snapshot" ]; then
				read -p "xiaomi设备的QOS服务与本模式冲突，是否禁用相关功能？(1/0) > " res
				[ "$res" = '1' ] && {
					${CRASHDIR}/misnap_init.sh tproxyfix
					redir_mod=Tproxy模式
					set_redir_config
				}
			elif grep -qE '^TPROXY$' /proc/net/ip_tables_targets || modprobe xt_TPROXY >/dev/null 2>&1; then
				redir_mod=Tproxy模式
				set_redir_config
			else
				echo -e "\033[31m设备未检测到iptables-mod-tproxy模块，请尝试其他模式或者安装相关依赖！\033[0m"
				sleep 1
			fi
		elif [ "$firewall_mod" = "nftables" ]; then
			if modprobe nft_tproxy >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q nft_tproxy; then
				redir_mod=Tproxy模式
				set_redir_config
			else
				echo -e "\033[31m设备未检测到nft_tproxy内核模块，请尝试其他模式或者安装相关依赖！\033[0m"
				sleep 1
			fi
		fi
		set_redir_mod
		;;
	4)
		if [ -n "$sup_tun" ]; then
			redir_mod=Tun模式
			set_redir_config
		else
			echo -e "\033[31m设备未检测到Tun内核模块，请尝试其他模式或者安装相关依赖！\033[0m"
			sleep 1
		fi
		set_redir_mod
		;;
	5)
		redir_mod=TCP旁路转发
		set_redir_config
		set_redir_mod
		;;
	6)
		redir_mod=T &
		U旁路转发
		set_redir_config
		set_redir_mod
		;;
	7)
		set_firewall_area
		set_redir_mod
		;;
	8)
		if [ "$firewall_mod" = 'iptables' ]; then
			if nft add table inet shellcrash 2>/dev/null; then
				firewall_mod=nftables
				redir_mod=Redir模式
				setconfig redir_mod $redir_mod
			else
				echo -e "\033[31m当前设备未安装nftables或者nftables版本过低(<1.0.2),无法切换！\033[0m"
			fi
		elif [ "$firewall_mod" = 'nftables' ]; then
			if ckcmd iptables; then
				firewall_mod=iptables
				redir_mod=Redir模式
				setconfig redir_mod $redir_mod
			else
				echo -e "\033[31m当前设备未安装iptables,无法切换！\033[0m"
			fi
		else
			iptables -j REDIRECT -h >/dev/null 2>&1 && firewall_mod=iptables
			nft add table inet shellcrash 2>/dev/null && firewall_mod=nftables
			if [ -n "$firewall_mod" ]; then
				redir_mod=Redir模式
				setconfig redir_mod $redir_mod
				setconfig firewall_mod $firewall_mod
			else
				echo -e "\033[31m检测不到可用的防火墙应用(iptables/nftables),无法切换！\033[0m"
			fi
		fi
		sleep 1
		setconfig firewall_mod $firewall_mod
		set_redir_mod
		;;
	9)
		setipv6
		set_redir_mod
		;;
	*)
		errornum
		;;
	esac
}
set_dns_mod() { #DNS设置
	echo -----------------------------------------------
	echo -e "当前DNS运行模式为：\033[47;30m $dns_mod \033[0m"
	echo -e "\033[33m切换模式后需要手动重启服务以生效！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 fake-ip模式：   \033[32m响应速度更快\033[0m"
	echo -e "                   不支持绕过CN-IP功能"
	if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
		echo -e " 3 mix混合模式：   \033[32m内部realip外部fakeip\033[0m"
		echo -e "                   依赖geosite-cn.(db/srs)数据库"
	elif [ "$crashcore" = meta ]; then
		echo -e " 2 redir_host模式：\033[32m兼容性更好\033[0m"
		echo -e "                   需搭配加密DNS使用"
	fi
	echo -e " 4 \033[36mDNS进阶设置\033[0m"
	echo " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	0) ;;
	1)
		dns_mod=fake-ip
		setconfig dns_mod $dns_mod
		echo -----------------------------------------------
		echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
		;;
	2)
		dns_mod=redir_host
		setconfig dns_mod $dns_mod
		echo -----------------------------------------------
		echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
		;;
	3)
		if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
			dns_mod=mix
			setconfig dns_mod $dns_mod
			echo -----------------------------------------------
			echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
		else
			echo -e "\033[31m当前内核不支持的功能！！！\033[0m"
			sleep 1
		fi
		;;
	4)
		setdns
		set_dns_mod
		;;
	*)
		errornum
		;;
	esac
}
fake_ip_filter() {
	echo -e "\033[32m用于解决Fake-ip模式下部分地址或应用无法连接的问题\033[0m"
	echo -e "\033[31m脚本已经内置了大量地址，你只需要添加出现问题的地址！\033[0m"
	echo -e "\033[36m示例：a.b.com"
	echo -e "示例：*.b.com"
	echo -e "示例：*.*.b.com\033[0m"
	echo -----------------------------------------------
	if [ -s ${CRASHDIR}/configs/fake_ip_filter ]; then
		echo -e "\033[33m已添加Fake-ip过滤地址：\033[0m"
		cat ${CRASHDIR}/configs/fake_ip_filter | awk '{print NR" "$1}'
	else
		echo -e "\033[33m你还未添加Fake-ip过滤地址\033[0m"
	fi
	echo -----------------------------------------------
	echo -e "\033[32m输入数字直接移除对应地址，输入地址直接添加！\033[0m"
	read -p "请输入数字或地址 > " input
	case $input in
	0) ;;
	'') ;;
	[0-99])
		sed -i "${input}d" ${CRASHDIR}/configs/fake_ip_filter 2>/dev/null
		echo -e "\033[32m移除成功！\033[0m"
		fake_ip_filter
		;;
	*)
		echo -e "你输入的地址是：\033[32m$input\033[0m"
		read -p "确认添加？(1/0) > " res
		[ "$res" = 1 ] && echo $input >>${CRASHDIR}/configs/fake_ip_filter
		fake_ip_filter
		;;
	esac
}
normal_set() { #基础设置
	#获取设置默认显示
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ -z "$common_ports" ] && common_ports=已开启
	[ -z "$dns_mod" ] && dns_mod=fake-ip
	[ -z "$dns_over" ] && dns_over=已开启
	[ -z "$cn_ip_route" ] && cn_ip_route=未开启
	[ -z "$local_proxy" ] && local_proxy=未开启
	[ -z "$quic_rj" ] && quic_rj=未开启
	[ -z "$(cat ${CRASHDIR}/configs/mac)" ] && mac_return=未开启 || mac_return=已启用
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用功能设置菜单：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 切换防火墙运行模式: 	\033[36m$redir_mod\033[0m"
	[ "$disoverride" != "1" ] && {
		echo -e " 2 切换DNS运行模式：	\033[36m$dns_mod\033[0m"
		echo -e " 3 跳过本地证书验证：	\033[36m$skip_cert\033[0m   ————解决节点证书验证错误"
	}
	echo -e " 4 只代理常用端口： 	\033[36m$common_ports\033[0m   ————用于过滤P2P流量"
	echo -e " 5 过滤局域网设备：	\033[36m$mac_return\033[0m   ————使用黑/白名单进行过滤"
	echo -e " 7 屏蔽QUIC流量:	\033[36m$quic_rj\033[0m   ————优化视频性能"
	[ "$disoverride" != "1" ] && {
		[ "$dns_mod" != "fake-ip" ] &&
			echo -e " 8 CN_IP绕过内核:	\033[36m$cn_ip_route\033[0m   ————优化性能，不兼容Fake-ip"
		[ "$dns_mod" != "redir_host" ] &&
			echo -e " 9 管理Fake-ip过滤列表"
	}
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then
		if [ "$USER" != "root" -a "$USER" != "admin" ]; then
			echo -----------------------------------------------
			read -p "非root用户可能无法正确配置其他模式！依然尝试吗？(1/0) > " res
			[ "$res" = 1 ] && set_redir_mod
		else
			set_redir_mod
		fi
		normal_set

	elif [ "$num" = 2 ]; then
		set_dns_mod
		normal_set

	elif [ "$num" = 3 ]; then
		echo -----------------------------------------------
		if [ "$skip_cert" = "未开启" ] >/dev/null 2>&1; then
			echo -e "\033[33m已设为开启跳过本地证书验证！！\033[0m"
			skip_cert=已开启
		else
			echo -e "\033[33m已设为禁止跳过本地证书验证！！\033[0m"
			skip_cert=未开启
		fi
		setconfig skip_cert $skip_cert
		normal_set

	elif [ "$num" = 4 ]; then
		set_common_ports() {
			if [ "$common_ports" = "未开启" ]; then
				echo -e "\033[33m已设为仅代理【$multiport】等常用端口！！\033[0m"
				echo -e "\033[31m注意，fake-ip模式下，非常用端口的域名连接将不受影响！！\033[0m"
				common_ports=已开启
				sleep 1
			else
				echo -e "\033[33m已设为代理全部端口！！\033[0m"
				common_ports=未开启
			fi
			setconfig common_ports $common_ports
		}
		echo -----------------------------------------------
		if [ -n "$(pidof CrashCore)" ]; then
			read -p "切换时将停止服务，是否继续？(1/0) > " res
			[ "$res" = 1 ] && ${CRASHDIR}/start.sh stop && set_common_ports
		else
			set_common_ports
		fi
		normal_set

	elif [ "$num" = 5 ]; then
		checkcfg_mac=$(cat ${CRASHDIR}/configs/mac)
		macfilter
		if [ -n "$PID" ]; then
			checkcfg_mac_new=$(cat ${CRASHDIR}/configs/mac)
			[ "$checkcfg_mac" != "$checkcfg_mac_new" ] && checkrestart
		fi
		normal_set

	elif [ "$num" = 7 ]; then
		echo -----------------------------------------------
		if [ -n "$(echo "$redir_mod" | grep -oE '混合|Tproxy|Tun')" ]; then
			if [ "$quic_rj" = "未开启" ]; then
				echo -e "\033[33m已禁止QUIC流量通过ShellCrash内核！！\033[0m"
				quic_rj=已启用
			else
				echo -e "\033[33m已取消禁止QUIC协议流量！！\033[0m"
				quic_rj=未开启
			fi
			setconfig quic_rj $quic_rj
		else
			echo -e "\033[33m当前模式默认不会代理UDP流量，无需设置！！\033[0m"
		fi
		sleep 1
		normal_set

	elif [ "$num" = 8 ]; then
		if [ -n "$(ipset -v 2>/dev/null)" ] || [ "$firewall_mod" = 'nftables' ]; then
			if [ "$cn_ip_route" = "未开启" ]; then
				echo -e "\033[32m已开启CN_IP绕过内核功能！！\033[0m"
				echo -e "\033[31m注意！！！此功能会导致全局模式及一切CN相关规则失效！！！\033[0m"
				cn_ip_route=已开启
				sleep 2
			else
				echo -e "\033[33m已禁用CN_IP绕过内核功能！！\033[0m"
				cn_ip_route=未开启
			fi
			setconfig cn_ip_route $cn_ip_route
		else
			echo -e "\033[31m当前设备缺少ipset模块或未使用nftables模式，无法启用绕过功能！！\033[0m"
			sleep 1
		fi
		normal_set

	elif [ "$num" = 9 ]; then
		echo -----------------------------------------------
		fake_ip_filter
		normal_set

	else
		errornum
	fi
}
advanced_set() { #进阶设置
	#获取设置默认显示
	[ -z "$proxies_bypass" ] && proxies_bypass=未启用
	[ -z "$start_old" ] && start_old=未开启
	[ -z "$tproxy_mod" ] && tproxy_mod=未开启
	[ -z "$public_support" ] && public_support=未开启
	[ -z "$sniffer" ] && sniffer=未启用
	[ "$crashcore" = "clashpre" ] && [ "$dns_mod" = "redir_host" ] && sniffer=已启用
	[ "$BINDIR" = "/tmp/ShellCrash" ] && mini_clash=已开启 || mini_clash=未开启
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用进阶模式菜单：\033[0m"
	echo -e "\033[33m如您并不了解ShellCrash的运行机制，请勿更改本页面功能！\033[0m"
	echo -----------------------------------------------
	#echo -e " 2 配置Meta特性"
	echo -e " 3 配置公网及局域网防火墙"
	[ "$disoverride" != "1" ] && {
		echo -e " 4 启用域名嗅探:	\033[36m$sniffer\033[0m	————用于流媒体及防DNS污染"
		echo -e " 5 自定义\033[32m端口及秘钥\033[0m"
	}
	echo -----------------------------------------------
	echo -e " 9 \033[31m重置/备份/还原\033[0m脚本设置"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0) ;;
	3)
		setfirewall
		advanced_set
		;;
	4)
		echo -----------------------------------------------
		if [ "$sniffer" = "未启用" ]; then
			if [ "$crashcore" = "clash" ]; then
				rm -rf ${TMPDIR}/CrashCore
				rm -rf ${CRASHDIR}/CrashCore
				rm -rf ${CRASHDIR}/CrashCore.tar.gz
				crashcore=meta
				setconfig crashcore $crashcore
				echo "已将ShellCrash内核切换为Meta内核！域名嗅探依赖Meta或者高版本clashpre内核！"
			fi
			sniffer=已启用
		elif [ "$crashcore" = "clashpre" -a "$dns_mod" = "redir_host" ]; then
			echo -e "\033[31m使用clashpre内核且开启redir-host模式时无法关闭！\033[0m"
		else
			sniffer=未启用
		fi
		setconfig sniffer $sniffer
		echo -e "\033[32m设置成功！\033[0m"
		sleep 1
		advanced_set
		;;
	5)
		if [ -n "$(pidof CrashCore)" ]; then
			echo -----------------------------------------------
			echo -e "\033[33m检测到服务正在运行，需要先停止服务！\033[0m"
			read -p "是否停止服务？(1/0) > " res
			if [ "$res" = "1" ]; then
				${CRASHDIR}/start.sh stop
				setport
			fi
		else
			setport
		fi
		advanced_set
		;;
	9)
		echo -e " 1 备份脚本设置"
		echo -e " 2 还原脚本设置"
		echo -e " 3 重置脚本设置"
		echo -e " 0 返回上级菜单"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			errornum
		elif [ "$num" = 0 ]; then
			i=
		elif [ "$num" = 1 ]; then
			cp -f $CFG_PATH $CFG_PATH.bak
			echo -e "\033[32m脚本设置已备份！\033[0m"
		elif [ "$num" = 2 ]; then
			if [ -f "$CFG_PATH.bak" ]; then
				mv -f $CFG_PATH $CFG_PATH.bak2
				mv -f $CFG_PATH.bak $CFG_PATH
				mv -f $CFG_PATH.bak2 $CFG_PATH.bak
				echo -e "\033[32m脚本设置已还原！(被覆盖的配置已备份！)\033[0m"
			else
				echo -e "\033[31m找不到备份文件，请先备份脚本设置！\033[0m"
			fi
		elif [ "$num" = 3 ]; then
			mv -f $CFG_PATH $CFG_PATH.bak
			source ${CRASHDIR}/init.sh >/dev/null
			echo -e "\033[32m脚本设置已重置！(旧文件已备份！)\033[0m"
		fi
		echo -e "\033[33m请重新启动脚本！\033[0m"
		exit 0
		;;
	*) errornum ;;
	esac
}
#工具脚本
autoSSH() {
	echo -----------------------------------------------
	echo -e "\033[33m本功能使用软件命令进行固化不保证100%成功！\033[0m"
	echo -e "\033[33m如有问题请加群反馈：\033[36;4mhttps://t.me/ShellClash\033[0m"
	read -p "请输入需要还原的SSH密码(不影响当前密码,回车可跳过) > " mi_autoSSH_pwd
	mi_autoSSH=已配置
	cp -f /etc/dropbear/dropbear_rsa_host_key ${CRASHDIR}/configs/dropbear_rsa_host_key 2>/dev/null
	cp -f /etc/dropbear/authorized_keys ${CRASHDIR}/configs/authorized_keys 2>/dev/null
	ckcmd nvram && {
		nvram set ssh_en=1
		nvram set telnet_en=1
		nvram set uart_en=1
		nvram set boot_wait=on
		nvram commit
	}
	echo -e "\033[32m设置成功！\033[0m"
	setconfig mi_autoSSH $mi_autoSSH
	setconfig mi_autoSSH_pwd $mi_autoSSH_pwd
	sleep 1
}
uninstall() {
	read -p "确认卸载ShellCrash？(警告：该操作不可逆！)[1/0] > " res
	if [ "$res" = '1' ]; then
		${CRASHDIR}/start.sh stop 2>/dev/null
		${CRASHDIR}/start.sh cronset "clash服务" 2>/dev/null
		${CRASHDIR}/start.sh cronset "订阅链接" 2>/dev/null
		${CRASHDIR}/start.sh cronset "ShellCrash初始化" 2>/dev/null
		${CRASHDIR}/start.sh cronset "task.sh" 2>/dev/null
		read -p "是否保留脚本配置及订阅文件？[1/0] > " res
		if [ "$res" = '1' ]; then
			mv -f ${CRASHDIR}/configs /tmp/ShellCrash
			mv -f ${CRASHDIR}/yamls /tmp/ShellCrash
			mv -f ${CRASHDIR}/jsons /tmp/ShellCrash
			rm -rf ${CRASHDIR}/*
			mv -f /tmp/ShellCrash/configs ${CRASHDIR}
			mv -f /tmp/ShellCrash/yamls ${CRASHDIR}
			mv -f /tmp/ShellCrash/jsons ${CRASHDIR}
		else
			rm -rf ${CRASHDIR}
		fi
		[ -w ~/.bashrc ] && profile=~/.bashrc
		[ -w /etc/profile ] && profile=/etc/profile
		sed -i '/alias clash=*/'d $profile
		sed -i '/alias crash=*/'d $profile
		sed -i '/export CRASHDIR=*/'d $profile
		sed -i '/export crashdir=*/'d $profile
		sed -i '/all_proxy/'d $profile
		sed -i '/ALL_PROXY/'d $profile
		sed -i "/启用外网访问SSH服务/d" /etc/firewall.user 2>/dev/null
		sed -i '/ShellCrash初始化/'d /etc/storage/started_script.sh 2>/dev/null
		sed -i '/ShellCrash初始化/'d /jffs/.asusrouter 2>/dev/null
		[ "$BINDIR" != "$CRASHDIR" ] && rm -rf ${BINDIR}
		rm -rf /etc/init.d/shellcrash
		rm -rf /etc/systemd/system/shellcrash.service
		rm -rf /usr/lib/systemd/system/shellcrash.service
		rm -rf /www/clash
		rm -rf /tmp/ShellCrash
		rm -rf /usr/bin/crash
		sed -i '/0:7890/d' /etc/passwd
		userdel -r shellcrash 2>/dev/null
		nvram set script_usbmount="" 2>/dev/null
		nvram commit 2>/dev/null
		uci delete firewall.ShellCrash 2>/dev/null
		uci commit firewall 2>/dev/null
		echo -----------------------------------------------
		echo -e "\033[36m已卸载ShellCrash相关文件！有缘再会！\033[0m"
		echo -e "\033[33m请手动关闭当前窗口以重置环境变量！\033[0m"
		echo -----------------------------------------------
		exit
	fi
	echo -e "\033[31m操作已取消！\033[0m"
}
tools() {
	ssh_tools() {
		stop_iptables() {
			iptables -w -t nat -D PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 >/dev/null 2>&1
			ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 >/dev/null 2>&1
		}
		[ -n "$(cat /etc/firewall.user 2>&1 | grep '启用外网访问SSH服务')" ] && ssh_ol=禁止 || ssh_ol=开启
		[ -z "$ssh_port" ] && ssh_port=10022
		echo -----------------------------------------------
		echo -e "\033[33m此功能仅针对使用Openwrt系统的设备生效，且不依赖服务\033[0m"
		echo -e "\033[31m本功能不支持红米AX6S等镜像化系统设备，请勿尝试！\033[0m"
		echo -----------------------------------------------
		echo -e " 1 \033[32m修改\033[0m外网访问端口：\033[36m$ssh_port\033[0m"
		echo -e " 2 \033[32m修改\033[0mSSH访问密码(请连续输入2次后回车)"
		echo -e " 3 \033[33m$ssh_ol\033[0m外网访问SSH"
		echo -----------------------------------------------
		echo -e " 0 返回上级菜单 \033[0m"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			errornum
		elif [ "$num" = 0 ]; then
			i=

		elif [ "$num" = 1 ]; then
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
			ssh_tools

		elif [ "$num" = 2 ]; then
			passwd
			sleep 1
			ssh_tools

		elif [ "$num" = 3 ]; then
			if [ "$ssh_ol" = "开启" ]; then
				iptables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22
				[ -n "$(ckcmd ip6tables)" ] && ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22
				echo "iptables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >>/etc/firewall.user
				[ -n "$(ckcmd ip6tables)" ] && echo "ip6tables -w -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >>/etc/firewall.user
				echo -----------------------------------------------
				echo -e "已开启外网访问SSH功能！"
			else
				sed -i "/启用外网访问SSH服务/d" /etc/firewall.user
				stop_iptables
				echo -----------------------------------------------
				echo -e "已禁止外网访问SSH！"
			fi
		else
			errornum
		fi
	}
	#获取设置默认显示
	grep -qE "^\s*[^#].*otapredownload" /etc/crontabs/root >/dev/null 2>&1 && mi_update=禁用 || mi_update=启用
	[ "$mi_autoSSH" = "已配置" ] && mi_autoSSH_type=32m已配置 || mi_autoSSH_type=31m未配置
	[ -f ${CRASHDIR}/tools/tun.ko ] && mi_tunfix=32m已启用 || mi_tunfix=31m未启用
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用其他工具菜单：\033[0m"
	echo -e "\033[33m本页工具可能无法兼容全部Linux设备，请酌情使用！\033[0m"
	echo -e "磁盘占用/所在目录："
	du -sh ${CRASHDIR}
	echo -----------------------------------------------
	echo -e " 1 ShellCrash\033[33m测试菜单\033[0m"
	echo -e " 2 ShellCrash\033[32m新手引导\033[0m"
	echo -e " 3 \033[36m日志及推送工具\033[0m"
	[ -f /etc/firewall.user ] && echo -e " 4 \033[32m配置\033[0m外网访问SSH"
	[ -x /usr/sbin/otapredownload ] && echo -e " 5 \033[33m$mi_update\033[0m小米系统自动更新"
	[ -f ${CRASHDIR}/misnap_init.sh ] && echo -e " 6 小米设备软固化SSH ———— \033[$mi_autoSSH_type \033[0m"
	[ -f /etc/config/ddns -a -d "/etc/ddns" ] && echo -e " 7 配置\033[32mDDNS服务\033[0m(需下载相关脚本)"
	[ -f ${CRASHDIR}/misnap_init.sh ] && echo -e " 8 小米设备Tun模块修复 ———— \033[$mi_tunfix \033[0m"
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=

	elif [ "$num" = 1 ]; then
		source ${CRASHDIR}/webget.sh && testcommand

	elif [ "$num" = 2 ]; then
		source ${CRASHDIR}/webget.sh && userguide

	elif [ "$num" = 3 ]; then
		log_pusher
		tools

	elif [ "$num" = 4 ]; then
		ssh_tools
		sleep 1
		tools

	elif [ "$num" = 7 ]; then
		echo -----------------------------------------------
		if [ ! -f ${CRASHDIR}/tools/ShellDDNS.sh ]; then
			echo -e "正在获取在线脚本……"
			${CRASHDIR}/start.sh get_bin ${TMPDIR}/ShellDDNS.sh tools/ShellDDNS.sh
			if [ "$?" = "0" ]; then
				mv -f ${TMPDIR}/ShellDDNS.sh ${CRASHDIR}/tools/ShellDDNS.sh
				source ${CRASHDIR}/tools/ShellDDNS.sh
			else
				echo -e "\033[31m文件下载失败！\033[0m"
			fi
		else
			source ${CRASHDIR}/tools/ShellDDNS.sh
		fi
		sleep 1
		tools

	elif [ -x /usr/sbin/otapredownload ] && [ "$num" = 5 ]; then
		if [ "$mi_update" = "禁用" ]; then
			grep -q "otapredownload" /etc/crontabs/root &&
				sed -i "/^[^\#]*otapredownload/ s/^/#/" /etc/crontabs/root ||
				echo "#15 3,4,5 * * * /usr/sbin/otapredownload >/dev/null 2>&1" >>/etc/crontabs/root
		else
			grep -q "otapredownload" /etc/crontabs/root &&
				sed -i "/^\s*#.*otapredownload/ s/^\s*#//" /etc/crontabs/root ||
				echo "15 3,4,5 * * * /usr/sbin/otapredownload >/dev/null 2>&1" >>/etc/crontabs/root
		fi
		echo -----------------------------------------------
		echo -e "已\033[33m$mi_update\033[0m小米路由器的自动更新，如未生效，请在官方APP中同步设置！"
		sleep 1
		tools

	elif [ "$num" = 6 ]; then
		if [ "$systype" = "mi_snapshot" ]; then
			autoSSH
		else
			echo 不支持的设备！
		fi
		tools
	elif [ "$num" = 8 ]; then
		if [ -f ${CRASHDIR}/tools/tun.ko ]; then
			read -p "是否禁用此功能并移除相关补丁？(1/0) > " res
			[ "$res" = 1 ] && {
				rm -rf ${CRASHDIR}/tools/tun.ko
				echo -e "\033[33m补丁文件已移除，请立即重启设备以防止出错！\033[0m"
			}
		elif [ -z "$(modinfo tun)" ]; then
			echo -e "\033[33m本功能需要修改系统文件，不保证没有任何风险！\033[0m"
			echo -e "\033[33m本功能采集的Tun模块并不一定适用于你的设备！\033[0m"
			sleep 1
			read -p "我已知晓，出现问题会自行承担！(1/0) > " res
			if [ "$res" = 1 ]; then
				echo -----------------------------------------------
				echo 正在连接服务器获取Tun模块补丁文件…………
				${CRASHDIR}/start.sh get_bin ${TMPDIR}/tun.ko bin/fix/tun.ko
				if [ "$?" = "0" ]; then
					mv -f ${TMPDIR}/tun.ko ${CRASHDIR}/tools/tun.ko &&
						${CRASHDIR}/misnap_init.sh tunfix &&
						echo -e "\033[32m设置成功！请重启服务！\033[0m"
				else
					echo -e "\033[31m文件下载失败，请重试！\033[0m"
				fi
			fi
		else
			echo -e "\033[31m当前设备无需设置，请勿尝试！\033[0m"
			sleep 1
		fi
		tools
	else
		errornum
	fi
}
#主菜单
main_menu() {
	#############################
	ckstatus
	#############################
	echo -e " 1 \033[32m启动/重启\033[0m服务"
	echo -e " 2 内核\033[33m功能设置\033[0m"
	echo -e " 3 \033[31m停止\033[0m内核服务"
	echo -e " 4 内核\033[36m启动设置\033[0m"
	echo -e " 5 配置\033[33m自动任务\033[0m"
	echo -e " 6 导入\033[32m配置文件\033[0m"
	echo -e " 7 内核\033[31m进阶设置\033[0m"
	echo -e " 8 \033[35m其他工具\033[0m"
	echo -e " 9 \033[36m更新/卸载\033[0m"
	echo -----------------------------------------------
	echo -e " 0 \033[0m退出脚本\033[0m"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
		exit

	elif [ "$num" = 0 ]; then
		exit

	elif [ "$num" = 1 ]; then
		start_service
		exit

	elif [ "$num" = 2 ]; then
		checkcfg=$(cat $CFG_PATH)
		normal_set
		if [ -n "$PID" ]; then
			checkcfg_new=$(cat $CFG_PATH)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
		main_menu

	elif [ "$num" = 3 ]; then
		${CRASHDIR}/start.sh stop
		sleep 1
		echo -----------------------------------------------
		echo -e "\033[31m$corename服务已停止！\033[0m"
		main_menu

	elif [ "$num" = 4 ]; then
		setboot
		main_menu

	elif [ "$num" = 5 ]; then
		source ${CRASHDIR}/task/task.sh && task_menu
		main_menu

	elif [ "$num" = 6 ]; then
		source ${CRASHDIR}/webget.sh && set_core_config
		main_menu

	elif [ "$num" = 7 ]; then
		checkcfg=$(cat $CFG_PATH)
		advanced_set
		if [ -n "$PID" ]; then
			checkcfg_new=$(cat $CFG_PATH)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
		main_menu

	elif [ "$num" = 8 ]; then
		tools
		main_menu

	elif [ "$num" = 9 ]; then
		checkcfg=$(cat $CFG_PATH)
		source ${CRASHDIR}/webget.sh && update
		if [ -n "$PID" ]; then
			checkcfg_new=$(cat $CFG_PATH)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
		main_menu

	else
		errornum
		exit
	fi
}

[ -z "$CRASHDIR" ] && {
	echo 环境变量配置有误！正在初始化~~~
	CRASHDIR=$(
		cd $(dirname $0)
		pwd
	)
	source ${CRASHDIR}/init.sh
	sleep 1
	echo 请重启SSH窗口以完成初始化！
	exit
}

[ -z "$1" ] && main_menu

case "$1" in
-h)
	echo -----------------------------------------
	echo "欢迎使用ShellCrash"
	echo -----------------------------------------
	echo "	-t 测试模式"
	echo "	-h 帮助列表"
	echo "	-u 卸载脚本"
	echo "	-i 初始化脚本"
	echo "	-d 测试运行"
	echo -----------------------------------------
	echo "	crash -s start	启动服务"
	echo "	crash -s stop	停止服务"
	echo "	安装目录/start.sh init		开机初始化"
	echo -----------------------------------------
	echo "在线求助：t.me/ShellClash"
	echo "官方博客：juewuy.github.io"
	echo "发布页面：github.com/juewuy/ShellCrash"
	echo -----------------------------------------
	;;
-t)
	shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
	$shtype -x ${CRASHDIR}/menu.sh
	;;
-s)
	${CRASHDIR}/start.sh $2 $3 $4 $5 $6
	;;
-i)
	source ${CRASHDIR}/init.sh
	;;
-st)
	shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
	$shtype -x ${CRASHDIR}/start.sh $2 $3 $4 $5 $6
	;;
-d)
	shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
	echo -e "正在测试运行！如发现错误请截图后前往\033[32;4mt.me/ShellClash\033[0m咨询"
	$shtype ${CRASHDIR}/start.sh debug >/dev/null 2>${TMPDIR}/debug_sh_bug.log
	$shtype -x ${CRASHDIR}/start.sh debug >/dev/null 2>${TMPDIR}/debug_sh.log
	echo -----------------------------------------
	cat ${TMPDIR}/debug_sh_bug.log | grep 'start\.sh' >${TMPDIR}/sh_bug
	if [ -s ${TMPDIR}/sh_bug ]; then
		while read line; do
			echo -e "发现错误：\033[33;4m$line\033[0m"
			grep -A 1 -B 3 "$line" ${TMPDIR}/debug_sh.log
			echo -----------------------------------------
		done <${TMPDIR}/sh_bug
		rm -rf ${TMPDIR}/sh_bug
		echo -e "\033[32m测试完成！\033[0m完整执行记录请查看：\033[36m${TMPDIR}/debug_sh.log\033[0m"
	else
		echo -e "\033[32m测试完成！没有发现问题，请重新启动服务~\033[0m"
		rm -rf ${TMPDIR}/debug_sh.log
	fi
	${CRASHDIR}/start.sh stop
	;;
-u)
	uninstall
	;;
*)
	$0 -h
	;;
esac
