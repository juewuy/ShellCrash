
crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}'| tr -d ' ')"
[ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron"
[ -z "$USER" ] && USER=$(whoami 2>/dev/null)
tmpcron=/tmp/cron_tmp
touch "$tmpcron"

cronadd() { #定时任务工具
	if crontab -h 2>&1 | grep -q '\-l'; then
        crontab "$1"
	elif [ -f "$crondir/$USER" ];then
		cat "$1" >"$crondir"/"$USER" && cru a REFRESH "0 0 1 1 * /bin/true" 2>/dev/null
	else
		echo "找不到可用的crond或者crontab应用！No available crond or crontab application can be found!"
	fi
}
cronload() { #定时任务工具
	if crontab -h 2>&1 | grep -q '\-l'; then
        crontab -l
	elif [ -f "$crondir/$USER" ];then
		cat "$crondir"/"$USER" 2>/dev/null
	else
		return 1
	fi
}
cronset() { #定时任务设置
    # 参数1代表要移除的关键字,参数2代表要添加的任务语句
    cronload | grep -v '^$' | grep -vF "$1" >"$tmpcron"
    [ -n "$2" ] && echo "$2" >>"$tmpcron"
	cronadd "$tmpcron"
	#华硕/Padavan固件存档在本地,其他则删除
	if [ -d /jffs ] || [ -d /etc/storage/ShellCrash ];then
		mv -f "$tmpcron" "$CRASHDIR"/task/cron
	else
		rm -f "$tmpcron"
	fi
	sleep 1
}
