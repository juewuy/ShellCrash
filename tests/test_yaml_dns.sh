#!/bin/sh

set -eu

test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/shellcrash-dns-test.XXXXXX")
trap 'rm -rf "$test_tmp"' EXIT

. "$(dirname "$0")/../scripts/libs/yaml_dns.sh"

fail() {
    printf 'FAIL: %s\n' "$1" >&2
    exit 1
}

assert_contains() {
    grep -Fq -- "$1" "$2" || fail "$1 not found in $2"
}

assert_not_contains() {
    grep -Fq -- "$1" "$2" && fail "$1 unexpectedly found in $2" || :
}

# A subscription block keeps provider-specific DNS policy and unknown fields,
# while ShellCrash-managed values still replace the subscription nameserver.
printf '%s\n' \
    'dns:' \
    '  nameserver-policy:' \
    '    "+.v51124-4.qpon": [1.1.1.1]' \
    '  fallback-filter: {geoip: true}' \
    '  fallback-filter: {geosite: true}' \
    '  nameserver: [9.9.9.9]' \
    'proxies: []' >"$test_tmp/original.yaml"
printf '%s\n' \
    'dns:' \
    '  nameserver: [223.5.5.5]' \
    '  enable: true' >"$test_tmp/managed.yaml"
yaml_dns_merge "$test_tmp/original.yaml" "$test_tmp/managed.yaml" /dev/null >"$test_tmp/block.out"
assert_contains '"+.v51124-4.qpon": [1.1.1.1]' "$test_tmp/block.out"
assert_contains 'fallback-filter: {geosite: true}' "$test_tmp/block.out"
assert_not_contains 'fallback-filter: {geoip: true}' "$test_tmp/block.out"
[ "$(grep -c '^  fallback-filter:' "$test_tmp/block.out")" = 1 ] || fail 'repeated DNS key was not reduced'
assert_contains 'nameserver: [223.5.5.5]' "$test_tmp/block.out"
assert_not_contains 'nameserver: [9.9.9.9]' "$test_tmp/block.out"
[ "$(grep -c '^dns:' "$test_tmp/block.out")" = 1 ] || fail 'block output has duplicate dns keys'

# Common one-line flow mappings are normalized before merging.
printf '%s\n' \
    'dns: {nameserver-policy: {"+.flow": [1.1.1.1]}, fallback-filter: {geoip: true}, nameserver: [9.9.9.9]}' \
    'proxies: []' >"$test_tmp/flow.yaml"
yaml_dns_merge "$test_tmp/flow.yaml" "$test_tmp/managed.yaml" /dev/null >"$test_tmp/flow.out"
assert_contains '"+.flow": [1.1.1.1]' "$test_tmp/flow.out"
assert_contains 'fallback-filter: {geoip: true}' "$test_tmp/flow.out"
[ "$(grep -c '^dns:' "$test_tmp/flow.out")" = 1 ] || fail 'flow output has duplicate dns keys'

# No subscription DNS still produces the managed DNS section.
: >"$test_tmp/empty.yaml"
yaml_dns_merge "$test_tmp/empty.yaml" "$test_tmp/managed.yaml" /dev/null >"$test_tmp/empty.out"
assert_contains 'enable: true' "$test_tmp/empty.out"

# User DNS wins field-by-field and is removed from the ordinary user overlay.
printf '%s\n' \
    'dns:' \
    '  nameserver: [8.8.8.8]' \
    '  custom-user: yes' \
    'mode: Rule' >"$test_tmp/user.yaml"
yaml_dns_merge "$test_tmp/original.yaml" "$test_tmp/managed.yaml" "$test_tmp/user.yaml" >"$test_tmp/user.out"
assert_contains 'nameserver: [8.8.8.8]' "$test_tmp/user.out"
assert_contains 'custom-user: yes' "$test_tmp/user.out"
assert_not_contains 'nameserver: [223.5.5.5]' "$test_tmp/user.out"
yaml_dns_without "$test_tmp/user.yaml" >"$test_tmp/user-without.out"
assert_contains 'mode: Rule' "$test_tmp/user-without.out"
if grep -q '^dns:' "$test_tmp/user-without.out"; then
    fail 'user overlay still contains dns'
fi

# A provider template may place dns after rules. Section extraction must stop
# at that next top-level key before dns.yaml is appended.
printf '%s\n' \
    'proxy-groups: []' \
    'rule-providers:' \
    '  sample: {type: http, behavior: classical}' \
    'rules:' \
    '  - MATCH,DIRECT' \
    'dns:' \
    '  nameserver-policy: {"+.provider": [1.1.1.1]}' >"$test_tmp/provider.yaml"
yaml_top_level_section "$test_tmp/provider.yaml" '^rule' >"$test_tmp/provider-rules.out"
assert_contains 'rules:' "$test_tmp/provider-rules.out"
assert_not_contains 'dns:' "$test_tmp/provider-rules.out"
yaml_dns_extract "$test_tmp/provider.yaml" >"$test_tmp/provider-dns.out"
cat "$test_tmp/provider-rules.out" "$test_tmp/provider-dns.out" >"$test_tmp/provider-config.out"
[ "$(grep -c '^dns:' "$test_tmp/provider-config.out")" = 1 ] ||
    fail 'provider output has duplicate dns keys'

# The one-click encrypted DNS preset must keep the resolver as IP literals.
assert_not_contains "dns_resolver='https://" "$(dirname "$0")/../scripts/menus/dns.sh"
assert_contains "dns_resolver='223.5.5.5, 2400:3200::1'" "$(dirname "$0")/../scripts/menus/dns.sh"

printf '%s\n' 'yaml dns tests passed'
