#!/bin/sh
# Copyright (C) Juewuy

clashdir=/data/clash
profile=/etc/profile

#检查clash运行状态
if [ -z $(pidof clash) ]; then
	#初始化环境变量
	sed -i "/alias clash/d" $profile
	sed -i "/export clashdir/d" $profile
	echo "alias clash=\"$clashdir/clash.sh\"" >>$profile
	echo "export clashdir=\"$clashdir\"" >>$profile
	#设置init.d服务并启动clash服务
	cp -f $clashdir/clashservice /etc/init.d/clash
	chmod 755 /etc/init.d/clash

	if [ ! -f $clashdir/.dis_startup ]; then
		log_file=$(uci get system.@system[0].log_file)
		while [ "$i" -lt 10 ]; do
			sleep 5
			[ -n "$(grep 'init complete' $log_file)" ] && i=10 || i=$((i + 1))
		done
		/etc/init.d/clash start
		/etc/init.d/clash enable
	fi
else
	sleep 10
	$clashdir/start.sh restart
fi
