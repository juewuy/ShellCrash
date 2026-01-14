
setproxy(){
	[ -n "$(pidof CrashCore)" ] && {
		[ -n "$authentication" ] && auth="$authentication@" || auth=""
		[ -z "$mix_port" ] && mix_port=7890
		export https_proxy="http://${auth}127.0.0.1:$mix_port"
		export http_proxy="http://${auth}127.0.0.1:$mix_port"
	}
}