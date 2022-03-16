#!/bin/sh
# Copyright (C) Juewuy

clashdir=/data/clash
profile=/etc/profile

log(){
	dir=$clashdir/ui/log
	echo `date`ssh状态获取 >> $dir
	nvram get telnet_en >> $dir
	nvram get ssh_en >> $dir
	nvram get uart_en >> $dir
	uci -c /usr/share/xiaoqiang get xiaoqiang_version.version.CHANNEL >> $dir
	grep 'channel=.*' /etc/init.d/dropbear >> $dir
	/etc/init.d/dropbear enabled
	echo dropbear自启状态：$? >> $dir
}

#还原SSH秘钥
ln -sf $clashdir/dropbear_rsa_host_key /etc/dropbear/dropbear_rsa_host_key

#h初始化环境变量
echo "alias clash=\"$clashdir/clash.sh\"" >> $profile 
echo "export clashdir=\"$clashdir\"" >> $profile 

#设置init.d服务并启动clash服务
ln -sf $clashdir/clashservice /etc/init.d/clash
chmod 755 /etc/init.d/clash

log

[ -f $clashdir/.dis_startup ] || {
	log_file=`uci get system.@system[0].log_file`
	while [ "$i" -lt 10 ];do
		sleep 3
		[ -n "$(grep 'init complete' $log_file)" ] && i=10 || i=$((i+1))
	done
	/etc/init.d/clash start
	/etc/init.d/clash enable
}

sleep 10
log
