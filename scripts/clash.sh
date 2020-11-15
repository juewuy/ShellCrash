#!/bin/sh
# Copyright (C) Juewuy

#读取配置相关
getconfig(){
	#服务器缺省地址
	[ -z "$update_url" ] && update_url=https://cdn.jsdelivr.net/gh/juewuy/ShellClash
	#文件路径
	[ -z "$clashdir" ] && echo 环境变量配置有误！请重新安装脚本！
	ccfg=$clashdir/mark
	yaml=$clashdir/config.yaml
	#检查/读取标识文件
	[ ! -f $ccfg ] && echo '#标识clash运行状态的文件，不明勿动！' > $ccfg
	source $ccfg
	#设置默认核心资源目录
	[ -z "$bindir" ] && bindir=$clashdir
	#设置默认端口及变量
	[ -z "$mix_port" ] && mix_port=7890
	[ -z "$redir_port" ] && redir_port=7892
	[ -z "$db_port" ] && db_port=9999
	[ -z "$dns_port" ] && dns_port=1053
	[ -z "$local_proxy" ] && local_proxy=未开启
	#检查mac地址记录
	[ ! -f $clashdir/mac ] && touch $clashdir/mac
	#获取本机host地址
	host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E '192.|10.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host=127.0.0.1
	#dashboard目录位置
	[ -d $clashdir/ui ] && dbdir=$clashdir/ui && hostdir=":$db_port/ui"
	[ -d /www/clash ] && dbdir=/www/clash && hostdir=/clash
	#开机自启相关
	if [ -f /etc/rc.common ];then
		[ -n "$(find /etc/rc.d -name '*clash')" ] && autostart=enable_rc || autostart=disable_rc
	else
		[ -n "$(systemctl is-enabled clash.service 2>&1 | grep enable)" ] && autostart=enable_sys || autostart=disable_sys
	fi
	#开机自启描述
	if [ "$start_old" = "已开启" ];then
		auto="\033[32m保守模式\033[0m"
		auto1="代理本机：\033[36m$local_proxy\033[0m"
	elif [ "$autostart" = "enable_rc" -o "$autostart" = "enable_sys" ]; then
		auto="\033[32m已设置开机启动！\033[0m"
		auto1="\033[36m禁用\033[0mclash开机启动"
	else
		auto="\033[31m未设置开机启动！\033[0m"
		auto1="\033[36m允许\033[0mclash开机启动"
	fi
	#获取运行模式
	[ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod=Redir模式
	[ -z "$redir_mod" ] && redir_mod=纯净模式
	#获取运行状态
	PID=$(pidof clash)
	if [ -n "$PID" ];then
		run="\033[32m正在运行（$redir_mod）\033[0m"
		VmRSS=`cat /proc/$PID/status|grep -w VmRSS|awk '{print $2,$3}'`
		#获取运行时长
		if [ -n "$start_time" ]; then 
			time=$((`date +%s`-start_time))
			day=$((time/86400))
			[ "$day" = "0" ] && day='' || day="$day天"
			time=`date -u -d @${time} +%H小时%M分%S秒`
		fi
	else
		run="\033[31m没有运行（$redir_mod）\033[0m"
		#检测系统端口占用
		checkport
	fi
	#输出状态
	echo -----------------------------------------------
	echo -e "\033[30;46m欢迎使用ShellClash！\033[0m		版本：$versionsh_l"
	echo -e "Clash服务"$run"，"$auto""
	if [ -n "$PID" ];then
		echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
	fi
	echo -e "TG群：\033[36;4mhttps://t.me/clashfm\033[0m"
	echo -----------------------------------------------
	#检查新手引导
	if [ -z "$userguide" ];then
		sed -i "1i\userguide=1" $ccfg
		[ "$res" = 1 ] && source $clashdir/getdate.sh && userguide
	fi
	#检查执行权限
	[ ! -x $clashdir/start.sh ] && chmod +x $clashdir/start.sh
}
setconfig(){
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath=$clashdir/mark || configpath=$3
	sed -i "/${1}*/"d $configpath
	echo "${1}=${2}" >> $configpath
}
#启动相关
errornum(){
	echo -----------------------------------------------
	echo -e "\033[31m请输入正确的数字！\033[0m"
}
startover(){
	echo -e "\033[32mclash服务已启动！\033[0m"
	if [ -n "$hostdir" ];then
		echo -e "请使用 \033[4;32mhttp://$host$hostdir\033[0m 管理内置规则"
	else
		echo -e "可使用 \033[4;32mhttp://clash.razord.top\033[0m 管理内置规则"
		echo -e "Host地址:\033[36m $host \033[0m 端口:\033[36m $db_port \033[0m"
		echo -e "推荐前往更新菜单安装本地Dashboard面板，连接更稳定！\033[0m"
	fi
	if [ "$redir_mod" = "纯净模式" ];then
		echo -----------------------------------------------
		echo -e "其他设备可以使用PAC配置连接：\033[4;32mhttp://$host:$db_port/ui/pac\033[0m"
		echo -e "或者使用HTTP/SOCK5方式连接：IP{\033[36m$host\033[0m}端口{\033[36m$mix_port\033[0m}"
	fi
}
clashstart(){
	#检查yaml配置文件
	if [ ! -f "$yaml" ];then
		echo -----------------------------------------------
		echo -e "\033[31m没有找到配置文件，请先导入配置文件！\033[0m"
		source $clashdir/getdate.sh && clashlink
	fi
	echo -----------------------------------------------
	$clashdir/start.sh start
	sleep 1
	[ -n "$(pidof clash)" ] && startover || exit 1
}
#功能相关
setport(){
	inputport(){
		read -p "请输入端口号(1000-65535) > " portx
		if [ -z "$portx" ]; then
			setport
		elif [ $portx -gt 65535 -o $portx -le 999 ]; then
			echo -e "\033[31m输入错误！请输入正确的数值(1000-65535)！\033[0m"
			inputport
		elif [ -n "$(echo $mix_port$redir_port$dns_port$db_port|grep $portx)" ]; then
			echo -e "\033[31m输入错误！请不要输入重复的端口！\033[0m"
			inputport
		elif [ -n "$(netstat -ntul |grep :$portx)" ];then
			echo -e "\033[31m当前端口已被其他进程占用，请重新输入！\033[0m"
			inputport
		else
			setconfig $xport $portx 
			echo -e "\033[32m设置成功！！！\033[0m"
			setport
		fi
	}
	source $ccfg
	[ -z "$secret" ] && secret=未设置
	[ -z "$authentication" ] && authentication=未设置
	if [ -n "$(pidof clash)" ];then
		echo -----------------------------------------------
		echo -e "\033[33m检测到clash服务正在运行，需要先停止clash服务！\033[0m"
		read -p "是否停止clash服务？(1/0) > " res
		if [ "$res" = "1" ];then
			$clashdir/start.sh stop
		else
			clashadv
		fi
	fi
	echo -----------------------------------------------
	echo -e " 1 修改Http/Sock5端口：	\033[36m$mix_port\033[0m"
	echo -e " 2 设置Http/Sock5密码：	\033[36m$authentication\033[0m"
	echo -e " 3 修改静态路由端口：	\033[36m$redir_port\033[0m"
	echo -e " 4 修改DNS监听端口：	\033[36m$dns_port\033[0m"
	echo -e " 5 修改面板访问端口：	\033[36m$db_port\033[0m"
	echo -e " 6 设置面板访问密码：	\033[36m$secret\033[0m"
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
		echo -e "请尽量不要使用特殊符号！可能会产生未知错误！"
		echo -e "\033[31m需要使用本机代理功能时，请勿设置密码！\033[0m"
		echo "输入 0 删除密码"
		echo -----------------------------------------------
		read -p "请输入Http/Sock5用户名及密码 > " input
		if [ "$input" = "0" ];then
			authentication=""
			sed -i "/authentication*/"d $ccfg
			echo 密码已移除！
		else
			if [ "$local_proxy" = "已开启" ];then
				echo -----------------------------------------------
				echo -e "\033[33m请先禁用本机代理功能！\033[0m"
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
	fi	
}
setdns(){
	source $ccfg
	if [ "$dns_no" = "已禁用" ];then
		read -p "检测到内置DNS已被禁用，是否启用内置DNS？(1/0) > " res
		if [ "$res" = "1" ];then
			sed -i "/dns_no*/"d $ccfg
		else
			clashadv
		fi
	fi
	[ -z "$dns_nameserver" ] && dns_nameserver='114.114.114.114, 223.5.5.5'
	[ -z "$dns_fallback" ] && dns_fallback='1.0.0.1, 8.8.4.4'
	echo -----------------------------------------------
	echo -e "当前基础DNS：\033[32m$dns_nameserver\033[0m"
	echo -e "fallbackDNS：\033[36m$dns_fallback\033[0m"
	echo -e "多个DNS地址请用\033[30;47m | \033[0m分隔一次性输入"
	echo -e "\033[33m使用redir-host时，fallback组暂不支持tls或者https形式的DNS\033[0m"
	echo -----------------------------------------------
	echo -e " 1 修改\033[32m基础DNS\033[0m"
	echo -e " 2 修改\033[36mfallback_DNS\033[0m"
	echo -e " 3 \033[33m重置\033[0mDNS配置"
	echo -e " 4 禁用内置DNS(慎用)"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then 
		errornum
		clashadv
	elif [ "$num" = 1 ]; then
		read -p "请输入新的DNS > " dns_nameserver
		dns_nameserver=$(echo $dns_nameserver | sed 's/|/\,\ /g')
		if [ -n "$dns_nameserver" ]; then
			setconfig dns_nameserver \'"$dns_nameserver"\'
			echo -e "\033[32m设置成功！！！\033[0m"
		fi
	elif [ "$num" = 2 ]; then
		read -p "请输入新的DNS > " dns_fallback
		dns_fallback=$(echo $dns_fallback | sed 's/|/\,\ /g')
		if [ -n "$dns_fallback" ]; then
			setconfig dns_fallback \'"$dns_fallback"\' 
			echo -e "\033[32m设置成功！！！\033[0m"
		fi	
	elif [ "$num" = 3 ]; then
		dns_nameserver=""
		dns_fallback=""
		sed -i "/dns_nameserver*/"d $ccfg
		sed -i "/dns_fallback*/"d $ccfg
		echo -e "\033[33mDNS配置已重置！！！\033[0m"
	elif [ "$num" = 4 ]; then
		echo -----------------------------------------------
		echo -e "\033[31m仅限搭配其他DNS服务(比如dnsmasq、smartDNS)时使用！\033[0m"
		dns_no=已禁用
		setconfig dns_no $dns_no
		echo -e "\033[33m已禁用内置DNS！！！\033[0m"
		clashadv
	else
		clashadv
	fi
	setdns
}
checkport(){
	for portx in $dns_port $mix_port $redir_port $db_port ;do
		if [ -n "$(netstat -ntul 2>&1 |grep :$portx)" ];then
			echo -----------------------------------------------
			echo -e "检测到端口【$portx】被以下进程占用！clash可能无法正常启动！\033[33m"
			echo $(netstat -ntulp | grep :$portx | head -n 1)
			echo -e "\033[0m-----------------------------------------------"
			echo -e "\033[36m请修改默认端口配置！\033[0m"
			setport
			source $ccfg
			checkport
		fi
	done
}
macfilter(){
	add_mac(){
		echo -----------------------------------------------
		echo 已添加的mac地址：
		cat $clashdir/mac
		echo -----------------------------------------------
		echo -e "\033[33m序号   设备IP       设备mac地址       设备名称\033[32m"
		cat $dhcpdir | awk '{print " "NR" "$3,$2,$4}'
		echo -e "\033[0m-----------------------------------------------"
		echo -e "手动输入mac地址时仅支持\033[32mxx:xx:xx:xx:xx:xx\033[0m的形式"
		echo -e " 0 或回车 结束添加"
		echo -----------------------------------------------
		read -p "请输入对应序号或直接输入mac地址 > " num
		if [ -z "$num" -o "$num" = 0 ]; then
			macfilter
		elif [ -n "$(echo $num | grep -E '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$')" ];then
			if [ -z "$(cat $clashdir/mac | grep -E "$num")" ];then
				echo $num | grep -oE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$' >> $clashdir/mac
			else
				echo -----------------------------------------------
				echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
			fi
		elif [ $num -le $(cat $dhcpdir | awk 'END{print NR}') 2>/dev/null ]; then
			macadd=$(cat $dhcpdir | awk '{print $2}' | sed -n "$num"p)
			if [ -z "$(cat $clashdir/mac | grep -E "$macadd")" ];then
				echo $macadd >> $clashdir/mac
			else
				echo -----------------------------------------------
				echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
			fi
		else
			echo -----------------------------------------------
			echo -e "\033[31m输入有误，请重新输入！\033[0m"
		fi
		add_mac
	}
	del_mac(){
		echo -----------------------------------------------
		if [ -z "$(cat $clashdir/mac)" ];then
			echo -e "\033[31m列表中没有需要移除的设备！\033[0m"
			macfilter
		fi
		echo -e "\033[33m序号   设备IP       设备mac地址       设备名称\033[0m"
		i=1
		for mac in $(cat $clashdir/mac); do
			dev_ip=$(cat $dhcpdir | grep $mac | awk '{print $3}') && [ -z "$dev_ip" ] && dev_ip='000.000.00.00'
			dev_mac=$(cat $dhcpdir | grep $mac | awk '{print $2}') && [ -z "$dev_mac" ] && dev_mac=$mac
			dev_name=$(cat $dhcpdir | grep $mac | awk '{print $4}') && [ -z "$dev_name" ] && dev_name='未知设备'
			echo -e " $i \033[32m$dev_ip \033[36m$dev_mac \033[32m$dev_name\033[0m"
			i=$((i+1))
		done
		echo -----------------------------------------------
		echo -e "\033[0m 0 或回车 结束删除"
		read -p "请输入需要移除的设备的对应序号 > " num
		if [ -z "$num" ]||[ "$num" -le 0 ]; then
			macfilter
		elif [ $num -le $(cat $clashdir/mac | wc -l) ];then
			sed -i "${num}d" $clashdir/mac
			echo -----------------------------------------------
			echo -e "\033[32m对应设备已移除！\033[0m"
		else
			echo -----------------------------------------------
			echo -e "\033[31m输入有误，请重新输入！\033[0m"
		fi
		del_mac
	}
	echo -----------------------------------------------
	[ -f /var/lib/dhcp/dhcpd.leases ] && dhcpdir='/var/lib/dhcp/dhcpd.leases'
	[ -f /var/lib/dhcpd/dhcpd.leases ] && dhcpdir='/var/lib/dhcpd/dhcpd.leases'
	[ -f /tmp/dhcp.leases ] && dhcpdir='/tmp/dhcp.leases'
	[ -z "$dhcpdir" ] && dhcpdir='/dev/null'
	[ -z "$macfilter_type" ] && macfilter_type='黑名单' 
	[ "$macfilter_type" = "黑名单" ] && macfilter_over='白名单' || macfilter_over='黑名单'
	######
	echo -e "\033[30;47m请在此添加或移除设备\033[0m"
	echo -e "当前过滤方式为：\033[33m$macfilter_type模式\033[0m"
	if [ -n "$(cat $clashdir/mac)" ]; then
		echo -----------------------------------------------
		echo -e "当前已过滤设备为：\033[36m"
		echo -e "\033[33m   设备IP       设备mac地址       设备名称\033[0m"
		for mac in $(cat $clashdir/mac); do
			dev_ip=$(cat $dhcpdir | grep $mac | awk '{print $3}') && [ -z "$dev_ip" ] && dev_ip='000.000.00.00'
			dev_mac=$(cat $dhcpdir | grep $mac | awk '{print $2}') && [ -z "$dev_mac" ] && dev_mac=$mac
			dev_name=$(cat $dhcpdir | grep $mac | awk '{print $4}') && [ -z "$dev_name" ] && dev_name='未知设备'
			echo -e "\033[32m$dev_ip \033[36m$dev_mac \033[32m$dev_name\033[0m"
		done
		echo -----------------------------------------------
	fi
	echo -e " 1 切换为\033[33m$macfilter_over模式\033[0m"
	echo -e " 2 \033[32m添加指定设备\033[0m"
	echo -e " 3 \033[36m移除指定设备\033[0m"
	echo -e " 4 \033[31m清空整个列表\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
		clashcfg
	elif [ "$num" = 0 ]; then
		clashcfg
	elif [ "$num" = 1 ]; then
		macfilter_type=$macfilter_over
		setconfig macfilter_type $macfilter_type
		echo -----------------------------------------------
		echo -e "\033[31m已切换为$macfilter_type模式！\033[0m"
		macfilter
	elif [ "$num" = 2 ]; then	
		add_mac
	elif [ "$num" = 3 ]; then	
		del_mac
	elif [ "$num" = 4 ]; then
		:>$clashdir/mac
		echo -----------------------------------------------
		echo -e "\033[31m设备列表已清空！\033[0m"
		macfilter
	else
		errornum
		macfilter
	fi
}
localproxy(){
	[ -z "$local_proxy" ] && local_proxy='未开启'
	[ -z "$local_proxy_type" ] && local_proxy_type='环境变量'
	[ "$local_proxy" = "已开启" ] && proxy_set='禁用' || proxy_set='启用'
	echo -----------------------------------------------
	echo -e "\033[33m当前本机代理配置方式为：\033[32m$local_proxy_type\033[0m"
	echo -----------------------------------------------
	echo -e " 1 \033[36m$proxy_set本机代理\033[0m"
	echo -e " 2 使用\033[32m环境变量\033[0m方式配置"
	echo -e " 3 使用\033[32mGNOME桌面API\033[0m配置"
	echo -e " 4 使用\033[32mKDE桌面API\033[0m配置"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then 
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then
		echo -----------------------------------------------
		if [ "$local_proxy" = "未开启" ]; then 
			if [ -n "$authentication" ] && [ "$authentication" != "未设置" ] ;then
				echo -e "\033[32m检测到您已经设置了Http/Sock5代理密码，请先取消密码！\033[0m"
				sleep 1
				setport
				localproxy
			else
				local_proxy=已开启
				$clashdir/start.sh set_proxy $mix_port $db_port
				echo -e "\033[32m已经成功使用$local_proxy_type方式配置本机代理~\033[0m"
				[ "$local_proxy_type" = "环境变量" ] && echo -e "\033[36m如未生效，请重新启动终端或重新连接SSH！\033[0m" && sleep 1
			fi		
		else
			local_proxy=未开启
			$clashdir/start.sh unset_proxy
			echo -e "\033[33m已经停用本机代理规则！！\033[0m"
			[ "$local_proxy_type" = "环境变量" ] && echo -e "\033[36m如未生效，请重新启动终端或重新连接SSH！\033[0m" && sleep 1
		fi
		setconfig local_proxy $local_proxy
	elif [ "$num" = 2 ]; then
		local_proxy_type="环境变量"
		setconfig local_proxy_type $local_proxy_type
		localproxy
	elif [ "$num" = 3 ]; then
		if  gsettings --version >/dev/null 2>&1 ;then
			local_proxy_type="GNOME"
			setconfig local_proxy_type $local_proxy_type
		else
			echo -e "\033[31m没有找到GNOME桌面，无法设置！\033[0m"
			sleep 1
		fi
		localproxy
	elif [ "$num" = 4 ]; then
		if  kwriteconfig5 -h >/dev/null 2>&1 ;then
			local_proxy_type="KDE"
			setconfig local_proxy_type $local_proxy_type
		else
			echo -e "\033[31m没有找到KDE桌面，无法设置！\033[0m"
			sleep 1
		fi
		localproxy
	else
		errornum
	fi	
}
clashcfg(){
	set_redir_mod(){
		echo -----------------------------------------------
		echo -e "当前代理模式为：\033[47;30m $redir_mod \033[0m；Clash核心为：\033[47;30m $clashcore \033[0m"
		echo -e "\033[33m切换模式后需要手动重启clash服务以生效！\033[0m"
		echo -e "\033[36mTun及混合模式必须使用clashpre核心！\033[0m"
		echo -----------------------------------------------
		echo " 1 Redir模式：CPU以及内存占用较低"
		echo "              但不支持UDP流量转发"
		echo "              适合非游戏用户使用"
		echo " 2 Tun模式：  支持UDP转发且延迟最低"
		echo "              CPU占用极高，只支持fake-ip模式"
		echo "              适合游戏用户、非大流量用户"
		echo " 3 混合模式： 使用redir转发TCP，Tun转发UPD"
		echo "              速度较快，内存占用略高"
		echo "              适合游戏用户、综合用户"
		echo " 4 纯净模式： 不设置iptables静态路由"
		echo "              必须手动配置http/sock5代理"
		echo "              或使用内置的PAC文件配置代理"
		echo " 0 返回上级菜单"
		read -p "请输入对应数字 > " num	
		if [ -z "$num" ]; then
			errornum
			clashcfg
		elif [ "$num" = 0 ]; then
			clashcfg
		elif [ "$num" = 1 ]; then
			redir_mod=Redir模式
		elif [ "$num" = 2 ]; then
			modinfo tun >/dev/null 2>&1
			if [ "$?" != 0 ];then
				echo -----------------------------------------------
				echo -e "\033[31m当前设备内核可能不支持开启Tun/混合模式！\033[0m"
				read -p "是否强制开启？可能无法正常使用！(1/0) > " res
				if [ "$res" = 1 ];then
					redir_mod=Tun模式
					dns_mod=fake-ip
				else
					set_redir_mod
				fi
			elif [ "$clashcore" = "clash" ] || [ "$clashcore" = "clashr" ];then
				echo -----------------------------------------------
				echo -e "\033[31m当前核心不支持开启Tun模式！请先切换clash核心！！！\033[0m"
				sleep 1
				clashcfg
			else	
				redir_mod=Tun模式
				dns_mod=fake-ip
			fi
		elif [ "$num" = 3 ]; then
			modinfo tun >/dev/null 2>&1
			if [ "$?" != 0 ];then
				echo -e "\033[31m当前设备内核可能不支持开启Tun/混合模式！\033[0m"
				read -p "是否强制开启？可能无法正常使用！(1/0) > " res
				if [ "$res" = 1 ];then
					redir_mod=混合模式
				else
					set_redir_mod
				fi
			elif [ "$clashcore" = "clash" ] || [ "$clashcore" = "clashr" ];then
				echo -----------------------------------------------
				echo -e "\033[31m当前核心不支持开启Tun模式！请先切换clash核心！！！\033[0m"
				sleep 1
				clashcfg
			else	
				redir_mod=混合模式	
			fi
		elif [ "$num" = 4 ]; then
			redir_mod=纯净模式			
			echo -----------------------------------------------
			echo -e "\033[33m当前模式需要手动在设备WiFi或应用中配置HTTP或sock5代理\033[0m"
			echo -e "HTTP/SOCK5代理服务器地址：\033[30;47m$host\033[0m;端口均为：\033[30;47m$mix_port\033[0m"
			echo -e "也可以使用更便捷的PAC自动代理，PAC代理链接为："
			echo -e "\033[30;47m http://$host:$db_port/ui/pac \033[0m"
			echo -e "PAC的使用教程请参考：\033[4;32mhttps://juewuy.github.io/ehRUeewcv\033[0m"
			sleep 2
		else
			errornum
			clashcfg
		fi
		setconfig redir_mod $redir_mod
		setconfig dns_mod $dns_mod 
		echo -----------------------------------------------	
		echo -e "\033[36m已设为 $redir_mod ！！\033[0m"
	}
	set_dns_mod(){
		echo -----------------------------------------------
		echo -e "当前DNS运行模式为：\033[47;30m $dns_mod \033[0m"
		echo -e "\033[33m切换模式后需要手动重启clash服务以生效！\033[0m"
		echo -----------------------------------------------
		echo " 1 fake-ip模式：   响应速度更快"
		echo "                   可能与某些局域网设备有冲突"
		echo " 2 redir_host模式：兼容性更好"
		echo "                   不支持Tun模式，可能存在DNS污染"
		echo " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			errornum
			clashcfg
		elif [ "$num" = 0 ]; then
			clashcfg
		elif [ "$num" = 1 ]; then
			dns_mod=fake-ip
		elif [ "$num" = 2 ]; then
			dns_mod=redir_host
		else
			errornum
			clashcfg
		fi
		setconfig dns_mod $dns_mod 
		echo -----------------------------------------------	
		echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
	}
	
	#获取设置默认显示
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ -z "$common_ports" ] && common_ports=已开启
	[ -z "$dns_mod" ] && dns_mod=redir_host
	[ -z "$dns_over" ] && dns_over=已开启
	[ -z "$(cat $clashdir/mac)" ] && mac_return=未开启 || mac_return=已启用
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用功能设置菜单：\033[0m"
	echo -e "\033[32m修改配置后请手动重启clash服务！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 切换Clash运行模式: 	\033[36m$redir_mod\033[0m"
	echo -e " 2 切换DNS运行模式：	\033[36m$dns_mod\033[0m"
	echo -e " 3 跳过本地证书验证：	\033[36m$skip_cert\033[0m   ————解决节点证书验证错误"
	echo -e " 4 只代理常用端口： 	\033[36m$common_ports\033[0m   ————用于过滤P2P流量"
	echo -e " 5 过滤局域网设备：	\033[36m$mac_return\033[0m   ————当前为$macfilter_type模式"
	echo -e " 6 设置本机代理服务:	\033[36m$local_proxy\033[0m	————使用环境变量或GUI/api配置本机代理"
	echo -----------------------------------------------
	echo -e " 9 \033[32m重启\033[0mclash服务"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
		clashsh
	elif [ "$num" = 0 ]; then
		clashsh  
	elif [ "$num" = 1 ]; then
		if [ "$USER" != "root" -a "$USER" != "admin" ];then
			echo -----------------------------------------------
			echo -e "\033[33m非root用户无法启用静态路由，仅可以使用纯净模式！\033[0m"
			sleep 1
		else
			set_redir_mod
		fi
		clashcfg
	  
	elif [ "$num" = 2 ]; then
		set_dns_mod
		clashcfg
	
	elif [ "$num" = 3 ]; then	
		echo -----------------------------------------------
		if [ "$skip_cert" = "未开启" ] > /dev/null 2>&1; then 
			echo -e "\033[33m已设为开启跳过本地证书验证！！\033[0m"
			skip_cert=已开启
		else
			echo -e "\033[33m已设为禁止跳过本地证书验证！！\033[0m"
			skip_cert=未开启
		fi
		setconfig skip_cert $skip_cert 
		clashcfg
	
	elif [ "$num" = 4 ]; then	
		echo -----------------------------------------------
		if [ "$common_ports" = "未开启" ] > /dev/null 2>&1; then 
			echo -e "\033[33m已设为仅代理（53,587,465,995,993,143,80,443）等常用端口！！\033[0m"
			common_ports=已开启
		else
			echo -e "\033[33m已设为代理全部端口！！\033[0m"
			common_ports=未开启
		fi
		setconfig common_ports $common_ports
		clashcfg  

	elif [ "$num" = 5 ]; then	
		macfilter
		
	elif [ "$num" = 6 ]; then	
		localproxy
		sleep 1
		clashcfg
		
	elif [ "$num" = 9 ]; then	
		clashstart
		clashsh
	else
		errornum
		clashsh
	fi
}
clashadv(){
	#获取设置默认显示
	[ -z "$modify_yaml" ] && modify_yaml=未开启
	[ -z "$ipv6_support" ] && ipv6_support=未开启
	[ -z "$start_old" ] && start_old=未开启
	[ -z "$tproxy_mod" ] && tproxy_mod=未开启
	[ "$bindir" = "/tmp/clash_$USER" ] && mini_clash=已开启 || mini_clash=未开启
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用进阶模式菜单：\033[0m"
	echo -e "\033[33m如您不是很了解clash的运行机制，请勿更改！\033[0m"
	echo -e "\033[32m修改配置后请手动重启clash服务！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 使用保守方式启动:	\033[36m$start_old\033[0m	————切换时会停止clash服务"
	echo -e " 2 启用ipv6支持:	\033[36m$ipv6_support\033[0m	————实验性功能，可能不稳定"
	echo -e " 3 Redir模式udp转发:	\033[36m$tproxy_mod\033[0m	————依赖iptables-mod-tproxy"
	echo -e " 4 启用小闪存模式:	\033[36m$mini_clash\033[0m	————启动时方下载核心及数据库文件"
	echo -e " 5 配置内置DNS服务:	\033[36m$dns_no\033[0m"
	echo -e " 6 手动指定clash运行端口及秘钥"
	echo -e " 7 使用自定义配置"
	echo -----------------------------------------------
	echo -e " 8 \033[31m重置\033[0m配置文件"
	echo -e " 9 \033[32m重启\033[0mclash服务"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
		clashsh
	elif [ "$num" = 0 ]; then
		clashsh  
		
	elif [ "$num" = 2 ]; then
		echo -----------------------------------------------
		if [ "$ipv6_support" = "未开启" ] > /dev/null 2>&1; then 
			echo -e "\033[33m已开启对ipv6协议的支持！！\033[0m"
			echo -e "Clash对ipv6的支持并不友好，如不能使用请静等修复！"
			ipv6_support=已开启
			sleep 2
		else
			echo -e "\033[32m已禁用对ipv6协议的支持！！\033[0m"
			ipv6_support=未开启
		fi
		setconfig ipv6_support $ipv6_support
		clashadv  
		
	elif [ "$num" = 1 ]; then	
		echo -----------------------------------------------
		if [ "$start_old" = "未开启" ] > /dev/null 2>&1; then 
			echo -e "\033[33m改为使用保守方式启动clash服务！！\033[0m"
			echo -e "\033[36m此模式兼容性更好但无法禁用开机启动！！\033[0m"
			start_old=已开启
			setconfig start_old $start_old
			$clashdir/start.sh stop
			sleep 2
		else
			if [ -f /etc/init.d/clash -o -w /etc/systemd/system -o -w /usr/lib/systemd/system ];then
				echo -e "\033[32m改为使用默认方式启动clash服务！！\033[0m"
				start_old=未开启
				setconfig start_old $start_old
				$clashdir/start.sh stop
			else
				echo -e "\033[31m当前设备不支持以其他模式启动！！\033[0m"
				sleep 1
			fi
		fi
		clashadv  
		
	elif [ "$num" = 3 ]; then	
		echo -----------------------------------------------
		if [ "$tproxy_mod" = "未开启" ]; then 
			if [ -n "$(iptables -j TPROXY 2>&1 | grep 'on-port')" ];then
				tproxy_mod=已开启
				echo -e "\033[32m已经为Redir模式启用udp转发功能！\033[0m"
			else
				tproxy_mod=未开启
				echo -e "\033[31m您的设备不支持tproxy模式，无法开启！\033[0m"
			fi
		else
			tproxy_mod=未开启
			echo -e "\033[33m已经停止使用tproxy转发udp流量！！\033[0m"
		fi
		setconfig tproxy_mod $tproxy_mod
		sleep 1
		clashadv 	
		
	elif [ "$num" = 4 ]; then	
		echo -----------------------------------------------
		dir_size=$(df $clashdir | awk '{print $4}' | sed 1d)
		if [ "$mini_clash" = "未开启" ]; then 
			if [ "$dir_size" -gt 20480 ];then
				echo -e "\033[33m您的设备空间充足(>20M)，无需开启！\033[0m"
			elif pidof systemd >/dev/null 2>&1;then
				echo -e "\033[33m该设备不支持开启此模式！\033[0m"
			else
				bindir="/tmp/clash_$USER"
				echo -e "\033[32m已经启用小闪存功能！\033[0m"
				echo -e "核心及数据库文件将存储在内存中执行，并在每次开机运行后自动下载\033[0m"
			fi
		else
			if [ "$dir_size" -lt 8192 ];then
				echo -e "\033[31m您的设备剩余空间不足8M，停用后可能无法正常运行！\033[0m"
				read -p "确认停用此功能？(1/0) > " res
				[ "$res" = 1 ] && bindir="$clashdir" && echo -e "\033[33m已经停用小闪存功能！\033[0m"
			else
				bindir="$clashdir"
				echo -e "\033[33m已经停用小闪存功能！\033[0m"
			fi
		fi
		setconfig bindir $bindir
		sleep 1
		clashadv
		
	elif [ "$num" = 5 ]; then
		setdns
		clashadv	
		
	elif [ "$num" = 6 ]; then
		setport
		clashadv
		
	elif [ "$num" = 7 ]; then
		[ ! -f $clashdir/user.yaml ] && cat > $clashdir/user.yaml <<EOF
#用于编写自定义设定(可参考https://lancellc.gitbook.io/clash)，例如
#port: 7890
#hosts:
#   '*.clash.dev': 127.0.0.1 
#   'alpha.clash.dev': ::1
EOF
		[ ! -f $clashdir/rules.yaml ] && cat > $clashdir/rules.yaml <<EOF
#用于编写自定义规则(此处规则将优先生效)，(可参考https://lancellc.gitbook.io/clash/clash-config-file/rules)：
#例如“🚀 节点选择”、“🎯 全球直连”这样的自定义规则组必须与config.yaml中的代理规则组相匹配，否则将无法运行！
# - DOMAIN-SUFFIX,google.com,🚀 节点选择
# - DOMAIN-KEYWORD,baidu,🎯 全球直连
# - DOMAIN,ad.com,REJECT
# - SRC-IP-CIDR,192.168.1.201/32,DIRECT
# - IP-CIDR,127.0.0.0/8,DIRECT
# - IP-CIDR6,2620:0:2d0:200::7/32,🚀 节点选择
# - DST-PORT,80,DIRECT
# - SRC-PORT,7777,DIRECT
EOF
		echo -e "\033[32m已经启用自定义配置功能！\033[0m"
		echo -e "Shell下(部分旧设备可能不显示中文)可\n使用【\033[36mvi $clashdir/user.yaml\033[0m】编辑自定义设定文件;\n使用【\033[36mvi $clashdir/rules.yaml\033[0m】编辑自定义规则文件。"
		echo -e "Windows下请\n使用\033[33mwinscp软件\033[0m进入$clashdir目录后手动编辑！\033[0m"
		echo -e "其他设备请\n使用\033[32mscp命令\033[0m下载文件编辑后上传到$clashdir目录！\033[0m"
		echo -e "如需自定义节点，可以在config.yaml文件中修改或者直接替换config.yaml文件！\033[0m"
		sleep 3
		clashadv
		
	elif [ "$num" = 8 ]; then	
		read -p "确认重置配置文件？(1/0) > " res
		if [ "$res" = "1" ];then
			echo "versionsh_l=$versionsh_l" > $ccfg
			echo "start_time=$start_time" >> $ccfg
			echo "#标识clash运行状态的文件，不明勿动！" >> $ccfg
			echo -e "\033[33m配置文件已重置，请重新运行脚本！\033[0m"
			exit
		fi
		clashadv
		
	elif [ "$num" = 9 ]; then	
		clashstart
		sleep 1
		clashsh
	else
		errornum
		clashsh
	fi
}
clashcron(){

	setcron(){
		echo -----------------------------------------------
		echo -e " 正在设置：\033[32m$cronname\033[0m定时任务"
		echo -e " 输入  1-7  对应\033[33m每周相应天\033[0m运行"
		echo -e " 输入   8   设为\033[33m每天定时\033[0m运行"
		echo -e " 输入 1,3,6 代表\033[36m每周1,3,6\033[0m运行(注意用小写逗号分隔)"
		echo -----------------------------------------------
		echo -e " 输入   9   \033[31m删除定时任务\033[0m"
		echo -e " 输入   0   返回上级菜单"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then 
			errornum
			clashcron
		elif [ "$num" = 0 ]; then
			clashcron
		elif [ "$num" = 9 ]; then
			crontab -l > /tmp/conf && sed -i "/$cronname/d" /tmp/conf && crontab /tmp/conf
			rm -f /tmp/conf
			echo -----------------------------------------------
			echo -e "\033[31m定时任务：$cronname已删除！\033[0m"
			clashcron
		elif [ "$num" = 8 ]; then	
			week='*'
			week1=每天
			echo 已设为每天定时运行！
		else
			week=$num	
			week1=每周$week
			echo 已设为每周 $num 运行！
		fi
		#设置具体时间
		echo -----------------------------------------------
		read -p "请输入小时（0-23） > " num
		if [ -z "$num" ]; then 
			errornum
			setcron
		elif [ $num -gt 23 ] || [ $num -lt 0 ]; then 
			errornum
			setcron
		else	
			hour=$num
		fi
		echo -----------------------------------------------
		read -p "请输入分钟（0-60） > " num
		if [ -z "$num" ]; then 
			errornum
			setcron
		elif [ $num -gt 60 ] || [ $num -lt 0 ]; then 
			errornum
			setcron
		else	
			min=$num
		fi
		echo -----------------------------------------------
		echo 将在$week1的$hour点$min分$cronname（旧的任务会被覆盖）
		read -p  "是否确认添加定时任务？(1/0) > " res
			if [ "$res" = '1' ]; then
				cronwords="$min $hour * * $week $cronset >/dev/null 2>&1 #$week1的$hour点$min分$cronname"
				crontab -l > /tmp/conf
				sed -i "/$cronname/d" /tmp/conf
				echo "$cronwords" >> /tmp/conf && crontab /tmp/conf
				rm -f /tmp/conf
				echo -----------------------------------------------
				echo -e "\033[31m定时任务已添加！！！\033[0m"
			fi
			clashcron
	}
	#定时任务菜单
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用定时任务功能：\033[0m"
	echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
	echo -----------------------------------------------
	echo  -e "\033[33m已添加的定时任务：\033[36m"
	crontab -l | grep -oE ' #.*' 
	echo -e "\033[0m"-----------------------------------------------
	echo -e " 1 设置\033[33m定时重启\033[0mclash服务"
	echo -e " 2 设置\033[31m定时停止\033[0mclash服务"
	echo -e " 3 设置\033[32m定时开启\033[0mclash服务"
	echo -e " 4 设置\033[33m定时更新\033[0m订阅并重启服务"
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单" 
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then 
		errornum
		clashsh
		
	elif [ "$num" = 0 ]; then
		clashsh
		
	elif [ "$num" = 1 ]; then
		cronname=重启clash服务
		cronset="$clashdir/start.sh restart"
		setcron
	elif [ "$num" = 2 ]; then
		cronname=停止clash服务
		cronset="$clashdir/start.sh stop"
		setcron
	elif [ "$num" = 3 ]; then
		cronname=开启clash服务
		cronset="$clashdir/start.sh start"
		setcron
	elif [ "$num" = 4 ]; then	
		cronname=更新订阅链接
		cronset="$clashdir/start.sh getyaml"
		setcron	
		
	else
		errornum
		clashsh
	fi
}
#主菜单
clashsh(){
	#############################
	getconfig
	#############################
	echo -e " 1 \033[32m启动/重启\033[0mclash服务"
	echo -e " 2 clash\033[33m功能设置\033[0m"
	echo -e " 3 \033[31m停止\033[0mclash服务"
	echo -e " 4 $auto1"
	echo -e " 5 设置\033[33m定时任务\033[0m$cronoff"
	echo -e " 6 导入\033[32m配置文件\033[0m"
	echo -e " 7 clash\033[31m进阶设置\033[0m"
	echo -e " 8 \033[35m测试菜单\033[0m"
	echo -e " 9 \033[36m更新/卸载\033[0m"
	echo -----------------------------------------------
	echo -e " 0 \033[0m退出脚本\033[0m"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ];then
		errornum
		exit;
		
	elif [ "$num" = 0 ]; then
		exit;
		
	elif [ "$num" = 1 ]; then
		clashstart
		sleep 1
		clashsh
  
	elif [ "$num" = 2 ]; then
		clashcfg

	elif [ "$num" = 3 ]; then
		$clashdir/start.sh stop
		echo -----------------------------------------------
		echo -e "\033[31mClash服务已停止！\033[0m"
		echo -----------------------------------------------
		exit;

	elif [ "$num" = 4 ]; then
		echo -----------------------------------------------
		if [ "$start_old" = "已开启" ];then
			localproxy
		elif [ "$autostart" = "enable_rc" ]; then
			/etc/init.d/clash disable
			echo -e "\033[33m已禁止Clash开机启动！\033[0m"
		elif [ "$autostart" = "disable_rc" ]; then
			/etc/init.d/clash enable
			echo -e "\033[32m已设置Clash开机启动！\033[0m"
		elif [ "$autostart" = "enable_sys" ]; then
			systemctl disable clash.service > /dev/null 2>&1
			echo -e "\033[33m已禁止Clash开机启动！\033[0m"
		elif [ "$autostart" = "disable_sys" ]; then
			systemctl enable clash.service > /dev/null 2>&1
			echo -e "\033[32m已设置Clash开机启动！\033[0m"
		else
			echo -e "\033[32m当前系统不支持设置开启启动！\033[0m"
		fi
		clashsh

	elif [ "$num" = 5 ]; then
		clashcron
    
	elif [ "$num" = 6 ]; then
		source $clashdir/getdate.sh && clashlink
		
	elif [ "$num" = 7 ]; then
		clashadv

	elif [ "$num" = 8 ]; then
		source $clashdir/getdate.sh && testcommand

	elif [ "$num" = 9 ]; then
		source $clashdir/getdate.sh && update
	
	else
		errornum
		exit;
	fi
}

[ -z "$1" ] && clashsh

case "$1" in
	-h)
		echo -----------------------------------------
		echo "欢迎使用ShellClash"
		echo -----------------------------------------
		echo "	-t 测试模式"
		echo "	-h 帮助列表"
		echo -----------------------------------------
		echo "在线求助：t.me/clashfm"
		echo "官方博客：juewuy.github.io"
		echo "发布页面：github.com/juewuy/ShellClash"
		echo -----------------------------------------
	;;
	-t)
		shtype=sh && [ -n "$(ls -l /bin/sh|grep -o dash)" ] && shtype=bash
		$shtype -x $clashdir/clash.sh
	;;
	*)
		echo "	-t 测试模式"
		echo "	-h 帮助列表"	
	;;
esac
