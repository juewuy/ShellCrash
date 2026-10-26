#!/bin/sh
set -e

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CRASHDIR="$ROOT/scripts"
. "$CRASHDIR/libs/web_get.sh"
. "$CRASHDIR/libs/web_get_lite.sh"

pidof() {
    [ "$1" = CrashCore ] && printf '12345\n'
}

ckcmd() {
    [ "$backend" = basic_wget ] && [ "$1" = wget ]
}

wget() {
    if [ "$1" = --help ]; then
        [ "$backend" != gnu_wget ] || printf '%s\n' '--show-progress'
        return 0
    fi
    if [ "${operation:-webget}" = lite ]; then
        [ "$scenario" = success ] && return 0
        return 8
    fi
    case "$scenario" in
        success) return 0 ;;
        retry) [ "$2" = off ] ;;
        failure) return 8 ;;
    esac
}

curl() {
    if [ "$1" = --version ]; then
        [ "$backend" = curl ] || return 1
        printf '%s\n' 'curl 7.88.1'
        return 0
    fi
    if [ "${operation:-webget}" = lite ]; then
        [ "$scenario" = success ] && return 0
        return 7
    fi
    case "$scenario" in
        success) printf 200 ;;
        retry)
            if [ -z "$http_proxy" ]; then
                printf 200
            else
                printf 503
            fi
            ;;
        failure) printf 503 ;;
    esac
}

proxy_state() {
    printf '%s\n' "${http_proxy+x}:${http_proxy-}" "${https_proxy+x}:${https_proxy-}"
}

failures=0
for backend in curl gnu_wget basic_wget; do
    for scenario in success retry failure; do
        for initial in unset exported; do
            if (
                authentication=
                mix_port=7890
                if [ "$initial" = unset ]; then
                    unset http_proxy https_proxy
                else
                    export http_proxy='http://caller.invalid:8080'
                    export https_proxy='http://caller.invalid:8443'
                fi
                before=$(proxy_state)
                if webget /dev/null http://example.invalid/core echooff; then
                    actual_rc=0
                else
                    actual_rc=$?
                fi
                expected_rc=0
                if [ "$scenario" = failure ]; then
                    if [ "$backend" = curl ]; then
                        expected_rc=1
                    else
                        expected_rc=8
                    fi
                fi
                if [ "$actual_rc" != "$expected_rc" ]; then
                    printf 'FAIL %s/%s/%s: expected rc=%s, got rc=%s\n' \
                        "$backend" "$scenario" "$initial" "$expected_rc" "$actual_rc" >&2
                    exit 1
                fi
                if [ "$(proxy_state)" != "$before" ]; then
                    printf 'FAIL %s/%s/%s: caller proxy environment changed\n' \
                        "$backend" "$scenario" "$initial" >&2
                    exit 1
                fi
            ); then
                printf 'PASS %s/%s/%s\n' "$backend" "$scenario" "$initial"
            else
                failures=$((failures + 1))
            fi
        done
    done
done

operation=lite
for backend in curl gnu_wget; do
    for scenario in success failure; do
        for initial in unset exported; do
            for proxy_mode in enabled disabled; do
                if (
                    authentication=
                    mix_port=7890
                    if [ "$initial" = unset ]; then
                        unset http_proxy https_proxy
                    else
                        export http_proxy='http://caller.invalid:8080'
                        export https_proxy='http://caller.invalid:8443'
                    fi
                    before=$(proxy_state)
                    set -- http://example.invalid/ip
                    [ "$proxy_mode" != disabled ] || set -- "$@" 0
                    if web_get_lite "$@" >/dev/null; then
                        actual_rc=0
                    else
                        actual_rc=$?
                    fi
                    expected_rc=0
                    if [ "$scenario" = failure ]; then
                        if [ "$backend" = curl ]; then
                            expected_rc=7
                        else
                            expected_rc=8
                        fi
                    fi
                    if [ "$actual_rc" != "$expected_rc" ]; then
                        printf 'FAIL lite/%s/%s/%s/%s: expected rc=%s, got rc=%s\n' \
                            "$backend" "$scenario" "$initial" "$proxy_mode" "$expected_rc" "$actual_rc" >&2
                        exit 1
                    fi
                    if [ "$(proxy_state)" != "$before" ]; then
                        printf 'FAIL lite/%s/%s/%s/%s: caller proxy environment changed\n' \
                            "$backend" "$scenario" "$initial" "$proxy_mode" >&2
                        exit 1
                    fi
                ); then
                    printf 'PASS lite/%s/%s/%s/%s\n' "$backend" "$scenario" "$initial" "$proxy_mode"
                else
                    failures=$((failures + 1))
                fi
            done
        done
    done
done

[ "$failures" -eq 0 ] || exit 1
printf 'webget proxy scope tests passed\n'
