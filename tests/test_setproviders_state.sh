#!/bin/sh
# 配置文件管理菜单中连续打开不同提供者时，不得沿用上一条记录的 link/link_uri 等字段 (#1372)
# 从 set_core_config 主菜单按编号进入：先打开一条记录并返回，再打开另一条执行操作

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CRASHDIR=$(mktemp -d)
trap 'rm -rf "$CRASHDIR"' EXIT
mkdir -p "$CRASHDIR/configs" "$CRASHDIR/menus"

# 界面函数替身：只简化显示，菜单分支、保存、删除均使用源码
load_lang() { :; }
line_break() { :; }
separator_line() { :; }
content_line() { :; }
comp_box() { :; }
top_box() { :; }
btm_box() { :; }
list_box() { :; }
msg_alert() { :; }
common_success() { :; }
# 输入序列走错分支时直接失败，避免菜单死循环
errornum() { exit 99; }
error_letter() { exit 99; }
error_input() { exit 99; }
# 会改配置或联网的调用只记录，不执行；选项 b 会 source 沙箱中的 providers_clash.sh
setconfig() { printf 'setconfig %s\n' "$*" >>"$CRASHDIR/log"; }
cat >"$CRASHDIR/menus/providers_clash.sh" <<'EOF'
gen_providers() { printf 'gen_providers %s\n' "$*" >>"$CRASHDIR/log"; }
EOF

crashcore=meta
. "$ROOT/scripts/menus/6_core_config.sh"
jump_core_config() { printf 'jump_core_config\n' >>"$CRASHDIR/log"; }

NL='
'
HTTP='Old https://example.invalid/sub 3 12 clash.meta # #'
LOCAL='Loc ./providers/local.yaml 5 24 ua2 #HK #US'
URI='Node ss://dummy'
URI2='Node2 trojan://dummy2'
# 主菜单编号：1) Old  2) Loc  3) Node  4) Node2
P0="$HTTP$NL$LOCAL"
U0="$URI$NL$URI2"

join() { printf '%s\n' "$1" | awk 'NR > 1 { printf " | " } { printf "%s", $0 } END { print "" }'; }
show() {
    [ "$2" = "$3" ] || printf '  %s\n    want: %s\n    got:  %s\n' "$1" "$(join "$2")" "$(join "$3")" >&2
}

failures=0
# 参数：用例名 菜单输入(按空格拆分) 期望providers.cfg 期望providers_uri.cfg 期望副作用
# 列表比较不计顺序，保存会把记录移到文件末尾
t() {
    printf '%s\n' "$P0" >"$CRASHDIR/configs/providers.cfg"
    printf '%s\n' "$U0" >"$CRASHDIR/configs/providers_uri.cfg"
    : >"$CRASHDIR/log"
    printf '%s\n' $2 | (set_core_config) >/dev/null 2>&1
    rc=$?
    got_p=$(sort "$CRASHDIR/configs/providers.cfg")
    got_u=$(sort "$CRASHDIR/configs/providers_uri.cfg")
    got_l=$(cat "$CRASHDIR/log")
    want_p=$(printf '%s\n' "$3" | grep -v '^$' | sort)
    want_u=$(printf '%s\n' "$4" | grep -v '^$' | sort)
    if [ "$rc" = 0 ] && [ "$got_p" = "$want_p" ] && [ "$got_u" = "$want_u" ] && [ "$got_l" = "$5" ]; then
        printf 'PASS %s\n' "$1"
    else
        failures=$((failures + 1))
        printf 'FAIL %s (rc=%s)\n' "$1" "$rc" >&2
        show providers.cfg "$want_p" "$got_p"
        show providers_uri.cfg "$want_u" "$got_u"
        show 'side effects' "$5" "$got_l"
    fi
}

# 订阅 -> 分享链接
t http_to_uri/delete '1 0 3 d 0' "$P0" "$URI2" ''
t http_to_uri/save '1 0 3 a 0' "$P0" "$U0" ''
t http_to_uri/gen_online '1 0 3 c 0 0' "$P0" "$U0" \
    "setconfig Url 'ss://dummy#Node'${NL}setconfig Https${NL}jump_core_config"
# 分享链接记录不支持本地生成(b)、在线获取(e)：只提示，不写列表、不生成、不下载
t http_to_uri/gen_local '1 0 3 b 0 0' "$P0" "$U0" ''
# e 后的 1 用于确认旧代码会弹出的危险操作提示；修复后无此提示，1 进入改名并被 0 取消
t http_to_uri/fetch_direct '1 0 3 e 1 0 0 0' "$P0" "$U0" ''

# 分享链接 -> 订阅
t uri_to_http/delete '3 0 1 d 0' "$LOCAL" "$U0" ''
t uri_to_http/save '3 0 1 a 0' "$P0" "$U0" ''
t uri_to_http/gen_online '3 0 1 c 0 0' "$P0" "$U0" \
    "setconfig Url 'https://example.invalid/sub'${NL}setconfig Https${NL}jump_core_config"

# 同类型连续编辑
t http_to_local/delete '1 0 2 d 0' "$HTTP" "$U0" ''
t http_to_local/save '1 0 2 a 0' "$P0" "$U0" ''
t uri_to_uri/delete '3 0 4 d 0' "$P0" "$URI" ''
t uri_to_uri/save '3 0 4 a 0' "$P0" "$U0" ''

# 分享链接记录改为订阅链接后保存：间隔、UA、过滤词取默认值，不沿用 Loc 的设置
t local_to_uri/relink '2 0 3 2 https://example.invalid/new a 0' \
    "$P0${NL}Node https://example.invalid/new 3 12 clash.meta # #" "$URI2" ''
# 打开已有记录后新建提供者（无参数调用），字段同样取默认值
t local_then_new '2 0 a 1 New 2 https://example.invalid/new a 0' \
    "$P0${NL}New https://example.invalid/new 3 12 clash.meta # #" "$U0" ''

[ "$failures" -eq 0 ] || exit 1
printf 'setproviders state reset tests passed\n'
