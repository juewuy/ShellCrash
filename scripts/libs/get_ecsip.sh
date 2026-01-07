
get_ecs_address() {
    for f in /tmp/resolv.conf.auto /tmp/resolv.conf /tmp/resolv.conf.d/resolv.conf.auto; do
        [ -f "$f" ] || continue
        ip=$(grep -A1 "^# Interface wan$" "$f" | grep nameserver | awk '{printf "%s ", $2}')
        [ -n "$ip" ] && return
    done
	. "$CRASHDIR"/libs/web_get_lite.sh
	for web in http://members.3322.org/dyndns/getip http://4.ipw.cn http://ipinfo.io/ip; do
		ip=$(web_get_lite "$web" 0)
		[ -n "$ip" ] && return
	done
}
get_ecs_address
[ -n "$ip" ] && ecs_address="${ip%.*}.0/24"
