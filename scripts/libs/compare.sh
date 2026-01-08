compare() { #对比文件
    if [ ! -f "$1" ] || [ ! -f "$2" ]; then
        return 1
    elif ckcmd cmp; then
        cmp -s "$1" "$2"
		return $?
    else
        [ "$(cat "$1")" = "$(cat "$2")" ] && return 0 || return 1
    fi
}