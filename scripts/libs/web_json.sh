. "$CRASHDIR"/libs/set_proxy.sh
#$1:目标地址 $2:json字符串
web_json_get() {
	setproxy
	if curl --version >/dev/null 2>&1; then
		curl -ksSl --connect-timeout 3 "$1" 2>/dev/null
	else
		wget -Y on -q --timeout=3 -O - "$1"
	fi
}
web_json_post() {
	setproxy
	if curl --version >/dev/null 2>&1; then
		curl -ksSl -X POST --connect-timeout 3 -H "Content-Type: application/json; charset=utf-8" "$1" -d "$2" >/dev/null 2>&1
	else
		wget -Y on -q --timeout=3 --method=POST --header="Content-Type: application/json; charset=utf-8" --body-data="$2" "$1"
	fi
}
