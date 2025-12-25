i=1
while [ -z "$test" -a "$i" -lt 30 ]; do
	sleep 1
	if curl --version >/dev/null 2>&1; then
		test=$(curl -s -H "Authorization: Bearer $secret" http://127.0.0.1:${db_port}/proxies | grep -o proxies)
	else
		test=$(wget -q --header="Authorization: Bearer $secret" -O - http://127.0.0.1:${db_port}/proxies | grep -o proxies)
	fi
	i=$((i + 1))
done
