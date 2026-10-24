if [ "$network_check" = "OFF" ]; then
    #复用网络检查开关：禁用自启网络检查时，也跳过启动后的面板端口校验
    test=skip
else
    i=1
    while [ -z "$test" ] && [ "$i" -lt 30 ]; do
        sleep 1
        if curl --version >/dev/null 2>&1; then
            test=$(curl -s -H "Authorization: Bearer $secret" http://127.0.0.1:${db_port}/proxies | grep -o proxies)
        else
            test=$(wget -q --header="Authorization: Bearer $secret" -O - http://127.0.0.1:${db_port}/proxies | grep -o proxies)
        fi
        i=$((i + 1))
    done
fi
