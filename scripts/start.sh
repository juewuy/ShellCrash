#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
CRASHDIR=$(cd $(dirname $0);pwd)
#加载执行目录，失败则初始化
source ${CRASHDIR}/configs/command.env &>/dev/null
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && source ${CRASHDIR}/init.sh &>/dev/null
[ ! -f ${TMPDIR} ] && mkdir -p ${TMPDIR}

#脚本内部工具
getconfig(){ #获取脚本配置
	#加载配置文件
	source ${CRASHDIR}/configs/ShellCrash.cfg >/dev/null
	#默认设置
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
	[ -z "$fwmark" ] && fwmark=$redir_port
	[ -z "$sniffer" ] && sniffer=已开启
	#是否代理常用端口
	[ -z "$common_ports" ] && common_ports=已开启
	[ -z "$multiport" ] && multiport='22,53,80,123,143,194,443,465,587,853,993,995,5222,8080,8443'
	[ "$common_ports" = "已开启" ] && ports="-m multiport --dports $multiport"
	#内核配置文件
	if [ "$crashcore" = singbox -o "$crashcore" = singboxp ];then
		target=singbox
		format=json
		core_config=${CRASHDIR}/jsons/config.json
	else
		target=clash
		format=yaml
		core_config=${CRASHDIR}/yamls/config.yaml
	fi
}
setconfig(){ #脚本配置工具
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath=${CRASHDIR}/configs/ShellCrash.cfg || configpath="${3}"
	[ -n "$(grep "${1}=" "$configpath")" ] && sed -i "s#${1}=.*#${1}=${2}#g" $configpath || echo "${1}=${2}" >> $configpath
}
ckcmd(){ #检查命令是否存在
	command -v sh &>/dev/null && command -v $1 &>/dev/null || type $1 &>/dev/null
}
finds(){ #find命令兼容
	[ -n "$(find --help 2>&1|grep size)" ] && find $1 $2 $3 $4 $5 || find $1
}
compare(){ #对比文件
	if [ ! -f $1 -o ! -f $2 ];then
		return 1
	elif ckcmd cmp;then
		cmp -s $1 $2
	else
		[ "$(cat $1)" = "$(cat $2)" ] && return 0 || return 1
	fi
}
logger(){ #日志工具
	#$1日志内容$2显示颜色$3是否推送
	[ -n "$2" -a "$2" != 0 ] && echo -e "\033[$2m$1\033[0m"
	log_text="$(date "+%G-%m-%d_%H:%M:%S")~$1"
	echo $log_text >> ${TMPDIR}/ShellCrash.log
	[ "$(wc -l  ${TMPDIR}/ShellCrash.log | awk '{print $1}')" -gt 99 ] && sed -i '1,50d'  ${TMPDIR}/ShellCrash.log
	[ -z "$3" ] && {
		getconfig
		[ -n "$device_name" ] && log_text="$log_text($device_name)"
		[ -n "$(pidof CrashCore)" ] && {
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
			url=${push_bark}/${log_text}${bark_param}
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
croncmd(){ #定时任务工具
	if [ -n "$(crontab -h 2>&1 | grep '\-l')" ];then
		crontab $1
	else
		crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}')"
		[ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
		[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
		[ ! -w "$crondir" ] && crondir="/var/spool/cron"
		if [ -w "$crondir" ];then
			[ "$1" = "-l" ] && cat $crondir/$USER 2>/dev/null
			[ -f "$1" ] && cat $1 > $crondir/$USER
		else
			echo "你的设备不支持定时任务配置，脚本大量功能无法启用，请尝试使用搜索引擎查找安装方式！"
		fi
	fi
}
cronset(){ #定时任务设置
	# 参数1代表要移除的关键字,参数2代表要添加的任务语句
	tmpcron=${TMPDIR}/cron_$USER
	croncmd -l > $tmpcron 2>/dev/null
	sed -i "/$1/d" $tmpcron
	sed -i '/^$/d' $tmpcron
	echo "$2" >> $tmpcron
	croncmd $tmpcron
	rm -f $tmpcron
}
get_save(){ #获取面板信息
	if curl --version > /dev/null 2>&1;then
		curl -s -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1"
	elif [ -n "$(wget --help 2>&1|grep '\-\-method')" ];then
		wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1"
	fi
}
put_save(){ #推送面板选择
	[ -z "$3" ] && request_type=PUT || request_type=$3
	if curl --version > /dev/null 2>&1;then
		curl -sS -X ${request_type} -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1" -d "$2" >/dev/null
	elif wget --version > /dev/null 2>&1;then
		wget -q --method=${request_type} --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" --body-data="$2" "$1" >/dev/null
	fi
}
get_bin(){ #专用于项目内部文件的下载
	source ${CRASHDIR}/configs/ShellCrash.cfg >/dev/null
	[ -z "$update_url" ] && update_url=https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master
	if [ -n "$url_id" ];then
		[ -z "$release_type" ] && release_type=master
		if [ "$url_id" = 101 -o "$url_id" = 104 ];then
			url="$(grep "$url_id" ${CRASHDIR}/configs/servers.list | awk '{print $3}')@$release_type/$2" #jsdelivr特殊处理
		else
			url="$(grep "$url_id" ${CRASHDIR}/configs/servers.list | awk '{print $3}')/$release_type/$2"
		fi
	else
		url="$update_url/$2"
	fi
	$0 webget "$1" "$url" "$3" "$4" "$5" "$6"
}
mark_time(){ #时间戳
	echo `date +%s` > ${TMPDIR}/crash_start_time
}
getlanip(){ #获取局域网host地址
	i=1
	while [ "$i" -le "20" ];do
		host_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'br' | grep -Ev 'iot' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/br.*$//g' | sed 's/metric.*$//g' ) #ipv4局域网网段
		[ "$ipv6_redir" = "已开启" ] && host_ipv6=$(ip a 2>&1 | grep -w 'inet6' | grep -E 'global' | sed 's/.*inet6.//g' | sed 's/scope.*$//g' ) #ipv6公网地址段
		[ -f  ${TMPDIR}/ShellCrash.log ] && break
		[ -n "$host_ipv4" -a "$ipv6_redir" != "已开启" ] && break
		[ -n "$host_ipv4" -a -n "$host_ipv6" ] && break
		sleep 1 && i=$((i+1))
	done
	#添加自定义ipv4局域网网段
	host_ipv4="$host_ipv4$cust_host_ipv4"
	#缺省配置
	[ -z "$host_ipv4" ] && host_ipv4='192.168.0.0/16 10.0.0.0/12 172.16.0.0/12'
	[ -z "$host_ipv6" ] && host_ipv6='fe80::/10 fd00::/8'
	#获取本机出口IP地址
	local_ipv4=$(ip route 2>&1 | grep 'src' | grep -Ev 'utun|iot|docker' | grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3} $' | sed 's/.*src //g' )
	[ -z "$local_ipv4" ] && local_ipv4=$(ip route 2>&1 | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u )
	#保留地址
	reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
	reserve_ipv6="::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 100::/64 2001::/32 2001:20::/28 2001:db8::/32 2002::/16 fc00::/7 fe80::/10 ff00::/8"
}
#配置文件相关
check_clash_config(){ #检查clash配置文件
	#检测节点或providers
	if [ -z "$(cat $core_config_new | grep -E 'server|proxy-providers' | grep -v 'nameserver' | head -n 1)" ];then
		echo -----------------------------------------------
		logger "获取到了配置文件，但似乎并不包含正确的节点信息！" 31
		echo -----------------------------------------------
		sed -n '1,30p' $core_config_new
		echo -----------------------------------------------
		echo -e "\033[33m请检查如上配置文件信息:\033[0m"
		echo -----------------------------------------------
		exit 1
	fi
	#检测旧格式
	if cat $core_config_new | grep 'Proxy Group:' >/dev/null;then
		echo -----------------------------------------------
		logger "已经停止对旧格式配置文件的支持！！！" 31
		echo -e "请使用新格式或者使用【在线生成配置文件】功能！"
		echo -----------------------------------------------
		exit 1
	fi
	#检测不支持的加密协议
	if cat $core_config_new | grep 'cipher: chacha20,' >/dev/null;then
		echo -----------------------------------------------
		logger "已停止支持chacha20加密，请更换更安全的节点加密协议！" 31
		echo -----------------------------------------------
		exit 1
	fi
	#检测并去除无效策略组
	[ -n "$url_type" ] && ckcmd xargs && {
		cat $core_config_new | sed '/^rules:/,$d' | grep -A 15 "\- name:" | xargs | sed 's/- name: /\n/g' | sed 's/ type: .*proxies: /#/g' | sed 's/- //g' | grep -E '#DIRECT $|#DIRECT$' | awk -F '#' '{print $1}' > ${TMPDIR}/clash_proxies_$USER
		while read line ;do
			sed -i "/- $line/d" $core_config_new
			sed -i "/- name: $line/,/- DIRECT/d" $core_config_new
		done < ${TMPDIR}/clash_proxies_$USER
		rm -rf ${TMPDIR}/clash_proxies_$USER
	}
}
check_singbox_config(){ #检查singbox配置文件
	#检测节点或providers
	if [ -z "$(cat $core_config_new | grep -Eo '"server":|"outbound_providers":' )" ];then
		echo -----------------------------------------------
		logger "获取到了配置文件【$core_config_new】，但似乎并不包含正确的节点信息！" 31
		exit 1
	fi
	#检测并去除无效策略组
	[ -n "$url_type" ] && {
		#获得无效策略组名称
		grep -oE '\{"type":"[^"]*","tag":"[^"]*","outbounds":\["DIRECT"\]' $core_config_new | sed -n 's/.*"tag":"\([^"]*\)".*/\1/p' > ${TMPDIR}/singbox_tags
		#删除策略组
		sed -i 's/{"type":"[^"]*","tag":"[^"]*","outbounds":\["DIRECT"\]}//g; s/{"type":"[^"]*","tag":"[^"]*","outbounds":\["DIRECT"\],"url":"[^"]*","interval":"[^"]*","tolerance":[^}]*}//g' $core_config_new
		#删除全部包含策略组名称的规则
		while read line ;do
			sed -i "s/\"$line\"//g" $core_config_new
		done < ${TMPDIR}/singbox_tags
		rm -rf ${TMPDIR}/singbox_tags
		#删除多余逗号
		sed -i 's/,\+/,/g; s/\[,/\[/g; s/,]/]/g' $core_config_new
	} 
}
get_core_config(){ #下载内核配置文件
	getconfig
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	Server=$(grep -aE '^3|^4' ${CRASHDIR}/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	[ -n "$(echo $Url | grep -oE 'vless:|hysteria:')" ] && Server=$(grep -aE '^4' ${CRASHDIR}/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	[ "$retry" = 4 ] && Server=$(grep -aE '^497' ${CRASHDIR}/configs/servers.list | awk '{print $3}')
	Config=$(grep -aE '^5' ${CRASHDIR}/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $3}')
	#如果传来的是Url链接则合成Https链接，否则直接使用Https链接
	if [ -z "$Https" ];then
		#Urlencord转码处理保留字符
		Url=$(echo $Url | sed 's/;/\%3B/g; s|/|\%2F|g; s/?/\%3F/g; s/:/\%3A/g; s/@/\%40/g; s/=/\%3D/g; s/&/\%26/g')
		Https="${Server}/sub?target=${target}&insert=true&new_name=true&scv=true&udp=true&exclude=${exclude}&include=${include}&url=${Url}&config=${Config}"
		url_type=true
	fi
	#输出
	echo -----------------------------------------------
	logger 正在连接服务器获取【${target}】配置文件…………
	echo -e "链接地址为：\033[4;32m$Https\033[0m"
	echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
	#获取在线config文件
	core_config_new=${TMPDIR}/${target}_config.${format}
	rm -rf ${core_config_new}
	$0 webget "$core_config_new" "$Https"
	if [ "$?" = "1" ];then
		if [ -z "$url_type" ];then
			echo -----------------------------------------------
			logger "配置文件获取失败！" 31
			echo -e "\033[31m请尝试使用【在线生成配置文件】功能！\033[0m"
			echo -----------------------------------------------
			exit 1
		else
			if [ "$retry" = 4 ];then
				logger "无法获取配置文件，请检查链接格式以及网络连接状态！" 31
				echo -e "\033[32m也可用浏览器下载以上链接后，使用WinSCP手动上传到/tmp目录后执行crash命令本地导入！\033[0m"
				exit 1
			elif [ "$retry" = 3 ];then
				retry=4
				logger "配置文件获取失败！将尝试使用http协议备用服务器获取！" 31
				echo -e "\033[32m如担心数据安全，请在3s内使用【Ctrl+c】退出！\033[0m"
				sleep 3
				Https=""
				get_core_config
			else
				retry=$((retry+1))
				logger "配置文件获取失败！" 31
				echo -e "\033[32m尝试使用其他服务器获取配置！\033[0m"
				logger "正在重试第$retry次/共4次！" 33
				if [ "$server_link" -ge 5 ]; then
					server_link=0
				fi
				server_link=$((server_link+1))
				setconfig server_link $server_link
				Https=""
				get_core_config
			fi
		fi
	else
		Https=""
		[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && check_singbox_config || check_clash_config
		#如果不同则备份并替换文件
		if [ -s $core_config ];then
			compare $core_config_new $core_config
			[ "$?" = 0 ] || mv -f $core_config $core_config.bak && mv -f $core_config_new $core_config
		else
			mv -f $core_config_new $core_config
		fi
		echo -e "\033[32m已成功获取配置文件！\033[0m"
	fi
}
modify_yaml(){ #修饰clash配置文件
##########需要变更的配置###########
	[ -z "$dns_nameserver" ] && dns_nameserver='114.114.114.114, 223.5.5.5'
	[ -z "$dns_fallback" ] && dns_fallback='1.0.0.1, 8.8.4.4'
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ "$ipv6_support" = "已开启" ] && ipv6='ipv6: true' || ipv6='ipv6: false'
	[ "$ipv6_dns" = "已开启" ] && dns_v6='true' || dns_v6='false'
	external="external-controller: 0.0.0.0:$db_port"
	if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ];then
		[ "$crashcore" = 'meta' ] && tun_meta=', device: utun, auto-route: false'
		tun="tun: {enable: true, stack: system$tun_meta}"
	else
		tun='tun: {enable: false}'
	fi
	exper='experimental: {ignore-resolve-fail: true, interface-name: en0}'
	#Meta内核专属配置
	[ "$crashcore" = 'meta' ] && {
		[ "$redir_mod" != "纯净模式" ] && find_process='find-process-mode: "off"'
	}
	#dns配置
	[ -z "$(cat ${CRASHDIR}/yamls/user.yaml 2>/dev/null | grep '^dns:')" ] && { 
		[ "$crashcore" = 'meta' ] && dns_default_meta='- https://223.5.5.5/dns-query'
		cat > ${TMPDIR}/dns.yaml <<EOF
dns:
  enable: true
  listen: 0.0.0.0:$dns_port
  use-hosts: true
  ipv6: $dns_v6
  default-nameserver:
    - 114.114.114.114
    - 223.5.5.5
    $dns_default_meta
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
EOF
		if [ "$dns_mod" = "fake-ip" ];then
			cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep '\.' | sed "s/^/    - '/" | sed "s/$/'/" >> ${TMPDIR}/dns.yaml
		else
			echo "    - '+.*'" >> ${TMPDIR}/dns.yaml #使用fake-ip模拟redir_host
		fi
		cat >> ${TMPDIR}/dns.yaml <<EOF
  nameserver: [$dns_nameserver]
  fallback: [$dns_fallback]
  fallback-filter:
    geoip: true
EOF
		[ -s ${CRASHDIR}/configs/fallback_filter.list ] && {
			echo "    domain:" >> ${TMPDIR}/dns.yaml
			cat ${CRASHDIR}/configs/fallback_filter.list | grep '\.' | sed "s/^/      - '/" | sed "s/$/'/" >> ${TMPDIR}/dns.yaml
		}		
}
	#域名嗅探配置
	[ "$sniffer" = "已启用" ] && [ "$crashcore" = "meta" ] && sniffer_set="sniffer: {enable: true, skip-domain: [Mijia Cloud], sniff: {tls: {ports: [443, 8443]}, http: {ports: [80, 8080-8880]}}}"
	[ "$crashcore" = "clashpre" ] && [ "$dns_mod" = "redir_host" ] && exper="experimental: {ignore-resolve-fail: true, interface-name: en0, sniff-tls-sni: true}"
	#生成set.yaml
	cat > ${TMPDIR}/set.yaml <<EOF
mixed-port: $mix_port
redir-port: $redir_port
tproxy-port: $tproxy_port
authentication: ["$authentication"]
allow-lan: true
mode: Rule
log-level: info
$ipv6
external-controller: :$db_port
external-ui: ui
secret: $secret
$tun
$exper
$sniffer_set
$find_process
EOF
	#读取本机hosts并生成配置文件
	if [ "$hosts_opt" != "未启用" ] && [ -z "$(grep -aE '^hosts:' ${CRASHDIR}/yamls/user.yaml 2>/dev/null)" ];then
		#NTP劫持
		cat >> ${TMPDIR}/hosts.yaml <<EOF
hosts:
   'time.android.com': 203.107.6.88
   'time.facebook.com': 203.107.6.88  
EOF
		#加载本机hosts
		sys_hosts=/etc/hosts
		[ -f /data/etc/custom_hosts ] && sys_hosts=/data/etc/custom_hosts
		while read line;do
			[ -n "$(echo "$line" | grep -oE "([0-9]{1,3}[\.]){3}" )" ] && \
			[ -z "$(echo "$line" | grep -oE '^#')" ] && \
			hosts_ip=$(echo $line | awk '{print $1}')  && \
			hosts_domain=$(echo $line | awk '{print $2}') && \
			[ -z "$(cat ${TMPDIR}/hosts.yaml | grep -oE "$hosts_domain")" ] && \
			echo "   '$hosts_domain': $hosts_ip" >> ${TMPDIR}/hosts.yaml
		done < $sys_hosts
	fi	
	#分割配置文件
	yaml_char='proxies proxy-groups proxy-providers rules rule-providers'
	for char in $yaml_char;do
		sed -n "/^$char:/,/^[a-z]/ { /^[a-z]/d; p; }" $core_config > ${TMPDIR}/${char}.yaml
	done
	#跳过本地tls证书验证
	[ "$skip_cert" = "已开启" ] && sed -i 's/skip-cert-verify: false/skip-cert-verify: true/' ${TMPDIR}/proxies.yaml || \
		sed -i 's/skip-cert-verify: true/skip-cert-verify: false/' ${TMPDIR}/proxies.yaml
	#插入自定义策略组
	sed -i "/#自定义策略组开始/,/#自定义策略组结束/d" ${TMPDIR}/proxy-groups.yaml
	sed -i "/#自定义策略组/d" ${TMPDIR}/proxy-groups.yaml
	[ -n "$(grep -Ev '^#' ${CRASHDIR}/yamls/proxy-groups.yaml 2>/dev/null)" ] && {
		#获取空格数
		space_name=$(grep -aE '^ *- name: ' ${TMPDIR}/proxy-groups.yaml | head -n 1 | grep -oE '^ *') 
		space_proxy=$(grep -A 1 'proxies:$' ${TMPDIR}/proxy-groups.yaml | grep -aE '^ *- ' | head -n 1 | grep -oE '^ *') 
		#合并自定义策略组到proxy-groups.yaml
		cat ${CRASHDIR}/yamls/proxy-groups.yaml | sed "/^#/d" | sed "s/#.*//g" | sed '1i\ #自定义策略组开始' | sed '$a\ #自定义策略组结束' | sed "s/^ */${space_name}  /g" | sed "s/^ *- /${space_proxy}- /g" | sed "s/^ *- name: /${space_name}- name: /g" > ${TMPDIR}/proxy-groups_add.yaml 
		cat ${TMPDIR}/proxy-groups.yaml  >> ${TMPDIR}/proxy-groups_add.yaml
		mv -f ${TMPDIR}/proxy-groups_add.yaml ${TMPDIR}/proxy-groups.yaml
		oldIFS="$IFS"
		grep "\- name: " ${CRASHDIR}/yamls/proxy-groups.yaml | sed "/^#/d" | while read line;do #将自定义策略组插入现有的proxy-group
				new_group=$(echo $line | grep -Eo '^ *- name:.*#' | cut -d'#' -f1 | sed 's/.*name: //g')
				proxy_groups=$(echo $line | grep -Eo '#.*' | sed "s/#//" )
				IFS="#"
				for name in $proxy_groups; do
					line_a=$(grep -n "\- name: $name" ${TMPDIR}/proxy-groups.yaml | awk -F: '{print $1}') #获取group行号
					[ -n "$line_a" ] && {
						line_b=$(grep -A 8 "\- name: $name" ${TMPDIR}/proxy-groups.yaml | grep -n "proxies:$" | awk -F: '{print $1}') #获取proxies行号
						line_c=$((line_a + line_b - 1)) #计算需要插入的行号
						space=$(sed -n "$((line_c + 1))p" ${TMPDIR}/proxy-groups.yaml | grep -oE '^ *') #获取空格数
						[ "$line_c" -gt 2 ] && sed -i "${line_c}a\\${space}- ${new_group} #自定义策略组" ${TMPDIR}/proxy-groups.yaml
					}
				done
				IFS="$oldIFS"
		done
	}	
	#插入自定义代理
	sed -i "/#自定义代理/d" ${TMPDIR}/proxies.yaml
	sed -i "/#自定义代理/d" ${TMPDIR}/proxy-groups.yaml
	[ -n "$(grep -Ev '^#' ${CRASHDIR}/yamls/proxies.yaml 2>/dev/null)" ] && {
		space_proxy=$(cat ${TMPDIR}/proxies.yaml | grep -aE '^ *- ' | head -n 1 | grep -oE '^ *') #获取空格数
		cat ${CRASHDIR}/yamls/proxies.yaml | sed "s/^ *- /${space_proxy}- /g" | sed "/^#/d" | sed "/^ *$/d" | sed 's/#.*/ #自定义代理/g' >> ${TMPDIR}/proxies.yaml #插入节点
		oldIFS="$IFS"
		cat ${CRASHDIR}/yamls/proxies.yaml | sed "/^#/d" | while read line;do #将节点插入proxy-group
				proxy_name=$(echo $line | grep -Eo 'name: .+, ' | cut -d',' -f1 | sed 's/name: //g')
				proxy_groups=$(echo $line | grep -Eo '#.*' | sed "s/#//" )
				IFS="#"
				for name in $proxy_groups; do
					line_a=$(grep -n "\- name: $name" ${TMPDIR}/proxy-groups.yaml | awk -F: '{print $1}') #获取group行号
					[ -n "$line_a" ] && {
						line_b=$(grep -A 8 "\- name: $name" ${TMPDIR}/proxy-groups.yaml | grep -n "proxies:$" | head -n 1 | awk -F: '{print $1}') #获取proxies行号
						line_c=$((line_a + line_b - 1)) #计算需要插入的行号
						space=$(sed -n "$((line_c + 1))p" ${TMPDIR}/proxy-groups.yaml | grep -oE '^ *') #获取空格数
						[ "$line_c" -gt 2 ] && sed -i "${line_c}a\\${space}- ${proxy_name} #自定义代理" ${TMPDIR}/proxy-groups.yaml
					}
				done
				IFS="$oldIFS"
		done
	}
	#节点绕过功能支持
	sed -i "/#节点绕过/d" ${TMPDIR}/rules.yaml
	[ "$proxies_bypass" = "已启用" ] && {
		cat ${TMPDIR}/proxies.yaml | sed '/^proxy-/,$d' | sed '/^rule-/,$d' | grep -v '^\s*#' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | awk '!a[$0]++' | sed 's/^/\ -\ IP-CIDR,/g' | sed 's|$|/32,DIRECT,no-resolve #节点绕过|g' >> ${TMPDIR}/proxies_bypass
		cat ${TMPDIR}/proxies.yaml | sed '/^proxy-/,$d' | sed '/^rule-/,$d' | grep -v '^\s*#' | grep -vE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?'| awk '!a[$0]++' | sed 's/^/\ -\ DOMAIN,/g' | sed 's/$/,DIRECT #节点绕过/g' >> ${TMPDIR}/proxies_bypass
		cat ${TMPDIR}/rules.yaml >> ${TMPDIR}/proxies_bypass 
		mv -f ${TMPDIR}/proxies_bypass ${TMPDIR}/rules.yaml
	}
	#插入自定义规则
	sed -i "/#自定义规则/d" ${TMPDIR}/rules.yaml
	[ -s ${CRASHDIR}/yamls/rules.yaml ] && {
		cat ${CRASHDIR}/yamls/rules.yaml | sed "/^#/d" | sed '$a\' | sed 's/$/ #自定义规则/g' > ${TMPDIR}/rules.add
		cat ${TMPDIR}/rules.yaml >> ${TMPDIR}/rules.add
		mv -f ${TMPDIR}/rules.add ${TMPDIR}/rules.yaml
	}
	#对齐rules中的空格
	sed -i 's/^ *-/ -/g' ${TMPDIR}/rules.yaml
	#合并文件
	[ -s ${CRASHDIR}/yamls/user.yaml ] && {
		yaml_user=${CRASHDIR}/yamls/user.yaml
		#set和user去重,且优先使用user.yaml
		cp -f ${TMPDIR}/set.yaml ${TMPDIR}/set_bak.yaml
		for char in mode allow-lan log-level tun experimental interface-name dns store-selected;do
			[ -n "$(grep -E "^$char" $yaml_user)" ] && sed -i "/^$char/d" ${TMPDIR}/set.yaml
		done
	}
	[ -s ${TMPDIR}/dns.yaml ] && yaml_dns=${TMPDIR}/dns.yaml
	[ -s ${TMPDIR}/hosts.yaml ] && yaml_hosts=${TMPDIR}/hosts.yaml
	[ -s ${CRASHDIR}/yamls/others.yaml ] && yaml_others=${CRASHDIR}/yamls/others.yaml
	yaml_add=
	for char in $yaml_char;do #将额外配置文件合并
		[ -s ${TMPDIR}/${char}.yaml ] && {
			sed -i "1i\\${char}:" ${TMPDIR}/${char}.yaml
			yaml_add="$yaml_add ${TMPDIR}/${char}.yaml"
		}
	done	
	#合并完整配置文件
	cut -c 1- ${TMPDIR}/set.yaml $yaml_dns $yaml_hosts $yaml_user $yaml_others $yaml_add > ${TMPDIR}/config.yaml
	#测试自定义配置文件
	${TMPDIR}/CrashCore -t -d ${BINDIR} -f ${TMPDIR}/config.yaml >/dev/null
	if [ "$?" != 0 ];then
		logger "$(${TMPDIR}/CrashCore -t -d ${BINDIR} -f ${TMPDIR}/config.yaml | grep -Eo 'error.*=.*')" 31
		logger "自定义配置文件校验失败！将使用基础配置文件启动！" 33
		logger "错误详情请参考 ${TMPDIR}/error.yaml 文件！" 33
		mv -f ${TMPDIR}/config.yaml ${TMPDIR}/error.yaml &>/dev/null
		sed -i "/#自定义策略组开始/,/#自定义策略组结束/d"  ${TMPDIR}/proxy-groups.yaml
		mv -f ${TMPDIR}/set_bak.yaml ${TMPDIR}/set.yaml &>/dev/null
		#合并基础配置文件
		cut -c 1- ${TMPDIR}/set.yaml $yaml_dns $yaml_add > ${TMPDIR}/config.yaml
		sed -i "/#自定义/d" ${TMPDIR}/config.yaml 
	fi
	#建立软连接
	[ "${TMPDIR}" = "${BINDIR}" ] || ln -sf ${TMPDIR}/config.yaml ${BINDIR}/config.yaml
	#清理缓存
	for char in $yaml_char set set_bak dns hosts;do
		rm -f ${TMPDIR}/${char}.yaml
	done
}
modify_json(){ #修饰singbox配置文件
	#生成log.json
	cat > ${TMPDIR}/jsons/log.json <<EOF
{ "log": { "level": "info", "timestamp": true } }
EOF
	#生成add_hosts.json
	if [ "$hosts_opt" != "未启用" ];then #本机hosts
		sys_hosts=/etc/hosts
		[ -s /data/etc/custom_hosts ] && sys_hosts=/data/etc/custom_hosts
		#NTP劫持
		[ -s $sys_hosts ] && {
		sed -i '/203.107.6.88/d' $sys_hosts
		cat >> $sys_hosts <<EOF
203.107.6.88 time.android.com
203.107.6.88 time.facebook.com
EOF
		hosts_domain=$(cat $sys_hosts | grep -E "^([0-9]{1,3}[\.]){3}" | awk '{printf "\"%s\", ", $2}' | sed 's/, $//' )
		cat > ${TMPDIR}/jsons/add_hosts.json <<EOF
{
  "dns": { 
    "rules": [{
      "domain": [$hosts_domain],
      "server": "dns_local"
    }]
  }
}
EOF
}
	fi
	#生成dns.json
	dns_direct=\"$(echo $dns_nameserver | awk -F ',' '{print $1}')\"
	dns_proxy=\"$(echo $dns_fallback | awk -F ',' '{print $1}')\"
	[ -z "$dns_direct" ] && dns_direct='223.5.5.5'
	[ -z "$dns_proxy" ] && dns_proxy='1.0.0.1'
	[ "$ipv6_dns" = "已开启" ] && strategy='prefer_ipv4' || strategy='ipv4_only'
	[ "$dns_mod" = "redir_host" ] && final_dns=dns_direct && global_dns=dns_proxy
	[ "$dns_mod" = "fake-ip" ] && final_dns=dns_fakeip && global_dns=dns_fakeip
	[ "$dns_mod" = "mix" ] && {
		final_dns=dns_direct && global_dns=dns_fakeip
		mix_dns="{ \"rule_set\": [\"geosite-cn\"], \"invert\": true, \"server\": \"dns_fakeip\" },"
		#生成add_rule_set.json
		[ -z "$(cat ${CRASHDIR}/jsons/*.json | grep -Ei '\"tag\": \"geosite-cn\"')" ] && cat > ${TMPDIR}/jsons/add_rule_set.json <<EOF
{
  "route": {
	"rule_set": [
      {
        "tag": "geosite-cn",
        "type": "local",
        "format": "binary",
        "path": "geosite-cn.srs"
      }
	]
  }
}
EOF
	}
	cat > ${TMPDIR}/jsons/dns.json <<EOF
{
  "dns": { 
    "servers": [
	  {
        "tag": "dns_proxy",
        "address": $dns_proxy,
        "strategy": "$strategy",
        "address_resolver": "dns_resolver"
      }, {
        "tag": "dns_direct",
        "address": $dns_direct,
        "strategy": "$strategy",
        "address_resolver": "dns_resolver",
        "detour": "DIRECT"
      }, {
        "tag": "dns_fakeip",
        "address": "fakeip"
      }, {
        "tag": "dns_resolver",
        "address": "223.5.5.5",
        "detour": "DIRECT"
      }, {
        "tag": "dns_local",
        "address": "local"
      }, {
        "tag": "block",
        "address": "rcode://success"
      }
	],
    "rules": [
	  { "outbound": ["any"], "server": "dns_resolver" },
	  { "clash_mode": "Global", "server": "$global_dns" },
      { "clash_mode": "Direct", "server": "dns_direct" },
	  $mix_dns
	  { "query_type": [ "A", "AAAA" ], "server": "$final_dns" }
	],
    "final": "dns_direct",
    "independent_cache": true,
    "reverse_mapping": true,
    "fakeip": { "enabled": true, "inet4_range": "198.18.0.0/16", "inet6_range": "fc00::/16" }
  }
}
EOF
	#生成add_route.json
	cat > ${TMPDIR}/jsons/add_route.json <<EOF
{
  "route": {
    "rules": [ 
	{ "inbound": "dns-in", "outbound": "dns-out" }
	]
  }
}
EOF
	#生成ntp.json
	cat > ${TMPDIR}/jsons/ntp.json <<EOF
{
  "ntp": {
    "enabled": true,
    "server": "203.107.6.88",
    "server_port": 123,
    "interval": "30m0s",
    "detour": "DIRECT"
  }
}
EOF
	#生成inbounds.json
	[ -n "$authentication" ] && {
		username=$(echo $authentication | awk -F ':' '{print $1}') #混合端口账号密码
		password=$(echo $authentication | awk -F ':' '{print $2}')
		userpass=', "users": [{ "username": "'$username'", "password": "'$password'" }]'
	}
	[ "$sniffer" = "已启用" ] && sniffer=true || sniffer=false #域名嗅探配置
		
	cat > ${TMPDIR}/jsons/inbounds.json <<EOF
{
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "0.0.0.0",
      "listen_port": $mix_port,
      "sniff": false$userpass
    }, {
      "type": "direct",
      "tag": "dns-in",
      "listen": "::",
      "listen_port": $dns_port
    }, {
      "type": "redirect",
      "tag": "redirect-in",
      "listen": "::",
      "listen_port": $redir_port,
      "sniff": true,
      "sniff_override_destination": $sniffer
    }, {
      "type": "tproxy",
      "tag": "tproxy-in",
      "listen": "::",
      "listen_port": $tproxy_port,
      "sniff": true,
      "sniff_override_destination": $sniffer
    }
  ]
}
EOF
	if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ];then
		cat >> ${TMPDIR}/jsons/tun.json <<EOF
{
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "utun",
      "inet4_address": "198.18.0.0/16",
      "auto_route": false,
      "stack": "system",
      "sniff": true,
      "sniff_override_destination": $sniffer
    }
  ]
}
EOF
	fi
	#生成experimental.json
	cat > ${TMPDIR}/jsons/experimental.json <<EOF
{
  "experimental": {
    "clash_api": {
      "external_controller": "0.0.0.0:$db_port",
      "external_ui": "ui",
      "secret": "$secret",
      "default_mode": "Rule"
    }
  }
}
EOF
	#生成自定义规则文件
	[ -s ${CRASHDIR}/yamls/rules.yaml ] && {
		cat ${CRASHDIR}/yamls/rules.yaml \
			| sed '/#.*/d' \
			| grep -oE '\-.*,.*,.*' \
			| sed 's/- DOMAIN-SUFFIX,/{ "domain_suffix": [ "/g' \
			| sed 's/- DOMAIN-KEYWORD,/{ "domain_keyword": [ "/g' \
			| sed 's/- IP-CIDR,/{ "ip_cidr": [ "/g' \
			| sed 's/- SRC-IP-CIDR,/{ "source_ip_cidr": [ "/g' \
			| sed 's/- DST-PORT,/{ "port": [ "/g' \
			| sed 's/- SRC-PORT,/{ "source_port": [ "/g' \
			| sed 's/- GEOIP,/{ "geoip": [ "/g' \
			| sed 's/- GEOSITE,/{ "geosite": [ "/g' \
			| sed 's/- IP-CIDR6,/{ "ip_cidr": [ "/g' \
			| sed 's/- DOMAIN,/{ "domain": [ "/g' \
			| sed 's/,/" ], "outbound": "/g' \
			| sed 's/$/" },/g' \
			| sed '1i\{ "route": { "rules": [ ' \
			| sed '$s/,$/ ] } }/' > ${TMPDIR}/jsons/cust_add_rules.json
	}
	#提取配置文件以获得outbounds.json,outbound_providers.json及route.json
	${TMPDIR}/CrashCore format -c $core_config > ${TMPDIR}/format.json
	echo '{' > ${TMPDIR}/jsons/outbounds.json
	echo '{' > ${TMPDIR}/jsons/route.json
	cat ${TMPDIR}/format.json | sed -n '/"outbounds":/,/^  "[a-z]/p' | sed '$d' >> ${TMPDIR}/jsons/outbounds.json
	[ "$crashcore" = "singboxp" ] && {
		echo '{' > ${TMPDIR}/jsons/outbound_providers.json
		cat ${TMPDIR}/format.json | sed -n '/"outbound_providers":/,/^  "[a-z]/p}' | sed '$d' >> ${TMPDIR}/jsons/outbound_providers.json
	}
	cat ${TMPDIR}/format.json | sed -n '/"route":/,/^\(  "[a-z]\|}\)/p}' | sed '$d' >> ${TMPDIR}/jsons/route.json
	#清理route.json中的process_name规则以及"auto_detect_interface"
	sed -i '/"process_name": \[/,/],$/d' ${TMPDIR}/jsons/route.json
	sed -i '/"process_name": "[^"]*",/d' ${TMPDIR}/jsons/route.json
	sed -i 's/"auto_detect_interface": true/"auto_detect_interface": false/g' ${TMPDIR}/jsons/route.json
	#跳过本地tls证书验证
	if [ -z "$skip_cert" -o "$skip_cert" = "已开启" ];then
		sed -i 's/"insecure": false/"insecure": true/' ${TMPDIR}/jsons/outbounds.json
	else
		sed -i 's/"insecure": true/"insecure": false/' ${TMPDIR}/jsons/outbounds.json
	fi
	#判断可用并修饰outbounds&outbound_providers&route.json结尾
	for file in outbounds outbound_providers route;do
		if [ -n "$(grep ${file} ${TMPDIR}/jsons/${file}.json 2>/dev/null)" ];then
			sed -i 's/^  },$/  }/; s/^  ],$/  ]/' ${TMPDIR}/jsons/${file}.json
			echo '}' >> ${TMPDIR}/jsons/${file}.json
		else
			rm -rf ${TMPDIR}/jsons/${file}.json
		fi
	done
	#加载自定义配置文件
	mkdir -p ${TMPDIR}/jsons_base
	for char in log dns ntp experimental;do
		[ -s ${CRASHDIR}/jsons/${char}.json ] && {
			ln -sf ${CRASHDIR}/jsons/${char}.json ${TMPDIR}/jsons/cust_${char}.json
			mv -f ${TMPDIR}/jsons/${char}.json ${TMPDIR}/jsons_base #如果重复则临时备份
		}
	done
	for char in others inbounds outbounds outbound_providers route rule-set;do
		[ -s ${CRASHDIR}/jsons/${char}.json ] && {
			ln -sf ${CRASHDIR}/jsons/${char}.json ${TMPDIR}/jsons/cust_${char}.json
		}
	done
	#测试自定义配置文件
	error=$(${TMPDIR}/CrashCore check -D ${BINDIR} -C ${TMPDIR}/jsons 2>&1 )
	if [ -n "$error" ];then
		echo $error
		error_file=$(echo $error | grep -Eo 'cust.*\.json' | sed 's/cust_//g' )
		[ "$error_file" = 'add_rules.json' ] && error_file=${CRASHDIR}/yamls/rules.yaml自定义规则 || error_file=${CRASHDIR}/jsons/$error_file
		logger "自定义配置文件校验失败，请检查【${error_file}】文件！" 31
		logger "尝试使用基础配置文件启动~" 33
		#清理自定义配置文件并还原基础配置
		rm -rf ${TMPDIR}/jsons/cust_*
		mv -f ${TMPDIR}/jsons_base/* ${TMPDIR}/jsons 2>/dev/null
	fi
	#清理缓存
	rm -rf ${TMPDIR}/*.json
	rm -rf ${TMPDIR}/jsons_base
	return 0
}

#设置路由规则
cn_ip_route(){	#CN-IP绕过
	[ -z "$(finds ${BINDIR}/cn_ip.txt -size +10 2>/dev/null)" ] && {
		if [ -f ${CRASHDIR}/cn_ip.txt ];then
			mv ${CRASHDIR}/cn_ip.txt ${BINDIR}/cn_ip.txt
		else
			logger "未找到cn_ip列表，正在下载！" 33
			get_bin ${BINDIR}/cn_ip.txt "bin/geodata/china_ip_list.txt"
			[ "$?" = "1" ] && rm -rf ${BINDIR}/cn_ip.txt && logger "列表下载失败！" 31 
		fi
	}
	[ -f ${BINDIR}/cn_ip.txt -a -z "$(echo $redir_mod|grep 'Nft')" ] && {
			# see https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/CN-ip-cidr.txt
			echo "create cn_ip hash:net family inet hashsize 10240 maxelem 10240" > ${TMPDIR}/cn_$USER.ipset
			awk '!/^$/&&!/^#/{printf("add cn_ip %s'" "'\n",$0)}' ${BINDIR}/cn_ip.txt >> ${TMPDIR}/cn_$USER.ipset
			ipset -! flush cn_ip 2>/dev/null
			ipset -! restore < ${TMPDIR}/cn_$USER.ipset 
			rm -rf cn_$USER.ipset
	}
}
cn_ipv6_route(){ #CN-IPV6绕过
	[ -z "$(finds ${BINDIR}/cn_ipv6.txt -size +10 2>/dev/null)" ] && {
		if [ -f ${CRASHDIR}/cn_ipv6.txt ];then
			mv ${CRASHDIR}/cn_ipv6.txt ${BINDIR}/cn_ipv6.txt
		else
			logger "未找到cn_ipv6列表，正在下载！" 33
			get_bin ${BINDIR}/cn_ipv6.txt "bin/geodata/china_ipv6_list.txt"
			[ "$?" = "1" ] && rm -rf ${BINDIR}/cn_ipv6.txt && logger "列表下载失败！" 31 
		fi
	}
	[ -f ${BINDIR}/cn_ipv6.txt -a -z "$(echo $redir_mod|grep 'Nft')" ] && {
			#ipv6
			#see https://ispip.clang.cn/all_cn_ipv6.txt
			echo "create cn_ip6 hash:net family inet6 hashsize 4096 maxelem 4096" > ${TMPDIR}/cn6_$USER.ipset
			awk '!/^$/&&!/^#/{printf("add cn_ip6 %s'" "'\n",$0)}' ${BINDIR}/cn_ipv6.txt >> ${TMPDIR}/cn6_$USER.ipset
			ipset -! flush cn_ip6 2>/dev/null
			ipset -! restore < ${TMPDIR}/cn6_$USER.ipset 
			rm -rf cn6_$USER.ipset
	}
}
start_redir(){ #iptables-redir
	#获取局域网host地址
	getlanip
	#流量过滤
	iptables -t nat -N shellcrash
	for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
		iptables -t nat -A shellcrash -d $ip -j RETURN
	done
	#绕过CN_IP
	[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && \
	iptables -t nat -A shellcrash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
	#局域网设备过滤
	if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
		for mac in $(cat ${CRASHDIR}/configs/mac); do #mac白名单
			iptables -t nat -A shellcrash -p tcp -m mac --mac-source $mac -j REDIRECT --to-ports $redir_port
		done
	else
		for mac in $(cat ${CRASHDIR}/configs/mac); do #mac黑名单
			iptables -t nat -A shellcrash -m mac --mac-source $mac -j RETURN
		done
		#仅代理本机局域网网段流量
		for ip in $host_ipv4;do
			iptables -t nat -A shellcrash -p tcp -s $ip -j REDIRECT --to-ports $redir_port
		done
	fi
	#将PREROUTING链指向shellcrash链
	iptables -t nat -A PREROUTING -p tcp $ports -j shellcrash
	[ "$dns_mod" != "redir_host" -a "$common_ports" = "已开启" ] && iptables -t nat -A PREROUTING -p tcp -d 198.18.0.0/16 -j shellcrash
	#设置ipv6转发
	if [ "$ipv6_redir" = "已开启" ] && ip6tables -t nat -L &>/dev/null;then
		ip6tables -t nat -N shellcrashv6
		for ip in $reserve_ipv6 $host_ipv6;do #跳过目标保留地址及目标本机网段
			ip6tables -t nat -A shellcrashv6 -d $ip -j RETURN
		done
		#绕过CN_IPV6
		[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" ] && \
		ip6tables -t nat -A shellcrashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
		#局域网设备过滤
		if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
			for mac in $(cat ${CRASHDIR}/configs/mac); do #mac白名单
				ip6tables -t nat -A shellcrashv6 -p tcp -m mac --mac-source $mac -j REDIRECT --to-ports $redir_port
			done
		else
			for mac in $(cat ${CRASHDIR}/configs/mac); do #mac黑名单
				ip6tables -t nat -A shellcrashv6 -m mac --mac-source $mac -j RETURN
			done
			#仅代理本机局域网网段流量
			for ip in $host_ipv6;do
				ip6tables -t nat -A shellcrashv6 -p tcp -s $ip -j REDIRECT --to-ports $redir_port
			done
		fi
		ip6tables -t nat -A PREROUTING -p tcp $ports -j shellcrashv6
	fi
	return 0
}
start_ipt_dns(){ #iptables-dns
	#屏蔽OpenWrt内置53端口转发
	[ "$(uci get dhcp.@dnsmasq[0].dns_redirect 2>/dev/null)" = 1 ] && {
		uci del dhcp.@dnsmasq[0].dns_redirect
		uci commit dhcp.@dnsmasq[0]
	}
	#设置dns转发
	iptables -t nat -N shellcrash_dns
	if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
		for mac in $(cat ${CRASHDIR}/configs/mac); do #mac白名单
			iptables -t nat -A shellcrash_dns -p udp -m mac --mac-source $mac -j REDIRECT --to $dns_port
		done
	else
		for mac in $(cat ${CRASHDIR}/configs/mac); do #mac黑名单
			iptables -t nat -A shellcrash_dns -m mac --mac-source $mac -j RETURN
		done	
		iptables -t nat -A shellcrash_dns -p tcp -j REDIRECT --to $dns_port
		iptables -t nat -A shellcrash_dns -p udp -j REDIRECT --to $dns_port
	fi
	iptables -t nat -I PREROUTING -p tcp --dport 53 -j shellcrash_dns
	iptables -t nat -I PREROUTING -p udp --dport 53 -j shellcrash_dns
	#ipv6DNS
	if [ -n "$(lsmod | grep 'ip6table_nat')" -a -n "$(lsmod | grep 'xt_nat')" ];then
		ip6tables -t nat -N shellcrashv6_dns > /dev/null 2>&1
		if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
			for mac in $(cat ${CRASHDIR}/configs/mac); do #mac白名单
				ip6tables -t nat -A shellcrashv6_dns -p udp -m mac --mac-source $mac -j REDIRECT --to $dns_port
			done
		else
			for mac in $(cat ${CRASHDIR}/configs/mac); do #mac黑名单
				ip6tables -t nat -A shellcrashv6_dns -m mac --mac-source $mac -j RETURN
			done	
			ip6tables -t nat -A shellcrashv6_dns -p tcp -j REDIRECT --to $dns_port
			ip6tables -t nat -A shellcrashv6_dns -p udp -j REDIRECT --to $dns_port
		fi
		ip6tables -t nat -I PREROUTING -p tcp --dport 53 -j shellcrashv6_dns
		ip6tables -t nat -I PREROUTING -p udp --dport 53 -j shellcrashv6_dns
	else
		ip6tables -I INPUT -p udp --dport 53 -m comment --comment "ShellCrash-IPV6_DNS-REJECT" -j REJECT 2>/dev/null
	fi
	return 0

}
start_tproxy(){ #iptables-tproxy
	#获取局域网host地址
	getlanip
	modprobe xt_TPROXY &>/dev/null
	ip rule add fwmark $fwmark table 100
	ip route add local default dev lo table 100
	iptables -t mangle -N shellcrash
	iptables -t mangle -A shellcrash -p udp --dport 53 -j RETURN
	for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
		iptables -t mangle -A shellcrash -d $ip -j RETURN
	done
	#绕过CN_IP
	[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && \
	iptables -t mangle -A shellcrash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
	#tcp&udp分别进代理链
	tproxy_set(){
	if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
		for mac in $(cat ${CRASHDIR}/configs/mac); do #mac白名单
			iptables -t mangle -A shellcrash -p $1 -m mac --mac-source $mac -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
		done
	else
		for mac in $(cat ${CRASHDIR}/configs/mac); do #mac黑名单
			iptables -t mangle -A shellcrash -m mac --mac-source $mac -j RETURN
		done
		#仅代理本机局域网网段流量
		for ip in $host_ipv4;do
			iptables -t mangle -A shellcrash -p $1 -s $ip -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
		done			
	fi
	iptables -t mangle -A PREROUTING -p $1 $ports -j shellcrash
	[ "$dns_mod" != "redir_host" -a "$common_ports" = "已开启" ] && iptables -t mangle -A PREROUTING -p $1 -d 198.18.0.0/16 -j shellcrash
	}
	[ "$1" = "all" ] && tproxy_set tcp
	tproxy_set udp
	
	#屏蔽QUIC
	[ "$quic_rj" = 已启用 ] && {
		[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
		iptables -I INPUT -p udp --dport 443 -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip -j REJECT >/dev/null 2>&1
	}
	#设置ipv6转发
	[ "$ipv6_redir" = "已开启" ] && ip6tables -t nat -L &>/dev/null && {
		ip -6 rule add fwmark $fwmark table 101
		ip -6 route add local ::/0 dev lo table 101
		ip6tables -t mangle -N shellcrashv6
		ip6tables -t mangle -A shellcrashv6 -p udp --dport 53 -j RETURN
		for ip in $host_ipv6 $reserve_ipv6;do #跳过目标保留地址及目标本机网段
			ip6tables -t mangle -A shellcrashv6 -d $ip -j RETURN
		done
		#绕过CN_IPV6
		[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" ] && \
		ip6tables -t mangle -A shellcrashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
		#tcp&udp分别进代理链
		tproxy_set6(){
			if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
				#mac白名单
				for mac in $(cat ${CRASHDIR}/configs/mac); do
					ip6tables -t mangle -A shellcrashv6 -p $1 -m mac --mac-source $mac -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
				done
			else
				#mac黑名单
				for mac in $(cat ${CRASHDIR}/configs/mac); do
					ip6tables -t mangle -A shellcrashv6 -m mac --mac-source $mac -j RETURN
				done
				#仅代理本机局域网网段流量
				for ip in $host_ipv6;do
					ip6tables -t mangle -A shellcrashv6 -p $1 -s $ip -j TPROXY --on-port $tproxy_port --tproxy-mark $fwmark
				done
			fi	
			ip6tables -t mangle -A PREROUTING -p $1 $ports -j shellcrashv6		
		}
		[ "$1" = "all" ] && tproxy_set6 tcp
		tproxy_set6 udp
		
		#屏蔽QUIC
		[ "$quic_rj" = 已启用 ] && {
			[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" ] && set_cn_ip6='-m set ! --match-set cn_ip6 dst'
			ip6tables -I INPUT -p udp --dport 443 -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2>/dev/null
		}	
	}
}
start_output(){ #iptables本机代理
	#获取局域网host地址
	getlanip
	#流量过滤
	iptables -t nat -N shellcrash_out
	iptables -t nat -A shellcrash_out -m owner --gid-owner 7890 -j RETURN
	for ip in $local_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
		iptables -t nat -A shellcrash_out -d $ip -j RETURN
	done
	#绕过CN_IP
	[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && \
	iptables -t nat -A shellcrash_out -m set --match-set cn_ip dst -j RETURN >/dev/null 2>&1 
	#仅允许本机流量
	for ip in 127.0.0.0/8 $local_ipv4;do 
		iptables -t nat -A shellcrash_out -p tcp -s $ip -j REDIRECT --to-ports $redir_port
	done
	iptables -t nat -A OUTPUT -p tcp $ports -j shellcrash_out
	#设置dns转发
	[ "$dns_no" != "已禁用" ] && {
	iptables -t nat -N shellcrash_dns_out
	iptables -t nat -A shellcrash_dns_out -m owner --gid-owner 453 -j RETURN #绕过本机dnsmasq
	iptables -t nat -A shellcrash_dns_out -m owner --gid-owner 7890 -j RETURN
	iptables -t nat -A shellcrash_dns_out -p udp -j REDIRECT --to $dns_port
	iptables -t nat -A OUTPUT -p udp --dport 53 -j shellcrash_dns_out
	}
	#Docker转发
	ckcmd docker && {
		iptables -t nat -N shellcrash_docker
		for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
			iptables -t nat -A shellcrash_docker -d $ip -j RETURN
		done
		iptables -t nat -A shellcrash_docker -p tcp -j REDIRECT --to-ports $redir_port
		iptables -t nat -A PREROUTING -p tcp -s 172.16.0.0/12 -j shellcrash_docker
		[ "$dns_no" != "已禁用" ] && iptables -t nat -A PREROUTING -p udp --dport 53 -s 172.16.0.0/12 -j REDIRECT --to $dns_port
	}
}
start_tun(){ #iptables-tun
	modprobe tun &>/dev/null
	#允许流量
	iptables -I FORWARD -o utun -j ACCEPT
	iptables -I FORWARD -s 198.18.0.0/16 -o utun -j RETURN #防止回环
	ip6tables -I FORWARD -o utun -j ACCEPT > /dev/null 2>&1
	#屏蔽QUIC
	if [ "$quic_rj" = 已启用 ];then
		[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && {
			set_cn_ip='-m set ! --match-set cn_ip dst'
			set_cn_ip6='-m set ! --match-set cn_ip6 dst'
		}
		iptables -I FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip -j REJECT >/dev/null 2>&1 
		ip6tables -I FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip6 -j REJECT >/dev/null 2>&1
	fi
	modprobe xt_mark &>/dev/null && {
		i=1
		while [ -z "$(ip route list |grep utun)" -a "$i" -le 29 ];do
			sleep 1
			i=$((i+1))
		done
		if [ -z "$(ip route list |grep utun)" ];then
			logger "找不到tun模块，放弃启动tun相关防火墙规则！" 31
		else
			ip route add default dev utun table 100
			ip rule add fwmark $fwmark table 100
			#获取局域网host地址
			getlanip
			iptables -t mangle -N shellcrash
			iptables -t mangle -A shellcrash -p udp --dport 53 -j RETURN
			for ip in $host_ipv4 $reserve_ipv4;do #跳过目标保留地址及目标本机网段
				iptables -t mangle -A shellcrash -d $ip -j RETURN
			done
			#防止回环
			iptables -t mangle -A shellcrash -s 198.18.0.0/16 -j RETURN
			#绕过CN_IP
			[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && \
			iptables -t mangle -A shellcrash -m set --match-set cn_ip dst -j RETURN 2>/dev/null
			#局域网设备过滤
			if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
				for mac in $(cat ${CRASHDIR}/configs/mac); do #mac白名单
					iptables -t mangle -A shellcrash -m mac --mac-source $mac -j MARK --set-mark $fwmark
				done
			else
				for mac in $(cat ${CRASHDIR}/configs/mac); do #mac黑名单
					iptables -t mangle -A shellcrash -m mac --mac-source $mac -j RETURN
				done
				#仅代理本机局域网网段流量
				for ip in $host_ipv4;do
					iptables -t mangle -A shellcrash -s $ip -j MARK --set-mark $fwmark
				done
			fi
			iptables -t mangle -A PREROUTING -p udp $ports -j shellcrash
			[ "$1" = "all" ] && iptables -t mangle -A PREROUTING -p tcp $ports -j shellcrash
			
			#设置ipv6转发
			[ "$ipv6_redir" = "已开启" ] && ip6tables -t nat -L &>/dev/null && [ "$crashcore" != clash ] && {
				ip -6 route add default dev utun table 101
				ip -6 rule add fwmark $fwmark table 101
				ip6tables -t mangle -N shellcrashv6
				ip6tables -t mangle -A shellcrashv6 -p udp --dport 53 -j RETURN
				for ip in $host_ipv6 $reserve_ipv6;do #跳过目标保留地址及目标本机网段
					ip6tables -t mangle -A shellcrashv6 -d $ip -j RETURN
				done
				#绕过CN_IPV6
				[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" ] && \
				ip6tables -t mangle -A shellcrashv6 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
				#局域网设备过滤
				if [ "$macfilter_type" = "白名单" -a -n "$(cat ${CRASHDIR}/configs/mac)" ];then
					for mac in $(cat ${CRASHDIR}/configs/mac); do #mac白名单
						ip6tables -t mangle -A shellcrashv6 -m mac --mac-source $mac -j MARK --set-mark $fwmark
					done
				else
					for mac in $(cat ${CRASHDIR}/configs/mac); do #mac黑名单
						ip6tables -t mangle -A shellcrashv6 -m mac --mac-source $mac -j RETURN
					done
					#仅代理本机局域网网段流量
					for ip in $host_ipv6;do
						ip6tables -t mangle -A shellcrashv6 -s $ip -j MARK --set-mark $fwmark
					done					
				fi	
				ip6tables -t mangle -A PREROUTING -p udp $ports -j shellcrashv6		
				[ "$1" = "all" ] && ip6tables -t mangle -A PREROUTING -p tcp $ports -j shellcrashv6
			}
		fi
	}
}
start_nft(){ #nftables-allinone
	#获取局域网host地址
	getlanip
	[ "$common_ports" = "已开启" ] && PORTS=$(echo $multiport | sed 's/,/, /g')
	RESERVED_IP=$(echo $reserve_ipv4 | sed 's/ /, /g')
	LOCAL_IP="127.0.0.0/8, $(echo $local_ipv4 | sed 's/ /, /g')"
	HOST_IP=$(echo $host_ipv4 | sed 's/ /, /g')
	#设置策略路由
	ip rule add fwmark $fwmark table 100
	ip route add local default dev lo table 100
	[ "$redir_mod" = "Nft基础" ] && \
		nft add chain inet shellcrash prerouting { type nat hook prerouting priority -100 \; }
	[ "$redir_mod" = "Nft混合" ] && {
		modprobe nft_tproxy &> /dev/null
		nft add chain inet shellcrash prerouting { type filter hook prerouting priority 0 \; }
	}
	[ -n "$(echo $redir_mod|grep Nft)" ] && {
		#过滤局域网设备
		[ -n "$(cat ${CRASHDIR}/configs/mac)" ] && {
			MAC=$(awk '{printf "%s, ",$1}' ${CRASHDIR}/configs/mac)
			[ "$macfilter_type" = "黑名单" ] && \
				nft add rule inet shellcrash prerouting ether saddr {$MAC} return || \
				nft add rule inet shellcrash prerouting ether saddr != {$MAC} return
		}
		#过滤保留地址
		nft add rule inet shellcrash prerouting ip daddr {$RESERVED_IP} return
		#仅代理本机局域网网段流量
		nft add rule inet shellcrash prerouting ip saddr != {$HOST_IP} return
		#绕过CN-IP
		[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" -a -f ${BINDIR}/cn_ip.txt ] && {
			CN_IP=$(awk '{printf "%s, ",$1}' ${BINDIR}/cn_ip.txt)
			[ -n "$CN_IP" ] && nft add rule inet shellcrash prerouting ip daddr {$CN_IP} return
		}
		#过滤常用端口
		[ -n "$PORTS" ] && nft add rule inet shellcrash prerouting tcp dport != {$PORTS} ip daddr != {198.18.0.0/16} return
		#ipv6支持
		if [ "$ipv6_redir" = "已开启" ];then
			RESERVED_IP6="$(echo "$reserve_ipv6 $host_ipv6" | sed 's/ /, /g')"
			HOST_IP6="$(echo $host_ipv6 | sed 's/ /, /g')"
			ip -6 rule add fwmark $fwmark table 101 2> /dev/null
			ip -6 route add local ::/0 dev lo table 101 2> /dev/null
			#过滤保留地址及本机地址
			nft add rule inet shellcrash prerouting ip6 daddr {$RESERVED_IP6} return
			#仅代理本机局域网网段流量
			nft add rule inet shellcrash prerouting ip6 saddr != {$HOST_IP6} return
			#绕过CN_IPV6
			[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" -a -f ${BINDIR}/cn_ipv6.txt ] && {
				CN_IP6=$(awk '{printf "%s, ",$1}' ${BINDIR}/cn_ipv6.txt)
				[ -n "$CN_IP6" ] && nft add rule inet shellcrash prerouting ip6 daddr {$CN_IP6} return
			}
		else
			nft add rule inet shellcrash prerouting meta nfproto ipv6 return
		fi
		#透明路由
		[ "$redir_mod" = "Nft基础" ] && nft add rule inet shellcrash prerouting meta l4proto tcp mark set $fwmark redirect to $redir_port
		[ "$redir_mod" = "Nft混合" ] && nft add rule inet shellcrash prerouting meta l4proto {tcp, udp} mark set $fwmark tproxy to :$tproxy_port
	}
	#屏蔽QUIC
	[ "$quic_rj" = 已启用 ] && {
		nft add chain inet shellcrash input { type filter hook input priority 0 \; }
		[ -n "$CN_IP" ] && nft add rule inet shellcrash input ip daddr {$CN_IP} return
		[ -n "$CN_IP6" ] && nft add rule inet shellcrash input ip6 daddr {$CN_IP6} return
		nft add rule inet shellcrash input udp dport 443 reject comment 'ShellCrash-QUIC-REJECT'
	}
	#代理本机(仅TCP)
	[ "$local_proxy" = "已开启" ] && [ "$local_type" = "nftables增强模式" ] && {
		#dns
		nft add chain inet shellcrash dns_out { type nat hook output priority -100 \; }
		nft add rule inet shellcrash dns_out meta skgid { 453, 7890 } return && \
		nft add rule inet shellcrash dns_out udp dport 53 redirect to $dns_port
		#output
		nft add chain inet shellcrash output { type nat hook output priority -100 \; }
		nft add rule inet shellcrash output meta skgid 7890 return && {
			[ -n "$PORTS" ] && nft add rule inet shellcrash output tcp dport != {$PORTS} return
			nft add rule inet shellcrash output ip daddr {$RESERVED_IP} return
			nft add rule inet shellcrash output ip saddr != {$LOCAL_IP} return
			nft add rule inet shellcrash output meta l4proto tcp mark set $fwmark redirect to $redir_port
		}
		#Docker
		type docker &>/dev/null && {
			nft add chain inet shellcrash docker { type nat hook prerouting priority -100 \; }
			nft add rule inet shellcrash docker ip saddr != {172.16.0.0/12} return #进代理docker网段
			nft add rule inet shellcrash docker ip daddr {$RESERVED_IP} return #过滤保留地址
			nft add rule inet shellcrash docker udp dport 53 redirect to $dns_port
			nft add rule inet shellcrash docker meta l4proto tcp mark set $fwmark redirect to $redir_port
		}
	}
}
start_nft_dns(){ #nftables-dns
	nft add chain inet shellcrash dns { type nat hook prerouting priority -100 \; }
	#过滤局域网设备
	[ -n "$(cat ${CRASHDIR}/configs/mac)" ] && {
		MAC=$(awk '{printf "%s, ",$1}' ${CRASHDIR}/configs/mac)
		[ "$macfilter_type" = "黑名单" ] && \
			nft add rule inet shellcrash dns ether saddr {$MAC} return || \
			nft add rule inet shellcrash dns ether saddr != {$MAC} return
	}
	nft add rule inet shellcrash dns udp dport 53 redirect to ${dns_port}
	nft add rule inet shellcrash dns tcp dport 53 redirect to ${dns_port}
}
start_wan(){ #iptables公网访问防火墙
	#获取局域网host地址
	getlanip
	if [ "$public_support" = "已开启" ];then
		iptables -I INPUT -p tcp --dport $db_port -j ACCEPT
		ckcmd ip6tables && ip6tables -I INPUT -p tcp --dport $db_port -j ACCEPT 
	else
		#仅允许非公网设备访问面板
		for ip in $reserve_ipv4;do
			iptables -A INPUT -p tcp -s $ip --dport $db_port -j ACCEPT
		done
		iptables -A INPUT -p tcp --dport $db_port -j REJECT
		ckcmd ip6tables && ip6tables -A INPUT -p tcp --dport $db_port -j REJECT
	fi
	if [ "$public_mixport" = "已开启" ];then
		iptables -I INPUT -p tcp --dport $mix_port -j ACCEPT
		ckcmd ip6tables && ip6tables -I INPUT -p tcp --dport $mix_port -j ACCEPT 
	else
		#仅允许局域网设备访问混合端口
		for ip in $reserve_ipv4;do
			iptables -A INPUT -p tcp -s $ip --dport $mix_port -j ACCEPT
		done
		iptables -A INPUT -p tcp --dport $mix_port -j REJECT
		ckcmd ip6tables && ip6tables -A INPUT -p tcp --dport $mix_port -j REJECT 
	fi
	iptables -I INPUT -p tcp -d 127.0.0.1 -j ACCEPT #本机请求全放行
}
stop_firewall(){ #还原防火墙配置
	getconfig
	#获取局域网host地址
	getlanip
    #重置iptables相关规则
	ckcmd iptables && {
		#redir
		iptables -t nat -D PREROUTING -p tcp $ports -j shellcrash 2> /dev/null
		iptables -t nat -D PREROUTING -p tcp -d 198.18.0.0/16 -j shellcrash 2> /dev/null
		iptables -t nat -F shellcrash 2> /dev/null
		iptables -t nat -X shellcrash 2> /dev/null
		#dns
		iptables -t nat -D PREROUTING -p tcp --dport 53 -j shellcrash_dns 2> /dev/null
		iptables -t nat -D PREROUTING -p udp --dport 53 -j shellcrash_dns 2> /dev/null
		iptables -t nat -F shellcrash_dns 2> /dev/null
		iptables -t nat -X shellcrash_dns 2> /dev/null
		#tun
		iptables -D FORWARD -o utun -j ACCEPT 2> /dev/null
		iptables -D FORWARD -s 198.18.0.0/16 -o utun -j RETURN 2> /dev/null
		#屏蔽QUIC
		[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
		iptables -D INPUT -p udp --dport 443 -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
		iptables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
		#本机代理
		iptables -t nat -D OUTPUT -p tcp $ports -j shellcrash_out 2> /dev/null
		iptables -t nat -F shellcrash_out 2> /dev/null
		iptables -t nat -X shellcrash_out 2> /dev/null	
		iptables -t nat -D OUTPUT -p udp --dport 53 -j shellcrash_dns_out 2> /dev/null
		iptables -t nat -F shellcrash_dns_out 2> /dev/null
		iptables -t nat -X shellcrash_dns_out 2> /dev/null
		#docker
		iptables -t nat -F shellcrash_docker 2> /dev/null
		iptables -t nat -X shellcrash_docker 2> /dev/null
		iptables -t nat -D PREROUTING -p tcp -s 172.16.0.0/12 -j shellcrash_docker 2> /dev/null
		iptables -t nat -D PREROUTING -p udp --dport 53 -s 172.16.0.0/12 -j REDIRECT --to $dns_port 2> /dev/null
		#TPROXY&tun
		iptables -t mangle -D PREROUTING -p tcp $ports -j shellcrash 2> /dev/null
		iptables -t mangle -D PREROUTING -p udp $ports -j shellcrash 2> /dev/null
		iptables -t mangle -D PREROUTING -p tcp -d 198.18.0.0/16 -j shellcrash 2> /dev/null
		iptables -t mangle -D PREROUTING -p udp -d 198.18.0.0/16 -j shellcrash 2> /dev/null
		iptables -t mangle -F shellcrash 2> /dev/null
		iptables -t mangle -X shellcrash 2> /dev/null
		#公网访问
		for ip in $host_ipv4 $local_ipv4 $reserve_ipv4;do
			iptables -D INPUT -p tcp -s $ip --dport $mix_port -j ACCEPT 2> /dev/null
			iptables -D INPUT -p tcp -s $ip --dport $db_port -j ACCEPT 2> /dev/null
		done
		iptables -D INPUT -p tcp -d 127.0.0.1 -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp --dport $mix_port -j REJECT 2> /dev/null
		iptables -D INPUT -p tcp --dport $mix_port -j ACCEPT 2> /dev/null
		iptables -D INPUT -p tcp --dport $db_port -j REJECT 2> /dev/null
		iptables -D INPUT -p tcp --dport $db_port -j ACCEPT 2> /dev/null
	}
	#重置ipv6规则
	ckcmd ip6tables && {
		#redir
		ip6tables -t nat -D PREROUTING -p tcp $ports -j shellcrashv6 2> /dev/null
		ip6tables -D INPUT -p udp --dport 53 -m comment --comment "ShellCrash-IPV6_DNS-REJECT" -j REJECT 2> /dev/null
		ip6tables -t nat -F shellcrashv6 2> /dev/null
		ip6tables -t nat -X shellcrashv6 2> /dev/null
		#dns
		ip6tables -t nat -D PREROUTING -p tcp --dport 53 -j shellcrashv6_dns 2>/dev/null
		ip6tables -t nat -D PREROUTING -p udp --dport 53 -j shellcrashv6_dns 2>/dev/null
		ip6tables -t nat -F shellcrashv6_dns 2> /dev/null
		ip6tables -t nat -X shellcrashv6_dns 2> /dev/null
		#tun
		ip6tables -D FORWARD -o utun -j ACCEPT 2> /dev/null
		ip6tables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellCrash-QUIC-REJECT" -j REJECT >/dev/null 2>&1
		#屏蔽QUIC
		[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" ] && set_cn_ip6='-m set ! --match-set cn_ip6 dst'
		iptables -D INPUT -p udp --dport 443 -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2> /dev/null
		iptables -D FORWARD -p udp --dport 443 -o utun -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip6 -j REJECT 2> /dev/null
		#公网访问
		ip6tables -D INPUT -p tcp --dport $mix_port -j REJECT 2> /dev/null
		ip6tables -D INPUT -p tcp --dport $mix_port -j ACCEPT 2> /dev/null
		ip6tables -D INPUT -p tcp --dport $db_port -j REJECT 2> /dev/null	
		ip6tables -D INPUT -p tcp --dport $db_port -j ACCEPT 2> /dev/null
		#tproxy&tun
		ip6tables -t mangle -D PREROUTING -p tcp $ports -j shellcrashv6 2> /dev/null
		ip6tables -t mangle -D PREROUTING -p udp $ports -j shellcrashv6 2> /dev/null
		ip6tables -t mangle -F shellcrashv6 2> /dev/null
		ip6tables -t mangle -X shellcrashv6 2> /dev/null
		ip6tables -D INPUT -p udp --dport 443 -m comment --comment "ShellCrash-QUIC-REJECT" $set_cn_ip -j REJECT 2> /dev/null
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
	ip rule del fwmark $fwmark table 100  2> /dev/null
	ip route del local default dev lo table 100 2> /dev/null
	ip -6 rule del fwmark $fwmark table 101 2> /dev/null
	ip -6 route del local ::/0 dev lo table 101 2> /dev/null
	#重置nftables相关规则
	ckcmd nft && {
		nft flush table inet shellcrash >/dev/null 2>&1
		nft delete table inet shellcrash >/dev/null 2>&1
	}
	#还原防火墙文件
	[ -s /etc/init.d/firewall.bak ] && mv -f /etc/init.d/firewall.bak /etc/init.d/firewall
}
#启动相关
web_save(){ #最小化保存面板节点选择
	getconfig
	#使用get_save获取面板节点设置
	get_save http://127.0.0.1:${db_port}/proxies | sed 's/:{/!/g' | awk -F '!' '{for(i=1;i<=NF;i++) print $i}' | grep -aE '"Selector"' | grep -aoE '"name":.*"now":".*",' > ${TMPDIR}/web_proxies
	while read line ;do
		def=$(echo $line | grep -oE '"all".*",' | awk -F "[:\"]" '{print $5}' )
		now=$(echo $line | grep -oE '"now".*",' | awk -F "[:\"]" '{print $5}' )
		[ "$def" != "$now" ] && {
			name=$(echo $line | grep -oE '"name".*",' | awk -F "[:\"]" '{print $5}' )
			echo "${name},${now}" >> ${TMPDIR}/web_save
		}
	done < ${TMPDIR}/web_proxies
	rm -rf ${TMPDIR}/web_proxies
	#获取面板设置
	[ "$crashcore" != singbox ] && get_save http://127.0.0.1:${db_port}/configs > ${TMPDIR}/web_configs
	#对比文件，如果有变动且不为空则写入磁盘，否则清除缓存
	for file in web_save web_configs ;do
		if [ -s ${TMPDIR}/${file} ];then
			compare ${TMPDIR}/${file} ${CRASHDIR}/configs/${file}
			[ "$?" = 0 ] && rm -rf ${TMPDIR}/${file} || mv -f ${TMPDIR}/${file} ${CRASHDIR}/configs/${file}
		else
			echo > ${CRASHDIR}/configs/${file}
		fi
	done
}
web_restore(){ #还原面板选择
	getconfig
	#设置循环检测面板端口以判定服务启动是否成功
	i=1
	while [ -z "$test" -a "$i" -lt 20 ];do
		sleep 2
		if curl --version > /dev/null 2>&1;then
			test=$(curl -s http://127.0.0.1:${db_port}/configs | grep -o port)
		else
			test=$(wget -q -O - http://127.0.0.1:${db_port}/configs | grep -o port)
		fi
		i=$((i+1))
	done
	[ -n "$test" ] && {
		#发送节点选择数据
		[ -s ${CRASHDIR}/configs/web_save ] && {
			num=$(cat ${CRASHDIR}/configs/web_save | wc -l)
			i=1
			while [ "$i" -le "$num" ];do
				group_name=$(awk -F ',' 'NR=="'${i}'" {print $1}' ${CRASHDIR}/configs/web_save | sed 's/ /%20/g')
				now_name=$(awk -F ',' 'NR=="'${i}'" {print $2}' ${CRASHDIR}/configs/web_save)
				put_save http://127.0.0.1:${db_port}/proxies/${group_name} "{\"name\":\"${now_name}\"}"
				i=$((i+1))
			done
		}
		#还原面板设置
		[ "$crashcore" != singbox ] && [ -s ${CRASHDIR}/configs/web_configs ] && {
			sleep 5
			put_save http://127.0.0.1:${db_port}/configs "$(cat ${CRASHDIR}/configs/web_configs)" PATCH
		}
	}
}
makehtml(){ #生成面板跳转文件
	cat > ${BINDIR}/ui/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShellCrash面板提示</title>
</head>
<body>
    <div style="text-align: center; margin-top: 50px;">
        <h1>您还未安装本地面板</h1>
		<h3>请在脚本更新功能中(9-4)安装<br>或者使用在线面板：</h3>
        <a href="https://metacubexd.pages.dev" style="font-size: 24px;">Meta XD面板(推荐)<br></a>
        <a href="https://yacd.metacubex.one" style="font-size: 24px;">Meta YACD面板(推荐)<br></a>
        <a href="https://yacd.haishan.me" style="font-size: 24px;">Clash YACD面板<br></a>
        <a href="https://clash.razord.top" style="font-size: 24px;">Clash Razord面板<br></a>
        <a style="font-size: 16px;"><br>如已安装，请使用Ctrl+F5强制刷新！<br></a>		
    </div>
</body>
</html
EOF
}
catpac(){ #生成pac文件
	#获取本机host地址
	[ -n "$host" ] && host_pac=$host
	[ -z "$host_pac" ] && host_pac=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
	[ -z "$host_pac" ] && host_pac=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	cat > ${TMPDIR}/shellcrash_pac <<EOF
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
	compare ${TMPDIR}/shellcrash_pac ${BINDIR}/ui/pac
	[ "$?" = 0 ] && rm -rf ${TMPDIR}/shellcrash_pac || mv -f ${TMPDIR}/shellcrash_pac ${BINDIR}/ui/pac
}
core_check(){
	#检查及下载内核文件
	if [ ! -f ${TMPDIR}/CrashCore ];then
		if [ -f ${BINDIR}/CrashCore ];then
			ln -sf ${BINDIR}/CrashCore ${TMPDIR}/CrashCore
		elif [ -f ${BINDIR}/CrashCore.tar.gz ];then
			tar -zxvf "${BINDIR}/CrashCore.tar.gz" -C ${TMPDIR}/ &>/dev/null || tar -zxvf "${BINDIR}/CrashCore.tar.gz" --no-same-owner -C ${TMPDIR}/
		else
			logger "未找到【$crashcore】核心，正在下载！" 33
			[ -z "$cpucore" ] && source ${CRASHDIR}/getdate.sh && getcpucore
			[ -z "$cpucore" ] && logger 找不到设备的CPU信息，请手动指定处理器架构类型！ 31 && exit 1
			get_bin ${TMPDIR}/CrashCore.tar.gz "bin/$crashcore/${target}-linux-${cpucore}.tar.gz"
			#校验内核
			mkdir -p ${TMPDIR}/core_tmp
			tar -zxvf "${TMPDIR}/CrashCore.tar.gz" -C ${TMPDIR}/core_tmp/ &>/dev/null || tar -zxvf "${TMPDIR}/CrashCore.tar.gz" --no-same-owner -C ${TMPDIR}/core_tmp/
			for file in "$(finds ${TMPDIR}/core_tmp -type f -size +4096)" ;do
				mv -f $file ${TMPDIR}/core_new
			done
			rm -rf ${TMPDIR}/core_tmp
			chmod +x ${TMPDIR}/core_new
			if [ "$crashcore" = singbox -o "$crashcore" = singboxp ];then
				core_v=$(${TMPDIR}/core_new version 2>/dev/null | grep version | awk '{print $3}')
				COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
			else
				core_v=$(${TMPDIR}/core_new -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
				COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
			fi
			if [ -z "$core_v" ];then
				rm -rf ${TMPDIR}/CrashCore
				logger "核心下载失败，请重新运行或更换安装源！" 31
				exit 1
			else
				mv -f ${TMPDIR}/core_new ${TMPDIR}/CrashCore
				mv -f ${TMPDIR}/CrashCore.tar.gz ${BINDIR}/CrashCore.tar.gz
				setconfig COMMAND "$COMMAND" ${CRASHDIR}/configs/command.env && source ${CRASHDIR}/configs/command.env
				setconfig crashcore $crashcore
				setconfig core_v $core_v
			fi
		fi
	fi
	[ ! -x ${TMPDIR}/CrashCore ] && chmod +x ${TMPDIR}/CrashCore 2>/dev/null #自动授权
	return 0
}
clash_check(){ #clash启动前检查
	#检测vless/hysteria协议
	if [ "$crashcore" != "meta" ] && [ -n "$(cat $core_config | grep -oE 'type: vless|type: hysteria')" ];then
		echo -----------------------------------------------
		logger "检测到vless/hysteria协议！将改为使用meta核心启动！" 33
		rm -rf ${TMPDIR}/CrashCore
		rm -rf ${BINDIR}/CrashCore
		rm -rf ${BINDIR}/CrashCore.tar.gz
		crashcore=meta
		echo -----------------------------------------------
	fi
	#检测是否存在高级版规则或者tun模式
	if [ "$crashcore" = "clash" ];then
		[ -n "$(cat $core_config | grep -aiE '^script:|proxy-providers|rule-providers|rule-set')" ] || \
		[ "$redir_mod" = "混合模式" ] || \
		[ "$redir_mod" = "Tun模式" ] && {
			echo -----------------------------------------------
			logger "检测到高级功能！将改为使用meta核心启动！" 33
			rm -rf ${TMPDIR}/CrashCore
			rm -rf ${BINDIR}/CrashCore
			rm -rf ${BINDIR}/CrashCore.tar.gz
			crashcore=meta
			echo -----------------------------------------------
		}
	fi
	core_check
	#预下载GeoIP数据库
	if [ -n "$(cat ${CRASHDIR}/yamls/*.yaml | grep -oEi 'geoip')" ] && [ -z "$(finds ${BINDIR}/Country.mmdb -size +10 2>/dev/null)" ];then
		if [ -f ${CRASHDIR}/Country.mmdb ];then
			mv -f ${CRASHDIR}/Country.mmdb ${BINDIR}/Country.mmdb
		else
			logger "未找到Country.mmdb数据库，正在下载！" 33
			get_bin ${BINDIR}/Country.mmdb bin/geodata/cn_mini.mmdb
			[ "$?" = "1" ] && rm -rf ${BINDIR}/Country.mmdb && logger "数据库下载失败，已退出，请前往更新界面尝试手动下载！" 31 && exit 1
			setconfig cn_mini_v $(date +"%Y%m%d")
		fi
	fi
	#预下载GeoSite数据库
	if [ -n "$(cat ${CRASHDIR}/yamls/*.yaml | grep -oEi 'geosite')" ] && [ -z "$(finds ${BINDIR}/GeoSite.dat -size +10 2>/dev/null)" ];then
		if [ -f ${CRASHDIR}/GeoSite.dat ];then
			mv -f ${CRASHDIR}/GeoSite.dat ${BINDIR}/GeoSite.dat
		else
			logger "未找到GeoSite.dat数据库，正在下载！" 33
			get_bin ${BINDIR}/GeoSite.dat bin/geodata/geosite.dat
			[ "$?" = "1" ] && rm -rf ${BINDIR}/GeoSite.dat && logger "数据库下载失败，已退出，请前往更新界面尝试手动下载！" 31 && exit 1
			setconfig geosite_v $(date +"%Y%m%d")
		fi
	fi
	return 0
}
singbox_check(){ #singbox启动前检查
	#检测PuerNya专属功能
	if [ "$crashcore" != "singboxp" ] && [ -n "$(cat ${CRASHDIR}/jsons/*.json | grep -oE 'shadowsocksr|providers')" ];then
		echo -----------------------------------------------
		logger "检测到PuerNya内核专属功能，改为使用singboxp内核启动！" 33
		rm -rf ${TMPDIR}/CrashCore
		rm -rf ${BINDIR}/CrashCore
		rm -rf ${BINDIR}/CrashCore.tar.gz
		crashcore=singboxp		
	fi
	core_check
	#预下载geoip-cn.srs数据库
	if [ -n "$(cat ${CRASHDIR}/jsons/*.json | grep -oEi '\"rule_set\": \"geoip-cn\"')" ] && [ -z "$(finds ${BINDIR}/geoip-cn.srs -size +10 2>/dev/null)" ];then
		if [ -f ${CRASHDIR}/geoip-cn.srs ];then
			mv -f ${CRASHDIR}/geoip-cn.srs ${BINDIR}/geoip-cn.srs
		else
			logger "未找到geoip-cn.srs数据库，正在下载！" 33
			get_bin ${BINDIR}/geoip-cn.srs bin/geodata/srs_geoip_cn.srs
			[ "$?" = "1" ] && rm -rf ${BINDIR}/geoip-cn.srs && logger "数据库下载失败，已退出，请前往更新界面尝试手动下载！" 31 && exit 1
			setconfig srs_geoip_cn_v $(date +"%Y%m%d")
		fi
	fi
	#预下载geosite-cn.srs数据库
	if [ -n "$(cat ${CRASHDIR}/jsons/*.json | grep -oEi '\"rule_set\": \"geosite-cn\"')" -o "$dns_mod" = "mix" ] && \
		[ -z "$(finds ${BINDIR}/geosite-cn.srs -size +10 2>/dev/null)" ];then
		if [ -f ${CRASHDIR}/geosite-cn.srs ];then
			mv -f ${CRASHDIR}/geosite-cn.srs ${BINDIR}/geosite-cn.srs
		else
			logger "未找到geosite-cn.srs数据库，正在下载！" 33
			get_bin ${BINDIR}/geosite-cn.srs bin/geodata/srs_geosite_cn.srs
			[ "$?" = "1" ] && rm -rf ${BINDIR}/geosite-cn.srs && logger "数据库下载失败，已退出，请前往更新界面尝试手动下载！" 31 && exit 1
			setconfig srs_geosite_cn_v $(date +"%Y%m%d")
		fi
	fi
	#预下载GeoIP数据库
	if [ -n "$(cat ${CRASHDIR}/jsons/*.json | grep -oEi '\"geoip\":')" ] && [ -z "$(finds ${BINDIR}/geoip.db -size +10 2>/dev/null)" ];then
		if [ -f ${CRASHDIR}/geoip.db ];then
			mv -f ${CRASHDIR}/geoip.db ${BINDIR}/geoip.db
		else
			logger "未找到geoip.db数据库，正在下载！" 33
			get_bin ${BINDIR}/geoip.db bin/geodata/geoip_cn.db
			[ "$?" = "1" ] && rm -rf ${BINDIR}/geoip.db && logger "数据库下载失败，已退出，请前往更新界面尝试手动下载！" 31 && exit 1
			setconfig geoip_cn_v $(date +"%Y%m%d")
		fi
	fi
	#预下载GeoSite数据库
	if [ -n "$(cat ${CRASHDIR}/jsons/*.json | grep -oEi '\"geosite\":')" ] && [ -z "$(finds ${BINDIR}/geosite.db -size +10 2>/dev/null)" ];then
		if [ -f ${CRASHDIR}/geosite.db ];then
			mv -f ${CRASHDIR}/geosite.db ${BINDIR}/geosite.db
		else
			logger "未找到geosite.db数据库，正在下载！" 33
			get_bin ${BINDIR}/geosite.db bin/geodata/geosite_cn.db
			[ "$?" = "1" ] && rm -rf ${BINDIR}/geosite.db && logger "数据库下载失败，已退出，请前往更新界面尝试手动下载！" 31 && exit 1
			setconfig geosite_cn_v $(date +"%Y%m%d")
		fi
	fi
	return 0
}
bfstart(){ #启动前
	#读取ShellCrash配置
	getconfig
	[ -z "$update_url" ] && update_url=https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master
	[ ! -d ${BINDIR}/ui ] && mkdir -p ${BINDIR}/ui
	[ -z "$crashcore" ] && crashcore=clash
	#执行条件任务
	[ -s ${CRASHDIR}/task/bfstart ] && source ${CRASHDIR}/task/bfstart
	#检查内核配置文件
	if [ ! -f $core_config ];then
		if [ -n "$Url" -o -n "$Https" ];then
			logger "未找到配置文件，正在下载！" 33
			get_core_config
			exit 0
		else
			logger "未找到配置文件链接，请先导入配置文件！" 31
			exit 1
		fi
	fi
	#检查dashboard文件
	if [ -f ${CRASHDIR}/ui/index.html -a ! -f ${BINDIR}/ui/index.html ];then
		cp -rf ${CRASHDIR}/ui ${BINDIR}
	fi
	[ ! -s ${BINDIR}/ui/index.html ] && makehtml #如没有面板则创建跳转界面
	catpac	#生成pac文件
	#内核及内核配置文件检查
	[ ! -x ${TMPDIR}/CrashCore ] && chmod +x ${TMPDIR}/CrashCore 2>/dev/null #检测可执行权限
	if [ "$crashcore" = singbox -o "$crashcore" = singboxp ];then
		singbox_check	
		[ -d ${TMPDIR}/jsons ] && rm -rf ${TMPDIR}/jsons/* || mkdir -p ${TMPDIR}/jsons #准备目录
		[ "$disoverride" != "1" ] && modify_json || ln -sf $core_config ${TMPDIR}/jsons/config.json
	else
		clash_check
		[ "$disoverride" != "1" ] && modify_yaml || ln -sf $core_config ${TMPDIR}/config.yaml
	fi
	#添加shellcrash用户
	[ -n "$(echo $local_type | grep '增强模式')" -o "$(cat /proc/1/comm)" = "systemd" ] && \
	[ -z "$(id shellcrash 2>/dev/null | grep 'root')" ] && {
		sed -i '/0:7890/d' /etc/passwd
		sed -i '/x:7890/d' /etc/group
		if ckcmd useradd; then
			useradd shellcrash -u 7890
			sed -Ei s/7890:7890/0:7890/g /etc/passwd
		else
			echo "shellcrash:x:0:7890:::" >> /etc/passwd
		fi
	}
	#清理debug日志
	rm -rf ${TMPDIR}/debug.log
	return 0
}
afstart(){ #启动后

	#读取配置文件
	getconfig
	#延迟启动
	[ ! -f ${TMPDIR}/crash_start_time ] && [ -n "$start_delay" ] && [ "$start_delay" -gt 0 ] && {
		logger "ShellCrash将延迟$start_delay秒启动" 31 pushoff
		sleep $start_delay
	}
	#设置循环检测面板端口以判定服务启动是否成功
	i=1
	while [ -z "$test" -a "$i" -lt 5 ];do
		sleep 1
		if curl --version > /dev/null 2>&1;then
			test=$(curl -s http://127.0.0.1:${db_port}/configs | grep -o port)
		else
			test=$(wget -q -O - http://127.0.0.1:${db_port}/configs | grep -o port)
		fi
		i=$((i+1))
	done
	if [ -n "$test" -o -n "$(pidof CrashCore)" ];then
		#设置DNS转发
		start_dns(){
			[ "$dns_mod" != "fake-ip" ] && [ "$cn_ip_route" = "已开启" ] && cn_ip_route
			[ "$ipv6_redir" = "已开启" ] && [ "$dns_mod" != "fake-ip" ] && [ "$cn_ipv6_route" = "已开启" ] && cn_ipv6_route
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
			return 0
		}
		#设置路由规则
		[ "$redir_mod" = "Redir模式" ] && start_dns && start_redir 	
		[ "$redir_mod" = "混合模式" ] && start_dns && start_redir && start_tun udp
		[ "$redir_mod" = "Tproxy混合" ] && start_dns && start_redir && start_tproxy udp
		[ "$redir_mod" = "Tun模式" ] && start_dns && start_tun all
		[ "$redir_mod" = "Tproxy模式" ] && start_dns && start_tproxy all
		[ -n "$(echo $redir_mod|grep Nft)" -o "$local_type" = "nftables增强模式" ] && {
			nft add table inet shellcrash #初始化nftables
			nft flush table inet shellcrash
		}
		[ -n "$(echo $redir_mod|grep Nft)" ] && start_dns && start_nft
		#设置本机代理
		[ "$local_proxy" = "已开启" ] && {
			[ "$local_type" = "环境变量" ] && $0 set_proxy $mix_port $db_port
			[ "$local_type" = "iptables增强模式" ] && [ -n "$(grep '0:7890' /etc/passwd)" ] && start_output
			[ "$local_type" = "nftables增强模式" ] && [ -n "$(grep '0:7890' /etc/passwd)" ] && [ "$redir_mod" = "纯净模式" ] && start_nft
		}
		ckcmd iptables && start_wan #本地防火墙
		mark_time #标记启动时间
		[ -s ${CRASHDIR}/configs/web_save -o -s ${CRASHDIR}/configs/web_configs ] && web_restore &>/dev/null & #后台还原面板配置
		{ sleep 5;logger ShellCrash服务已启动！;} & #推送日志
		#加载定时任务
		[ -s ${CRASHDIR}/task/cron ] && croncmd ${CRASHDIR}/task/cron
		[ -s ${CRASHDIR}/task/running ] && {
			cronset '运行时每'
			while read line ;do
				cronset '2fjdi124dd12s' "$line"
			done < ${CRASHDIR}/task/running
		}
		[ "$start_old" = "已开启" ] && cronset '保守模式守护进程' "* * * * * test -z \"\$(pidof CrashCore)\" && ${CRASHDIR}/start.sh daemon #ShellCrash保守模式守护进程"
		#加载条件任务
		[ -s ${CRASHDIR}/task/afstart ] && { source ${CRASHDIR}/task/afstart ;} &
		[ -s ${CRASHDIR}/task/affirewall -a -s /etc/init.d/firewall -a ! -f /etc/init.d/firewall.bak ] && {
			#注入防火墙
			line=$(grep -En "fw3 restart" /etc/init.d/firewall | cut -d ":" -f 1)
			sed -i.bak "${line}a\\source ${CRASHDIR}/task/affirewall" /etc/init.d/firewall
			line=$(grep -En "fw3 .* start" /etc/init.d/firewall | cut -d ":" -f 1)
			sed -i "${line}a\\source ${CRASHDIR}/task/affirewall" /etc/init.d/firewall
		} &
	else
		$0 stop
		start_error
	fi
}
start_error(){ #启动报错
	if [ "$start_old" != "已开启" ] && ckcmd journalctl;then
		ournalctl -xeu shellcrash > $TMPDIR/core_test.log
	else
		${COMMAND} &>${TMPDIR}/core_test.log &
		sleep 2 ; kill $! &>/dev/null
	fi
	error=$(cat $TMPDIR/core_test.log | grep -Eo 'error.*=.*|.*ERROR.*|.*FATAL.*')
	logger "服务启动失败！请查看报错信息！详细信息请查看$TMPDIR/core_test.log" 33
	logger "$error" 31
	exit 1
}
start_old(){ #保守模式
	#使用传统后台执行二进制文件的方式执行
	if [ "$local_proxy" = "已开启" -a -n "$(echo $local_type | grep '增强模式')" ];then
		if ckcmd su;then
			su shellcrash -c "$COMMAND >/dev/null 2>&1" &
		else
			logger "当前设备缺少su命令，保守模式下无法兼容本机代理增强模式，已停止启动！" 31
			exit 1
		fi
	else
		ckcmd nohup && [ -d /jffs ] && nohup=nohup #华硕调用nohup启动
		$nohup $COMMAND >/dev/null 2>&1 &
	fi
	afstart &
}
#杂项
update_config(){ #更新订阅并重启
		getconfig
		get_core_config && \
		$0 restart
}
hotupdate(){ #热更新订阅
		getconfig
		get_core_config
		modify_$format && \
		put_save http://127.0.0.1:${db_port}/configs "{\"path\":\"${CRASHDIR}/config.$format\"}"
}
set_proxy(){ #设置环境变量
	getconfig
	if  [ "$local_type" = "环境变量" ];then
		[ -w ~/.bashrc ] && profile=~/.bashrc
		[ -w /etc/profile ] && profile=/etc/profile
		echo 'export all_proxy=http://127.0.0.1:'"$mix_port" >> $profile
		echo 'export ALL_PROXY=$all_proxy' >>  $profile
	fi
}
unset_proxy(){	#卸载环境变量
	[ -w ~/.bashrc ] && profile=~/.bashrc
	[ -w /etc/profile ] && profile=/etc/profile
	sed -i '/all_proxy/'d  $profile
	sed -i '/ALL_PROXY/'d  $profile
}

case "$1" in

start)		
		[ -n "$(pidof CrashCore)" ] && $0 stop #禁止多实例
		getconfig
		stop_firewall #清理路由策略
		#使用不同方式启动服务
		if [ "$start_old" = "已开启" ];then
			bfstart && start_old
		elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ];then
			/etc/init.d/shellcrash start 
		elif [ "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ];then
			FragmentPath=$(systemctl show -p FragmentPath shellcrash | sed 's/FragmentPath=//')
			setconfig ExecStart "$COMMAND >/dev/null" "$FragmentPath"
			systemctl daemon-reload
			systemctl start shellcrash.service || start_error
		else
			bfstart && start_old
		fi
	;;
stop)	
		getconfig
		logger ShellCrash服务即将关闭……
		[ -n "$(pidof CrashCore)" ] && web_save #保存面板配置
		#删除守护进程&面板配置自动保存
		cronset '保守模式守护进程'
		cronset '运行时每'
		cronset '流媒体预解析'
		#多种方式结束进程

		if [ "$start_old" != "已开启" -a "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ];then
			systemctl stop shellcrash.service &>/dev/null
		elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ];then
			/etc/init.d/shellcrash stop &>/dev/null
		else
			stop_firewall #清理路由策略
			unset_proxy #禁用本机代理
		fi
		PID=$(pidof CrashCore) && [ -n "$PID" ] &&  kill -9 $PID &>/dev/null
        ;;
restart)
        $0 stop
        $0 start
        ;;
daemon)
        [ ! -f $TMPDIR/crash_start_time ] && sleep 20
        $0 start
        ;;
debug)		
		[ -n "$(pidof CrashCore)" ] && $0 stop >/dev/null #禁止多实例
		getconfig 
		stop_firewall >/dev/null #清理路由策略
		bfstart
		[ -n "$2" ] && {
			if [ "$crashcore" = singbox -o "$crashcore" = singboxp ];then
				sed -i "s/\"level\": \"info\"/\"level\": \"$2\"/"  ${TMPDIR}/config.json
			else
				sed -i "s/log-level: info/log-level: $2/" ${TMPDIR}/config.yaml
			fi
		}
		$COMMAND &>${TMPDIR}/debug.log &
		afstart
		logger "已运行debug模式!如需停止，请正常重启一次服务！" 33 
	;;
init)
		profile=/etc/profile
        if [ -d "/etc/storage/clash" -o -d "/etc/storage/ShellCrash" ];then
			i=1
			while [ ! -w /etc/profile -a "$i" -lt 10 ];do
				sleep 5 && i=$((i+1))
			done
			profile=/etc/profile
			sed -i '' $profile #将软链接转化为一般文件
		elif [ -d "/jffs" ];then
			sleep 60
			if [ -w /etc/profile ];then
				profile=/etc/profile
			else
				profile=$(cat /etc/profile | grep -oE '\-f.*jffs.*profile' | awk '{print $2}')
			fi
		fi
		sed -i "/alias crash/d" $profile 
		sed -i "/alias clash/d" $profile 
		sed -i "/export CRASHDIR/d" $profile 
		echo "alias crash=\"$CRASHDIR/menu.sh\"" >> $profile 
		echo "alias clash=\"$CRASHDIR/menu.sh\"" >> $profile 
		echo "export CRASHDIR=\"$CRASHDIR\"" >> $profile 
		[ -f ${CRASHDIR}/.dis_startup ] && cronset "保守模式守护进程" || $0 start
        ;;
webget)
		#设置临时代理 
		if [ -n "$(pidof CrashCore)" ];then
			getconfig
			[ -n "$authentication" ] && auth="$authentication@"
			export all_proxy="http://${auth}127.0.0.1:$mix_port"
			url=$(echo $3 | sed 's#https://.*jsdelivr.net/gh/juewuy/ShellCrash[@|/]#https://raw.githubusercontent.com/juewuy/ShellCrash/#' | sed 's#https://gh.jwsc.eu.org/#https://raw.githubusercontent.com/juewuy/ShellCrash/#')
		else
			url=$(echo $3 | sed 's#https://raw.githubusercontent.com/juewuy/ShellCrash/#https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@#')
		fi
		#参数【$2】代表下载目录，【$3】代表在线地址
		#参数【$4】代表输出显示，【$4】不启用重定向
		#参数【$6】代表验证证书
		if curl --version > /dev/null 2>&1;then
			[ "$4" = "echooff" ] && progress='-s' || progress='-#'
			[ "$5" = "rediroff" ] && redirect='' || redirect='-L'
			[ "$6" = "skipceroff" ] && certificate='' || certificate='-k'
			result=$(curl $agent -w %{http_code} --connect-timeout 3 $progress $redirect $certificate -o "$2" "$url" )
			[ "$result" != "200" ] && export all_proxy="" && result=$(curl $agent -w %{http_code} --connect-timeout 5 $progress $redirect $certificate -o "$2" "$3")
		else
			if wget --version > /dev/null 2>&1;then
				[ "$4" = "echooff" ] && progress='-q' || progress='-q --show-progress'
				[ "$5" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
				[ "$6" = "skipceroff" ] && certificate='' || certificate='--no-check-certificate'
				timeout='--timeout=5 -t 2'
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
*)
	$1 $2 $3 $4 $5 $6 $7
	;;

esac
