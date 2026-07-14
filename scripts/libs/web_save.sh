get_save() { #获取面板信息并内部处理所有异常
    local response exit_code
    if curl --version >/dev/null 2>&1; then
        response=$(curl -sf -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1" 2>&1)
        exit_code=$?
        [ $exit_code -eq 0 ] && [ -n "$response" ] && [ "$response" != "{}" ] && {
            echo "$response"
            return 0
        }
        return 1
    elif [ -n "$(wget --help 2>&1 | grep '\-\-method')" ]; then
        response=$(wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1" 2>&1)
        exit_code=$?
        [ $exit_code -eq 0 ] && [ -n "$response" ] && [ "$response" != "{}" ] && {
            echo "$response"
            return 0
        }
        return 1
    fi
    return 1
}
web_save() { #保存面板配置(备份 cache.db 到 $BINDIR/configs;小内存模式跳过)
    [ "$BINDIR" != "$TMPDIR" ] && [ -s "$TMPDIR"/cache.db ] && cp -f "$TMPDIR"/cache.db "$BINDIR"/configs/cache.db
}
