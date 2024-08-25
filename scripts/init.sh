#!/bin/sh
# Copyright (C) Juewuy

version=1.9.1beta15

setdir(){
	dir_avail(){
		df $2 $1 |awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' |grep -E 'Ava|可用' |awk '{print $2}'
	}
	set_usb_dir(){
		echo -e "请选择安装目录"
		du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
		read -p "请输入相应数字 > " num
		dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
		if [ -z "$dir" ];then
			echo -e "\033[31m输入错误！请重新设置！\033[0m"
			set_usb_dir
		fi
	}
	set_cust_dir(){
		echo -----------------------------------------------
		echo '可用路径 剩余空间:'
		df -h | awk '{print $6,$4}'| sed 1d 
		echo '路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！！！'
		read -p "请输入自定义路径 > " dir
		if [ "$(dir_avail $dir)" = 0 ];then
			echo "\033[31m路径错误！请重新设置！\033[0m"
			set_cust_dir
		fi
	}
echo -----------------------------------------------
if [ -n "$systype" ];then
	[ "$systype" = "Padavan" ] && dir=/etc/storage
	[ "$systype" = "mi_snapshot" ] && {
		echo -e "\033[33m检测到当前设备为小米官方系统，请选择安装位置\033[0m"	
		[ "$(dir_avail /data)" -gt 256 ] && echo " 1 安装到 /data 目录(推荐，支持软固化功能)"
		[ "$(dir_avail /userdisk)" -gt 256 ] && echo " 2 安装到 /userdisk 目录(推荐，支持软固化功能)"
		echo " 3 安装自定义目录(不推荐，不明勿用！)"
		echo " 0 退出安装"
		echo -----------------------------------------------
		read -p "请输入相应数字 > " num
		case "$num" in 
		1)
			dir=/data
			;;
		2)
			dir=/userdisk
			;;
		3)
			set_cust_dir
			;;
		*)
			exit 1 ;;
		esac
	}
	[ "$systype" = "asusrouter" ] && {
		echo -e "\033[33m检测到当前设备为华硕固件，请选择安装方式\033[0m"	
		echo -e " 1 基于USB设备安装(通用，须插入\033[31m任意\033[0mUSB设备)"
		echo -e " 2 基于自启脚本安装(仅支持梅林及部分官改固件)"
		echo -e " 0 退出安装"
		echo -----------------------------------------------
		read -p "请输入相应数字 > " num
		case "$num" in 
		1)
			read -p "将脚本安装到USB存储/系统闪存？(1/0) > " res
			[ "$res" = "1" ] && set_usb_dir || dir=/jffs
			usb_status=1
			;;
		2)
			echo -e "如无法正常开机启动，请重新使用USB方式安装！"
			sleep 2
			dir=/jffs ;;
		*)
			exit 1 ;;
		esac
	}
	[ "$systype" = "ng_snapshot" ] && dir=/tmp/mnt
else
	echo -e "\033[33m安装ShellCrash至少需要预留约1MB的磁盘空间\033[0m"	
	echo -e " 1 在\033[32m/etc目录\033[0m下安装(适合root用户)"
	echo -e " 2 在\033[32m/usr/share目录\033[0m下安装(适合Linux系统)"
	echo -e " 3 在\033[32m当前用户目录\033[0m下安装(适合非root用户)"
	echo -e " 4 在\033[32m外置存储\033[0m中安装"
	echo -e " 5 手动设置安装目录"
	echo -e " 0 退出安装"
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
		set_usb_dir
	elif [ "$num" = "5" ];then
		echo -----------------------------------------------
		echo '可用路径 剩余空间:'
		df -h | awk '{print $6,$4}'| sed 1d 
		echo '路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！！！'
		read -p "请输入自定义路径 > " dir
		if [ -z "$dir" ];then
			echo -e "\033[31m路径错误！请重新设置！\033[0m"
			setdir
		fi
	else
		echo 安装已取消！！！
		exit 1;
	fi
fi

if [ ! -w $dir ];then
	echo -e "\033[31m没有$dir目录写入权限！请重新设置！\033[0m" && sleep 1 && setdir
