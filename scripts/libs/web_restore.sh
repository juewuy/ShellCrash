
#
put_save() { #推送面板选择
    [ -z "$3" ] && request_type=PUT || request_type=$3
    if curl --version >/dev/null 2>&1; then
        curl -sS -X "$request_type" -H "Authorization: Bearer $secret" -H "Content-Type:application/json" "$1" -d "$2" >/dev/null
    elif wget --version >/dev/null 2>&1; then
        wget -q --method="$request_type" --header="Authorization: Bearer $secret" --header="Content-Type:application/json" --body-data="$2" "$1" >/dev/null
    fi
}
web_restore() { #还原面板选择
	num=$(cat "$CRASHDIR"/configs/web_save | wc -l)
	i=1
	while [ "$i" -le "$num" ]; do
		group_name=$(awk -F ',' 'NR=="'${i}'" {print $1}' "$CRASHDIR"/configs/web_save | sed 's/ /%20/g')
		now_name=$(awk -F ',' 'NR=="'${i}'" {print $2}' "$CRASHDIR"/configs/web_save)
		put_save "http://127.0.0.1:${db_port}/proxies/${group_name}" "{\"name\":\"${now_name}\"}"
		i=$((i + 1))
	done
}
