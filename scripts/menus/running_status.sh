
running_status(){
	VmRSS=$(awk '/^VmRSS:/ {printf "%.2f MB\n", ($2 * 1024) / 1000000}' /proc/$PID/status)
	#获取运行时长
	touch "$TMPDIR"/crash_start_time #用于延迟启动的校验
	start_time=$(cat "$TMPDIR"/crash_start_time)
	if [ -n "$start_time" ]; then
		time=$(($(date +%s) - start_time))
		day=$((time / 86400))
		[ "$day" = "0" ] && day='' || day="$day天"
		time=$(date -u -d @${time} +%H小时%M分%S秒)
	fi
}