else
	echo -e "目标目录\033[32m$dir\033[0m空间剩余：$(dir_avail $dir -h)"
	read -p "确认安装？(1/0) > " res
	[ "$res" = "1" ] && CRASHDIR=$dir/ShellCrash || setdir
fi
}
setconfig(){ 
	#参数1代表变量名，参数2代表变量值,参数3即文件路径
	[ -z "$3" ] && configpath=${CRASHDIR}/configs/ShellCrash.cfg || configpath="${3}"
	[ -n "$(grep "${1}=" "$configpath")" ] && sed -i "s#${1}=.*#${1}=${2}#g" $configpath || echo "${1}=${2}" >> $configpath
}
#特殊固件识别及标记
[ -f "/etc/storage/started_script.sh" ] && {
	systype=Padavan #老毛子固件
	initdir='/etc/storage/started_script.sh'
	}
[ -d "/jffs" ] && {
	systype=asusrouter #华硕固件
	[ -f "/jffs/.asusrouter" ] && initdir='/jffs/.asusrouter'
	[ -d "/jffs/scripts" ] && initdir='/jffs/scripts/nat-start' 
	#华硕启用jffs
	nvram set jffs2_scripts="1"
	nvram commit
	}
[ -f "/data/etc/crontabs/root" ] && systype=mi_snapshot #小米设备
[ -w "/var/mnt/cfg/firewall" ] && systype=ng_snapshot #NETGEAR设备

#检查环境变量
[ -z "$CRASHDIR" -a -n "$clashdir" ] && CRASHDIR=$clashdir
[ -z "$CRASHDIR" -a -d /tmp/SC_tmp ] && setdir
#移动文件
mkdir -p ${CRASHDIR}
mv -f /tmp/SC_tmp/* ${CRASHDIR} 2>/dev/null

#初始化
mkdir -p ${CRASHDIR}/configs
[ -f "${CRASHDIR}/configs/ShellCrash.cfg" ] || echo '#ShellCrash配置文件，不明勿动！' > ${CRASHDIR}/configs/ShellCrash.cfg
#判断系统类型写入不同的启动文件
if [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ];then
		#设为init.d方式启动
		cp -f ${CRASHDIR}/shellcrash.procd /etc/init.d/shellcrash
		chmod 755 /etc/init.d/shellcrash
else
	[ -w /usr/lib/systemd/system ] && sysdir=/usr/lib/systemd/system
	[ -w /etc/systemd/system ] && sysdir=/etc/systemd/system
	if [ -n "$sysdir" -a "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ];then
		#创建shellcrash用户
		userdel shellcrash 2>/dev/null
		sed -i '/0:7890/d' /etc/passwd
		sed -i '/x:7890/d' /etc/group
		if useradd -h >/dev/null 2>&1; then
			useradd shellcrash -u 7890 2>/dev/null
			sed -Ei s/7890:7890/0:7890/g /etc/passwd
		else
			echo "shellcrash:x:0:7890::/home/shellcrash:/bin/sh" >> /etc/passwd
		fi
		#配置systemd
		mv -f ${CRASHDIR}/shellcrash.service $sysdir/shellcrash.service 2>/dev/null
		sed -i "s%/etc/ShellCrash%$CRASHDIR%g" $sysdir/shellcrash.service
		rm -rf $sysdir/clash.service #旧版文件清理
		systemctl daemon-reload
	else
		#设为保守模式启动
		systemctl disable shellcrash 2>/dev/null
		setconfig start_old 已开启
	fi
fi
#修饰文件及版本号
command -v bash >/dev/null 2>&1 && shtype=bash 
[ -x /bin/ash ] && shtype=ash 
for file in start.sh task.sh menu.sh;do
	sed -i "s|/bin/sh|/bin/$shtype|" ${CRASHDIR}/${file}
	chmod 755 ${CRASHDIR}/${file}
done
setconfig versionsh_l $version
#生成用于执行systemd及procd服务的变量文件
[ ! -f ${CRASHDIR}/configs/command.env ] && {
	TMPDIR='/tmp/ShellCrash'
	BINDIR=${CRASHDIR}
	touch ${CRASHDIR}/configs/command.env
	setconfig TMPDIR ${TMPDIR} ${CRASHDIR}/configs/command.env
	setconfig BINDIR ${BINDIR} ${CRASHDIR}/configs/command.env	
}
if [ -n "$(grep 'crashcore=singbox' ${CRASHDIR}/configs/ShellCrash.cfg)" ];then
	COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
else
	COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
fi
setconfig COMMAND "$COMMAND" ${CRASHDIR}/configs/command.env
#设置防火墙执行模式
[ -z "$(grep firewall_mod $CRASHDIR/configs/ShellClash.cfg 2>/dev/null)" ] && {
	iptables -j REDIRECT -h >/dev/null 2>&1 && firewall_mod=iptables
	nft add table inet shellcrash 2>/dev/null && firewall_mod=nftables
	setconfig firewall_mod $firewall_mod
}
#设置更新地址
[ -n "$url" ] && setconfig update_url $url
#设置环境变量
[ -w /opt/etc/profile ] && profile=/opt/etc/profile
[ -w /jffs/configs/profile.add ] && profile=/jffs/configs/profile.add
[ -w ~/.bashrc ] && profile=~/.bashrc
[ -w /etc/profile ] && profile=/etc/profile
if [ -n "$profile" ];then
	sed -i '/alias crash=*/'d $profile
	echo "alias crash=\"$shtype $CRASHDIR/menu.sh\"" >> $profile #设置快捷命令环境变量
	sed -i '/alias clash=*/'d $profile
	echo "alias clash=\"$shtype $CRASHDIR/menu.sh\"" >> $profile #设置快捷命令环境变量
	sed -i '/export CRASHDIR=*/'d $profile
	echo "export CRASHDIR=\"$CRASHDIR\"" >> $profile #设置路径环境变量
	source $profile >/dev/null 2>&1 || echo 运行错误！请使用bash而不是dash运行安装命令！！！
	#适配zsh环境变量
	[ -n "$(cat /etc/shells 2>/dev/null|grep -oE 'zsh')" ] && [ -z "$(cat ~/.zshrc 2>/dev/null|grep CRASHDIR)" ] && { 
		sed -i '/alias crash=*/'d ~/.zshrc 2>/dev/null
		echo "alias crash=\"$shtype $CRASHDIR/menu.sh\"" >> ~/.zshrc
  		# 兼容 clash 命令
		sed -i '/alias clash=*/'d ~/.zshrc 2>/dev/null
		echo "alias clash=\"$shtype $CRASHDIR/menu.sh\"" >> ~/.zshrc
		sed -i '/export CRASHDIR=*/'d ~/.zshrc 2>/dev/null
		echo "export CRASHDIR=\"$CRASHDIR\"" >> ~/.zshrc
		source ~/.zshrc >/dev/null 2>&1
	}
