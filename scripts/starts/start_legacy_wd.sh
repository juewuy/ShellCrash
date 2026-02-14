
[ -z "$CRASHDIR" ] && CRASHDIR=$(cd "$(dirname "$0")"/.. && pwd)
PIDFILE="/tmp/ShellCrash/$1.pid"
LOCKDIR="/tmp/ShellCrash/start_$1.lock"

[ -f "$CRASHDIR"/.start_error ] && [ ! -f /tmp/ShellCrash/crash_start_time ] && exit 1 #当启动失败后禁止开机自启动
mkdir "$LOCKDIR" 2>/dev/null || exit 1

if [ -f "$PIDFILE" ]; then
	PID="$(cat "$PIDFILE")"
	if [ -n "$PID" ] && [ "$PID" -eq "$PID" ] 2>/dev/null; then
		if kill -0 "$PID" 2>/dev/null || [ -d "/proc/$PID" ]; then
			rm -d "$LOCKDIR" 2>/dev/null
			return 0
		fi
	else
		rm -f "$PIDFILE"
	fi
fi

#如果没有进程则拉起
if [ "$1" = "shellcrash" ]; then
	"$CRASHDIR"/start.sh start
else
	[ -f "$CRASHDIR/starts/start_legacy.sh" ] && . "$CRASHDIR/starts/start_legacy.sh"
	killall bot_tg.sh 2>/dev/null
	start_legacy "$CRASHDIR/menus/bot_tg.sh" "$1"
fi

rm -d "$LOCKDIR" 2>/dev/null
