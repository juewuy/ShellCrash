check_autostart(){
	if [ "$start_old" = ON ];then
		[ ! -f "$CRASHDIR"/.dis_startup ] && return 0
	elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
		[ -n "$(find /etc/rc.d -name '*shellcrash')" ] && return 0
	elif ckcmd systemctl; then
		[ "$(systemctl is-enabled shellcrash.service 2>&1)" = enabled ] && return 0
	elif grep -q 's6' /proc/1/comm; then
		[ -f /etc/s6-overlay/s6-rc.d/user/contents.d/afstart ] && return 0
	elif rc-status -r >/dev/null 2>&1; then
		rc-update show default | grep -q "shellcrash" && return 0
	else
		return 1
	fi
	return 1
}
