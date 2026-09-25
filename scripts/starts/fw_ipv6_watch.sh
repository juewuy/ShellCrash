#!/bin/sh
# Keep the nftables LAN IPv6 prefix set in sync with dynamic prefixes.

[ -z "$CRASHDIR" ] && CRASHDIR=$(
    cd "$(dirname "$0")"
    cd ..
    pwd
)
. "$CRASHDIR"/libs/get_config.sh
. "$CRASHDIR"/starts/fw_getlanip.sh

[ -z "$TMPDIR" ] && TMPDIR=/tmp/ShellCrash
ipv6_watch_pid="$TMPDIR/ipv6_watch.pid"
ipv6_watch_fifo="$TMPDIR/ipv6_route_monitor.$$"
ipv6_nft_family=${SHELLCRASH_NFT_FAMILY:-inet}
ipv6_nft_table=${SHELLCRASH_NFT_TABLE:-shellcrash}
ipv6_nft_set=${SHELLCRASH_IPV6_SET:-lan_ip6}

stop_ipv6_watch() {
    [ -s "$ipv6_watch_pid" ] || return 0
    ipv6_watch_old_pid=$(cat "$ipv6_watch_pid" 2>/dev/null)
    case "$ipv6_watch_old_pid" in
    '' | *[!0-9]*) ;;
    *)
        if [ ! -r "/proc/$ipv6_watch_old_pid/cmdline" ] ||
            tr '\0' ' ' <"/proc/$ipv6_watch_old_pid/cmdline" 2>/dev/null | grep -q 'fw_ipv6_watch.sh'; then
            kill "$ipv6_watch_old_pid" 2>/dev/null
        fi
        ;;
    esac
    rm -f "$ipv6_watch_pid"
}

cleanup_ipv6_watch() {
    trap - EXIT INT TERM
    [ -n "$ipv6_monitor_pid" ] && kill "$ipv6_monitor_pid" 2>/dev/null
    [ -p "$ipv6_watch_fifo" ] && rm -f "$ipv6_watch_fifo"
    if [ "$(cat "$ipv6_watch_pid" 2>/dev/null)" = "$$" ]; then
        rm -f "$ipv6_watch_pid"
    fi
    exit 0
}

update_ipv6_set() {
    lan_ifaces=$(get_lan_ifaces)
    detected_host_ipv6=$(get_ipv6_prefixes)
    build_host_ipv6 "$detected_host_ipv6"
    ipv6_watch_state="$host_ipv6"

    if [ "$ipv6_watch_state" = "$ipv6_watch_last_state" ] &&
        nft list set "$ipv6_nft_family" "$ipv6_nft_table" "$ipv6_nft_set" >/dev/null 2>&1; then
        return 0
    fi

    ipv6_watch_elements=$(echo "$host_ipv6" | sed 's/[[:space:]]\+/, /g')
    [ -n "$ipv6_watch_elements" ] || return 1
    nft list set "$ipv6_nft_family" "$ipv6_nft_table" "$ipv6_nft_set" >/dev/null 2>&1 || return 1

    # nft processes a batch atomically, so packets never observe a partially
    # updated set while an ISP prefix is being replaced.
    printf 'flush set %s %s %s\nadd element %s %s %s { %s }\n' \
        "$ipv6_nft_family" "$ipv6_nft_table" "$ipv6_nft_set" \
        "$ipv6_nft_family" "$ipv6_nft_table" "$ipv6_nft_set" "$ipv6_watch_elements" |
        nft -f - >/dev/null 2>&1 || return 1
    ipv6_watch_last_state="$ipv6_watch_state"
}

run_iproute2_monitor() {
    rm -f "$ipv6_watch_fifo"
    mkfifo "$ipv6_watch_fifo" 2>/dev/null || return 1
    ip -6 monitor route >"$ipv6_watch_fifo" 2>/dev/null &
    ipv6_monitor_pid=$!
    while IFS= read -r _ipv6_route_event; do
        # Coalesce delete/add notifications emitted during renumbering.
        sleep 1
        update_ipv6_set
    done <"$ipv6_watch_fifo"
    wait "$ipv6_monitor_pid" 2>/dev/null
    ipv6_monitor_pid=
    rm -f "$ipv6_watch_fifo"
    return 1
}

run_ipv6_watch() {
    mkdir -p "$TMPDIR"
    echo $$ >"$ipv6_watch_pid"
    trap cleanup_ipv6_watch EXIT INT TERM
    ipv6_watch_last_state=
    update_ipv6_set

    # Full iproute2 has event monitoring. BusyBox/router variants that do not
    # support it use a small polling fallback instead.
    if ip -Version 2>&1 | grep -qi 'iproute2'; then
        run_iproute2_monitor
    fi
    while :; do
        sleep 30
        update_ipv6_set
    done
}

case "$1" in
start)
    mkdir -p "$TMPDIR"
    stop_ipv6_watch
    /bin/sh "$0" run >/dev/null 2>&1 &
    echo $! >"$ipv6_watch_pid"
    ;;
stop)
    stop_ipv6_watch
    ;;
run)
    run_ipv6_watch
    ;;
once)
    ipv6_watch_last_state=
    update_ipv6_set
    ;;
*)
    echo "Usage: $0 {start|stop|run|once}" >&2
    exit 1
    ;;
esac
