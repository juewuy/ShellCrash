
if [ "$start_old" != "ON" ] && ckcmd journalctl; then
	journalctl -u shellcrash >"$TMPDIR"/core_test.log
else
	PID=$(pidof CrashCore) && [ -n "$PID" ] && kill -9 "$PID" >/dev/null 2>&1
	${COMMAND} >"$TMPDIR"/core_test.log 2>&1 &
	sleep 2
	kill $! >/dev/null 2>&1
fi
touch "$CRASHDIR"/.start_error #标记启动失败，防止自启
error=$(cat "$TMPDIR"/core_test.log | grep -iEo 'error.*=.*|.*ERROR.*|.*FATAL.*')
logger "服务启动失败！请查看报错信息！详细信息请查看$TMPDIR/core_test.log" 33
logger "$error" 31
