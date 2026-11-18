#!/bin/sh
# Run with sh tests/local_only_listeners.sh [path/to/scripts].
set -e
scripts=${1:-$(dirname "$0")/../scripts}
. "$scripts/starts/clash_modify.sh"
. "$scripts/starts/singbox_modify.sh"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

setup() {
    CRASHDIR="$test_dir/$1"
    TMPDIR="$CRASHDIR/tmp"
    BINDIR="$CRASHDIR/bin"
    mkdir -p "$CRASHDIR/yamls" "$TMPDIR/jsons" "$BINDIR"
    core_config="$CRASHDIR/yamls/config.yaml"
    printf 'rules:\n - MATCH,DIRECT\n' >"$core_config"
    crashcore=meta
    redir_mod=Redir
    dns_mod=redir_host
    ipv6_dns=OFF
    ecs_subnet=OFF
    sniffer=OFF
    hosts_opt=OFF
    dns_resolver=223.5.5.5
    dns_nameserver=223.5.5.5
    dns_proxy_server=223.5.5.5
    fakeip4=198.18.0.0/15
    fakeip6=2001:2::/64
    mix_port=7890
    redir_port=7892
    tproxy_port=7893
    dns_port=1053
    db_port=9999
    routing_mark=7894
    secret=test-secret
    authentication=
    vms_service=OFF
    sss_service=OFF
    vm_redir=OFF
    ipv6_redir=OFF
    ipv6_support=OFF
    yaml_user= yaml_others= yaml_dns= yaml_hosts=
}

assert_line() {
    grep -qFx -- "$1" "$2" || {
        echo "Missing expected line in $2: $1" >&2
        exit 1
    }
}

generate_clash() {
    # Optional sections return a nonzero status when disabled.
    prepare_clash_base_config || :
    generate_set_and_hosts_yaml || :
    : >"$TMPDIR/listeners.yaml"
    : >"$TMPDIR/rules.yaml"
    add_custom_inbounds_and_rules || :
}

assert_local() {
    generate_clash
    assert_line 'mixed-port: 0' "$TMPDIR/set.yaml"
    assert_line '   listen: 127.0.0.1' "$TMPDIR/listeners.yaml"
    assert_line '   port: 7890' "$TMPDIR/listeners.yaml"
    assert_line 'external-controller: 127.0.0.1:9999' "$TMPDIR/set.yaml"
    assert_line '  listen: :1053' "$TMPDIR/dns.yaml"
    gen_inbounds
    gen_experimental
    [ "$(grep -c '"listen": "127.0.0.1"' "$TMPDIR/jsons/inbounds.json")" = 1 ]
    [ "$(grep -c '"listen": "::"' "$TMPDIR/jsons/inbounds.json")" = 3 ]
    assert_line '      "external_controller": "127.0.0.1:9999",' "$TMPDIR/jsons/experimental.json"
}

assert_network() {
    generate_clash
    assert_line 'allow-lan: true' "$TMPDIR/set.yaml"
    assert_line 'mixed-port: 7890' "$TMPDIR/set.yaml"
    [ ! -s "$TMPDIR/listeners.yaml" ]
    assert_line 'external-controller: :9999' "$TMPDIR/set.yaml"
    assert_line '  listen: :1053' "$TMPDIR/dns.yaml"
    gen_inbounds
    gen_experimental
    [ "$(grep -c '"listen": "::"' "$TMPDIR/jsons/inbounds.json")" = 4 ]
    assert_line '      "external_controller": "0.0.0.0:9999",' "$TMPDIR/jsons/experimental.json"
}

# The generated mixed proxy and API must stay local without a working firewall.
setup local
firewall_area=2
assert_local
authentication='test-user:test-pass'
assert_local
assert_line 'authentication: ["test-user:test-pass"]' "$TMPDIR/set.yaml"
assert_line '      "users": [{ "username": "test-user", "password": "test-pass" }], ' "$TMPDIR/jsons/inbounds.json"

# Preserve router, combined, pure-proxy and gateway modes. Switching modes in
# the same process must not reuse an earlier listener address.
setup modes
for firewall_area in 1 3 4 5 ''; do
    assert_network
    firewall_area=2
    assert_local
done

# Transparent IPv6 and VM forwarding must keep their existing listeners while
# neither setting reopens the explicit mixed proxy.
firewall_area=2
ipv6_redir=ON
assert_local
assert_line '   listen: ::1' "$TMPDIR/listeners.yaml"
[ "$(grep -c '"listen": "::1"' "$TMPDIR/jsons/inbounds.json")" = 1 ]
ipv6_redir=OFF
ipv6_support=ON
assert_local
assert_line '   listen: ::1' "$TMPDIR/listeners.yaml"
ipv6_support=OFF
vm_redir=ON
assert_local
vm_redir=OFF
assert_local
! grep -q 'listen: ::1' "$TMPDIR/listeners.yaml"
! grep -q '"listen": "::1"' "$TMPDIR/jsons/inbounds.json"

# A rejected custom override must fall back to local-only base settings.
setup fallback
firewall_area=2
generate_clash
printf 'allow-lan: true\nlog-level: invalid\n' >"$CRASHDIR/yamls/user.yaml"
printf ' - MATCH,DIRECT\n' >"$TMPDIR/rules.yaml"
: >"$TMPDIR/proxy-groups.yaml"
yaml_char='rules listeners'
merger_yaml
printf '#!/bin/sh\nexit 1\n' >"$TMPDIR/CrashCore"
chmod +x "$TMPDIR/CrashCore"
logger() { :; }
set +e
test_yaml
set -e
assert_line 'mixed-port: 0' "$TMPDIR/config.yaml"
assert_line '   listen: 127.0.0.1' "$TMPDIR/config.yaml"
assert_line 'external-controller: 127.0.0.1:9999' "$TMPDIR/config.yaml"
assert_line '  listen: :1053' "$TMPDIR/config.yaml"
! grep -qFx 'mixed-port: 7890' "$TMPDIR/config.yaml"

echo 'PASS: local-only listeners, both cores, network modes, VM forwarding and fallback'
