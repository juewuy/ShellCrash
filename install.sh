#! /bin/bash
# Copyright (C) Juewuy

echo='echo -e' && [ -n "$(echo -e|grep e)" ] && echo=echo
#[ -z "$1" ] && test=0 || test=$1

echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**                ShellClash                 **"
echo "**                             by  Juewuy    **"
echo "***********************************************"
dir_avail(){
	df -h $1 |awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' |grep Ava |awk '{print $2}'
}
setconfig(){
	configpath=$clashdir/mark
	[ -n "$(grep ${1} $configpath)" ] && sed -i "s#${1}=.*#${1}=${2}#g" $configpath || echo "${1}=${2}" >> $configpath
}
[ -f "/etc/storage/started_script.sh" ] && systype=Padavan && initdir='/etc/storage/started_script.sh'
[ -d "/jffs" ] && systype=asusrouter && { 
	[ -f "/jffs/.asusrouter" ] && initdir='/jffs/.asusrouter'
	[ -d "/jffs/scripts" ] && initdir='/jffs/scripts/nat-start' 
	[ -z "$initdir" ] && initdir='/jffs/scripts/nat-start' && mkdir -p '/jffs/scripts'
	}
[ -f "/data/etc/crontabs/root" -a "$(dir_avail /etc)" = 0 ] && systype=mi_snapshot
#检查root权限
if [ "$USER" != "root" -a -z "$systype" ];then
	echo 当前用户:$USER
	$echo "\033[31m请尽量使用root用户（不要直接使用sudo命令！）执行安装!\033[0m"
	echo -----------------------------------------------
	read -p "仍要安装？可能会产生未知错误！(1/0) > " res
	[ "$res" != "1" ] && exit 1
fi

