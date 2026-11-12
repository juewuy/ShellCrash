#!/bin/sh
# webget curl 分支：退出码判定与失败清理 (#1369)
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CRASHDIR="$ROOT/scripts"
. "$CRASHDIR/libs/web_get.sh"

SANDBOX=$(mktemp -d)
trap 'command rm -rf "$SANDBOX"' EXIT

pidof() { return 1; }
ckcmd() { return 1; }
usleep() { sleep 0; }

wget() {
    [ "$1" = --help ] && return 0 #不含 show-progress，走 curl 分支
    return 1
}

# 安全网：只放行沙箱内路径及 execute_curl 自带的结果文件，并记录调用
rm() {
    for arg; do
        case "$arg" in
            -* | "$SANDBOX"/* | /tmp/webget_res) ;;
            *)
                printf '%s\n' "$*" >>"$SANDBOX/rm_blocked"
                return 1
                ;;
        esac
    done
    printf '%s\n' "$*" >>"$SANDBOX/rm.log"
    command rm "$@"
}

# 按 $plan 逐次决定每次下载的行为：ok / partial(200+退出码18) / notfound(404) / refused
curl() {
    case "$1" in
        --version)
            printf '%s\n' 'curl 7.88.1'
            return 0
            ;;
        -sIL)
            printf 'HTTP/1.1 200 OK\r\nContent-Length: 300000\r\n\r\n'
            return 0
            ;;
    esac
    out=
    while [ $# -gt 0 ]; do
        [ "$1" = -o ] && out=$2
        shift
    done
    n=$(($(cat "$SANDBOX/attempts" 2>/dev/null || echo 0) + 1))
    echo "$n" >"$SANDBOX/attempts"
    step=$(echo "$plan" | cut -d ' ' -f "$n")
    case "$step" in
        ok)
            printf 'complete\n' >"$out"
            printf 200
            return 0
            ;;
        partial)
            printf 'part' >"$out"
            printf 200
            return 18
            ;;
        notfound)
            printf 'not found' >"$out"
            printf 404
            return 0
            ;;
        refused)
            printf 000
            return 7
            ;;
    esac
}

failures=0
fail() {
    printf 'FAIL %s: %s\n' "$name" "$1" >&2
    exit 1
}

# 参数：用例名 下载计划 目标准备方式 期望返回值 期望目标状态
run_case() (
    name=$1 plan=$2 setup=$3 expected_rc=$4 expected_target=$5
    work="$SANDBOX/$name"
    mkdir -p "$work"
    command rm -f "$SANDBOX/attempts" "$SANDBOX/rm.log"
    target="$work/file"
    case "$setup" in
        new) ;;
        existing) printf 'old\n' >"$target" ;;
        symlink)
            printf 'keep\n' >"$work/real"
            ln -s "$work/real" "$target"
            ;;
        devnull) target=/dev/null ;;
    esac
    url=http://example.invalid/file
    [ "$big" = 1 ] && url=https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@update/bin/file
    if webget "$target" "$url" echoon 2>/dev/null; then rc=0; else rc=$?; fi
    [ "$rc" = "$expected_rc" ] || fail "expected rc=$expected_rc, got rc=$rc"
    case "$expected_target" in
        absent) [ ! -e "$target" ] && [ ! -L "$target" ] || fail 'target should be removed' ;;
        complete) [ "$(cat "$target")" = complete ] || fail 'target should hold complete content' ;;
        kept) [ -f "$target" ] || fail 'pre-existing target should be kept' ;;
        link_kept)
            [ -L "$target" ] || fail 'symlink should be kept'
            [ -f "$work/real" ] || fail 'symlink target should be kept'
            ;;
        untouched) ;;
    esac
    if [ "$expected_target" != absent ] && grep -qF -- "$target" "$SANDBOX/rm.log" 2>/dev/null; then
        fail 'rm must not be called on target'
    fi
    [ ! -f "$SANDBOX/rm_blocked" ] || fail "blocked rm: $(cat "$SANDBOX/rm_blocked")"
)

for big in 0 1; do
    for c in \
        'ok|ok|new|0|complete' \
        'partial_then_ok|partial ok|new|0|complete' \
        'partial_twice|partial partial|new|1|absent' \
        'notfound_twice|notfound notfound|new|1|absent' \
        'partial_then_refused|partial refused|new|1|absent' \
        'existing_kept|partial partial|existing|1|kept' \
        'symlink_kept|partial partial|symlink|1|link_kept' \
        'devnull_kept|partial partial|devnull|1|untouched'; do
        old_ifs=$IFS
        IFS='|'
        set -- $c
        IFS=$old_ifs
        label="big$big/$1"
        if run_case "$label" "$2" "$3" "$4" "$5"; then
            printf 'PASS %s\n' "$label"
        else
            failures=$((failures + 1))
        fi
    done
done

[ "$failures" -eq 0 ] || exit 1
printf 'webget curl exit code tests passed\n'
