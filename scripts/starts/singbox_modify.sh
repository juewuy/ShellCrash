#!/bin/sh
# Copyright (C) Juewuy

 #修饰singbox配置文件
parse_singbox_dns() { #dns转换
    first_dns=$(echo "$1" | cut -d',' -f1 | cut -d' ' -f1)
    type=""
    server=""
    port=""
    case "$first_dns" in
        *://*)
            type="${first_dns%%://*}"
            tmp="${first_dns#*://}"
            ;;
        *)
            type="udp"
            tmp="$first_dns"
            ;;
    esac
    case "$tmp" in
        \[*\]*)
            server="${tmp%%]*}"
            server="${server#[}"
            port="${tmp#*\]}"
            port="${port#:}"
            ;;
        *)
            server="${tmp%%[:/]*}"
            port="${tmp#*:}"
            [ "$port" = "$tmp" ] && port=""
            ;;
    esac
    if [ -z "$port" ]; then
        case "$type" in
            udp|tcp) port=53 ;;
            doh|https) port=443 ;;
            dot|tls) port=853 ;;
            *) port=53 ;;
        esac
    fi
    # 输出
	echo '"type": "'"$type"'", "server": "'"$server"'", "server_port": '"$port"','
}
modify_json() {
    #提取配置文件以获得outbounds.json,providers.json及route.json
    "$TMPDIR"/CrashCore format -c $core_config >"$TMPDIR"/format.json
    echo '{' >"$TMPDIR"/jsons/outbounds.json
    echo '{' >"$TMPDIR"/jsons/route.json
    cat "$TMPDIR"/format.json | sed -n '/"outbounds":/,/^  "[a-z]/p' | sed '$d' >>"$TMPDIR"/jsons/outbounds.json
    [ "$crashcore" = "singboxr" ] && {
        echo '{' >"$TMPDIR"/jsons/providers.json
        cat "$TMPDIR"/format.json | sed -n '/^  "providers":/,/^  "[a-z]/p' | sed '$d' >>"$TMPDIR"/jsons/providers.json
    }
    cat "$TMPDIR"/format.json | sed -n '/"route":/,/^\(  "[a-z]\|}\)/p' | sed '$d' >>"$TMPDIR"/jsons/route.json
    #生成endpoints.json
	[ "$ts_service" = ON ] || [ "$wg_service" = ON ] && [ "$zip_type" != upx ] && {
		. "$CRASHDIR"/configs/gateway.cfg
		. "$CRASHDIR"/libs/sb_endpoints.sh
	}
	#生成log.json
    cat >"$TMPDIR"/jsons/log.json <<EOF
{ "log": { "level": "info", "timestamp": true } }
EOF
    #生成add_hosts.json
    if [ "$hosts_opt" != "OFF" ]; then #本机hosts
        [ -s /data/etc/custom_hosts ] && custom_hosts='"/data/etc/custom_hosts",'
        #NTP劫持
        cat >"$TMPDIR"/jsons/add_hosts.json <<EOF
{
  "dns": {
    "servers": [
      {
        "type": "hosts",
        "tag": "hosts",
        "path": [
          $custom_hosts
          "$HOME/.hosts",
		  "/etc/hosts"
        ],
        "predefined": {
          "localhost": [
            "127.0.0.1",
            "::1"
          ],
          "time.android.com": "203.107.6.88",
          "time.facebook.com": "203.107.6.88"
        }
      }
	],
    "rules": [
      {
        "ip_accept_any": true,
        "server": "hosts"
      }
	]}
}
EOF
    fi
    #生成dns.json
    [ "$ipv6_dns" != "OFF" ] && strategy='prefer_ipv4' || strategy='ipv4_only'
    #获取detour出口
	auto_detour=$(grep -E '"type": "urltest"' -A 1 "$TMPDIR"/jsons/outbounds.json | grep '自动' | head -n 1 | sed 's/^[[:space:]]*"tag": //;s/,$//')
    [ -z "$auto_detour" ] && auto_detour=$(grep -E '"type": "urltest"' -A 1 "$TMPDIR"/jsons/outbounds.json | grep '"tag":' | head -n 1 | sed 's/^[[:space:]]*"tag": //;s/,$//')
    [ -z "$auto_detour" ] && auto_detour=$(grep -E '"type": "selector"' -A 1 "$TMPDIR"/jsons/outbounds.json | grep '"tag":' | head -n 1 | sed 's/^[[:space:]]*"tag": //;s/,$//')
    [ -z "$auto_detour" ] && auto_detour='"DIRECT"'
	#ecs优化
	[ "$ecs_subnet" = ON ] && {
		. "$CRASHDIR"/libs/get_ecsip.sh
		client_subnet='"client_subnet": "'"$ecs_address"'",'
	}
    #根据dns模式生成
    [ "$dns_mod" = "redir_host" ] && {
        global_dns=dns_proxy
        direct_dns='{ "inbound": [ "dns-in" ], "server": "dns_direct" }'
    }
    [ "$dns_mod" = "fake-ip" ] || [ "$dns_mod" = "mix" ] && {
        global_dns=dns_fakeip
        fake_ip_filter_domain=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep -Ev '#|\*|\+|Mijia' | sed '/^\s*$/d' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
        fake_ip_filter_suffix=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep -v '.\*' | grep -E '\*|\+' | sed 's/^[*+]\.//' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
        fake_ip_filter_regex=$(cat ${CRASHDIR}/configs/fake_ip_filter ${CRASHDIR}/configs/fake_ip_filter.list 2>/dev/null | grep '.\*' | sed 's/\./\\\\./g' | sed 's/\*/.\*/' | sed 's/^+/.\+/' | awk '{printf "\"%s\", ",$1}' | sed 's/, $//')
        [ -n "$fake_ip_filter_domain" ] && fake_ip_filter_domain="{ \"domain\": [$fake_ip_filter_domain], \"server\": \"dns_direct\" },"
        [ -n "$fake_ip_filter_suffix" ] && fake_ip_filter_suffix="{ \"domain_suffix\": [$fake_ip_filter_suffix], \"server\": \"dns_direct\" },"
        [ -n "$fake_ip_filter_regex" ] && fake_ip_filter_regex="{ \"domain_regex\": [$fake_ip_filter_regex], \"server\": \"dns_direct\" },"
        proxy_dns='{ "query_type": ["A", "AAAA"], "server": "dns_fakeip", "strategy": "'"$strategy"'", "rewrite_ttl": 1 }'
        #mix模式插入fakeip过滤规则
        [ "$dns_mod" = "mix" ] && direct_dns='{ "rule_set": ["cn"], "server": "dns_direct" },'
    }
    [ "$dns_mod" = "route" ] && {
        global_dns=dns_proxy
        direct_dns='{ "rule_set": ["cn"], "server": "dns_direct" }'
    }
    #防泄露设置
    [ "$dns_protect" = "OFF" ] && sed -i 's/"server": "dns_proxy"/"server": "dns_direct"/g' "$TMPDIR"/jsons/route.json
    #生成add_rule_set.json
    [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ] && ! grep -Eq '"tag" *:[[:space:]]*"cn"' "$CRASHDIR"/jsons/*.json && {
		[ "$crashcore" = "singboxr" ] && srs_path='"path": "./ruleset/cn.srs",'
        cat >"$TMPDIR"/jsons/add_rule_set.json <<EOF
{
  "route": {
    "rule_set": [
      {
        "tag": "cn",
        "type": "remote",
        "format": "binary",
        $srs_path
        "url": "https://testingcf.jsdelivr.net/gh/DustinWin/ruleset_geodata@sing-box-ruleset/cn.srs",
        "download_detour": "DIRECT"
      }
    ]
  }
}
EOF
}
    cat >"$TMPDIR"/jsons/dns.json <<EOF
{
  "dns": {
    "servers": [
      {
        "tag": "dns_proxy",
        $(parse_singbox_dns "$dns_fallback")
		"routing_mark": $routing_mark,
		"detour": $auto_detour,
        "domain_resolver": "dns_resolver"
      },
      {
        "tag": "dns_direct",
        $(parse_singbox_dns "$dns_nameserver")
		"routing_mark": $routing_mark,
        "domain_resolver": "dns_resolver"
      },
      {
        "tag": "dns_fakeip",
        "type": "fakeip",
        "inet4_range": "28.0.0.0/8",
        "inet6_range": "fc00::/16"
      },
      {
        "tag": "dns_resolver",
        $(parse_singbox_dns "$dns_resolver")
		"routing_mark": $routing_mark
      }
    ],
    "rules": [
      { "clash_mode": "Direct", "server": "dns_direct", "strategy": "$strategy" },
      { "domain_suffix": ["services.googleapis.cn"], "server": "dns_fakeip", "strategy": "$strategy", "rewrite_ttl": 1 },
      $fake_ip_filter_domain
      $fake_ip_filter_suffix
      $fake_ip_filter_regex
	  { "clash_mode": "Global", "query_type": ["A", "AAAA"], "server": "$global_dns", "strategy": "$strategy", "rewrite_ttl": 1 },
      $direct_dns
	  $proxy_dns
    ],
    "final": "dns_proxy",
	"strategy": "$strategy",
    "independent_cache": true,
	$client_subnet
    "reverse_mapping": true
  }
}
EOF
    #生成add_route.json
    #域名嗅探配置
    [ "$sniffer" = ON ] && sniffer_set='{ "action": "sniff", "timeout": "500ms" },'
	[ "$ts_service" = ON ] && tailscale_set='{ "inbound": [ "ts-ep" ], "port": 53, "action": "hijack-dns" },'
    cat >"$TMPDIR"/jsons/add_route.json <<EOF
{
  "route": {
	"default_domain_resolver": "dns_resolver",
    "default_mark": $routing_mark,
	"rules": [
	  { "inbound": [ "dns-in" ], "action": "hijack-dns" },
	  $tailscale_set
	  $sniffer_set
      { "clash_mode": "Direct" , "outbound": "DIRECT" },
      { "clash_mode": "Global" , "outbound": "GLOBAL" }
	]
  }
}
EOF
    #生成certificate.json
    cat >"$TMPDIR"/jsons/certificate.json <<EOF
{
  "certificate": {
    "store": "mozilla"
  }
}
EOF
    #生成inbounds.json
    [ -n "$authentication" ] && {
        username=$(echo $authentication | awk -F ':' '{print $1}') #混合端口账号密码
        password=$(echo $authentication | awk -F ':' '{print $2}')
        userpass='"users": [{ "username": "'$username'", "password": "'$password'" }], '
    }
    cat >"$TMPDIR"/jsons/inbounds.json <<EOF
{
  "inbounds": [
    {
      "type": "mixed",
      "tag": "mixed-in",
      "listen": "::",
      $userpass
      "listen_port": $mix_port
    },
    {
      "type": "direct",
      "tag": "dns-in",
      "listen": "::",
      "listen_port": $dns_port
    },
    {
      "type": "redirect",
      "tag": "redirect-in",
      "listen": "::",
      "listen_port": $redir_port
    },
    {
      "type": "tproxy",
      "tag": "tproxy-in",
      "listen": "::",
      "listen_port": $tproxy_port
    }
  ]
}
EOF
    #inbounds.json添加自定义入站
	[ "$vms_service" = ON ] || [ "$sss_service" = ON ] && {
		. "$CRASHDIR"/configs/gateway.cfg
		. "$CRASHDIR"/libs/sb_inbounds.sh
	}
    if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ]; then
        [ "ipv6_redir" = 'ON' ] && ipv6_address='"fe80::e5c5:2469:d09b:609a/64",'
        cat >>"$TMPDIR"/jsons/tun.json <<EOF
{
  "inbounds": [
    {
      "type": "tun",
      "tag": "tun-in",
      "interface_name": "utun",
      "address": [
        $ipv6_address
        "28.0.0.1/30"
      ],
      "auto_route": false,
      "stack": "system"
    }
  ]
}
EOF
    fi
    #生成add_outbounds.json
    grep -qE '"tag": "DIRECT"' "$TMPDIR"/jsons/outbounds.json || add_direct='{ "tag": "DIRECT", "type": "direct" }'
    grep -qE '"tag": "REJECT"' "$TMPDIR"/jsons/outbounds.json || add_reject='{ "tag": "REJECT", "type": "block" }'
    grep -qE '"tag": "GLOBAL"' "$TMPDIR"/jsons/outbounds.json || {
        auto_proxies=$(grep -E '"type": "(selector|urltest)"' -A 1 "$TMPDIR"/jsons/outbounds.json | grep '"tag":' | sed 's/^[[:space:]]*"tag": //;$ s/,$//')
        [ -n "$auto_proxies" ] && add_global='{ "tag": "GLOBAL", "type": "selector", "outbounds": ['"$auto_proxies"', "DIRECT"]}'
    }
    [ -n "$add_direct" -a -n "$add_reject" ] && add_direct="${add_direct},"
    [ -n "$add_reject" -a -n "$add_global" ] && add_reject="${add_reject},"
    [ -n "$add_direct$add_reject$add_global" ] && cat >"$TMPDIR"/jsons/add_outbounds.json <<EOF
{
  "outbounds": [
	$add_direct
	$add_reject
	$add_global
  ]
}
EOF
    #生成experimental.json
    cat >"$TMPDIR"/jsons/experimental.json <<EOF
{
  "experimental": {
    "clash_api": {
      "external_controller": "0.0.0.0:$db_port",
      "external_ui": "ui",
	  "external_ui_download_url": "$external_ui_url",
      "secret": "$secret",
      "default_mode": "Rule"
    }
  }
}
EOF
    #生成自定义规则文件
    [ -n "$(grep -Ev ^# "$CRASHDIR"/yamls/rules.yaml 2>/dev/null)" ] && {
        cat "$CRASHDIR"/yamls/rules.yaml |
            sed '/#.*/d' |
            sed 's/,no-resolve//g' |
            grep -oE '\-.*,.*,.*' |
            sed 's/- DOMAIN-SUFFIX,/{ "domain_suffix": [ "/g' |
            sed 's/- DOMAIN-KEYWORD,/{ "domain_keyword": [ "/g' |
            sed 's/- IP-CIDR,/{ "ip_cidr": [ "/g' |
            sed 's/- SRC-IP-CIDR,/{ "._ip_cidr": [ "/g' |
            sed 's/- DST-PORT,/{ "port": [ "/g' |
            sed 's/- SRC-PORT,/{ "._port": [ "/g' |
            sed 's/- GEOIP,/{ "geoip": [ "/g' |
            sed 's/- GEOSITE,/{ "geosite": [ "/g' |
            sed 's/- IP-CIDR6,/{ "ip_cidr": [ "/g' |
            sed 's/- DOMAIN,/{ "domain": [ "/g' |
            sed 's/- PROCESS-NAME,/{ "process_name": [ "/g' |
            sed 's/,/" ], "outbound": "/g' |
            sed 's/$/" },/g' |
            sed '1i\{ "route": { "rules": [ ' |
            sed '$s/,$/ ] } }/' >"$TMPDIR"/jsons/cust_add_rules.json
        [ ! -s "$TMPDIR"/jsons/cust_add_rules.json ] && rm -rf "$TMPDIR"/jsons/cust_add_rules.json
    }
    #清理route.json中的process_name规则以及"auto_detect_interface"
    sed -i '/"process_name": \[/,/],$/d' "$TMPDIR"/jsons/route.json
    sed -i '/"process_name": "[^"]*",/d' "$TMPDIR"/jsons/route.json
    sed -i 's/"auto_detect_interface": true/"auto_detect_interface": false/g' "$TMPDIR"/jsons/route.json
    #跳过本地tls证书验证
    if [ "$skip_cert" != "OFF" ]; then
        sed -i 's/"insecure": false/"insecure": true/' "$TMPDIR"/jsons/outbounds.json "$TMPDIR"/jsons/providers.json 2>/dev/null
    else
        sed -i 's/"insecure": true/"insecure": false/' "$TMPDIR"/jsons/outbounds.json "$TMPDIR"/jsons/providers.json 2>/dev/null
    fi
    #判断可用并修饰outbounds&providers&route.json结尾
    for file in outbounds providers route; do
        if [ -n "$(grep ${file} "$TMPDIR"/jsons/${file}.json 2>/dev/null)" ]; then
            sed -i 's/^  },$/  }/; s/^  ],$/  ]/' "$TMPDIR"/jsons/${file}.json
            echo '}' >>"$TMPDIR"/jsons/${file}.json
        else
            rm -rf "$TMPDIR"/jsons/${file}.json
        fi
    done
    #加载自定义配置文件
    mkdir -p "$TMPDIR"/jsons_base
    #以下为覆盖脚本的自定义文件
    for char in log dns ntp certificate experimental; do
        [ -s "$CRASHDIR"/jsons/${char}.json ] && {
            ln -sf "$CRASHDIR"/jsons/${char}.json "$TMPDIR"/jsons/cust_${char}.json
            mv -f "$TMPDIR"/jsons/${char}.json "$TMPDIR"/jsons_base #如果重复则临时备份
        }
    done
    #以下为增量添加的自定义文件
    for char in others endpoints inbounds outbounds providers route services; do
        [ -s "$CRASHDIR"/jsons/${char}.json ] && {
            ln -sf "$CRASHDIR"/jsons/${char}.json "$TMPDIR"/jsons/cust_${char}.json
        }
    done
    #测试自定义配置文件
    if ! error=$("$TMPDIR"/CrashCore check -D "$BINDIR" -C "$TMPDIR"/jsons 2>&1); then
        echo $error
        error_file=$(echo $error | grep -Eo 'cust.*\.json' | sed 's/cust_//g')
        [ "$error_file" = 'add_rules.json' ] && error_file="$CRASHDIR"/yamls/rules.yaml自定义规则 || error_file="$CRASHDIR"/jsons/$error_file
        logger "自定义配置文件校验失败，请检查【${error_file}】文件！" 31
        logger "尝试使用基础配置文件启动~" 33
        #清理自定义配置文件并还原基础配置
        rm -rf "$TMPDIR"/jsons/cust_*
        mv -f "$TMPDIR"/jsons_base/* "$TMPDIR"/jsons 2>/dev/null
    fi
    #清理缓存
    rm -rf "$TMPDIR"/*.json
    rm -rf "$TMPDIR"/jsons_base
    return 0
}
