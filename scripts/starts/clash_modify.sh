#!/bin/sh
# Copyright (C) Juewuy

#修饰clash配置文件
modify_yaml() {
    ##########需要变更的配置###########
    [ "$ipv6_dns" != "OFF" ] && dns_v6='true' || dns_v6='false'
    external="external-controller: 0.0.0.0:$db_port"
    if [ "$redir_mod" = "混合模式" -o "$redir_mod" = "Tun模式" ]; then
        [ "$crashcore" = 'meta' ] && tun_meta=', device: utun, auto-route: false, auto-detect-interface: false'
        tun="tun: {enable: true, stack: system$tun_meta}"
    else
        tun='tun: {enable: false}'
    fi
    exper='experimental: {ignore-resolve-fail: true, interface-name: en0}'
    #Meta内核专属配置
    [ "$crashcore" = 'meta' ] && {
        [ "$redir_mod" != "纯净模式" ] && [ -z "$(grep 'PROCESS' "$CRASHDIR"/yamls/*.yaml)" ] && find_process='find-process-mode: "off"'
		#ecs优化
		[ "$ecs_subnet" = ON ] && {
			. "$CRASHDIR"/libs/get_ecsip.sh
			if [ -n "$ecs_address" ];then
				dns_fallback=$(echo "$dns_fallback, " | sed "s|, |#ecs-override=true\&ecs=$ecs_address, |g" | sed 's|, $||')
			else
				logger "自动获取ecs网段失败！"
			fi
		}
    }
    #dns配置
    [ -z "$(cat "$CRASHDIR"/yamls/user.yaml 2>/dev/null | grep '^dns:')" ] && {
        [ "$crashcore" != meta ] && dns_resolver='223.5.5.5'
        cat >"$TMPDIR"/dns.yaml <<EOF
dns:
  enable: true
  listen: :$dns_port
  use-hosts: true
  ipv6: $dns_v6
  default-nameserver: [ $dns_resolver ]
  enhanced-mode: fake-ip
  fake-ip-range: 28.0.0.0/8
  fake-ip-range6: fc00::/16
  fake-ip-filter:
EOF
        if [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "fake-ip" ]; then
            cat "$CRASHDIR"/configs/fake_ip_filter "$CRASHDIR"/configs/fake_ip_filter.list 2>/dev/null | grep -v '#' | sed "s/^/    - '/" | sed "s/$/'/" >>"$TMPDIR"/dns.yaml
        else
            echo "    - '+.*'" >>"$TMPDIR"/dns.yaml #使用fake-ip模拟redir_host
        fi
        #mix模式fakeip绕过cn
        [ "$dns_mod" = "mix" ] && echo '    - "rule-set:cn"' >>"$TMPDIR"/dns.yaml
        #mix模式和route模式插入分流设置
        if [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ]; then
            [ "$dns_protect" != "OFF" ] && dns_final="$dns_fallback" || dns_final="$dns_nameserver"
            cat >>"$TMPDIR"/dns.yaml <<EOF
  respect-rules: true
  nameserver-policy: {'rule-set:cn': [ $dns_nameserver ]}
  proxy-server-nameserver : [ $dns_resolver ]
  nameserver: [ $dns_final ]
EOF
        else
            cat >>"$TMPDIR"/dns.yaml <<EOF
  nameserver: [ $dns_nameserver ]
EOF
        fi
    }
    #域名嗅探配置
    [ "$sniffer" = "ON" ] && [ "$crashcore" = "meta" ] && sniffer_set="sniffer: {enable: true, parse-pure-ip: true, skip-domain: [Mijia Cloud], sniff: {http: {ports: [80, 8080-8880], override-destination: true}, tls: {ports: [443, 8443]}, quic: {ports: [443, 8443]}}}"
    [ "$crashcore" = "clashpre" ] && [ "$dns_mod" = "redir_host" -o "$sniffer" = "ON" ] && exper="experimental: {ignore-resolve-fail: true, interface-name: en0,sniff-tls-sni: true}"
    #生成set.yaml
    cat >"$TMPDIR"/set.yaml <<EOF
mixed-port: $mix_port
redir-port: $redir_port
tproxy-port: $tproxy_port
authentication: ["$authentication"]
allow-lan: true
mode: Rule
log-level: info
ipv6: true
external-controller: :$db_port
external-ui: ui
external-ui-url: "$external_ui_url"
secret: $secret
$tun
$exper
$sniffer_set
$find_process
routing-mark: $routing_mark
unified-delay: true
EOF
    #读取本机hosts并生成配置文件
    if [ "$hosts_opt" != "OFF" ] && [ -z "$(grep -aE '^hosts:' "$CRASHDIR"/yamls/user.yaml 2>/dev/null)" ]; then
        #NTP劫持
        cat >"$TMPDIR"/hosts.yaml <<EOF
use-system-hosts: true
hosts:
  'time.android.com': 203.107.6.88
  'time.facebook.com': 203.107.6.88
EOF
        if [ "$crashcore" = "meta" ]; then
            echo "  'services.googleapis.cn': services.googleapis.com" >>"$TMPDIR"/hosts.yaml
        fi
		#加载本机hosts
		sys_hosts=/etc/hosts
		[ -f /data/etc/custom_hosts ] && sys_hosts='/etc/hosts /data/etc/custom_hosts'
		cat $sys_hosts | while read line; do
			[ -n "$(echo "$line" | grep -oE "([0-9]{1,3}[\.]){3}")" ] &&
				[ -z "$(echo "$line" | grep -oE '^#')" ] &&
				hosts_ip=$(echo $line | awk '{print $1}') &&
				hosts_domain=$(echo $line | awk '{print $2}') &&
				[ -z "$(cat "$TMPDIR"/hosts.yaml | grep -oE "$hosts_domain")" ] &&
				echo "  '$hosts_domain': $hosts_ip" >>"$TMPDIR"/hosts.yaml
		done
    fi
    #分割配置文件
    yaml_char='proxies proxy-groups proxy-providers rules rule-providers sub-rules listeners'
    for char in $yaml_char; do
        sed -n "/^$char:/,/^[a-z]/ { /^[a-z]/d; p; }" $core_config >"$TMPDIR"/${char}.yaml
    done
    #跳过本地tls证书验证
    [ "$skip_cert" != "OFF" ] && sed -i 's/skip-cert-verify: false/skip-cert-verify: true/' "$TMPDIR"/proxies.yaml ||
        sed -i 's/skip-cert-verify: true/skip-cert-verify: false/' "$TMPDIR"/proxies.yaml
    #插入自定义策略组
    sed -i "/#自定义策略组开始/,/#自定义策略组结束/d" "$TMPDIR"/proxy-groups.yaml
    sed -i "/#自定义策略组/d" "$TMPDIR"/proxy-groups.yaml
    [ -n "$(grep -Ev '^#' "$CRASHDIR"/yamls/proxy-groups.yaml 2>/dev/null)" ] && {
        #获取空格数
        space_name=$(grep -aE '^ *- \{?name: ' "$TMPDIR"/proxy-groups.yaml | head -n 1 | grep -oE '^ *')
        space_proxy="$space_name    "
        #合并自定义策略组到proxy-groups.yaml
        cat "$CRASHDIR"/yamls/proxy-groups.yaml | sed "/^#/d" | sed "s/#.*//g" | sed '1i\ #自定义策略组开始' | sed '$a\ #自定义策略组结束' | sed "s/^ */${space_name}  /g" | sed "s/^ *- /${space_proxy}- /g" | sed "s/^ *- name: /${space_name}- name: /g"  | sed "s/^ *- {name: /${space_name}- {name: /g" >"$TMPDIR"/proxy-groups_add.yaml
        cat "$TMPDIR"/proxy-groups.yaml >>"$TMPDIR"/proxy-groups_add.yaml
        mv -f "$TMPDIR"/proxy-groups_add.yaml "$TMPDIR"/proxy-groups.yaml
        oldIFS="$IFS"
        grep "\- name: " "$CRASHDIR"/yamls/proxy-groups.yaml | sed "/^#/d" | while read line; do #将自定义策略组插入现有的proxy-group
            new_group=$(echo $line | grep -Eo '^ *- name:.*#' | cut -d'#' -f1 | sed 's/.*name: //g')
            proxy_groups=$(echo $line | grep -Eo '#.*' | sed "s/#//")
            IFS="#"
            for name in $proxy_groups; do
                line_a=$(grep -n "\- name: $name" "$TMPDIR"/proxy-groups.yaml | head -n 1 | awk -F: '{print $1}') #获取group行号
                [ -n "$line_a" ] && {
                    line_b=$(grep -A 8 "\- name: $name" "$TMPDIR"/proxy-groups.yaml | grep -n "proxies:$" | head -n 1 | awk -F: '{print $1}') #获取proxies行号
                    line_c=$((line_a + line_b - 1))                                                                                           #计算需要插入的行号
                    space=$(sed -n "$((line_c + 1))p" "$TMPDIR"/proxy-groups.yaml | grep -oE '^ *')                                           #获取空格数
                    [ "$line_c" -gt 2 ] && sed -i "${line_c}a\\${space}- ${new_group} #自定义策略组" "$TMPDIR"/proxy-groups.yaml
                }
            done
            IFS="$oldIFS"
        done
    }
    #插入自定义代理
    sed -i "/#自定义代理/d" "$TMPDIR"/proxies.yaml
    sed -i "/#自定义代理/d" "$TMPDIR"/proxy-groups.yaml
    [ -n "$(grep -Ev '^#' "$CRASHDIR"/yamls/proxies.yaml 2>/dev/null)" ] && {
        space_proxy=$(cat "$TMPDIR"/proxies.yaml | grep -aE '^ *- ' | head -n 1 | grep -oE '^ *')                                                            #获取空格数
        cat "$CRASHDIR"/yamls/proxies.yaml | sed "s/^ *- /${space_proxy}- /g" | sed "/^#/d" | sed "/^ *$/d" | sed 's/#.*/ #自定义代理/g' >>"$TMPDIR"/proxies.yaml #插入节点
        oldIFS="$IFS"
        cat "$CRASHDIR"/yamls/proxies.yaml | sed "/^#/d" | while read line; do #将节点插入proxy-group
            proxy_name=$(echo $line | grep -Eo 'name: .+, ' | cut -d',' -f1 | sed 's/name: //g')
            proxy_groups=$(echo $line | grep -Eo '#.*' | sed "s/#//")
            IFS="#"
            for name in $proxy_groups; do
                line_a=$(grep -n "\- name: $name" "$TMPDIR"/proxy-groups.yaml | head -n 1 | awk -F: '{print $1}') #获取group行号
                [ -n "$line_a" ] && {
                    line_b=$(grep -A 8 "\- name: $name" "$TMPDIR"/proxy-groups.yaml | grep -n "proxies:$" | head -n 1 | awk -F: '{print $1}') #获取proxies行号
                    line_c=$((line_a + line_b - 1))                                                                                           #计算需要插入的行号
                    space=$(sed -n "$((line_c + 1))p" "$TMPDIR"/proxy-groups.yaml | grep -oE '^ *')                                           #获取空格数
                    [ "$line_c" -gt 2 ] && sed -i "${line_c}a\\${space}- ${proxy_name} #自定义代理" "$TMPDIR"/proxy-groups.yaml
                }
            done
            IFS="$oldIFS"
        done
    }
    #添加自定义入站
	[ "$vms_service" = ON ] || [ "$sss_service" = ON ] && {
		. "$CRASHDIR"/configs/gateway.cfg
		. "$CRASHDIR"/libs/meta_listeners.sh
	}
    #节点绕过功能支持
    sed -i "/#节点绕过/d" "$TMPDIR"/rules.yaml
    [ "$proxies_bypass" = "ON" ] && {
        cat "$TMPDIR"/proxies.yaml | sed '/^proxy-/,$d' | sed '/^rule-/,$d' | grep -v '^\s*#' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | awk '!a[$0]++' | sed 's/^/\ -\ IP-CIDR,/g' | sed 's|$|/32,DIRECT,no-resolve #节点绕过|g' >>"$TMPDIR"/proxies_bypass
        cat "$TMPDIR"/proxies.yaml | sed '/^proxy-/,$d' | sed '/^rule-/,$d' | grep -v '^\s*#' | grep -vE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?' | awk '!a[$0]++' | sed 's/^/\ -\ DOMAIN,/g' | sed 's/$/,DIRECT #节点绕过/g' >>"$TMPDIR"/proxies_bypass
        cat "$TMPDIR"/rules.yaml >>"$TMPDIR"/proxies_bypass
        mv -f "$TMPDIR"/proxies_bypass "$TMPDIR"/rules.yaml
    }
    #插入自定义规则
    sed -i "/#自定义规则/d" "$TMPDIR"/rules.yaml
    [ -s "$CRASHDIR"/yamls/rules.yaml ] && {
        cat "$CRASHDIR"/yamls/rules.yaml | sed "/^#/d" | sed '$a\' | sed 's/$/ #自定义规则/g' >"$TMPDIR"/rules.add
        cat "$TMPDIR"/rules.yaml >>"$TMPDIR"/rules.add
        mv -f "$TMPDIR"/rules.add "$TMPDIR"/rules.yaml
    }
    #mix和route模式生成rule-providers
    [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ] && ! grep -Eq '^[[:space:]]*cn:' "$TMPDIR"/rule-providers.yaml && ! grep -q '^rule-providers' "$CRASHDIR"/yamls/others.yaml 2>/dev/null && {
        space=$(sed -n "1p" "$TMPDIR"/rule-providers.yaml | grep -oE '^ *') #获取空格数
        [ -z "$space" ] && space='  '
        echo "${space}cn: {type: http, behavior: domain, format: mrs, path: ./ruleset/cn.mrs, url: https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@update/bin/geodata/mrs_geosite_cn.mrs}" >>"$TMPDIR"/rule-providers.yaml
    }
    #对齐rules中的空格
    sed -i 's/^ *-/ -/g' "$TMPDIR"/rules.yaml
    #合并文件
    [ -s "$CRASHDIR"/yamls/user.yaml ] && {
        yaml_user="$CRASHDIR"/yamls/user.yaml
        #set和user去重,且优先使用user.yaml
        cp -f "$TMPDIR"/set.yaml "$TMPDIR"/set_bak.yaml
        for char in mode allow-lan log-level tun experimental external-ui-url interface-name dns store-selected unified-delay; do
            [ -n "$(grep -E "^$char" $yaml_user)" ] && sed -i "/^$char/d" "$TMPDIR"/set.yaml
        done
    }
    [ -s "$TMPDIR"/dns.yaml ] && yaml_dns="$TMPDIR"/dns.yaml
    [ -s "$TMPDIR"/hosts.yaml ] && yaml_hosts="$TMPDIR"/hosts.yaml
    [ -s "$CRASHDIR"/yamls/others.yaml ] && yaml_others="$CRASHDIR"/yamls/others.yaml
    yaml_add=
    for char in $yaml_char; do #将额外配置文件合并
        [ -s "$TMPDIR"/${char}.yaml ] && {
            sed -i "1i\\${char}:" "$TMPDIR"/${char}.yaml
            yaml_add="$yaml_add $TMPDIR/${char}.yaml"
        }
    done
    #合并完整配置文件
    cut -c 1- "$TMPDIR"/set.yaml $yaml_dns $yaml_hosts $yaml_user $yaml_others $yaml_add >"$TMPDIR"/config.yaml
    #测试自定义配置文件
    "$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml >/dev/null
    if [ "$?" != 0 ]; then
        logger "$("$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml | grep -Eo 'error.*=.*')" 31
        logger "自定义配置文件校验失败！将使用基础配置文件启动！" 33
        logger "错误详情请参考 "$TMPDIR"/error.yaml 文件！" 33
        mv -f "$TMPDIR"/config.yaml "$TMPDIR"/error.yaml >/dev/null 2>&1
        sed -i "/#自定义策略组开始/,/#自定义策略组结束/d" "$TMPDIR"/proxy-groups.yaml
        mv -f "$TMPDIR"/set_bak.yaml "$TMPDIR"/set.yaml >/dev/null 2>&1
        #合并基础配置文件
        cut -c 1- "$TMPDIR"/set.yaml $yaml_dns $yaml_add >"$TMPDIR"/config.yaml
        sed -i "/#自定义/d" "$TMPDIR"/config.yaml
    fi
    #建立软连接
    [ ""$TMPDIR"" = ""$BINDIR"" ] || ln -sf "$TMPDIR"/config.yaml "$BINDIR"/config.yaml 2>/dev/null || cp -f "$TMPDIR"/config.yaml "$BINDIR"/config.yaml
    #清理缓存
    for char in $yaml_char set set_bak dns hosts; do
        rm -f "$TMPDIR"/${char}.yaml
    done
}