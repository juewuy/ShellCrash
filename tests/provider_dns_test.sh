#!/bin/sh

set -eu

TEST_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$TEST_DIR/.." && pwd)
SANDBOX=${TMPDIR:-/tmp}/shellcrash-provider-dns-test.$$
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

CRASHDIR=$SANDBOX/crash
TMPDIR=$SANDBOX/tmp
BINDIR=$TMPDIR
TASKCFGDIR=$CRASHDIR/configs/task
PROVIDER_DNS_NO_RELOAD=1
export CRASHDIR TMPDIR BINDIR TASKCFGDIR PROVIDER_DNS_NO_RELOAD

mkdir -p "$CRASHDIR/configs" "$TMPDIR/providers"
cp "$TEST_DIR/fixtures/provider_block.yaml" "$TMPDIR/providers/Block.yaml"
cp "$TEST_DIR/fixtures/provider_inline.yaml" "$TMPDIR/providers/Inline.yaml"
cp "$TEST_DIR/fixtures/provider_conflict.yaml" "$TMPDIR/providers/Conflict.yaml"
cat >"$CRASHDIR/configs/providers.cfg" <<'EOF'
Block https://subscription.example/block 3 12 clash.meta
Inline https://subscription.example/inline 3 12 clash.meta
Conflict https://subscription.example/conflict 3 12 clash.meta
EOF

. "$REPO_DIR/scripts/libs/provider_dns.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    grep -qF "$2" "$1" || fail "$1 does not contain $2"
}

provider_dns_resolve() {
    case "$1:$2" in
    edge-a.nodes.example:*resolver-d.example*) echo 203.0.113.40 ;;
    edge-a.nodes.example:*) echo 192.0.2.10 ;;
    edge-b.nodes.example:*) echo 192.0.2.11 ;;
    gateway.nodes.example:*) echo 198.51.100.20 ;;
    *) return 1 ;;
    esac
}

block_urls=$(provider_dns_extract_doh "$TMPDIR/providers/Block.yaml")
[ "$(printf '%s\n' "$block_urls" | wc -l | tr -d ' ')" = 2 ] || fail 'block DoH URLs were not parsed'
block_servers=$(provider_dns_extract_servers "$TMPDIR/providers/Block.yaml")
[ "$(printf '%s\n' "$block_servers" | wc -l | tr -d ' ')" = 2 ] || fail 'block proxy servers were not parsed'
inline_urls=$(provider_dns_extract_doh_for_server "$TMPDIR/providers/Inline.yaml" gateway.nodes.example)
[ "$(printf '%s\n' "$inline_urls" | wc -l | tr -d ' ')" = 1 ] || fail 'domain policy DoH was not selected'
printf '%s\n' "$inline_urls" | grep -qF resolver-c.example || fail 'the matching domain policy was not selected'

provider_dns_sync
assert_contains "$CRASHDIR/configs/provider_dns/hosts.yaml" "'edge-a.nodes.example': 192.0.2.10"
assert_contains "$CRASHDIR/configs/provider_dns/hosts.yaml" "'gateway.nodes.example': 198.51.100.20"
assert_contains "$CRASHDIR/configs/provider_dns/policy.yaml" "https://resolver-c.example/token/dns-query"
[ "$(grep -c edge-a.nodes.example "$CRASHDIR/configs/provider_dns/hosts.yaml")" = 1 ] || fail 'conflicting providers generated duplicate host keys'
assert_contains "$CRASHDIR/configs/provider_dns/hosts.yaml" "'edge-a.nodes.example': 192.0.2.10"

# The DNS parser skips CNAME records and returns a following A record.
printf '\000\000\201\200\000\001\000\002\000\000\000\000\001a\007example\000\000\001\000\001\300\014\000\005\000\001\000\000\000\000\000\002\300\014\300\014\000\001\000\001\000\000\000\000\000\004\313\000\161\011' >"$SANDBOX/cname-response.bin"
[ "$(provider_dns_parse_a "$SANDBOX/cname-response.bin")" = 203.0.113.9 ] || fail 'CNAME followed by A was not parsed'

