#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_DNS_LOADED" ] && return
__IS_MODULE_DNS_LOADED=1

set_dns_mod() { #DNS模式设置
	[ -z "$hosts_opt" ] && hosts_opt=ON
    [ -z "$dns_protect" ] && dns_protect=ON
	[ -z "$ecs_subnet" ] && ecs_subnet=OFF || ecs_subnet=ON
    echo "-----------------------------------------------"
    echo -e "当前DNS运行模式为：\033[47;30m $dns_mod \033[0m"
    echo -e "\033[33m切换模式后需要手动重启服务以生效！\033[0m"
    echo "-----------------------------------------------"
	echo -e " 1 MIX模式：  \033[32mCN域名realip其他fake-ip分流\033[0m"
	echo -e " 2 Route模式：\033[32mCN域名realip其他dns2proxy分流\033[0m"
    echo -e " 3 Redir模式：\033[33m不安全,需搭配第三方DNS服务使用\033[0m"
	echo "-----------------------------------------------"
    echo -e " 4 DNS防泄漏：  \033[36m$dns_protect\033[0m	———启用时少量网站可能连接卡顿"
    echo -e " 5 Hosts优化：  \033[36m$hosts_opt\033[0m	———调用本机hosts并劫持NTP服务"
	echo -e " 6 ECS优化：    \033[36m$ecs_subnet\033[0m	———解决CDN下载浪费流量等问题"
    echo -e " 7 DNS劫持端口：\033[36m$dns_redir_port\033[0m	———用于兼容第三方DNS服务"
    [ "$dns_mod" = "mix" ] &&
    echo -e " 8 管理MIX模式\033[33mFake-ip过滤列表\033[0m"
    echo -e " 9 修改\033[36mDNS服务器\033[0m"
	echo "-----------------------------------------------"
    echo " 0 返回上级菜单"
    read -p "请输入对应数字 > " num
    case "$num" in
    0) ;;
    1)
        if echo "$crashcore" | grep -q 'singbox' || [ "$crashcore" = meta ]; then
            dns_mod=mix
            setconfig dns_mod $dns_mod
            echo "-----------------------------------------------"
            echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
        else
            echo -e "\033[31m当前内核不支持的功能！！！\033[0m"
            sleep 1
        fi
		set_dns_mod
    ;;
    2)
        if echo "$crashcore" | grep -q 'singbox' || [ "$crashcore" = meta ]; then
            dns_mod=route
            setconfig dns_mod $dns_mod
            echo "-----------------------------------------------"
            echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
        else
            echo -e "\033[31m当前内核不支持的功能！！！\033[0m"
            sleep 1
        fi
		set_dns_mod
    ;;
    3)
        dns_mod=redir_host
        setconfig dns_mod $dns_mod
        echo "-----------------------------------------------"
        echo -e "\033[36m已设为 $dns_mod 模式！！\033[0m"
		set_dns_mod
    ;;
    4)
        [ "$dns_protect" = "ON" ] && dns_protect=OFF || dns_protect=ON
        setconfig dns_protect $dns_protect
        set_dns_mod
	;;
    5)
		[ "$hosts_opt" = "ON" ] && hosts_opt=OFF || hosts_opt=ON
        setconfig hosts_opt $hosts_opt
        set_dns_mod
	;;
    6)
		[ "$ecs_subnet" = "ON" ] && ecs_subnet=OFF || ecs_subnet=ON
		setconfig ecs_subnet "$ecs_subnet"
		set_dns_mod
	;;
    7)
        echo "-----------------------------------------------"
        echo -e "\033[31m仅限搭配第三方DNS服务(AdGuard、SmartDNS……)使用！\033[0m"
		echo -e "\033[33m设置为第三方DNS服务的监听端口即可修改防火墙劫持！\n建议在第三方DNS服务中将上游DNS指向【localhost:$dns_port】\033[0m"
		echo "-----------------------------------------------"
		read -p "请输入第三方DNS服务的监听端口(0重置端口) > " num
		if [ "$num" = 0 ];then
			dns_redir_port="$dns_port"
			setconfig dns_redir_port
		elif [ "$num" -lt 65535 -a "$num" -ge 1 ];then
			if [ -n "$(netstat -ntul | grep -E ":$num[[:space:]]")" ];then
				dns_redir_port="$num"
				setconfig dns_redir_port "$dns_redir_port"
			else
				echo -e "\033[33m此端口未检测到已运行的DNS服务！\033[0m"
			fi
		else
			errornum
		fi
        sleep 1
        set_dns_mod
	;;
    8)
        echo "-----------------------------------------------"
        fake_ip_filter
        set_dns_mod
	;;
    9)
        set_dns_adv
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
    echo "-----------------------------------------------"
    if [ -s ${CRASHDIR}/configs/fake_ip_filter ]; then
        echo -e "\033[33m已添加Fake-ip过滤地址：\033[0m"
        cat ${CRASHDIR}/configs/fake_ip_filter | awk '{print NR" "$1}'
    else
        echo -e "\033[33m你还未添加Fake-ip过滤地址\033[0m"
    fi
    echo "-----------------------------------------------"
    echo -e "\033[32m输入数字直接移除对应地址，输入地址直接添加！\033[0m"
    read -p "请输入数字或地址 > " input
    case "$input" in
    0) ;;
    '') ;;
    *)
        if [ $input -ge 1 ] 2>/dev/null; then
            sed -i "${input}d" ${CRASHDIR}/configs/fake_ip_filter 2>/dev/null
            echo -e "\033[32m移除成功！\033[0m"
        else
            echo -e "你输入的地址是：\033[32m$input\033[0m"
            read -p "确认添加？(1/0) > " res
            [ "$res" = 1 ] && echo $input >>${CRASHDIR}/configs/fake_ip_filter
        fi
        sleep 1
        fake_ip_filter
    ;;
    esac
}
set_dns_adv() { #DNS详细设置
    echo "-----------------------------------------------"
    echo -e "当前基础DNS：\033[32m$dns_nameserver\033[0m"
    echo -e "PROXY-DNS：\033[36m$dns_fallback\033[0m"
    echo -e "解析DNS：\033[33m$dns_resolver\033[0m"
    echo -e "多个DNS地址请用\033[30;47m“|”\033[0m或者\033[30;47m“, ”\033[0m分隔输入"
    echo -e "\033[33m必须拥有本地根证书文件才能使用dot/doh类型的加密dns\033[0m"
    echo -e "\033[31m注意singbox内核只有首个dns会被加载！\033[0m"
    echo "-----------------------------------------------"
    echo -e " 1 修改\033[32m基础DNS\033[0m"
    echo -e " 2 修改\033[36mPROXY-DNS\033[0m(该DNS查询会经过节点)"
    echo -e " 3 修改\033[33m解析DNS\033[0m(必须是IP,用于解析其他DNS)"
    echo -e " 4 一键配置\033[32m加密DNS\033[0m"
    echo -e " 9 \033[33m重置\033[0m默认DNS配置"
    echo -e " 0 返回上级菜单"
    echo "-----------------------------------------------"
    read -p "请输入对应数字 > " num
    case "$num" in
    0) ;;
    1)
        read -p "请输入新的DNS > " dns_nameserver
        dns_nameserver=$(echo $dns_nameserver | sed 's#|#\,\ #g')
        if [ -n "$dns_nameserver" ]; then
            setconfig dns_nameserver "'$dns_nameserver'"
            echo -e "\033[32m设置成功！！！\033[0m"
        fi
        sleep 1
        set_dns_adv
	;;
    2)
        read -p "请输入新的DNS > " dns_fallback
        dns_fallback=$(echo $dns_fallback | sed 's/|/\,\ /g')
        if [ -n "$dns_fallback" ]; then
            setconfig dns_fallback "'$dns_fallback'"
            echo -e "\033[32m设置成功！！！\033[0m"
        fi
        sleep 1
        set_dns_adv
	;;
    3)
        read -p "请输入新的DNS > " text
        if echo "$text" | grep -qE '://.*::'; then
            echo -e "\033[31m此选项暂不支持ipv6加密DNS！！！\033[0m"
        elif [ -n "$text" ]; then
            dns_resolver=$(echo $text | sed 's/|/\,\ /g')
            setconfig dns_resolver "'$dns_resolver'"
            echo -e "\033[32m设置成功！！！\033[0m"
        fi
        sleep 1
        set_dns_adv
	;;
    4)
        echo "-----------------------------------------------"
        openssldir="$(openssl version -d 2>&1 | awk -F '"' '{print $2}')"
        if [ -s "$openssldir/certs/ca-certificates.crt" ] || [ -s "/etc/ssl/certs/ca-certificates.crt" ] ||
            echo "$crashcore" | grep -qE 'meta|singbox'; then
            dns_nameserver='https://dns.alidns.com/dns-query, https://doh.pub/dns-query'
            dns_fallback='https://cloudflare-dns.com/dns-query, https://dns.google/dns-query, https://doh.opendns.com/dns-query'
            dns_resolver='https://223.5.5.5/dns-query, 2400:3200::1'
            setconfig dns_nameserver "'$dns_nameserver'"
            setconfig dns_fallback "'$dns_fallback'"
            setconfig dns_resolver "'$dns_resolver'"
            echo -e "\033[32m已设置加密DNS，如出现DNS解析问题，请尝试重置DNS配置！\033[0m"
        else
            echo -e "\033[31m找不到根证书文件，无法启用加密DNS，Linux系统请自行搜索安装OpenSSL的方式！\033[0m"
        fi
        sleep 1
        set_dns_adv
	;;
    9)
        setconfig dns_nameserver
        setconfig dns_fallback
        setconfig dns_resolver
		. "$CRASHDIR"/libs/get_config.sh
        echo -e "\033[33mDNS配置已重置！！！\033[0m"
        sleep 1
        set_dns_adv
	;;
    *)
        errornum
        sleep 1
	;;
    esac
}
