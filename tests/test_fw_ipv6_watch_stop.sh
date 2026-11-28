#!/bin/sh
# Regression tests for stopping the IPv6 prefix watcher.
#
# The watcher sleeps between polls. A foreground sleep is not interrupted by a
# signal: the shell only runs the trap once the command returns, so a stop
# request waited out the whole interval. Because stop also dropped the PID file
# immediately, the next start could spawn a replacement next to the still-live
# watcher and the orphan kept rewriting the nftables set for the rest of the
# uptime.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WATCHER="$ROOT/scripts/starts/fw_ipv6_watch.sh"

grep -Fq 'ipv6_watch_stop_wait' "$WATCHER"
grep -Fq 'sleep 30 &' "$WATCHER"
grep -Fq 'wait "$ipv6_watch_sleep_pid"' "$WATCHER"
if grep -Fq '^        sleep 30$' "$WATCHER"; then
    echo 'the poll loop still sleeps in the foreground' >&2
    exit 1
fi

if [ "${1:-}" = check-term ]; then
    state_file=$2
    # Report only the final state so the caller can assert on the exit timing.
    trap 'printf "term:%s\n" "$(date +%s)" >"$state_file"; exit 0' TERM
    while :; do
        sleep 30 &
        sleep_pid=$!
        wait "$sleep_pid"
        sleep_pid=
    done
fi

if command -v busybox >/dev/null 2>&1 && [ -d /proc/self/fd ]; then
    state_file=$(mktemp)
    trap 'rm -f "$state_file"' EXIT INT TERM

    # The interruptible loop must honour TERM in about a second instead of
    # waiting out the whole poll interval.
    TEST_SCRIPT="$ROOT/tests/test_fw_ipv6_watch_stop.sh"
    export TEST_SCRIPT
    start=$(date +%s)
    busybox ash -c '"$TEST_SCRIPT" check-term "$1" & child=$!; sleep 2; kill -TERM "$child" 2>/dev/null; wait "$child" 2>/dev/null || true' ash "$state_file"
    elapsed=$(($(date +%s) - start))
    if [ "$elapsed" -ge 10 ]; then
        echo "TERM was not handled promptly (${elapsed}s)" >&2
        exit 1
    fi
fi

echo 'ipv6 watcher stop tests passed'
