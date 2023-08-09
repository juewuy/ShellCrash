#!/bin/sh
# Copyright (C) Juewuy

clashdir="$(uci get firewall.ShellClash.path | sed 's/\/misnap_init.sh//')"
profile=/etc/profile

autoSSH(){
	#自动开启SSH
    [ "`uci -c /usr/share/xiaoqiang get xiaoqiang_version.version.CHANNEL`" != 'stable' ] && {
		uci -c /usr/share/xiaoqiang set xiaoqiang_version.version.CHANNEL='stable' 
		uci -c /usr/share/xiaoqiang commit xiaoqiang_version.version
	}
	[ -z "$(pidof dropbear)" -o -z "$(netstat -ntul | grep :22)" ] && {
		sed -i 's/channel=.*/channel="debug"/g' /etc/init.d/dropbear
		/etc/init.d/dropbear restart
		mi_autoSSH_pwd=$(grep 'mi_autoSSH_pwd=' $clashdir/mark | awk -F "=" '{print $2}')
		[ -n "$mi_autoSSH_pwd" ] && echo -e "$mi_autoSSH_pwd\n$mi_autoSSH_pwd" | passwd root
	}
	#配置nvram
	[ "$(nvram get ssh_en)" = 0 ] && nvram set ssh_en=1 
	[ "$(nvram get telnet_en)" = 0 ] && nvram set telnet_en=1
	nvram commit &> /dev/null
	#备份还原SSH秘钥
	[ -f $clashdir/configs/dropbear_rsa_host_key ] && ln -sf $clashdir/configs/dropbear_rsa_host_key /etc/dropbear/dropbear_rsa_host_key
	[ -f $clashdir/configs/authorized_keys ] && ln -sf $clashdir/configs/authorized_keys /etc/dropbear/authorized_keys
	#自动清理升级备份文件夹
	rm -rf /data/etc_bak
}
tunfix(){
	ko_dir=$(modinfo ip_tables | grep  -Eo '/lib/modules.*/ip_tables.ko' | sed 's|/ip_tables.ko||' )
	#在/tmp创建并挂载overlay
	mkdir -p /tmp/overlay
	mkdir -p /tmp/overlay/upper
	mkdir -p /tmp/overlay/work
	mount -o noatime,lowerdir=${ko_dir},upperdir=/tmp/overlay/upper,workdir=/tmp/overlay/work -t overlay "overlay_mods_only" ${ko_dir}
	#将tun.ko链接到lib
	ln -sf $clashdir/tools/tun.ko ${ko_dir}/tun.ko
}
tproxyfix(){
	sed -i 's/sysctl -w net.bridge.bridge-nf-call-ip/#sysctl -w net.bridge.bridge-nf-call-ip/g' /etc/init.d/qca-nss-ecm
	sysctl -w net.bridge.bridge-nf-call-iptables=0
	sysctl -w net.bridge.bridge-nf-call-ip6tables=0
}
init(){
	#等待启动完成
	log_file=$(uci get system.@system[0].log_file)
	local i=0
	while [ "$i" -lt 20 ]; do
		sleep 3
		[ -n "$(grep 'init complete' $log_file)" ] && i=20 || i=$((i + 1))
	done
	#初始化环境变量
	sed -i "/alias clash/d" $profile
	sed -i "/export clashdir/d" $profile
	echo "alias clash=\"$clashdir/clash.sh\"" >>$profile
	echo "export clashdir=\"$clashdir\"" >>$profile
	#软固化功能
	autoSSH
	#设置init.d服务
	cp -f $clashdir/clashservice /etc/init.d/clash
	chmod 755 /etc/init.d/clash
	#启动服务
	if [ ! -f $clashdir/.dis_startup ]; then
		#AX6S/AX6000修复tun功能
		[ -f $clashdir/configs/tun.ko ] && tunfix
		#小米7000/小米万兆修复tproxy
		[ -f /etc/init.d/qca-nss-ecm ] && [ -n "$(grep 'redir_mod=Tproxy' $clashdir/configs/ShellClash.cfg )" ] && tproxyfix
		#启动服务
		/etc/init.d/clash start
		/etc/init.d/clash enable
	fi
}

case "$1" in
	tunfix) tunfix ;;
	tproxyfix) tproxyfix ;;
	init) init ;;
	*)
		if [ -z $(pidof clash) ];then
			init &
		fi
	;;
esac

