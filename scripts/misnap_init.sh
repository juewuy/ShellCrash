#!/bin/sh
# Copyright (C) Juewuy

clashdir=/data/clash
profile=/etc/profile

tunfix(){
	#在/tmp创建并挂载overlay
	[ -e /tmp/overlay ] || mkdir /tmp/overlay
	[ -e /tmp/overlay/upper ] || mkdir /tmp/overlay/upper
	[ -e /tmp/overlay/work ] || mkdir /tmp/overlay/work
	mount --bind /tmp/overlay /overlay
	. /lib/functions/preinit.sh
	fopivot /overlay/upper /overlay/work /rom 1
	#Fixup miwifi misc, and DO NOT use /overlay/upper/etc instead, /etc/uci-defaults/* may be already removed
	mount -o noatime,move /rom/data /data 2>&-
	mount -o noatime,move /rom/etc /etc 2>&-
	mount -o noatime,move /rom/userdisk /userdisk 2>&-
	#将tun.ko链接到lib
	ln -s $clashdir/tun.ko /overlay/upper/lib/modules/4.4.198/tun.ko
}
init(){
	#初始化环境变量
	sed -i "/alias clash/d" $profile
	sed -i "/export clashdir/d" $profile
	echo "alias clash=\"$clashdir/clash.sh\"" >>$profile
	echo "export clashdir=\"$clashdir\"" >>$profile
	#设置init.d服务
	cp -f $clashdir/clashservice /etc/init.d/clash
	chmod 755 /etc/init.d/clash
	#启动服务
	if [ ! -f $clashdir/.dis_startup ]; then
		log_file=$(uci get system.@system[0].log_file)
		while [ "$i" -lt 10 ]; do
			sleep 5
			[ -n "$(grep 'init complete' $log_file)" ] && i=10 || i=$((i + 1))
		done
		#AX6S/AX6000修复tun功能
		[ -f $clashdir/tun.ko -a ! -f /lib/modules/4.4.198/tun.ko ] && tunfix
		#
		/etc/init.d/clash start
		/etc/init.d/clash enable
	fi
}

case "$1" in
	tunfix) tunfix ;;
	init) init ;;
	*)
		if [ -z $(pidof clash) ];then
			init
		else
			sleep 10
			$clashdir/start.sh restart
		fi
	;;
esac

