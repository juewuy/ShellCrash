. "$CRASHDIR"/libs/set_proxy.sh
#$1:目标地址 $2:禁用proxy
web_get_lite() {
	[ -z "$2" ] && setproxy
	if curl --version >/dev/null 2>&1; then
		curl -ksSl --connect-timeout 3 "$1" 2>/dev/null
	else
		wget -Y on -q --timeout=3 -O - "$1"
	fi
}
