
. "$CRASHDIR"/libs/check_cmd.sh

start_legacy(){	
	ckcmd nohup && _nohup=nohup
	if ckcmd su && grep -q 'shellcrash:x:0:7890' /etc/passwd;then
		su shellcrash -c "$_nohup $1 >/dev/null 2>&1 & echo \$! > /tmp/ShellCrash/$2.pid"
	elif ckcmd setsid; then
        $_nohup setsid $1 >/dev/null 2>&1 &
        echo $! > "/tmp/ShellCrash/$2.pid"
	else
		$_nohup $1 >/dev/null 2>&1 &
		echo $! > "/tmp/ShellCrash/$2.pid"
	fi
}
