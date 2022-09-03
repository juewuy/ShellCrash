#!/bin/sh
# Copyright (C) Juewuy

#读取配置相关
getconfig(){
	#服务器缺省地址
	[ -z "$update_url" ] && update_url=https://raw.githubusercontents.com/juewuy/ShellClash
	#文件路径
	[ -z "$clashdir" ] && echo 环境变量配置有误！请重新安装脚本！
	ccfg=$clashdir/mark
	yaml=$clashdir/config.yaml
	#检查/读取标识文件
	[ ! -f $ccfg ] && echo '#标识clash运行状态的文件，不明勿动！' > $ccfg
	#检查重复行并去除
	[ -n "$(awk 'a[$0]++' $ccfg)" ] && awk '!a[$0]++' $ccfg > $ccfg
	#使用source加载配置文件
	source $ccfg
	#设置默认核心资源目录
	[ -z "$bindir" ] && bindir=$clashdir
	#设置默认端口及变量
	[ -z "$mix_port" ] && mix_port=7890
	[ -z "$redir_port" ] && redir_port=7892
	[ -z "$db_port" ] && db_port=9999
	[ -z "$dns_port" ] && dns_port=1053
	[ -z "$multiport" ] && multiport='22,53,587,465,995,993,143,80,443,8080'
	[ -z "$local_proxy" ] && local_proxy=未开启
	#检查mac地址记录
	[ ! -f $clashdir/mac ] && touch $clashdir/mac
	#获取本机host地址
	[ -z "$host" ] && host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E '\ 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host=127.0.0.1
	#dashboard目录位置
	[ -d $clashdir/ui ] && dbdir=$clashdir/ui && hostdir=":$db_port/ui"
	[ -d /www/clash ] && dbdir=/www/clash && hostdir=/clash
	#开机自启检测
	if [ -f /etc/rc.common ];then
		[ -n "$(find /etc/rc.d -name '*clash')" ] && autostart=enable || autostart=disable
	elif [ -w /etc/systemd/system -o -w /usr/lib/systemd/system ];then
		[ -n "$(systemctl is-enabled clash.service 2>&1 | grep enable)" ] && autostart=enable || autostart=disable
	else
		[ -f $clashdir/.dis_startup ] && autostart=disable || autostart=enable
	fi
	#开机自启描述
	if [ "$autostart" = "enable" ]; then
		auto="\033[32m已设置开机启动！\033[0m"
		auto1="\033[36m禁用\033[0mclash开机启动"
	else
		auto="\033[31m未设置开机启动！\033[0m"
		auto1="\033[36m允许\033[0mclash开机启动"
	fi
	#获取运行模式
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
	echo -e "TG频道：\033[36;4mhttps://t.me/ShellClash\033[0m"
	echo -----------------------------------------------
	#检查新手引导
	if [ -z "$userguide" ];then
		setconfig userguide 1
		source $clashdir/getdate.sh && userguide
	fi
	#检查执行权限
	[ ! -x $clashdir/start.sh ] && chmod +x $clashdir/start.sh
}
setconfig(){
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath=$clashdir/mark || configpath=$3
	[ -n "$(grep -E "^${1}=" $configpath)" ] && sed -i "s#^${1}=\(.*\)#${1}=${2}#g" $configpath || echo "${1}=${2}" >> $configpath
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
	[ -n "$(pidof clash)" ] && startover
}
checkrestart(){
	echo -----------------------------------------------
	echo -e "\033[32m检测到已变更的内容，请重启clash服务！\033[0m"
	echo -----------------------------------------------
	read -p "是否现在重启clash服务？(1/0) > " res
	[ "$res" = 1 ] && clashstart
}
#功能相关
setport(){
	source $ccfg
	[ -z "$secret" ] && secret=未设置
	[ -z "$authentication" ] && authentication=未设置
	inputport(){
		read -p "请输入端口号(1-65535) > " portx
		if [ -z "$portx" ]; then
			setport
		elif [ $portx -gt 65535 -o $portx -le 1 ]; then
			echo -e "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
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
	echo -----------------------------------------------
	echo -e " 1 修改Http/Sock5端口：	\033[36m$mix_port\033[0m"
	echo -e " 2 设置Http/Sock5密码：	\033[36m$authentication\033[0m"
	echo -e " 3 修改静态路由端口：	\033[36m$redir_port\033[0m"
	echo -e " 4 修改DNS监听端口：	\033[36m$dns_port\033[0m"
	echo -e " 5 修改面板访问端口：	\033[36m$db_port\033[0m"
	echo -e " 6 设置面板访问密码：	\033[36m$secret\033[0m"
	echo -e " 7 修改默认端口过滤：	\033[36m$multiport\033[0m"
	echo -e " 8 指定本机host地址：	\033[36m$host\033[0m"
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
			setconfig authentication
			echo 密码已移除！
		else
			if [ "$local_proxy" = "已开启" -a "$local_type" = "环境变量" ];then
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
		echo -e "\033[33m此处可以更改脚本内置的局域网设备IP地址\033[0m"
		echo -e "\033[31m设置后如本机host地址有变动，请务必手动修改！\033[0m"
		echo -----------------------------------------------
		read -p "请输入自定义host地址(输入0移除自定义host) > " host
		if [ "$host" = "0" ];then
			host=""
			setconfig host $host
			echo -e "\033[32m已经移除自定义host地址，请重新运行脚本以自动获取host！！！\033[0m"
			exit 0
		elif [ -n "$(echo $host |grep -E -o '\<([1-9]|[1-9][0-9]|1[0-9]{2}|2[01][0-9]|22[0-3])\>(\.\<([0-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\>){2}\.\<([1-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])\>' )" ]; then
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
setdns(){
	[ -z "$dns_nameserver" ] && dns_nameserver='114.114.114.114, 223.5.5.5'
	[ -z "$dns_fallback" ] && dns_fallback='1.0.0.1, 8.8.4.4'
	[ -z "$ipv6_dns" ] && ipv6_dns=已开启
	[ -z "$dns_redir" ] && dns_redir=未开启
	[ -z "$dns_no" ] && dns_no=未禁用
	echo -----------------------------------------------
	echo -e "当前基础DNS：\033[32m$dns_nameserver\033[0m"
	echo -e "fallbackDNS：\033[36m$dns_fallback\033[0m"
	echo -e "fallback域名：\033[36m$fallback_domain\033[0m"
	echo -e "多个DNS地址请用\033[30;47m“|”\033[0m或者\033[30;47m“, ”\033[0m分隔输入"
	echo -e "\033[33m必须拥有本地根证书文件才能使用dot/doh类型的加密dns\033[0m"
	echo -----------------------------------------------
	echo -e " 1 修改\033[32m基础DNS\033[0m"
	echo -e " 2 修改\033[36mfallback_DNS\033[0m"
	echo -e " 3 \033[33m重置\033[0mDNS配置"
	echo -e " 4 一键配置\033[32m加密DNS\033[0m"
	echo -e " 5 ipv6_dns解析：	\033[36m$ipv6_dns\033[0m	————建议开启"
	echo -e " 6 Dnsmasq转发：	\033[36m$dns_redir\033[0m	————用于解决dns劫持失败的问题"
	echo -e " 7 禁用内置DNS：	\033[36m$dns_no\033[0m	————不明勿动"
	echo -e " 8 修改\033[36mfallback-filter domain\033[0m	————强制自定义域名走\033[36mfallback_DNS\033[0m解析"
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
		fallback_domain=""
		setconfig dns_nameserver
		setconfig dns_fallback
		setconfig fallback_domain
		echo -e "\033[33mDNS配置已重置！！！\033[0m"
		setdns
		
	elif [ "$num" = 4 ]; then
		$clashdir/start.sh webget /tmp/ssl_test https://www.baidu.com echooff rediron skipceroff
		if [ "$？" = "1" ];then
			echo -----------------------------------------------
			if openssl version >/dev/null 2>&1;then
				echo -e "\033[31m当前设备缺少本地根证书，请先安装证书！\033[0m"
				source $clashdir/getdate.sh
				setcrt
			else
				echo -e "\033[31m当前设备未安装OpenSSL，无法启用加密DNS，Linux系统请自行搜索安装方式！\033[0m"
			fi
		else
			dns_nameserver='https://223.5.5.5/dns-query, https://doh.pub/dns-query, tls://dns.rubyfish.cn:853'
			dns_fallback='tls://1.0.0.1:853, tls://8.8.4.4:853, https://doh.opendns.com/dns-query'
			setconfig dns_nameserver \'"$dns_nameserver"\'
			setconfig dns_fallback \'"$dns_fallback"\' 
			echo -e "\033[32m设置成功！！！\033[0m"
		fi
		rm -rf /tmp/ssl_test
		sleep 1
		setdns
		
	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		if [ "$ipv6_dns" = "未开启" ]; then 
			echo -e "\033[32m开启成功！！\033[0m"
			ipv6_dns=已开启
		else
			echo -e "\033[33m禁用成功！！\033[0m"
			ipv6_dns=未开启
		fi
		sleep 1
		setconfig ipv6_dns $ipv6_dns
		setdns
				
	elif [ "$num" = 6 ]; then
		echo -----------------------------------------------
		if [ "$dns_redir" = "未开启" ]; then 
			echo -e "\033[31m将使用OpenWrt中Dnsmasq插件自带的DNS转发功能转发DNS请求至clash内核！\033[0m"
			echo -e "\033[33m启用后将禁用本插件自带的iptables转发功能\033[0m"
			dns_redir=已开启
			echo -e "\033[32m已启用Dnsmasq转发DNS功能！！！\033[0m"
			sleep 1
		else
			echo -e "\033[33m禁用成功！！\033[0m"
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
			echo -e "\033[32m已禁用内置DNS！！！\033[0m"
		else
			dns_no=未禁用
			echo -e "\033[33m已启用内置DNS！！！\033[0m"
		fi
		sleep 1
		setconfig dns_no $dns_no
		setdns

	elif [ "$num" = 8 ]; then
		read -p "请输入强制fallback的域名 > " fallback_domain
		fallback_domain=$(echo $fallback_domain | sed 's/|/\,\ /g')
		if [ -n "$fallback_domain" ]; then
			setconfig fallback_domain \'"$fallback_domain"\' 
			echo -e "\033[32m设置成功！！！\033[0m"
		fi
		setdns
	fi
}
checkport(){
	for portx in $dns_port $mix_port $redir_port $db_port ;do
		if [ -n "$(netstat -ntul 2>&1 |grep \:$portx\ )" ];then
			echo -----------------------------------------------
			echo -e "检测到端口【$portx】被以下进程占用！clash可能无法正常启动！\033[33m"
			echo $(netstat -ntul | grep :$portx | head -n 1)
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
			i=
		elif [ -n "$(echo $num | grep -E '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$')" ];then
			if [ -z "$(cat $clashdir/mac | grep -E "$num")" ];then
				echo $num | grep -oE '^([0-9A-Fa-f]{2}[:]){5}([0-9A-Fa-f]{2})$' >> $clashdir/mac
			else
				echo -----------------------------------------------
				echo -e "\033[31m已添加的设备，请勿重复添加！\033[0m"
			fi
			add_mac
		elif [ $num -le $(cat $dhcpdir | awk 'END{print NR}') 2>/dev/null ]; then
			macadd=$(cat $dhcpdir | awk '{print $2}' | sed -n "$num"p)
			if [ -z "$(cat $clashdir/mac | grep -E "$macadd")" ];then
				echo $macadd >> $clashdir/mac
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
	del_mac(){
		echo -----------------------------------------------
		if [ -z "$(cat $clashdir/mac)" ];then
			echo -e "\033[31m列表中没有需要移除的设备！\033[0m"
		else
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
				n=
			elif [ $num -le $(cat $clashdir/mac | wc -l) ];then
				sed -i "${num}d" $clashdir/mac
				echo -----------------------------------------------
				echo -e "\033[32m对应设备已移除！\033[0m"
				del_mac
			else
				echo -----------------------------------------------
				echo -e "\033[31m输入有误，请重新输入！\033[0m"
				del_mac
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
	if [ "$macfilter_type" = "黑名单" ];then
		macfilter_over='白名单'
		macfilter_scrip='不'
	else
		macfilter_over='黑名单'
		macfilter_scrip=''
	fi
	######
	echo -e "\033[30;47m请在此添加或移除设备\033[0m"
	echo -e "当前过滤方式为：\033[33m$macfilter_type模式\033[0m"
	echo -e "仅列表内设备\033[36m$macfilter_scrip经过\033[0mClash内核"
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
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then
		macfilter_type=$macfilter_over
		setconfig macfilter_type $macfilter_type
		echo -----------------------------------------------
		echo -e "\033[32m已切换为$macfilter_type模式！\033[0m"
		macfilter
	elif [ "$num" = 2 ]; then	
		add_mac
		macfilter
	elif [ "$num" = 3 ]; then	
		del_mac
		macfilter
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
	[ -z "$local_type" ] && local_type='环境变量'
	[ "$local_proxy" = "已开启" ] && proxy_set='禁用' || proxy_set='启用'
	echo -----------------------------------------------
	echo -e "\033[33m当前本机代理配置方式为：\033[32m$local_type\033[0m"
	echo -----------------------------------------------
	echo -e " 1 \033[36m$proxy_set本机代理\033[0m"
	echo -e " 2 使用\033[32m环境变量\033[0m方式配置(部分应用可能无法使用)"
	echo -e " 3 使用\033[32miptables增强模式\033[0m配置(支持docker)"
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
				setconfig local_proxy $local_proxy
				setconfig local_type $local_type
				echo -e "\033[32m已经成功使用$local_type方式配置本机代理~\033[0m"
				if [ "$local_type" = "环境变量" ];then
					$clashdir/start.sh set_proxy $mix_port $db_port
					echo -e "\033[36m如未生效，请重新启动终端或重新连接SSH！\033[0m"
				else
					echo -e "\033[36m请重新启动clash服务！\033[0m"
				fi
				sleep 1
			fi		
		else
			local_proxy=未开启
			setconfig local_proxy $local_proxy
			setconfig local_type
			sed -i '/user shellclash/d' /etc/init.d/clash 2>/dev/null
			$clashdir/start.sh stop
			echo -e "\033[33m已经停用本机代理规则并停止clash服务！！\033[0m"
			[ "$local_type" = "环境变量" ] && echo -e "\033[36m如未生效，请重新启动终端或重新连接SSH！\033[0m" && sleep 1
		fi

	elif [ "$num" = 2 ]; then
		local_type="环境变量"
		setconfig local_type $local_type
		localproxy
	elif [ "$num" = 3 ]; then
		if [ -w /etc/systemd/system/clash.service -o -w /usr/lib/systemd/system/clash.service -o -x /bin/su ];then
			local_type="iptables增强模式"
			setconfig local_type $local_type
		elif [ -f /etc/rc.common -a -w /etc/passwd ]; then
			local_type="iptables增强模式"
			setconfig local_type $local_type
		else
			echo -e "\033[31m当前设备无法使用增强模式！\033[0m"
			sleep 1
		fi
		localproxy
	else
		errornum
	fi	
}
clashcfg(){
	set_redir_mod(){
		set_redir_config(){
			setconfig redir_mod $redir_mod
			setconfig dns_mod $dns_mod 
			if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ] && [ "$clashcore" = "clash" ];then
				rm -rf $bindir/clash
				rm -rf $clashdir/clash
				setconfig clashcore clash.meta
			fi
			echo -----------------------------------------------	
			echo -e "\033[36m已设为 $redir_mod ！！\033[0m"
		}
		echo -----------------------------------------------
		echo -e "当前代理模式为：\033[47;30m $redir_mod \033[0m；Clash核心为：\033[47;30m $clashcore \033[0m"
		echo -e "\033[33m切换模式后需要手动重启clash服务以生效！\033[0m"
		echo -e "\033[36mTun及混合模式必须使用clashpre核心！\033[0m"
		echo -----------------------------------------------
		echo -e " 1 Redir模式：CPU以及内存\033[33m占用较低\033[0m"
		echo -e "              但\033[31m不支持UDP\033[0m"
		echo -e "              适合\033[32m非外服游戏用户\033[0m使用"
		echo -e " 2 混合模式： 使用redir转发TCP，Tun转发UDP流量"
		echo -e "              \033[33m速度较快\033[0m，\033[31m内存占用略高\033[0m"
		echo -e "              适合\033[32m游戏用户、综合用户\033[0m"
		echo -e " 3 Tun模式：  \033[33m支持UDP转发\033[0m且延迟最低"
		echo -e "              \033[31mCPU占用极高\033[0m，只支持fake-ip模式"
		echo -e "              \033[33m如非必要不推荐使用\033[0m"
		echo -e " 4 纯净模式： 不设置iptables静态路由"
		echo -e "              必须\033[33m手动配置\033[0mhttp/sock5代理"
		echo -e "              或使用内置的PAC文件配置代理"
		echo " 0 返回上级菜单"
		read -p "请输入对应数字 > " num	
		if [ -z "$num" ]; then
			errornum
		elif [ "$num" = 0 ]; then
			i=
		elif [ "$num" = 1 ]; then
			redir_mod=Redir模式
			dns_mod=redir_host
			set_redir_config
		elif [ "$num" = 3 ]; then
			ip tuntap >/dev/null 2>&1
			if [ "$?" != 0 ];then
				echo -----------------------------------------------
				echo -e "\033[31m当前设备内核可能不支持开启Tun/混合模式！\033[0m"
				read -p "是否强制开启？可能无法正常使用！(1/0) > " res
				if [ "$res" = 1 ];then
					redir_mod=Tun模式
					dns_mod=fake-ip
					set_redir_config
				else
					set_redir_mod
				fi
			else	
				redir_mod=Tun模式
				dns_mod=fake-ip
				set_redir_config
			fi
		elif [ "$num" = 2 ]; then
			ip tuntap >/dev/null 2>&1
			if [ "$?" != 0 ];then
				echo -e "\033[31m当前设备内核可能不支持开启Tun/混合模式！\033[0m"
				read -p "是否强制开启？可能无法正常使用！(1/0) > " res
				if [ "$res" = 1 ];then
					redir_mod=混合模式
					set_redir_config
				else
					set_redir_mod
				fi
			else	
				redir_mod=混合模式	
				set_redir_config
			fi
		elif [ "$num" = 4 ]; then
			redir_mod=纯净模式	
			set_redir_config		
			echo -----------------------------------------------
			echo -e "\033[33m当前模式需要手动在设备WiFi或应用中配置HTTP或sock5代理\033[0m"
			echo -e "HTTP/SOCK5代理服务器地址：\033[30;47m$host\033[0m;端口均为：\033[30;47m$mix_port\033[0m"
			echo -e "也可以使用更便捷的PAC自动代理，PAC代理链接为："
			echo -e "\033[30;47m http://$host:$db_port/ui/pac \033[0m"
			echo -e "PAC的使用教程请参考：\033[4;32mhttps://juewuy.github.io/ehRUeewcv\033[0m"
			sleep 2
		else
			errornum
		fi

	}
	set_dns_mod(){
		echo -----------------------------------------------
		echo -e "当前DNS运行模式为：\033[47;30m $dns_mod \033[0m"
		echo -e "\033[33m切换模式后需要手动重启clash服务以生效！\033[0m"
		echo -----------------------------------------------
		echo -e " 1 fake-ip模式：   \033[32m响应速度更快\033[0m"
		echo -e "                   兼容性比较差，部分应用可能打不开"
		echo -e " 2 redir_host模式：\033[32m兼容性更好\033[0m"
		echo -e "                   不支持Tun模式，抗污染能力略差"
		echo " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			errornum
		elif [ "$num" = 0 ]; then
			i=
		elif [ "$num" = 1 ]; then
			set_fake_ip(){
				dns_mod=fake-ip
				setconfig dns_mod $dns_mod 
				echo -----------------------------------------------	
				echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
				}
			if [ "$redir_mod" = "Redir模式" ];then
				echo -----------------------------------------------	
				read -p "fake-ip与Redir模式兼容性较差，是否依然强制使用？(1/0) > "	res
				[ "$res" = 1 ] && set_fake_ip
			else
				set_fake_ip
			fi

		elif [ "$num" = 2 ]; then
			dns_mod=redir_host
			setconfig dns_mod $dns_mod 
			echo -----------------------------------------------	
			echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
		else
			errornum
		fi
	}
	fake_ip_filter(){
		echo -e "\033[32m用于解决Fake-ip模式下部分地址或应用无法连接的问题\033[0m"
		echo -e "\033[31m脚本已经内置了大量地址，你只需要添加出现问题的地址！\033[0m"
		echo -e "\033[36m示例：a.b.com"
		echo -e "示例：*.b.com"
		echo -e "示例：*.*.b.com\033[0m"
		echo -----------------------------------------------
		if [ -f $clashdir/fake_ip_filter ];then
			echo -e "\033[33m已添加Fake-ip过滤地址：\033[0m"
			cat $clashdir/fake_ip_filter | awk '{print NR" "$1}'
		else
			echo -e "\033[33m你还未添加Fake-ip过滤地址\033[0m" 
		fi
		echo -----------------------------------------------
		echo -e "\033[32m输入数字直接移除对应地址，输入地址直接添加！\033[0m"
		read -p "请输入数字或地址 > " input
		if [ -z "$input" -o "input" = 0 ];then
			i=
		elif [ "$input" -le "$(cat $clashdir/fake_ip_filter | wc -l)" ];then
			sed -i "${input}d" $clashdir/fake_ip_filter	2>/dev/null
			echo -e "\033[32m移除成功！\033[0m"	
			fake_ip_filter
		else
			echo -e "你输入的地址是：\033[32m$input\033[0m"	
			read -p "确认添加？(1/0) > " res
			[ "$res" = 1 ] && echo $input >> $clashdir/fake_ip_filter || fake_ip_filter
		fi
	}
	#获取设置默认显示
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ -z "$common_ports" ] && common_ports=已开启
	[ -z "$dns_mod" ] && dns_mod=redir_host
	[ -z "$dns_over" ] && dns_over=已开启
	[ -z "$cn_ip_route" ] && cn_ip_route=未开启
	[ -z "$quic_rj" ] && quic_rj=未开启
	[ -z "$(cat $clashdir/mac)" ] && mac_return=未开启 || mac_return=已启用
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用功能设置菜单：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 切换Clash运行模式: 	\033[36m$redir_mod\033[0m"
	echo -e " 2 切换DNS运行模式：	\033[36m$dns_mod\033[0m"
	echo -e " 3 跳过本地证书验证：	\033[36m$skip_cert\033[0m   ————解决节点证书验证错误"
	echo -e " 4 只代理常用端口： 	\033[36m$common_ports\033[0m   ————用于过滤P2P流量"
	echo -e " 5 过滤局域网设备：	\033[36m$mac_return\033[0m   ————使用黑/白名单进行过滤"
	echo -e " 6 设置本机代理服务:	\033[36m$local_proxy\033[0m   ————使本机流量经过clash内核"
	echo -e " 7 屏蔽QUIC流量:	\033[36m$quic_rj\033[0m   ————优化视频性能"
	[ "$dns_mod" = "fake-ip" ] && \
	echo -e " 8 管理Fake-ip过滤列表" || \
	echo -e " 8 CN_IP绕过内核:	\033[36m$cn_ip_route\033[0m   ————优化性能，不兼容Fake-ip"
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then
		if [ "$USER" != "root" -a "$USER" != "admin" ];then
			echo -----------------------------------------------
			read -p "非root用户可能无法正确配置其他模式！依然尝试吗？(1/0) > " res
			[ "$res" = 1 ] && set_redir_mod
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
		if [ "$common_ports" = "未开启" ]; then 
			echo -e "\033[33m已设为仅代理【$multiport】等常用端口！！\033[0m"
			common_ports=已开启
		else
			echo -e "\033[33m已设为代理全部端口！！\033[0m"
			common_ports=未开启
		fi
		setconfig common_ports $common_ports
		clashcfg  

	elif [ "$num" = 5 ]; then	
		macfilter
		clashcfg
		
	elif [ "$num" = 6 ]; then	
		localproxy
		sleep 1
		clashcfg
		
	elif [ "$num" = 7 ]; then	
		echo -----------------------------------------------
		if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" -o "$tproxy_mod" = "已开启" ];then
			if [ "$quic_rj" = "未开启" ]; then 
				echo -e "\033[33m已禁止QUCI流量通过clash内核！！\033[0m"
				quic_rj=已启用
			else
				echo -e "\033[33m已取消禁止QUIC协议流量！！\033[0m"
				quic_rj=未开启
			fi
			setconfig quic_rj $quic_rj
		else
			echo -e "\033[33m当前模式默认不会代理UDP流量，无需设置！！\033[0m"
		fi
		clashcfg	
		
	elif [ "$num" = 8 ]; then
		echo -----------------------------------------------
		if [ "$dns_mod" = "fake-ip" ];then
			fake_ip_filter
			clashcfg
		else
			if ! ipset -v >/dev/null 2>&1;then
				echo -e "\033[31m当前设备缺少ipset模块，无法启用绕过功能！！\033[0m"
				sleep 1
			else
				if [ "$cn_ip_route" = "未开启" ]; then 
					echo -e "\033[32m已开启CN_IP绕过内核功能！！\033[0m"
					cn_ip_route=已开启
					sleep 1
				else
					echo -e "\033[33m已禁用CN_IP绕过内核功能！！\033[0m"
					cn_ip_route=未开启
				fi
				setconfig cn_ip_route $cn_ip_route
			fi
		fi
		clashcfg  	
		
	elif [ "$num" = 9 ]; then	
		clashstart
	else
		errornum
	fi
}
clashadv(){
	#获取设置默认显示
	[ -z "$modify_yaml" ] && modify_yaml=未开启
	[ -z "$ipv6_support" ] && ipv6_support=未开启
	[ -z "$start_old" ] && start_old=未开启
	[ -z "$tproxy_mod" ] && tproxy_mod=未开启
	[ -z "$public_support" ] && public_support=未开启
	[ "$bindir" = "/tmp/clash_$USER" ] && mini_clash=已开启 || mini_clash=未开启
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用进阶模式菜单：\033[0m"
	echo -e "\033[33m如您并不了解clash的运行机制，请勿更改本页面功能！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 使用保守模式启动:	\033[36m$start_old\033[0m	————切换时会停止clash服务"
	echo -e " 2 启用ipv6支持:	\033[36m$ipv6_support\033[0m	————实验性功能，可能不稳定"
	echo -e " 3 Redir模式udp转发:	\033[36m$tproxy_mod\033[0m	————依赖iptables-mod-tproxy"
	echo -e " 4 启用小闪存模式:	\033[36m$mini_clash\033[0m	————不保存核心及数据库文件"
	echo -e " 5 允许公网访问:	\033[36m$public_support\033[0m	————需要路由拨号+公网IP"
	echo -e " 6 配置内置DNS服务	\033[36m$dns_no\033[0m"
	echo -e " 7 使用自定义配置"
	echo -e " 8 手动指定相关端口、秘钥及本机host"
	echo -----------------------------------------------
	echo -e " 9 \033[31m重置/备份/还原\033[0m脚本设置"
	echo -e " 0 返回上级菜单 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then	
		echo -----------------------------------------------
		if [ "$start_old" = "未开启" ] > /dev/null 2>&1; then 
			echo -e "\033[33m改为使用保守模式启动clash服务！！\033[0m"
			echo -e "\033[31m注意：部分设备保守模式可能无法禁用开机启动！！\033[0m"
			start_old=已开启
			setconfig start_old $start_old
			$clashdir/start.sh stop
		else
			if [ -f /etc/init.d/clash -o -w /etc/systemd/system -o -w /usr/lib/systemd/system ];then
				echo -e "\033[32m改为使用默认方式启动clash服务！！\033[0m"
				$clashdir/start.sh cronset "ShellClash初始化"
				start_old=未开启
				setconfig start_old $start_old
				$clashdir/start.sh stop
				
			else
				echo -e "\033[31m当前设备不支持以其他模式启动！！\033[0m"
			fi
		fi
		sleep 1
		clashadv 
		
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
				rm -rf /tmp/clash_$USER
				bindir="$clashdir"
				echo -e "\033[33m已经停用小闪存功能！\033[0m"
			fi
		fi
		setconfig bindir $bindir
		sleep 1
		clashadv
		
	elif [ "$num" = 5 ]; then
		if [ "$public_support" = "未开启" ]; then 
			echo -e "\033[32m已开启公网访问Dashboard端口及Http/Sock5代理端口！！\033[0m"
			echo -e "\033[33m安全起见建议设置相关访问密码！！\033[0m"
			public_support=已开启
			setconfig public_support $public_support
			sleep 1
		else
			echo -e "\033[32m已禁止公网访问Dashboard端口及Http/Sock5代理端口！！\033[0m"
			echo -e "\033[33m如果你的防火墙默认放行公网流量，可能禁用失败！\033[0m"
			public_support=未开启
			setconfig public_support $public_support
			sleep 1
		fi
			clashadv
		
	elif [ "$num" = 6 ]; then
		source $ccfg
		if [ "$dns_no" = "已禁用" ];then
			read -p "检测到内置DNS已被禁用，是否启用内置DNS？(1/0) > " res
			if [ "$res" = "1" ];then
				setconfig dns_no
				setdns
			fi
		else
			setdns
		fi
		clashadv	
		
	elif [ "$num" = 8 ]; then
		source $ccfg
		if [ -n "$(pidof clash)" ];then
			echo -----------------------------------------------
			echo -e "\033[33m检测到clash服务正在运行，需要先停止clash服务！\033[0m"
			read -p "是否停止clash服务？(1/0) > " res
			if [ "$res" = "1" ];then
				$clashdir/start.sh stop
				setport
			fi
		else
			setport
		fi
		clashadv
		
	elif [ "$num" = 7 ]; then
		[ ! -f $clashdir/user.yaml ] && cat > $clashdir/user.yaml <<EOF
#用于编写自定义设定(可参考https://lancellc.gitbook.io/clash)，例如
#新版已经支持直接读取系统hosts(/etc/hosts)并写入配置文件，无需在此处添加！
#新版meta内核已经支持yaml-v3，所有能在脚本中修改的条目请勿在此处配置以免报错！
#port: 7890
EOF
		[ ! -f $clashdir/rules.yaml ] && cat > $clashdir/rules.yaml <<EOF
#用于编写自定义规则(此处规则将优先生效)，(可参考https://lancellc.gitbook.io/clash/clash-config-file/rules)：
#例如“🚀 节点选择”、“🎯 全球直连”这样的自定义规则组必须与config.yaml中的代理规则组相匹配，否则将无法运行
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
		echo -e "Windows下请\n使用\033[33mwinscp软件\033[0m进入$clashdir目录后手动编辑！\033[0m"
		echo -e "Shell下(\033[31m部分旧设备可能不显示中文\033[0m)可\n使用【\033[36mvi $clashdir/user.yaml\033[0m】编辑自定义设定文件;\n使用【\033[36mvi $clashdir/rules.yaml\033[0m】编辑自定义规则文件。"
		echo -e "如需自定义节点，可以在config.yaml文件中修改或者直接替换config.yaml文件！\033[0m"
		sleep 3
		clashadv
		
	elif [ "$num" = 9 ]; then	
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
			cp -f $ccfg $ccfg.bak
			echo -e "\033[32m脚本设置已备份！\033[0m"
		elif [ "$num" = 2 ]; then
			if [ -f "$ccfg.bak" ];then
				mv -f $ccfg $ccfg.bak2
				mv -f $ccfg.bak $ccfg
				mv -f $ccfg.bak2 $ccfg.bak
				echo -e "\033[32m脚本设置已还原！(被覆盖的配置已备份！)\033[0m"
			else
				echo -e "\033[31m找不到备份文件，请先备份脚本设置！\033[0m"
			fi
		elif [ "$num" = 3 ]; then
			mv -f $ccfg $ccfg.bak
			echo -e "\033[32m脚本设置已重置！(旧文件已备份！)\033[0m"
		fi
		echo -e "\033[33m请重新启动脚本！\033[0m"
		exit 0

	else
		errornum
	fi
}
streaming(){
	[ -z "$netflix_pre" ] && netflix_pre=未开启
	[ -z "$disneyP_pre" ] && disneyP_pre=未开启
	[ -z "$streaming_int" ] && streaming_int=24
	netflix_dir=$clashdir/streaming/Netflix_Domains.list
	disneyp_dir=$clashdir/streaming/Disney_Plus_Domains.list
	####
	echo -e "\033[30;46m欢迎使用流媒体预解析功能：\033[0m"
	echo -e "\033[33m感谢OpenClash项目提供相关域名数据库！\033[0m"
	echo -e "\033[31m修改后需重启服务！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 预解析\033[36mNetflix域名  	\033[33m$netflix_pre\033[0m"
	echo -e " 2 预解析\033[36mDisney+域名  	\033[33m$disneyP_pre\033[0m"
	echo -e " 3 设置预解析间隔	\033[32m$streaming_int小时\033[0m"
	echo -e " 4 更新本地\033[32m域名数据库\033[0m"
	echo -e " 0 返回上级菜单" 
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then	
		echo -----------------------------------------------
		if [ "$netflix_pre" = "未开启" ] > /dev/null 2>&1; then
			echo -e "\033[33m已启用Netflix域名预解析功能！！\033[0m"
			netflix_pre=已开启
			sleep 1
		else
			echo -e "\033[31m已停用Netflix域名预解析功能！！\033[0m"
			[ -f "$netflix_dir" ] && rm -rf $netflix_dir
			netflix_pre=未开启
		fi
		setconfig netflix_pre $netflix_pre
		sleep 1
		streaming
	elif [ "$num" = 2 ]; then	
		echo -----------------------------------------------
		if [ "$disneyP_pre" = "未开启" ] > /dev/null 2>&1; then
			echo -e "\033[33m已启用Disney+域名预解析功能！！\033[0m"
			disneyP_pre=已开启
			sleep 1
		else
			echo -e "\033[31m已停用Disney+域名预解析功能！！\033[0m"
			[ -f "$disneyp_dir" ] && rm -rf $disneyp_dir
			disneyP_pre=未开启
		fi
		setconfig disneyP_pre $disneyP_pre
		sleep 1
		streaming
	elif [ "$num" = 3 ]; then	
		echo -----------------------------------------------
		read -p "请输入刷新间隔(1-24小时,不支持小数) > " num
			if [ -z "$num" ]; then 
				errornum
			elif [ $num -gt 24 ] || [ $num -lt 1 ]; then 
				errornum
			else	
				streaming_int=$num
				setconfig streaming_int $streaming_int
				echo -e "\033[32m设置成功！！！\033[0m"
			fi
			sleep 1
			streaming
	elif [ "$num" = 4 ]; then
		[ -f "$netflix_dir" ] && rm -rf $netflix_dir
		[ -f "$disneyp_dir" ] && rm -rf $disneyp_dir
		echo -----------------------------------------------
		echo -e "\033[32m本地文件已清理，将在下次刷新时自动更新数据库文件！！！\033[0m"
		sleep 1
		streaming
	else
		errornum
		streaming
	fi		
}
tools(){
	ssh_tools(){
		stop_iptables(){
			iptables -t nat -D PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 >/dev/null 2>&1
			ip6tables -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 >/dev/null 2>&1
		}
		[ -n "$(cat /etc/firewall.user 2>&1 | grep '启用外网访问SSH服务')" ] && ssh_ol=禁止 || ssh_ol=开启
		[ -z "$ssh_port" ] && ssh_port=10022
		echo -----------------------------------------------
		echo -e "\033[33m此功能仅针对使用Openwrt系统的设备生效，且不依赖clash服务\033[0m"
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
					elif [ -n "$(netstat -ntul |grep :$num)" ];then
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
				if [ "$ssh_ol" = "开启" ];then
					iptables -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22
					[ -n "$(command -v ip6tables)" ] && ip6tables -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22
					echo "iptables -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >> /etc/firewall.user
					[ -n "$(command -v ip6tables)" ] && echo "ip6tables -t nat -A PREROUTING -p tcp -m multiport --dports $ssh_port -j REDIRECT --to-ports 22 #启用外网访问SSH服务" >> /etc/firewall.user
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
	[ -n "$(cat /etc/crontabs/root 2>&1| grep otapredownload)" ] && mi_update=禁用 || mi_update=启用
	[ "$mi_autoSSH" = "已启用" ] && mi_autoSSH_type=32m已启用 || mi_autoSSH_type=31m未启用
	#
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用其他工具菜单：\033[0m"
	echo -e "\033[33m本页工具可能无法兼容全部Linux设备，请酌情使用！\033[0m"
	echo -e "磁盘占用/所在目录："
	du -sh $clashdir
	echo -----------------------------------------------
	echo -e " 1 ShellClash测试菜单"
	[ -f /etc/firewall.user ] && echo -e " 2 \033[32m配置\033[0m外网访问SSH"
	[ -f /etc/config/ddns -a -d "/etc/ddns" ] && echo -e " 3 配置DDNS服务(需下载相关脚本)"
	echo -e " 4 \033[32m流媒体增强\033[0m————用于解决流媒体解锁在TV应用上失效的问题"
	[ -x /usr/sbin/otapredownload ] && echo -e " 5 \033[33m$mi_update\033[0m小米系统自动更新"
	[ -f /usr/sbin/otapredownload ] && echo -e " 6 小米设备软固化SSH ———— \033[$mi_autoSSH_type \033[0m"
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
		
	elif [ "$num" = 1 ]; then
		source $clashdir/getdate.sh && testcommand  
		
	elif [ "$num" = 2 ]; then
		ssh_tools
		sleep 1
		tools  
		
	elif [ "$num" = 3 ]; then
		echo -----------------------------------------------
		if [ ! -f $clashdir/ShellDDNS.sh ];then
			echo -e "正在获取在线脚本……"
			$clashdir/start.sh webget /tmp/ShellDDNS.sh $update_url/tools/ShellDDNS.sh
			if [ "$?" = "0" ];then
				mv -f /tmp/ShellDDNS.sh $clashdir/ShellDDNS.sh
				source $clashdir/ShellDDNS.sh
			else
				echo -e "\033[31m文件下载失败！\033[0m"
			fi
		else
			source $clashdir/ShellDDNS.sh
		fi
		sleep 1
		tools  
		
	elif [ "$num" = 4 ]; then
		checkcfg=$(cat $ccfg)
		echo -----------------------------------------------
		echo -e "\033[36m请选择实现方式(不建议同时开启)：\033[0m"
		echo -e " 1 定时预解析流媒体DNS"
		echo -e " 2 Meta内核专属tls域名嗅探(推荐) \033[33m$sniffer\033[0m"
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			errornum
		elif [ "$num" = 0 ]; then
			i=
		elif [ "$num" = 1 ]; then
			streaming
		elif [ "$num" = 2 ]; then
			echo -----------------------------------------------
			if [ "$sniffer" = "未启用" ];then
				if [ "$clashcore" != "clash.meta" ];then
					rm -rf $bindir/clash
					clashcore=clash.meta
					setconfig clashcore $clashcore
					echo "已将clash内核切换为Meta内核！"
				fi
				sniffer=已启用
			else
				sniffer=未启用
			fi
			setconfig sniffer $sniffer
			echo -e "\033[32m设置成功！\033[0m"
			sleep 1
		fi
		if [ -n "$PID" ];then
			checkcfg_new=$(cat $ccfg)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
		tools
		
	elif [ -x /usr/sbin/otapredownload ] && [ "$num" = 5 ]; then	
		[ "$mi_update" = "禁用" ] && sed -i "/otapredownload/d" /etc/crontabs/root || echo "15 3,4,5 * * * /usr/sbin/otapredownload >/dev/null 2>&1" >> /etc/crontabs/root	
		echo -----------------------------------------------
		echo -e "已\033[33m$mi_update\033[0m小米路由器的自动更新，如未生效，请在官方APP中同步设置！"
		sleep 1
		tools	
		
	elif [ -f /usr/sbin/otapredownload ] && [ "$num" = 6 ]; then
		if [ "$mi_autoSSH" = "已启用" ];then
			mi_autoSSH=禁用
		else
			if [ "$systype" = "mi_snapshot" ];then
				echo -----------------------------------------------
				echo -e "\033[33m本功能使用软件命令进行固化不保证100%成功！\033[0m"
				echo -e "本功能需依赖clash服务，请确保clash为开机启动状态！"
				echo -e "\033[33m如有问题请加群反馈：\033[36;4mhttps://t.me/ShellClash\033[0m"
				read -p "请输入需要还原的SSH密码(不影响当前密码,回车可跳过) > " mi_autoSSH_pwd
				mi_autoSSH=已启用
				cp -f /etc/dropbear/dropbear_rsa_host_key $clashdir/dropbear_rsa_host_key 2>/dev/null
				cp -f /etc/dropbear/authorized_keys $clashdir/authorized_keys 2>/dev/null
				echo -e "\033[32m设置成功！\033[0m"
				sleep 1
			else
				echo 不支持的设备！
			fi
		fi
		setconfig mi_autoSSH $mi_autoSSH
		setconfig mi_autoSSH_pwd $mi_autoSSH_pwd
		tools		
	else
		errornum
	fi
}
clashcron(){
	croncmd(){
		if [ -n "$(crontab -h 2>&1 | grep '\-l')" ];then
			crontab $1
		else
			crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}')"
			[ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
			[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
			[ ! -w "$crondir" ] && crondir="/var/spool/cron"
			[ ! -w "$crondir" ] && echo "你的设备不支持定时任务配置，脚本大量功能无法启用，请前往 https://t.me/ShellClash 申请适配！"
			[ "$1" = "-l" ] && cat $crondir/$USER 2>/dev/null
			[ -f "$1" ] && cat $1 > $crondir/$USER
		fi
	}
	setcron(){
		setcrontab(){
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
				echo -----------------------------------------------
				read -p "请输入分钟（0-59） > " num
				if [ -z "$num" ]; then 
					errornum
					setcron
				elif [ $num -gt 59 ] || [ $num -lt 0 ]; then 
					errornum
					setcron
				else	
					min=$num
						echo -----------------------------------------------
						echo 将在$week1的$hour点$min分$cronname（旧的任务会被覆盖）
						read -p  "是否确认添加定时任务？(1/0) > " res
						if [ "$res" = '1' ]; then
							cronwords="$min $hour * * $week $cronset >/dev/null 2>&1 #$week1的$hour点$min分$cronname"
							tmpcron=/tmp/cron_$USER
							croncmd -l > $tmpcron
							sed -i "/$cronname/d" $tmpcron
							sed -i '/^$/d' $tmpcron
							echo "$cronwords" >> $tmpcron
							croncmd $tmpcron
							#华硕/Padavan固件存档在本地,其他则删除
							[ "$clashdir" = "/jffs/clash" -o "$clashdir" = "/etc/storage/clash" ] && mv -f $tmpcron $clashdir/cron || rm -f $tmpcron
							echo -----------------------------------------------
							echo -e "\033[31m定时任务已添加！！！\033[0m"
						fi
				fi			
			fi
		}
		echo -----------------------------------------------
		echo -e " 正在设置：\033[32m$cronname\033[0m定时任务"
		echo -e " 输入  1~7  对应\033[33m每周的指定某天\033[0m运行"
		echo -e " 输入   8   设为\033[33m每天\033[0m定时运行"
		echo -e " 输入 1,3,6 代表\033[36m指定每周1,3,6\033[0m运行(小写逗号分隔)"
		echo -e " 输入 a,b,c 代表\033[36m指定每周a,b,c\033[0m运行(1<=abc<=7)"
		echo -----------------------------------------------
		echo -e " 输入   9   \033[31m删除定时任务\033[0m"
		echo -e " 输入   0   返回上级菜单"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then 
			errornum
		elif [ "$num" = 0 ]; then
			i=
		elif [ "$num" = 9 ]; then
			croncmd -l > /tmp/conf && sed -i "/$cronname/d" /tmp/conf && croncmd /tmp/conf
			sed -i "/$cronname/d" $clashdir/cron 2>/dev/null
			rm -f /tmp/conf
			echo -----------------------------------------------
			echo -e "\033[31m定时任务：$cronname已删除！\033[0m"
		elif [ "$num" = 8 ]; then	
			week='*'
			week1=每天
			echo 已设为每天定时运行！
			setcrontab
		else
			week=$num	
			week1=每周$week
			echo 已设为每周 $num 运行！
			setcrontab
		fi
	}
	#定时任务菜单
	echo -----------------------------------------------
	echo -e "\033[30;47m欢迎使用定时任务功能：\033[0m"
	echo -----------------------------------------------
	echo  -e "\033[33m已添加的定时任务：\033[36m"
	croncmd -l | grep -oE ' #.*' 
	echo -e "\033[0m"-----------------------------------------------
	echo -e " 1 设置\033[33m定时重启\033[0mclash服务"
	echo -e " 2 设置\033[31m定时停止\033[0mclash服务"
	echo -e " 3 设置\033[32m定时开启\033[0mclash服务"
	echo -e " 4 设置\033[33m定时更新\033[0m订阅并重启服务"
	echo -e " 5 设置\033[33m定时更新\033[0m订阅但不重启服务"
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单" 
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then 
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then
		cronname=重启clash服务
		cronset="$clashdir/start.sh restart"
		setcron
		clashcron
	elif [ "$num" = 2 ]; then
		cronname=停止clash服务
		cronset="$clashdir/start.sh stop"
		setcron
		clashcron
	elif [ "$num" = 3 ]; then
		cronname=开启clash服务
		cronset="$clashdir/start.sh start"
		setcron
		clashcron
	elif [ "$num" = 4 ]; then	
		cronname=更新订阅链接
		cronset="$clashdir/start.sh getyaml && $clashdir/start.sh restart"
		setcron	
		clashcron
	elif [ "$num" = 5 ]; then	
		cronname=更新订阅但不重启
		cronset="$clashdir/start.sh updateyaml"
		setcron	
		clashcron
	else
		errornum
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
	echo -e " 8 \033[35m其他工具\033[0m"
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
		exit;
  
	elif [ "$num" = 2 ]; then
		checkcfg=$(cat $ccfg)
		clashcfg
		if [ -n "$PID" ];then
			checkcfg_new=$(cat $ccfg)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
		clashsh

	elif [ "$num" = 3 ]; then
		$clashdir/start.sh stop
		echo -----------------------------------------------
		echo -e "\033[31mClash服务已停止！\033[0m"
		clashsh

	elif [ "$num" = 4 ]; then
		echo -----------------------------------------------
		if [ "$autostart" = "enable" ]; then
			[ -d /etc/rc.d ] && cd /etc/rc.d && rm -rf *clash > /dev/null 2>&1 && cd - >/dev/null
			type systemctl >/dev/null 2>&1 && systemctl disable clash.service > /dev/null 2>&1
			touch $clashdir/.dis_startup
			echo -e "\033[33m已禁止Clash开机启动！\033[0m"
		elif [ "$autostart" = "disable" ]; then
			[ -f /etc/rc.common ] && /etc/init.d/clash enable
			type systemctl >/dev/null 2>&1 && systemctl enable clash.service > /dev/null 2>&1
			rm -rf $clashdir/.dis_startup
			echo -e "\033[32m已设置Clash开机启动！\033[0m"
		fi
		clashsh

	elif [ "$num" = 5 ]; then
		clashcron
		clashsh
    
	elif [ "$num" = 6 ]; then
		source $clashdir/getdate.sh && clashlink
		clashsh
		
	elif [ "$num" = 7 ]; then
		checkcfg=$(cat $ccfg)
		clashadv
		if [ -n "$PID" ];then
			checkcfg_new=$(cat $ccfg)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
		clashsh

	elif [ "$num" = 8 ]; then
		tools
		clashsh

	elif [ "$num" = 9 ]; then
		checkcfg=$(cat $ccfg)
		source $clashdir/getdate.sh && update
		if [ -n "$PID" ];then
			checkcfg_new=$(cat $ccfg)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
		clashsh
	
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
		echo "	-u 卸载脚本"
		echo -----------------------------------------
		echo "	$clashdir/start.sh start	启动服务"
		echo "	$clashdir/start.sh stop		停止服务"
		echo "	$clashdir/start.sh init		写入服务"
		echo -----------------------------------------
		echo "在线求助：t.me/ShellClash"
		echo "官方博客：juewuy.github.io"
		echo "发布页面：github.com/juewuy/ShellClash"
		echo -----------------------------------------
	;;
	-t)
		shtype=sh && [ -n "$(ls -l /bin/sh|grep -o dash)" ] && shtype=bash
		$shtype -x $clashdir/clash.sh
	;;
	-st)
		shtype=sh && [ -n "$(ls -l /bin/sh|grep -o dash)" ] && shtype=bash
		$shtype -x $clashdir/start.sh $2 $3 $4 $5 $6
	;;
	-u)
		read -p "确认卸载ShellClash？（警告：该操作不可逆！）[1/0] " res
		if [ "$res" = '1' ]; then
			$clashdir/start.sh stop
			$clashdir/start.sh cronset "clash服务"
			$clashdir/start.sh cronset "订阅链接"
			$clashdir/start.sh cronset "ShellClash初始化"
			[ -w ~/.bashrc ] && profile=~/.bashrc
			[ -w /etc/profile ] && profile=/etc/profile
			sed -i '/alias clash=*/'d $profile
			sed -i '/export clashdir=*/'d $profile
			sed -i '/all_proxy/'d $profile
			sed -i '/ALL_PROXY/'d $profile
			sed -i "/启用外网访问SSH服务/d" /etc/firewall.user
			sed -i '/ShellClash初始化/'d /etc/storage/started_script.sh 2>/dev/null
			sed -i '/ShellClash初始化/'d /jffs/.asusrouter 2>/dev/null
			rm -rf $clashdir
			rm -rf /etc/init.d/clash
			rm -rf /etc/systemd/system/clash.service
			rm -rf /usr/lib/systemd/system/clash.service
			rm -rf /www/clash
			rm -rf /tmp/clash_$USER
			sed -Ei s/0:7890/7890:7890/g /etc/passwd
			userdel -r shellclash 2>/dev/null
			echo -----------------------------------------------
			echo -e "\033[36m已卸载ShellClash相关文件！有缘再会！\033[0m"
			echo -e "\033[33m请手动关闭当前窗口以重置环境变量！\033[0m"
			echo -----------------------------------------------
			exit
		fi
		echo -e "\033[31m操作已取消！\033[0m"
	;;
	*)
		$0 -h
	;;
esac
