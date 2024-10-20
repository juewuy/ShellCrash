#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
CRASHDIR=$(
	cd $(dirname $0)
	pwd
)
#加载执行目录，失败则初始化
. "$CRASHDIR"/configs/command.env >/dev/null 2>&1
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && . "$CRASHDIR"/init.sh >/dev/null 2>&1
[ ! -f "$TMPDIR" ] && mkdir -p "$TMPDIR"

#脚本内部工具
getconfig() { #读取配置及全局变量
	#加载配置文件
	. "$CRASHDIR"/configs/ShellCrash.cfg >/dev/null
	#缺省值
	[ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod=Redir模式
	[ -z "$redir_mod" ] && redir_mod=纯净模式
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ -z "$dns_mod" ] && dns_mod=fake-ip
	[ -z "$ipv6_redir" ] && ipv6_redir=未开启
	[ -z "$ipv6_dns" ] && ipv6_dns=已开启
	[ -z "$cn_ipv6_route" ] && cn_ipv6_route=未开启
	[ -z "$macfilter_type" ] && macfilter_type=黑名单
	[ -z "$mix_port" ] && mix_port=7890
	[ -z "$redir_port" ] && redir_port=7892
	[ -z "$tproxy_port" ] && tproxy_port=7893
	[ -z "$db_port" ] && db_port=9999
	[ -z "$dns_port" ] && dns_port=1053
	[ -z "$fwmark" ] && fwmark=$redir_port
	routing_mark=$((fwmark + 2))
	[ -z "$sniffer" ] && sniffer=已开启
	#是否代理常用端口
	[ -z "$common_ports" ] && common_ports=已开启
	[ -z "$multiport" ] && multiport='22,80,143,194,443,465,587,853,993,995,5222,8080,8443'
	[ "$common_ports" = "已开启" ] && ports="-m multiport --dports $multiport"
	#内核配置文件
	if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
		target=singbox
		format=json
		core_config="$CRASHDIR"/jsons/config.json
	else
		target=clash
		format=yaml
		core_config="$CRASHDIR"/yamls/config.yaml
	fi
	#检查$iptable命令可用性
	ckcmd iptables && iptables -h | grep -q '\-w' && iptable='iptables -w' || iptable=iptables
	ckcmd ip6tables && ip6tables -h | grep -q '\-w' && ip6table='ip6tables -w' || ip6table=ip6tables
}
setconfig() { #脚本配置工具
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath="$CRASHDIR"/configs/ShellCrash.cfg || configpath="${3}"
	grep -q "${1}=" "$configpath" && sed -i "s#${1}=.*#${1}=${2}#g" "$configpath" || sed -i "\$a\\${1}=${2}" $configpath
}
ckcmd() { #检查命令是否存在
	command -v sh >/dev/null 2>&1 && command -v "$1" >/dev/null 2>&1 || type "$1" >/dev/null 2>&1
}
ckgeo() {                                                  #查找及下载Geo数据文件
	find --help 2>&1 | grep -q size && find_para=' -size +20' #find命令兼容
	[ -z "$(find "$BINDIR"/"$1" "$find_para" 2>/dev/null)" ] && {
		if [ -n "$(find "$CRASHDIR"/"$1" "$find_para" 2>/dev/null)" ]; then
			mv "$CRASHDIR"/"$1" "$BINDIR"/"$1" #小闪存模式移动文件
		else
			logger "未找到${1}文件，正在下载！" 33
			get_bin "$BINDIR"/"$1" bin/geodata/"$2"
			[ "$?" = "1" ] && rm -rf "${BINDIR:?}"/"${1}" && logger "${1}文件下载失败,已退出！请前往更新界面尝试手动下载！" 31 && exit 1
			geo_v="$(echo "$2" | awk -F "." '{print $1}')_v"
			setconfig "$geo_v" "$(date +"%Y%m%d")"
		fi
	}
}
compare() { #对比文件
	if [ ! -f "$1" ] || [ ! -f "$2" ]; then
		return 1
	elif ckcmd cmp; then
		cmp -s "$1" "$2"
	else
		[ "$(cat "$1")" = "$(cat "$2")" ] && return 0 || return 1
	fi
}
logger() { #日志工具
	#$1日志内容$2显示颜色$3是否推送
	[ -n "$2" -a "$2" != 0 ] && echo -e "\033[$2m$1\033[0m"
	log_text="$(date "+%G-%m-%d_%H:%M:%S")~$1"
	echo "$log_text" >>"$TMPDIR"/ShellCrash.log
	[ "$(wc -l "$TMPDIR"/ShellCrash.log | awk '{print $1}')" -gt 99 ] && sed -i '1,50d' "$TMPDIR"/ShellCrash.log
	#推送工具
	webpush() {
		[ -n "$(pidof CrashCore)" ] && {
			[ -n "$authentication" ] && auth="$authentication@"
			export https_proxy="http://${auth}127.0.0.1:$mix_port"
		}
		if curl --version >/dev/null 2>&1; then
			curl -kfsSl -X POST --connect-timeout 3 -H "Content-Type: application/json; charset=utf-8" "$1" -d "$2" >/dev/null 2>&1
		elif wget --version >/dev/null 2>&1; then
			wget -Y on -q --timeout=3 --method=POST --header="Content-Type: application/json; charset=utf-8" --body-data="$2" "$1"
		else
			echo "找不到有效的curl或wget应用，请先安装！"
		fi
	}
	[ -z "$3" ] && {
		[ -n "$device_name" ] && log_text="$log_text($device_name)"
		[ -n "$push_TG" ] && {
			url="https://api.telegram.org/bot${push_TG}/sendMessage"
			content="{\"chat_id\":\"${chat_ID}\",\"text\":\"$log_text\"}"
			webpush "$url" "$content" &
		}
		[ -n "$push_bark" ] && {
			url="${push_bark}"
			content="{\"body\":\"${log_text}\",\"title\":\"ShellCrash日志推送\",\"level\":\"passive\",\"badge\":\"1\"}"
			webpush "$url" "$content" &
		}
		[ -n "$push_Deer" ] && {
			url="https://api2.pushdeer.com/message/push"
			content="{\"pushkey\":\"${push_Deer}\",\"text\":\"$log_text\"}"
			webpush "$url" "$content" &
		}
		[ -n "$push_Po" ] && {
			url="https://api.pushover.net/1/messages.json"
			content="{\"token\":\"${push_Po}\",\"user\":\"${push_Po_key}\",\"title\":\"ShellCrash日志推送\",\"message\":\"$log_text\"}"
			webpush "$url" "$content" &
		}
		[ -n "$push_PP" ] && {
			url="http://www.pushplus.plus/send"
			content="{\"token\":\"${push_PP}\",\"title\":\"ShellCrash日志推送\",\"content\":\"$log_text\"}"
			webpush "$url" "$content" &
		}
	} &
}
croncmd() { #定时任务工具
	if [ -n "$(crontab -h 2>&1 | grep '\-l')" ]; then
		crontab "$1"
	else
		crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}')"
		[ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
		[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
		[ ! -w "$crondir" ] && crondir="/var/spool/cron"
		if [ -w "$crondir" ]; then
			[ "$1" = "-l" ] && cat "$crondir"/"$USER" 2>/dev/null
			[ -f "$1" ] && cat "$1" >"$crondir"/"$USER"
		else
			echo "你的设备不支持定时任务配置，脚本大量功能无法启用，请尝试使用搜索引擎查找安装方式！"
		fi
	fi
}
cronset() { #定时任务设置
	# 参数1代表要移除的关键字,参数2代表要添加的任务语句
	tmpcron="$TMPDIR"/cron_$USER
	croncmd -l >"$tmpcron" 2>/dev/null
	sed -i "/$1/d" "$tmpcron"
	sed -i '/^$/d' "$tmpcron"
	echo "$2" >>"$tmpcron"
	croncmd "$tmpcron"
	rm -f "$tmpcron"
}
get_save() { #获取面板信息
	if curl --version >/dev/null 2>&1; then
		curl -s -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1"
	elif [ -n "$(wget --help 2>&1 | grep '\-\-method')" ]; then
		wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1"
	fi
}
put_save() { #推送面板选择
	[ -z "$3" ] && request_type=PUT || request_type=$3
	if curl --version >/dev/null 2>&1; then
		curl -sS -X "$request_type" -H "Authorization: Bearer $secret" -H "Content-Type:application/json" "$1" -d "$2" >/dev/null
	elif wget --version >/dev/null 2>&1; then
		wget -q --method="$request_type" --header="Authorization: Bearer $secret" --header="Content-Type:application/json" --body-data="$2" "$1" >/dev/null
	fi
}
get_bin() { #专用于项目内部文件的下载
	. "$CRASHDIR"/configs/ShellCrash.cfg >/dev/null
	[ -z "$update_url" ] && update_url=https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master
	if [ -n "$url_id" ]; then
		[ -z "$release_type" ] && release_type=master
		if [ "$url_id" = 101 -o "$url_id" = 104 ]; then
			url="$(grep "$url_id" "$CRASHDIR"/configs/servers.list | awk '{print $3}')@$release_type/$2" #jsdelivr特殊处理
		else
			url="$(grep "$url_id" "$CRASHDIR"/configs/servers.list | awk '{print $3}')/$release_type/$2"
		fi
	else
		url="$update_url/$2"
	fi
	$0 webget "$1" "$url" "$3" "$4" "$5" "$6"
}
mark_time() { #时间戳
	date +%s >"$TMPDIR"/crash_start_time
}
getlanip() { #获取局域网host地址
	i=1
	while [ "$i" -le "20" ]; do
		host_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Ev 'utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/br.*$//g' | sed 's/metric.*$//g') #ipv4局域网网段
		[ "$ipv6_redir" = "已开启" ] && host_ipv6=$(ip a 2>&1 | grep -w 'inet6' | grep -E 'global' | sed 's/.*inet6.//g' | sed 's/scope.*$//g')                                                                                                                                #ipv6公网地址段
		[ -f "$TMPDIR"/ShellCrash.log ] && break
		[ -n "$host_ipv4" -a "$ipv6_redir" != "已开启" ] && break
		[ -n "$host_ipv4" -a -n "$host_ipv6" ] && break
		sleep 1 && i=$((i + 1))
	done
	#添加自定义ipv4局域网网段
	if [ "$replace_default_host_ipv4" == "已启用" ]; then
		host_ipv4="$cust_host_ipv4"
	else
		host_ipv4="$host_ipv4$cust_host_ipv4"
	fi
	#缺省配置
	[ -z "$host_ipv4" ] && host_ipv4='192.168.0.0/16 10.0.0.0/12 172.16.0.0/12'
	host_ipv6="fe80::/10 fd00::/8 $host_ipv6"
	#获取本机出口IP地址
	local_ipv4=$(ip route 2>&1 | grep -Ev 'utun|iot|docker|linkdown' | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
	[ -z "$local_ipv4" ] && local_ipv4=$(ip route 2>&1 | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
	#保留地址
	[ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
	[ -z "$reserve_ipv6" ] && reserve_ipv6="::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 100::/64 2001::/32 2001:20::/28 2001:db8::/32 2002::/16 fe80::/10 ff00::/8"
}
#配置文件相关
check_clash_config() { #检查clash配置文件
	#检测节点或providers
	sed -n "/^proxies:/,/^[a-z]/ { /^[a-z]/d; p; }" "$core_config_new" >"$TMPDIR"/proxies.yaml
	if ! grep -q 'server:' "$TMPDIR"/proxies.yaml && ! grep -q 'proxy-providers:' "$core_config_new"; then
		echo -----------------------------------------------
		logger "获取到了配置文件【$core_config_new】，但似乎并不包含正确的节点信息！" 31
		cat "$TMPDIR"/proxies.yaml
		sleep 1
		echo -----------------------------------------------
		echo "请尝试使用其他生成方式！"
		exit 1
	fi
	rm -rf "$TMPDIR"/proxies.yaml
	#检测旧格式
	if cat "$core_config_new" | grep 'Proxy Group:' >/dev/null; then
		echo -----------------------------------------------
		logger "已经停止对旧格式配置文件的支持！！！" 31
		echo -e "请使用新格式或者使用【在线生成配置文件】功能！"
		echo -----------------------------------------------
		exit 1
	fi
	#检测不支持的加密协议
	if cat "$core_config_new" | grep 'cipher: chacha20,' >/dev/null; then
		echo -----------------------------------------------
		logger "已停止支持chacha20加密，请更换更安全的节点加密协议！" 31
		echo -----------------------------------------------
		exit 1
	fi
	#检测并去除无效策略组
	[ -n "$url_type" ] && ckcmd xargs && {
		cat "$core_config_new" | sed '/^rules:/,$d' | grep -A 15 "\- name:" | xargs | sed 's/- name: /\n/g' | sed 's/ type: .*proxies: /#/g' | sed 's/- //g' | grep -E '#DIRECT $|#DIRECT$' | awk -F '#' '{print $1}' >"$TMPDIR"/clash_proxies_$USER
		while read line; do
			sed -i "/- $line/d" "$core_config_new"
			sed -i "/- name: $line/,/- DIRECT/d" "$core_config_new"
		done <"$TMPDIR"/clash_proxies_$USER
		rm -rf "$TMPDIR"/clash_proxies_$USER
	}
}
check_singbox_config() { #检查singbox配置文件
	#检测节点或providers
	if ! grep -qE '"(socks|http|shadowsocks(r)?|vmess|trojan|wireguard|hysteria(2)?|vless|shadowtls|tuic|ssh|tor|outbound_providers)"' "$core_config_new"; then
		echo -----------------------------------------------
		logger "获取到了配置文件【$core_config_new】，但似乎并不包含正确的节点信息！" 31
		echo "请尝试使用其他生成方式！"
		exit 1
	fi
	#检测并去除无效策略组
	[ -n "$url_type" ] && {
		#获得无效策略组名称
		grep -oE '\{"type":"[^"]*","tag":"[^"]*","outbounds":\["DIRECT"\]' $core_config_new | sed -n 's/.*"tag":"\([^"]*\)".*/\1/p' >"$TMPDIR"/singbox_tags
		#删除策略组
		sed -i 's/{"type":"[^"]*","tag":"[^"]*","outbounds":\["DIRECT"\]}//g; s/{"type":"[^"]*","tag":"[^"]*","outbounds":\["DIRECT"\],"url":"[^"]*","interval":"[^"]*","tolerance":[^}]*}//g' $core_config_new
		#删除全部包含策略组名称的规则
		while read line; do
			sed -i "s/\"$line\"//g" $core_config_new
		done <"$TMPDIR"/singbox_tags
		rm -rf "$TMPDIR"/singbox_tags
		#删除多余逗号
		sed -i 's/,\+/,/g; s/\[,/\[/g; s/,]/]/g' $core_config_new
	}
}
get_core_config() { #下载内核配置文件
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] || [ $server_link -gt $(grep -aE '^4' "$CRASHDIR"/configs/servers.list | wc -l) ] && server_link=1
	Server=$(grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	[ -n "$(echo $Url | grep -oE 'vless:|hysteria:')" ] && Server=$(grep -aE '^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	[ "$retry" = 4 ] && Server=$(grep -aE '^497' "$CRASHDIR"/configs/servers.list | awk '{print $3}')
	Config=$(grep -aE '^5' "$CRASHDIR"/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $3}')
	#如果传来的是Url链接则合成Https链接，否则直接使用Https链接
	if [ -z "$Https" ]; then
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
	core_config_new="$TMPDIR"/${target}_config.${format}
	rm -rf ${core_config_new}
	$0 webget "$core_config_new" "$Https"
	if [ "$?" = "1" ]; then
		if [ -z "$url_type" ]; then
			echo -----------------------------------------------
			logger "配置文件获取失败！" 31
			echo -e "\033[31m请尝试使用【在线生成配置文件】功能！\033[0m"
			echo -----------------------------------------------
			exit 1
		else
			if [ "$retry" -ge 4 ]; then
				logger "无法获取配置文件，请检查链接格式以及网络连接状态！" 31
				echo -e "\033[32m也可用浏览器下载以上链接后，使用WinSCP手动上传到/tmp目录后执行crash命令本地导入！\033[0m"
				exit 1
			elif [ "$retry" = 3 ]; then
				retry=4
				logger "配置文件获取失败！将尝试使用http协议备用服务器获取！" 31
				echo -e "\033[32m如担心数据安全，请在3s内使用【Ctrl+c】退出！\033[0m"
				sleep 3
				Https=""
				get_core_config
			else
				retry=$((retry + 1))
				logger "配置文件获取失败！" 31
				echo -e "\033[32m尝试使用其他服务器获取配置！\033[0m"
				logger "正在重试第$retry次/共4次！" 33
				if [ "$server_link" -ge 4 ]; then
					server_link=0
				fi
				server_link=$((server_link + 1))
				setconfig server_link $server_link
				Https=""
				get_core_config
			fi
		fi
	else
		Https=""
		if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
			check_singbox_config
		else
			check_clash_config
		fi
		#如果不同则备份并替换文件
		if [ -s $core_config ]; then
			compare $core_config_new $core_config
			[ "$?" = 0 ] || mv -f $core_config $core_config.bak && mv -f $core_config_new $core_config
		else
			mv -f $core_config_new $core_config
		fi
		echo -e "\033[32m已成功获取配置文件！\033[0m"
	fi
	return 0
}
modify_yaml() { #修饰clash配置文件
	##########需要变更的配置###########
	[ -z "$dns_nameserver" ] && dns_nameserver='114.114.114.114, 223.5.5.5'
	[ -z "$dns_fallback" ] && dns_fallback='1.0.0.1, 8.8.4.4'
	[ -z "$skip_cert" ] && skip_cert=已开启
	[ "$ipv6_dns" = "已开启" ] && dns_v6='true' || dns_v6='false'
	external="external-controller: 0.0.0.0:$db_port"
	if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ]; then
		[ "$crashcore" = 'meta' ] && tun_meta=', device: utun, auto-route: false, auto-detect-interface: false'
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
	[ -z "$(cat "$CRASHDIR"/yamls/user.yaml 2>/dev/null | grep '^dns:')" ] && {
		cat >"$TMPDIR"/dns.yaml <<EOF
dns:
  enable: true
  listen: :$dns_port
  use-hosts: true
  ipv6: $dns_v6
  default-nameserver:
    - 114.114.114.114
    - 223.5.5.5
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
EOF
		if [ "$dns_mod" = "fake-ip" ]; then
			cat "$CRASHDIR"/configs/fake_ip_filter "$CRASHDIR"/configs/fake_ip_filter.list 2>/dev/null | grep '\.' | sed "s/^/    - '/" | sed "s/$/'/" >>"$TMPDIR"/dns.yaml
		else
			echo "    - '+.*'" >>"$TMPDIR"/dns.yaml #使用fake-ip模拟redir_host
		fi
		cat >>"$TMPDIR"/dns.yaml <<EOF
  nameserver: [$dns_nameserver]
  fallback: [$dns_fallback]
  fallback-filter:
    geoip: true
EOF
		[ -s "$CRASHDIR"/configs/fallback_filter.list ] && {
			echo "    domain:" >>"$TMPDIR"/dns.yaml
			cat "$CRASHDIR"/configs/fallback_filter.list | grep '\.' | sed "s/^/      - '/" | sed "s/$/'/" >>"$TMPDIR"/dns.yaml
		}
	}
	#域名嗅探配置
	[ "$sniffer" = "已启用" ] && [ "$crashcore" = "meta" ] && sniffer_set="sniffer: {enable: true, parse-pure-ip: true, skip-domain: [Mijia Cloud], sniff: {tls: {ports: [443, 8443]}, http: {ports: [80, 8080-8880]}, quic: {ports: [443, 8443]}}}"
	[ "$crashcore" = "clashpre" ] && [ "$dns_mod" = "redir_host" -o "$sniffer" = "已启用" ] && exper="experimental: {ignore-resolve-fail: true, interface-name: en0,sniff-tls-sni: true}"
	#生成set.yaml
	cat >"$TMPDIR"/set.yaml <<EOF
mixed-port: $mix_port
redir-port: $redir_port
tproxy-port: $tproxy_port
authentication: ["$authentication"]
allow-lan: true
mode: Rule
log-level: info
ipv6: true
external-controller: :$db_port
external-ui: ui
secret: $secret
$tun
$exper
$sniffer_set
$find_process
routing-mark: $routing_mark
EOF
	#读取本机hosts并生成配置文件
	if [ "$hosts_opt" != "未启用" ] && [ -z "$(grep -aE '^hosts:' "$CRASHDIR"/yamls/user.yaml 2>/dev/null)" ]; then
		#NTP劫持
		cat >>"$TMPDIR"/hosts.yaml <<EOF
hosts:
   'time.android.com': 203.107.6.88
   'time.facebook.com': 203.107.6.88  
EOF
		#加载本机hosts
		sys_hosts=/etc/hosts
		[ -f /data/etc/custom_hosts ] && sys_hosts=/data/etc/custom_hosts
		while read line; do
			[ -n "$(echo "$line" | grep -oE "([0-9]{1,3}[\.]){3}")" ] &&
				[ -z "$(echo "$line" | grep -oE '^#')" ] &&
				hosts_ip=$(echo $line | awk '{print $1}') &&
				hosts_domain=$(echo $line | awk '{print $2}') &&
				[ -z "$(cat "$TMPDIR"/hosts.yaml | grep -oE "$hosts_domain")" ] &&
				echo "   '$hosts_domain': $hosts_ip" >>"$TMPDIR"/hosts.yaml
		done <$sys_hosts
	fi
	#分割配置文件
	yaml_char='proxies proxy-groups proxy-providers rules rule-providers'
	for char in $yaml_char; do
		sed -n "/^$char:/,/^[a-z]/ { /^[a-z]/d; p; }" $core_config >"$TMPDIR"/${char}.yaml
	done
	#跳过本地tls证书验证
	[ "$skip_cert" = "已开启" ] && sed -i 's/skip-cert-verify: false/skip-cert-verify: true/' "$TMPDIR"/proxies.yaml ||
		sed -i 's/skip-cert-verify: true/skip-cert-verify: false/' "$TMPDIR"/proxies.yaml
	#插入自定义策略组
	sed -i "/#自定义策略组开始/,/#自定义策略组结束/d" "$TMPDIR"/proxy-groups.yaml
	sed -i "/#自定义策略组/d" "$TMPDIR"/proxy-groups.yaml
	[ -n "$(grep -Ev '^#' "$CRASHDIR"/yamls/proxy-groups.yaml 2>/dev/null)" ] && {
		#获取空格数
		space_name=$(grep -aE '^ *- name: ' "$TMPDIR"/proxy-groups.yaml | head -n 1 | grep -oE '^ *')
		space_proxy=$(grep -A 1 'proxies:$' "$TMPDIR"/proxy-groups.yaml | grep -aE '^ *- ' | head -n 1 | grep -oE '^ *')
		#合并自定义策略组到proxy-groups.yaml
		cat "$CRASHDIR"/yamls/proxy-groups.yaml | sed "/^#/d" | sed "s/#.*//g" | sed '1i\ #自定义策略组开始' | sed '$a\ #自定义策略组结束' | sed "s/^ */${space_name}  /g" | sed "s/^ *- /${space_proxy}- /g" | sed "s/^ *- name: /${space_name}- name: /g" >"$TMPDIR"/proxy-groups_add.yaml
		cat "$TMPDIR"/proxy-groups.yaml >>"$TMPDIR"/proxy-groups_add.yaml
		mv -f "$TMPDIR"/proxy-groups_add.yaml "$TMPDIR"/proxy-groups.yaml
		oldIFS="$IFS"
		grep "\- name: " "$CRASHDIR"/yamls/proxy-groups.yaml | sed "/^#/d" | while read line; do #将自定义策略组插入现有的proxy-group
			new_group=$(echo $line | grep -Eo '^ *- name:.*#' | cut -d'#' -f1 | sed 's/.*name: //g')
			proxy_groups=$(echo $line | grep -Eo '#.*' | sed "s/#//")
			IFS="#"
			for name in $proxy_groups; do
				line_a=$(grep -n "\- name: $name" "$TMPDIR"/proxy-groups.yaml | awk -F: '{print $1}') #获取group行号
				[ -n "$line_a" ] && {
					line_b=$(grep -A 8 "\- name: $name" "$TMPDIR"/proxy-groups.yaml | grep -n "proxies:$" | awk -F: '{print $1}') #获取proxies行号
					line_c=$((line_a + line_b - 1))                                                                               #计算需要插入的行号
					space=$(sed -n "$((line_c + 1))p" "$TMPDIR"/proxy-groups.yaml | grep -oE '^ *')                               #获取空格数
					[ "$line_c" -gt 2 ] && sed -i "${line_c}a\\${space}- ${new_group} #自定义策略组" "$TMPDIR"/proxy-groups.yaml
				}
			done
			IFS="$oldIFS"
		done
	}
	#插入自定义代理
	sed -i "/#自定义代理/d" "$TMPDIR"/proxies.yaml
	sed -i "/#自定义代理/d" "$TMPDIR"/proxy-groups.yaml
	[ -n "$(grep -Ev '^#' "$CRASHDIR"/yamls/proxies.yaml 2>/dev/null)" ] && {
		space_proxy=$(cat "$TMPDIR"/proxies.yaml | grep -aE '^ *- ' | head -n 1 | grep -oE '^ *')                                                            #获取空格数
		cat "$CRASHDIR"/yamls/proxies.yaml | sed "s/^ *- /${space_proxy}- /g" | sed "/^#/d" | sed "/^ *$/d" | sed 's/#.*/ #自定义代理/g' >>"$TMPDIR"/proxies.yaml #插入节点
		oldIFS="$IFS"
		cat "$CRASHDIR"/yamls/proxies.yaml | sed "/^#/d" | while read line; do #将节点插入proxy-group
			proxy_name=$(echo $line | grep -Eo 'name: .+, ' | cut -d',' -f1 | sed 's/name: //g')
			proxy_groups=$(echo $line | grep -Eo '#.*' | sed "s/#//")
			IFS="#"
			for name in $proxy_groups; do
				line_a=$(grep -n "\- name: $name" "$TMPDIR"/proxy-groups.yaml | awk -F: '{print $1}') #获取group行号
				[ -n "$line_a" ] && {
					line_b=$(grep -A 8 "\- name: $name" "$TMPDIR"/proxy-groups.yaml | grep -n "proxies:$" | head -n 1 | awk -F: '{print $1}') #获取proxies行号
					line_c=$((line_a + line_b - 1))                                                                                           #计算需要插入的行号
					space=$(sed -n "$((line_c + 1))p" "$TMPDIR"/proxy-groups.yaml | grep -oE '^ *')                                           #获取空格数
					[ "$line_c" -gt 2 ] && sed -i "${line_c}a\\${space}- ${proxy_name} #自定义代理" "$TMPDIR"/proxy-groups.yaml
				}
			done
			IFS="$oldIFS"
		done
	}
	#节点绕过功能支持
	sed -i "/#节点绕过/d" "$TMPDIR"/rules.yaml
	[ "$proxies_bypass" = "已启用" ] && {
		cat "$TMPDIR"/proxies.yaml | sed '/^proxy-/,$d' | sed '/^rule-/,$d' | grep -v '^\s*#' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | awk '!a[$0]++' | sed 's/^/\ -\ IP-CIDR,/g' | sed 's|$|/32,DIRECT,no-resolve #节点绕过|g' >>"$TMPDIR"/proxies_bypass
		cat "$TMPDIR"/proxies.yaml | sed '/^proxy-/,$d' | sed '/^rule-/,$d' | grep -v '^\s*#' | grep -vE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?' | awk '!a[$0]++' | sed 's/^/\ -\ DOMAIN,/g' | sed 's/$/,DIRECT #节点绕过/g' >>"$TMPDIR"/proxies_bypass
		cat "$TMPDIR"/rules.yaml >>"$TMPDIR"/proxies_bypass
		mv -f "$TMPDIR"/proxies_bypass "$TMPDIR"/rules.yaml
	}
	#插入自定义规则
	sed -i "/#自定义规则/d" "$TMPDIR"/rules.yaml
	[ -s "$CRASHDIR"/yamls/rules.yaml ] && {
		cat "$CRASHDIR"/yamls/rules.yaml | sed "/^#/d" | sed '$a\' | sed 's/$/ #自定义规则/g' >"$TMPDIR"/rules.add
		cat "$TMPDIR"/rules.yaml >>"$TMPDIR"/rules.add
		mv -f "$TMPDIR"/rules.add "$TMPDIR"/rules.yaml
	}
	#对齐rules中的空格
	sed -i 's/^ *-/ -/g' "$TMPDIR"/rules.yaml
	#合并文件
	[ -s "$CRASHDIR"/yamls/user.yaml ] && {
		yaml_user="$CRASHDIR"/yamls/user.yaml
		#set和user去重,且优先使用user.yaml
		cp -f "$TMPDIR"/set.yaml "$TMPDIR"/set_bak.yaml
		for char in mode allow-lan log-level tun experimental interface-name dns store-selected; do
			[ -n "$(grep -E "^$char" $yaml_user)" ] && sed -i "/^$char/d" "$TMPDIR"/set.yaml
		done
	}
	[ -s "$TMPDIR"/dns.yaml ] && yaml_dns="$TMPDIR"/dns.yaml
	[ -s "$TMPDIR"/hosts.yaml ] && yaml_hosts="$TMPDIR"/hosts.yaml
	[ -s "$CRASHDIR"/yamls/others.yaml ] && yaml_others="$CRASHDIR"/yamls/others.yaml
	yaml_add=
	for char in $yaml_char; do #将额外配置文件合并
		[ -s "$TMPDIR"/${char}.yaml ] && {
			sed -i "1i\\${char}:" "$TMPDIR"/${char}.yaml
			yaml_add="$yaml_add "$TMPDIR"/${char}.yaml"
		}
	done
	#合并完整配置文件
	cut -c 1- "$TMPDIR"/set.yaml $yaml_dns $yaml_hosts $yaml_user $yaml_others $yaml_add >"$TMPDIR"/config.yaml
	#测试自定义配置文件
	"$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml >/dev/null
	if [ "$?" != 0 ]; then
		logger "$("$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml | grep -Eo 'error.*=.*')" 31
		logger "自定义配置文件校验失败！将使用基础配置文件启动！" 33
		logger "错误详情请参考 "$TMPDIR"/error.yaml 文件！" 33
		mv -f "$TMPDIR"/config.yaml "$TMPDIR"/error.yaml >/dev/null 2>&1
		sed -i "/#自定义策略组开始/,/#自定义策略组结束/d" "$TMPDIR"/proxy-groups.yaml
		mv -f "$TMPDIR"/set_bak.yaml "$TMPDIR"/set.yaml >/dev/null 2>&1
		#合并基础配置文件
		cut -c 1- "$TMPDIR"/set.yaml $yaml_dns $yaml_add >"$TMPDIR"/config.yaml
		sed -i "/#自定义/d" "$TMPDIR"/config.yaml
	fi
	#建立软连接
	[ ""$TMPDIR"" = ""$BINDIR"" ] || ln -sf "$TMPDIR"/config.yaml "$BINDIR"/config.yaml
	#清理缓存
	for char in $yaml_char set set_bak dns hosts; do
		rm -f "$TMPDIR"/${char}.yaml
	done
}
modify_json() { #修饰singbox配置文件
	#生成log.json
	cat >"$TMPDIR"/jsons/log.json <<EOF
{ "log": { "level": "info", "timestamp": true } }
EOF
	#生成add_hosts.json
	if [ "$hosts_opt" != "未启用" ]; then #本机hosts
		sys_hosts=/etc/hosts
		[ -s /data/etc/custom_hosts ] && sys_hosts=/data/etc/custom_hosts
		#NTP劫持
		[ -s $sys_hosts ] && {
			sed -i '/203.107.6.88/d' $sys_hosts
			cat >>$sys_hosts <<EOF
203.107.6.88 time.android.com
203.107.6.88 time.facebook.com
EOF
			hosts_domain=$(cat $sys_hosts | grep -E "^([0-9]{1,3}[\.]){3}" | awk '{printf "\"%s\", ", $2}' | sed 's/, $//')
			cat >"$TMPDIR"/jsons/add_hosts.json <<EOF
{
  "dns": { 
	"servers": [
	  { "tag": "hosts_local", "address": "local", "detour": "DIRECT" }
	],
    "rules": [
	  { 
	    "domain": [$hosts_domain], 
		"server": "hosts_local" 
	  }
	]
  }
}
EOF
		}
	fi
	#生成dns.json
	dns_direct=$(echo $dns_nameserver | awk -F ',' '{print $1}')
	dns_proxy=$(echo $dns_fallback | awk -F ',' '{print $1}')
	[ -z "$dns_direct" ] && dns_direct='223.5.5.5'
	[ -z "$dns_proxy" ] && dns_proxy='1.0.0.1'
	[ "$ipv6_dns" = "已开启" ] && strategy='prefer_ipv4' || strategy='ipv4_only'
	[ "$dns_mod" = "redir_host" ] && {
		global_dns=dns_proxy
		direct_dns="{ \"query_type\": [ \"A\", \"AAAA\" ], \"server\": \"dns_direct\" },"
	}
	[ "$dns_mod" = "fake-ip" ] && {
		global_dns=dns_fakeip
		fake_ip_filter_domain=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep -Ev '#|\*|\+|Mijia' | sed '/^\s*$/d' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
		fake_ip_filter_suffix=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep -v '.\*' | grep -E '\*|\+' | sed 's/^[*+]\.//' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
		fake_ip_filter_regex=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep '.\*' | sed 's/\./\\\\./g' | sed 's/\*/.\*/' | sed 's/^+/.\+/' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
		[ -n "$fake_ip_filter_domain" ] && fake_ip_filter_domain="{ \"domain\": [$fake_ip_filter_domain], \"server\": \"dns_direct\" },"
		[ -n "$fake_ip_filter_suffix" ] && fake_ip_filter_suffix="{ \"domain_suffix\": [$fake_ip_filter_suffix], \"server\": \"dns_direct\" },"
		[ -n "$fake_ip_filter_regex" ] && fake_ip_filter_regex="{ \"domain_regex\": [$fake_ip_filter_regex], \"server\": \"dns_direct\" },"
	}
	[ "$dns_mod" = "mix" ] && {
		global_dns=dns_fakeip
		fake_ip_filter_domain=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep -Ev '#|\*|\+|Mijia' | sed '/^\s*$/d' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
		fake_ip_filter_suffix=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep -v '.\*' | grep -E '\*|\+' | sed 's/^[*+]\.//' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
		fake_ip_filter_regex=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep '.\*' | sed 's/^*/.\*/' | sed 's/^+/.\+/' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
		[ -n "$fake_ip_filter_domain" ] && fake_ip_filter_domain="{ \"domain\": [$fake_ip_filter_domain], \"server\": \"dns_direct\" },"
		[ -n "$fake_ip_filter_suffix" ] && fake_ip_filter_suffix="{ \"domain_suffix\": [$fake_ip_filter_suffix], \"server\": \"dns_direct\" },"
		[ -n "$fake_ip_filter_regex" ] && fake_ip_filter_regex="{ \"domain_regex\": [$fake_ip_filter_regex], \"server\": \"dns_direct\" },"
		if [ -z "$(echo "$core_v" | grep -E '^1\.7.*')" ]; then
			direct_dns="{ \"rule_set\": [\"geosite-cn\"], \"server\": \"dns_direct\" },"
			#生成add_rule_set.json
			[ -z "$(cat "$CRASHDIR"/jsons/*.json | grep -Ei '"tag" *: *"geosite-cn"')" ] && cat >"$TMPDIR"/jsons/add_rule_set.json <<EOF
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
		else
			direct_dns="{ \"geosite\": \"geolocation-cn\", \"server\": \"dns_direct\" },"
		fi
	}
	cat >"$TMPDIR"/jsons/dns.json <<EOF
{
  "dns": { 
    "servers": [
	  {
        "tag": "dns_proxy",
        "address": "$dns_proxy",
        "strategy": "$strategy",
        "address_resolver": "dns_resolver"
      }, {
        "tag": "dns_direct",
        "address": "$dns_direct",
        "strategy": "$strategy",
        "address_resolver": "dns_resolver",
        "detour": "DIRECT"
      }, 
	  { "tag": "dns_fakeip", "address": "fakeip" }, 
	  { "tag": "dns_resolver", "address": "223.5.5.5", "detour": "DIRECT" }, 
	  { "tag": "block", "address": "rcode://success" }, 
	  { "tag": "local", "address": "local", "detour": "DIRECT" }
	],
    "rules": [
	  { "outbound": ["any"], "server": "dns_direct" },
	  { "clash_mode": "Global", "server": "$global_dns", "rewrite_ttl": 1 },
      { "clash_mode": "Direct", "server": "dns_direct" },
	  $fake_ip_filter_domain
	  $fake_ip_filter_suffix
	  $fake_ip_filter_regex
	  $direct_dns
	  { "query_type": [ "A", "AAAA" ], "server": "dns_fakeip", "rewrite_ttl": 1 }
	],
    "final": "dns_proxy",
    "independent_cache": true,
    "reverse_mapping": true,
    "fakeip": { "enabled": true, "inet4_range": "198.18.0.0/16", "inet6_range": "fc00::/16" }
  }
}
EOF
	#生成add_route.json
	cat >"$TMPDIR"/jsons/add_route.json <<EOF
{
  "route": {
    "rules": [ 
	{ "inbound": "dns-in", "outbound": "dns-out" }
	],
	"default_mark": $routing_mark
  }
}
EOF
	#生成ntp.json
	# cat > "$TMPDIR"/jsons/ntp.json <<EOF
	# {
	# "ntp": {
	# "enabled": true,
	# "server": "203.107.6.88",
	# "server_port": 123,
	# "interval": "30m0s",
	# "detour": "DIRECT"
	# }
	# }
	# EOF
	#生成inbounds.json
	[ -n "$authentication" ] && {
		username=$(echo $authentication | awk -F ':' '{print $1}') #混合端口账号密码
		password=$(echo $authentication | awk -F ':' '{print $2}')
		userpass='"users": [{ "username": "'$username'", "password": "'$password'" }], '
	}
	[ "$sniffer" = "已启用" ] && sniffer=true || sniffer=false #域名嗅探配置
	#[ "$crashcore" = singboxp ] && always_resolve_udp='"always_resolve_udp": true,'
	cat >"$TMPDIR"/jsons/inbounds.json <<EOF
{
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "::",
      "listen_port": $mix_port,
	  $userpass
      "sniff": false
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
	if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ]; then
		cat >>"$TMPDIR"/jsons/tun.json <<EOF
{
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "utun",
      "inet4_address": "172.19.0.1/30",
      "auto_route": false,
      "stack": "system",
      "sniff": true,
      "sniff_override_destination": $sniffer
    }
  ]
}
EOF
	fi
	#生成add_outbounds.json
	[ -z "$(cat "$CRASHDIR"/jsons/*.json | grep -oE '"tag" *: *"DIRECT"')" ] && add_direct='{ "tag": "DIRECT", "type": "direct" }'
	[ -z "$(cat "$CRASHDIR"/jsons/*.json | grep -oE '"tag" *: *"REJECT"')" ] && add_reject='{ "tag": "REJECT", "type": "block" }'
	[ -z "$(cat "$CRASHDIR"/jsons/*.json | grep -oE '"tag" *: *"dns-out"')" ] && add_dnsout='{ "tag": "dns-out", "type": "dns" }'
	[ -n "$add_direct" -a -n "$add_reject" ] && add_direct="${add_direct},"
	[ -n "$add_reject" -a -n "$add_dnsout" ] && add_reject="${add_reject},"
	[ -n "$add_direct" -o -n "$add_reject" -o -n "$add_dnsout" ] && cat >"$TMPDIR"/jsons/add_outbounds.json <<EOF
{
  "outbounds": [ 
    $add_direct
	$add_reject
	$add_dnsout
  ]
}
EOF
	#生成experimental.json
	cat >"$TMPDIR"/jsons/experimental.json <<EOF
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
	[ -n "$(grep -Ev ^# "$CRASHDIR"/yamls/rules.yaml 2>/dev/null)" ] && {
		cat "$CRASHDIR"/yamls/rules.yaml |
			sed '/#.*/d' |
			grep -oE '\-.*,.*,.*' |
			sed 's/- DOMAIN-SUFFIX,/{ "domain_suffix": [ "/g' |
			sed 's/- DOMAIN-KEYWORD,/{ "domain_keyword": [ "/g' |
			sed 's/- IP-CIDR,/{ "ip_cidr": [ "/g' |
			sed 's/- SRC-IP-CIDR,/{ "._ip_cidr": [ "/g' |
			sed 's/- DST-PORT,/{ "port": [ "/g' |
			sed 's/- SRC-PORT,/{ "._port": [ "/g' |
			sed 's/- GEOIP,/{ "geoip": [ "/g' |
			sed 's/- GEOSITE,/{ "geosite": [ "/g' |
			sed 's/- IP-CIDR6,/{ "ip_cidr": [ "/g' |
			sed 's/- DOMAIN,/{ "domain": [ "/g' |
			sed 's/,/" ], "outbound": "/g' |
			sed 's/$/" },/g' |
			sed '1i\{ "route": { "rules": [ ' |
			sed '$s/,$/ ] } }/' >"$TMPDIR"/jsons/cust_add_rules.json
		[ ! -s "$TMPDIR"/jsons/cust_add_rules.json ] && rm -rf "$TMPDIR"/jsons/cust_add_rules.json
	}
	#提取配置文件以获得outbounds.json,outbound_providers.json及route.json
	"$TMPDIR"/CrashCore format -c $core_config >"$TMPDIR"/format.json
	echo '{' >"$TMPDIR"/jsons/outbounds.json
	echo '{' >"$TMPDIR"/jsons/route.json
	cat "$TMPDIR"/format.json | sed -n '/"outbounds":/,/^  "[a-z]/p' | sed '$d' >>"$TMPDIR"/jsons/outbounds.json
	[ "$crashcore" = "singboxp" ] && {
		echo '{' >"$TMPDIR"/jsons/outbound_providers.json
		cat "$TMPDIR"/format.json | sed -n '/"outbound_providers":/,/^  "[a-z]/p' | sed '$d' >>"$TMPDIR"/jsons/outbound_providers.json
	}
	cat "$TMPDIR"/format.json | sed -n '/"route":/,/^\(  "[a-z]\|}\)/p' | sed '$d' >>"$TMPDIR"/jsons/route.json
	#清理route.json中的process_name规则以及"auto_detect_interface"
	sed -i '/"process_name": \[/,/],$/d' "$TMPDIR"/jsons/route.json
	sed -i '/"process_name": "[^"]*",/d' "$TMPDIR"/jsons/route.json
	sed -i 's/"auto_detect_interface": true/"auto_detect_interface": false/g' "$TMPDIR"/jsons/route.json
	#跳过本地tls证书验证
	if [ -z "$skip_cert" -o "$skip_cert" = "已开启" ]; then
		sed -i 's/"insecure": false/"insecure": true/' "$TMPDIR"/jsons/outbounds.json
	else
		sed -i 's/"insecure": true/"insecure": false/' "$TMPDIR"/jsons/outbounds.json
	fi
	#判断可用并修饰outbounds&outbound_providers&route.json结尾
	for file in outbounds outbound_providers route; do
		if [ -n "$(grep ${file} "$TMPDIR"/jsons/${file}.json 2>/dev/null)" ]; then
			sed -i 's/^  },$/  }/; s/^  ],$/  ]/' "$TMPDIR"/jsons/${file}.json
			echo '}' >>"$TMPDIR"/jsons/${file}.json
		else
			rm -rf "$TMPDIR"/jsons/${file}.json
		fi
	done
	#加载自定义配置文件
	mkdir -p "$TMPDIR"/jsons_base
	for char in log dns ntp experimental; do
		[ -s "$CRASHDIR"/jsons/${char}.json ] && {
			ln -sf "$CRASHDIR"/jsons/${char}.json "$TMPDIR"/jsons/cust_${char}.json
			mv -f "$TMPDIR"/jsons/${char}.json "$TMPDIR"/jsons_base #如果重复则临时备份
		}
	done
	for char in others inbounds outbounds outbound_providers route rule-set; do
		[ -s "$CRASHDIR"/jsons/${char}.json ] && {
			ln -sf "$CRASHDIR"/jsons/${char}.json "$TMPDIR"/jsons/cust_${char}.json
		}
	done
	#测试自定义配置文件
	error=$("$TMPDIR"/CrashCore check -D "$BINDIR" -C "$TMPDIR"/jsons 2>&1)
	if [ -n "$error" ]; then
		echo $error
		error_file=$(echo $error | grep -Eo 'cust.*\.json' | sed 's/cust_//g')
		[ "$error_file" = 'add_rules.json' ] && error_file="$CRASHDIR"/yamls/rules.yaml自定义规则 || error_file="$CRASHDIR"/jsons/$error_file
		logger "自定义配置文件校验失败，请检查【${error_file}】文件！" 31
		logger "尝试使用基础配置文件启动~" 33
		#清理自定义配置文件并还原基础配置
		rm -rf "$TMPDIR"/jsons/cust_*
		mv -f "$TMPDIR"/jsons_base/* "$TMPDIR"/jsons 2>/dev/null
	fi
	#清理缓存
	rm -rf "$TMPDIR"/*.json
	rm -rf "$TMPDIR"/jsons_base
	return 0
}

#设置路由规则
cn_ip_route() { #CN-IP绕过
	ckgeo cn_ip.txt china_ip_list.txt
	[ -f "$BINDIR"/cn_ip.txt ] && [ "$firewall_mod" = iptables ] && {
		# see https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/CN-ip-cidr.txt
		echo "create cn_ip hash:net family inet hashsize 10240 maxelem 10240" >"$TMPDIR"/cn_ip.ipset
		awk '!/^$/&&!/^#/{printf("add cn_ip %s'" "'\n",$0)}' "$BINDIR"/cn_ip.txt >>"$TMPDIR"/cn_ip.ipset
		ipset destroy cn_ip >/dev/null 2>&1
		ipset -! restore <"$TMPDIR"/cn_ip.ipset
		rm -rf "$TMPDIR"/cn_ip.ipset
	}
}
cn_ipv6_route() { #CN-IPV6绕过
	ckgeo cn_ipv6.txt china_ipv6_list.txt
	[ -f "$BINDIR"/cn_ipv6.txt ] && [ "$firewall_mod" = iptables ] && {
		#ipv6
		#see https://ispip.clang.cn/all_cn_ipv6.txt
		echo "create cn_ip6 hash:net family inet6 hashsize 5120 maxelem 5120" >"$TMPDIR"/cn_ipv6.ipset
		awk '!/^$/&&!/^#/{printf("add cn_ip6 %s'" "'\n",$0)}' "$BINDIR"/cn_ipv6.txt >>"$TMPDIR"/cn_ipv6.ipset
		ipset destroy cn_ip6 >/dev/null 2>&1
		ipset -! restore <"$TMPDIR"/cn_ipv6.ipset
		rm -rf "$TMPDIR"/cn_ipv6.ipset
	}
}
start_ipt_route() { #iptables-route通用工具
	#$1:iptables/ip6tables	$2:所在的表(nat/mangle) $3:所在的链(OUTPUT/PREROUTING)	$4:新创建的shellcrash链表	$5:tcp/udp/all
	#区分ipv4/ipv6
	[ "$1" = 'iptables' ] && {
		RESERVED_IP=$reserve_ipv4
		HOST_IP=$host_ipv4
		[ "$3" = 'OUTPUT' ] && HOST_IP="127.0.0.0/8 $local_ipv4"
		[ "$4" = 'shellcrash_vm' ] && HOST_IP="$vm_ipv4"
		iptables -h | grep -q '\-w' && w='-w' || w=''
	}
	[ "$1" = 'ip6tables' ] && {
		RESERVED_IP=$reserve_ipv6
		HOST_IP=$host_ipv6
		[ "$3" = 'OUTPUT' ] && HOST_IP="::1 $host_ipv6"
		ip6tables -h | grep -q '\-w' && w='-w' || w=''
	}
	#创建新的shellcrash链表
	$1 $w -t $2 -N $4
	#过滤dns
	$1 $w -t $2 -A $4 -p tcp --dport 53 -j RETURN
	$1 $w -t $2 -A $4 -p udp --dport 53 -j RETURN
	#防回环
	$1 $w -t $2 -A $4 -m mark --mark $routing_mark -j RETURN
	[ "$3" = 'OUTPUT' ] && for gid in 453 7890; do
		$1 $w -t $2 -A $4 -m owner --gid-owner $gid -j RETURN
	done
	[ "$firewall_area" = 5 ] && $1 $w -t $2 -A $4 -s $bypass_host -j RETURN
	[ -z "$ports" ] && $1 $w -t $2 -A $4 -p tcp -m multiport --dports "$mix_port,$redir_port,$tproxy_port" -j RETURN
	#跳过目标保留地址及目标本机网段
	for ip in $HOST_IP $RESERVED_IP; do
		$1 $w -t $2 -A $4 -d $ip -j RETURN
	done
	#绕过CN_IP
	[ "$1" = iptables ] && [ "$dns_mod" != "fake-ip" ] && [ "$cn_ip_route" = "已开启" ] && [ -f "$BINDIR"/cn_ip.txt ] && $1 $w -t $2 -A $4 -m set --match-set cn_ip dst -j RETURN 2>/dev/null
	[ "$1" = ip6tables ] && [ "$dns_mod" != "fake-ip" ] && [ "$cn_ipv6_route" = "已开启" ] && [ -f "$BINDIR"/cn_ipv6.txt ] && $1 $w -t $2 -A $4 -m set --match-set cn_ip6 dst -j RETURN 2>/dev/null
	#局域网mac地址黑名单过滤
	[ "$3" = 'PREROUTING' ] && [ "$macfilter_type" != "白名单" ] && {
		[ -s "$CRASHDIR"/configs/mac ] &&
			for mac in $(cat "$CRASHDIR"/configs/mac); do
				$1 $w -t $2 -A $4 -m mac --mac-source $mac -j RETURN
			done
		[ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
			for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
				$1 $w -t $2 -A $4 -s $ip -j RETURN
			done
	}
	#tcp&udp分别进代理链
	proxy_set() {
		if [ "$3" = 'PREROUTING' ] && [ "$4" != 'shellcrash_vm' ] && [ "$macfilter_type" = "白名单" ] && [ -n "$(cat $CRASHDIR/configs/mac $CRASHDIR/configs/ip_filter 2>/dev/null)" ]; then
			[ -s "$CRASHDIR"/configs/mac ] &&
				for mac in $(cat "$CRASHDIR"/configs/mac); do
					$1 $w -t $2 -A $4 -p $5 -m mac --mac-source $mac -j $JUMP
				done
			[ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
				for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
					$1 $w -t $2 -A $4 -p $5 -s $ip -j $JUMP
				done
		else
			for ip in $HOST_IP; do #仅限指定网段流量
				$1 $w -t $2 -A $4 -p $5 -s $ip -j $JUMP
			done
		fi
		#将所在链指定流量指向shellcrash表
		$1 $w -t $2 -I $3 -p $5 $ports -j $4
		[ "$dns_mod" != "redir_host" ] && [ "$common_ports" = "已开启" ] && [ "$1" = iptables ] && $1 $w -t $2 -I $3 -p $5 -d 198.18.0.0/16 -j $4
	}
	[ "$5" = "tcp" -o "$5" = "all" ] && proxy_set $1 $2 $3 $4 tcp
	[ "$5" = "udp" -o "$5" = "all" ] && proxy_set $1 $2 $3 $4 udp
}
start_ipt_dns() { #iptables-dns通用工具
	#$1:iptables/ip6tables	$2:所在的表(OUTPUT/PREROUTING)	$3:新创建的shellcrash表
	#区分ipv4/ipv6
	[ "$1" = 'iptables' ] && {
		HOST_IP="$host_ipv4"
		[ "$2" = 'OUTPUT' ] && HOST_IP="127.0.0.0/8 $local_ipv4"
		[ "$3" = 'shellcrash_vm_dns' ] && HOST_IP="$vm_ipv4"
		iptables -h | grep -q '\-w' && w='-w' || w=''
	}
	[ "$1" = 'ip6tables' ] && {
		HOST_IP=$host_ipv6
		ip6tables -h | grep -q '\-w' && w='-w' || w=''
	}
	$1 $w -t nat -N $3
	#防回环
	$1 $w -t nat -A $3 -m mark --mark $routing_mark -j RETURN
	[ "$2" = 'OUTPUT' ] && for gid in 453 7890; do
		$1 $w -t nat -A $3 -m owner --gid-owner $gid -j RETURN
	done
	[ "$firewall_area" = 5 ] && {
		$1 $w -t nat -A $3 -p tcp -s $bypass_host -j RETURN
		$1 $w -t nat -A $3 -p udp -s $bypass_host -j RETURN
	}
	#局域网mac地址黑名单过滤
	[ "$2" = 'PREROUTING' ] && [ "$macfilter_type" != "白名单" ] && {
		[ -s "$CRASHDIR"/configs/mac ] &&
			for mac in $(cat "$CRASHDIR"/configs/mac); do
				$1 $w -t nat -A $3 -m mac --mac-source $mac -j RETURN
			done
		[ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
			for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
				$1 $w -t nat -A $3 -s $ip -j RETURN
			done
	}
	if [ "$2" = 'PREROUTING' ] && [ "$3" != 'shellcrash_vm_dns' ] && [ "$macfilter_type" = "白名单" ] && [ -n "$(cat $CRASHDIR/configs/mac $CRASHDIR/configs/ip_filter 2>/dev/null)" ]; then
		[ -s "$CRASHDIR"/configs/mac ] &&
			for mac in $(cat "$CRASHDIR"/configs/mac); do
				$1 $w -t nat -A $3 -p tcp -m mac --mac-source $mac -j REDIRECT --to-ports $dns_port
				$1 $w -t nat -A $3 -p udp -m mac --mac-source $mac -j REDIRECT --to-ports $dns_port
			done
		[ -s "$CRASHDIR"/configs/ip_filter ] && [ "$1" = 'iptables' ] &&
			for ip in $(cat "$CRASHDIR"/configs/ip_filter); do
				$1 $w -t nat -A $3 -p tcp -s $ip -j REDIRECT --to-ports $dns_port
				$1 $w -t nat -A $3 -p udp -s $ip -j REDIRECT --to-ports $dns_port
			done
	else
		for ip in $HOST_IP; do #仅限指定网段流量
			$1 $w -t nat -A $3 -p tcp -s $ip -j REDIRECT --to-ports $dns_port
			$1 $w -t nat -A $3 -p udp -s $ip -j REDIRECT --to-ports $dns_port
		done
	fi
	[ "$1" = 'ip6tables' ] && { #屏蔽外部请求
		$1 $w -t nat -A $3 -p tcp -j RETURN
		$1 $w -t nat -A $3 -p udp -j RETURN
	}
	$1 $w -t nat -I $2 -p tcp --dport 53 -j $3
	$1 $w -t nat -I $2 -p udp --dport 53 -j $3
}
start_ipt_wan() { #iptables公网防火墙
	#获取局域网host地址
	getlanip
	if [ "$public_support" = "已开启" ]; then
		$iptable -I INPUT -p tcp --dport $db_port -j ACCEPT
		ckcmd ip6tables && $ip6table -I INPUT -p tcp --dport $db_port -j ACCEPT
	else
		#仅允许非公网设备访问面板
		for ip in $reserve_ipv4; do
			$iptable -A INPUT -p tcp -s $ip --dport $db_port -j ACCEPT
		done
		$iptable -A INPUT -p tcp --dport $db_port -j REJECT
		ckcmd ip6tables && $ip6table -A INPUT -p tcp --dport $db_port -j REJECT
	fi
	if [ "$public_mixport" = "已开启" ]; then
		$iptable -I INPUT -p tcp --dport $mix_port -j ACCEPT
		ckcmd ip6tables && $ip6table -I INPUT -p tcp --dport $mix_port -j ACCEPT
	else
		#仅允许局域网设备访问混合端口
		for ip in $reserve_ipv4; do
			$iptable -A INPUT -p tcp -s $ip --dport $mix_port -j ACCEPT
		done
		$iptable -A INPUT -p tcp --dport $mix_port -j REJECT
		ckcmd ip6tables && $ip6table -A INPUT -p tcp --dport $mix_port -j REJECT
	fi
	$iptable -I INPUT -p tcp -d 127.0.0.1 -j ACCEPT #本机请求全放行
}
start_iptables() { #iptables配置总入口
	#启动公网访问防火墙
	start_ipt_wan
	#分模式设置流量劫持
	[ "$redir_mod" = "Redir模式" -o "$redir_mod" = "混合模式" ] && {
		JUMP="REDIRECT --to-ports $redir_port" #跳转劫持的具体命令
		[ "$lan_proxy" = true ] && {
			start_ipt_route iptables nat PREROUTING shellcrash tcp #ipv4-局域网tcp转发
			[ "$ipv6_redir" = "已开启" ] && {
				if $ip6table -j REDIRECT -h 2>/dev/null | grep -q '\--to-ports'; then
					start_ipt_route ip6tables nat PREROUTING shellcrashv6 tcp #ipv6-局域网tcp转发
				else
					logger "当前设备内核缺少ip6tables_REDIRECT模块支持，已放弃启动相关规则！" 31
				fi
			}
		}
		[ "$local_proxy" = true ] && {
			start_ipt_route iptables nat OUTPUT shellcrash_out tcp #ipv4-本机tcp转发
			[ "$ipv6_redir" = "已开启" ] && {
				if $ip6table -j REDIRECT -h 2>/dev/null | grep -q '\--to-ports'; then
					start_ipt_route ip6tables nat OUTPUT shellcrashv6_out tcp #ipv6-本机tcp转发
				else
					logger "当前设备内核缺少ip6tables_REDIRECT模块支持，已放弃启动相关规则！" 31
				fi
			}
		}
	}
	[ "$redir_mod" = "Tproxy模式" ] && {
		modprobe xt_TPROXY >/dev/null 2>&1
		JUMP="TPROXY --on-port $tproxy_port --tproxy-mark $fwmark" #跳转劫持的具体命令
		if $iptable -j TPROXY -h 2>/dev/null | grep -q '\--on-port'; then
			[ "$lan_proxy" = true ] && start_ipt_route iptables mangle PREROUTING shellcrash_mark all
			[ "$local_proxy" = true ] && {
				if [ -n "$(grep -E '^MARK$' /proc/net/ip_tables_targets)" ]; then
					JUMP="MARK --set-mark $fwmark" #跳转劫持的具体命令
					start_ipt_route iptables mangle OUTPUT shellcrash_mark_out all
					$iptable -t mangle -A PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port
					$iptable -t mangle -A PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port
				else
					logger "当前设备内核可能缺少xt_mark模块支持，已放弃启动本机代理相关规则！" 31
				fi
			}
		else
			logger "当前设备内核可能缺少kmod_ipt_tproxy模块支持，已放弃启动相关规则！" 31
		fi
		[ "$ipv6_redir" = "已开启" ] && {
			if $ip6table -j TPROXY -h 2>/dev/null | grep -q '\--on-port'; then
				JUMP="TPROXY --on-port $tproxy_port --tproxy-mark $fwmark" #跳转劫持的具体命令
				[ "$lan_proxy" = true ] && start_ipt_route ip6tables mangle PREROUTING shellcrashv6_mark all
				[ "$local_proxy" = true ] && {
					if [ -n "$(grep -E '^MARK$' /proc/net/ip6_tables_targets)" ]; then
						JUMP="MARK --set-mark $fwmark" #跳转劫持的具体命令
						start_ipt_route ip6tables mangle OUTPUT shellcrashv6_mark_out all
						$ip6table -t mangle -A PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port
						$ip6table -t mangle -A PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port
					else
						logger "当前设备内核可能缺少xt_mark模块支持，已放弃启动本机代理相关规则！" 31
					fi
				}
			else
				logger "当前设备内核可能缺少kmod_ipt_tproxy或者xt_mark模块支持，已放弃启动相关规则！" 31
			fi
		}
	}
	[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" -o "$redir_mod" = "T&U旁路转发" -o "$redir_mod" = "TCP旁路转发" ] && {
		JUMP="MARK --set-mark $fwmark" #跳转劫持的具体命令
		[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "T&U旁路转发" ] && protocol=all
		[ "$redir_mod" = "混合模式" ] && protocol=udp
		[ "$redir_mod" = "TCP旁路转发" ] && protocol=tcp
		if $iptable -j MARK -h 2>/dev/null | grep -q '\--set-mark'; then
			[ "$lan_proxy" = true ] && {
				[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && $iptable -I FORWARD -o utun -j ACCEPT
				start_ipt_route iptables mangle PREROUTING shellcrash_mark $protocol
			}
			[ "$local_proxy" = true ] && start_ipt_route iptables mangle OUTPUT shellcrash_mark_out $protocol
		else
			logger "当前设备内核可能缺少x_mark模块支持，已放弃启动相关规则！" 31
		fi
		[ "$ipv6_redir" = "已开启" ] && [ "$crashcore" != clashpre ] && {
			if $ip6table -j MARK -h 2>/dev/null | grep -q '\--set-mark'; then
				[ "$lan_proxy" = true ] && {
					[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && $ip6table -I FORWARD -o utun -j ACCEPT
					start_ipt_route ip6tables mangle PREROUTING shellcrashv6_mark $protocol
				}
				[ "$local_proxy" = true ] && start_ipt_route ip6tables mangle OUTPUT shellcrashv6_mark_out $protocol
			else
				logger "当前设备内核可能缺少xt_mark模块支持，已放弃启动相关规则！" 31
			fi
		}
	}
	[ "$vm_redir" = "已开启" ] && [ -n "$$vm_ipv4" ] && {
		JUMP="REDIRECT --to-ports $redir_port"                    #跳转劫持的具体命令
		start_ipt_dns iptables PREROUTING shellcrash_vm_dns       #ipv4-局域网dns转发
		start_ipt_route iptables nat PREROUTING shellcrash_vm tcp #ipv4-局域网tcp转发
	}
	#启动DNS劫持
	[ "$dns_no" != "已禁用" -a "$dns_redir" != "已开启" -a "$firewall_area" -le 3 ] && {
		[ "$lan_proxy" = true ] && {
			start_ipt_dns iptables PREROUTING shellcrash_dns #ipv4-局域网dns转发
			if $ip6table -j REDIRECT -h 2>/dev/null | grep -q '\--to-ports'; then
				start_ipt_dns ip6tables PREROUTING shellcrashv6_dns #ipv6-局域网dns转发
			else
				$ip6table -I INPUT -p tcp --dport 53 -j REJECT >/dev/null 2>&1
				$ip6table -I INPUT -p udp --dport 53 -j REJECT >/dev/null 2>&1
			fi
		}
		[ "$local_proxy" = true ] && start_ipt_dns iptables OUTPUT shellcrash_dns_out #ipv4-本机dns转发
	}
	#屏蔽QUIC
	[ "$quic_rj" = '已启用' -a "$lan_proxy" = true -a "$redir_mod" != "Redir模式" ] && {
		[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && {
			set_cn_ip='-m set ! --match-set cn_ip dst'
			set_cn_ip6='-m set ! --match-set cn_ip6 dst'
		}
		[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && {
			$iptable -I FORWARD -p udp --dport 443 -o utun $set_cn_ip -j REJECT >/dev/null 2>&1
			$ip6table -I FORWARD -p udp --dport 443 -o utun $set_cn_ip6 -j REJECT >/dev/null 2>&1
		}
		[ "$redir_mod" = "Tproxy模式" ] && {
			$iptable -I INPUT -p udp --dport 443 $set_cn_ip -j REJECT >/dev/null 2>&1
			$ip6table -I INPUT -p udp --dport 443 $set_cn_ip6 -j REJECT >/dev/null 2>&1
		}
	}
}
start_nft_route() { #nftables-route通用工具
	#$1:name  $2:hook(prerouting/output)  $3:type(nat/mangle/filter)  $4:priority(-100/-150)
	[ "$common_ports" = "已开启" ] && PORTS=$(echo $multiport | sed 's/,/, /g')
	RESERVED_IP=$(echo $reserve_ipv4 | sed 's/ /, /g')
	HOST_IP=$(echo $host_ipv4 | sed 's/ /, /g')
	[ "$1" = 'output' ] && HOST_IP="127.0.0.0/8, $(echo $local_ipv4 | sed 's/ /, /g')"
	[ "$1" = 'prerouting_vm' ] && HOST_IP="$(echo $vm_ipv4 | sed 's/ /, /g')"
	#添加新链
	nft add chain inet shellcrash $1 { type $3 hook $2 priority $4 \; }
	#过滤dns
	nft add rule inet shellcrash $1 tcp dport 53 return
	nft add rule inet shellcrash $1 udp dport 53 return
	#过滤常用端口
	[ -n "$PORTS" ] && nft add rule inet shellcrash $1 tcp dport != {$PORTS} ip daddr != {198.18.0.0/16} return
	#防回环
	nft add rule inet shellcrash $1 meta mark $routing_mark return
	nft add rule inet shellcrash $1 meta skgid 7890 return
	[ -z "$ports" ] && nft add rule inet shellcrash $1 tcp dport {"$mix_port, $redir_port, $tproxy_port"} return
	#nft add rule inet shellcrash $1 ip saddr 198.18.0.0/16 return
	[ "$firewall_area" = 5 ] && nft add rule inet shellcrash $1 ip saddr $bypass_host return
	nft add rule inet shellcrash $1 ip daddr {$RESERVED_IP} return #过滤保留地址
	#过滤局域网设备
	[ "$1" = 'prerouting' ] && {
		[ "$macfilter_type" != "白名单" ] && {
			[ -s "$CRASHDIR"/configs/mac ] && {
				MAC=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/mac)
				nft add rule inet shellcrash $1 ether saddr {$MAC} return
			}
			[ -s "$CRASHDIR"/configs/ip_filter ] && {
				FL_IP=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/ip_filter)
				nft add rule inet shellcrash $1 ip saddr {$FL_IP} return
			}
			nft add rule inet shellcrash $1 ip saddr != {$HOST_IP} return #仅代理本机局域网网段流量
		}
		[ "$macfilter_type" = "白名单" ] && {
			[ -s "$CRASHDIR"/configs/mac ] && MAC=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/mac)
			[ -s "$CRASHDIR"/configs/ip_filter ] && FL_IP=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/ip_filter)
			if [ -n "$MAC" ] && [ -n "$FL_IP" ]; then
				nft add rule inet shellcrash $1 ether saddr != {$MAC} ip saddr != {$FL_IP} return
			elif [ -n "$MAC" ]; then
				nft add rule inet shellcrash $1 ether saddr != {$MAC} return
			elif [ -n "$FL_IP" ]; then
				nft add rule inet shellcrash $1 ip saddr != {$FL_IP} return
			else
				nft add rule inet shellcrash $1 ip saddr != {$HOST_IP} return #仅代理本机局域网网段流量
			fi
		}
	}
	#绕过CN-IP
	[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" -a -f "$BINDIR"/cn_ip.txt ] && {
		CN_IP=$(awk '{printf "%s, ",$1}' "$BINDIR"/cn_ip.txt)
		[ -n "$CN_IP" ] && nft add rule inet shellcrash $1 ip daddr {$CN_IP} return
	}
	#局域网ipv6支持
	if [ "$ipv6_redir" = "已开启" -a "$1" = 'prerouting' -a "$firewall_area" != 5 ]; then
		RESERVED_IP6="$(echo "$reserve_ipv6 $host_ipv6" | sed 's/ /, /g')"
		HOST_IP6="$(echo $host_ipv6 | sed 's/ /, /g')"
		#过滤保留地址及本机地址
		nft add rule inet shellcrash $1 ip6 daddr {$RESERVED_IP6} return
		#仅代理本机局域网网段流量
		nft add rule inet shellcrash $1 ip6 saddr != {$HOST_IP6} return
		#绕过CN_IPV6
		[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" -a -f "$BINDIR"/cn_ipv6.txt ] && {
			CN_IP6=$(awk '{printf "%s, ",$1}' "$BINDIR"/cn_ipv6.txt)
			[ -n "$CN_IP6" ] && nft add rule inet shellcrash $1 ip6 daddr {$CN_IP6} return
		}
	elif [ "$ipv6_redir" = "已开启" -a "$1" = 'output' -a \( "$firewall_area" = 2 -o "$firewall_area" = 3 \) ]; then
		RESERVED_IP6="$(echo "$reserve_ipv6 $host_ipv6" | sed 's/ /, /g')"
		HOST_IP6="::1, $(echo $host_ipv6 | sed 's/ /, /g')"
		#过滤保留地址及本机地址
		nft add rule inet shellcrash $1 ip6 daddr {$RESERVED_IP6} return
		#仅代理本机局域网网段流量
		nft add rule inet shellcrash $1 ip6 saddr != {$HOST_IP6} return
		#绕过CN_IPV6
		[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" -a -f "$BINDIR"/cn_ipv6.txt ] && {
			CN_IP6=$(awk '{printf "%s, ",$1}' "$BINDIR"/cn_ipv6.txt)
			[ -n "$CN_IP6" ] && nft add rule inet shellcrash $1 ip6 daddr {$CN_IP6} return
		}
	else
		nft add rule inet shellcrash $1 meta nfproto ipv6 return
	fi
	#添加通用路由
	nft add rule inet shellcrash "$1" "$JUMP"
	#处理特殊路由
	[ "$redir_mod" = "混合模式" ] && {
		nft add rule inet shellcrash $1 meta l4proto tcp mark set $((fwmark + 1))
		nft add chain inet shellcrash "$1"_mixtcp { type nat hook $2 priority -100 \; }
		nft add rule inet shellcrash "$1"_mixtcp mark $((fwmark + 1)) meta l4proto tcp redirect to $redir_port
	}
	#nft add rule inet shellcrash local_tproxy log prefix \"pre\" level debug
}
start_nft_dns() { #nftables-dns
	HOST_IP=$(echo $host_ipv4 | sed 's/ /, /g')
	HOST_IP6=$(echo $host_ipv6 | sed 's/ /, /g')
	[ "$1" = 'output' ] && HOST_IP="127.0.0.0/8, $(echo $local_ipv4 | sed 's/ /, /g')"
	[ "$1" = 'prerouting_vm' ] && HOST_IP="$(echo $vm_ipv4 | sed 's/ /, /g')"
	nft add chain inet shellcrash "$1"_dns { type nat hook $2 priority -100 \; }
	#过滤非dns请求
	nft add rule inet shellcrash "$1"_dns udp dport != 53 return
	nft add rule inet shellcrash "$1"_dns tcp dport != 53 return
	#防回环
	nft add rule inet shellcrash "$1"_dns meta mark $routing_mark return
	nft add rule inet shellcrash "$1"_dns meta skgid { 453, 7890 } return
	[ "$firewall_area" = 5 ] && nft add rule inet shellcrash "$1"_dns ip saddr $bypass_host return
	nft add rule inet shellcrash "$1"_dns ip saddr != {$HOST_IP} return                              #屏蔽外部请求
	[ "$1" = 'prerouting' ] && nft add rule inet shellcrash "$1"_dns ip6 saddr != {$HOST_IP6} reject #屏蔽外部请求
	#过滤局域网设备
	[ "$1" = 'prerouting' ] && [ -s "$CRASHDIR"/configs/mac ] && {
		MAC=$(awk '{printf "%s, ",$1}' "$CRASHDIR"/configs/mac)
		if [ "$macfilter_type" = "黑名单" ]; then
			nft add rule inet shellcrash "$1"_dns ether saddr {$MAC} return
		else
			nft add rule inet shellcrash "$1"_dns ether saddr != {$MAC} return
		fi
	}
	nft add rule inet shellcrash "$1"_dns udp dport 53 redirect to ${dns_port}
	nft add rule inet shellcrash "$1"_dns tcp dport 53 redirect to ${dns_port}
}
start_nft_wan() { #nftables公网防火墙
	#获取局域网host地址
	getlanip
	HOST_IP=$(echo $host_ipv4 | sed 's/ /, /g')
	nft add chain inet shellcrash input { type filter hook input priority -100 \; }
	nft add rule inet shellcrash input ip daddr 127.0.0.1 accept
	if [ "$public_support" = "已开启" ]; then
		nft add rule inet shellcrash input tcp dport $db_port accept
	else
		#仅允许非公网设备访问面板
		nft add rule inet shellcrash input tcp dport $db_port ip saddr {$HOST_IP} accept
		nft add rule inet shellcrash input tcp dport $db_port reject
	fi
	if [ "$public_mixport" = "已开启" ]; then
		nft add rule inet shellcrash input tcp dport $mix_port accept
	else
		#仅允许局域网设备访问混合端口
		nft add rule inet shellcrash input tcp dport $mix_port ip saddr {$HOST_IP} accept
		nft add rule inet shellcrash input tcp dport $mix_port reject
	fi
}
start_nftables() { #nftables配置总入口
	#初始化nftables
	nft add table inet shellcrash
	nft flush table inet shellcrash
	#公网访问防火墙
	start_nft_wan
	#启动DNS劫持
	[ "$dns_no" != "已禁用" -a "$dns_redir" != "已开启" -a "$firewall_area" -le 3 ] && {
		[ "$lan_proxy" = true ] && start_nft_dns prerouting prerouting #局域网dns转发
		[ "$local_proxy" = true ] && start_nft_dns output output       #本机dns转发
	}
	#分模式设置流量劫持
	[ "$redir_mod" = "Redir模式" ] && {
		JUMP="meta l4proto tcp redirect to $redir_port" #跳转劫持的具体命令
		[ "$lan_proxy" = true ] && start_nft_route prerouting prerouting nat -100
		[ "$local_proxy" = true ] && start_nft_route output output nat -100
	}
	[ "$redir_mod" = "Tproxy模式" ] && (modprobe nft_tproxy >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q nft_tproxy) && {
		JUMP="meta l4proto {tcp, udp} mark set $fwmark tproxy to :$tproxy_port" #跳转劫持的具体命令
		[ "$lan_proxy" = true ] && start_nft_route prerouting prerouting filter -150
		[ "$local_proxy" = true ] && {
			JUMP="meta l4proto {tcp, udp} mark set $fwmark" #跳转劫持的具体命令
			start_nft_route output output route -150
			nft add chain inet shellcrash mark_out { type filter hook prerouting priority -100 \; }
			nft add rule inet shellcrash mark_out meta mark $fwmark meta l4proto {tcp, udp} tproxy to :$tproxy_port
		}
	}
	[ "$tun_statu" = true ] && {
		[ "$redir_mod" = "Tun模式" ] && JUMP="meta l4proto {tcp, udp} mark set $fwmark" #跳转劫持的具体命令
		[ "$redir_mod" = "混合模式" ] && JUMP="meta l4proto udp mark set $fwmark"         #跳转劫持的具体命令
		[ "$lan_proxy" = true ] && {
			start_nft_route prerouting prerouting filter -150
			#放行流量
			nft list table inet fw4 >/dev/null 2>&1 || nft add table inet fw4
			nft list chain inet fw4 forward >/dev/null 2>&1 || nft add chain inet fw4 forward { type filter hook forward priority filter \; } 2>/dev/null
			nft list chain inet fw4 input >/dev/null 2>&1 || nft add chain inet fw4 input { type filter hook input priority filter \; } 2>/dev/null
			nft list chain inet fw4 forward | grep -q 'oifname "utun" accept' || nft insert rule inet fw4 forward oifname "utun" accept
			nft list chain inet fw4 input | grep -q 'iifname "utun" accept' || nft insert rule inet fw4 input iifname "utun" accept
		}
		[ "$local_proxy" = true ] && start_nft_route output output route -150
	}
	[ "$firewall_area" = 5 ] && {
		[ "$redir_mod" = "T&U旁路转发" ] && JUMP="meta l4proto {tcp, udp} mark set $fwmark" #跳转劫持的具体命令
		[ "$redir_mod" = "TCP旁路转发" ] && JUMP="meta l4proto tcp mark set $fwmark"        #跳转劫持的具体命令
		[ "$lan_proxy" = true ] && start_nft_route prerouting prerouting filter -150
		[ "$local_proxy" = true ] && start_nft_route output output route -150
	}
	[ "$vm_redir" = "已开启" ] && [ -n "$$vm_ipv4" ] && {
		start_nft_dns prerouting_vm prerouting
		JUMP="meta l4proto tcp redirect to $redir_port" #跳转劫持的具体命令
		start_nft_route prerouting_vm prerouting nat -100
	}
	#屏蔽QUIC
	[ "$quic_rj" = '已启用' -a "$lan_proxy" = true ] && {
		[ "$redir_mod" = "Tproxy模式" ] && {
			nft add chain inet shellcrash quic_rj { type filter hook input priority 0 \; }
			[ -n "$CN_IP" ] && nft add rule inet shellcrash quic_rj ip daddr {$CN_IP} return
			[ -n "$CN_IP6" ] && nft add rule inet shellcrash quic_rj ip6 daddr {$CN_IP6} return
			nft add rule inet shellcrash quic_rj udp dport {443, 8443} reject comment 'ShellCrash-QUIC-REJECT'
		}
		[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && {
			nft insert rule inet fw4 forward oifname "utun" udp dport {443, 8443} reject comment 'ShellCrash-QUIC-REJECT'
			[ -n "$CN_IP" ] && nft insert rule inet fw4 forward oifname "utun" ip daddr {$CN_IP} return
			[ -n "$CN_IP6" ] && nft insert rule inet fw4 forward oifname "utun" ip6 daddr {$CN_IP6} return
		}
	}
}
start_firewall() { #路由规则总入口
	getlanip          #获取局域网host地址
	#设置策略路由
	[ "$firewall_area" != 4 ] && {
		local table=100
		[ "$redir_mod" = "Tproxy模式" ] && ip route add local default dev lo table $table 2>/dev/null
		[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && {
			i=1
			while [ -z "$(ip route list | grep utun)" -a "$i" -le 29 ]; do
				sleep 1
				i=$((i + 1))
			done
			if [ -z "$(ip route list | grep utun)" ]; then
				logger "找不到tun模块，放弃启动tun相关防火墙规则！" 31
			else
				ip route add default dev utun table $table && tun_statu=true
			fi
		}
		[ "$firewall_area" = 5 ] && ip route add default via $bypass_host table $table 2>/dev/null
		[ "$redir_mod" != "Redir模式" ] && ip rule add fwmark $fwmark table $table 2>/dev/null
	}
	#添加ipv6路由
	[ "$ipv6_redir" = "已开启" -a "$firewall_area" -le 3 ] && {
		[ "$redir_mod" = "Tproxy模式" ] && ip -6 route add local default dev lo table $((table + 1)) 2>/dev/null
		[ -n "$(ip route list | grep utun)" ] && ip -6 route add default dev utun table $((table + 1)) 2>/dev/null
		[ "$redir_mod" != "Redir模式" ] && ip -6 rule add fwmark $fwmark table $((table + 1)) 2>/dev/null
	}
	#判断代理用途
	[ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && local_proxy=true
	[ "$firewall_area" = 1 -o "$firewall_area" = 3 -o "$firewall_area" = 5 ] && lan_proxy=true
	#防火墙配置
	[ "$firewall_mod" = 'iptables' ] && start_iptables
	[ "$firewall_mod" = 'nftables' ] && start_nftables
	#修复部分虚拟机dns查询失败的问题
	[ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && [ -z "$(grep 'nameserver 127.0.0.1' /etc/resolv.conf 2>/dev/null)" ] && {
		line=$(grep -n 'nameserver' /etc/resolv.conf | awk -F: 'FNR==1{print $1}')
		sed -i "$line i\nameserver 127.0.0.1 #shellcrash-dns-repair" /etc/resolv.conf
	}
	#openwrt使用dnsmasq转发DNS
	if [ "$dns_redir" = "已开启" -a "$firewall_area" -le 3 -a "$dns_no" != "已禁用" ]; then
		uci del dhcp.@dnsmasq[-1].server >/dev/null 2>&1
		uci delete dhcp.@dnsmasq[0].resolvfile 2>/dev/null
		uci add_list dhcp.@dnsmasq[0].server=127.0.0.1#$dns_port >/dev/null 2>&1
		uci set dhcp.@dnsmasq[0].noresolv=1 2>/dev/null
		uci commit dhcp >/dev/null 2>&1
		/etc/init.d/dnsmasq restart >/dev/null 2>&1
	elif [ "$(uci get dhcp.@dnsmasq[0].dns_redirect 2>/dev/null)" = 1 ]; then
		uci del dhcp.@dnsmasq[0].dns_redirect
		uci commit dhcp.@dnsmasq[0]
	fi
}
stop_firewall() { #还原防火墙配置
	#获取局域网host地址
	getlanip
	#重置iptables相关规则
	ckcmd iptables && {
		#dns
		$iptable -t nat -D PREROUTING -p tcp --dport 53 -j shellcrash_dns 2>/dev/null
		$iptable -t nat -D PREROUTING -p udp --dport 53 -j shellcrash_dns 2>/dev/null
		$iptable -t nat -D OUTPUT -p udp --dport 53 -j shellcrash_dns_out 2>/dev/null
		$iptable -t nat -D OUTPUT -p tcp --dport 53 -j shellcrash_dns_out 2>/dev/null
		#redir
		$iptable -t nat -D PREROUTING -p tcp $ports -j shellcrash 2>/dev/null
		$iptable -t nat -D PREROUTING -p tcp -d 198.18.0.0/16 -j shellcrash 2>/dev/null
		$iptable -t nat -D OUTPUT -p tcp $ports -j shellcrash_out 2>/dev/null
		$iptable -t nat -D OUTPUT -p tcp -d 198.18.0.0/16 -j shellcrash_out 2>/dev/null
		#vm_dns
		$iptable -t nat -D PREROUTING -p tcp --dport 53 -j shellcrash_vm_dns 2>/dev/null
		$iptable -t nat -D PREROUTING -p udp --dport 53 -j shellcrash_vm_dns 2>/dev/null
		#vm_redir
		$iptable -t nat -D PREROUTING -p tcp $ports -j shellcrash_vm 2>/dev/null
		$iptable -t nat -D PREROUTING -p tcp -d 198.18.0.0/16 -j shellcrash_vm 2>/dev/null
		#TPROXY&tun
		$iptable -t mangle -D PREROUTING -p tcp $ports -j shellcrash_mark 2>/dev/null
		$iptable -t mangle -D PREROUTING -p udp $ports -j shellcrash_mark 2>/dev/null
		$iptable -t mangle -D PREROUTING -p tcp -d 198.18.0.0/16 -j shellcrash_mark 2>/dev/null
		$iptable -t mangle -D PREROUTING -p udp -d 198.18.0.0/16 -j shellcrash_mark 2>/dev/null
		$iptable -t mangle -D OUTPUT -p tcp $ports -j shellcrash_mark_out 2>/dev/null
		$iptable -t mangle -D OUTPUT -p udp $ports -j shellcrash_mark_out 2>/dev/null
		$iptable -t mangle -D OUTPUT -p tcp -d 198.18.0.0/16 -j shellcrash_mark_out 2>/dev/null
		$iptable -t mangle -D OUTPUT -p udp -d 198.18.0.0/16 -j shellcrash_mark_out 2>/dev/null
		$iptable -t mangle -D PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port 2>/dev/null
		$iptable -t mangle -D PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port 2>/dev/null
		#tun
		$iptable -D FORWARD -o utun -j ACCEPT 2>/dev/null
		#屏蔽QUIC
		[ "$dns_mod" != "fake-ip" -a "$cn_ip_route" = "已开启" ] && set_cn_ip='-m set ! --match-set cn_ip dst'
		$iptable -D INPUT -p udp --dport 443 $set_cn_ip -j REJECT 2>/dev/null
		$iptable -D FORWARD -p udp --dport 443 -o utun $set_cn_ip -j REJECT 2>/dev/null
		#公网访问
		for ip in $host_ipv4 $local_ipv4 $reserve_ipv4; do
			$iptable -D INPUT -p tcp -s $ip --dport $mix_port -j ACCEPT 2>/dev/null
			$iptable -D INPUT -p tcp -s $ip --dport $db_port -j ACCEPT 2>/dev/null
		done
		$iptable -D INPUT -p tcp -d 127.0.0.1 -j ACCEPT 2>/dev/null
		$iptable -D INPUT -p tcp --dport $mix_port -j REJECT 2>/dev/null
		$iptable -D INPUT -p tcp --dport $mix_port -j ACCEPT 2>/dev/null
		$iptable -D INPUT -p tcp --dport $db_port -j REJECT 2>/dev/null
		$iptable -D INPUT -p tcp --dport $db_port -j ACCEPT 2>/dev/null
		#清理shellcrash自建表
		for table in shellcrash_dns shellcrash shellcrash_out shellcrash_dns_out shellcrash_vm shellcrash_vm_dns; do
			$iptable -t nat -F $table 2>/dev/null
			$iptable -t nat -X $table 2>/dev/null
		done
		for table in shellcrash_mark shellcrash_mark_out; do
			$iptable -t mangle -F $table 2>/dev/null
			$iptable -t mangle -X $table 2>/dev/null
		done
	}
	#重置ipv6规则
	ckcmd ip6tables && {
		#dns
		$ip6table -t nat -D PREROUTING -p tcp --dport 53 -j shellcrashv6_dns 2>/dev/null
		$ip6table -t nat -D PREROUTING -p udp --dport 53 -j shellcrashv6_dns 2>/dev/null
		#redir
		$ip6table -t nat -D PREROUTING -p tcp $ports -j shellcrashv6 2>/dev/null
		$ip6table -t nat -D OUTPUT -p tcp $ports -j shellcrashv6_out 2>/dev/null
		$ip6table -D INPUT -p tcp --dport 53 -j REJECT 2>/dev/null
		$ip6table -D INPUT -p udp --dport 53 -j REJECT 2>/dev/null
		#mark
		$ip6table -t mangle -D PREROUTING -p tcp $ports -j shellcrashv6_mark 2>/dev/null
		$ip6table -t mangle -D PREROUTING -p udp $ports -j shellcrashv6_mark 2>/dev/null
		$ip6table -t mangle -D OUTPUT -p tcp $ports -j shellcrashv6_mark_out 2>/dev/null
		$ip6table -t mangle -D OUTPUT -p udp $ports -j shellcrashv6_mark_out 2>/dev/null
		$ip6table -D INPUT -p udp --dport 443 $set_cn_ip -j REJECT 2>/dev/null
		$ip6table -t mangle -D PREROUTING -m mark --mark $fwmark -p tcp -j TPROXY --on-port $tproxy_port 2>/dev/null
		$ip6table -t mangle -D PREROUTING -m mark --mark $fwmark -p udp -j TPROXY --on-port $tproxy_port 2>/dev/null
		#tun
		$ip6table -D FORWARD -o utun -j ACCEPT 2>/dev/null
		#屏蔽QUIC
		[ "$dns_mod" != "fake-ip" -a "$cn_ipv6_route" = "已开启" ] && set_cn_ip6='-m set ! --match-set cn_ip6 dst'
		$ip6table -D INPUT -p udp --dport 443 $set_cn_ip6 -j REJECT 2>/dev/null
		$ip6table -D FORWARD -p udp --dport 443 -o utun $set_cn_ip6 -j REJECT 2>/dev/null
		#公网访问
		$ip6table -D INPUT -p tcp --dport $mix_port -j REJECT 2>/dev/null
		$ip6table -D INPUT -p tcp --dport $mix_port -j ACCEPT 2>/dev/null
		$ip6table -D INPUT -p tcp --dport $db_port -j REJECT 2>/dev/null
		$ip6table -D INPUT -p tcp --dport $db_port -j ACCEPT 2>/dev/null
		#清理shellcrash自建表
		for table in shellcrashv6_dns shellcrashv6 shellcrashv6_out; do
			$ip6table -t nat -F $table 2>/dev/null
			$ip6table -t nat -X $table 2>/dev/null
		done
		for table in shellcrashv6_mark shellcrashv6_mark_out; do
			$ip6table -t mangle -F $table 2>/dev/null
			$ip6table -t mangle -X $table 2>/dev/null
		done
		$ip6table -t mangle -F shellcrashv6_mark 2>/dev/null
		$ip6table -t mangle -X shellcrashv6_mark 2>/dev/null
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
	ip rule del fwmark $fwmark table 100 2>/dev/null
	ip route flush table 100 2>/dev/null
	ip -6 rule del fwmark $fwmark table 101 2>/dev/null
	ip -6 route flush table 101 2>/dev/null
	#重置nftables相关规则
	ckcmd nft && {
		nft flush table inet shellcrash >/dev/null 2>&1
		nft delete table inet shellcrash >/dev/null 2>&1
	}
	#还原防火墙文件
	[ -s /etc/init.d/firewall.bak ] && mv -f /etc/init.d/firewall.bak /etc/init.d/firewall
	#others
	sed -i '/shellcrash-dns-repair/d' /etc/resolv.conf
}
#启动相关
web_save() { #最小化保存面板节点选择
	#使用get_save获取面板节点设置
	get_save http://127.0.0.1:${db_port}/proxies | sed 's/:{/!/g' | awk -F '!' '{for(i=1;i<=NF;i++) print $i}' | grep -aE '"Selector"' | grep -aoE '"name":.*"now":".*",' >"$TMPDIR"/web_proxies
	[ -s "$TMPDIR"/web_proxies ] && while read line; do
		def=$(echo $line | grep -oE '"all".*",' | awk -F "[:\"]" '{print $5}')
		now=$(echo $line | grep -oE '"now".*",' | awk -F "[:\"]" '{print $5}')
		[ "$def" != "$now" ] && {
			name=$(echo $line | grep -oE '"name".*",' | awk -F "[:\"]" '{print $5}')
			echo "${name},${now}" >>"$TMPDIR"/web_save
		}
	done <"$TMPDIR"/web_proxies
	rm -rf "$TMPDIR"/web_proxies
	#获取面板设置
	#[ "$crashcore" != singbox ] && get_save http://127.0.0.1:${db_port}/configs > "$TMPDIR"/web_configs
	#对比文件，如果有变动且不为空则写入磁盘，否则清除缓存
	for file in web_save web_configs; do
		if [ -s "$TMPDIR"/${file} ]; then
			compare "$TMPDIR"/${file} "$CRASHDIR"/configs/${file}
			[ "$?" = 0 ] && rm -rf "$TMPDIR"/${file} || mv -f "$TMPDIR"/${file} "$CRASHDIR"/configs/${file}
		fi
	done
}
web_restore() { #还原面板选择
	#设置循环检测面板端口以判定服务启动是否成功
	test=""
	i=1
	while [ -z "$test" -a "$i" -lt 20 ]; do
		sleep 2
		test=$(get_save http://127.0.0.1:${db_port}/configs | grep -o port)
		i=$((i + 1))
	done
	sleep 1
	[ -n "$test" ] && {
		#发送节点选择数据
		[ -s "$CRASHDIR"/configs/web_save ] && {
			num=$(cat "$CRASHDIR"/configs/web_save | wc -l)
			i=1
			while [ "$i" -le "$num" ]; do
				group_name=$(awk -F ',' 'NR=="'${i}'" {print $1}' "$CRASHDIR"/configs/web_save | sed 's/ /%20/g')
				now_name=$(awk -F ',' 'NR=="'${i}'" {print $2}' "$CRASHDIR"/configs/web_save)
				put_save http://127.0.0.1:${db_port}/proxies/${group_name} "{\"name\":\"${now_name}\"}"
				i=$((i + 1))
			done
		}
		#还原面板设置
		#[ "$crashcore" != singbox ] && [ -s "$CRASHDIR"/configs/web_configs ] && {
		#sleep 5
		#put_save http://127.0.0.1:${db_port}/configs "$(cat "$CRASHDIR"/configs/web_configs)" PATCH
		#}
	}
}
makehtml() { #生成面板跳转文件
	cat >"$BINDIR"/ui/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShellCrash面板提示</title>
</head>
<body>
    <div style="text-align: center; margin-top: 50px;">
        <h1>您还未安装本地面板</h1>
		<h3>请在脚本更新功能中(9-4)安装<br>或者使用在线面板：</h3>
		<h4>请复制当前地址/ui(不包括)前面的内容，填入url位置即可连接</h3>
        <a href="https://metacubexd.pages.dev" style="font-size: 24px;">Meta XD面板(推荐)<br></a>
        <a href="https://yacd.metacubex.one" style="font-size: 24px;">Meta YACD面板(推荐)<br></a>
        <a href="https://yacd.haishan.me" style="font-size: 24px;">Clash YACD面板<br></a>
        <a style="font-size: 21px;"><br>如已安装，请刷新此页面！<br></a>		
    </div>
</body>
</html
EOF
}
catpac() { #生成pac文件
	#获取本机host地址
	[ -n "$host" ] && host_pac=$host
	[ -z "$host_pac" ] && host_pac=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
	[ -z "$host_pac" ] && host_pac=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
	cat >"$TMPDIR"/shellcrash_pac <<EOF
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
	compare "$TMPDIR"/shellcrash_pac "$BINDIR"/ui/pac
	[ "$?" = 0 ] && rm -rf "$TMPDIR"/shellcrash_pac || mv -f "$TMPDIR"/shellcrash_pac "$BINDIR"/ui/pac
}
core_check() {                                                                       #检查及下载内核文件
	[ -n "$(tar --help 2>&1 | grep -o 'no-same-owner')" ] && tar_para='--no-same-owner' #tar命令兼容
	[ -n "$(find --help 2>&1 | grep -o size)" ] && find_para=' -size +2000'             #find命令兼容
	tar_core() {
		mkdir -p "$TMPDIR"/core_tmp
		tar -zxf "$1" ${tar_para} -C "$TMPDIR"/core_tmp/
		for file in $(find "$TMPDIR"/core_tmp $find_para 2>/dev/null); do
			[ -f $file ] && [ -n "$(echo $file | sed 's#.*/##' | grep -iE '(CrashCore|sing|meta|mihomo|clash|pre)')" ] && mv -f $file "$TMPDIR"/"$2"
		done
		rm -rf "$TMPDIR"/core_tmp
	}
	[ -z "$(find "$TMPDIR"/CrashCore $find_para 2>/dev/null)" ] && [ -n "$(find "$BINDIR"/CrashCore $find_para 2>/dev/null)" ] && mv "$BINDIR"/CrashCore "$TMPDIR"/CrashCore
	[ -z "$(find "$TMPDIR"/CrashCore $find_para 2>/dev/null)" ] && [ -n "$(find "$BINDIR"/CrashCore.tar.gz $find_para 2>/dev/null)" ] &&
		tar_core "$BINDIR"/CrashCore.tar.gz CrashCore
	[ -z "$(find "$TMPDIR"/CrashCore $find_para 2>/dev/null)" ] && {
		logger "未找到【$crashcore】核心，正在下载！" 33
		[ -z "$cpucore" ] && . "$CRASHDIR"/webget.sh && getcpucore
		[ -z "$cpucore" ] && logger 找不到设备的CPU信息，请手动指定处理器架构类型！ 31 && exit 1
		get_bin "$TMPDIR"/CrashCore.tar.gz "bin/$crashcore/${target}-linux-${cpucore}.tar.gz"
		#校验内核
		tar_core "$TMPDIR"/CrashCore.tar.gz core_new
		chmod +x "$TMPDIR"/core_new
		if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
			core_v=$("$TMPDIR"/core_new version 2>/dev/null | grep version | awk '{print $3}')
			COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
		else
			core_v=$("$TMPDIR"/core_new -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
			COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
		fi
		if [ -z "$core_v" ]; then
			rm -rf "$TMPDIR"/CrashCore
			logger "核心下载失败，请重新运行或更换安装源！" 31
			exit 1
		else
			mv -f "$TMPDIR"/core_new "$TMPDIR"/CrashCore
			mv -f "$TMPDIR"/CrashCore.tar.gz "$BINDIR"/CrashCore.tar.gz
			setconfig COMMAND "$COMMAND" "$CRASHDIR"/configs/command.env && . "$CRASHDIR"/configs/command.env
			setconfig crashcore $crashcore
			setconfig core_v $core_v
		fi
	}
	[ ! -x "$TMPDIR"/CrashCore ] && chmod +x "$TMPDIR"/CrashCore 2>/dev/null                               #自动授权
	[ "$start_old" != "已开启" -a "$(cat /proc/1/comm)" = "systemd" ] && restorecon -RF $CRASHDIR 2>/dev/null #修复SELinux权限问题
	return 0
}
core_exchange() { #升级为高级内核
	#$1：目标内核  $2：提示语句
	logger "检测到${2}！将改为使用${1}核心启动！" 33
	rm -rf "$TMPDIR"/CrashCore
	rm -rf "$BINDIR"/CrashCore
	rm -rf "$BINDIR"/CrashCore.tar.gz
	crashcore="$1"
	setconfig crashcore "$1"
	echo -----------------------------------------------
}
clash_check() { #clash启动前检查
	#检测vless/hysteria协议
	[ "$crashcore" != "meta" ] && [ -n "$(cat $core_config | grep -oE 'type: vless|type: hysteria')" ] && core_exchange meta 'vless/hy协议'
	#检测是否存在高级版规则或者tun模式
	if [ "$crashcore" = "clash" ]; then
		[ -n "$(cat $core_config | grep -aiE '^script:|proxy-providers|rule-providers|rule-set')" ] ||
			[ "$redir_mod" = "混合模式" ] ||
			[ "$redir_mod" = "Tun模式" ] && core_exchange meta '当前内核不支持的配置'
	fi
	[ "$crashcore" = "clash" ] && [ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && [ -z "$(grep '0:7890' /etc/passwd)" ] &&
		core_exchange meta '当前内核不支持非root用户启用本机代理'
	core_check
	#预下载GeoIP数据库
	[ -n "$(cat "$CRASHDIR"/yamls/*.yaml | grep -oEi 'geoip')" ] && ckgeo Country.mmdb cn_mini.mmdb
	#预下载GeoSite数据库
	[ -n "$(cat "$CRASHDIR"/yamls/*.yaml | grep -oEi 'geosite')" ] && ckgeo GeoSite.dat geosite.dat
	return 0
}
singbox_check() { #singbox启动前检查
	#检测PuerNya专属功能
	[ "$crashcore" != "singboxp" ] && [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oE '"shadowsocksr"|"outbound_providers"')" ] && core_exchange singboxp 'PuerNya内核专属功能'
	core_check
	#预下载geoip-cn.srs数据库
	[ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"rule_set" *: *"geoip-cn"')" ] && ckgeo geoip-cn.srs srs_geoip_cn.srs
	#预下载geosite-cn.srs数据库
	[ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"rule_set" *: *"geosite-cn"')" -o "$dns_mod" = "mix" ] && ckgeo geosite-cn.srs srs_geosite_cn.srs
	#预下载GeoIP数据库
	[ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"geoip":')" ] && ckgeo geoip.db geoip_cn.db
	#预下载GeoSite数据库
	[ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"geosite":')" ] && ckgeo geosite.db geosite_cn.db
	return 0
}
network_check() { #检查是否联网
	for host in 223.5.5.5 114.114.114.114 1.2.4.8 dns.alidns.com doh.pub doh.360.cn; do
		ping -c 3 $host >/dev/null 2>&1 && return 0
		sleep 2
	done
	logger "当前设备无法连接网络，已停止启动！" 33
	exit 1
}
bfstart() { #启动前
	routing_mark=$((fwmark + 2))
	#检测网络连接
	[ ! -f "$TMPDIR"/crash_start_time ] && ckcmd ping && network_check
	[ ! -d "$BINDIR"/ui ] && mkdir -p "$BINDIR"/ui
	[ -z "$crashcore" ] && crashcore=clash
	#执行条件任务
	[ -s "$CRASHDIR"/task/bfstart ] && . "$CRASHDIR"/task/bfstart
	#检查内核配置文件
	if [ ! -f $core_config ]; then
		if [ -n "$Url" -o -n "$Https" ]; then
			logger "未找到配置文件，正在下载！" 33
			get_core_config
		else
			logger "未找到配置文件链接，请先导入配置文件！" 31
			exit 1
		fi
	fi
	#检查dashboard文件
	if [ -f "$CRASHDIR"/ui/CNAME -a ! -f "$BINDIR"/ui/CNAME ]; then
		cp -rf "$CRASHDIR"/ui "$BINDIR"
	fi
	[ ! -s "$BINDIR"/ui/index.html ] && makehtml #如没有面板则创建跳转界面
	catpac                                       #生成pac文件
	#内核及内核配置文件检查
	if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
		singbox_check
		[ -d "$TMPDIR"/jsons ] && rm -rf "$TMPDIR"/jsons/* || mkdir -p "$TMPDIR"/jsons #准备目录
		[ "$disoverride" != "1" ] && modify_json || ln -sf $core_config "$TMPDIR"/jsons/config.json
	else
		clash_check
		[ "$disoverride" != "1" ] && modify_yaml || ln -sf $core_config "$TMPDIR"/config.yaml
	fi
	#检查下载cnip绕过相关文件
	[ "$firewall_mod" = nftables ] || ckcmd ipset && [ "$dns_mod" != "fake-ip" ] && {
		[ "$cn_ip_route" = "已开启" ] && cn_ip_route
		[ "$ipv6_redir" = "已开启" ] && [ "$cn_ipv6_route" = "已开启" ] && cn_ipv6_route
	}
	#添加shellcrash用户
	[ "$firewall_area" = 2 ] || [ "$firewall_area" = 3 ] || [ "$(cat /proc/1/comm)" = "systemd" ] &&
		[ -z "$(id shellcrash 2>/dev/null | grep 'root')" ] && {
		ckcmd userdel && userdel shellcrash 2>/dev/null
		sed -i '/0:7890/d' /etc/passwd
		sed -i '/x:7890/d' /etc/group
		if ckcmd useradd; then
			useradd shellcrash -u 7890
			sed -Ei s/7890:7890/0:7890/g /etc/passwd
		else
			echo "shellcrash:x:0:7890:::" >>/etc/passwd
		fi
	}
	#清理debug日志
	rm -rf "$TMPDIR"/debug.log
	rm -rf "$CRASHDIR"/debug.log
	return 0
}
afstart() { #启动后
	[ -z "$firewall_area" ] && firewall_area=1
	#延迟启动
	[ ! -f "$TMPDIR"/crash_start_time ] && [ -n "$start_delay" ] && [ "$start_delay" -gt 0 ] && {
		logger "ShellCrash将延迟$start_delay秒启动" 31
		sleep $start_delay
	}
	#设置循环检测面板端口以判定服务启动是否成功
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
	if [ -n "$test" -o -n "$(pidof CrashCore)" ]; then
		rm -rf "$TMPDIR"/CrashCore                                           #删除缓存目录内核文件
		start_firewall                                                       #配置防火墙流量劫持
		mark_time                                                            #标记启动时间
		[ -s "$CRASHDIR"/configs/web_save ] && web_restore >/dev/null 2>&1 & #后台还原面板配置
		{
			sleep 5
			logger ShellCrash服务已启动！
		} &                                                           #推送日志
		ckcmd mtd_storage.sh && mtd_storage.sh save >/dev/null 2>&1 & #Padavan保存/etc/storage
		#加载定时任务
		[ -s "$CRASHDIR"/task/cron ] && croncmd "$CRASHDIR"/task/cron
		[ -s "$CRASHDIR"/task/running ] && {
			cronset '运行时每'
			while read line; do
				cronset '2fjdi124dd12s' "$line"
			done <"$CRASHDIR"/task/running
		}
		[ "$start_old" = "已开启" ] && cronset '保守模式守护进程' "* * * * * test -z \"\$(pidof CrashCore)\" && "$CRASHDIR"/start.sh daemon #ShellCrash保守模式守护进程"
		#加载条件任务
		[ -s "$CRASHDIR"/task/afstart ] && { . "$CRASHDIR"/task/afstart; } &
		[ -s "$CRASHDIR"/task/affirewall -a -s /etc/init.d/firewall -a ! -f /etc/init.d/firewall.bak ] && {
			#注入防火墙
			line=$(grep -En "fw.* restart" /etc/init.d/firewall | cut -d ":" -f 1)
			sed -i.bak "${line}a\\. "$CRASHDIR"/task/affirewall" /etc/init.d/firewall
			line=$(grep -En "fw.* start" /etc/init.d/firewall | cut -d ":" -f 1)
			sed -i "${line}a\\. "$CRASHDIR"/task/affirewall" /etc/init.d/firewall
		} &
	else
		$0 stop
		start_error
	fi
}
start_error() { #启动报错
	if [ "$start_old" != "已开启" ] && ckcmd journalctl; then
		journalctl -u shellcrash >$TMPDIR/core_test.log
	else
		${COMMAND} >"$TMPDIR"/core_test.log 2>&1 &
		sleep 2
		kill $! >/dev/null 2>&1
	fi
	error=$(cat $TMPDIR/core_test.log | grep -iEo 'error.*=.*|.*ERROR.*|.*FATAL.*')
	logger "服务启动失败！请查看报错信息！详细信息请查看$TMPDIR/core_test.log" 33
	logger "$error" 31
	exit 1
}
start_old() { #保守模式
	#使用传统后台执行二进制文件的方式执行
	if ckcmd su && [ -n "$(grep 'shellcrash:x:0:7890' /etc/passwd)" ]; then
		su shellcrash -c "$COMMAND >/dev/null 2>&1" &
	else
		ckcmd nohup && local nohup=nohup
		$nohup $COMMAND >/dev/null 2>&1 &
	fi
	afstart &
}
#杂项
update_config() { #更新订阅并重启
	get_core_config &&
		$0 restart
}
hotupdate() { #热更新订阅
	get_core_config
	core_check
	modify_$format &&
		put_save http://127.0.0.1:${db_port}/configs "{\"path\":\""$CRASHDIR"/config.$format\"}"
	rm -rf "$TMPDIR"/CrashCore
}
set_proxy() { #设置环境变量
	if [ "$local_type" = "环境变量" ]; then
		[ -w ~/.bashrc ] && profile=~/.bashrc
		[ -w /etc/profile ] && profile=/etc/profile
		echo 'export all_proxy=http://127.0.0.1:'"$mix_port" >>$profile
		echo 'export ALL_PROXY=$all_proxy' >>$profile
	fi
}
unset_proxy() { #卸载环境变量
	[ -w ~/.bashrc ] && profile=~/.bashrc
	[ -w /etc/profile ] && profile=/etc/profile
	sed -i '/all_proxy/'d $profile
	sed -i '/ALL_PROXY/'d $profile
}

getconfig #读取配置及全局变量

case "$1" in

start)
	[ -n "$(pidof CrashCore)" ] && $0 stop #禁止多实例
	stop_firewall                          #清理路由策略
	#使用不同方式启动服务
	if [ "$firewall_area" = "5" ]; then #主旁转发
		start_firewall
	elif [ "$start_old" = "已开启" ]; then
		bfstart && start_old
	elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
		/etc/init.d/shellcrash start
	elif [ "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ]; then
		bfstart && {
			FragmentPath=$(systemctl show -p FragmentPath shellcrash | sed 's/FragmentPath=//')
			[ -f $FragmentPath ] && setconfig ExecStart "$COMMAND >/dev/null" "$FragmentPath"
			systemctl daemon-reload
			systemctl start shellcrash.service || start_error
		}
	else
		bfstart && start_old
	fi
	if [ "$2" = "infinity" ]; then #增加容器自启方式，请将CMD设置为"$CRASHDIR"/start.sh start infinity
		sleep infinity
	fi
	;;
stop)
	logger ShellCrash服务即将关闭……
	[ -n "$(pidof CrashCore)" ] && web_save #保存面板配置
	#删除守护进程&面板配置自动保存
	cronset '保守模式守护进程'
	cronset '运行时每'
	cronset '流媒体预解析'
	#多种方式结束进程

	if [ "$start_old" != "已开启" -a "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ]; then
		systemctl stop shellcrash.service >/dev/null 2>&1
	elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
		/etc/init.d/shellcrash stop >/dev/null 2>&1
	else
		stop_firewall #清理路由策略
		unset_proxy   #禁用本机代理
	fi
	PID=$(pidof CrashCore) && [ -n "$PID" ] && kill -9 $PID >/dev/null 2>&1
	;;
restart)
	$0 stop
	$0 start
	;;
daemon)
	if [ -f $TMPDIR/crash_start_time ]; then
		$0 start
	else
		sleep 60 && touch $TMPDIR/crash_start_time
	fi
	;;
debug)
	[ -n "$(pidof CrashCore)" ] && $0 stop >/dev/null #禁止多实例
	stop_firewall >/dev/null                          #清理路由策略
	bfstart
	if [ -n "$2" ]; then
		if [ "$crashcore" = singbox -o "$crashcore" = singboxp ]; then
			sed -i "s/\"level\": \"info\"/\"level\": \"$2\"/" "$TMPDIR"/jsons/log.json 2>/dev/null
		else
			sed -i "s/log-level: info/log-level: $2/" "$TMPDIR"/config.yaml
		fi
		[ "$3" = flash ] && dir=$CRASHDIR || dir=$TMPDIR
		$COMMAND >${dir}/debug.log 2>&1 &
		sleep 2
		logger "已运行debug模式!如需停止，请使用重启/停止服务功能！" 33
	else
		$COMMAND >/dev/null 2>&1 &
	fi
	afstart
	;;
init)
	if [ -d "/etc/storage/clash" -o -d "/etc/storage/ShellCrash" ]; then
		i=1
		while [ ! -w /etc/profile -a "$i" -lt 10 ]; do
			sleep 3 && i=$((i + 1))
		done
		[ -w /etc/profile ] && profile=/etc/profile || profile=/etc_ro/profile
		mount -t tmpfs -o remount,rw,size=45M tmpfs /tmp #增加/tmp空间以适配新的内核压缩方式
		sed -i '' $profile                               #将软链接转化为一般文件
	elif [ -d "/jffs" ]; then
		sleep 60
		if [ -w /etc/profile ]; then
			profile=/etc/profile
		else
			profile=$(cat /etc/profile | grep -oE '\-f.*jffs.*profile' | awk '{print $2}')
		fi
	fi
	sed -i "/alias crash/d" $profile
	sed -i "/alias clash/d" $profile
	sed -i "/export CRASHDIR/d" $profile
	echo "alias crash=\"$CRASHDIR/menu.sh\"" >>$profile
	echo "alias clash=\"$CRASHDIR/menu.sh\"" >>$profile
	echo "export CRASHDIR=\"$CRASHDIR\"" >>$profile
	[ -f "$CRASHDIR"/.dis_startup ] && cronset "保守模式守护进程" || $0 start
	;;
webget)
	#设置临时代理
	if [ -n "$(pidof CrashCore)" ]; then
		[ -n "$authentication" ] && auth="$authentication@"
		export all_proxy="http://${auth}127.0.0.1:$mix_port"
		url=$(echo $3 | sed 's#https://.*jsdelivr.net/gh/juewuy/ShellCrash[@|/]#https://raw.githubusercontent.com/juewuy/ShellCrash/#' | sed 's#https://gh.jwsc.eu.org/#https://raw.githubusercontent.com/juewuy/ShellCrash/#')
	else
		url=$(echo $3 | sed 's#https://raw.githubusercontent.com/juewuy/ShellCrash/#https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@#')
	fi
	#参数【$2】代表下载目录，【$3】代表在线地址
	#参数【$4】代表输出显示，【$4】不启用重定向
	#参数【$6】代表验证证书
	if curl --version >/dev/null 2>&1; then
		[ "$4" = "echooff" ] && progress='-s' || progress='-#'
		[ "$5" = "rediroff" ] && redirect='' || redirect='-L'
		[ "$6" = "skipceroff" ] && certificate='' || certificate='-k'
		result=$(curl $agent -w %{http_code} --connect-timeout 3 $progress $redirect $certificate -o "$2" "$url")
		[ "$result" != "200" ] && export all_proxy="" && result=$(curl $agent -w %{http_code} --connect-timeout 5 $progress $redirect $certificate -o "$2" "$3")
	else
		if wget --version >/dev/null 2>&1; then
			[ "$4" = "echooff" ] && progress='-q' || progress='-q --show-progress'
			[ "$5" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
			[ "$6" = "skipceroff" ] && certificate='' || certificate='--no-check-certificate'
			timeout='--timeout=5'
		fi
		[ "$4" = "echoon" ] && progress=''
		[ "$4" = "echooff" ] && progress='-q'
		wget -Y on $agent $progress $redirect $certificate $timeout -O "$2" "$url"
		if [ "$?" != "0" ]; then
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
