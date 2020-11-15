#!/bin/sh
# Copyright (C) Juewuy

#脚本内部工具
getconfig(){
	#加载配置文件
	[ -z "$clashdir" ] && source /etc/profile > /dev/null
	[ -z "$clashdir" ] && source ~/.bashrc > /dev/null
	ccfg=$clashdir/mark
	[ -f $ccfg ] && source $ccfg
	#默认设置
	[ -z "$bindir" ] && bindir=$clashdir
	[ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod=Redir模式
	[ -z "$redir_mod" ] && redir_mod=纯净模式
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ -z "$common_ports" ] && common_ports=已开启
	[ -z "$dns_mod" ] && dns_mod=redir_host
	[ -z "$dns_over" ] && dns_over=已开启
	[ -z "$modify_yaml" ] && modify_yaml=未开启
	[ -z "$ipv6_support" ] && ipv6_support=未开启
	[ -z "$start_old" ] && start_old=未开启
	[ -z "$local_proxy" ] && local_proxy=未开启
	[ -z "$mix_port" ] && mix_port=7890
	[ -z "$redir_port" ] && redir_port=7892
	[ -z "$db_port" ] && db_port=9999
	[ -z "$dns_port" ] && dns_port=1053
	[ -z "$dns_nameserver" ] && dns_nameserver='114.114.114.114, 223.5.5.5'
	[ -z "$dns_fallback" ] && dns_fallback='1.0.0.1, 8.8.4.4'
	#是否代理常用端口
	[ "$common_ports" = "已开启" ] && ports='-m multiport --dports 53,587,465,995,993,143,80,443'
	}
