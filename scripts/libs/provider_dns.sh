#!/bin/sh
# Copyright (C) Juewuy

[ -n "${__IS_PROVIDER_DNS:-}" ] && return
__IS_PROVIDER_DNS=1

provider_dns_init() {
    [ -z "${TMPDIR:-}" ] && TMPDIR=/tmp/ShellCrash
    [ -z "${BINDIR:-}" ] && BINDIR="$TMPDIR"
    [ -z "${TASKCFGDIR:-}" ] && TASKCFGDIR="$CRASHDIR/configs/task"
    PROVIDER_DNS_DIR="$CRASHDIR/configs/provider_dns"
    PROVIDER_DNS_STATE_DIR="$PROVIDER_DNS_DIR/providers"
    PROVIDER_DNS_HOSTS="$PROVIDER_DNS_DIR/hosts.yaml"
    PROVIDER_DNS_POLICY="$PROVIDER_DNS_DIR/policy.yaml"
}

provider_dns_log() {
    command logger -t shellcrash-provider-dns "$*" 2>/dev/null || true
}

provider_dns_enable() {
    provider_dns_init
    mkdir -p "$TASKCFGDIR" || return 1
    task_file="$TASKCFGDIR/running"
    task_line="*/10 * * * * $CRASHDIR/task/task.sh sync_provider_dns ShellCrash-provider-dns"
    sed '/ShellCrash-provider-dns/d' "$task_file" 2>/dev/null >"$task_file.tmp" || true
    echo "$task_line" >>"$task_file.tmp"
    mv -f "$task_file.tmp" "$task_file"
}

provider_dns_extract_doh() {
    provider_file=$1
    awk '
        /^dns:[[:space:]]*/ { in_dns = 1 }
        in_dns && NR != 1 && /^[A-Za-z0-9_-]+:[[:space:]]*/ && $0 !~ /^dns:/ { exit }
        in_dns { print }
    ' "$provider_file" |
        grep -oE "https://[^][,}\"'[:space:]]+" 2>/dev/null |
        sed 's/[[:space:]]*$//' |
        awk '!seen[$0]++'
}

provider_dns_extract_proxy_doh() {
    provider_file=$1
    awk '
        function indentation(value) {
            match(value, /^[[:space:]]*/)
            return RLENGTH
        }

        /^[[:space:]]*proxy-server-nameserver:[[:space:]]*/ {
            capture = 1
            base_indent = indentation($0)
            print
            next
        }
        capture {
            current_indent = indentation($0)
            if ($0 ~ /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*/ && current_indent <= base_indent) exit
            print
        }
    ' "$provider_file" |
        grep -oE "https://[^][,}\"'[:space:]]+" 2>/dev/null |
        awk '!seen[$0]++'
}

