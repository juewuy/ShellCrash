#
put_save() { #推送面板选择
    [ -z "$3" ] && request_type=PUT || request_type=$3
    if curl --version >/dev/null 2>&1; then
        curl -sS -X "$request_type" -H "Authorization: Bearer $secret" -H "Content-Type:application/json" "$1" -d "$2" >/dev/null
    elif wget --version >/dev/null 2>&1; then
        wget -q --method="$request_type" --header="Authorization: Bearer $secret" --header="Content-Type:application/json" --body-data="$2" "$1" >/dev/null
    fi
}
web_restore() { #还原面板配置(恢复 cache.db 到 $TMPDIR;tmpfs 已有则跳过,避免覆盖更新的)
    [ ! -f "$TMPDIR"/cache.db ] && [ -s "$BINDIR"/configs/cache.db ] && cp -f "$BINDIR"/configs/cache.db "$TMPDIR"/cache.db
}
