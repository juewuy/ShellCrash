#! /bin/bash
# Copyright (C) Juewuy


ddns_menu(){
	echo -----------------------------------------------
	echo -e "\033[30;46m欢迎使用DDNS！\033[0m"
	load_ddns
}
add_ddns() {
	cat >>"$ddns_dir" <<EOF
	
config service '$service'
	option enabled '1'
	option force_unit 'hours'
	option lookup_host '$domain'
	option service_name '$service_name'
	option domain '$domain'
	option username '$username'
	option use_https '0'
	option use_ipv6 '$use_ipv6'
	option password '$password'
	option ip_source 'web'
	option check_unit 'minutes'
	option check_interval '$check_interval'
	option force_interval '$force_interval'
	option interface 'wan'
	option bind_network 'wan'
EOF
	/usr/lib/ddns/dynamic_dns_updater.sh -S "$service" start >/dev/null 2>&1 &
	sleep 3
	echo 服务已经添加！
}
set_ddns() {
	echo -----------------------------------------------
	read -p "请输入你的域名 > " str
	[ -z "$str" ] && domain="$domain" || domain="$str"
	echo -----------------------------------------------
	read -p "请输入用户名或邮箱 > " str
	[ -z "$str" ] && username="$username" || username="$str"
	echo -----------------------------------------------
	read -p "请输入密码或令牌秘钥 > " str
	[ -z "$str" ] && password="$password" || password="$str"
	echo -----------------------------------------------
	read -p "请输入检测更新间隔(单位:分钟;默认为10) > " check_interval
	[ -z "$check_interval" ] || [ "$check_interval" -lt 1 -o "$check_interval" -gt 1440 ] && check_interval=10
	echo -----------------------------------------------
	read -p "请输入强制更新间隔(单位:小时;默认为24) > " force_interval
	[ -z "$force_interval" ] || [ "$force_interval" -lt 1 -o "$force_interval" -gt 240 ] && force_interval=24
	echo -----------------------------------------------
	echo -e "请核对如下信息："
	echo -e "服务商：		\033[32m$service\033[0m"
	echo -e "域名：			\033[32m$domain\033[0m"
	echo -e "用户名：		\033[32m$username\033[0m"
	echo -e "检测间隔：		\033[32m$check_interval\033[0m"
	echo -----------------------------------------------
	read -p "确认添加？(1/0) > " res
	[ "$res" = 1 ] && add_ddns || set_ddns
}
set_ddns_service() {
	services_dir=/etc/ddns/"$serv"
	[ -s "$services_dir" ] || services_dir=/usr/share/ddns/list
	echo -----------------------------------------------
	echo -e "\033[32m请选择服务提供商\033[0m"
	cat "$services_dir" | grep -v '^#' | awk '{print " "NR" " $1}'
	nr=$(cat "$services_dir" | grep -v '^#' | wc -l)
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		i=
	elif [ "$num" -gt 0 -a "$num" -lt $nr ]; then
		service_name=$(cat "$services_dir" | grep -v '^#' | awk '{print $1}' | sed -n "$num"p | sed 's/"//g')
		service=$(echo $service_name | sed 's/\./_/g')
		set_ddns
	else
		echo "输入错误，请重新输入！"
		sleep 1
		set_ddns_service
	fi
}
set_ddns_type() {
	echo -----------------------------------------------
	echo -e "\033[32m请选择网络模式\033[0m"
	echo -e " 1 \033[36mIPV4\033[0m"
	echo -e " 2 \033[36mIPV6\033[0m"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		i=
	elif [ "$num" = 1 ]; then
		use_ipv6=0
		serv=services
		set_ddns_service
	elif [ "$num" = 2 ]; then
		use_ipv6=1
		serv=services_ipv6
		set_ddns_service
	else
		echo "输入错误，请重新输入！"
		sleep 1
		set_ddns_type
	fi
}
rev_ddns_service() {
	enabled=$(uci get ddns."$service".enabled)
	[ "$enabled" = 1 ] && enabled_b="停用" || enabled_b="启用"
	echo -----------------------------------------------
	echo -e " 1 \033[32m立即更新\033[0m"
	echo -e " 2 编辑当前服务\033[0m"
	echo -e " 3 $enabled_b当前服务"
	echo -e " 4 移除当前服务"
	echo -e " 5 查看运行日志"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" -o "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then
		/usr/lib/ddns/dynamic_dns_updater.sh -S $service start >/dev/null 2>&1 &
		sleep 3
	elif [ "$num" = 2 ]; then
		domain=$(uci get ddns."$service".domain 2>/dev/null)
		username=$(uci get ddns."$service".username 2>/dev/null)
		password=$(uci get ddns."$service".password 2>/dev/null)
		service_name=$(uci get ddns."$service".service_name 2>/dev/null)
		uci delete ddns."$service"
		set_ddns
	elif [ "$num" = 3 ]; then
		[ "$enabled" = 1 ] && uci set ddns."$service".enabled='0' || uci set ddns."$service".enabled='1' && sleep 3
		uci commit ddns."$service"
	elif [ "$num" = 4 ]; then
		uci delete ddns."$service"
		uci commit ddns."$service"
	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		cat /var/log/ddns/"$service".log 2>/dev/null
		sleep 1
	fi
}
load_ddns() {
	ddns_dir=/etc/config/ddns
	tmp_dir="$TMPDIR"/ddns
	[ ! -f "$ddns_dir" ] && {
		echo -e "\033[31m本脚本依赖OpenWrt内置的DDNS服务,当前设备无法运行,已退出！\033[0m"
		sleep 1
		return 1
	}
	nr=0
	cat "$ddns_dir" | grep 'config service' | awk '{print $3}' | sed "s/'//g" | sed 's/"//g' >"$tmp_dir"
	echo -----------------------------------------------
	echo -e "列表      域名       启用     IP地址"
	echo -----------------------------------------------
	[ -s "$tmp_dir" ] && for service in $(cat "$tmp_dir"); do
		#echo $service >>$tmp_dir
		nr=$((nr + 1))
		enabled=$(uci get ddns."$service".enabled 2>/dev/null)
		domain=$(uci get ddns."$service".domain 2>/dev/null)
		local_ip=$(sed '1!G;h;$!d' /var/log/ddns/$service.log 2>/dev/null | grep -E 'Registered IP' | tail -1 | awk -F "'" '{print $2}' | tr -d "'\"")
		echo -e " $nr   $domain  $enabled   $local_ip"
	done
	echo -e " $((nr + 1))   添加DDNS服务"
	echo -e " 0   退出"
	echo -----------------------------------------------
	read -p "请输入对应序号 > " num
	if [ -z "$num" -o "$num" = 0 ]; then
		i=
	elif [ "$num" -gt $nr ]; then
		set_ddns_type
		load_ddns
	elif [ "$num" -gt 0 -a "$num" -le $nr ]; then
		service=$(cat $tmp_dir | sed -n "$num"p)
		rev_ddns_service
		load_ddns
	else
		echo "请输入正确数字！" && load_ddns
	fi
	rm -rf "$tmp_dir"
}


