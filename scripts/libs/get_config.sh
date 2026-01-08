. "$CRASHDIR"/configs/command.env >/dev/null 2>&1
. "$CRASHDIR"/configs/ShellCrash.cfg

[ -z "$mix_port" ] && mix_port=7890
[ -z "$redir_port" ] && redir_port=7892
[ -z "$tproxy_port" ] && tproxy_port=7893
[ -z "$db_port" ] && db_port=9999
[ -z "$dns_port" ] && dns_port=1053
[ -z "$dns_redir_port" ] && dns_redir_port="$dns_port"
[ -z "$fwmark" ] && fwmark="$redir_port"
routing_mark=$((fwmark + 2))
[ -z "$table" ] && table=100

[ -z "$dns_nameserver" ] && {
	dns_nameserver='223.5.5.5, 1.2.4.8'
	cat /proc/net/udp | grep -q '0035' && dns_nameserver='localhost'
}
[ -z "$dns_fallback" ] && dns_fallback="1.1.1.1, 8.8.8.8"
[ -z "$dns_resolver" ] && {
	dns_resolver="223.5.5.5, 2400:3200::1"
	cat /proc/net/udp | grep -q '0035' && dns_resolver='127.0.0.1'
}