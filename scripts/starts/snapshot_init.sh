#!/bin/sh
# Copyright (C) Juewuy

CRASHDIR="$(uci get firewall.ShellCrash.path | sed 's/\/misnap_init.sh//')"
profile=/etc/profile
. "$CRASHDIR"/configs/ShellCrash.cfg

autoSSH(){
	#自动开启SSH
    [ "`uci -c /usr/share/xiaoqiang get xiaoqiang_version.version.CHANNEL`" != 'stable' ] && {
		uci -c /usr/share/xiaoqiang set xiaoqiang_version.version.CHANNEL='stable' 
		uci -c /usr/share/xiaoqiang commit xiaoqiang_version.version
	}
	[ -z "$(pidof dropbear)" -o -z "$(netstat -ntul | grep :22)" ] && {
		sed -i 's/channel=.*/channel="debug"/g' /etc/init.d/dropbear
		/etc/init.d/dropbear restart
		mi_autoSSH_pwd=$(grep 'mi_autoSSH_pwd=' $CRASHDIR/configs/ShellCrash.cfg | awk -F "=" '{print $2}')
		[ -n "$mi_autoSSH_pwd" ] && echo -e "$mi_autoSSH_pwd\n$mi_autoSSH_pwd" | passwd root
	}
	#配置nvram
	[ "$(nvram get ssh_en)" = 0 ] && nvram set ssh_en=1 
	[ "$(nvram get telnet_en)" = 0 ] && nvram set telnet_en=1
	nvram commit &> /dev/null
	#备份还原SSH秘钥
	[ -f $CRASHDIR/configs/dropbear_rsa_host_key ] && ln -sf $CRASHDIR/configs/dropbear_rsa_host_key /etc/dropbear/dropbear_rsa_host_key
	[ -f $CRASHDIR/configs/authorized_keys ] && ln -sf $CRASHDIR/configs/authorized_keys /etc/dropbear/authorized_keys
}
tunfix(){
	ko_dir=$(modinfo ip_tables | grep  -Eo '/lib/modules.*/ip_tables.ko' | sed 's|/ip_tables.ko||' )
	#在/tmp创建并挂载overlay
	mkdir -p /tmp/overlay
	mkdir -p /tmp/overlay/upper
	mkdir -p /tmp/overlay/work
	mount -o noatime,lowerdir=${ko_dir},upperdir=/tmp/overlay/upper,workdir=/tmp/overlay/work -t overlay "overlay_mods_only" ${ko_dir}
	#将tun.ko链接到lib
	ln -sf $CRASHDIR/tools/tun.ko ${ko_dir}/tun.ko || $CRASHDIR/start.sh loggger "小米Tun模块修复失败！"
}
tproxyfix(){
	sed -i 's/sysctl -w net.bridge.bridge-nf-call-ip/#sysctl -w net.bridge.bridge-nf-call-ip/g' /etc/init.d/qca-nss-ecm
	sysctl -w net.bridge.bridge-nf-call-iptables=0
	sysctl -w net.bridge.bridge-nf-call-ip6tables=0
}
auto_clean(){
	#自动清理升级备份文件夹
	rm -rf /data/etc_bak
	#自动清理被写入闪存的系统日志并禁止服务
	/etc/init.d/stat_points stop 2>/dev/null
	/etc/init.d/stat_points disable 2>/dev/null
	sed -i '\#/logrotate#{ /^[[:space:]]*#/!s/^/#ShellCrash自动注释 / }' /etc/crontabs/root
	rm -rf /data/usr/log
}
init(){
	#等待启动完成
	while ! ip a| grep -q lan; do
		sleep 10
	done
	sleep 20
	#初始化环境变量
    [ -z "$my_alias" ] && my_alias=crash
    sed -i "/ShellCrash\/menu.sh/"d "$profile"
    echo "alias ${my_alias}=\"sh $CRASHDIR/menu.sh\"" >>"$profile"
	sed -i "/export CRASHDIR/d" "$profile"
	echo "export CRASHDIR=\"$CRASHDIR\"" >>"$profile"
	autoSSH #软固化功能
	auto_clean #自动清理
	#设置init.d服务
	cp -f $CRASHDIR/shellcrash.procd /etc/init.d/shellcrash
	chmod 755 /etc/init.d/shellcrash
	#启动服务
	if [ ! -f $CRASHDIR/.dis_startup ]; then
		#AX6S/AX6000修复tun功能
		[ -s $CRASHDIR/tools/tun.ko ] && tunfix
		#小米7000/小米万兆修复tproxy
		[ -f /etc/init.d/qca-nss-ecm ] && [ -n "$(grep 'redir_mod=Tproxy' $CRASHDIR/configs/ShellCrash.cfg )" ] && tproxyfix
		#自动覆盖根证书文件
		[ -s $CRASHDIR/tools/ca-certificates.crt ] && cp -f $CRASHDIR/tools/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
		#启动服务
		$CRASHDIR/start.sh start
		/etc/init.d/shellcrash enable
	fi
}

case "$1" in
	tunfix) tunfix ;;
	tproxyfix) tproxyfix ;;
	auto_clean) auto_clean ;;
	init) init ;;
	*)
		if [ -z $(pidof CrashCore) ];then
			init &
		fi
	;;
esac

