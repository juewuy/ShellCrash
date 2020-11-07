#! /bin/bash
# Copyright (C) Juewuy

echo='echo -e' && [ -n "$(echo -e|grep e)" ] && echo=echo
[ -z "$1" ] && test=0 || test=$1

echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**                ShellClash                 **"
echo "**                             by  Juewuy    **"
echo "***********************************************"

#检查root权限
if [ "$USER" != "root" ];then
	echo 当前用户:$USER
	$echo "\033[31m请尽量使用root用户执行安装!\033[0m"
	echo -----------------------------------------------
	read -p "仍要安装？可能会产生大量未知错误！(1/0) > " res
	[ "$res" != "1" ] && exit
fi
webget(){
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
		[ $? -eq 0 ] && result="200"
	fi
}
#检查更新
url="https://cdn.jsdelivr.net/gh/juewuy/ShellClash"
if [ "$test" -gt 0 ];then 
	url="https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master"
	[ "$test" -eq 2 ] && url="http://192.168.31.30:8080/clash-for-Miwifi"
	[ "$test" -eq 3 ] && url="http://192.168.123.90:8080/clash-for-Miwifi"
else
	webget /tmp/clashrelease $url@master/bin/release_version echoon rediroff 2>/tmp/clashrelease
	release_new=$(cat /tmp/clashrelease | head -1)
	[ -z "$release_new" ] && release_new=master
	url=$url@$release_new
fi
webget /tmp/clashversion $url/bin/version echooff
[ "$result" = "200" ] && versionsh=$(cat /tmp/clashversion | grep "versionsh" | awk -F "=" '{print $2}')
[ -z "$release_new" ] && release_new=$versionsh
rm -rf /tmp/clashversion
rm -rf /tmp/clashrelease
[ -z "$release_new" ] && echo "无法连接服务器！" && exit

tarurl=$url/bin/clashfm.tar.gz