webget(){
	#参数【$1】代表下载目录，【$2】代表在线地址
	#参数【$3】代表输出显示，【$4】不启用重定向
	if curl --version > /dev/null 2>&1;then
		[ "$3" = "echooff" ] && progress='-s' || progress='-#'
		[ -z "$4" ] && redirect='-L' || redirect=''
		result=$(curl -w %{http_code} --connect-timeout 5 $progress $redirect -ko $1 $2)
		[ -n "$(echo $result | grep -e ^2)" ] && result="200"
	else
		if wget --version > /dev/null 2>&1;then
			[ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
			[ "$4" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
			certificate='--no-check-certificate'
			timeout='--timeout=3'
		fi
		[ "$3" = "echoon" ] && progress=''
		[ "$3" = "echooff" ] && progress='-q'
		wget $progress $redirect $certificate $timeout -O $1 $2 
		[ $? -eq 0 ] && result="200"
	fi
}
#检查更新
url_cdn="https://raw.githubusercontents.com/juewuy/ShellClash"
[ -z "$url" ] && url=$url_cdn
echo -----------------------------------------------
$echo "\033[33m请选择想要安装的版本：\033[0m"	
$echo " 1 \033[32mShellclash正式版\033[0m"
$echo " 2 \033[31mShellclash测试版\033[0m"
echo -----------------------------------------------
read -p "请输入相应数字 > " num
if [ -z $num ];then
	echo 安装已取消！ && exit 1;
elif [ "$num" = "1" ];then
	webget /tmp/clashrelease $url_cdn/master/bin/release_version echoon rediroff 2>/tmp/clashrelease
	if [ "$result" = "200" ];then
		release_new=$(cat /tmp/clashrelease | head -1)
		url_dl="$url_cdn/$release_new"
	else
		echo "无法切换版本，尝试安装测试版！"
	fi
fi
[ -z "$url_dl" ] && url_dl=$url
webget /tmp/clashversion "$url_dl/bin/version" echooff
[ "$result" = "200" ] && versionsh=$(cat /tmp/clashversion | grep "versionsh" | awk -F "=" '{print $2}')
[ -z "$release_new" ] && release_new=$versionsh
rm -rf /tmp/clashversion
rm -rf /tmp/clashrelease
tarurl=$url_dl/bin/clashfm.tar.gz

gettar(){
	webget /tmp/clashfm.tar.gz $tarurl
	[ "$result" != "200" ] && echo "文件下载失败,请尝试使用其他安装源！" && exit 1
	$clashdir/start.sh stop 2>/dev/null
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
			cp -f $clashdir/clashservice /etc/init.d/clash
			chmod 755 /etc/init.d/clash
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
			setconfig start_old 已开启
		fi
	fi
	#修饰文件及版本号
	shtype=sh && [ -n "$(ls -l /bin/sh|grep -oE 'dash|show|bash')" ] && shtype=bash 
	sed -i "s|/bin/sh|/bin/$shtype|" $clashdir/start.sh
	chmod 755 $clashdir/start.sh
	setconfig versionsh_l $release_new
	#设置更新地址
	[ -n "$url" ] && setconfig update_url $url
	#设置环境变量	
	[ -w /opt/etc/profile ] && profile=/opt/etc/profile
	[ -w /jffs/configs/profile.add ] && profile=/jffs/configs/profile.add
	[ -w ~/.bashrc ] && profile=~/.bashrc
	[ -w /etc/profile ] && profile=/etc/profile
	if [ -n "$profile" ];then
		sed -i '/alias clash=*/'d $profile
		echo "alias clash=\"$shtype $clashdir/clash.sh\"" >> $profile #设置快捷命令环境变量
		sed -i '/export clashdir=*/'d $profile
		echo "export clashdir=\"$clashdir\"" >> $profile #设置clash路径环境变量
	else
		echo 无法写入环境变量！请检查安装权限！
		exit 1
	fi
	#华硕/Padavan额外设置
	[ -n "$initdir" ] && {
		sed -i '/ShellClash初始化/'d $initdir && touch $initdir && echo "$clashdir/start.sh init #ShellClash初始化脚本" >> $initdir
		setconfig initdir $initdir
		}
	#小米镜像化OpenWrt额外设置
	if [ "$systype" = "mi_snapshot" ];then
		chmod 755 $clashdir/misnap_init.sh
		uci set firewall.ShellClash=include
		uci set firewall.ShellClash.type='script'
		uci set firewall.ShellClash.path='/data/clash/misnap_init.sh'
		uci set firewall.ShellClash.enabled='1'
		uci commit firewall
		setconfig systype $systype
	else
		rm -rf $clashdir/misnap_init.sh
		rm -rf $clashdir/clashservice
	fi
	#删除临时文件
	rm -rf /tmp/clashfm.tar.gz 
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
[ "$profile" = "~/.bashrc" ] && echo "请执行【source ~/.bashrc &> /dev/null】命令以加载环境变量！"
echo -----------------------------------------------
$echo "\033[33m输入\033[30;47m clash \033[0;33m命令即可管理！！！\033[0m"
echo -----------------------------------------------
}
setdir(){
if [ -n "$systype" ];then
	[ "$systype" = "Padavan" ] && dir=/etc/storage
	[ "$systype" = "asusrouter" ] && dir=/jffs
	[ "$systype" = "mi_snapshot" ] && dir=/data
else
	echo -----------------------------------------------
	$echo "\033[33m安装ShellClash至少需要预留约1MB的磁盘空间\033[0m"	
	$echo " 1 在\033[32m/etc目录\033[0m下安装(适合root用户)"
	$echo " 2 在\033[32m/usr/share目录\033[0m下安装(适合Linux设备)"
	$echo " 3 在\033[32m当前用户目录\033[0m下安装(适合非root用户)"
	$echo " 4 手动设置安装目录"
	$echo " 0 退出安装"
	echo -----------------------------------------------
	read -p "请输入相应数字 > " num
	#设置目录
	if [ -z $num ];then
		echo 安装已取消
		exit 1;
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
		echo '路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！！！'
		read -p "请输入自定义路径 > " dir
		if [ -z "$dir" ];then
			$echo "\033[31m路径错误！请重新设置！\033[0m"
			setdir
		fi
	else
		echo 安装已取消！！！
		exit 1;
	fi
fi

if [ ! -w $dir ];then
	$echo "\033[31m没有$dir目录写入权限！请重新设置！\033[0m" && sleep 1 && setdir
else
	$echo "目标目录\033[32m$dir\033[0m空间剩余：$(dir_avail $dir)"
	read -p "确认安装？(1/0) > " res
	[ "$res" = "1" ] && clashdir=$dir/clash || setdir
fi
}

#输出
$echo "最新版本：\033[32m$release_new\033[0m"
echo -----------------------------------------------
$echo "\033[44m如遇问题请加TG群反馈：\033[42;30m t.me/ShellClash \033[0m"
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
		exit 1;
	fi
else
	setdir
	install
fi
