#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
profile=/etc/profile
. "$CRASHDIR"/libs/set_profile.sh
. "$CRASHDIR"/libs/set_cron.sh
. "$CRASHDIR"/configs/ShellCrash.cfg
#padavan和华硕环境变量目录设置
if [ -d "/etc/storage/clash" -o -d "/etc/storage/ShellCrash" ]; then
	i=1
	while [ ! -w /etc/profile -a "$i" -lt 10 ]; do
		sleep 3 && i=$((i + 1))
	done
	[ -w "$profile" ] || profile=/etc_ro/profile
	[ "$zip_type" = 'upx' ] || mount -t tmpfs -o remount,rw,size=45M tmpfs /tmp #增加/tmp空间以适配新的内核压缩方式
	sed -i '' "$profile"                        #将软链接转化为一般文件
elif [ -d "/jffs" ]; then
	sleep 60
	[ -w "$profile" ] || profile=$(cat /etc/profile | grep -oE '\-f.*jffs.*profile' | awk '{print $2}')
fi
#写入环境变量
set_profile "$profile"
#启动进程或删除守护进程
if [ -f "$CRASHDIR"/.dis_startup ];then
	cronset "保守模式守护进程"
else
	"$CRASHDIR"/start.sh start
fi
