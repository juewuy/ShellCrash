
[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
PIDFILE="/tmp/ShellCrash/$1.pid"

if [ -f "$PIDFILE" ]; then
	PID="$(cat "$PIDFILE")"
	if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
		return 0
	else
		if [ "$1" = shellcrash ];then
			"$CRASHDIR"/start.sh start
		else
			. "$CRASHDIR"/starts/start_legacy.sh
			start_legacy "$CRASHDIR/menus/bot_tg.sh" "$1"
		fi
	fi
fi