cat >"$SANDBOX/config.yaml" <<'EOF'
dns:
  enable: true
  # BEGIN provider DNS sync
  proxy-server-nameserver:
    - 'https://legacy.example/dns-query'
  nameserver-policy:
    'legacy.nodes.example':
      - 'https://legacy.example/dns-query'
  # END provider DNS sync
  nameserver-policy:
    'rule-set:cn': [ 223.5.5.5 ]
hosts:
  # BEGIN provider DNS hosts sync
  'legacy.nodes.example': 203.0.113.99
  # END provider DNS hosts sync
  'router.lan': 192.168.1.1
proxies: []
EOF
provider_dns_apply_config "$SANDBOX/config.yaml"
assert_contains "$SANDBOX/config.yaml" '# BEGIN ShellCrash provider DNS'
assert_contains "$SANDBOX/config.yaml" "'edge-b.nodes.example': 192.0.2.11"
assert_contains "$SANDBOX/config.yaml" "'router.lan': 192.168.1.1"
if grep -q legacy.nodes.example "$SANDBOX/config.yaml"; then
    fail 'legacy managed blocks were not removed'
fi

# Hot reload validates and installs the candidate without losing its path in nested functions.
cat >"$TMPDIR/config.yaml" <<'EOF'
dns:
  enable: true
hosts:
  'router.lan': 192.168.1.1
proxies: []
EOF
cat >"$TMPDIR/CrashCore" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$TMPDIR/CrashCore"
pidof() { echo 123; }
curl() { printf 204; }
provider_dns_reload
assert_contains "$TMPDIR/config.yaml" '# BEGIN ShellCrash provider DNS hosts'
[ ! -e "$TMPDIR/config.provider_dns.bak" ] || fail 'hot reload backup was not cleaned up'

# A changed provider DoH replaces the managed policy on the next sync.
sed 's#resolver-c.example/token#resolver-new.example/token#' "$TMPDIR/providers/Inline.yaml" >"$TMPDIR/providers/Inline.yaml.new"
mv "$TMPDIR/providers/Inline.yaml.new" "$TMPDIR/providers/Inline.yaml"
provider_dns_sync
assert_contains "$CRASHDIR/configs/provider_dns/policy.yaml" 'https://resolver-new.example/token/dns-query'
provider_dns_apply_config "$SANDBOX/config.yaml"
[ "$(grep -c 'BEGIN ShellCrash provider DNS$' "$SANDBOX/config.yaml")" = 1 ] || fail 'managed DNS policy was duplicated'

# A failed refresh retains the last valid state for that provider.
provider_dns_resolve() { return 1; }
provider_dns_sync
assert_contains "$CRASHDIR/configs/provider_dns/hosts.yaml" "'edge-a.nodes.example': 192.0.2.10"

# A malformed provider cache also keeps the last valid state.
echo 'proxies: []' >"$TMPDIR/providers/Inline.yaml"
provider_dns_sync
assert_contains "$CRASHDIR/configs/provider_dns/hosts.yaml" "'gateway.nodes.example': 198.51.100.20"

# Removing a provider removes its records from the aggregate without touching its fallback state.
sed -n '2p' "$CRASHDIR/configs/providers.cfg" >"$CRASHDIR/configs/providers.cfg.new"
mv "$CRASHDIR/configs/providers.cfg.new" "$CRASHDIR/configs/providers.cfg"
provider_dns_sync
if grep -qF edge-a.nodes.example "$CRASHDIR/configs/provider_dns/hosts.yaml"; then
    fail 'removed provider remains in the aggregate'
fi
assert_contains "$CRASHDIR/configs/provider_dns/hosts.yaml" gateway.nodes.example

echo 'provider_dns_test: PASS'
