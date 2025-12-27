. "$CRASHDIR"/libs/set_proxy.sh
#$1:目标地址 $2:json字符串
web_json_post() {
	setproxy
	if curl --version >/dev/null 2>&1; then
		curl -kfsSl -X POST --connect-timeout 3 -H "Content-Type: application/json" "$1" -d "$2" >/dev/null 2>&1
	else
		wget -Y on -q --timeout=3 --method=POST --header="Content-Type: application/json" --body-data="$2" "$1"
	fi
}
