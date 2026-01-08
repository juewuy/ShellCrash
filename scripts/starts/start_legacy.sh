
. "$CRASHDIR"/libs/check_cmd.sh

start_legacy(){	
	if ckcmd su && grep -q 'shellcrash:x:0:7890' /etc/passwd;then
		su shellcrash -c "$1 >/dev/null 2>&1 & echo \$! > /tmp/ShellCrash/$2.pid"
	elif ckcmd setsid; then
        setsid $1 >/dev/null 2>&1 &
        echo $! > "/tmp/ShellCrash/$2.pid"
	elif ckcmd nohup; then
		nohup $1 >/dev/null 2>&1 &
		echo $! > "/tmp/ShellCrash/$2.pid"
	else
		$1 >/dev/null 2>&1 &
		echo $! > "/tmp/ShellCrash/$2.pid"
	fi
}