setconfig(){
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath=$clashdir/mark || configpath=$3
	sed -i "/${1}*/"d $configpath
	echo "${1}=${2}" >> $configpath
}
compare(){
	if command -v cmp >/dev/null 2>&1; then
		cmp -s $1 $2
	else
		[ "$(cat $1)" = "$(cat $2)" ] && return 0 || return 1
	fi
}
webget(){
	[ -n "$(pidof clash)" ] && export all_proxy="http://$authentication@127.0.0.1:$mix_port" #设置临时http代理
	#参数【$1】代表下载目录，【$2】代表在线地址
	#参数【$3】代表输出显示，【$4】不启用重定向
	if curl --version > /dev/null 2>&1;then
		[ "$3" = "echooff" ] && progress='-s' || progress='-#'
		[ -z "$4" ] && redirect='-L' || redirect=''
		result=$(curl -w %{http_code} --connect-timeout 5 $progress $redirect -ko $1 $2)
	else
		[ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
		[ "$3" = "echoon" ] && progress=''
		[ -z "$4" ] && redirect='' || redirect='--max-redirect=0'
		wget -Y on $progress $redirect --no-check-certificate --timeout=5 -O $1 $2 
		[ "$?" = 0 ] && result="200"
	fi
	export all_proxy=''
}
logger(){
	[ -n "$2" ] && echo -e "\033[$2m$1\033[0m"
	echo `date "+%G-%m-%d %H:%M:%S"` $1 >> $clashdir/log
	[ "$(wc -l $clashdir/log | awk '{print $1}')" -gt 30 ] && sed -i '1,5d' $clashdir/log
}
cronset(){
	# 参数1代表要移除的关键字,参数2代表要添加的任务语句
	crondir=/tmp/cron_$USER
	crontab -l > $crondir
	sed -i "/$1/d" $crondir
	echo "$2" >> $crondir
	crontab $crondir
	rm -f $crondir
}
mark_time(){
	start_time=`date +%s`
	sed -i '/start_time*/'d $clashdir/mark
	echo start_time=$start_time >> $clashdir/mark
}
#配置文件相关
getyaml(){
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	#前后端订阅服务器地址索引，可在此处添加！
	Server=`sed -n ""$server_link"p"<<EOF
subcon.dlj.tf
subconverter.herokuapp.com
subcon.py6.pw
api.dler.io
api.wcc.best
EOF`
	Config=`sed -n ""$rule_link"p"<<EOF
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_NoReject.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Mini_MultiMode.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_AdblockPlus.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Mini_AdblockPlus.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Full_Netflix.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Full_AdblockPlus.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/lhie1_clash.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/lhie1_dler.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/connershua_pro.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/connershua_backtocn.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/dlercloud_lige_platinum.ini
https://subconverter.oss-ap-southeast-1.aliyuncs.com/Rules/RemoteConfig/special/basic.ini
https://subconverter.oss-ap-southeast-1.aliyuncs.com/Rules/RemoteConfig/special/netease.ini
EOF`
	#如果传来的是Url链接则合成Https链接，否则直接使用Https链接
	if [ -z "$Https" ];then
		Https="https://$Server/sub?target=clash&insert=true&new_name=true&scv=true&exclude=$exclude&include=$include&url=$Url&config=$Config"
		markhttp=1
	fi
	#输出
	echo -----------------------------------------------
	echo 正在连接服务器获取配置文件…………链接地址为：
	echo -e "\033[4;32m$Https\033[0m"
	echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
	#获取在线yaml文件
	yaml=$clashdir/config.yaml
	yamlnew=/tmp/clash_config_$USER.yaml
	rm -rf $yamlnew
	webget $yamlnew $Https
	if [ "$result" != "200" ];then
		if [ -z "$markhttp" ];then
			echo -----------------------------------------------
			logger "配置文件获取失败！" 31
			echo -e "\033[31m请尝试使用【导入订阅】功能！\033[0m"
			echo -----------------------------------------------
			exit 1
		else
			if [ "$retry" -ge 5 ];then
				logger "无法获取配置文件，请检查链接格式以及网络连接状态！" 31
				exit 1
			else
				retry=$((retry+1))
				logger "配置文件获取失败！" 31
				echo -e "\033[32m尝试使用其他服务器获取配置！\033[0m"
				logger "正在重试第$retry次/共5次！" 32
				sed -i '/server_link=*/'d $ccfg
				if [ "$server_link" -ge 5 ]; then
					server_link=0
				fi
				server_link=$((server_link+1))
				echo server_link=$server_link >> $ccfg
				Https=""
				getyaml
			fi
		fi
	else
		Https=""
		#检测节点或providers
		if [ -z "$(cat $yamlnew | grep -E 'server:|proxy-providers:' | grep -v 'nameserver')" ];then
			echo -----------------------------------------------
			logger "获取到了配置文件，但似乎并不包含正确的节点信息！" 31
			echo -----------------------------------------------
			sed -n '1,30p' $yamlnew
			echo -----------------------------------------------
			echo -e "\033[33m请检查如上配置文件信息:\033[0m"
			echo -----------------------------------------------
			exit 1
		fi
		#检测旧格式
		if cat $yamlnew | grep 'Proxy Group:' >/dev/null;then
			echo -----------------------------------------------
			logger "已经停止对旧格式配置文件的支持！！！" 31
			echo -e "请使用新格式或者使用【导入节点/链接】功能！"
			echo -----------------------------------------------
			exit 1
		fi
		#检测不支持的加密协议
		if cat $yamlnew | grep 'cipher: chacha20,' >/dev/null;then
			echo -----------------------------------------------
			logger "不支持chacha20加密，请更换节点加密协议！！！" 31
			echo -----------------------------------------------
			exit 1
		fi
		#如果不同则备份并替换文件
		if [ -f $yaml ];then
			compare $yamlnew $yaml
			[ "$?" = 0 ] && rm -f $yamlnew || mv -f $yaml $yaml.bak && mv -f $yamlnew $yaml
		else
			mv -f $yamlnew $yaml
		fi
		echo 配置文件已生成！正在启动clash使其生效！
		#启动clash服务
		$0 start
		if [ "$?" = 0 ];then
			logger "配置文件获取成功！clash服务已启动！"
			exit 0
		else
			if [ -f $yaml.bak ];then
				$0 stop
				mv -f $yaml.bak $yaml
				$0 start
				[ "$?" = 0 ] && logger "已还原配置文件并重启clash！" 32 && exit 0
				logger "已还原配置文件但依然无法启动clash！" 31 && exit 1
			fi
		fi
	fi
}
modify_yaml(){
##########需要变更的配置###########
	lan='allow-lan: true'
	mode='mode: Rule'
	log='log-level: info'
	[ "$ipv6_support" = "已开启" ] && ipv6='ipv6: true' || ipv6='ipv6: false'
	external="external-controller: 0.0.0.0:$db_port"
	[ -d $clashdir/ui ] && db_ui=ui
	[ "$redir_mod" != "Redir模式" ] && tun='tun: {enable: true, stack: system}' || tun='tun: {enable: false}'
	exper='experimental: {ignore-resolve-fail: true, interface-name: en0}'
	#dns配置
	if [ "$dns_mod" = "fake-ip" ];then
		dns='dns: {enable: true, listen: 0.0.0.0:'$dns_port', use-hosts: true, fake-ip-range: 198.18.0.1/16, enhanced-mode: fake-ip, fake-ip-filter: ["*.lan", "time.windows.com", "time.nist.gov", "time.apple.com", "time.asia.apple.com", "*.ntp.org.cn", "*.openwrt.pool.ntp.org", "time1.cloud.tencent.com", "time.ustc.edu.cn", "pool.ntp.org", "ntp.ubuntu.com", "ntp.aliyun.com", "ntp1.aliyun.com", "ntp2.aliyun.com", "ntp3.aliyun.com", "ntp4.aliyun.com", "ntp5.aliyun.com", "ntp6.aliyun.com", "ntp7.aliyun.com", "time1.aliyun.com", "time2.aliyun.com", "time3.aliyun.com", "time4.aliyun.com", "time5.aliyun.com", "time6.aliyun.com", "time7.aliyun.com", "*.time.edu.cn", "time1.apple.com", "time2.apple.com", "time3.apple.com", "time4.apple.com", "time5.apple.com", "time6.apple.com", "time7.apple.com", "time1.google.com", "time2.google.com", "time3.google.com", "time4.google.com", "music.163.com", "*.music.163.com", "*.126.net", "musicapi.taihe.com", "music.taihe.com", "songsearch.kugou.com", "trackercdn.kugou.com", "*.kuwo.cn", "api-jooxtt.sanook.com", "api.joox.com", "joox.com", "y.qq.com", "*.y.qq.com", "streamoc.music.tc.qq.com", "mobileoc.music.tc.qq.com", "isure.stream.qqmusic.qq.com", "dl.stream.qqmusic.qq.com", "aqqmusic.tc.qq.com", "amobile.music.tc.qq.com", "*.xiami.com", "*.music.migu.cn", "music.migu.cn", "*.msftconnecttest.com", "*.msftncsi.com", "localhost.ptlogin2.qq.com", "*.*.*.srv.nintendo.net", "*.*.stun.playstation.net", "xbox.*.*.microsoft.com", "*.*.xboxlive.com", "proxy.golang.org"], nameserver: ['$dns_nameserver', 127.0.0.1:53], fallback: ['$dns_fallback'], fallback-filter: {geoip: true}}'
	else
		dns='dns: {enable: true, ipv6: true, listen: 0.0.0.0:'$dns_port', use-hosts: true, enhanced-mode: redir-host, nameserver: ['$dns_nameserver$dns_local'], fallback: ['$dns_fallback'], fallback-filter: {geoip: true}}'
	fi
	#设置目录
	yaml=$clashdir/config.yaml
	tmpdir=/tmp/clash_$USER
	#预删除需要添加的项目
	a=$(grep -n "port:" $yaml | head -1 | cut -d ":" -f 1)
	b=$(grep -n "^prox" $yaml | head -1 | cut -d ":" -f 1)
	b=$((b-1))
	mkdir -p $tmpdir > /dev/null
	sed "${a},${b}d" $yaml > $tmpdir/proxy.yaml
	#跳过本地tls证书验证
	[ "$skip_cert" = "已开启" ] && sed -i '10,99s/skip-cert-verify: false/skip-cert-verify: true/' $tmpdir/proxy.yaml
	#添加配置
###################################
	cat > $tmpdir/set.yaml <<EOF
mixed-port: $mix_port
redir-port: $redir_port
authentication: ["$authentication"]
$lan
$mode
$log
$ipv6
external-controller: :$db_port
external-ui: $db_ui
secret: $secret
$tun
$exper
$dns
EOF
###################################
	[ -f $clashdir/user.yaml ] && yaml_user=$clashdir/user.yaml
	#合并文件
	cut -c 1- $tmpdir/set.yaml $yaml_user $tmpdir/proxy.yaml > $tmpdir/config.yaml
	#插入自定义规则
	if [ -f $clashdir/rules.yaml ];then
		while read line;do
			[ -z "$(echo "$line" | grep '#')" ] && \
			[ -n "$(echo "$line" | grep '\-\ ')" ] && \
			sed -i "/$line/d" $tmpdir/config.yaml && \
			sed -i "/^rules:/a\ $line" $tmpdir/config.yaml
		done < $clashdir/rules.yaml
	fi
	#如果没有使用小闪存模式
	if [ "$tmpdir" != "$bindir" ];then
		compare $tmpdir/config.yaml $yaml
		[ "$?" != 0 ] && mv -f $tmpdir/config.yaml $yaml || rm -f $tmpdir/config.yaml
	fi
	rm -f $tmpdir/set.yaml
	rm -f $tmpdir/proxy.yaml
}
#设置路由规则
start_redir(){
	#流量过滤规则
	iptables -t nat -N clash
	iptables -t nat -A clash -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A clash -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A clash -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A clash -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A clash -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A clash -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A clash -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A clash -d 240.0.0.0/4 -j RETURN
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
		#mac白名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash -p tcp $ports -m mac --mac-source $mac -j REDIRECT --to-ports $redir_port
		done
	else
		#mac黑名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash -m mac --mac-source $mac -j RETURN
		done
		iptables -t nat -A clash -p tcp $ports -j REDIRECT --to-ports $redir_port
	fi
	iptables -t nat -A PREROUTING -p tcp -j clash
	#设置ipv6转发
	ip6_nat=$(ip6tables -t nat -L 2>&1 | grep -o 'Chain')
	if [ -n "$ip6_nat" -a "$ipv6_support" = "已开启" ];then
		ip6tables -t nat -N clashv6
		if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
			#mac白名单
			for mac in $(cat $clashdir/mac); do
				ip6tables -t nat -A clashv6 -p tcp $ports -m mac --mac-source $mac -j REDIRECT --to-ports $redir_port
			done
		else
			#mac黑名单
			for mac in $(cat $clashdir/mac); do
				ip6tables -t nat -A clashv6 -m mac --mac-source $mac -j RETURN
			done
			ip6tables -t nat -A clashv6 -p tcp $ports -j REDIRECT --to-ports $redir_port
		fi
		ip6tables -t nat -A PREROUTING -p tcp -j clashv6
	fi
}
start_dns(){
	#允许tun网卡接受流量
	if [ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ];then
		iptables -I FORWARD -o utun -j ACCEPT
		[ "$ipv6_support" = "已开启" ] && ip6tables -I FORWARD -o utun -j ACCEPT > /dev/null 2>&1
	fi
	#设置dns转发
	iptables -t nat -N clash_dns
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
		#mac白名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash_dns -p udp --dport 53 -m mac --mac-source $mac -j REDIRECT --to $dns_port
			iptables -t nat -A clash_dns -p tcp --dport 53 -m mac --mac-source $mac -j REDIRECT --to $dns_port
		done
	else
		#mac黑名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash_dns -m mac --mac-source $mac -j RETURN
		done	
		iptables -t nat -A clash_dns -p udp --dport 53 -j REDIRECT --to $dns_port
		iptables -t nat -A clash_dns -p tcp --dport 53 -j REDIRECT --to $dns_port
	fi
	iptables -t nat -A PREROUTING -p udp -j clash_dns
	#Google home DNS特殊处理
	iptables -t nat -I PREROUTING -p tcp -d 8.8.8.8 -j clash_dns
	iptables -t nat -I PREROUTING -p tcp -d 8.8.4.4 -j clash_dns
	#ipv6DNS
	ip6_nat=$(ip6tables -t nat -L 2>&1 | grep -o 'Chain')
	if [ -n "$ip6_nat" ];then
		ip6tables -t nat -N clashv6_dns > /dev/null 2>&1
		if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
			#mac白名单
			for mac in $(cat $clashdir/mac); do
				ip6tables -t nat -A clashv6_dns -p udp --dport 53 -m mac --mac-source $mac -j REDIRECT --to $dns_port
				ip6tables -t nat -A clashv6_dns -p tcp --dport 53 -m mac --mac-source $mac -j REDIRECT --to $dns_port
			done
		else
			#mac黑名单
			for mac in $(cat $clashdir/mac); do
				ip6tables -t nat -A clashv6_dns -m mac --mac-source $mac -j RETURN
			done	
			ip6tables -t nat -A clashv6_dns -p udp --dport 53 -j REDIRECT --to $dns_port
			ip6tables -t nat -A clashv6_dns -p tcp --dport 53 -j REDIRECT --to $dns_port
		fi
		ip6tables -t nat -A PREROUTING -p udp -j clashv6_dns
	else
		ip6tables -I INPUT -p tcp --dport 53 -j REJECT > /dev/null 2>&1
		ip6tables -I INPUT -p udp --dport 53 -j REJECT > /dev/null 2>&1
	fi
}
start_udp(){
	ip rule add fwmark 1 table 100
	ip route add local default dev lo table 100
	iptables -t mangle -N clash
	iptables -t mangle -A clash -d 0.0.0.0/8 -j RETURN
	iptables -t mangle -A clash -d 10.0.0.0/8 -j RETURN
	iptables -t mangle -A clash -d 127.0.0.0/8 -j RETURN
	iptables -t mangle -A clash -d 169.254.0.0/16 -j RETURN
	iptables -t mangle -A clash -d 172.16.0.0/12 -j RETURN
	iptables -t mangle -A clash -d 192.168.0.0/16 -j RETURN
	iptables -t mangle -A clash -d 224.0.0.0/4 -j RETURN
	iptables -t mangle -A clash -d 240.0.0.0/4 -j RETURN
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
		#mac白名单
		for mac in $(cat $clashdir/mac); do
			iptables -t mangle -A clash -p udp -m mac --mac-source $mac -j TPROXY --on-port $redir_port --tproxy-mark 1
		done
	else
		#mac黑名单
		for mac in $(cat $clashdir/mac); do
			iptables -t mangle -A clash -m mac --mac-source $mac -j RETURN
		done
		iptables -t mangle -A clash -p udp -j TPROXY --on-port $redir_port --tproxy-mark 1
	fi
	iptables -t mangle -A PREROUTING -p udp -j clash
}
stop_iptables(){
    #重置iptables规则
	iptables -t nat -D PREROUTING -p tcp -j clash > /dev/null 2>&1
	iptables -t nat -D PREROUTING -p udp -j clash_dns > /dev/null 2>&1
	iptables -t nat -D PREROUTING -p tcp -d 8.8.8.8 -j clash_dns > /dev/null 2>&1
	iptables -t nat -D PREROUTING -p tcp -d 8.8.4.4 -j clash_dns > /dev/null 2>&1
	iptables -t nat -F clash > /dev/null 2>&1
	iptables -t nat -X clash > /dev/null 2>&1
	iptables -t nat -F clash_dns > /dev/null 2>&1
	iptables -t nat -X clash_dns > /dev/null 2>&1
	iptables -D FORWARD -o utun -j ACCEPT > /dev/null 2>&1
	#重置udp规则
	iptables -t mangle -D PREROUTING -p udp -j clash > /dev/null 2>&1
	iptables -t mangle -F clash > /dev/null 2>&1
	iptables -t mangle -X clash > /dev/null 2>&1
	#重置ipv6规则
	ip6tables -t nat -D PREROUTING -p tcp -j clashv6 > /dev/null 2>&1
	ip6tables -t nat -D PREROUTING -p udp -j clashv6_dns > /dev/null 2>&1
	ip6tables -t nat -F clashv6 > /dev/null 2>&1
	ip6tables -t nat -X clashv6 > /dev/null 2>&1
	ip6tables -t nat -F clashv6_dns > /dev/null 2>&1
	ip6tables -t nat -X clashv6_dns > /dev/null 2>&1
	ip6tables -D FORWARD -o utun -j ACCEPT > /dev/null 2>&1
}
#面板配置保存相关
web_save(){
	get_save(){
		if curl --version > /dev/null 2>&1;then
			curl -s -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1"
		elif [ -n "$(wget --help 2>&1|grep '\-\-method')" ];then
			wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1"
		else
			logger 当前系统未安装curl且wget的版本太低，无法保存节点配置！ 31
			getconfig
			cronset '保存节点配置'
		fi
	}
	#使用get_save获取面板节点设置
	get_save http://localhost:${db_port}/proxies | awk -F "{" '{for(i=1;i<=NF;i++) print $i}' | grep -E '^"all".*"Selector"' | grep -oE '"name".*"now".*",' | sed 's/"name"://g' | sed 's/"now"://g'| sed 's/"//g' > /tmp/clash_web_save_$USER
	#对比文件，如果有变动且不为空则写入磁盘，否则清除缓存
	[ ! -s /tmp/clash_web_save_$USER ] && compare /tmp/clash_web_save_$USER $clashdir/web_save
	[ "$?" = 0 ] && rm -rf /tmp/clash_web_save_$USER || mv -f /tmp/clash_web_save_$USER $clashdir/web_save
}
web_restore(){
	put_save(){
		if curl --version > /dev/null 2>&1;then
			curl -sS -X PUT -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1" -d "$2" >/dev/null
		else
			wget -q --method=PUT --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" --body-data="$2" "$1" >/dev/null
		fi
	}
	#设置循环检测clash面板端口
	i=1
	while [ $i -lt 10 ]
	do
		sleep 1
		if curl --version > /dev/null 2>&1;then
			test=$(curl -s http://localhost:${db_port})
		else
			test=$(wget -q -O - http://localhost:${db_port})
		fi
		[ -n "$test" ] && i=10
	done
	#发送数据
	num=$(cat $clashdir/web_save | wc -l)
	for i in `seq $num`;
	do
		group_name=$(awk -F ',' 'NR=="'${i}'" {print $1}' $clashdir/web_save | sed 's/ /%20/g')
		now_name=$(awk -F ',' 'NR=="'${i}'" {print $2}' $clashdir/web_save)
		put_save http://localhost:${db_port}/proxies/${group_name} "{\"name\":\"${now_name}\"}"
	done
}
#启动相关
catpac(){
	host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
	[ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E '192.|10.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	[ -z "$host" ] && host=127.0.0.1
	cat > /tmp/clash_pac <<EOF
function FindProxyForURL(url, host) {
	if (
		isInNet(host, "0.0.0.0", "255.0.0.0")||
		isInNet(host, "10.0.0.0", "255.0.0.0")||
		isInNet(host, "127.0.0.0", "255.0.0.0")||
		isInNet(host, "224.0.0.0", "224.0.0.0")||
		isInNet(host, "240.0.0.0", "240.0.0.0")||
		isInNet(host, "172.16.0.0",  "255.240.0.0")||
		isInNet(host, "192.168.0.0", "255.255.0.0")||
		isInNet(host, "169.254.0.0", "255.255.0.0")
	)
		return "DIRECT";
	else
		return "SOCKS5 $host:$mix_port; PROXY $host:$mix_port; DIRECT;"
}
EOF
	compare /tmp/clash_pac $bindir/ui/pac
	[ "$?" = 0 ] && rm -rf /tmp/clash_pac || mv -f /tmp/clash_pac $bindir/ui/pac
}
bfstart(){
	#读取配置文件
	getconfig
	[ ! -d $bindir/ui ] && mkdir -p $bindir/ui
	[ -z "$update_url" ] && update_url=https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master
	#检查clash核心
	if [ ! -f $bindir/clash ];then
		if [ -f $clashdir/clash ];then
			mv $clashdir/clash $bindir/clash && chmod +x $bindir/clash
		else
			logger "未找到clash核心，正在下载！" 33
			[ -z "$clashcore" ] && [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ] && clashcore=clashpre || clashcore=clash
			[ -z "$cpucore" ] && source $clashdir/getdate.sh && getcpucore
			[ -z "$cpucore" ] && logger 找不到设备的CPU信息，请手动指定处理器架构类型！ 31 && setcpucore
			webget $bindir/clash "$update_url/bin/$clashcore/clash-linux-$cpucore"
			[ "$?" = 1 ] && logger "核心下载失败，已退出！" 31 && rm -f $bindir/clash && exit 1
			[ ! -x $bindir/clash ] && chmod +x $bindir/clash 	#检测可执行权限
			clashv=$($bindir/clash -v | awk '{print $2}')
			setconfig clashv $clashv
		fi
	fi
	#检查数据库文件
	if [ ! -f $bindir/Country.mmdb ];then
		if [ -f $clashdir/Country.mmdb ];then
			mv $clashdir/Country.mmdb $bindir/Country.mmdb
		else
			logger "未找到GeoIP数据库，正在下载！" 33
			webget $bindir/Country.mmdb $update_url/bin/Country.mmdb
			[ "$?" = 1 ] && logger "数据库下载失败，已退出！" 31 && rm -f $bindir/Country.mmdb && exit 1
			GeoIP_v=$(date +"%Y%m%d")
			setconfig GeoIP_v $GeoIP_v
		fi
	fi
	#检查dashboard文件
	if [ -f $clashdir/ui/index.html -a ! -f $bindir/ui/index.html ];then
		cp -rf $clashdir/ui $bindir
	fi
	catpac #生成pac文件
	#检查yaml配置文件
	if [ ! -f $clashdir/config.yaml ];then
		if [ -n "$Url" -o -n "$Https" ];then
			logger "未找到配置文件，正在下载！" 33
			getyaml
			exit 0
		else
			logger "未找到配置文件链接，请先导入配置文件！" 31
			exit 1
		fi
	fi
}
afstart(){
	#读取配置文件
	getconfig
	$bindir/clash -t -d $bindir >/dev/null
	if [ "$?" = 0 ];then
		#修改iptables规则使流量进入clash
		[ "$redir_mod" != "纯净模式" ] && [ "$dns_no" != "已禁用" ] && start_dns
		[ "$redir_mod" != "纯净模式" ] && [ "$redir_mod" != "Tun模式" ] && start_redir
		[ "$redir_mod" = "Redir模式" ] && [ "$tproxy_mod" = "已开启" ] && start_udp
		#标记启动时间
		mark_time
		#设置本机代理
		[ "$local_proxy" = "已开启" ] && $0 set_proxy $mix_port $db_port
		#启用面板配置自动保存
		cronset '#每10分钟保存节点配置' "*/10 * * * * test -n \"$(pidof clash)\" && $clashdir/start.sh web_save #每10分钟保存节点配置"
		[ -f $clashdir/web_save ] && web_restore & #后台还原面板配置
	else
		logger "clash服务启动失败！请查看报错信息！" 31
		logger `$bindir/clash -t -d $bindir 1>&0` 0
		$0 stop
		exit 1
	fi
}
start_old(){
	#使用传统后台执行二进制文件的方式执行
	$bindir/clash -d $bindir >/dev/null &
	afstart
	$0 daemon
}

case "$1" in

bfstart)
		bfstart
	;;
afstart)
		afstart
	;;
start)		
		[ -n "$(pidof clash)" ] && $0 stop #禁止多实例
		getconfig
		#检测必须文件并下载
		bfstart
		stop_iptables #清理iptables
		#使用内置规则强行覆盖config配置文件
		[ "$modify_yaml" != "已开启" ] && modify_yaml
		#使用不同方式启动clash服务
		if [ "$start_old" = "已开启" ];then
			start_old
		elif [ -f /etc/rc.common ];then
			/etc/init.d/clash start
		elif [ "$USER" = "root" ];then
			systemctl start clash.service
		else
			start_old
		fi
	;;
stop)	
		getconfig
		[ -n "$(pidof clash)" ] && web_save #保存面板配置
		#删除守护进程&面板配置自动保存
		cronset "clash保守模式守护进程"
		cronset "保存节点配置"
		#多种方式结束进程
		if [ -f /etc/rc.common ];then
			/etc/init.d/clash stop >/dev/null 2>&1
		elif [ "$USER" = "root" ];then
			systemctl stop clash.service >/dev/null 2>&1
		fi
		PID=$(pidof clash) && [ -n "$PID" ] &&  kill -9 $PID >/dev/null 2>&1
		stop_iptables #清理iptables
		[ "$local_proxy" = "已开启" ] && $0 unset_proxy #禁用本机代理
        ;;
