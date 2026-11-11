
setproxy(){
    [ -n "$(pidof CrashCore)" ] && {
        [ -n "$authentication" ] && auth="$authentication@" || auth=""
        [ -z "$mix_port" ] && mix_port=7890
        export https_proxy="http://${auth}127.0.0.1:$mix_port"
        export http_proxy="http://${auth}127.0.0.1:$mix_port"
    }
}

wget_proxy() (
    mode=$1
    shift
    # BusyBox 使用 -Y，GNU Wget 和 Wget2 使用长选项控制代理。
    if wget --help 2>&1 | grep -q -- '-Y'; then
        exec wget -Y "$mode" "$@"
    fi
    exec wget "--proxy=$mode" "$@"
)
