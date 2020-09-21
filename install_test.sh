#! /bin/bash
# Copyright (C) Juewuy

echo='echo -e' && [ -n "$(ls -l /bin/sh|grep -o dash)" ] && echo=echo
test=1

echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**                ShellClash                 **"
echo "**                             by  Juewuy    **"
echo "***********************************************"

url="https://cdn.jsdelivr.net/gh/juewuy/ShellClash"
if [ $test -ge 1 ];then 
	url="--resolve raw.githubusercontent.com:443:199.232.68.133 https://raw.githubusercontent.com/juewuy/ShellClash/master"
	[ $test -ge 2 ] && url="http://192.168.31.30:8080/clash-for-Miwifi"
else
	release_new=$(curl -kfsSL --resolve api.github.com:443:140.82.113.5 "https://api.github.com/repos/juewuy/ShellClash/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')	#检查版本
fi
[ -z "$release_new" ] && release_new=$(curl -kfsSL $url/bin/version | grep "versionsh" | awk -F "=" '{print $2}')
[ -z "$release_new" ] && echo "无法连接服务器！" && exit
tarurl=$url@$release_new/bin/clashfm.tar.gz
[ $test -ge 1 ] && tarurl=$url/bin/clashfm.tar.gz
gettar(){
	result=$(curl -w %{http_code} -kLo /tmp/clashfm.tar.gz $tarurl)
	[ "$result" != "200" ] && echo "文件下载失败！" && exit 1
	#解压
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo 开始解压文件！
	mkdir -p $clashdir > /dev/null
	tar -zxvf '/tmp/clashfm.tar.gz' -C $clashdir/
	[ $? -ne 0 ] && echo "文件解压失败！" && exit 1 
	#初始化文件目录
	[ -f "$clashdir/mark" ] || echo '#标识clash运行状态的文件，不明勿动！' > $clashdir/mark
	#判断系统类型写入不同的启动文件
	if [ -f /etc/rc.common ];then
			#设为init.d方式启动
			mv $clashdir/clashservice /etc/init.d/clash
			chmod  777 /etc/init.d/clash
	else
		[ -d /etc/systemd/system ] && sysdir=/etc/systemd/system
		[ -d /usr/lib/systemd/system/ ] && sysdir=/usr/lib/systemd/system/ 
		if [ -n "$sysdir" ];then
			#设为systemd方式启动
			mv $clashdir/clash.service $sysdir/clash.service
			sed -i "s%/etc/clash%$clashdir%g" $sysdir/clash.service
			systemctl daemon-reload
			rm -rf /etc/init.d/clash
		else
			#设为保守模式启动
			sed -i '/start_old=*/'d $clashdir/mark
			sed -i "1i\start_old=已开启" $clashdir/mark
		fi
	fi
	#修饰文件及版本号
	shtype=sh && [ -n "$(ls -l /bin/sh|grep -o dash)" ] && shtype=bash 
	sed -i "s%#!/bin/sh%#!/bin/$shtype%g" $clashdir/start.sh
	chmod  777 $clashdir/start.sh
	sed -i '/versionsh_l=*/'d $clashdir/mark
	sed -i "1i\versionsh_l=$release_new" $clashdir/mark
	#设置环境变量
	sed -i '/alias clash=*/'d /etc/profile
	echo "alias clash=\"$shtype $clashdir/clash.sh\"" >> /etc/profile #设置快捷命令环境变量
	sed -i '/export clashdir=*/'d /etc/profile
	echo "export clashdir=\"$clashdir\"" >> /etc/profile #设置clash路径环境变量
	#删除临时文件
	rm -rf /tmp/clashfm.tar.gz 
	rm -rf $clashdir/clashservice
	rm -rf $clashdir/clash.service
}
#输出
$echo "最新版本：\033[32m$release_new\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$echo "\033[44m如遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
$echo "\033[37m支持各种基于openwrt的路由器设备"
$echo "\033[33m支持Debian、Centos等标准Linux系统\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$echo "\033[32m 1 在默认目录(/etc)安装"
$echo "\033[33m 2 手动设置安装目录"
$echo "\033[0m 0 退出安装"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
read -p "请输入相应数字 > " num
#设置目录
if [ -z $num ];then
	echo 安装已取消
	exit;
elif [ "$num" = "1" ];then
	dir=/etc
elif [ "$num" = "2" ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo '可用路径 剩余空间:'
	df -h | awk '{print $6,$2}'| sed 1d 
	echo '路径是必须带 / 的格式，写入虚拟内存(/tmp,/sys,..)的文件会在重启后消失！！！'
	read -p "请输入自定义路径 > " dir
	if [ -z $dir ];then
		echo 路径错误！已取消安装！
		exit;
	fi
else
	echo 安装已取消
	exit;
fi
clashdir=$dir/clash
#输出
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo 开始从服务器获取安装文件！
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#下载及安装
gettar
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo ShellClash 已经安装成功!
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$echo "\033[33m输入\033[30;47m clash \033[0;33m命令即可管理！！！\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

