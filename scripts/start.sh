#!/bin/sh
# Copyright (C) Juewuy

#脚本内部工具
getconfig(){
	#加载配置文件
	[ -d "/etc/storage/clash" ] && clashdir=/etc/storage/clash
	[ -d "/jffs/clash" ] && clashdir=/jffs/clash
	[ -z "$clashdir" ] && clashdir=$(cat /etc/profile | grep clashdir | awk -F "\"" '{print $2}')
	[ -z "$clashdir" ] && clashdir=$(cat ~/.bashrc | grep clashdir | awk -F "\"" '{print $2}')
	ccfg=$clashdir/mark
	[ -f $ccfg ] && source $ccfg
	#默认设置
	[ -z "$bindir" ] && bindir=$clashdir
	[ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod=Redir模式
	[ -z "$redir_mod" ] && redir_mod=纯净模式
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ -z "$dns_mod" ] && dns_mod=redir_host
	[ -z "$ipv6_support" ] && ipv6_support=已开启
	[ -z "$ipv6_redir" ] && ipv6_redir=未开启
	[ -z "$ipv6_dns" ] && ipv6_dns=已开启
	[ -z "$cn_ipv6_route" ] && cn_ipv6_route=未开启
	[ -z "$mix_port" ] && mix_port=7890
	[ -z "$redir_port" ] && redir_port=7892
	[ -z "$tproxy_port" ] && tproxy_port=7893
	[ -z "$db_port" ] && db_port=9999
	[ -z "$dns_port" ] && dns_port=1053
	[ -z "$sniffer" ] && sniffer=已开启
	#是否代理常用端口
	[ -z "$common_ports" ] && common_ports=已开启
	[ -z "$multiport" ] && multiport='22,53,80,123,143,194,443,465,587,853,993,995,5222,8080,8443'
	[ "$common_ports" = "已开启" ] && ports="-m multiport --dports $multiport"
}
setconfig(){
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath=$clashdir/mark || configpath=$3
	[ -n "$(grep ${1} $configpath)" ] && sed -i "s#${1}=.*#${1}=${2}#g" $configpath || echo "${1}=${2}" >> $configpath
}
ckcmd(){
	command -v sh &>/dev/null && command -v $1 &>/dev/null || type $1 &>/dev/null
}
compare(){
	if [ ! -f $1 -o ! -f $2 ];then
		return 1
	elif ckcmd cmp;then
		cmp -s $1 $2
	else
		[ "$(cat $1)" = "$(cat $2)" ] && return 0 || return 1
	fi
}
logger(){
	#$1文字描述$2显示颜色$3是否推送
	[ -n "$2" ] && echo -e "\033[$2m$1\033[0m"
	log_text="$(date "+%G-%m-%d_%H:%M:%S")~$1"
	echo $log_text >> /tmp/ShellClash_log
	[ "$(wc -l /tmp/ShellClash_log | awk '{print $1}')" -gt 99 ] && sed -i '1,5d' /tmp/ShellClash_log
	[ -z "$3" ] && {
		getconfig
		[ -n "$(pidof clash)" ] && {
			[ -n "$authentication" ] && auth="$authentication@"
			export https_proxy="http://${auth}127.0.0.1:$mix_port"
		}
		[ -n "$push_TG" ] && {
			url=https://api.telegram.org/bot${push_TG}/sendMessage
			curl_data="-d chat_id=$chat_ID&text=$log_text"
			wget_data="--post-data=$chat_ID&text=$log_text"
			if curl --version &> /dev/null;then 
				curl -kfsSl --connect-timeout 3 -d "chat_id=$chat_ID&text=$log_text" "$url" &>/dev/null 
			else
				wget -Y on -q --timeout=3 -t 1 --post-data="chat_id=$chat_ID&text=$log_text" "$url" 
			fi
		}
		[ -n "$push_bark" ] && {
			url=${push_bark}/${log_text}
			if curl --version &> /dev/null;then 
				curl -kfsSl --connect-timeout 3 "$url" &>/dev/null 
			else
				wget -Y on -q --timeout=3 -t 1 "$url" 
			fi
		}
		[ -n "$push_Deer" ] && {
			url=https://api2.pushdeer.com/message/push?pushkey=${push_Deer}
			if curl --version &> /dev/null;then 
				curl -kfsSl --connect-timeout 3 "$url"\&text="$log_text" &>/dev/null 
			else
				wget -Y on -q --timeout=3 -t 1 "$url"\&text="$log_text" 
			fi
		}
		[ -n "$push_Po" ] && {
			url=https://api.pushover.net/1/messages.json
			curl -kfsSl --connect-timeout 3 --form-string "token=$push_Po" --form-string "user=$push_Po_key" --form-string "message=$log_text" "$url" &>/dev/null 
		}	
	} &
}
croncmd(){
	if [ -n "$(crontab -h 2>&1 | grep '\-l')" ];then
		crontab $1
	else
		crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}')"
		[ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
		[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
		[ ! -w "$crondir" ] && crondir="/var/spool/cron"
		[ ! -w "$crondir" ] && echo "你的设备不支持定时任务配置，脚本大量功能无法启用，请前往 https://t.me/clashfm 申请适配！"
		[ "$1" = "-l" ] && cat $crondir/$USER 2>/dev/null
		[ -f "$1" ] && cat $1 > $crondir/$USER
	fi
}
cronset(){
	# 参数1代表要移除的关键字,参数2代表要添加的任务语句
	tmpcron=/tmp/cron_$USER
	croncmd -l > $tmpcron 
	sed -i "/$1/d" $tmpcron
	sed -i '/^$/d' $tmpcron
	echo "$2" >> $tmpcron
	croncmd $tmpcron
	rm -f $tmpcron
}
put_save(){
	if curl --version > /dev/null 2>&1;then
		curl -sS -X PUT -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1" -d "$2" >/dev/null
	elif wget --version > /dev/null 2>&1;then
		wget -q --method=PUT --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" --body-data="$2" "$1" >/dev/null
	fi
}
mark_time(){
	echo `date +%s` > /tmp/clash_start_time
}
autoSSH(){
	#自动开启SSH
	[ "$(nvram get ssh_en)" = 0 ] && nvram set ssh_en=1 && nvram commit
    [ "`uci -c /usr/share/xiaoqiang get xiaoqiang_version.version.CHANNEL`" != 'stable' ] && {
	uci -c /usr/share/xiaoqiang set xiaoqiang_version.version.CHANNEL='stable' 
    uci -c /usr/share/xiaoqiang commit xiaoqiang_version.version
	}
	[ -z "$(pidof dropbear)" -o -z "$(netstat -ntul | grep :22)" ] && {
	sed -i 's/channel=.*/channel="debug"/g' /etc/init.d/dropbear
	/etc/init.d/dropbear restart
	[ -n "$mi_autoSSH_pwd" ] && echo -e "$mi_autoSSH_pwd\n$mi_autoSSH_pwd" | passwd root
	}
	#备份还原SSH秘钥
	[ -f $clashdir/dropbear_rsa_host_key ] && ln -sf $clashdir/dropbear_rsa_host_key /etc/dropbear/dropbear_rsa_host_key
	[ -f $clashdir/authorized_keys ] && ln -sf $clashdir/authorized_keys /etc/dropbear/authorized_keys
}
host_lan(){
	[ -n "$(echo $host | grep -oE "([0-9]{1,3}[\.]){3}[0-9]{1,3}" )" ] && host_lan="$(echo $host | grep -oE "([0-9]{1,3}[\.]){3}")0/24"
}
#配置文件相关
getyaml(){
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	#前后端订阅服务器地址索引，可在此处添加！
	Server=`sed -n ""$server_link"p"<<EOF
https://api.dler.io
https://api.v1.mk
https://sub.xeton.dev
https://v.id9.cc
https://sub.maoxiongnet.com
http://sub2.jwsc.eu.org
EOF`
	Config=`sed -n ""$rule_link"p"<<EOF
https://github.com/juewuy/ShellClash/raw/master/rules/ShellClash.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ShellClash_Mini.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ShellClash_Block.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ShellClash_Nano.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ShellClash_Full.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ShellClash_Full_Block.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/lhie1_clash.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/lhie1_dler.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/connershua_pro.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/connershua_backtocn.ini
https://gist.githubusercontent.com/tindy2013/1fa08640a9088ac8652dbd40c5d2715b/raw/dlercloud_lige_platinum.ini
https://subconverter.oss-ap-southeast-1.aliyuncs.com/Rules/RemoteConfig/special/basic.ini
https://subconverter.oss-ap-southeast-1.aliyuncs.com/Rules/RemoteConfig/special/netease.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Full_Google.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ACL4SSR_Online_Games.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ACL4SSR_Online_Mini_Games.ini
https://github.com/juewuy/ShellClash/raw/master/rules/ACL4SSR_Online_Full_Games.ini
EOF`
	Https=$(echo ${Https//\%26/\&})   #将%26替换回&
	#如果传来的是Url链接则合成Https链接，否则直接使用Https链接
	if [ -z "$Https" -a -z "$retry" ];then
		[ -n "$(echo $Url | grep -oE 'vless:')" ] && Server='https://api.v1.mk'
		[ -n "$(echo $Url | grep -oE 'hysteria:')" ] && Server='https://sub.jwsc.eu.org'
		Https="$Server/sub?target=clash&insert=true&new_name=true&scv=true&udp=true&exclude=$exclude&include=$include&url=$Url&config=$Config"
		url_type=true
	fi
	#输出
	echo -----------------------------------------------
	logger 正在连接服务器获取配置文件…………
	echo -e "链接地址为：\033[4;32m$Https\033[0m"
	echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
	#获取在线yaml文件
	yaml=$clashdir/config.yaml
	yamlnew=/tmp/clash_config_$USER.yaml
	rm -rf $yamlnew
	$0 webget $yamlnew $Https
	if [ "$?" = "1" ];then
		if [ -z "$url_type" ];then
			echo -----------------------------------------------
			logger "配置文件获取失败！" 31
			echo -e "\033[31m请尝试使用【在线生成配置文件】功能！\033[0m"
			echo -----------------------------------------------
			exit 1
		else
			if [ "$retry" -ge 4 ];then
				logger "无法获取配置文件，请检查链接格式以及网络连接状态！" 31
				exit 1
			elif [ "$retry" = 3 ];then
				retry=4
				logger "配置文件获取失败！最后尝试使用http备用服务器获取！" 31
				echo -e "\033[32m如担心安全性，请在5s内使用【ctrl+c】退出！\033[0m"
				sleep 5
				server_link=6
				setconfig server_link 6
				Https=""
				getyaml
			else
				retry=$((retry+1))
				logger "配置文件获取失败！" 31
				echo -e "\033[32m尝试使用其他服务器获取配置！\033[0m"
				logger "正在重试第$retry次/共4次！" 33
				sed -i '/server_link=*/'d $ccfg
				if [ "$server_link" -ge 5 ]; then
					server_link=0
				fi
				server_link=$((server_link+1))
				setconfig server_link $server_link
				Https=""
				getyaml
			fi
		fi
	else
		Https=""
		#检测节点或providers
		if [ -z "$(cat $yamlnew | grep -E 'server|proxy-providers' | grep -v 'nameserver' | head -n 1)" ];then
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
			echo -e "请使用新格式或者使用【在线生成配置文件】功能！"
			echo -----------------------------------------------
			exit 1
		fi
		#检测不支持的加密协议
		if cat $yamlnew | grep 'cipher: chacha20,' >/dev/null;then
			echo -----------------------------------------------
			logger "已停止支持chacha20加密，请更换更安全的节点加密协议！" 31
			echo -----------------------------------------------
			exit 1
		fi
		#检测并去除无效节点组
		[ -n "$url_type" ] && ckcmd xargs && {
			cat $yamlnew | grep -A 8 "\- name:" | xargs | sed 's/- name: /\n/g' | sed 's/ type: .*proxies: /#/g' | sed 's/ rules:.*//g' | sed 's/- //g' | grep -E '#DIRECT $' | awk -F '#' '{print $1}' > /tmp/clash_proxies_$USER
			while read line ;do
				sed -i "/- $line/d" $yamlnew
				sed -i "/- name: $line/,/- DIRECT/d" $yamlnew
			done < /tmp/clash_proxies_$USER
			rm -rf /tmp/clash_proxies_$USER
		}
		#使用核心内置test功能检测
		if [ -x $bindir/clash ];then
			$bindir/clash -t -d $bindir -f $yamlnew >/dev/null
			if [ "$?" != "0" ];then
				logger "配置文件加载失败！请查看报错信息！" 31
				$bindir/clash -t -d $bindir -f $yamlnew
				echo "$($bindir/clash -t -d $bindir -f $yamlnew)" >> $clashdir/log
				exit 1
			fi
		fi
		#如果不同则备份并替换文件
		if [ -f $yaml ];then
			compare $yamlnew $yaml
			[ "$?" = 0 ] || mv -f $yaml $yaml.bak && mv -f $yamlnew $yaml
		else
			mv -f $yamlnew $yaml
		fi
		echo -e "\033[32m已成功获取配置文件！\033[0m"
	fi
}
modify_yaml(){
##########需要变更的配置###########
	[ -z "$dns_nameserver" ] && dns_nameserver='114.114.114.114, 223.5.5.5'
	[ -z "$dns_fallback" ] && dns_fallback='1.0.0.1, 8.8.4.4'
	[ -z "$skip_cert" ] && skip_cert=已开启
	#默认fake-ip过滤列表
	fake_ft_df='"*.lan", "time.windows.com", "time.nist.gov", "time.apple.com", "time.asia.apple.com", "*.ntp.org.cn", "*.openwrt.pool.ntp.org", "time1.cloud.tencent.com", "time.ustc.edu.cn", "pool.ntp.org", "ntp.ubuntu.com", "ntp.aliyun.com", "ntp1.aliyun.com", "ntp2.aliyun.com", "ntp3.aliyun.com", "ntp4.aliyun.com", "ntp5.aliyun.com", "ntp6.aliyun.com", "ntp7.aliyun.com", "time1.aliyun.com", "time2.aliyun.com", "time3.aliyun.com", "time4.aliyun.com", "time5.aliyun.com", "time6.aliyun.com", "time7.aliyun.com", "*.time.edu.cn", "time1.apple.com", "time2.apple.com", "time3.apple.com", "time4.apple.com", "time5.apple.com", "time6.apple.com", "time7.apple.com", "time1.google.com", "time2.google.com", "time3.google.com", "time4.google.com", "music.163.com", "*.music.163.com", "*.126.net", "musicapi.taihe.com", "music.taihe.com", "songsearch.kugou.com", "trackercdn.kugou.com", "*.kuwo.cn", "api-jooxtt.sanook.com", "api.joox.com", "joox.com", "y.qq.com", "*.y.qq.com", "streamoc.music.tc.qq.com", "mobileoc.music.tc.qq.com", "isure.stream.qqmusic.qq.com", "dl.stream.qqmusic.qq.com", "aqqmusic.tc.qq.com", "amobile.music.tc.qq.com", "*.xiami.com", "*.music.migu.cn", "music.migu.cn", "*.msftconnecttest.com", "*.msftncsi.com", "localhost.ptlogin2.qq.com", "*.*.*.srv.nintendo.net", "*.*.stun.playstation.net", "xbox.*.*.microsoft.com", "*.*.xboxlive.com", "proxy.golang.org","*.sgcc.com.cn","*.alicdn.com","*.aliyuncs.com"'
	lan='allow-lan: true'
	log='log-level: info'
	[ "$ipv6_support" = "已开启" ] && ipv6='ipv6: true' || ipv6='ipv6: false'
	[ "$ipv6_dns" = "已开启" ] && dns_v6='ipv6: true' || dns_v6='ipv6: false'
	external="external-controller: 0.0.0.0:$db_port"
	[ -d $clashdir/ui ] && db_ui=ui
	if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ];then
		[ "$clashcore" = 'clash.meta' ] && tun_meta=', device: utun, auto-route: false'
		tun="tun: {enable: true, stack: system$tun_meta}"
	else
		tun='tun: {enable: false}'
	fi
	exper='experimental: {ignore-resolve-fail: true, interface-name: en0}'
	#dns配置
	[ -z "$(cat $clashdir/user.yaml 2>/dev/null | grep '^dns:')" ] && { 
		[ "$clashcore" = 'clash.meta' ] && dns_default_meta=', https://1.0.0.1/dns-query, https://223.5.5.5/dns-query'
		dns_default="114.114.114.114, 223.5.5.5$dns_default_meta"
		if [ -f $clashdir/fake_ip_filter ];then
			while read line;do
				fake_ft_ad=$fake_ft_ad,\"$line\"
			done < $clashdir/fake_ip_filter
		fi
		if [ "$dns_mod" = "fake-ip" ];then
			dns='dns: {enable: true, '$dns_v6', listen: 0.0.0.0:'$dns_port', use-hosts: true, fake-ip-range: 198.18.0.1/16, enhanced-mode: fake-ip, fake-ip-filter: ['${fake_ft_df}${fake_ft_ad}'], default-nameserver: ['$dns_default', 127.0.0.1:53], nameserver: ['$dns_nameserver', 127.0.0.1:53], fallback: ['$dns_fallback'], fallback-filter: {geoip: true}}'
		else
			dns='dns: {enable: true, '$dns_v6', listen: 0.0.0.0:'$dns_port', use-hosts: true, enhanced-mode: redir-host, default-nameserver: ['$dns_default', 127.0.0.1:53], nameserver: ['$dns_nameserver$dns_local'], fallback: ['$dns_fallback'], fallback-filter: {geoip: true}}'
		fi
	}
	#域名嗅探配置
	[ "$sniffer" = "已启用" ] && [ "$clashcore" = "clash.meta" ] && sniffer_set="sniffer: {enable: true, sniffing: [tls, http]}"
	[ "$clashcore" = "clashpre" ] && [ "$dns_mod" = "redir_host" ] && exper="experimental: {ignore-resolve-fail: true, interface-name: en0, sniff-tls-sni: true}"
	
	#设置目录
	yaml=$clashdir/config.yaml
	tmpdir=/tmp/clash_$USER
	#预读取变量
	mode=$(grep "^mode" $yaml | head -1 | awk '{print $2}')
	[ -z "$mode" ] && mode='Rule'
	#分割配置文件
	mkdir -p $tmpdir > /dev/null
	yaml_p=$(grep -n "^prox" $yaml | head -1 | cut -d ":" -f 1) #获取节点起始行号
	yaml_r=$(grep -n "^rules:" $yaml | head -1 | cut -d ":" -f 1) #获取规则起始行号
	if [ "$yaml_p" -lt "$yaml_r" ];then
		sed -n "${yaml_p},${yaml_r}p" $yaml > $tmpdir/proxy.yaml
		cat $yaml | sed -n "${yaml_r},\$p" | sed '1d' | sed 's/^ *-/ -/g' > $tmpdir/rule.yaml #切割rule并对齐
	else
		cat $yaml | sed -n "${yaml_r},${yaml_p}p" | sed '1d' | sed '$d' | sed 's/^ *-/ -/g' > $tmpdir/rule.yaml #切割rule并对齐
		sed -n "${yaml_p},\$p" $yaml > $tmpdir/proxy.yaml
		sed -n "${yaml_r}p" $yaml >> $tmpdir/proxy.yaml #将rule字段附在末尾
	fi
	#跳过本地tls证书验证
	[ "$skip_cert" = "已开启" ] && sed -i 's/skip-cert-verify: false/skip-cert-verify: true/' $tmpdir/proxy.yaml
	#节点绕过功能支持
	sed -i "/#节点绕过/d" $tmpdir/rule.yaml
	[ "$proxies_bypass" = "已启用" ] && {
		cat /tmp/clash_$USER/proxy.yaml | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | awk '!a[$0]++' | sed 's/^/\ -\ IP-CIDR,/g' | sed 's|$|/32,DIRECT #节点绕过|g' >> $tmpdir/proxies_bypass
		cat /tmp/clash_$USER/proxy.yaml | grep -vE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?'| awk '!a[$0]++' | sed 's/^/\ -\ DOMAIN,/g' | sed 's/$/,DIRECT #节点绕过/g' >> $tmpdir/proxies_bypass
		cat $tmpdir/rule.yaml >> $tmpdir/proxies_bypass 
		mv -f $tmpdir/proxies_bypass $tmpdir/rule.yaml
	}
	#插入自定义规则
	sed -i "/#自定义规则/d" $tmpdir/rule.yaml
	[ -f $clashdir/rules.yaml ] && {
		cat $clashdir/rules.yaml | sed 's/^ *-/ -/g' | sed "/^#/d" | sed '$a\' | sed 's/$/ #自定义规则/g' > $tmpdir/rules.yaml
		cat $tmpdir/rule.yaml >> $tmpdir/rules.yaml
		mv -f $tmpdir/rules.yaml $tmpdir/rule.yaml
	}
	#添加配置
###################################
	cat > $tmpdir/set.yaml <<EOF
mixed-port: $mix_port
redir-port: $redir_port
tproxy-port: $tproxy_port
authentication: ["$authentication"]
$lan
mode: $mode
$log
$ipv6
external-controller: :$db_port
external-ui: $db_ui
secret: $secret
$tun
$exper
$dns
$sniffer_set
store-selected: $restore
EOF
###################################
	#读取本机hosts并生成配置文件
	if [ "$hosts_opt" != "未启用" ] && [ -z "$(grep -E '^hosts:' $clashdir/user.yaml 2>/dev/null)" ];then
		#NTP劫持
		cat >> $tmpdir/hosts.yaml <<EOF
hosts:
   'time.android.com': 203.107.6.88
   'time.facebook.com': 203.107.6.88  
EOF
		while read line;do
			[ -n "$(echo "$line" | grep -oE "([0-9]{1,3}[\.]){3}" )" ] && \
			[ -z "$(echo "$line" | grep -oE '^#')" ] && \
			hosts_ip=$(echo $line | awk '{print $1}')  && \
			hosts_domain=$(echo $line | awk '{print $2}') && \
			[ -z "$(cat $tmpdir/hosts.yaml | grep -oE "$hosts_domain")" ] && \
			echo "   '$hosts_domain': $hosts_ip" >> $tmpdir/hosts.yaml
		done < /etc/hosts
	fi
	#合并文件
	[ -f $clashdir/user.yaml ] && yaml_user=$clashdir/user.yaml
	[ -f $tmpdir/hosts.yaml ] && yaml_hosts=$tmpdir/hosts.yaml
	[ -f $tmpdir/proxy.yaml ] && yaml_proxy=$tmpdir/proxy.yaml
	[ -f $tmpdir/rule.yaml ] && yaml_rule=$tmpdir/rule.yaml
	cut -c 1- $tmpdir/set.yaml $yaml_hosts $yaml_user $yaml_proxy $yaml_rule > $tmpdir/config.yaml


	#插入自定义代理
	sed -i "/#自定义代理/d" $tmpdir/config.yaml
	space=$(sed -n '/^proxies:/{n;p}' $tmpdir/config.yaml | grep -oE '^ *') #获取空格数
	if [ -f $clashdir/proxies.yaml ];then
		sed -i '/^$/d' $clashdir/proxies.yaml && echo >> $clashdir/proxies.yaml #处理换行
		while read line;do
			[ -z "$(echo "$line" | grep '^proxies:')" ] && \
			[ -z "$(echo "$line" | grep '#')" ] && \
			[ -n "$(echo "$line" | grep '\- ')" ] && \
			line=$(echo "$line" | sed 's#/#\\/#') && \
			sed -i "/^proxies:/a\\$space$line #自定义代理" $tmpdir/config.yaml
		done < $clashdir/proxies.yaml
	fi

	#插入自定义策略组
	sed -i "/#自定义策略组/d" $tmpdir/config.yaml
	space=$(sed -n '/^proxy-groups:/{n;p}' $tmpdir/config.yaml | grep -oE '^ *') #获取原始配置空格数
	if [ -f $clashdir/proxy-groups.yaml ];then
		c_space=$(sed -n '/^proxy-groups:/{n;p}' $clashdir/proxy-groups.yaml | grep -oE '^ *') #获取自定义配置空格数
		[ -n "$c_space" ] && sed -i "s/$c_space/$space/g" $clashdir/proxy-groups.yaml && echo >> $clashdir/proxy-groups.yaml #处理缩进空格数
		sed -i '/^$/d' $clashdir/proxy-groups.yaml && echo >> $clashdir/proxy-groups.yaml #处理换行
		cat $clashdir/proxy-groups.yaml | awk '{array[NR]=$0} END { for(i=NR;i>0;i--){print array[i];} }' | while IFS= read line;do
			[ -z "$(echo "$line" | grep '^proxy-groups:')" ] && \
			[ -n "${line// /}" ] && \
			[ -z "$(echo "$line" | grep '#')" ] && \
			line=$(echo "$line" | sed 's#/#\\/#') && \
			sed -i "/^proxy-groups:/a\\$line #自定义策略组" $tmpdir/config.yaml
		done
	fi
	#如果没有使用小闪存模式
	if [ "$tmpdir" != "$bindir" ];then
		cmp -s $tmpdir/config.yaml $yaml >/dev/null 2>&1
		[ "$?" != 0 ] && mv -f $tmpdir/config.yaml $yaml || rm -f $tmpdir/config.yaml
	fi
	rm -f $tmpdir/set.yaml
	rm -f $tmpdir/proxy.yaml
	rm -f $tmpdir/hosts.yaml
	rm -f $tmpdir/rule.yaml
}
#设置路由规则
cn_ip_route(){	
	[ ! -f $bindir/cn_ip.txt ] && {
		if [ -f $clashdir/cn_ip.txt ];then
			mv $clashdir/cn_ip.txt $bindir/cn_ip.txt
		else
			logger "未找到cn_ip列表，正在下载！" 33
			$0 webget $bindir/cn_ip.txt "$update_url/bin/china_ip_list.txt"
			[ "$?" = "1" ] && rm -rf $bindir/cn_ip.txt && logger "列表下载失败！" 31 
		fi
	}
	[ -f $bindir/cn_ip.txt -a -z "$(echo $redir_mod|grep 'Nft')" ] && {
			echo "create cn_ip hash:net family inet hashsize 1024 maxelem 65536" > /tmp/cn_$USER.ipset
			awk '!/^$/&&!/^#/{printf("add cn_ip %s'" "'\n",$0)}' $bindir/cn_ip.txt >> /tmp/cn_$USER.ipset
			ipset -! flush cn_ip 2>/dev/null
			ipset -! restore < /tmp/cn_$USER.ipset 
			rm -rf cn_$USER.ipset
	}
}
cn_ipv6_route(){
	[ ! -f $bindir/cn_ipv6.txt ] && {
		if [ -f $clashdir/cn_ipv6.txt ];then
			mv $clashdir/cn_ipv6.txt $bindir/cn_ipv6.txt
		else
			logger "未找到cn_ipv6列表，正在下载！" 33
			$0 webget $bindir/cn_ipv6.txt "$update_url/bin/china_ipv6_list.txt"
			[ "$?" = "1" ] && rm -rf $bindir/cn_ipv6.txt && logger "列表下载失败！" 31 
		fi
	}
	[ -f $bindir/cn_ipv6.txt -a -z "$(echo $redir_mod|grep 'Nft')" ] && {
			#ipv6
			echo "create cn_ip6 hash:net family inet6 hashsize 1024 maxelem 65536" > /tmp/cn6_$USER.ipset
			awk '!/^$/&&!/^#/{printf("add cn_ip6 %s'" "'\n",$0)}' $bindir/cn_ipv6.txt >> /tmp/cn6_$USER.ipset
			ipset -! flush cn_ip6 2>/dev/null
			ipset -! restore < /tmp/cn6_$USER.ipset 
			rm -rf cn6_$USER.ipset
	}
}
start_redir(){
	#获取局域网host地址
	host_lan
	#流量过滤规则
	iptables -t nat -N clash
	iptables -t nat -A clash -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A clash -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A clash -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A clash -d 100.64.0.0/10 -j RETURN
	iptables -t nat -A clash -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A clash -d 172.16.0.0/12 -j RETURN
	iptables -t nat -A clash -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A clash -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A clash -d 240.0.0.0/4 -j RETURN
	[ -n "$host_lan" ] && iptables -t nat -A clash -d $host_lan -j RETURN
	#绕过CN_IP
	[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && iptables -t nat -A clash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
	[ "$dns_mod" = "fake-ip" ] && iptables -t nat -A clash -s 198.18.0.0/16 -j RETURN
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
		#mac白名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash -p tcp -m mac --mac-source $mac -j REDIRECT --to-ports $redir_port
		done
	else
		#mac黑名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash -m mac --mac-source $mac -j RETURN
		done
		iptables -t nat -A clash -p tcp -s 192.168.0.0/16 -j REDIRECT --to-ports $redir_port
		iptables -t nat -A clash -p tcp -s 10.0.0.0/8 -j REDIRECT --to-ports $redir_port
		[ -n "$host_lan" ] && iptables -t nat -A clash -p tcp -s $host_lan -j REDIRECT --to-ports $redir_port
	fi
	#将PREROUTING链指向clash链
	iptables -t nat -A PREROUTING -p tcp $ports -j clash
	#设置ipv6转发
	if [ "$ipv6_redir" = "已开启" -a -n "$(lsmod | grep 'ip6table_nat')" ];then
		
		ip6tables -t nat -N clashv6
		ip6tables -t nat -A clashv6 -d ::1/128 -j RETURN
		ip6tables -t nat -A clashv6 -d fc00::/7 -j RETURN
		ip6tables -t nat -A clashv6 -d fe80::/10 -j RETURN
		[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && ip6tables -t nat -A clashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
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
			for ip in $ipv6_wan ;do
				ip6tables -t nat -A clashv6 -p tcp -s $ip -j RETURN #屏蔽本机ipv6地址
			done
			ip6tables -t nat -A clashv6 -p tcp $ports -j REDIRECT --to-ports $redir_port
		fi
		ip6tables -t nat -A PREROUTING -p tcp -j clashv6
	fi
	return 0
}
start_ipt_dns(){
	#屏蔽OpenWrt内置53端口转发
	[ "$(uci get dhcp.@dnsmasq[0].dns_redirect 2>/dev/null)" = 1 ] && {
		uci del dhcp.@dnsmasq[0].dns_redirect
		uci commit dhcp.@dnsmasq[0]
	}
	#设置dns转发
	iptables -t nat -N clash_dns
	if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
		#mac白名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash_dns -p udp -m mac --mac-source $mac -j REDIRECT --to $dns_port
		done
	else
		#mac黑名单
		for mac in $(cat $clashdir/mac); do
			iptables -t nat -A clash_dns -m mac --mac-source $mac -j RETURN
		done	
		iptables -t nat -A clash_dns -p udp -j REDIRECT --to $dns_port
	fi
	iptables -t nat -I PREROUTING -p udp --dport 53 -j clash_dns
	#ipv6DNS
	if [ -n "$(lsmod | grep 'ip6table_nat')" ];then
		ip6tables -t nat -N clashv6_dns > /dev/null 2>&1
		if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
			#mac白名单
			for mac in $(cat $clashdir/mac); do
				ip6tables -t nat -A clashv6_dns -p udp -m mac --mac-source $mac -j REDIRECT --to $dns_port
			done
		else
			#mac黑名单
			for mac in $(cat $clashdir/mac); do
				ip6tables -t nat -A clashv6_dns -m mac --mac-source $mac -j RETURN
			done	
			ip6tables -t nat -A clashv6_dns -p udp -j REDIRECT --to $dns_port
		fi
		ip6tables -t nat -I PREROUTING -p udp --dport 53 -j clashv6_dns
	else
		ip6tables -I INPUT -p udp --dport 53 -m comment --comment "ShellClash-IPV6_DNS-REJECT" -j REJECT 2>/dev/null
	fi
	return 0

}
start_tproxy(){
	modprobe xt_TPROXY &>/dev/null && {
		#获取局域网host地址
		host_lan
		ip rule add fwmark 1 table 100
		ip route add local default dev lo table 100
		iptables -t mangle -N clash
		iptables -t mangle -A clash -p udp --dport 53 -j RETURN
		iptables -t mangle -A clash -d 0.0.0.0/8 -j RETURN
		iptables -t mangle -A clash -d 10.0.0.0/8 -j RETURN
		iptables -t mangle -A clash -d 127.0.0.0/8 -j RETURN
		iptables -t mangle -A clash -d 100.64.0.0/10 -j RETURN
		iptables -t mangle -A clash -d 169.254.0.0/16 -j RETURN
		iptables -t mangle -A clash -d 172.16.0.0/12 -j RETURN
		iptables -t mangle -A clash -d 192.168.0.0/16 -j RETURN
		iptables -t mangle -A clash -d 224.0.0.0/4 -j RETURN
		iptables -t mangle -A clash -d 240.0.0.0/4 -j RETURN
		[ -n "$host_lan" ] && iptables -t mangle -A clash -d $host_lan -j RETURN
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && iptables -t mangle -A clash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
		[ "$dns_mod" = "fake-ip" ] && iptables -t mangle -A clash -s 198.18.0.0/16 -j RETURN
		tproxy_set(){
		if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
			#mac白名单
			for mac in $(cat $clashdir/mac); do
				iptables -t mangle -A clash -p $1 -m mac --mac-source $mac -j TPROXY --on-port $tproxy_port --tproxy-mark 1
			done
		else
			#mac黑名单
			for mac in $(cat $clashdir/mac); do
				iptables -t mangle -A clash -m mac --mac-source $mac -j RETURN
			done
			iptables -t mangle -A clash -p $1 -s 192.168.0.0/16 -j TPROXY --on-port $tproxy_port --tproxy-mark 1
			iptables -t mangle -A clash -p $1 -s 10.0.0.0/8 -j TPROXY --on-port $tproxy_port --tproxy-mark 1
			[ -n "$host_lan" ] && iptables -t mangle -A clash -p $1 -s $host_lan -j TPROXY --on-port $tproxy_port --tproxy-mark 1
		fi
		iptables -t mangle -A PREROUTING -p $1 $ports -j clash
		}
		[ "$1" = "all" ] && tproxy_set tcp
		tproxy_set udp
		
		#屏蔽QUIC
		[ "$quic_rj" = 已启用 ] && {
			[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
			iptables -I INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT >/dev/null 2>&1
		}
		#设置ipv6转发
		[ "$ipv6_redir" = "已开启" ] && {
			ip -6 rule add fwmark 1 table 101
			ip -6 route add local ::/0 dev lo table 101
			ip6tables -t mangle -N clashv6
			ip6tables -t mangle -A clashv6 -p udp --dport 53 -j RETURN
			ip6tables -t mangle -A clashv6 -d ::1/128 -j RETURN
			ip6tables -t mangle -A clashv6 -d fc00::/7 -j RETURN
			ip6tables -t mangle -A clashv6 -d fe80::/10 -j RETURN
			[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && ip6tables -t mangle -A clashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
			tproxy_set6(){
				if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
					#mac白名单
					for mac in $(cat $clashdir/mac); do
						ip6tables -t mangle -A clashv6 -p $1 -m mac --mac-source $mac -j TPROXY --on-port $tproxy_port --tproxy-mark 1
					done
				else
					#mac黑名单
					for mac in $(cat $clashdir/mac); do
						ip6tables -t mangle -A clashv6 -m mac --mac-source $mac -j RETURN
					done
					for ip in $ipv6_wan ;do
						ip6tables -t mangle -A clashv6 -p $1 -s $ip -j RETURN #屏蔽本机ipv6地址
					done
					ip6tables -t mangle -A clashv6 -p $1 -j TPROXY --on-port $tproxy_port --tproxy-mark 1
				fi	
				ip6tables -t mangle -A PREROUTING -p $1 $ports -j clashv6		
			}
			[ "$1" = "all" ] && tproxy_set6 tcp
			tproxy_set6 udp
	
			[ "$quic_rj" = 已启用 ] && {
				ip6tables -I INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT 2>/dev/null
			}	
		}
	}
}
start_output(){
	#流量过滤
	iptables -t nat -N clash_out
	iptables -t nat -A clash_out -m owner --gid-owner 7890 -j RETURN
	iptables -t nat -A clash_out -d 0.0.0.0/8 -j RETURN
	iptables -t nat -A clash_out -d 10.0.0.0/8 -j RETURN
	iptables -t nat -A clash_out -d 100.64.0.0/10 -j RETURN
	iptables -t nat -A clash_out -d 127.0.0.0/8 -j RETURN
	iptables -t nat -A clash_out -d 169.254.0.0/16 -j RETURN
	iptables -t nat -A clash_out -d 192.168.0.0/16 -j RETURN
	iptables -t nat -A clash_out -d 224.0.0.0/4 -j RETURN
	iptables -t nat -A clash_out -d 240.0.0.0/4 -j RETURN
	[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && \
	iptables -t nat -A clash_out -m set --match-set cn_ip dst -j RETURN >/dev/null 2>&1 #绕过大陆IP
	iptables -t nat -A clash_out -p tcp -j REDIRECT --to-ports $redir_port
	#
	iptables -t nat -A OUTPUT -p tcp -j clash_out
	#设置dns转发
	[ "$dns_no" != "已禁用" ] && {
	iptables -t nat -N clash_dns_out
	iptables -t nat -A clash_dns_out -m owner --gid-owner 7890 -j RETURN
	iptables -t nat -A clash_dns_out -p udp -j REDIRECT --to $dns_port
	iptables -t nat -A OUTPUT -p udp --dport 53 -j clash_dns_out
	}
	#Docker转发
	ckcmd docker && {
		iptables -t nat -N clash_docker
		iptables -t nat -A clash_docker -d 10.0.0.0/8 -j RETURN
		iptables -t nat -A clash_docker -d 127.0.0.0/8 -j RETURN
		iptables -t nat -A clash_docker -d 172.16.0.0/12 -j RETURN
		iptables -t nat -A clash_docker -d 192.168.0.0/16 -j RETURN
		iptables -t nat -A clash_docker -p tcp -j REDIRECT --to-ports $redir_port
		iptables -t nat -A PREROUTING -p tcp -s 172.16.0.0/12 -j clash_docker
		[ "$dns_no" != "已禁用" ] && iptables -t nat -A PREROUTING -p udp --dport 53 -s 172.16.0.0/12 -j REDIRECT --to $dns_port
	}
}
start_tun(){
	modprobe tun &> /dev/null && {
		#允许流量
		iptables -I FORWARD -o utun -j ACCEPT
		iptables -I FORWARD -s 198.18.0.0/16 -o utun -j RETURN
		#ip6tables -I FORWARD -o utun -j ACCEPT > /dev/null 2>&1
		#屏蔽QUIC
		if [ "$quic_rj" = 已启用 ];then
			[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
			iptables -I FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT >/dev/null 2>&1 
			#ip6tables -I FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" -j REJECT >/dev/null 2>&1
		fi
		modprobe xt_mark &> /dev/null && {
			i=1
			while [ -z "$(ip route list |grep utun)" -a "$i" -le 9 ];do
				sleep 1
				i=$((i+1))
			done
			ip route add default dev utun table 100
			ip rule add fwmark 1 table 100
			#获取局域网host地址
			host_lan
			iptables -t mangle -N clash
			iptables -t mangle -F clash
			iptables -t mangle -A clash -p udp --dport 53 -j RETURN
			iptables -t mangle -A clash -d 0.0.0.0/8 -j RETURN
			iptables -t mangle -A clash -d 10.0.0.0/8 -j RETURN
			iptables -t mangle -A clash -d 127.0.0.0/8 -j RETURN
			iptables -t mangle -A clash -d 100.64.0.0/10 -j RETURN
			iptables -t mangle -A clash -d 169.254.0.0/16 -j RETURN
			iptables -t mangle -A clash -d 172.16.0.0/12 -j RETURN
			iptables -t mangle -A clash -d 192.168.0.0/16 -j RETURN
			iptables -t mangle -A clash -d 224.0.0.0/4 -j RETURN
			iptables -t mangle -A clash -d 240.0.0.0/4 -j RETURN
			iptables -t mangle -A clash -s 198.18.0.0/16 -j RETURN
			[ -n "$host_lan" ] && iptables -t mangle -A clash -d $host_lan -j RETURN	
			[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && iptables -t mangle -A clash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
			if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
				#mac白名单
				for mac in $(cat $clashdir/mac); do
					iptables -t mangle -A clash -m mac --mac-source $mac -j MARK --set-mark 1	
				done
			else
				#mac黑名单
				for mac in $(cat $clashdir/mac); do
					iptables -t mangle -A clash -m mac --mac-source $mac -j RETURN
				done
				iptables -t mangle -A clash -s 192.168.0.0/16 -j MARK --set-mark 1	
				iptables -t mangle -A clash -s 10.0.0.0/8 -j MARK --set-mark 1	
				[ -n "$host_lan" ] && iptables -t mangle -A clash -s $host_lan -j MARK --set-mark 1	
			fi
			iptables -t mangle -A PREROUTING -p udp $ports -j clash
			[ "$1" = "all" ] && iptables -t mangle -A PREROUTING -p tcp $ports -j clash
			
			#设置ipv6转发
			[ "$ipv6_redir" = "已开启" -a "$clashcore" = "clash.meta" ] && {
				ip -6 route add default dev utun table 101
				ip -6 rule add fwmark 1 table 101
				ip6tables -t mangle -N clashv6
				ip6tables -t mangle -A clashv6 -p udp --dport 53 -j RETURN
				ip6tables -t mangle -A clashv6 -d ::1/128 -j RETURN
				ip6tables -t mangle -A clashv6 -d fc00::/7 -j RETURN
				ip6tables -t mangle -A clashv6 -d fe80::/10 -j RETURN
				[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && ip6tables -t mangle -A clashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
				if [ "$macfilter_type" = "白名单" -a -n "$(cat $clashdir/mac)" ];then
					#mac白名单
					for mac in $(cat $clashdir/mac); do
						ip6tables -t mangle -A clashv6 -m mac --mac-source $mac -j MARK --set-mark 1	
					done
				else
					#mac黑名单
					for mac in $(cat $clashdir/mac); do
						ip6tables -t mangle -A clashv6 -m mac --mac-source $mac -j RETURN
					done
					for ip in $ipv6_wan ;do
						ip6tables -t mangle -A clashv6 -s $ip -j RETURN #屏蔽本机ipv6地址
					done					
					ip6tables -t mangle -A clashv6 -j MARK --set-mark 1	
				fi	
				ip6tables -t mangle -A PREROUTING -p udp $ports -j clashv6		
				[ "$1" = "all" ] && ip6tables -t mangle -A PREROUTING -p tcp $ports -j clashv6
			}
		} &
	} 
}
start_nft(){
	[ "$common_ports" = "已开启" ] && PORTS=$(echo $multiport | sed 's/,/, /g')
	RESERVED_IP="{0.0.0.0/8, 10.0.0.0/8, 127.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16, 224.0.0.0/4, 240.0.0.0/4}"
	#设置策略路由
	ip rule add fwmark 1 table 100 2> /dev/null
	ip route add local default dev lo table 100 2> /dev/null
	[ "$redir_mod" = "Nft基础" ] && \
		nft add chain inet shellclash prerouting { type nat hook prerouting priority -100 \; }
	[ "$redir_mod" = "Nft混合" ] && {
		modprobe nft_tproxy &> /dev/null
		nft add chain inet shellclash prerouting { type filter hook prerouting priority 0 \; }
	}
	[ -n "$(echo $redir_mod|grep Nft)" ] && {
		#过滤局域网设备
		[ -n "$(cat $clashdir/mac)" ] && {
			MAC=$(awk '{printf "%s, ",$1}' $clashdir/mac)
			[ "$macfilter_type" = "黑名单" ] && \
				nft add rule inet shellclash prerouting ether saddr {${MAC}} return || \
				nft add rule inet shellclash prerouting ether saddr != {${MAC}} return
		}
		#过滤保留地址
		nft add rule inet shellclash prerouting ip daddr {${RESERVED_IP}} return
		#过滤CN-IP
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" -a -f $bindir/cn_ip.txt ] && {
			CN_IP=$(awk '{printf "%s, ",$1}' $bindir/cn_ip.txt)
			[ -n "$CN_IP" ] && nft add rule inet shellclash prerouting ip daddr {${CN_IP}} return
		}
		#过滤常用端口
		[ -n "$PORTS" ] && nft add rule inet shellclash prerouting tcp dport != {${PORTS}} return
		#ipv6支持
		if [ "$ipv6_redir" = "已开启" ];then
			RESERVED_IP6="{::1/128, fc00::/7, fe80::/10}"
			ip -6 rule add fwmark 1 table 101 2> /dev/null
			ip -6 route add local ::/0 dev lo table 101 2> /dev/null
			nft add rule inet shellclash prerouting ip6 daddr {${RESERVED_IP6}} return
			[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" -a -f $bindir/cn_ipv6.txt ] && {
				CN_IP6=$(awk '{printf "%s, ",$1}' $bindir/cn_ipv6.txt)
				[ -n "$CN_IP6" ] && nft add rule inet shellclash prerouting ip6 daddr {${CN_IP6}} return
			}
			[ -n "$ipv6_wan" ] && {
				LOCAL_IP6="{$(echo $ipv6_wan | sed s/\ /\,\ /g)}"
				nft add rule inet shellclash prerouting ip6 daddr {${LOCAL_IP6}} return #屏蔽本机ipv6地址
			}
		else
			nft add rule inet shellclash prerouting meta nfproto ipv6 return
		fi
		#透明路由
		[ "$redir_mod" = "Nft基础" ] && nft add rule inet shellclash prerouting meta l4proto tcp mark set 1 redirect to ${redir_port}
		[ "$redir_mod" = "Nft混合" ] && nft add rule inet shellclash prerouting meta l4proto {tcp, udp} mark set 1 tproxy to :${tproxy_port}
	}
	#屏蔽QUIC
	[ "$quic_rj" = 已启用 ] && {
		nft add chain inet shellclash input { type filter hook input priority 0 \; }
		[ -n "$CN_IP" ] && nft add rule inet shellclash input ip daddr {${CN_IP}} return
		[ -n "$CN_IP6" ] && nft add rule inet shellclash input ip6 daddr {${CN_IP6}} return
		nft add rule inet shellclash input udp dport 443 reject comment 'ShellClash-QUIC-REJECT'
	}
	#代理本机(仅TCP)
	[ "$local_proxy" = "已开启" ] && [ "$local_type" = "nftables增强模式" ] && {
		#dns
		nft add chain inet shellclash dns_out { type nat hook output priority -100 \; }
		nft add rule inet shellclash dns_out meta skgid 7890 return && \
		nft add rule inet shellclash dns_out udp dport 53 redirect to ${dns_port}
		#output
		nft add chain inet shellclash output { type nat hook output priority -100 \; }
		nft add rule inet shellclash output meta skgid 7890 return && {
			[ -n "$PORTS" ] && nft add rule inet shellclash output tcp dport != {${PORTS}} return
			nft add rule inet shellclash output ip daddr {${RESERVED_IP}} return
			nft add rule inet shellclash output meta l4proto tcp mark set 1 redirect to ${redir_port}
		}
		#Docker
		type docker &>/dev/null && {
			ip rule add fwmark 1 table 102 2> /dev/null
			ip route add local 172.16.0.0/12 dev lo table 102 2> /dev/null
		}
	}
}
start_nft_dns(){
	nft add chain inet shellclash dns { type nat hook prerouting priority -100 \; }
	#过滤局域网设备
	[ -n "$(cat $clashdir/mac)" ] && {
		MAC=$(awk '{printf "%s, ",$1}' $clashdir/mac)
		[ "$macfilter_type" = "黑名单" ] && \
			nft add rule inet shellclash dns ether saddr {${MAC}} return || \
			nft add rule inet shellclash dns ether saddr != {${MAC}} return
	}
	nft add rule inet shellclash dns udp dport 53 redirect to ${dns_port}
	nft add rule inet shellclash dns tcp dport 53 redirect to ${dns_port}
}
start_wan(){
	[ "$mix_port" = "7890" -o -z "$authentication" ] && {
	iptables -A INPUT -p tcp -s 10.0.0.0/8 --dport $mix_port -j ACCEPT
	iptables -A INPUT -p tcp -s 127.0.0.0/8 --dport $mix_port -j ACCEPT
	iptables -A INPUT -p tcp -s 192.168.0.0/16 --dport $mix_port -j ACCEPT
	iptables -A INPUT -p tcp -s 172.16.0.0/12 --dport $mix_port -j ACCEPT
	iptables -A INPUT -p tcp --dport $mix_port -j REJECT
	ckcmd ip6tables && ip6tables -A INPUT -p tcp --dport $mix_port -j REJECT 2> /dev/null
	}
	if [ "$public_support" = "已开启" ];then
		[ "$mix_port" != "7890" -a -n "$authentication" ] && {
		iptables -I INPUT -p tcp --dport $mix_port -j ACCEPT
		ckcmd ip6tables && ip6tables -I INPUT -p tcp --dport $mix_port -j ACCEPT 2> /dev/null
		}
		iptables -I INPUT -p tcp --dport $db_port -j ACCEPT
		ckcmd ip6tables && ip6tables -I INPUT -p tcp --dport $db_port -j ACCEPT 2> /dev/null
	fi
}
stop_firewall(){
    #重置iptables相关规则
	ckcmd iptables && {
		#redir
		iptables -t nat -D PREROUTING -p tcp $ports -j clash 2> /dev/null
		iptables -t nat -F clash 2> /dev/null
		iptables -t nat -X clash 2> /dev/null
		#dns
		iptables -t nat -D PREROUTING -p udp --dport 53 -j clash_dns 2> /dev/null
		iptables -t nat -F clash_dns 2> /dev/null
		iptables -t nat -X clash_dns 2> /dev/null
		#tun
		iptables -D FORWARD -o utun -j ACCEPT 2> /dev/null
		iptables -D FORWARD -s 198.18.0.0/16 -o utun -j RETURN 2> /dev/null
		#屏蔽QUIC
		[ "$dns_mod" = "redir_host" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
		iptables -D INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
		iptables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
		#本机代理
		iptables -t nat -D OUTPUT -p tcp -j clash_out 2> /dev/null
		iptables -t nat -F clash_out 2> /dev/null
		iptables -t nat -X clash_out 2> /dev/null	
		iptables -t nat -D OUTPUT -p udp --dport 53 -j clash_dns_out 2> /dev/null
		iptables -t nat -F clash_dns_out 2> /dev/null
		iptables -t nat -X clash_dns_out 2> /dev/null
		#docker
		iptables -t nat -F clash_docker 2> /dev/null
		iptables -t nat -X clash_docker 2> /dev/null
		iptables -t nat -D PREROUTING -p tcp -s 172.16.0.0/12 -j clash_docker 2> /dev/null
		iptables -t nat -D PREROUTING -p udp --dport 53 -s 172.16.0.0/12 -j REDIRECT --to $dns_port 2> /dev/null
		#TPROXY&tun
		iptables -t mangle -D PREROUTING -p tcp $ports -j clash 2> /dev/null
		iptables -t mangle -D PREROUTING -p udp $ports -j clash 2> /dev/null
		iptables -t mangle -F clash 2> /dev/null
		iptables -t mangle -X clash 2> /dev/null
		#公网访问
		iptables -D INPUT -p tcp -s 10.0.0.0/8 --dport $mix_port -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp -s 127.0.0.0/8 --dport $mix_port -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp -s 172.16.0.0/12 --dport $mix_port -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp -s 192.168.0.0/16 --dport $mix_port -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp --dport $mix_port -j REJECT 2> /dev/null
		iptables -D INPUT -p tcp --dport $mix_port -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp --dport $db_port -j ACCEPT 2> /dev/null
	}
	#重置ipv6规则
	ckcmd ip6tables && {
		#redir
		ip6tables -t nat -D PREROUTING -p tcp -j clashv6 2> /dev/null
		ip6tables -D INPUT -p udp --dport 53 -m comment --comment "ShellClash-IPV6_DNS-REJECT" -j REJECT 2> /dev/null
		ip6tables -t nat -F clashv6 2> /dev/null
		ip6tables -t nat -X clashv6 2> /dev/null
		#dns
		ip6tables -t nat -D PREROUTING -p udp --dport 53 -j clashv6_dns 2>/dev/null
		ip6tables -t nat -F clashv6_dns 2> /dev/null
		ip6tables -t nat -X clashv6_dns 2> /dev/null
		#tun
		ip6tables -D FORWARD -o utun -j ACCEPT 2> /dev/null
		ip6tables -I FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" -j REJECT >/dev/null 2>&1
		#屏蔽QUIC
		[ "$dns_mod" = "redir_host" -a "$cn_ipv6_route" = "已开启" ] && set_cn_ip6='-m set ! --match-set cn_ip6 dst'
		iptables -D INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2> /dev/null
		iptables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2> /dev/null
		#公网访问
		ip6tables -D INPUT -p tcp --dport $mix_port -j REJECT 2> /dev/null
		ip6tables -D INPUT -p tcp --dport $mix_port -j ACCEPT 2> /dev/null
		ip6tables -D INPUT -p tcp --dport $db_port -j ACCEPT 2> /dev/null
		#tproxy&tun
		ip6tables -t mangle -D PREROUTING -p tcp $ports -j clashv6 2> /dev/null
		ip6tables -t mangle -D PREROUTING -p udp $ports -j clashv6 2> /dev/null
		ip6tables -t mangle -F clashv6 2> /dev/null
		ip6tables -t mangle -X clashv6 2> /dev/null
		ip6tables -D INPUT -p udp --dport 443 -m comment --comment "ShellClash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
	}
	#清理ipset规则
	ipset destroy cn_ip >/dev/null 2>&1
	ipset destroy cn_ip6 >/dev/null 2>&1
	#移除dnsmasq转发规则
	[ "$dns_redir" = "已开启" ] && {
		uci del dhcp.@dnsmasq[-1].server >/dev/null 2>&1
		uci set dhcp.@dnsmasq[0].noresolv=0 2>/dev/null
		uci commit dhcp >/dev/null 2>&1
		/etc/init.d/dnsmasq restart >/dev/null 2>&1
	}
	#清理路由规则
	ip rule del fwmark 1 table 100  2> /dev/null
	ip route del local default dev lo table 100 2> /dev/null
	ip -6 rule del fwmark 1 table 101 2> /dev/null
	ip -6 route del local ::/0 dev lo table 101 2> /dev/null
	ip rule del fwmark 1 table 102 2> /dev/null
	ip route del local 172.16.0.0/12 dev lo table 102 2> /dev/null
	#重置nftables相关规则
	ckcmd nft && {
		nft flush table inet shellclash >/dev/null 2>&1
		nft delete table inet shellclash >/dev/null 2>&1
	}
}
#面板配置保存相关
web_save(){
	get_save(){
		if curl --version > /dev/null 2>&1;then
			curl -s -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1"
		elif [ -n "$(wget --help 2>&1|grep '\-\-method')" ];then
			wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1"
		fi
	}
	#使用get_save获取面板节点设置
	get_save http://localhost:${db_port}/proxies | awk -F "{" '{for(i=1;i<=NF;i++) print $i}' | grep -E '^"all".*"Selector"' > /tmp/clash_web_check_$USER
	while read line ;do
		def=$(echo $line | awk -F "[[,]" '{print $2}')
		now=$(echo $line | grep -oE '"now".*",' | sed 's/"now"://g' | sed 's/"type":.*//g' |  sed 's/,//g')
		[ "$def" != "$now" ] && echo $line | grep -oE '"name".*"now".*",' | sed 's/"name"://g' | sed 's/"now"://g' | sed 's/"type":.*//g' | sed 's/"//g' >> /tmp/clash_web_save_$USER
	done < /tmp/clash_web_check_$USER
	rm -rf /tmp/clash_web_check_$USER
	#对比文件，如果有变动且不为空则写入磁盘，否则清除缓存
	if [ -s /tmp/clash_web_save_$USER ];then
		compare /tmp/clash_web_save_$USER $clashdir/web_save
		[ "$?" = 0 ] && rm -rf /tmp/clash_web_save_$USER || mv -f /tmp/clash_web_save_$USER $clashdir/web_save
	fi
}
web_restore(){

	#设置循环检测clash面板端口
	i=1
	while [ -z "$test" -a "$i" -lt 60 ];do
		sleep 1
		if curl --version > /dev/null 2>&1;then
			test=$(curl -s http://localhost:${db_port})
		else
			test=$(wget -q -O - http://localhost:${db_port})
		fi
		i=$((i+1))
	done
	#发送数据
	num=$(cat $clashdir/web_save | wc -l)
	i=1
	while [ "$i" -le "$num" ];do
		group_name=$(awk -F ',' 'NR=="'${i}'" {print $1}' $clashdir/web_save | sed 's/ /%20/g')
		now_name=$(awk -F ',' 'NR=="'${i}'" {print $2}' $clashdir/web_save)
		put_save http://localhost:${db_port}/proxies/${group_name} "{\"name\":\"${now_name}\"}"
		i=$((i+1))
	done
}
#启动相关
catpac(){
	#获取本机host地址
	[ -n "$host" ] && host_pac=$host
	[ -z "$host_pac" ] && host_pac=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
	[ -z "$host_pac" ] && host_pac=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	cat > /tmp/clash_pac <<EOF
//如看见此处内容，请重新安装本地面板！
//之后返回上一级页面，清理浏览器缓存并刷新页面！
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
		return "PROXY $host_pac:$mix_port; DIRECT; SOCKS5 $host_pac:$mix_port"
}
EOF
	compare /tmp/clash_pac $bindir/ui/pac
	[ "$?" = 0 ] && rm -rf /tmp/clash_pac || mv -f /tmp/clash_pac $bindir/ui/pac
}
bfstart(){
	#读取配置文件
	getconfig
	[ ! -d $bindir/ui ] && mkdir -p $bindir/ui
	[ -z "$update_url" ] && update_url=https://fastly.jsdelivr.net/gh/juewuy/ShellClash@master
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
	#检测vless/hysteria协议
	if [ -n "$(cat $clashdir/config.yaml | grep -oE 'type: vless|type: hysteria')" ] && [ "$clashcore" != "clash.meta" ];then
		echo -----------------------------------------------
		logger "检测到vless/hysteria协议！将改为使用clash.meta核心启动！" 33
		rm -rf $bindir/clash
		clashcore=clash.meta
		setconfig clashcore clash.meta
		echo -----------------------------------------------
	fi
	#检测是否存在高级版规则
	if [ "$clashcore" = "clash" -a -n "$(cat $clashdir/config.yaml | grep -E '^script:|proxy-providers|rule-providers|rule-set')" ];then
		echo -----------------------------------------------
		logger "检测到高级规则！将改为使用clash.meta核心启动！" 33
		rm -rf $bindir/clash
		clashcore=clash.meta
		setconfig clashcore clash.meta
		echo -----------------------------------------------
	fi
	#检查clash核心
	if [ ! -f $bindir/clash ];then
		if [ -f $clashdir/clash ];then
			mv $clashdir/clash $bindir/clash
		else
			logger "未找到clash核心，正在下载！" 33
			if [ -z "$clashcore" ];then
				[ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ] && clashcore=clashpre || clashcore=clash
			fi
			[ -z "$cpucore" ] && source $clashdir/getdate.sh && getcpucore
			[ -z "$cpucore" ] && logger 找不到设备的CPU信息，请手动指定处理器架构类型！ 31 && setcpucore
			[ "$update_url" = "https://jwsc.eu.org:8888" ] && [ "$clashcore" != 'clash' ] && update_url=https://fastly.jsdelivr.net/gh/juewuy/ShellClash@master
			$0 webget $bindir/clash "$update_url/bin/$clashcore/clash-linux-$cpucore"
			#校验内核
			chmod +x $bindir/clash 2>/dev/null
			clashv=$($bindir/clash -v 2>/dev/null | sed 's/ linux.*//;s/.* //')
			if [ -z "$clashv" ];then
				rm -rf $bindir/clash
				logger "核心下载失败，请重新运行或更换安装源！" 31
				exit 1
			else
				setconfig clashcore $clashcore
				setconfig clashv $clashv
			fi
		fi
	fi
	[ ! -x $bindir/clash ] && chmod +x $bindir/clash 	#检测可执行权限
	#检查数据库文件
	if [ ! -f $bindir/Country.mmdb ];then
		if [ -f $clashdir/Country.mmdb ];then
			mv $clashdir/Country.mmdb $bindir/Country.mmdb
		else
			logger "未找到GeoIP数据库，正在下载！" 33
			$0 webget $bindir/Country.mmdb $update_url/bin/cn_mini.mmdb
			[ "$?" = "1" ] && rm -rf $bindir/Country.mmdb && logger "数据库下载失败，已退出！" 31 && exit 1
			Geo_v=$(date +"%Y%m%d")
			setconfig Geo_v $Geo_v
		fi
	fi
	#检查dashboard文件
	if [ -f $clashdir/ui/index.html -a ! -f $bindir/ui/index.html ];then
		cp -rf $clashdir/ui $bindir
	fi
	#检查curl或wget支持
	curl --version > /dev/null 2>&1
	[ "$?" = 1 ] && wget --version > /dev/null 2>&1
	[ "$?" = 1 ] && restore=true || restore=false
	#生成pac文件
	catpac
	#预下载GeoSite数据库
	if [ "$clashcore" = "clash.meta" ] && [ ! -f $bindir/GeoSite.dat ] && [ -n "$(cat $clashdir/config.yaml|grep -Ei 'geosite')" ];then
		[ -f $clashdir/geosite.dat ] && mv -f $clashdir/geosite.dat $clashdir/GeoSite.dat
		if [ -f $clashdir/GeoSite.dat ];then
			mv -f $clashdir/GeoSite.dat $bindir/GeoSite.dat
		else
			logger "未找到geosite数据库，正在下载！" 33
			$0 webget $bindir/GeoSite.dat $update_url/bin/geosite.dat
			[ "$?" = "1" ] && rm -rf $bindir/GeoSite.dat && logger "数据库下载失败，已退出！" 31 && exit 1
		fi
	fi
	#本机代理准备
	if [ "$local_proxy" = "已开启" -a -n "$(echo $local_type | grep '增强模式')" ];then
		if [ -z "$(id shellclash 2>/dev/null | grep 'root')" ];then
			if ckcmd userdel useradd groupmod; then
				userdel shellclash 2>/dev/null
				useradd shellclash -u 7890
				groupmod shellclash -g 7890
				sed -Ei s/7890:7890/0:7890/g /etc/passwd
			else
				grep -qw shellclash /etc/passwd || echo "shellclash:x:0:7890:::" >> /etc/passwd
			fi
		fi
		if [ "$start_old" != "已开启" ];then
			[ -w /etc/systemd/system/clash.service ] && servdir=/etc/systemd/system/clash.service
			[ -w /usr/lib/systemd/system/clash.service ] && servdir=/usr/lib/systemd/system/clash.service
			if [ -w /etc/init.d/clash ]; then
				[ -z "$(grep 'procd_set_param user shellclash' /etc/init.d/clash)" ] && \
    			sed -i '/procd_close_instance/i\\t\tprocd_set_param user shellclash' /etc/init.d/clash
			elif [ -w "$servdir" ]; then
				setconfig ExecStart "/bin/su shellclash -c \"$bindir/clash -d $bindir\"" $servdir
				systemctl daemon-reload >/dev/null
			fi
		fi
	fi
}
afstart(){

	#读取配置文件
	getconfig
	#延迟启动
	[ ! -f /tmp/clash_start_time ] && [ -n "$start_delay" ] && [ "$start_delay" -gt 0 ] && {
	logger "clash将延迟$start_delay秒启动" 31 pushoff
	sleep $start_delay
	}
	$bindir/clash -t -d $bindir >/dev/null
	if [ "$?" = 0 ];then
		#设置DNS转发
		start_dns(){
			[ "$dns_mod" = "redir_host" ] && [ "$cn_ip_route" = "已开启" ] && cn_ip_route
			[ "$ipv6_redir" = "已开启" ] && [ "$dns_mod" = "redir_host" ] && [ "$cn_ipv6_route" = "已开启" ] && cn_ipv6_route
			if [ "$dns_no" != "已禁用" ];then
				if [ "$dns_redir" != "已开启" ];then
					[ -n "$(echo $redir_mod|grep Nft)" ] && start_nft_dns || start_ipt_dns
				else
					#openwrt使用dnsmasq转发
					uci del dhcp.@dnsmasq[-1].server >/dev/null 2>&1
					uci delete dhcp.@dnsmasq[0].resolvfile 2>/dev/null
					uci add_list dhcp.@dnsmasq[0].server=127.0.0.1#$dns_port > /dev/null 2>&1
					uci set dhcp.@dnsmasq[0].noresolv=1 2>/dev/null
					uci commit dhcp >/dev/null 2>&1
					/etc/init.d/dnsmasq restart >/dev/null 2>&1
				fi
			fi
		}
		#设置路由规则
		[ "$ipv6_redir" = "已开启" ] && ipv6_wan=$(ip addr show|grep -A1 'inet6 [^f:]'|grep -oE 'inet6 ([a-f0-9:]+)/'|sed s#inet6\ ##g|sed s#/##g)
		[ "$redir_mod" = "Redir模式" ] && start_dns && start_redir 	
		[ "$redir_mod" = "混合模式" ] && start_dns && start_redir && start_tun udp
		[ "$redir_mod" = "Tproxy混合" ] && start_dns && start_redir && start_tproxy udp
		[ "$redir_mod" = "Tun模式" ] && start_dns && start_tun all
		[ "$redir_mod" = "Tproxy模式" ] && start_dns && start_tproxy all
		[ -n "$(echo $redir_mod|grep Nft)" ] && {
			nft add table inet shellclash 2> /dev/null #初始化nftables
			nft flush table inet shellclash 2> /dev/null
			start_dns
			start_nft
		}
		#设置本机代理
		[ "$local_proxy" = "已开启" ] && [ "$local_type" = "环境变量" ] && $0 set_proxy $mix_port $db_port
		[ "$local_proxy" = "已开启" ] && [ "$local_type" = "iptables增强模式" ] && start_output
		[ "$local_proxy" = "已开启" ] && [ "$local_type" = "nftables增强模式" ] && [ "$redir_mod" = "纯净模式" ] && start_nft
		ckcmd iptables && start_wan
		#同步本机时间
		ckcmd ntpd && ntpd -n -q -p 203.107.6.88
		#标记启动时间
		mark_time
		#加载定时任务
		[ -f $clashdir/cron ] && croncmd $clashdir/cron	
		#启用面板配置自动保存
		cronset '#每10分钟保存节点配置' "*/10 * * * * test -n \"\$(pidof clash)\" && $clashdir/start.sh web_save #每10分钟保存节点配置"
		[ -f $clashdir/web_save ] && web_restore & #后台还原面板配置
		#自动开启SSH
		[ "$mi_autoSSH" = "已启用" ] && autoSSH 2>/dev/null	&
		{ sleep 30;logger Clash服务已启动！;} &
	else
		logger "Clash服务启动失败！请查看报错信息！" 31
		$bindir/clash -t -d $bindir
		echo "$($bindir/clash -t -d $bindir)" >> $clashdir/log
		$0 stop
		exit 1
	fi
}
start_old(){
	#使用传统后台执行二进制文件的方式执行
	if [ "$local_proxy" = "已开启" -a -n "$(echo $local_type | grep '增强模式')" ];then
		su shellclash -c "$bindir/clash -d $bindir >/dev/null" &
	else
		ckcmd nohup && nohup=nohup
		$nohup $bindir/clash -d $bindir >/dev/null 2>&1 &
	fi
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
		stop_firewall #清理路由策略
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
		logger Clash服务即将关闭……
		[ -n "$(pidof clash)" ] && [ "$restore" = false ] && web_save #保存面板配置
		#删除守护进程&面板配置自动保存
		cronset "clash保守模式守护进程"
		cronset "保存节点配置"
		cronset "流媒体预解析"
		#多种方式结束进程
		if [ -f /etc/rc.common ];then
			/etc/init.d/clash stop >/dev/null 2>&1
		elif [ "$USER" = "root" ];then
			systemctl stop clash.service >/dev/null 2>&1
		fi
		PID=$(pidof clash) && [ -n "$PID" ] &&  kill -9 $PID >/dev/null 2>&1
		stop_firewall #清理路由策略
		$0 unset_proxy #禁用本机代理
        ;;
restart)
        $0 stop
        $0 start
        ;;
init)
        if [ -d "/etc/storage/clash" ];then
			clashdir=/etc/storage/clash
			i=1
			while [ ! -w "/etc/profile" -a "$i" -lt 7 ];do
				sleep 5 && i=$((i+1))
			done
			profile=/etc/profile
			sed -i '' $profile #将软链接转化为一般文件
		elif [ -d "/jffs" ];then
			sleep 40
			clashdir=$(cd $(dirname $0);pwd)
			if [ -w /etc/profile ];then
				profile=/etc/profile
			else
				profile=$(cat /etc/profile | grep -oE '\-f.*jffs.*profile' | awk '{print $2}')
			fi
		else
			clashdir=$(cd $(dirname $0);pwd)
			profile=/etc/profile
		fi
		sed -i "/alias clash/d" $profile 
		sed -i "/export clashdir/d" $profile 
		echo "alias clash=\"$clashdir/clash.sh\"" >> $profile 
		echo "export clashdir=\"$clashdir\"" >> $profile 
		[ -f $clashdir/.dis_startup ] && cronset "clash保守模式守护进程" || $0 start
        ;;
getyaml)	
		getconfig
		getyaml && \
		logger ShellClash配置文件更新成功！
		;;
updateyaml)	
		getconfig
		getyaml && \
		modify_yaml && \
		put_save http://localhost:${db_port}/configs "{\"path\":\"${clashdir}/config.yaml\"}" && \
		logger ShellClash配置文件更新成功！
		;;
logger)
		logger $2 $3
	;;
webget)
		#设置临时代理 
		if [ -n "$(pidof clash)" ];then
			getconfig
			[ -n "$authentication" ] && auth="$authentication@"
			export https_proxy="http://${auth}127.0.0.1:$mix_port"
			url=$(echo $3 | sed 's#https://.*/juewuy/ShellClash[@|/]#https://raw.githubusercontent.com/juewuy/ShellClash/#' | sed 's#https://gh.jwsc.eu.org/#https://raw.githubusercontent.com/juewuy/ShellClash/#')
		else
			url=$(echo $3 | sed 's#https://.*/juewuy/ShellClash/#https://fastly.jsdelivr.net/gh/juewuy/ShellClash@#')
		fi
		#参数【$2】代表下载目录，【$3】代表在线地址
		#参数【$4】代表输出显示，【$4】不启用重定向
		#参数【$6】代表验证证书
		if curl --version > /dev/null 2>&1;then
			[ "$4" = "echooff" ] && progress='-s' || progress='-#'
			[ "$5" = "rediroff" ] && redirect='' || redirect='-L'
			[ "$6" = "skipceroff" ] && certificate='' || certificate='-k'
			result=$(curl $agent -w %{http_code} --connect-timeout 3 $progress $redirect $certificate -o "$2" "$url")
			[ "$result" != "200" ] && export https_proxy="" && result=$(curl $agent -w %{http_code} --connect-timeout 3 $progress $redirect $certificate -o "$2" "$3")
		else
			if wget --version > /dev/null 2>&1;then
				[ "$4" = "echooff" ] && progress='-q' || progress='-q --show-progress'
				[ "$5" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
				[ "$6" = "skipceroff" ] && certificate='' || certificate='--no-check-certificate'
				timeout='--timeout=3 -t 2'
			fi
			[ "$4" = "echoon" ] && progress=''
			[ "$4" = "echooff" ] && progress='-q'
			wget -Y on $agent $progress $redirect $certificate $timeout -O "$2" "$url"
			if [ "$?" != "0" ];then
				wget -Y off $agent $progress $redirect $certificate $timeout -O "$2" "$3"
				[ "$?" = "0" ] && result="200"
			else
				result="200"
			fi
		fi
		[ "$result" = "200" ] && exit 0 || exit 1
		;;
web_save)
		getconfig
		web_save
	;;
web_restore)
		getconfig
		web_restore
	;;
daemon)
		getconfig
		cronset '#clash保守模式守护进程' "*/1 * * * * test -z \"\$(pidof clash)\" && $clashdir/start.sh restart #clash保守模式守护进程"
	;;
cronset)
		cronset $2 $3
	;;
set_proxy)
		getconfig
		if  [ "$local_type" = "环境变量" ];then
			[ -w ~/.bashrc ] && profile=~/.bashrc
			[ -w /etc/profile ] && profile=/etc/profile
			echo 'export all_proxy=http://127.0.0.1:'"$mix_port" >> $profile
			echo 'export ALL_PROXY=$all_proxy' >>  $profile
		fi
	;;
unset_proxy)	
		[ -w ~/.bashrc ] && profile=~/.bashrc
		[ -w /etc/profile ] && profile=/etc/profile
		sed -i '/all_proxy/'d  $profile
		sed -i '/ALL_PROXY/'d  $profile
	;;

esac

exit 0
