#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
. "$CRASHDIR"/libs/get_config.sh
#加载工具
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/logger.sh
. "$CRASHDIR"/libs/set_cron.sh
#缺省值
[ -z "$firewall_area" ] && firewall_area=1
#延迟启动
[ ! -f "$TMPDIR"/crash_start_time ] && [ -n "$start_delay" ] && [ "$start_delay" -gt 0 ] && {
	logger "ShellCrash将延迟$start_delay秒启动" 31
	sleep "$start_delay"
}
#设置循环检测面板端口以判定服务启动是否成功
. "$CRASHDIR"/libs/start_wait.sh
if [ -n "$test" -o -n "$(pidof CrashCore)" ]; then
	[ "$start_old" = "ON" ] && [ ! -L "$TMPDIR"/CrashCore ] && rm -f "$TMPDIR"/CrashCore	#删除缓存目录内核文件
	. "$CRASHDIR"/starts/fw_start.sh										#配置防火墙流量劫持
	date +%s >"$TMPDIR"/crash_start_time                                    #标记启动时间
	#TG机器人守护进程
	[ "$bot_tg_service" = ON ] && . "$CRASHDIR"/menus/bot_tg_service.sh && bot_tg_cron
	#后台还原面板配置
	[ -s "$CRASHDIR"/configs/web_save ] && {
		. "$CRASHDIR"/libs/web_restore.sh
		web_restore >/dev/null 2>&1 &
	}
	#推送日志
	{
		sleep 5
		logger ShellCrash服务已启动！
	} &
	ckcmd mtd_storage.sh && mtd_storage.sh save >/dev/null 2>&1 & #Padavan保存/etc/storage
	#加载定时任务
	[ -s "$CRASHDIR"/task/cron ] && croncmd "$CRASHDIR"/task/cron
	[ -s "$CRASHDIR"/task/running ] && {
		cronset '运行时每'
		while read line; do
			cronset '2fjdi124dd12s' "$line"
		done <"$CRASHDIR"/task/running
	}
	[ "$start_old" = "ON" ] && cronset '保守模式守护进程' "* * * * * /bin/sh $CRASHDIR/starts/start_legacy_wd.sh shellcrash #ShellCrash保守模式守护进程"
	#加载条件任务
	[ -s "$CRASHDIR"/task/afstart ] && { . "$CRASHDIR"/task/afstart; } &
	[ -s "$CRASHDIR"/task/affirewall -a -s /etc/init.d/firewall -a ! -f /etc/init.d/firewall.bak ] && {
		#注入防火墙
		line=$(grep -En "fw.* restart" /etc/init.d/firewall | cut -d ":" -f 1)
		sed -i.bak "${line}a\\. "$CRASHDIR"/task/affirewall" /etc/init.d/firewall
		line=$(grep -En "fw.* start" /etc/init.d/firewall | cut -d ":" -f 1)
		sed -i "${line}a\\. $CRASHDIR/task/affirewall" /etc/init.d/firewall
	} &
	exit 0
else
	. "$CRASHDIR"/starts/start_error.sh
	"$CRASHDIR"/start.sh stop
fi
