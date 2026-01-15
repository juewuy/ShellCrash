#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
. "$CRASHDIR"/libs/get_config.sh
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && . "$CRASHDIR"/init.sh >/dev/null 2>&1
[ ! -f "$TMPDIR" ] && mkdir -p "$TMPDIR"

#当上次启动失败时终止自启动
[ -f "CRASHDIR"/.start_error ] && exit 1
#加载工具
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/check_target.sh
. "$CRASHDIR"/libs/logger.sh
. "$CRASHDIR"/libs/web_get_bin.sh
. "$CRASHDIR"/libs/compare.sh
. "$CRASHDIR"/starts/check_geo.sh
. "$CRASHDIR"/starts/check_core.sh
#缺省值
[ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod='Redir模式'
[ -z "$dns_mod" ] && dns_mod='redir_host'
[ -z "$redir_mod" ] && firewall_area='4'
routing_mark=$((fwmark + 2))

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
        <a href="http://board.zash.run.place" style="font-size: 24px;">Zashboard面板(推荐)<br></a>
        <a style="font-size: 21px;"><br>如已安装，请使用Ctrl+F5强制刷新此页面！<br></a>
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


#检测网络连接
[ "$network_check" != "OFF" ] && [ ! -f "$TMPDIR"/crash_start_time ] && ckcmd ping && . "$CRASHDIR"/starts/check_network.sh && check_network
[ ! -d "$BINDIR"/ui ] && mkdir -p "$BINDIR"/ui
[ -z "$crashcore" ] && crashcore=meta
#执行条件任务
[ -s "$CRASHDIR"/task/bfstart ] && . "$CRASHDIR"/task/bfstart
#检查内核配置文件
if [ ! -f "$core_config" ]; then
	if [ -n "$Url" -o -n "$Https" ]; then
		logger "未找到配置文件，正在下载！" 33
		. "$CRASHDIR"/starts/core_config.sh && get_core_config
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
if echo "$crashcore" | grep -q 'singbox'; then
	. "$CRASHDIR"/starts/singbox_check.sh && singbox_check
	[ -d "$TMPDIR"/jsons ] && rm -rf "$TMPDIR"/jsons/* || mkdir -p "$TMPDIR"/jsons #准备目录
	if [ "$disoverride" != "1" ];then
		. "$CRASHDIR"/starts/singbox_modify.sh && modify_json
	else
		ln -sf "$core_config" "$TMPDIR"/jsons/config.json
	fi
else
	. "$CRASHDIR"/starts/clash_check.sh && clash_check
	if [ "$disoverride" != "1" ];then
		. "$CRASHDIR"/starts/clash_modify.sh && modify_yaml
	else
		ln -sf "$core_config" "$TMPDIR"/config.yaml
	fi
fi
#检查下载cnip绕过相关文件
[ "$cn_ip_route" = "ON" ] && [ "$dns_mod" != "fake-ip" ] && {
	[ "$firewall_mod" = nftables ] || ckcmd ipset && {
		. "$CRASHDIR"/starts/check_cnip.sh
		ck_cn_ipv4
		[ "$ipv6_redir" = "ON" ] && ck_cn_ipv6
	}
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
#加载系统内核组件
[ "$redir_mod" = "Tun模式" -o "$redir_mod" = "混合模式" ] && ckcmd modprobe && modprobe tun 2>/dev/null
#清理debug日志
rm -rf /tmp/ShellCrash/debug.log
rm -rf "$CRASHDIR"/debug.log
exit 0

