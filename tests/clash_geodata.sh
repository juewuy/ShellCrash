#!/bin/sh
# Run with sh tests/clash_geodata.sh [path/to/clash_modify.sh].
set -e
script=${1:-$(dirname "$0")/../scripts/starts/clash_modify.sh}
. "$script"
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

setup() {
    CRASHDIR="$test_dir/$1"
    TMPDIR="$CRASHDIR/tmp"
    BINDIR="$CRASHDIR/bin"
    mkdir -p "$CRASHDIR/yamls" "$TMPDIR" "$BINDIR"
    core_config="$CRASHDIR/yamls/config.yaml"
    dns_mod=redir_host
    yaml_char='rules proxy-groups'
    yaml_user= yaml_others= yaml_dns= yaml_hosts=
    printf 'mode: Rule\n' >"$TMPDIR/set.yaml"
    printf ' - GEOSITE,GOOGLE,DIRECT\n' >"$TMPDIR/rules.yaml"
    : >"$TMPDIR/proxy-groups.yaml"
    cat >"$core_config" <<'EOF'
geodata-mode: true
geodata-loader: memconservative
geosite-matcher: succinct
geo-auto-update: true
geo-update-interval: 24
geox-url:
  geoip: https://example.invalid/geoip.dat
  geosite: >-
    https://example.invalid/geosite.dat
  mmdb: https://example.invalid/Country.mmdb
rules:
 - GEOSITE,GOOGLE,DIRECT
mixed-port: 1234
EOF
}

assert_line() {
    grep -qFx -- "$1" "$TMPDIR/config.yaml" || {
        echo "Missing expected line: $1" >&2
        exit 1
    }
}

setup inherited
merger_yaml
assert_line 'geodata-mode: true'
assert_line 'geodata-loader: memconservative'
assert_line 'geosite-matcher: succinct'
assert_line 'geo-auto-update: true'
assert_line 'geo-update-interval: 24'
assert_line '    https://example.invalid/geosite.dat'
[ "$(grep -c '^rules:' "$TMPDIR/config.yaml")" = 1 ]
! grep -q '^mixed-port: 1234' "$TMPDIR/config.yaml"
finalize_clash_yaml
[ ! -e "$TMPDIR/geodata.yaml" ]
[ ! -e "$TMPDIR/geodata_base.yaml" ]

setup overrides
printf 'geodata-mode: false\n' >"$CRASHDIR/yamls/user.yaml"
printf 'geox-url: {geosite: https://override.invalid/geosite.dat}\n' >"$CRASHDIR/yamls/others.yaml"
merger_yaml
assert_line 'geodata-mode: false'
assert_line 'geox-url: {geosite: https://override.invalid/geosite.dat}'
[ "$(grep -c '^geodata-mode:' "$TMPDIR/config.yaml")" = 1 ]
[ "$(grep -c '^geox-url:' "$TMPDIR/config.yaml")" = 1 ]
! grep -q 'example.invalid' "$TMPDIR/config.yaml"

# A rejected custom configuration must fall back to the subscription settings.
printf '#!/bin/sh\nexit 1\n' >"$TMPDIR/CrashCore"
chmod +x "$TMPDIR/CrashCore"
logger() { :; }
set +e
test_yaml
set -e
assert_line 'geodata-mode: true'
assert_line '    https://example.invalid/geosite.dat'
[ "$(grep -c '^geox-url:' "$TMPDIR/config.yaml")" = 1 ]
! grep -q 'override.invalid' "$TMPDIR/config.yaml"

setup inline
printf 'geox-url: {geosite: https://inline.invalid/geosite.dat}\ngeo-auto-update: false\n---\nmixed-port: 1234\n' >"$core_config"
merger_yaml
assert_line 'geox-url: {geosite: https://inline.invalid/geosite.dat}'
assert_line 'geo-auto-update: false'
! grep -qE '^---|^mixed-port: 1234' "$TMPDIR/config.yaml"

setup absent
printf 'rules:\n - MATCH,DIRECT\n' >"$core_config"
merger_yaml
! grep -qE '^geo(data|site|x|-)' "$TMPDIR/config.yaml"
assert_line 'mode: Rule'
echo 'PASS: inherited geodata, overrides, fallback, inline maps, cleanup and absent settings'
