
ck_cn_ipv4() { #CN-IP绕过
    check_geo cn_ip.txt china_ip_list.txt
    [ -f "$BINDIR"/cn_ip.txt ] && [ "$firewall_mod" = iptables ] && {
        # see https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/CN-ip-cidr.txt
        echo "create cn_ip hash:net family inet hashsize 10240 maxelem 10240" >"$TMPDIR"/cn_ip.ipset
        awk '!/^$/&&!/^#/{printf("add cn_ip %s'" "'\n",$0)}' "$BINDIR"/cn_ip.txt >>"$TMPDIR"/cn_ip.ipset
        ipset destroy cn_ip >/dev/null 2>&1
        ipset -! restore <"$TMPDIR"/cn_ip.ipset
        rm -rf "$TMPDIR"/cn_ip.ipset
    }
}
ck_cn_ipv6() { #CN-IPV6绕过
    check_geo cn_ipv6.txt china_ipv6_list.txt
    [ -f "$BINDIR"/cn_ipv6.txt ] && [ "$firewall_mod" = iptables ] && {
        #ipv6
        #see https://ispip.clang.cn/all_cn_ipv6.txt
        echo "create cn_ip6 hash:net family inet6 hashsize 5120 maxelem 5120" >"$TMPDIR"/cn_ipv6.ipset
        awk '!/^$/&&!/^#/{printf("add cn_ip6 %s'" "'\n",$0)}' "$BINDIR"/cn_ipv6.txt >>"$TMPDIR"/cn_ipv6.ipset
        ipset destroy cn_ip6 >/dev/null 2>&1
        ipset -! restore <"$TMPDIR"/cn_ipv6.ipset
        rm -rf "$TMPDIR"/cn_ipv6.ipset
    }
}