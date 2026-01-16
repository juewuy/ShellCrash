
crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}')"
[ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron"
tmpcron="$TMPDIR"/cron_tmp

croncmd() { #定时任务工具
	if [ -n "$(crontab -h 2>&1 | grep '\-l')" ]; then
        crontab "$1"
	elif [ -w "$crondir" ] && [ -n "$USER" ];then
		[ "$1" = "-l" ] && cat "$crondir"/"$USER" 2>/dev/null
		[ -f "$1" ] && cat "$1" >"$crondir"/"$USER"
		killall -HUP crond 2>/dev/null
	else
		echo "找不到可用的crond或者crontab应用！No available crond or crontab application can be found!"
	fi
}
cronset() { #定时任务设置
    # 参数1代表要移除的关键字,参数2代表要添加的任务语句
    croncmd -l >"$tmpcron"
    sed -i "/$1/d" "$tmpcron"
    sed -i '/^$/d' "$tmpcron"
    echo "$2" >>"$tmpcron"
    croncmd "$tmpcron"
    rm -f "$tmpcron"
}
