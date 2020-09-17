 #!/bin/sh
# Copyright (C) Juewuy

getconfig(){
ccfg=$clashdir/mark
if [ ! -f "$ccfg" ]; then
	echo mark文件不存在，默认以Redir模式运行！
cat >$ccfg<<EOF
#标识clash运行状态的文件，不明勿动！
EOF
	#指定一些默认状态
	redir_mod=redir模式
	modify_yaml=未开启
fi
source $ccfg #加载配置文件
#是否代理常用端口
[ "$common_ports" = "已开启" ] && ports='-m multiport --dports 22,53,587,465,995,993,143,80,443 '
#检测系统端口占用
for portx in 1053 7890 7892 9999 ;do
	[ -n "$(netstat -ntulp |grep :$portx|grep -v clash)" ] && echo -e "检测到端口：\033[30;47m $portx \033[0m被以下进程占用！clash无法启动！" && echo $(netstat -ntulp |grep :$portx) && exit;
done
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
dns='dns: {enable: true, listen: 0.0.0.0:1053, fake-ip-range: 198.18.0.1/16, enhanced-mode: fake-ip, nameserver: [114.114.114.114, 127.0.0.1:53], fallback: [tcp://1.0.0.1, 8.8.4.4]}'
elif [ "$dns_over" = "已开启" ];then
dns='dns: {enable: true, ipv6: true, listen: 0.0.0.0:1053, enhanced-mode: redir-host, nameserver: [114.114.114.114, 223.5.5.5], fallback: [1.0.0.1, 8.8.4.4]}'
else
dns='dns: {enable: true, ipv6: true, listen: 0.0.0.0:1053, enhanced-mode: redir-host, nameserver: [114.114.114.114, 223.5.5.5, 127.0.0.1:53], fallback: [1.0.0.1, 8.8.4.4]}'
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
	sed -i '1,'$i'd' $clashdir/config.yaml
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
	sed -i "3i\start_time=$start_time" $clashdir/mark
}
start_redir(){
	#修改iptables规则使流量进入clash
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
	
	iptables -t nat -A clash -p tcp $ports-j REDIRECT --to-ports 7892
	iptables -t nat -A PREROUTING -p tcp -j clash
	if [ "$ipv6_support" = "已开启" ];then
		ip6tables -t nat -N clash
		for mac in $(cat $clashdir/mac); do
			ip6tables -t nat -A clash -m mac --mac-source $mac -j RETURN
		done
		ip6tables -t nat -A clash -p tcp $ports-j REDIRECT --to-ports 7892
		ip6tables -t nat -A PREROUTING -p tcp -j clash
	fi
}
stop_iptables(){
    #重置iptables规则
	iptables -t nat -D PREROUTING -p tcp -j clash > /dev/null 2>&1
	iptables -t nat -D PREROUTING -p udp -j clash_dns > /dev/null 2>&1
	iptables -t nat -F clash > /dev/null 2>&1
	iptables -t nat -X clash > /dev/null 2>&1
	iptables -t nat -F clash_dns > /dev/null 2>&1
	iptables -t nat -X clash_dns > /dev/null 2>&1
	#重置ipv6规则
	ip6tables -t nat -D PREROUTING -p tcp -j clash > /dev/null 2>&1
	ip6tables -t nat -D PREROUTING -p udp -j clash_dns > /dev/null 2>&1
	ip6tables -t nat -F clash > /dev/null 2>&1
	ip6tables -t nat -X clash > /dev/null 2>&1
	ip6tables -t nat -F clash_dns > /dev/null 2>&1
	ip6tables -t nat -X clash_dns > /dev/null 2>&1
}
start_dns(){
	#允许tun网卡接受流量
	iptables -I FORWARD -o utun -j ACCEPT
	ip6tables -I FORWARD -o utun -j ACCEPT > /dev/null 2>&1
	#设置dns转发
	iptables -t nat -N clash_dns
	for mac in $(cat $clashdir/mac); do
		iptables -t nat -A clash_dns -m mac --mac-source $mac -j RETURN
	done
	iptables -t nat -A clash_dns -p udp --dport 53 -j REDIRECT --to 1053
	iptables -t nat -A PREROUTING -p udp -j clash_dns
	#ipv6DNS
	ip6tables -t nat -N clash_dns > /dev/null 2>&1
	for mac in $(cat $clashdir/mac); do
		ip6tables -t nat -A clash_dns -m mac --mac-source $mac -j RETURN > /dev/null 2>&1
	done
	ip6tables -t nat -A clash_dns -p udp --dport 53 -j REDIRECT --to 1053 > /dev/null 2>&1
	ip6tables -t nat -A PREROUTING -p udp -j clash_dns > /dev/null 2>&1
}
daemon_old(){
	#守护进程状态
	status=$(ps |grep -w 'clash'|grep -v grep|grep -v clash.sh)
	if [ -z $status ];then
	$clashdir/clash -d $clashdir> /dev/null &
	mark_time
	fi
}
checkcron(){
	[ -d /etc/crontabs/ ]&&cronpath="/etc/crontabs/root"
	[ -d /var/spool/cron/ ]&&cronpath="/var/spool/cron/root"
	[ -d /var/spool/cron/crontabs/ ]&&cronpath="/var/spool/cron/crontabs/root"
	if [ -z $cronpath ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo "找不到定时任务文件,无法添加定时任务！"
		clashsh
	fi
}
start_old(){
	#读取配置文件
	getconfig
	#使用内置规则强行覆盖config配置文件
	[ "$modify_yaml" != "已开启" ] && modify_yaml
    #创建clash后台进程
	$clashdir/clash -d $clashdir> /dev/null &
	#修改iptables规则使流量进入clash
	stop_iptables
	[ "$redir_mod" != "纯净模式" ] && start_dns
	[ "$redir_mod" != "纯净模式" ] && [ "$redir_mod" != "Tun模式" ] && start_redir
	#标记启动时间
	mark_time
	#创建守护进程
	checkcron
	sed -i /start.sh/d $cronpath
	echo "*/1 * * * * source /etc/profile && source $clashdir/start.sh && daemon_old >/dev/null 2>&1" >> $cronpath
	#设定启动方式
	sed -i /start_old=*/d $ccfg
	sed -i "1i\start_old=已开启" $ccfg	
}
stop_old(){
	#删除守护
	checkcron
	sed -i /start.sh/d $cronpath
	#结束进程
	killall -9 clash &> /dev/null
	stop_iptables
}
start(){
	getconfig
	if [ "$start_old" ="已开启" ];then
		start_old
	else
		/etc/init.d/clash start
	fi
}
stop(){
	getconfig
	if [ "$start_old" ="已开启" ];then
		stop_old
	else
		/etc/init.d/clash stop
	fi
}
restart(){
	stop
	start
}