provider_dns_extract_policy_doh() {
    provider_file=$1
    domain=$2
    awk -v domain="$domain" '
        function indentation(value) {
            match(value, /^[[:space:]]*/)
            return RLENGTH
        }

        function trim_key(value) {
            sub(/^[[:space:]"\047,{]+/, "", value)
            sub(/[[:space:]"\047:}]+$/, "", value)
            return value
        }

        function matches(key, name, suffix) {
            key = trim_key(key)
            if (key == name) return 1
            if (key ~ /^(\+\.|\*\.)/) {
                suffix = substr(key, 3)
                return name == suffix || (length(name) > length(suffix) && substr(name, length(name) - length(suffix), 1) == "." && substr(name, length(name) - length(suffix) + 1) == suffix)
            }
            return 0
        }

        /^[[:space:]]*nameserver-policy:[[:space:]]*/ {
            policy_indent = indentation($0)
            line = $0
            if (line ~ /\{/) {
                sub(/^[^{]*\{/, "", line)
                while (match(line, /:[[:space:]]*\[/)) {
                    key = substr(line, 1, RSTART - 1)
                    value = substr(line, RSTART)
                    end = index(value, "]")
                    if (!end) break
                    if (matches(key, domain)) print substr(value, 1, end)
                    line = substr(value, end + 1)
                }
                exit
            }
            in_policy = 1
            next
        }
        in_policy {
            current_indent = indentation($0)
            if ($0 ~ /^[[:space:]]*[A-Za-z0-9_-]+:[[:space:]]*/ && current_indent <= policy_indent) exit
            if ($0 ~ /^[[:space:]]*["\047+*A-Za-z0-9.-]+["\047]*:[[:space:]]*/) {
                key = $0
                sub(/:.*/, ":", key)
                capture = matches(key, domain)
            }
            if (capture) print
        }
    ' "$provider_file" |
        grep -oE "https://[^][,}\"'[:space:]]+" 2>/dev/null |
        awk '!seen[$0]++'
}

provider_dns_extract_doh_for_server() {
    provider_file=$1
    domain=$2
    urls=$(provider_dns_extract_policy_doh "$provider_file" "$domain")
    [ -n "$urls" ] || urls=$(provider_dns_extract_proxy_doh "$provider_file")
    [ -n "$urls" ] || urls=$(provider_dns_extract_doh "$provider_file")
    printf '%s\n' "$urls"
}

provider_dns_extract_servers() {
    provider_file=$1
    awk '
        function trim(value) {
            sub(/^[[:space:]"\047]+/, "", value)
            sub(/[[:space:]"\047,}#]+$/, "", value)
            return value
        }

        /^proxies:[[:space:]]*$/ { in_proxies = 1; next }
        in_proxies && /^[A-Za-z0-9_-]+:[[:space:]]*/ { exit }
        in_proxies {
            line = $0
            while (match(line, /(^|[, {])server:[[:space:]]*/)) {
                line = substr(line, RSTART + RLENGTH)
                if (substr(line, 1, 1) == "\"") {
                    line = substr(line, 2)
                    end = index(line, "\"")
                    value = end ? substr(line, 1, end - 1) : line
                } else if (substr(line, 1, 1) == "\047") {
                    line = substr(line, 2)
                    end = index(line, "\047")
                    value = end ? substr(line, 1, end - 1) : line
                } else {
                    value = line
                    sub(/[,}#[:space:]].*$/, "", value)
                }
                value = trim(value)
                if (value ~ /^[A-Za-z0-9][-A-Za-z0-9.]*[A-Za-z0-9]$/ && value ~ /\./ && value !~ /^[0-9.]+$/ && !seen[value]++) {
                    print value
                }
                if (!end) break
                line = substr(line, end + 1)
                end = 0
            }
        }
    ' "$provider_file"
}

provider_dns_make_query() {
    domain=$1
    output=$2
    {
        printf '\000\000\001\000\000\001\000\000\000\000\000\000'
        old_ifs=$IFS
        IFS=.
        set -- $domain
        IFS=$old_ifs
        for label in "$@"; do
            length=${#label}
            [ "$length" -le 63 ] || return 1
            octal=$(printf '%03o' "$length")
            printf "\\$octal%s" "$label"
        done
        printf '\000\000\001\000\001'
    } >"$output"
}

provider_dns_parse_a() {
    response=$1
    if command -v hexdump >/dev/null 2>&1; then
        hexdump -v -e '1/1 "%u "' "$response" 2>/dev/null
    else
        od -An -v -t u1 "$response" 2>/dev/null
    fi |
        awk '
            { for (i = 1; i <= NF; i++) bytes[++count] = $i }

            function u16(offset) {
                return bytes[offset] * 256 + bytes[offset + 1]
            }

            function skip_name(    label_len) {
                while (position <= count) {
                    label_len = bytes[position]
                    if (label_len == 0) {
                        position++
                        return
                    }
                    if (label_len >= 192) {
                        position += 2
                        return
                    }
                    position += label_len + 1
                }
            }

            END {
                if (count < 12 || bytes[4] % 16 != 0) exit 1
                questions = u16(5)
                answers = u16(7)
                position = 13

                for (i = 0; i < questions; i++) {
                    skip_name()
                    position += 4
                }

                for (i = 0; i < answers; i++) {
                    skip_name()
                    if (position + 9 > count) exit 1
                    type = u16(position)
                    rdlength = u16(position + 8)
                    position += 10
                    if (type == 1 && rdlength == 4 && position + 3 <= count) {
                        printf "%d.%d.%d.%d\n", bytes[position], bytes[position + 1], bytes[position + 2], bytes[position + 3]
                        exit 0
                    }
                    position += rdlength
                }
                exit 1
            }
        '
}

provider_dns_resolve() {
    domain=$1
    urls=$2
    query=$3/query.bin
    response=$3/response.bin

    provider_dns_make_query "$domain" "$query" || return 1
    encoded=$(base64 <"$query" 2>/dev/null | tr -d '\r\n=' | tr '+/' '-_')
    [ -n "$encoded" ] || return 1

    case $- in
    *f*) restore_glob= ;;
    *) set -f; restore_glob=1 ;;
    esac
    for base_url in $urls; do
        case "$base_url" in
        *\?*) request_url="${base_url}&dns=${encoded}" ;;
        *) request_url="${base_url}?dns=${encoded}" ;;
        esac
        if [ "${skip_cert:-}" != OFF ]; then
            insecure=-k
        else
            insecure=
        fi
        if curl $insecure -fsS --connect-timeout 5 --max-time 12 \
            -H 'accept: application/dns-message' "$request_url" >"$response" 2>/dev/null; then
            address=$(provider_dns_parse_a "$response" || true)
            if [ -n "$address" ]; then
                printf '%s\n' "$address"
                [ -n "$restore_glob" ] && set +f
                return 0
            fi
        fi
    done
    [ -n "$restore_glob" ] && set +f
    return 1
}

provider_dns_state_name() {
    safe_name=$(printf '%s' "$1" | sed 's/[^A-Za-z0-9_.-]/_/g')
    checksum=$(printf '%s' "$1" | cksum 2>/dev/null | awk '{print $1}')
    [ -n "$checksum" ] && printf '%s_%s' "$safe_name" "$checksum" || printf '%s' "$safe_name"
}

provider_dns_find_cache() {
    tag=$1
    for provider_file in \
        "$BINDIR/providers/$tag.yaml" \
        "$TMPDIR/providers/$tag.yaml" \
        "$CRASHDIR/providers/$tag.yaml"; do
        if [ -s "$provider_file" ]; then
            printf '%s\n' "$provider_file"
            return 0
        fi
    done
    return 1
}

provider_dns_build_provider() {
    tag=$1
    provider_file=$2
    state_name=$3
    work_dir=$4

    servers=$(provider_dns_extract_servers "$provider_file")
    [ -n "$servers" ] || return 1

    provider_hosts="$work_dir/$state_name.hosts"
    provider_policy="$work_dir/$state_name.policy"
    : >"$provider_hosts"
    : >"$provider_policy"

    for server in $servers; do
        urls=$(provider_dns_extract_doh_for_server "$provider_file" "$server")
        [ -n "$urls" ] || return 1
        address=$(provider_dns_resolve "$server" "$urls" "$work_dir" || true)
        if [ -z "$address" ]; then
            provider_dns_log "$tag: failed to resolve a proxy server; keeping the last valid state"
            return 1
        fi
        printf "  '%s': %s\n" "$server" "$address" >>"$provider_hosts"
        printf "    '%s':\n" "$server" >>"$provider_policy"
        printf '%s\n' "$urls" | awk '!seen[$0]++ { printf "      - \047%s\047\n", $0 }' >>"$provider_policy"
    done

    mv -f "$provider_hosts" "$PROVIDER_DNS_STATE_DIR/$state_name.hosts"
    mv -f "$provider_policy" "$PROVIDER_DNS_STATE_DIR/$state_name.policy"
    chmod 600 "$PROVIDER_DNS_STATE_DIR/$state_name.hosts" "$PROVIDER_DNS_STATE_DIR/$state_name.policy" 2>/dev/null || true
    return 0
}

provider_dns_install_aggregate() {
    source_file=$1
    target_file=$2
    if [ -f "$target_file" ] && cmp -s "$source_file" "$target_file"; then
        return 1
    fi
    mv -f "$source_file" "$target_file"
    chmod 600 "$target_file" 2>/dev/null || true
    return 0
}

provider_dns_sync() (
    provider_dns_init
    mkdir -p "$PROVIDER_DNS_STATE_DIR" "$TMPDIR" || return 1

    lock_dir="$TMPDIR/provider_dns.lock"
    if ! mkdir "$lock_dir" 2>/dev/null; then
        return 0
    fi
    work_dir="$TMPDIR/provider_dns.$$"
    trap 'rm -rf "$work_dir" "$lock_dir"' EXIT INT TERM
    mkdir -p "$work_dir" || return 1

    current_states="$work_dir/current_states"
    : >"$current_states"
    while IFS= read -r provider_line; do
        case "$provider_line" in
        '' | \#*) continue ;;
        esac
        tag=${provider_line%% *}
        [ -n "$tag" ] || continue
        case "$tag" in
        */* | *..*) continue ;;
        esac
        state_name=$(provider_dns_state_name "$tag")
        echo "$state_name" >>"$current_states"
        provider_file=$(provider_dns_find_cache "$tag" || true)
        if [ -n "$provider_file" ]; then
            provider_dns_build_provider "$tag" "$provider_file" "$state_name" "$work_dir" || true
        fi
    done <"$CRASHDIR/configs/providers.cfg" 2>/dev/null

    aggregate_hosts="$work_dir/hosts.yaml"
    aggregate_policy="$work_dir/policy.yaml"
    : >"$aggregate_hosts"
    : >"$aggregate_policy"
    while IFS= read -r state_name; do
        [ -s "$PROVIDER_DNS_STATE_DIR/$state_name.hosts" ] && cat "$PROVIDER_DNS_STATE_DIR/$state_name.hosts" >>"$aggregate_hosts"
        [ -s "$PROVIDER_DNS_STATE_DIR/$state_name.policy" ] && cat "$PROVIDER_DNS_STATE_DIR/$state_name.policy" >>"$aggregate_policy"
    done <"$current_states"
    awk '!seen[$1]++' "$aggregate_hosts" >"$aggregate_hosts.unique"
    awk '
        /^    .*:$/ {
            keep = !seen[$0]++
            if (keep) print
            next
        }
        keep { print }
    ' "$aggregate_policy" >"$aggregate_policy.unique"

    changed=0
    provider_dns_install_aggregate "$aggregate_hosts.unique" "$PROVIDER_DNS_HOSTS" && changed=1
    provider_dns_install_aggregate "$aggregate_policy.unique" "$PROVIDER_DNS_POLICY" && changed=1
    if [ "$changed" = 1 ] && [ "${PROVIDER_DNS_NO_RELOAD:-}" != 1 ]; then
        provider_dns_reload || return 1
        provider_dns_log 'provider DNS state updated'
    fi
    return 0
)

provider_dns_apply_config() (
    provider_dns_init
    config_file=$1
    [ -f "$config_file" ] || return 1
    policy_file=$PROVIDER_DNS_POLICY
    hosts_file=$PROVIDER_DNS_HOSTS
    candidate="$config_file.provider_dns"

    awk -v policy_file="$policy_file" '
        function emit_policy(    line) {
            print "    # BEGIN ShellCrash provider DNS"
            while ((getline line < policy_file) > 0) print line
            close(policy_file)
            print "    # END ShellCrash provider DNS"
            policy_emitted = 1
        }

        /^    # BEGIN ShellCrash provider DNS$/ { managed = 1; next }
        /^    # END ShellCrash provider DNS$/ { managed = 0; next }
        /^  # BEGIN provider DNS sync$/ { managed = 1; next }
        /^  # END provider DNS sync$/ { managed = 0; next }
        managed { next }

        /^dns:[[:space:]]*$/ { in_dns = 1 }
        in_dns && /^  nameserver-policy:[[:space:]]*$/ {
            print
            emit_policy()
            next
        }
        in_dns && /^  nameserver-policy:[[:space:]]*[^[:space:]]/ { inline_policy = 1 }
        in_dns && /^[A-Za-z0-9_-]+:[[:space:]]*/ && $0 !~ /^dns:/ {
            if (!policy_emitted && !inline_policy && (getline probe < policy_file) > 0) {
                close(policy_file)
                print "  nameserver-policy:"
                emit_policy()
            } else {
                close(policy_file)
            }
            in_dns = 0
        }
        { print }

        END {
            if (in_dns && !policy_emitted && !inline_policy && (getline probe < policy_file) > 0) {
                close(policy_file)
                print "  nameserver-policy:"
                emit_policy()
            }
        }
    ' "$config_file" >"$candidate" || return 1

    awk -v hosts_file="$hosts_file" '
        function emit_hosts(    line) {
            print "  # BEGIN ShellCrash provider DNS hosts"
            while ((getline line < hosts_file) > 0) print line
            close(hosts_file)
            print "  # END ShellCrash provider DNS hosts"
            hosts_emitted = 1
        }

        /^  # BEGIN ShellCrash provider DNS hosts$/ { managed = 1; next }
        /^  # END ShellCrash provider DNS hosts$/ { managed = 0; next }
        /^  # BEGIN provider DNS hosts sync$/ { managed = 1; next }
        /^  # END provider DNS hosts sync$/ { managed = 0; next }
        managed { next }

        /^hosts:[[:space:]]*$/ {
            print
            emit_hosts()
            next
        }
        /^hosts:[[:space:]]*[^[:space:]]/ { inline_hosts = 1 }
        !hosts_emitted && !inline_hosts && /^proxies:[[:space:]]*/ {
            if ((getline probe < hosts_file) > 0) {
                close(hosts_file)
                print "hosts:"
                emit_hosts()
            } else {
                close(hosts_file)
            }
        }
        { print }

        END {
            if (!hosts_emitted && !inline_hosts && (getline probe < hosts_file) > 0) {
                close(hosts_file)
                print "hosts:"
                emit_hosts()
            }
        }
    ' "$candidate" >"$candidate.hosts" || return 1
    mv -f "$candidate.hosts" "$config_file"
    rm -f "$candidate"
)

provider_dns_reload() {
    provider_dns_init
    runtime_config="$TMPDIR/config.yaml"
    pid=$(pidof CrashCore 2>/dev/null | awk '{print $1}')
    core_bin="$TMPDIR/CrashCore"
    [ -x "$core_bin" ] || core_bin="/proc/$pid/exe"
    [ -s "$runtime_config" ] && [ -n "$pid" ] && [ -x "$core_bin" ] || return 0

    candidate="$TMPDIR/config.provider_dns.yaml"
    cp -f "$runtime_config" "$candidate" || return 1
    provider_dns_apply_config "$candidate" || return 1
    cmp -s "$runtime_config" "$candidate" && {
        rm -f "$candidate"
        return 0
    }
    "$core_bin" -t -d "$BINDIR" -f "$candidate" >/dev/null 2>&1 || {
        rm -f "$candidate"
        provider_dns_log 'generated configuration failed validation'
        return 1
    }

    backup="$TMPDIR/config.provider_dns.bak"
    cp -f "$runtime_config" "$backup" || return 1
    mv -f "$candidate" "$runtime_config" || return 1
    secret=$(sed -n 's/^secret:[[:space:]]*//p' "$runtime_config" | head -n 1 | tr -d "'\"")
    [ -z "${db_port:-}" ] && db_port=9999
    http_code=$(curl -fsS --max-time 15 -o /dev/null -w '%{http_code}' \
        -X PUT -H "Authorization: Bearer $secret" -H 'Content-Type: application/json' \
        --data "{\"path\":\"$runtime_config\"}" \
        "http://127.0.0.1:$db_port/configs?force=true" 2>/dev/null || true)
    if [ "$http_code" != 204 ]; then
        mv -f "$backup" "$runtime_config"
        curl -fsS --max-time 15 -o /dev/null -X PUT \
            -H "Authorization: Bearer $secret" -H 'Content-Type: application/json' \
            --data "{\"path\":\"$runtime_config\"}" \
            "http://127.0.0.1:$db_port/configs?force=true" 2>/dev/null || true
        provider_dns_log 'hot reload failed; restored the previous configuration'
        return 1
    fi
    rm -f "$backup"
}