else
	echo -e "\033[33m无法写入环境变量！请检查安装权限！\033[0m"
	exit 1
fi
#在允许的情况下创建/usr/bin/crash文件
touch /usr/bin/crash 2>/dev/null && {
	cat > /usr/bin/crash <<EOF
#/bin/$shtype
$CRASHDIR/menu.sh \$1 \$2 \$3 \$4 \$5
EOF
	chmod +x /usr/bin/crash
}
#梅林/Padavan额外设置
[ -n "$initdir" ] && {
	sed -i '/ShellCrash初始化/'d $initdir
	touch $initdir
	echo "$CRASHDIR/start.sh init #ShellCrash初始化脚本" >> $initdir
	chmod a+rx $initdir 2>/dev/null
	setconfig initdir $initdir
}
#Padavan额外设置
[ -f "/etc/storage/started_script.sh" ] && mount -t tmpfs -o remount,rw,size=45M tmpfs /tmp #增加/tmp空间以适配新的内核压缩方式
#镜像化OpenWrt(snapshot)额外设置
if [ "$systype" = "mi_snapshot" -o "$systype" = "ng_snapshot" ];then
	chmod 755 ${CRASHDIR}/misnap_init.sh
	uci delete firewall.ShellClash 2>/dev/null
	uci delete firewall.ShellCrash 2>/dev/null
	uci set firewall.ShellCrash=include
	uci set firewall.ShellCrash.type='script'
	uci set firewall.ShellCrash.path="$CRASHDIR/misnap_init.sh"
	uci set firewall.ShellCrash.enabled='1'
	uci commit firewall
	setconfig systype $systype
