#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
[ -z "$CRASHDIR" ] && CRASHDIR=$(
    cd $(dirname $0)
    pwd
)
. "$CRASHDIR"/libs/get_config.sh
#加载工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/set_cron.sh
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/compare.sh
. "$CRASHDIR"/libs/logger.sh
. "$CRASHDIR"/libs/web_save.sh
#特殊脚本
bfstart(){
	"$CRASHDIR"/starts/bfstart.sh
}
afstart(){
	"$CRASHDIR"/starts/afstart.sh
}
stop_firewall(){
	"$CRASHDIR"/starts/fw_stop.sh
}
#保守模式启动
start_l(){
	bfstart && {
		. "$CRASHDIR"/starts/start_legacy.sh
		start_legacy "$COMMAND" 'shellcrash'	
	} && afstart &
}

case "$1" in

start)
    [ -n "$(pidof CrashCore)" ] && $0 stop #禁止多实例
    stop_firewall                          #清理路由策略
	rm -f "CRASHDIR"/.start_error #移除自启失败标记
    #使用不同方式启动服务
	if [ "$firewall_area" = "5" ]; then #主旁转发
        . "$CRASHDIR"/starts/fw_start.sh
    elif [ "$start_old" = "ON" ]; then
        start_l
    elif [ -f /etc/rc.common ] && grep -q 'procd' /proc/1/comm; then
        /etc/init.d/shellcrash start
    elif [ "$USER" = "root" ] && grep -q 'systemd' /proc/1/comm; then
		FragmentPath=$(systemctl show -p FragmentPath shellcrash | sed 's/FragmentPath=//')
		[ -f $FragmentPath ] && {
			setconfig ExecStart "$COMMAND >/dev/null" "$FragmentPath"
			systemctl daemon-reload
		}
		systemctl start shellcrash.service || . "$CRASHDIR"/starts/start_error.sh
    elif grep -q 's6' /proc/1/comm; then
		bfstart && /command/s6-svc -u /run/service/shellcrash && {
			[ ! -f "$CRASHDIR"/.dis_startup ] && touch /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
			afstart &
		}
    elif rc-status -r >/dev/null 2>&1; then
        rc-service shellcrash stop >/dev/null 2>&1
        rc-service shellcrash start
    else
        start_l
    fi
    ;;
stop)
    logger ShellCrash服务即将关闭……
    [ -n "$(pidof CrashCore)" ] && web_save #保存面板配置
    #删除守护进程&面板配置自动保存
    cronset '保守模式守护进程'
    cronset '运行时每'
    cronset '流媒体预解析'
    #多种方式结束进程
    if [ -f "$TMPDIR/shellcrash.pid" ];then
        kill -TERM "$(cat "$TMPDIR/shellcrash.pid")"
        rm -f "$TMPDIR/shellcrash.pid"
        stop_firewall
    elif [ "$USER" = "root" ] && grep -q 'systemd' /proc/1/comm; then
        systemctl stop shellcrash.service >/dev/null 2>&1
    elif [ -f /etc/rc.common ] && grep -q 'procd' /proc/1/comm; then
        /etc/init.d/shellcrash stop >/dev/null 2>&1
    elif grep -q 's6' /proc/1/comm; then
		/command/s6-svc -d /run/service/shellcrash
		stop_firewall
    elif rc-status -r >/dev/null 2>&1; then
        rc-service shellcrash stop >/dev/null 2>&1
    else
        stop_firewall
    fi
    killall CrashCore 2>/dev/null
    #清理缓存目录
    rm -rf "$TMPDIR"/CrashCore
    ;;
restart)
    $0 stop
    $0 start
    ;;
init)
    . "$CRASHDIR"/starts/general_init.sh
    ;;
daemon)
    if [ -f $TMPDIR/crash_start_time ]; then
        $0 start
    else
        sleep 60 && touch $TMPDIR/crash_start_time
    fi
    ;;
debug)
    [ -n "$(pidof CrashCore)" ] && $0 stop >/dev/null #禁止多实例
    stop_firewall >/dev/null                          #清理路由策略
    bfstart
    if [ -n "$2" ]; then
        if echo "$crashcore" | grep -q 'singbox'; then
            sed -i "s/\"level\": \"info\"/\"level\": \"$2\"/" "$TMPDIR"/jsons/log.json 2>/dev/null
        else
            sed -i "s/log-level: info/log-level: $2/" "$TMPDIR"/config.yaml
        fi
        [ "$3" = flash ] && dir="$CRASHDIR" || dir="$TMPDIR"
        $COMMAND >"$dir"/debug.log 2>&1 &
        sleep 2
        logger "已运行debug模式!如需停止，请使用重启/停止服务功能！" 33
    else
        $COMMAND >/dev/null 2>&1 &
    fi
    afstart
    ;;
*)
    "$1" "$2" "$3" "$4" "$5" "$6" "$7"
    ;;

esac
