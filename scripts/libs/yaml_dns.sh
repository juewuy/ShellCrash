#!/bin/sh
# Copyright (C) Juewuy

# Extract the top-level dns section without requiring a YAML parser. The
# merger below normalizes block and one-line flow mappings before overlaying
# fields, so the final configuration contains only one dns key.

yaml_dns_extract() {
    awk '
    function top_level(line) {
        return line !~ /^[[:space:]#]/ && line ~ /^[^:]+:/
    }
    function brace_delta(line, i, c, quote, escaped, delta) {
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (quote) {
                if (quote == "\042" && escaped) escaped = 0
                else if (quote == "\042" && c == "\\") escaped = 1
                else if (c == quote) quote = 0
            } else if (c == "\047" || c == "\042") quote = c
            else if (c == "{") delta++
            else if (c == "}") delta--
        }
        return delta
    }
    {
        if (!found) {
            if ($0 ~ /^dns:[[:space:]]*\{/) {
                print
                flow = 1
                balance = brace_delta($0)
                if (balance <= 0) exit
                found = 1
                next
            }
            if ($0 ~ /^dns:[[:space:]]*($|#)/) {
                print
                found = 1
            }
            next
        }
        if (flow) {
            print
            balance += brace_delta($0)
            if (balance <= 0) exit
            next
        }
        if (top_level($0)) exit
        print
    }' "$1"
}

yaml_dns_without() {
    awk '
    function top_level(line) {
        return line !~ /^[[:space:]#]/ && line ~ /^[^:]+:/
    }
    function brace_delta(line, i, c, quote, escaped, delta) {
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (quote) {
                if (quote == "\042" && escaped) escaped = 0
                else if (quote == "\042" && c == "\\") escaped = 1
                else if (c == quote) quote = 0
            } else if (c == "\047" || c == "\042") quote = c
            else if (c == "{") delta++
            else if (c == "}") delta--
        }
        return delta
    }
    {
        if (!in_dns) {
            if ($0 ~ /^dns:[[:space:]]*\{/) {
                in_dns = 1
                flow = 1
                balance = brace_delta($0)
                if (balance <= 0) in_dns = 0
                next
            }
            if ($0 ~ /^dns:[[:space:]]*($|#)/) {
                in_dns = 1
                next
            }
            print
            next
        }
        if (flow) {
            balance += brace_delta($0)
            if (balance <= 0) in_dns = 0
            next
        }
        if (top_level($0)) {
            in_dns = 0
            print
            next
        }
    }' "$1"
}

yaml_top_level_section() {
    awk -v section="$2" '
    function top_level(line) {
        return line !~ /^[[:space:]#]/ && line ~ /^[^:]+:/
    }
    {
        if (!started && $0 ~ section) started = 1
        if (started && top_level($0) && $0 !~ section) exit
        if (started) print
    }' "$1"
}

yaml_dns_merge() {
    awk -v original="${1:-/dev/null}" \
        -v managed="${2:-/dev/null}" \
        -v user="${3:-/dev/null}" '
    function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        return value
    }
    function brace_delta(line, i, c, quote, escaped, delta) {
        for (i = 1; i <= length(line); i++) {
            c = substr(line, i, 1)
            if (quote) {
                if (quote == "\042" && escaped) escaped = 0
                else if (quote == "\042" && c == "\\") escaped = 1
                else if (c == quote) quote = 0
            } else if (c == "\047" || c == "\042") quote = c
            else if (c == "{") delta++
            else if (c == "}") delta--
        }
        return delta
    }
    function add_entry(source, key, value) {
        if (!(source SUBSEP key in entry)) {
            order[source, ++count[source]] = key
        }
        entry[source, key] = value
    }
    function append_entry(source, key, line) {
        if (entry[source, key] == "") entry[source, key] = line
        else entry[source, key] = entry[source, key] "\n" line
    }
    function flow_pair(source, pair, i, c, depth_brace, depth_square, quote, escaped, colon, key, value) {
        pair = trim(pair)
        colon = 0
        depth_brace = depth_square = 0
        quote = escaped = 0
        for (i = 1; i <= length(pair); i++) {
            c = substr(pair, i, 1)
            if (quote) {
                if (quote == "\042" && escaped) escaped = 0
                else if (quote == "\042" && c == "\\") escaped = 1
                else if (c == quote) quote = 0
                continue
            }
            if (c == "\047") quote = "\047"
            else if (c == "\042") quote = "\042"
            else if (c == "{") depth_brace++
            else if (c == "}") depth_brace--
            else if (c == "[") depth_square++
            else if (c == "]") depth_square--
            else if (c == ":" && depth_brace == 0 && depth_square == 0) {
                colon = i
                break
            }
        }
        if (!colon) return
        key = trim(substr(pair, 1, colon - 1))
        value = trim(substr(pair, colon + 1))
        if ((substr(key, 1, 1) == "\047" && substr(key, length(key), 1) == "\047") ||
            (substr(key, 1, 1) == "\042" && substr(key, length(key), 1) == "\042"))
            key = substr(key, 2, length(key) - 2)
        add_entry(source, key, "  " key ": " value)
    }
    function parse_flow(source, text, i, c, depth_brace, depth_square, quote, escaped, start) {
        text = trim(text)
        if (substr(text, 1, 1) == "{") text = substr(text, 2)
        if (substr(text, length(text), 1) == "}") text = substr(text, 1, length(text) - 1)
        start = 1
        depth_brace = depth_square = 0
        quote = escaped = 0
        for (i = 1; i <= length(text); i++) {
            c = substr(text, i, 1)
            if (quote) {
                if (quote == "\042" && escaped) escaped = 0
                else if (quote == "\042" && c == "\\") escaped = 1
                else if (c == quote) quote = 0
                continue
            }
            if (c == "\047") quote = "\047"
            else if (c == "\042") quote = "\042"
            else if (c == "{") depth_brace++
            else if (c == "}") depth_brace--
            else if (c == "[") depth_square++
            else if (c == "]") depth_square--
            else if (c == "," && depth_brace == 0 && depth_square == 0) {
                flow_pair(source, substr(text, start, i - start))
                start = i + 1
            }
        }
        flow_pair(source, substr(text, start))
    }
    function parse_file(file, source, line, rest, key, value) {
        started = flow = balance = 0
        current = ""
        flow_text = ""
        while ((getline line < file) > 0) {
            if (!started) {
                if (line ~ /^dns:[[:space:]]*\{/) {
                    rest = line
                    sub(/^dns:[[:space:]]*/, "", rest)
                    flow_text = rest
                    flow = 1
                    balance = brace_delta(line)
                    started = 1
                    if (balance <= 0) {
                        parse_flow(source, flow_text)
                        started = flow = 0
                    }
                } else if (line ~ /^dns:[[:space:]]*($|#)/) {
                    started = 1
                }
                continue
            }
            if (flow) {
                flow_text = flow_text " " trim(line)
                balance += brace_delta(line)
                if (balance <= 0) {
                    parse_flow(source, flow_text)
                    started = flow = 0
                }
                continue
            }
            if (line ~ /^[[:space:]][[:space:]][A-Za-z0-9_-]+[[:space:]]*:/) {
                if (current != "") add_entry(source, key, value)
                key = line
                sub(/^[[:space:]]+/, "", key)
                sub(/[[:space:]]*:.*/, "", key)
                value = line
                current = key
            } else if (current != "") {
                value = value "\n" line
            }
        }
        if (current != "") add_entry(source, key, value)
        close(file)
    }
    function managed_key(key) {
        return key == "enable" || key == "listen" || key == "use-hosts" ||
            key == "ipv6" || key == "default-nameserver" || key == "direct-nameserver" ||
            key == "enhanced-mode" || key == "fake-ip-range" || key == "fake-ip-range6" ||
            key == "fake-ip-filter" || key == "respect-rules" ||
            key == "proxy-server-nameserver" || key == "nameserver"
    }
    BEGIN {
        parse_file(original, "original")
        parse_file(managed, "managed")
        parse_file(user, "user")
        print "dns:"
        for (i = 1; i <= count["original"]; i++) {
            key = order["original", i]
            # nameserver-policy is intentionally passthrough: ShellCrash
            # generated policy must not replace subscription-specific routes.
            if (!managed_key(key) && !("user" SUBSEP key in entry))
                print entry["original", key]
        }
        for (i = 1; i <= count["managed"]; i++) {
            key = order["managed", i]
            if (!("user" SUBSEP key in entry) &&
                !(key == "nameserver-policy" && ("original" SUBSEP key in entry)))
                print entry["managed", key]
        }
        for (i = 1; i <= count["user"]; i++) {
            key = order["user", i]
            print entry["user", key]
        }
    }'
}

case "${1:-}" in
extract)
    yaml_dns_extract "$2"
    ;;
without)
    yaml_dns_without "$2"
    ;;
merge)
    yaml_dns_merge "$2" "$3" "$4"
    ;;
esac
