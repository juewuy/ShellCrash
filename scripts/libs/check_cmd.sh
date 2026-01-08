ckcmd() {
    if command -v sh >/dev/null 2>&1;then
        command -v "$1" >/dev/null 2>&1
    else
        type "$1" >/dev/null 2>&1
    fi
}