gettar(){
	webget /tmp/clashfm.tar.gz $tarurl
	[ "$result" != "200" ] && echo "文件下载失败！" && exit 1
	#解压
	echo -----------------------------------------------
	echo 开始解压文件！
	mkdir -p $clashdir > /dev/null
	tar -zxvf '/tmp/clashfm.tar.gz' -C $clashdir/
	[ $? -ne 0 ] && echo "文件解压失败！" && rm -rf /tmp/clashfm.tar.gz && exit 1 
	#初始化文件目录
	[ -f "$clashdir/mark" ] || echo '#标识clash运行状态的文件，不明勿动！' > $clashdir/mark
	#判断系统类型写入不同的启动文件
	if [ -f /etc/rc.common ];then
			#设为init.d方式启动
			mv $clashdir/clashservice /etc/init.d/clash
			chmod  777 /etc/init.d/clash
	else
		[ -w /etc/systemd/system ] && sysdir=/etc/systemd/system
		[ -w /usr/lib/systemd/system ] && sysdir=/usr/lib/systemd/system
		if [ -n "$sysdir" ];then
			#设为systemd方式启动
			mv $clashdir/clash.service $sysdir/clash.service
			sed -i "s%/etc/clash%$clashdir%g" $sysdir/clash.service
			systemctl daemon-reload
		else
			#设为保守模式启动
			sed -i '/start_old=*/'d $clashdir/mark
			echo start_old=已开启 >> $clashdir/mark
		fi
	fi
	#修饰文件及版本号
	shtype=sh && [ -n "$(ls -l /bin/sh|grep -o dash)" ] && shtype=bash 
	sed -i "s%#!/bin/sh%#!/bin/$shtype%g" $clashdir/start.sh
	chmod  777 $clashdir/start.sh
	sed -i '/versionsh_l=*/'d $clashdir/mark
	echo versionsh_l=$release_new >> $clashdir/mark
	#设置环境变量
	[ -w ~/.bashrc ] && profile=~/.bashrc
	[ -w /etc/profile ] && profile=/etc/profile
	sed -i '/alias clash=*/'d $profile
	echo "alias clash=\"$shtype $clashdir/clash.sh\"" >> $profile #设置快捷命令环境变量
	sed -i '/export clashdir=*/'d $profile
	echo "export clashdir=\"$clashdir\"" >> $profile #设置clash路径环境变量
	#删除临时文件
	rm -rf /tmp/clashfm.tar.gz 
	rm -rf $clashdir/clashservice
	rm -rf $clashdir/clash.service
}
#下载及安装
install(){
echo -----------------------------------------------
echo 开始从服务器获取安装文件！
echo -----------------------------------------------
gettar
echo -----------------------------------------------
echo ShellClash 已经安装成功!
echo -----------------------------------------------
$echo "\033[33m输入\033[30;47m clash \033[0;33m命令即可管理！！！\033[0m"
echo -----------------------------------------------
}
setdir(){		
echo -----------------------------------------------
$echo "\033[33m安装ShellClash至少需要预留约10MB的磁盘空间\033[0m"	
$echo " 1 在\033[32m/etc目录\033[0m下安装(适合路由设备)"
$echo " 2 在\033[32m/usr/share目录\033[0m下安装(适合大多数设备)"
$echo " 3 在\033[32m当前用户目录\033[0m下安装(适合非root用户)"
$echo " 4 手动设置安装目录"
$echo " 0 退出安装"
echo -----------------------------------------------
read -p "请输入相应数字 > " num
#设置目录
if [ -z $num ];then
	echo 安装已取消
	exit;
elif [ "$num" = "1" ];then
	dir=/etc
elif [ "$num" = "2" ];then
	dir=/usr/share
elif [ "$num" = "3" ];then
	dir=~/.local/share
	mkdir -p ~/.config/systemd/user
elif [ "$num" = "4" ];then
	echo -----------------------------------------------
	echo '可用路径 剩余空间:'
	df -h | awk '{print $6,$4}'| sed 1d 
	echo '路径是必须带 / 的格式，写入虚拟内存(/tmp,/sys,..)的文件会在重启后消失！！！'
	read -p "请输入自定义路径 > " dir
	if [ -z "$dir" ];then
		$echo "\033[31m路径错误！请重新设置！\033[0m"
		setdir
	fi
else
	echo 安装已取消！！！
	exit;
fi
if [ ! -w $dir ];then
	$echo "\033[31m没有$dir目录写入权限！请重新设置！\033[0m" && sleep 1 && setdir
else
	echo 目标目录磁盘剩余：$(df -h $dir | awk '{print $4}' | sed 1d )
	read -p "确认安装？(1/0) > " res
	[ "$res" = "1" ] && clashdir=$dir/clash || setdir
fi
}

#输出
$echo "最新版本：\033[32m$release_new\033[0m"
echo -----------------------------------------------
$echo "\033[44m如遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
$echo "\033[37m支持各种基于openwrt的路由器设备"
$echo "\033[33m支持Debian、Centos等标准Linux系统\033[0m"

if [ -n "$clashdir" ];then
	echo -----------------------------------------------
	$echo "检测到旧的安装目录\033[36m$clashdir\033[0m，是否覆盖安装？"
	$echo "\033[32m覆盖安装时不会移除配置文件！\033[0m"
	read -p "覆盖安装/卸载旧版本？(1/0) > " res
	if [ "$res" = "1" ];then
		install
	elif [ "$res" = "0" ];then
		rm -rf $clashdir
		echo -----------------------------------------------
		$echo "\033[31m 旧版本文件已卸载！\033[0m"
		setdir
		install
	elif [ "$res" = "9" ];then
		echo 测试模式，变更安装位置
		setdir
		install
	else
		$echo "\033[31m输入错误！已取消安装！\033[0m"
		exit;
	fi
else
	setdir
	install
fi
