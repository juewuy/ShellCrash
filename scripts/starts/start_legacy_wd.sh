
[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
PIDFILE="/tmp/ShellCrash/$1.pid"

if [ -f "$PIDFILE" ]; then
	PID="$(cat "$PIDFILE")"
	if [ -n "$PID" ] && [ -d "/proc/$PID" ]; then
		return 0
	fi
fi
#如果没有进程则拉起
if [ "$1" = shellcrash ];then
	"$CRASHDIR"/start.sh start
else
	. "$CRASHDIR"/starts/start_legacy.sh
	start_legacy "$CRASHDIR/menus/bot_tg.sh" "$1"
fi
		