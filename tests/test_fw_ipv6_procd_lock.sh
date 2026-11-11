#!/bin/sh
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
WATCHER="$ROOT/scripts/starts/fw_ipv6_watch.sh"
PROCD="$ROOT/scripts/starts/shellcrash.procd"

if [ "${1:-}" = check-fd ]; then
    test ! -e "/proc/$$/fd/1000"
    exit
fi

grep -Fq '[ -e "/proc/$$/fd/1000" ] && eval "exec 1000>&-"' "$WATCHER"
grep -Fq '"$CRASHDIR"/starts/afstart.sh 1000>&- &' "$PROCD"

if command -v busybox >/dev/null 2>&1 && [ -d /proc/self/fd ]; then
    lock_file=$(mktemp)
    trap 'rm -f "$lock_file"' EXIT INT TERM

    # Verify the watcher-side fallback closes an inherited procd descriptor.
    busybox ash -c '
        exec 1000>"$1"
        test -e /proc/$$/fd/1000
        eval "exec 1000>&-"
        test ! -e /proc/$$/fd/1000
    ' ash "$lock_file"

    # Verify the procd launch redirection prevents child inheritance.
    TEST_SCRIPT="$ROOT/tests/test_fw_ipv6_procd_lock.sh"
    export TEST_SCRIPT
    busybox ash -c '
        exec 1000>"$1"
        "$TEST_SCRIPT" check-fd 1000>&- &
        child=$!
        wait "$child"
    ' ash "$lock_file"
fi

echo 'procd lock inheritance tests passed'
