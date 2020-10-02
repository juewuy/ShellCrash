#!/bin/sh
# Copyright (C) Juewuy

getconfig(){
#加载环境变量
[ -z "$clashdir" ] && source /etc/profile > /dev/null 2>&1
ccfg=$clashdir/mark
#检查/读取标识文件
[ ! -f $ccfg ]&& echo '#标识clash运行状态的文件，不明勿动！' >> $ccfg
source $ccfg
#默认设置
[ -z "$skip_cert" ] && skip_cert=已开启
[ -z "$common_ports" ] && common_ports=已开启
[ -z "$dns_mod" ] && dns_mod=redir_host
[ -z "$dns_over" ] && dns_over=已开启
[ -z "$modify_yaml" ] && modify_yaml=未开启
[ -z "$ipv6_support" ] && ipv6_support=未开启
[ -z "$start_old" ] && start_old=未开启
[ -z "$local_proxy" ] && local_proxy=未开启
#是否代理常用端口
[ "$common_ports" = "已开启" ] && ports='-m multiport --dports 22,53,587,465,995,993,143,80,443 '
}
getyaml(){
#前后端订阅服务器地址索引，可在此处添加！
Server=`sed -n ""$server_link"p"<<EOF
subconverter-web.now.sh
subconverter.herokuapp.com
subcon.py6.pw
api.dler.io
api.wcc.best
skapi.cool
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
if [ -z $Https ];then
	#echo $Url
	Https="https://$Server/sub?target=clashr&insert=true&new_name=true&scv=true&exclude=$exclude&url=$Url&config=$Config"
	markhttp=1
fi
#
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo 正在连接服务器获取配置文件…………链接地址为：
echo -e "\033[4;32m$Https\033[0m"
echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
echo -e "\033[36m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "|                                             |"
echo -e "|         需要一点时间，请耐心等待！          |"
echo -e "|       \033[0m如长时间没有数据请用ctrl+c退出\033[36m        |"
echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m"
#获取在线yaml文件
yaml=$clashdir/config.yaml
yamlnew=/tmp/config.yaml
rm -rf $yamlnew > /dev/null 2>&1
result=$(curl -w %{http_code} -kLo $yamlnew $Https)
if [ "$result" != "200" ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m配置文件获取失败！\033[0m"
	if [ -z $markhttp ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请尝试使用【导入节点/链接】功能！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		exit 1
		
	else
		read -p "是否更换后端地址后重试？[1/0] > " res
		if [ "$res" = '1' ]; then
			sed -i '/server_link=*/'d $ccfg
			if [[ $server_link -ge 6 ]]; then
				server_link=0
			fi
			server_link=$(($server_link + 1))
			echo $server_link
			sed -i "1i\server_link=$server_link" $ccfg
			Https=""
			getyaml
		fi
	fi
else
	Https=""
	#检测节点
	if [ -z "$(cat $yamlnew | grep ', server:')" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[33m获取到了配置文件，但格式似乎不对！\033[0m"
		echo -----------------------------------------------
		sed -n '1,30p' $yamlnew
		echo -----------------------------------------------
		echo -e "\033[33m请检查如上配置文件信息:\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		exit 1
	fi
	#检测旧格式
	if cat $yamlnew | grep 'Proxy Group:' >/dev/null;then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m已经停止对旧格式配置文件的支持！！！\033[0m"
		echo -e "请使用新格式或者使用【导入节点/链接】功能！"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		exit 1
	fi
	#检测不支持的加密协议
	if cat $yamlnew | grep 'cipher: chacha20,' >/dev/null;then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m不支持chacha20加密，请更换节点加密协议！！！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		exit 1
	fi
	#替换文件
	[ -f $yaml ] && mv $yaml $yaml.bak
	mv $yamlnew $yaml
	echo 配置文件已生成！正在启动clash使其生效！
	#重启clash服务
	$0 stop
	$0 start
	sleep 1
	if [ -z $(pidof clash) ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ -f $yaml.bak ];then
			$clashdir/start.sh stop
			mv $yaml.bak $yaml
			$0 start
			echo -e "\033[31mclash服务启动失败！已还原配置文件并重启clash！\033[0m"
			sleep 1
			[ -n $(pidof clash) ] && exit 0
		fi
		echo -e "\033[31mclash服务启动失败！请查看报错信息！\033[0m"
		$0 stop
		$clashdir/clash -t -d $clashdir
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		exit 1
	fi
fi
}
modify_yaml(){
##########需要变更的配置###########
mix='mixed-port: 7890'
redir='redir-port: 7892'
lan='allow-lan: true'
mode='mode: Rule'
log='log-level: info'
if [ "$ipv6_support" = "已开启" ];then
ipv6='ipv6: true'
else
ipv6='ipv6: false'
fi
external='external-controller: 0.0.0.0:9999'
if [ -d $clashdir/ui ];then
external_ui='external-ui: ui'
else
external_ui='external-ui:'
fi
if [ "$dns_mod" = "fake-ip" ];then
dns='dns: {enable: true, listen: 0.0.0.0:1053, fake-ip-range: 198.18.0.1/16, enhanced-mode: fake-ip, fake-ip-filter: ["*.lan", "time.windows.com", "time.nist.gov", "time.apple.com", "time.asia.apple.com", "*.ntp.org.cn", "*.openwrt.pool.ntp.org", "time1.cloud.tencent.com", "time.ustc.edu.cn", "pool.ntp.org", "ntp.ubuntu.com", "ntp.aliyun.com", "ntp1.aliyun.com", "ntp2.aliyun.com", "ntp3.aliyun.com", "ntp4.aliyun.com", "ntp5.aliyun.com", "ntp6.aliyun.com", "ntp7.aliyun.com", "time1.aliyun.com", "time2.aliyun.com", "time3.aliyun.com", "time4.aliyun.com", "time5.aliyun.com", "time6.aliyun.com", "time7.aliyun.com", "*.time.edu.cn", "time1.apple.com", "time2.apple.com", "time3.apple.com", "time4.apple.com", "time5.apple.com", "time6.apple.com", "time7.apple.com", "time1.google.com", "time2.google.com", "time3.google.com", "time4.google.com", "music.163.com", "*.music.163.com", "*.126.net", "musicapi.taihe.com", "music.taihe.com", "songsearch.kugou.com", "trackercdn.kugou.com", "*.kuwo.cn", "api-jooxtt.sanook.com", "api.joox.com", "joox.com", "y.qq.com", "*.y.qq.com", "streamoc.music.tc.qq.com", "mobileoc.music.tc.qq.com", "isure.stream.qqmusic.qq.com", "dl.stream.qqmusic.qq.com", "aqqmusic.tc.qq.com", "amobile.music.tc.qq.com", "*.xiami.com", "*.music.migu.cn", "music.migu.cn", "*.msftconnecttest.com", "*.msftncsi.com", "localhost.ptlogin2.qq.com", "*.*.*.srv.nintendo.net", "*.*.stun.playstation.net", "xbox.*.*.microsoft.com", "*.*.xboxlive.com", "proxy.golang.org"], nameserver: [114.114.114.114, 127.0.0.1:53], fallback: [tcp://1.0.0.1, 8.8.4.4], fallback-filter: {geoip: true}}'
elif [ "$dns_over" = "已开启" ];then
dns='dns: {enable: true, ipv6: true, listen: 0.0.0.0:1053, enhanced-mode: redir-host, nameserver: [114.114.114.114, 223.5.5.5], fallback: [1.0.0.1, 8.8.4.4], fallback-filter: {geoip: true}}'
else
dns='dns: {enable: true, ipv6: true, listen: 0.0.0.0:1053, enhanced-mode: redir-host, nameserver: [114.114.114.114, 223.5.5.5, 127.0.0.1:53], fallback: [1.0.0.1, 8.8.4.4], fallback-filter: {geoip: true}}'
fi
if [ "$redir_mod" != "Redir模式" ];then
tun='tun: {enable: true, stack: system}'
else
tun='tun: {enable: false}'
fi 
exper='experimental: {ignore-resolve-fail: true, interface-name: en0}'
###################################
	#预删除需要添加的项目
	i=$(grep  -n  "^proxies:" $clashdir/config.yaml | head -1 | cut -d ":" -f 1)
	i=$(($i-1))
	sed -i "1,${i}d" $clashdir/config.yaml
	#添加配置
	sed -i "1i$mix" $clashdir/config.yaml
	sed -i "1a$redir" $clashdir/config.yaml
	sed -i "2a$lan" $clashdir/config.yaml
	sed -i "3a$mode" $clashdir/config.yaml
	sed -i "4a$log" $clashdir/config.yaml
	sed -i "5a$ipv6" $clashdir/config.yaml
	sed -i "6a$external" $clashdir/config.yaml
	sed -i "7a$external_ui" $clashdir/config.yaml
	sed -i "8a$dns" $clashdir/config.yaml
	sed -i "9a$tun" $clashdir/config.yaml
	sed -i "10a$exper" $clashdir/config.yaml
	#跳过本地tls证书验证
	if [ "$skip_cert" = "已开启" ];then
	sed -i '10,99s/skip-cert-verify: false/skip-cert-verify: true/' $clashdir/config.yaml
	else
	sed -i '10,99s/skip-cert-verify: true/skip-cert-verify: false/' $clashdir/config.yaml
	fi
}
mark_time(){
	start_time=`date +%s`
	sed -i '/start_time*/'d $clashdir/mark
	sed -i "1i\start_time=$start_time" $clashdir/mark
}
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
	for mac in $(cat $clashdir/mac); do
		iptables -t nat -A clash -m mac --mac-source $mac -j RETURN
	done
	#设置防火墙流量转发
	iptables -t nat -A clash -p tcp $ports-j REDIRECT --to-ports 7892
	iptables -t nat -A PREROUTING -p tcp -j clash
	#设置ipv6转发
	if [ "$ipv6_support" = "已开启" ];then
		ip6tables -t nat -N clashv6
		for mac in $(cat $clashdir/mac); do
			ip6tables -t nat -A clashv6 -m mac --mac-source $mac -j RETURN
		done
		ip6tables -t nat -A clashv6 -p tcp $ports-j REDIRECT --to-ports 7892
		ip6tables -t nat -A PREROUTING -p tcp -j clashv6
	fi
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
	#重置ipv6规则
	ip6tables -t nat -D PREROUTING -p tcp -j clashv6 > /dev/null 2>&1
	ip6tables -t nat -D PREROUTING -p udp -j clashv6_dns > /dev/null 2>&1
	ip6tables -t nat -F clashv6 > /dev/null 2>&1
	ip6tables -t nat -X clashv6 > /dev/null 2>&1
	ip6tables -t nat -F clashv6_dns > /dev/null 2>&1
	ip6tables -t nat -X clashv6_dns > /dev/null 2>&1
	ip6tables -D FORWARD -o utun -j ACCEPT > /dev/null 2>&1
}
start_dns(){
	#允许tun网卡接受流量
	if [ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ];then
		iptables -I FORWARD -o utun -j ACCEPT
		[ "$ipv6_support" = "已开启" ] && ip6tables -I FORWARD -o utun -j ACCEPT > /dev/null 2>&1
	fi
	#设置dns转发
	iptables -t nat -N clash_dns
	for mac in $(cat $clashdir/mac); do
		iptables -t nat -A clash_dns -m mac --mac-source $mac -j RETURN
	done
	iptables -t nat -A clash_dns -p udp --dport 53 -j REDIRECT --to 1053
	iptables -t nat -A clash_dns -p tcp --dport 53 -j REDIRECT --to 1053
	iptables -t nat -A PREROUTING -p udp -j clash_dns
	#Google home DNS特殊处理
	iptables -t nat -I PREROUTING -p tcp -d 8.8.8.8 -j clash_dns
	iptables -t nat -I PREROUTING -p tcp -d 8.8.4.4 -j clash_dns
	#ipv6DNS
	ip6tables -t nat -N clashv6_dns > /dev/null 2>&1
	for mac in $(cat $clashdir/mac); do
		ip6tables -t nat -A clashv6_dns -m mac --mac-source $mac -j RETURN > /dev/null 2>&1
	done
	ip6tables -t nat -A clashv6_dns -p udp --dport 53 -j REDIRECT --to 1053 > /dev/null 2>&1
	ip6tables -t nat -A PREROUTING -p udp -j clashv6_dns > /dev/null 2>&1
}
checkcron(){
	[ -d /etc/crontabs/ ]&&cronpath="/etc/crontabs/root"
	[ -d /var/spool/cron/ ]&&cronpath="/var/spool/cron/root"
	[ -d /var/spool/cron/crontabs/ ]&&cronpath="/var/spool/cron/crontabs/root"
	[ -z $cronpath ]&&echo "找不到定时任务文件,无法添加定时任务！"
}
daemon(){
	checkcron
	echo '*/1 * * * * test -z "$(pidof clash)"  &&  /etc/init.d/clash restart #clash守护进程' >> $cronpath
	chmod 600 $cronpath
}
afstart(){
	#读取配置文件
	getconfig
	#修改iptables规则使流量进入clash
	stop_iptables
	[ "$redir_mod" != "纯净模式" ] && start_dns
	[ "$redir_mod" != "纯净模式" ] && [ "$redir_mod" != "Tun模式" ] && start_redir
	#标记启动时间
	mark_time
}

case "$1" in

afstart)
		afstart
	;;
start)		
		#读取配置文件
		getconfig
		#检测系统端口占用
		for portx in 1053 7890 7892 9999 ;do
			[ -n "$(netstat -ntul |grep :$portx)" ] && echo "检测到端口【$portx】被以下进程占用！clash无法启动！" && echo $(netstat -ntulp |grep :$portx) && exit 1
		done
		#使用内置规则强行覆盖config配置文件
		[ "$modify_yaml" != "已开启" ] && modify_yaml
		#使用不同方式启动clash服务
		if [ "$start_old" = "已开启" ];then
			$clashdir/clash -d $clashdir >/dev/null 2>&1 &
			daemon
			afstart
		elif [ -f /etc/rc.common ];then
			/etc/init.d/clash start
		else
			systemctl start clash.service
		fi
	;;
stop)	
		#删除守护
		checkcron
		sed -i /clash守护进程/d $cronpath >/dev/null 2>&1
		#多种方式结束进程
		if [ -f /etc/rc.common ];then
			/etc/init.d/clash stop >/dev/null 2>&1
		else
			systemctl stop clash.service >/dev/null 2>&1
		fi
		killall -9 clash >/dev/null 2>&1
		#清理iptables
		stop_iptables
        ;;
restart)
        $0 stop
        $0 start
        ;;
getyaml)	
		getconfig
		getyaml
		;;
daemon)	
		daemon
		;;
esac
