#!/bin/sh
# webget wget 分支：失败统一返回 1 与失败清理 (#1383)
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CRASHDIR="$ROOT/scripts"
. "$CRASHDIR/libs/web_get.sh"

SANDBOX=$(mktemp -d)
trap 'command rm -rf "$SANDBOX"' EXIT

pidof() { return 1; }
ckcmd() { [ "$1" = wget ]; }
curl() { return 127; } #curl 不可用时，帮助中没有 --show-progress 的 wget 走第三个分支

# wget_proxy 用 exec 调用外部 wget，函数替身拦不住，替身必须放在 PATH 中
# backend：gnu（含 --show-progress）、busybox（-Y on/off）、gnu_legacy（GNU 风格但不含 --show-progress）
# plan：按次序决定每次下载的行为 ok / partial / neterr / srverr
mkdir "$SANDBOX/bin"
cat >"$SANDBOX/bin/wget" <<'EOF'
#!/bin/sh
if [ "$1" = --help ]; then
    case "$backend" in
        gnu) printf '%s\n' '--show-progress' ;;
        busybox) printf '%s\n' '-Y on/off' ;;
    esac
    exit 0
fi
out=
while [ $# -gt 0 ]; do
    [ "$1" = -O ] && out=$2
    shift
done
n=$(($(cat "$SANDBOX/attempts" 2>/dev/null || echo 0) + 1))
echo "$n" >"$SANDBOX/attempts"
step=$(echo "$plan" | cut -d ' ' -f "$n")
# GNU 风格 wget 在发出请求前就创建并清空 -O 文件；BusyBox wget 收到响应数据后才创建
[ "$backend" = busybox ] || : >"$out"
case "$step" in
    ok)
        printf 'complete\n' >"$out"
        exit 0
        ;;
    partial)
        printf 'part' >"$out"
        code=4
        ;;
    neterr) code=4 ;;
    srverr) code=8 ;;
    *) exit 99 ;;
esac
# BusyBox wget 出错时一律返回 1
[ "$backend" != busybox ] || code=1
exit "$code"
EOF
chmod +x "$SANDBOX/bin/wget"
PATH="$SANDBOX/bin:$PATH"
export SANDBOX backend plan

# 安全网：只放行沙箱内路径，并记录调用
rm() {
    for arg; do
        case "$arg" in
            -* | "$SANDBOX"/*) ;;
            *)
                printf '%s\n' "$*" >>"$SANDBOX/rm_blocked"
                return 1
                ;;
        esac
    done
    printf '%s\n' "$*" >>"$SANDBOX/rm.log"
    command rm "$@"
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
    if webget "$target" http://example.invalid/file echoon 2>/dev/null; then rc=0; else rc=$?; fi
    [ -f "$SANDBOX/attempts" ] || fail 'fake wget was not called'
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

for backend in gnu busybox gnu_legacy; do
    for c in \
        'ok|ok|new|0|complete' \
        'srverr_then_ok|srverr ok|new|0|complete' \
        'srverr_twice|srverr srverr|new|1|absent' \
        'neterr_twice|neterr neterr|new|1|absent' \
        'partial_twice|partial partial|new|1|absent' \
        'existing_kept|partial partial|existing|1|kept' \
        'symlink_kept|partial partial|symlink|1|link_kept' \
        'devnull_kept|srverr srverr|devnull|1|untouched'; do
        old_ifs=$IFS
        IFS='|'
        set -- $c
        IFS=$old_ifs
        label="$backend/$1"
        if run_case "$label" "$2" "$3" "$4" "$5"; then
            printf 'PASS %s\n' "$label"
        else
            failures=$((failures + 1))
        fi
    done
done

[ "$failures" -eq 0 ] || exit 1
printf 'webget wget exit code tests passed\n'
