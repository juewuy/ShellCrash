#!/bin/sh
# Copyright (C) Juewuy

clashdir="$(uci get firewall.ShellClash.path | sed 's/\/misnap_init.sh//')"
profile=/etc/profile

autoSSH(){
	#自动开启SSH
	[ "$(nvram get ssh_en)" = 0 ] && nvram set ssh_en=1 && nvram commit
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
	#备份还原SSH秘钥
	[ -f $clashdir/dropbear_rsa_host_key ] && ln -sf $clashdir/dropbear_rsa_host_key /etc/dropbear/dropbear_rsa_host_key
	[ -f $clashdir/authorized_keys ] && ln -sf $clashdir/authorized_keys /etc/dropbear/authorized_keys
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
	ln -s $clashdir/tun.ko ${ko_dir}/tun.ko
}
init(){
	#初始化环境变量
	sed -i "/alias clash/d" $profile
	sed -i "/export clashdir/d" $profile
	echo "alias clash=\"$clashdir/clash.sh\"" >>$profile
	echo "export clashdir=\"$clashdir\"" >>$profile
	#软固化功能
	[ "$(grep 'mi_autoSSH=' $clashdir/mark | awk -F "=" '{print $2}')" = "已启用" ] && autoSSH
	#设置init.d服务
	cp -f $clashdir/clashservice /etc/init.d/clash
	chmod 755 /etc/init.d/clash
	#启动服务
	if [ ! -f $clashdir/.dis_startup ]; then
		#AX6S/AX6000修复tun功能
		[ -f $clashdir/tun.ko -a ! -f /lib/modules/4.4.198/tun.ko ] && tunfix
		#启动服务
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