restart)
        $0 stop
        $0 start
        ;;
getyaml)	
		getconfig
		getyaml
		;;
webget)
		webget $2 $3 $4 $5
		;;
web_save)
		getconfig
		web_save
	;;
daemon)
		getconfig
		cronset '#clash保守模式守护进程' "*/1 * * * * test -z \"$(pidof clash)\" && $clashdir/start.sh restart #clash保守模式守护进程"
	;;
set_proxy)
		getconfig
		#GNOME配置
		if  [ "$local_proxy_type" = "GNOME" ];then
			gsettings set org.gnome.system.proxy autoconfig-url "http://127.0.0.1:$db_port/ui/pac"
			gsettings set org.gnome.system.proxy mode "auto"
		#KDE配置
		elif  [ "$local_proxy_type" = "KDE" ];then
			kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "Proxy Config Script" "http://127.0.0.1:$db_port/ui/pac"
			kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "ProxyType" 2
		#环境变量方式
		else
			[ -w ~/.bashrc ] && profile=~/.bashrc
			[ -w /etc/profile ] && profile=/etc/profile
			echo 'export all_proxy=http://127.0.0.1:'"$mix_port" >> $profile
			echo 'export ALL_PROXY=$all_proxy' >>  $profile
		fi
	;;
unset_proxy)
		#GNOME配置
		if  gsettings --version >/dev/null 2>&1 ;then
			gsettings set org.gnome.system.proxy mode "none"
		fi
		#KDE配置
		if  kwriteconfig5 -h >/dev/null 2>&1 ;then
			kwriteconfig5 --file kioslaverc --group "Proxy Settings" --key "ProxyType" 0
		fi
		#环境变量方式
		[ -w ~/.bashrc ] && profile=~/.bashrc
		[ -w /etc/profile ] && profile=/etc/profile
		sed -i '/all_proxy/'d  $profile
		sed -i '/ALL_PROXY/'d  $profile
	;;
esac

exit 0
