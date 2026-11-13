#!/bin/sh
# 生成提供者配置时，过滤词、跳过证书验证与订阅标签不得沿用上一个订阅或上一次生成的值

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
CRASHDIR="$SANDBOX/crash"
CFG="$CRASHDIR/configs"
OUT="$SANDBOX/out"
TMPDIR="$SANDBOX/tmp"
mkdir -p "$CFG" "$CRASHDIR/libs" "$CRASHDIR/starts"

# 模板只保留订阅标签占位符
printf '{"tags": [{providers_tags}]}\n' >"$SANDBOX/singbox.json"
printf 'proxy-groups:\n  - {name: P, use: [{providers_tags}]}\nrules:\n  - MATCH,P\n' >"$SANDBOX/clash.yaml"
printf 'provider_temp_singbox=%s\nprovider_temp_clash=%s\n' "$SANDBOX/singbox.json" "$SANDBOX/clash.yaml" >"$CFG/ShellCrash.cfg"
: >"$CRASHDIR/libs/web_get_bin.sh"
# 内核检查替身：留存送检的生成结果，再按检查失败返回，不触发保存和启动
cat >"$CRASHDIR/starts/check_core.sh" <<'EOF'
check_core() {
    mkdir -p "$OUT"
    cp "$TMPDIR"/providers/providers.json "$TMPDIR"/providers/outbounds.json "$TMPDIR"/config.yaml "$OUT"/ 2>/dev/null
    return 1
}
EOF

load_lang() { :; }
msg_alert() { :; }
# macOS 的 BSD sed 不支持不带后缀的 -i
if ! sed --version >/dev/null 2>&1; then
    sed() {
        if [ "$1" = -i ]; then
            shift
            command sed -i '' "$@"
        else
            command sed "$@"
        fi
    }
fi

# 每个用例前重置沙箱，$1 为 providers.cfg 的内容
reset_case() {
    rm -rf "$OUT" "$TMPDIR" "$CRASHDIR/providers" "$CFG/providers.cfg" "$CFG/providers_uri.cfg"
    mkdir -p "$TMPDIR"
    [ -z "$1" ] || printf '%s\n' "$1" >"$CFG/providers.cfg"
}

# 同一会话里删光订阅，只留分享链接
uri_only() {
    : >"$CFG/providers.cfg"
    printf '%s\n' 'Node ss://dummy' >"$CFG/providers_uri.cfg"
}

# 按提供者输出"标签:排除:包含"，未设置记为 -
sb_filters() {
    awk -F'"' '
        $2 == "tag" { if (t != "") printf "%s:%s:%s ", t, ex, inc; t = $4; ex = "-"; inc = "-" }
        $2 == "exclude" { ex = $4 }
        $2 == "include" { inc = $4 }
        END { if (t != "") printf "%s:%s:%s", t, ex, inc }
    ' "$OUT/providers.json"
}

# 模板分组里实际填入的订阅标签
tags() {
    case "$1" in
        singbox) sed -n 's/^{"tags": \(.*\)}$/\1/p' "$OUT/outbounds.json" ;;
        clash) sed -n 's/^  - {name: P, use: \(.*\)}$/\1/p' "$OUT/config.yaml" ;;
    esac
}

failures=0
check() {
    if [ "$2" = "$3" ]; then
        printf 'PASS %s\n' "$1"
    else
        printf 'FAIL %s\n  want: %s\n  got:  %s\n' "$1" "$2" "$3" >&2
        failures=$((failures + 1))
    fi
}

# 一次生成全部订阅：后面的订阅不能继承前面订阅的过滤词
reset_case 'A https://a.invalid/sub 3 12 clash.meta #HK #
B https://b.invalid/sub 3 12 clash.meta # #
C https://c.invalid/sub 3 12 clash.meta # #JP
D https://d.invalid/sub 3 12 clash.meta # #'
got=$(
    CORE_TYPE=singbox
    . "$ROOT/scripts/menus/providers_singbox.sh"
    gen_providers >/dev/null 2>&1
    sb_filters
)
check singbox/all_filters 'A:HK:- B:-:- C:-:JP D:-:-' "$got"

# 同一会话里先后单独生成两个订阅
reset_case ''
got=$(
    CORE_TYPE=singbox
    . "$ROOT/scripts/menus/providers_singbox.sh"
    gen_providers A https://a.invalid/sub 3 12 clash.meta '#HK' '#JP' >/dev/null 2>&1
    gen_providers B https://b.invalid/sub 3 12 clash.meta '#' '#' >/dev/null 2>&1
    sb_filters
)
check singbox/single_then_single 'B:-:-' "$got"

# 生成过一次后只剩分享链接，再次生成时标签只能是 Uri_group
for core in singbox clash; do
    reset_case 'A https://a.invalid/sub 3 12 clash.meta # #'
    got=$(
        CORE_TYPE=$core crashcore=meta
        . "$ROOT/scripts/menus/providers_$core.sh"
        gen_providers >/dev/null 2>&1
        first=$(tags "$core")
        uri_only
        gen_providers >/dev/null 2>&1
        printf '%s | %s' "$first" "$(tags "$core")"
    )
    case "$core" in
        singbox) want='["A"] | ["Uri_group"]' ;;
        clash) want='[A] | [Uri_group]' ;;
    esac
    check "$core/tags_uri_only" "$want" "$got"
done

# 同一会话里关闭跳过证书验证后再生成
reset_case ''
got=$(
    CORE_TYPE=clash crashcore=meta
    . "$ROOT/scripts/menus/providers_clash.sh"
    skip_cert=ON
    gen_providers A https://a.invalid/sub 3 12 clash.meta '#' '#' >/dev/null 2>&1
    on=$(grep -c 'skip-cert-verify: true' "$OUT/config.yaml")
    skip_cert=OFF
    gen_providers A https://a.invalid/sub 3 12 clash.meta '#' '#' >/dev/null 2>&1
    printf 'ON=%s OFF=%s' "$on" "$(grep -c 'skip-cert-verify: true' "$OUT/config.yaml")"
)
check clash/skip_cert_on_then_off 'ON=1 OFF=0' "$got"

[ "$failures" -eq 0 ] || exit 1
printf 'providers stale vars tests passed\n'
