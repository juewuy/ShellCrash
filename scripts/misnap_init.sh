#!/bin/sh
# Copyright (C) Juewuy

clashdir=/data/clash
profile=/etc/profile

#h初始化环境变量
if [ `type -t clash` != "alias" ];then
	echo "alias clash=\"$clashdir/clash.sh\"" >> $profile 
fi
if [ -z $clashdir ];then
	echo "export clashdir=\"$clashdir\"" >> $profile 
fi
#设置init.d服务并启动clash服务
ln -sf $clashdir/clashservice /etc/init.d/clash
chmod 755 /etc/init.d/clash

if [ ! -f $clashdir/.dis_startup ];then
	log_file=`uci get system.@system[0].log_file`
	while [ "$i" -lt 10 ];do
		sleep 3
		[ -n "$(grep 'init complete' $log_file)" ] && i=10 || i=$((i+1))
	done
	/etc/init.d/clash start
	/etc/init.d/clash enable
fi