else
	rm -rf ${CRASHDIR}/misnap_init.sh
fi
#华硕USB启动额外设置
[ "$usb_status" = "1" ]	&& {
	echo "$CRASHDIR/start.sh init #ShellCrash初始化脚本" > ${CRASHDIR}/asus_usb_mount.sh
	nvram set script_usbmount="$CRASHDIR/asus_usb_mount.sh"
	nvram commit
}
#删除临时文件
rm -rf /tmp/*rash*gz
rm -rf /tmp/SC_tmp
#转换&清理旧版本文件
mkdir -p ${CRASHDIR}/yamls
mkdir -p ${CRASHDIR}/jsons
mkdir -p ${CRASHDIR}/tools
mkdir -p ${CRASHDIR}/task
for file in config.yaml.bak user.yaml proxies.yaml proxy-groups.yaml rules.yaml others.yaml ;do
	mv -f ${CRASHDIR}/$file ${CRASHDIR}/yamls/$file 2>/dev/null
done
	[ ! -L ${CRASHDIR}/config.yaml ] && mv -f ${CRASHDIR}/config.yaml ${CRASHDIR}/yamls/config.yaml 2>/dev/null
for file in fake_ip_filter mac web_save servers.list fake_ip_filter.list fallback_filter.list singbox_providers.list clash_providers.list;do
	mv -f ${CRASHDIR}/$file ${CRASHDIR}/configs/$file 2>/dev/null
done
	#配置文件改名
	mv -f ${CRASHDIR}/mark ${CRASHDIR}/configs/ShellCrash.cfg 2>/dev/null
	mv -f ${CRASHDIR}/configs/ShellClash.cfg ${CRASHDIR}/configs/ShellCrash.cfg 2>/dev/null
	#数据库改名
	mv -f ${CRASHDIR}/geosite.dat ${CRASHDIR}/GeoSite.dat 2>/dev/null
	#内核改名
	mv -f ${CRASHDIR}/clash ${CRASHDIR}/CrashCore 2>/dev/null
	#内核压缩 
	[ -f  ${CRASHDIR}/CrashCore ] && tar -zcf ${CRASHDIR}/CrashCore.tar.gz -C ${CRASHDIR} CrashCore
for file in dropbear_rsa_host_key authorized_keys tun.ko ShellDDNS.sh;do
	mv -f ${CRASHDIR}/$file ${CRASHDIR}/tools/$file 2>/dev/null
done
for file in cron task.sh task.list;do
	mv -f ${CRASHDIR}/$file ${CRASHDIR}/task/$file 2>/dev/null
done
#旧版文件清理
userdel shellclash >/dev/null 2>&1
sed -i '/shellclash/d' /etc/passwd
sed -i '/shellclash/d' /etc/group
rm -rf /etc/init.d/clash
[ "$systype" = "mi_snapshot" -a "$CRASHDIR" != '/data/clash' ] && rm -rf /data/clash
for file in CrashCore clash.sh getdate.sh shellcrash.rc core.new clashservice log shellcrash.service mark? mark.bak;do
	rm -rf ${CRASHDIR}/$file
done
#旧版变量改名
sed -i "s/clashcore/crashcore/g" $configpath
sed -i "s/clash_v/core_v/g" $configpath
sed -i "s/clash.meta/meta/g" $configpath
sed -i "s/ShellClash/ShellCrash/g" $configpath
sed -i "s/cpucore=armv8/cpucore=arm64/g" $configpath
sed -i "s/redir_mod=Nft基础/redir_mod=Redir模式/g" $configpath
sed -i "s/redir_mod=Nft混合/redir_mod=Tproxy模式/g" $configpath
sed -i "s/redir_mod=Tproxy混合/redir_mod=Tproxy模式/g" $configpath
sed -i "s/redir_mod=纯净模式/firewall_area=4/g" $configpath

echo -e "\033[32m脚本初始化完成,请输入\033[30;47m crash \033[0;33m命令开始使用！\033[0m"
