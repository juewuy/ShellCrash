#!/bin/sh
# Copyright (C) Juewuy

#初始化目录
CRASHDIR=$(
    cd $(dirname $0)
    pwd
)
#加载执行目录，失败则初始化
. "$CRASHDIR"/configs/command.env >/dev/null 2>&1
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && . "$CRASHDIR"/init.sh >/dev/null 2>&1
[ ! -f "$TMPDIR" ] && mkdir -p "$TMPDIR"
#加载工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/compare.sh
. "$CRASHDIR"/libs/logger.sh
. "$CRASHDIR"/starts/fw_start.sh
. "$CRASHDIR"/starts/fw_stop.sh

#脚本内部工具
getconfig() { #读取配置及全局变量
    #加载配置文件
    . "$CRASHDIR"/configs/ShellCrash.cfg >/dev/null
    #缺省值
    [ -z "$redir_mod" ] && [ "$USER" = "root" -o "$USER" = "admin" ] && redir_mod='Redir模式'
    [ -z "$redir_mod" ] && firewall_area='4'
    [ -z "$skip_cert" ] && skip_cert=已开启
    [ -z "$dns_mod" ] && dns_mod=fake-ip
    [ -z "$ipv6_redir" ] && ipv6_redir=未开启
    [ -z "$ipv6_dns" ] && ipv6_dns=已开启
    [ -z "$macfilter_type" ] && macfilter_type=黑名单
    [ -z "$mix_port" ] && mix_port=7890
    [ -z "$redir_port" ] && redir_port=7892
    [ -z "$tproxy_port" ] && tproxy_port=7893
    [ -z "$db_port" ] && db_port=9999
    [ -z "$dns_port" ] && dns_port=1053
    [ -z "$fwmark" ] && fwmark=$redir_port
    routing_mark=$((fwmark + 2))
    [ -z "$table" ] && table=100
    [ -z "$sniffer" ] && sniffer=已开启
    #是否代理常用端口
    [ -z "$common_ports" ] && common_ports=已开启
    [ -z "$multiport" ] && multiport='22,80,143,194,443,465,587,853,993,995,5222,8080,8443'
    [ "$common_ports" = "已开启" ] && ports="-m multiport --dports $multiport"
    #内核配置文件
    if echo "$crashcore" | grep -q 'singbox'; then
        target=singbox
        format=json
        core_config="$CRASHDIR"/jsons/config.json
    else
        target=clash
        format=yaml
        core_config="$CRASHDIR"/yamls/config.yaml
    fi
    #检查$iptable命令可用性
    ckcmd iptables && iptables -h | grep -q '\-w' && iptable='iptables -w' || iptable=iptables
    ckcmd ip6tables && ip6tables -h | grep -q '\-w' && ip6table='ip6tables -w' || ip6table=ip6tables
    #默认dns
    [ -z "$dns_nameserver" ] && dns_nameserver='223.5.5.5, 1.2.4.8'
    [ -z "$dns_fallback" ] && dns_fallback="1.1.1.1, 8.8.8.8"
    [ -z "$dns_resolver" ] && dns_resolver="223.5.5.5, 2400:3200::1"
    #自动生成ua
    [ -z "$user_agent" -o "$user_agent" = "auto" ] && {
        if echo "$crashcore" | grep -q 'singbox'; then
            user_agent="sing-box/singbox/$core_v"
        elif [ "$crashcore" = meta ]; then
            user_agent="clash.meta/mihomo/$core_v"
        else
            user_agent="clash"
        fi
    }
    [ "$user_agent" = "none" ] && unset user_agent
}

ckgeo() { #查找及下载Geo数据文件
    [ ! -d "$BINDIR"/ruleset ] && mkdir -p "$BINDIR"/ruleset
    find --help 2>&1 | grep -q size && find_para=' -size +20' #find命令兼容
    [ -z "$(find "$BINDIR"/"$1" "$find_para" 2>/dev/null)" ] && {
        if [ -n "$(find "$CRASHDIR"/"$1" "$find_para" 2>/dev/null)" ]; then
            mv "$CRASHDIR"/"$1" "$BINDIR"/"$1" #小闪存模式移动文件
        else
            logger "未找到${1}文件，正在下载！" 33
            get_bin "$BINDIR"/"$1" bin/geodata/"$2"
            [ "$?" = "1" ] && rm -rf "${BINDIR}"/"${1}" && logger "${1}文件下载失败,已退出！请前往更新界面尝试手动下载！" 31 && exit 1
            geo_v="$(echo "$2" | awk -F "." '{print $1}')_v"
            setconfig "$geo_v" "$(date +"%Y%m%d")"
        fi
    }
}

croncmd() { #定时任务工具
    if [ -n "$(crontab -h 2>&1 | grep '\-l')" ]; then
        crontab "$1"
    else
        crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}')"
        [ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
        [ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
        [ ! -w "$crondir" ] && crondir="/var/spool/cron"
        if [ -w "$crondir" ]; then
            [ "$1" = "-l" ] && cat "$crondir"/"$USER" 2>/dev/null
            [ -f "$1" ] && cat "$1" >"$crondir"/"$USER"
        else
            echo "你的设备不支持定时任务配置，脚本大量功能无法启用，请尝试使用搜索引擎查找安装方式！"
        fi
    fi
}
cronset() { #定时任务设置
    # 参数1代表要移除的关键字,参数2代表要添加的任务语句
    tmpcron="$TMPDIR"/cron_tmp
    croncmd -l >"$tmpcron" 2>/dev/null
    sed -i "/$1/d" "$tmpcron"
    sed -i '/^$/d' "$tmpcron"
    echo "$2" >>"$tmpcron"
    croncmd "$tmpcron"
    rm -f "$tmpcron"
}
get_save() { #获取面板信息
    if curl --version >/dev/null 2>&1; then
        curl -s -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1"
    elif [ -n "$(wget --help 2>&1 | grep '\-\-method')" ]; then
        wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1"
    fi
}
put_save() { #推送面板选择
    [ -z "$3" ] && request_type=PUT || request_type=$3
    if curl --version >/dev/null 2>&1; then
        curl -sS -X "$request_type" -H "Authorization: Bearer $secret" -H "Content-Type:application/json" "$1" -d "$2" >/dev/null
    elif wget --version >/dev/null 2>&1; then
        wget -q --method="$request_type" --header="Authorization: Bearer $secret" --header="Content-Type:application/json" --body-data="$2" "$1" >/dev/null
    fi
}
get_bin() { #专用于项目内部文件的下载
    [ -z "$update_url" ] && update_url=https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@master
    if [ -n "$url_id" ]; then
        echo "$2" | grep -q '^bin/' && release_type=update #/bin文件改为在update分支下载
        echo "$2" | grep -q '^public/' && release_type=dev #/public文件改为在dev分支下载
        [ -z "$release_type" ] && release_type=master
        if [ "$url_id" = 101 -o "$url_id" = 104 ]; then
            url="$(grep "$url_id" "$CRASHDIR"/configs/servers.list | awk '{print $3}')@$release_type/$2" #jsdelivr特殊处理
        else
            url="$(grep "$url_id" "$CRASHDIR"/configs/servers.list | awk '{print $3}')/$release_type/$2"
        fi
    else
        url="$update_url/$2"
    fi
    $0 webget "$1" "$url" "$3" "$4" "$5" "$6"
}
mark_time() { #时间戳
    date +%s >"$TMPDIR"/crash_start_time
}
getlanip() { #获取局域网host地址
    i=1
    while [ "$i" -le "20" ]; do
        host_ipv4=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Ev 'utun|iot|peer|docker|podman|virbr|vnet|ovs|vmbr|veth|vmnic|vboxnet|lxcbr|xenbr|vEthernet' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/br.*$//g' | sed 's/metric.*$//g') #ipv4局域网网段
        [ "$ipv6_redir" = "已开启" ] && host_ipv6=$(ip a 2>&1 | grep -w 'inet6' | grep -E 'global' | sed 's/.*inet6.//g' | sed 's/scope.*$//g')                                                                                                                                #ipv6公网地址段
        [ -f "$TMPDIR"/ShellCrash.log ] && break
        [ -n "$host_ipv4" -a "$ipv6_redir" != "已开启" ] && break
        [ -n "$host_ipv4" -a -n "$host_ipv6" ] && break
        sleep 1 && i=$((i + 1))
    done
    #添加自定义ipv4局域网网段
    if [ "$replace_default_host_ipv4" == "已启用" ]; then
        host_ipv4="$cust_host_ipv4"
    else
        host_ipv4="$host_ipv4$cust_host_ipv4"
    fi
    #缺省配置
    [ -z "$host_ipv4" ] && host_ipv4='192.168.0.0/16 10.0.0.0/12 172.16.0.0/12'
    host_ipv6="fe80::/10 fd00::/8 $host_ipv6"
    #获取本机出口IP地址
    local_ipv4=$(ip route 2>&1 | grep -Ev 'utun|iot|docker|linkdown' | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
    [ -z "$local_ipv4" ] && local_ipv4=$(ip route 2>&1 | grep -Eo 'src.*' | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort -u)
    #保留地址
    [ -z "$reserve_ipv4" ] && reserve_ipv4="0.0.0.0/8 10.0.0.0/8 127.0.0.0/8 100.64.0.0/10 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4"
    [ -z "$reserve_ipv6" ] && reserve_ipv6="::/128 ::1/128 ::ffff:0:0/96 64:ff9b::/96 100::/64 2001::/32 2001:20::/28 2001:db8::/32 2002::/16 fe80::/10 ff00::/8"
}
parse_singbox_dns() { #singbox的dns分割工具
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
urlencode() {
    LC_ALL=C
    printf '%s' "$1" \
    | hexdump -v -e '/1 "%02X\n"' \
    | while read -r hex; do
        case "$hex" in
            2D|2E|5F|7E|3[0-9]|4[1-9A-F]|5[0-9A]|6[1-9A-F]|7[0-9A-E])
                printf "\\$(printf '%03o' "0x$hex")"
                ;;
            *)
                printf "%%%s" "$hex"
                ;;
        esac
    done
}
#配置文件相关
check_clash_config() { #检查clash配置文件
    #检测节点或providers
    sed -n "/^proxies:/,/^[a-z]/ { /^[a-z]/d; p; }" "$core_config_new" >"$TMPDIR"/proxies.yaml
    if ! grep -Eq 'server:|server":|server'\'':' "$TMPDIR"/proxies.yaml && ! grep -q 'proxy-providers:' "$core_config_new"; then
        echo "-----------------------------------------------"
        logger "获取到了配置文件【$core_config_new】，但似乎并不包含正确的节点信息！" 31
        cat "$TMPDIR"/proxies.yaml
        sleep 1
        echo "-----------------------------------------------"
        echo "请尝试使用6-2或者6-3的方式生成配置文件！"
        exit 1
    fi
    rm -rf "$TMPDIR"/proxies.yaml
    #检测旧格式
    if cat "$core_config_new" | grep 'Proxy Group:' >/dev/null; then
        echo "-----------------------------------------------"
        logger "已经停止对旧格式配置文件的支持！！！" 31
        echo -e "请使用新格式或者使用【在线生成配置文件】功能！"
        echo "-----------------------------------------------"
        exit 1
    fi
    #检测不支持的加密协议
    if cat "$core_config_new" | grep 'cipher: chacha20,' >/dev/null; then
        echo "-----------------------------------------------"
        logger "已停止支持chacha20加密，请更换更安全的节点加密协议！" 31
        echo "-----------------------------------------------"
        exit 1
    fi
    #检测并去除无效策略组
    [ -n "$url_type" ] && ckcmd xargs && {
        cat "$core_config_new" | sed '/^rules:/,$d' | grep -A 15 "\- name:" | xargs | sed 's/- name: /\n/g' | sed 's/ type: .*proxies: /#/g' | sed 's/- //g' | grep -E '#DIRECT $|#DIRECT$' | grep -Ev '全球直连|direct|Direct' | awk -F '#' '{print $1}' >"$TMPDIR"/clash_proxies_$USER
        while read line; do
            sed -i "/- $line/d" "$core_config_new"
            sed -i "/- name: $line/,/- DIRECT/d" "$core_config_new"
        done <"$TMPDIR"/clash_proxies_$USER
        rm -rf "$TMPDIR"/clash_proxies_$USER
    }
}
check_singbox_config() { #检查singbox配置文件
    #检测节点或providers
    if ! grep -qE '"(socks|http|shadowsocks(r)?|vmess|trojan|wireguard|hysteria(2)?|vless|shadowtls|tuic|ssh|tor|providers|anytls|soduku)"' "$core_config_new"; then
        echo "-----------------------------------------------"
        logger "获取到了配置文件【$core_config_new】，但似乎并不包含正确的节点信息！" 31
        echo "请尝试使用6-2或者6-3的方式生成配置文件！"
        exit 1
    fi
    #删除不兼容的旧版内容
    [ "$(wc -l <"$core_config_new")" -lt 3 ] && {
        sed -i 's/^.*"inbounds":/{"inbounds":/' "$core_config_new"
        sed -i 's/{[^{}]*"dns-out"[^{}]*}//g' "$core_config_new"
    }
    #检查不支持的旧版内容
    grep -q '"sni"' "$core_config_new" && {
        logger "获取到了不支持的旧版(<1.12)配置文件【$core_config_new】！" 31
        echo "请尝试使用支持1.12以上版本内核的方式生成配置文件！"
        exit 1
    }
    #检测并去除无效策略组
    [ -n "$url_type" ] && {
        #获得无效策略组名称
        grep -oE '\{"type":"urltest","tag":"[^"]*","outbounds":\["DIRECT"\]' "$core_config_new" | sed -n 's/.*"tag":"\([^"]*\)".*/\1/p' >"$TMPDIR"/singbox_tags
        #删除策略组
        sed -i 's/{"type":"urltest","tag":"[^"]*","outbounds":\["DIRECT"\]}//g; s/{"type":"[^"]*","tag":"[^"]*","outbounds":\["DIRECT"\],"url":"[^"]*","interval":"[^"]*","tolerance":[^}]*}//g' "$core_config_new"
        #删除全部包含策略组名称的规则
        while read line; do
            sed -i "s/\"$line\"//g" "$core_config_new"
        done <"$TMPDIR"/singbox_tags
        rm -rf "$TMPDIR"/singbox_tags
    }
    #清理多余逗号
    sed -i 's/,\+/,/g; s/\[,/\[/g; s/,]/]/g' "$core_config_new"
}
update_servers() { #更新servers.list
    get_bin "$TMPDIR"/servers.list public/servers.list
    [ "$?" = 0 ] && mv -f "$TMPDIR"/servers.list "$CRASHDIR"/configs/servers.list
}
get_core_config() { #下载内核配置文件
    [ -z "$rule_link" ] && rule_link=1
    [ -z "$server_link" ] || [ $server_link -gt $(grep -aE '^4' "$CRASHDIR"/configs/servers.list | wc -l) ] && server_link=1
    Server=$(grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
    Server_ua=$(grep -aE '^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $4}')
    Config=$(grep -aE '^5' "$CRASHDIR"/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $3}')
    #如果传来的是Url链接则合成Https链接，否则直接使用Https链接
    if [ -z "$Https" ]; then
        #Urlencord转码处理保留字符
        if ckcmd hexdump;then
			Url=$(echo $Url | sed 's/%26/\&/g')   #处理分隔符
			urlencodeUrl="exclude=$(urlencode "$exclude")&include=$(urlencode "$include")&url=$(urlencode "$Url")&config=$(urlencode "$Config")"
		else
			urlencodeUrl="exclude=$exclude&include=$include&url=$Url&config=$Config"
		fi
        Https="${Server}/sub?target=${target}&${Server_ua}=${user_agent}&insert=true&new_name=true&scv=true&udp=true&${urlencodeUrl}"
        url_type=true
    fi
    #输出
    echo "-----------------------------------------------"
    logger 正在连接服务器获取【${target}】配置文件…………
    echo -e "链接地址为：\033[4;32m$Https\033[0m"
    echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
    #获取在线config文件
    core_config_new="$TMPDIR"/${target}_config.${format}
    rm -rf ${core_config_new}
    $0 webget "$core_config_new" "$Https" echoon rediron skipceron "$user_agent"
    if [ "$?" != "0" ]; then
        if [ -z "$url_type" ]; then
            echo "-----------------------------------------------"
            logger "配置文件获取失败！" 31
            echo -e "\033[31m请尝试使用【在线生成配置文件】功能！\033[0m"
            echo "-----------------------------------------------"
            exit 1
        else
            if [ -n "$retry" ] && [ "$retry" -ge 3 ]; then
                logger "无法获取配置文件，请检查链接格式以及网络连接状态！" 31
                echo -e "\033[32m也可用浏览器下载以上链接后，使用WinSCP手动上传到/tmp目录后执行crash命令本地导入！\033[0m"
                exit 1
            else
                retry=$((retry + 1))
                logger "配置文件获取失败！" 31
                if [ "$retry" = 1 ]; then
                    echo -e "\033[32m尝试更新服务器列表并使用其他服务器获取配置！\033[0m"
                    update_servers
                else
                    echo -e "\033[32m尝试使用其他服务器获取配置！\033[0m"
                fi
                echo -e "正在重试\033[33m第$retry次/共3次！\033[0m"
                if [ "$server_link" -ge 4 ]; then
                    server_link=0
                fi
                server_link=$((server_link + 1))
                setconfig server_link $server_link
                Https=""
                get_core_config
            fi
        fi
    else
        Https=""
        if echo "$crashcore" | grep -q 'singbox'; then
            check_singbox_config
        else
            check_clash_config
        fi
        #如果不同则备份并替换文件
        if [ -s $core_config ]; then
            compare $core_config_new $core_config
            [ "$?" = 0 ] || mv -f $core_config $core_config.bak && mv -f $core_config_new $core_config
        else
            mv -f $core_config_new $core_config
        fi
        echo -e "\033[32m已成功获取配置文件！\033[0m"
    fi
    return 0
}
modify_yaml() { #修饰clash配置文件
    ##########需要变更的配置###########
    [ -z "$skip_cert" ] && skip_cert=已开启
    [ "$ipv6_dns" = "已开启" ] && dns_v6='true' || dns_v6='false'
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
    [ "$sniffer" = "已启用" ] && [ "$crashcore" = "meta" ] && sniffer_set="sniffer: {enable: true, parse-pure-ip: true, skip-domain: [Mijia Cloud], sniff: {http: {ports: [80, 8080-8880], override-destination: true}, tls: {ports: [443, 8443]}, quic: {ports: [443, 8443]}}}"
    [ "$crashcore" = "clashpre" ] && [ "$dns_mod" = "redir_host" -o "$sniffer" = "已启用" ] && exper="experimental: {ignore-resolve-fail: true, interface-name: en0,sniff-tls-sni: true}"
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
EOF
    #读取本机hosts并生成配置文件
    if [ "$hosts_opt" != "未启用" ] && [ -z "$(grep -aE '^hosts:' "$CRASHDIR"/yamls/user.yaml 2>/dev/null)" ]; then
        #NTP劫持
        cat >"$TMPDIR"/hosts.yaml <<EOF
use-system-hosts: true
hosts:
  'time.android.com': 203.107.6.88
  'time.facebook.com': 203.107.6.88
EOF
        if [ "$crashcore" = "meta" ]; then
            echo "  'services.googleapis.cn': services.googleapis.com" >>"$TMPDIR"/hosts.yaml
        else
            #加载本机hosts
            sys_hosts=/etc/hosts
            [ -f /data/etc/custom_hosts ] && sys_hosts=/data/etc/custom_hosts
            while read line; do
                [ -n "$(echo "$line" | grep -oE "([0-9]{1,3}[\.]){3}")" ] &&
                    [ -z "$(echo "$line" | grep -oE '^#')" ] &&
                    hosts_ip=$(echo $line | awk '{print $1}') &&
                    hosts_domain=$(echo $line | awk '{print $2}') &&
                    [ -z "$(cat "$TMPDIR"/hosts.yaml | grep -oE "$hosts_domain")" ] &&
                    echo "  '$hosts_domain': $hosts_ip" >>"$TMPDIR"/hosts.yaml
            done <$sys_hosts
        fi
    fi
    #分割配置文件
    yaml_char='proxies proxy-groups proxy-providers rules rule-providers sub-rules listeners'
    for char in $yaml_char; do
        sed -n "/^$char:/,/^[a-z]/ { /^[a-z]/d; p; }" $core_config >"$TMPDIR"/${char}.yaml
    done
    #跳过本地tls证书验证
    [ "$skip_cert" = "已开启" ] && sed -i 's/skip-cert-verify: false/skip-cert-verify: true/' "$TMPDIR"/proxies.yaml ||
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
    [ "$proxies_bypass" = "已启用" ] && {
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
    [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ] && ! grep -q 'cn:' "$TMPDIR"/rule-providers.yaml && ! grep -q '^rule-providers' "$CRASHDIR"/yamls/others.yaml 2>/dev/null && {
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
        for char in mode allow-lan log-level tun experimental external-ui-url interface-name dns store-selected; do
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
modify_json() { #修饰singbox1.13配置文件
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
	[ "$ts_service" = ON ] || [ "$wg_service" = ON ] && {
		. "$CRASHDIR"/configs/gateway.cfg
		. "$CRASHDIR"/libs/sb_endpoints.sh
	}
	#生成log.json
    cat >"$TMPDIR"/jsons/log.json <<EOF
{ "log": { "level": "info", "timestamp": true } }
EOF
    #生成add_hosts.json
    if [ "$hosts_opt" != "未启用" ]; then #本机hosts
        sys_hosts=/etc/hosts
        [ -s /data/etc/custom_hosts ] && sys_hosts=/data/etc/custom_hosts
        #NTP劫持
        cat >"$TMPDIR"/jsons/add_hosts.json <<EOF
{
  "dns": {
    "servers": [
      {
        "type": "hosts",
        "tag": "hosts",
        "path": [
          "$sys_hosts",
          "$HOME/.hosts"
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
    [ "$ipv6_dns" = "已开启" ] && strategy='prefer_ipv4' || strategy='ipv4_only'
    #获取detour出口
    auto_detour=$(grep -E '"type": "urltest"' -A 1 "$TMPDIR"/jsons/outbounds.json | grep '"tag":' | head -n 1 | sed 's/^[[:space:]]*"tag": //;s/,$//')
    [ -z "$auto_detour" ] && auto_detour=$(grep -E '"type": "selector"' -A 1 "$TMPDIR"/jsons/outbounds.json | grep '"tag":' | head -n 1 | sed 's/^[[:space:]]*"tag": //;s/,$//')
    [ -z "$auto_detour" ] && auto_detour='"DIRECT"'
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
    [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ] &&
        [ -z "$(cat "$CRASHDIR"/jsons/*.json | grep -Ei '"tag" *: *"cn"')" ] &&
        cat >"$TMPDIR"/jsons/add_rule_set.json <<EOF
{
  "route": {
    "rule_set": [
      {
        "tag": "cn",
        "type": "local",
        "path": "./ruleset/cn.srs"
      }
    ]
  }
}
EOF
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
    "reverse_mapping": true
  }
}
EOF
    #生成add_route.json
    #域名嗅探配置
    [ "$sniffer" = "已启用" ] && sniffer_set='{ "inbound": [ "redirect-in", "tproxy-in", "tun-in" ], "action": "sniff", "timeout": "500ms" },'
	[ "advertise_exit_node" = true ] && tailscale_set='{ "inbound": [ "ts-ep" ], "port": 53, "action": "hijack-dns" },'
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
        [ "ipv6_redir" = '已开启' ] && ipv6_address='"fe80::e5c5:2469:d09b:609a/64",'
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
    if [ -z "$skip_cert" -o "$skip_cert" = "已开启" ]; then
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

#设置路由规则
cn_ip_route() { #CN-IP绕过
    ckgeo cn_ip.txt china_ip_list.txt
    [ -f "$BINDIR"/cn_ip.txt ] && [ "$firewall_mod" = iptables ] && {
        # see https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/CN-ip-cidr.txt
        echo "create cn_ip hash:net family inet hashsize 10240 maxelem 10240" >"$TMPDIR"/cn_ip.ipset
        awk '!/^$/&&!/^#/{printf("add cn_ip %s'" "'\n",$0)}' "$BINDIR"/cn_ip.txt >>"$TMPDIR"/cn_ip.ipset
        ipset destroy cn_ip >/dev/null 2>&1
        ipset -! restore <"$TMPDIR"/cn_ip.ipset
        rm -rf "$TMPDIR"/cn_ip.ipset
    }
}
cn_ipv6_route() { #CN-IPV6绕过
    ckgeo cn_ipv6.txt china_ipv6_list.txt
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
#启动相关
web_save() { #最小化保存面板节点选择
    #使用get_save获取面板节点设置
    get_save http://127.0.0.1:${db_port}/proxies | sed 's/:{/!/g' | awk -F '!' '{for(i=1;i<=NF;i++) print $i}' | grep -aE '"Selector"' | grep -aoE '"name":.*"now":".*",' >"$TMPDIR"/web_proxies
    [ -s "$TMPDIR"/web_proxies ] && while read line; do
        def=$(echo $line | grep -oE '"all".*",' | awk -F "[\"]" '{print $4}')
        now=$(echo $line | grep -oE '"now".*",' | awk -F "[\"]" '{print $4}')
        [ "$def" != "$now" ] && {
            name=$(echo $line | grep -oE '"name".*",' | awk -F "[\"]" '{print $4}')
            echo "${name},${now}" >>"$TMPDIR"/web_save
        }
    done <"$TMPDIR"/web_proxies
    rm -rf "$TMPDIR"/web_proxies
    #获取面板设置
    #[ "$crashcore" != singbox ] && get_save http://127.0.0.1:${db_port}/configs > "$TMPDIR"/web_configs
    #对比文件，如果有变动且不为空则写入磁盘，否则清除缓存
    for file in web_save web_configs; do
        if [ -s "$TMPDIR"/${file} ]; then
            compare "$TMPDIR"/${file} "$CRASHDIR"/configs/${file}
            [ "$?" = 0 ] && rm -rf "$TMPDIR"/${file} || mv -f "$TMPDIR"/${file} "$CRASHDIR"/configs/${file}
        fi
    done
}
web_restore() { #还原面板选择
    #设置循环检测面板端口以判定服务启动是否成功
    test=""
    i=1
    while [ -z "$test" -a "$i" -lt 30 ]; do
        test=$(get_save http://127.0.0.1:${db_port}/proxies | grep -o proxies)
        i=$((i + 1))
        sleep 2
    done
    [ -n "$test" ] && {
        #发送节点选择数据
        [ -s "$CRASHDIR"/configs/web_save ] && {
            num=$(cat "$CRASHDIR"/configs/web_save | wc -l)
            i=1
            while [ "$i" -le "$num" ]; do
                group_name=$(awk -F ',' 'NR=="'${i}'" {print $1}' "$CRASHDIR"/configs/web_save | sed 's/ /%20/g')
                now_name=$(awk -F ',' 'NR=="'${i}'" {print $2}' "$CRASHDIR"/configs/web_save)
                put_save http://127.0.0.1:${db_port}/proxies/${group_name} "{\"name\":\"${now_name}\"}"
                i=$((i + 1))
            done
        }
        #还原面板设置
        #[ "$crashcore" != singbox ] && [ -s "$CRASHDIR"/configs/web_configs ] && {
        #sleep 5
        #put_save http://127.0.0.1:${db_port}/configs "$(cat "$CRASHDIR"/configs/web_configs)" PATCH
        #}
    }
}
makehtml() { #生成面板跳转文件
    cat >"$BINDIR"/ui/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="0">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ShellCrash面板提示</title>
</head>
<body>
    <div style="text-align: center; margin-top: 50px;">
        <h1>您还未安装本地面板</h1>
		<h3>请在脚本更新功能中(9-4)安装<br>或者使用在线面板：</h3>
		<h4>请复制当前地址/ui(不包括)前面的内容，填入url位置即可连接</h3>
        <a href="http://board.zash.run.place" style="font-size: 24px;">Zashboard面板(推荐)<br></a>
        <a style="font-size: 21px;"><br>如已安装，请使用Ctrl+F5强制刷新此页面！<br></a>
    </div>
</body>
</html
EOF
}
catpac() { #生成pac文件
    #获取本机host地址
    [ -n "$host" ] && host_pac=$host
    [ -z "$host_pac" ] && host_pac=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    [ -z "$host_pac" ] && host_pac=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
    cat >"$TMPDIR"/shellcrash_pac <<EOF
function FindProxyForURL(url, host) {
	if (
		isInNet(host, "0.0.0.0", "255.0.0.0")||
		isInNet(host, "10.0.0.0", "255.0.0.0")||
		isInNet(host, "127.0.0.0", "255.0.0.0")||
		isInNet(host, "224.0.0.0", "224.0.0.0")||
		isInNet(host, "240.0.0.0", "240.0.0.0")||
		isInNet(host, "172.16.0.0",  "255.240.0.0")||
		isInNet(host, "192.168.0.0", "255.255.0.0")||
		isInNet(host, "169.254.0.0", "255.255.0.0")
	)
		return "DIRECT";
	else
		return "PROXY $host_pac:$mix_port; DIRECT; SOCKS5 $host_pac:$mix_port"
}
EOF
    compare "$TMPDIR"/shellcrash_pac "$BINDIR"/ui/pac
    [ "$?" = 0 ] && rm -rf "$TMPDIR"/shellcrash_pac || mv -f "$TMPDIR"/shellcrash_pac "$BINDIR"/ui/pac
}
core_check() { #检查及下载内核文件
    [ -n "$(tar --help 2>&1 | grep -o 'no-same-owner')" ] && tar_para='--no-same-owner' #tar命令兼容
    [ -n "$(find --help 2>&1 | grep -o size)" ] && find_para=' -size +2000'             #find命令兼容
    tar_core() {
        mkdir -p "$TMPDIR"/core_tmp
        tar -zxf "$1" ${tar_para} -C "$TMPDIR"/core_tmp/
        for file in $(find "$TMPDIR"/core_tmp $find_para 2>/dev/null); do
            [ -f $file ] && [ -n "$(echo $file | sed 's#.*/##' | grep -iE '(CrashCore|sing|meta|mihomo|clash|pre)')" ] && mv -f $file "$TMPDIR"/"$2"
        done
        rm -rf "$TMPDIR"/core_tmp
    }
    [ -z "$(find "$TMPDIR"/CrashCore $find_para 2>/dev/null)" ] && [ -n "$(find "$BINDIR"/CrashCore $find_para 2>/dev/null)" ] && mv "$BINDIR"/CrashCore "$TMPDIR"/CrashCore
    [ -z "$(find "$TMPDIR"/CrashCore $find_para 2>/dev/null)" ] && [ -n "$(find "$BINDIR"/CrashCore.tar.gz $find_para 2>/dev/null)" ] &&
        tar_core "$BINDIR"/CrashCore.tar.gz CrashCore
    [ -z "$(find "$TMPDIR"/CrashCore $find_para 2>/dev/null)" ] && {
        logger "未找到【$crashcore】核心，正在下载！" 33
        [ -z "$cpucore" ] && . "$CRASHDIR"/webget.sh && getcpucore
        [ -z "$cpucore" ] && logger 找不到设备的CPU信息，请手动指定处理器架构类型！ 31 && exit 1
        get_bin "$TMPDIR"/CrashCore.tar.gz "bin/$crashcore/${target}-linux-${cpucore}.tar.gz"
        #校验内核
        tar_core "$TMPDIR"/CrashCore.tar.gz core_new
        chmod +x "$TMPDIR"/core_new
        if echo "$crashcore" | grep -q 'singbox'; then
            core_v=$("$TMPDIR"/core_new version 2>/dev/null | grep version | awk '{print $3}')
            COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
        else
            core_v=$("$TMPDIR"/core_new -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
            COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
        fi
        if [ -z "$core_v" ]; then
            rm -rf "$TMPDIR"/CrashCore
            logger "核心下载失败，请重新运行或更换安装源！" 31
            exit 1
        else
            mv -f "$TMPDIR"/core_new "$TMPDIR"/CrashCore
            mv -f "$TMPDIR"/CrashCore.tar.gz "$BINDIR"/CrashCore.tar.gz
            setconfig COMMAND "$COMMAND" "$CRASHDIR"/configs/command.env && . "$CRASHDIR"/configs/command.env
            setconfig crashcore $crashcore
            setconfig core_v $core_v
        fi
    }
    [ ! -x "$TMPDIR"/CrashCore ] && chmod +x "$TMPDIR"/CrashCore 2>/dev/null                               #自动授权
    [ "$start_old" != "已开启" -a "$(cat /proc/1/comm)" = "systemd" ] && restorecon -RF $CRASHDIR 2>/dev/null #修复SELinux权限问题
    return 0
}
core_exchange() { #升级为高级内核
    #$1：目标内核  $2：提示语句
    logger "检测到${2}！将改为使用${1}核心启动！" 33
    rm -rf "$TMPDIR"/CrashCore
    rm -rf "$BINDIR"/CrashCore
    rm -rf "$BINDIR"/CrashCore.tar.gz
    crashcore="$1"
    setconfig crashcore "$1"
    echo "-----------------------------------------------"
}
clash_check() { #clash启动前检查
    #检测vless/hysteria协议
    [ "$crashcore" != "meta" ] && [ -n "$(cat $core_config | grep -oE 'type: vless|type: hysteria')" ] && core_exchange meta 'vless/hy协议'
    #检测是否存在高级版规则或者tun模式
    if [ "$crashcore" = "clash" ]; then
        [ -n "$(cat $core_config | grep -aiE '^script:|proxy-providers|rule-providers|rule-set')" ] ||
            [ "$redir_mod" = "混合模式" ] ||
            [ "$redir_mod" = "Tun模式" ] && core_exchange meta '当前内核不支持的配置'
    fi
    [ "$crashcore" = "clash" ] && [ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && [ -z "$(grep '0:7890' /etc/passwd)" ] &&
        core_exchange meta '当前内核不支持非root用户启用本机代理'
    core_check
    #预下载GeoIP数据库并排除存在自定义数据库链接的情况
    [ -n "$(grep -oEi 'geoip:' "$CRASHDIR"/yamls/*.yaml)" ] && [ -z "$(grep -oEi 'geoip:|mmdb:' "$CRASHDIR"/yamls/*.yaml)" ] && ckgeo Country.mmdb cn_mini.mmdb
    #预下载GeoSite数据库并排除存在自定义数据库链接的情况
    [ -n "$(grep -oEi 'geosite:' "$CRASHDIR"/yamls/*.yaml)" ] && [ -z "$(grep -oEi 'geosite:' "$CRASHDIR"/yamls/*.yaml)" ] && ckgeo GeoSite.dat geosite.dat
    #预下载cn.mrs数据库
    [ -n "$(cat "$CRASHDIR"/yamls/*.yaml | grep -oEi 'rule_set.*cn')" -o "$dns_mod" = "mix" ] && ckgeo ruleset/cn.mrs mrs_geosite_cn.mrs
    return 0
}
singbox_check() { #singbox启动前检查
    #检测singboxr专属功能
    [ "$crashcore" != "singboxr" ] && [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oE '"shadowsocksr"|"providers"')" ] && core_exchange singboxr 'singboxr内核专属功能'
    core_check
    #预下载geoip-cn.srs数据库
    [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"rule_set" *: *"geoip-cn"')" ] && ckgeo ruleset/geoip-cn.srs srs_geoip_cn.srs
    #预下载cn.srs数据库
    [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"rule_set" *: *"cn"')" -o "$dns_mod" = "mix" ] && ckgeo ruleset/cn.srs srs_geosite_cn.srs
    return 0
}
network_check() { #检查是否联网
    for text in 223.5.5.5 1.2.4.8 dns.alidns.com doh.pub; do
        ping -c 3 $text >/dev/null 2>&1 && return 0
        sleep 5
    done
    logger "当前设备无法连接网络，已停止启动！" 33
    exit 1
}
bfstart() { #启动前
    routing_mark=$((fwmark + 2))
    #检测网络连接
    [ "$network_check" != "已禁用" ] && [ ! -f "$TMPDIR"/crash_start_time ] && ckcmd ping && network_check
    [ ! -d "$BINDIR"/ui ] && mkdir -p "$BINDIR"/ui
    [ -z "$crashcore" ] && crashcore=meta
    #执行条件任务
    [ -s "$CRASHDIR"/task/bfstart ] && . "$CRASHDIR"/task/bfstart
    #检查内核配置文件
    if [ ! -f $core_config ]; then
        if [ -n "$Url" -o -n "$Https" ]; then
            logger "未找到配置文件，正在下载！" 33
            get_core_config
        else
            logger "未找到配置文件链接，请先导入配置文件！" 31
            exit 1
        fi
    fi
    #检查dashboard文件
    if [ -f "$CRASHDIR"/ui/CNAME -a ! -f "$BINDIR"/ui/CNAME ]; then
        cp -rf "$CRASHDIR"/ui "$BINDIR"
    fi
    [ ! -s "$BINDIR"/ui/index.html ] && makehtml #如没有面板则创建跳转界面
    catpac                                       #生成pac文件
    #内核及内核配置文件检查
    if echo "$crashcore" | grep -q 'singbox'; then
        singbox_check
        [ -d "$TMPDIR"/jsons ] && rm -rf "$TMPDIR"/jsons/* || mkdir -p "$TMPDIR"/jsons #准备目录
        [ "$disoverride" != "1" ] && modify_json || ln -sf $core_config "$TMPDIR"/jsons/config.json
    else
        clash_check
        [ "$disoverride" != "1" ] && modify_yaml || ln -sf $core_config "$TMPDIR"/config.yaml
    fi
    #检查下载cnip绕过相关文件
    [ "$firewall_mod" = nftables ] || ckcmd ipset && [ "$dns_mod" != "fake-ip" ] && {
        [ "$cn_ip_route" = "已开启" ] && cn_ip_route
        [ "$ipv6_redir" = "已开启" ] && [ "$cn_ip_route" = "已开启" ] && cn_ipv6_route
    }
    #添加shellcrash用户
    [ "$firewall_area" = 2 ] || [ "$firewall_area" = 3 ] || [ "$(cat /proc/1/comm)" = "systemd" ] &&
        [ -z "$(id shellcrash 2>/dev/null | grep 'root')" ] && {
        ckcmd userdel && userdel shellcrash 2>/dev/null
        sed -i '/0:7890/d' /etc/passwd
        sed -i '/x:7890/d' /etc/group
        if ckcmd useradd; then
            useradd shellcrash -u 7890
            sed -Ei s/7890:7890/0:7890/g /etc/passwd
        else
            echo "shellcrash:x:0:7890:::" >>/etc/passwd
        fi
    }
    #清理debug日志
    rm -rf "$TMPDIR"/debug.log
    rm -rf "$CRASHDIR"/debug.log
    return 0
}
afstart() { #启动后
    [ -z "$firewall_area" ] && firewall_area=1
    #延迟启动
    [ ! -f "$TMPDIR"/crash_start_time ] && [ -n "$start_delay" ] && [ "$start_delay" -gt 0 ] && {
        logger "ShellCrash将延迟$start_delay秒启动" 31
        sleep $start_delay
    }
    #设置循环检测面板端口以判定服务启动是否成功
    i=1
    while [ -z "$test" -a "$i" -lt 30 ]; do
        echo "$i" | grep -q '10' && echo -ne "服务正在启动，请耐心等待！\r"
        sleep 1
        if curl --version >/dev/null 2>&1; then
            test=$(curl -s -H "Authorization: Bearer $secret" http://127.0.0.1:${db_port}/configs | grep -o port)
        else
            test=$(wget -q --header="Authorization: Bearer $secret" -O - http://127.0.0.1:${db_port}/configs | grep -o port)
        fi
        i=$((i + 1))
    done
    if [ -n "$test" -o -n "$(pidof CrashCore)" ]; then
        [ "$start_old" = "已开启" ] && rm -rf "$TMPDIR"/CrashCore               #删除缓存目录内核文件
        start_firewall														#配置防火墙流量劫持
        mark_time                                                            #标记启动时间
        [ -s "$CRASHDIR"/configs/web_save ] && web_restore >/dev/null 2>&1 & #后台还原面板配置
        {
            sleep 5
            logger ShellCrash服务已启动！
        } &                                                           #推送日志
        ckcmd mtd_storage.sh && mtd_storage.sh save >/dev/null 2>&1 & #Padavan保存/etc/storage
        #加载定时任务
        [ -s "$CRASHDIR"/task/cron ] && croncmd "$CRASHDIR"/task/cron
        [ -s "$CRASHDIR"/task/running ] && {
            cronset '运行时每'
            while read line; do
                cronset '2fjdi124dd12s' "$line"
            done <"$CRASHDIR"/task/running
        }
        [ "$start_old" = "已开启" ] && cronset '保守模式守护进程' "* * * * * test -z \"\$(pidof CrashCore)\" && "$CRASHDIR"/start.sh daemon #ShellCrash保守模式守护进程"
        #加载条件任务
        [ -s "$CRASHDIR"/task/afstart ] && { . "$CRASHDIR"/task/afstart; } &
        [ -s "$CRASHDIR"/task/affirewall -a -s /etc/init.d/firewall -a ! -f /etc/init.d/firewall.bak ] && {
            #注入防火墙
            line=$(grep -En "fw.* restart" /etc/init.d/firewall | cut -d ":" -f 1)
            sed -i.bak "${line}a\\. "$CRASHDIR"/task/affirewall" /etc/init.d/firewall
            line=$(grep -En "fw.* start" /etc/init.d/firewall | cut -d ":" -f 1)
            sed -i "${line}a\\. "$CRASHDIR"/task/affirewall" /etc/init.d/firewall
        } &
		#启动TG机器人
		[ "$bot_tg_service" = ON ] && "$CRASHDIR"/menus/bot_tg.sh &
    else
        start_error
        $0 stop
    fi
}
start_error() { #启动报错
    if [ "$start_old" != "已开启" ] && ckcmd journalctl; then
        journalctl -u shellcrash >$TMPDIR/core_test.log
    else
        PID=$(pidof CrashCore) && [ -n "$PID" ] && kill -9 $PID >/dev/null 2>&1
        ${COMMAND} >"$TMPDIR"/core_test.log 2>&1 &
        sleep 2
        kill $! >/dev/null 2>&1
    fi
    error=$(cat $TMPDIR/core_test.log | grep -iEo 'error.*=.*|.*ERROR.*|.*FATAL.*')
    logger "服务启动失败！请查看报错信息！详细信息请查看$TMPDIR/core_test.log" 33
    logger "$error" 31
    exit 1
}
start_old() { #保守模式
    #使用传统后台执行二进制文件的方式执行
    if ckcmd su && [ -n "$(grep 'shellcrash:x:0:7890' /etc/passwd)" ]; then
        su shellcrash -c "$COMMAND >/dev/null 2>&1" &
    else
        ckcmd nohup && local nohup=nohup
        $nohup $COMMAND >/dev/null 2>&1 &
    fi
    afstart &
}
#杂项
update_config() { #更新订阅并重启
    get_core_config &&
        $0 restart
}
hotupdate() { #热更新订阅
    get_core_config
    core_check
    modify_$format &&
        put_save http://127.0.0.1:${db_port}/configs "{\"path\":\""$CRASHDIR"/config.$format\"}"
    rm -rf "$TMPDIR"/CrashCore
}

getconfig #读取配置及全局变量

case "$1" in

start)
    [ -n "$(pidof CrashCore)" ] && $0 stop #禁止多实例
    stop_firewall                          #清理路由策略
    #使用不同方式启动服务
	if [ "$firewall_area" = "5" ]; then #主旁转发
        start_firewall
    elif [ "$start_old" = "已开启" ]; then
        bfstart && start_old
    elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
        /etc/init.d/shellcrash start
    elif [ "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ]; then
        bfstart && {
            FragmentPath=$(systemctl show -p FragmentPath shellcrash | sed 's/FragmentPath=//')
            [ -f $FragmentPath ] && setconfig ExecStart "$COMMAND >/dev/null" "$FragmentPath"
            systemctl daemon-reload
            systemctl start shellcrash.service || start_error
        }
    elif grep -q 's6' /proc/1/comm; then
		bfstart && /command/s6-svc -u /run/service/shellcrash && {
			[ ! -f "$CRASHDIR"/.dis_startup ] && touch /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
			afstart &
		}
    elif rc-status -r >/dev/null 2>&1; then
        rc-service shellcrash stop >/dev/null 2>&1
        rc-service shellcrash start
    else
        bfstart && start_old
    fi
    ;;
stop)
    logger ShellCrash服务即将关闭……
    [ -n "$(pidof CrashCore)" ] && web_save #保存面板配置
    #删除守护进程&面板配置自动保存
    cronset '保守模式守护进程'
    cronset '运行时每'
    cronset '流媒体预解析'
    #多种方式结束进程

    if [ "$start_old" != "已开启" -a "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ]; then
        systemctl stop shellcrash.service >/dev/null 2>&1
    elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
        /etc/init.d/shellcrash stop >/dev/null 2>&1
    elif grep -q 's6' /proc/1/comm; then
		/command/s6-svc -d /run/service/shellcrash
		stop_firewall
    elif rc-status -r >/dev/null 2>&1; then
        rc-service shellcrash stop >/dev/null 2>&1
    else
        stop_firewall #清理路由策略
    fi
    PID=$(pidof CrashCore) && [ -n "$PID" ] && kill -9 $PID >/dev/null 2>&1
	PID=$(pidof /bin/sh "$CRASHDIR"/menus/bot_tg.sh) && [ -n "$PID" ] && kill -9 $PID >/dev/null 2>&1
    #清理缓存目录
    rm -rf "$TMPDIR"/CrashCore
    ;;
restart)
    $0 stop
    $0 start
    ;;
daemon)
    if [ -f $TMPDIR/crash_start_time ]; then
        $0 start
    else
        sleep 60 && touch $TMPDIR/crash_start_time
    fi
    ;;
debug)
    [ -n "$(pidof CrashCore)" ] && $0 stop >/dev/null #禁止多实例
    stop_firewall >/dev/null                          #清理路由策略
    bfstart
    if [ -n "$2" ]; then
        if echo "$crashcore" | grep -q 'singbox'; then
            sed -i "s/\"level\": \"info\"/\"level\": \"$2\"/" "$TMPDIR"/jsons/log.json 2>/dev/null
        else
            sed -i "s/log-level: info/log-level: $2/" "$TMPDIR"/config.yaml
        fi
        [ "$3" = flash ] && dir=$CRASHDIR || dir=$TMPDIR
        $COMMAND >${dir}/debug.log 2>&1 &
        sleep 2
        logger "已运行debug模式!如需停止，请使用重启/停止服务功能！" 33
    else
        $COMMAND >/dev/null 2>&1 &
    fi
    afstart
    ;;
init)
    if [ -d "/etc/storage/clash" -o -d "/etc/storage/ShellCrash" ]; then
        i=1
        while [ ! -w /etc/profile -a "$i" -lt 10 ]; do
            sleep 3 && i=$((i + 1))
        done
        [ -w /etc/profile ] && profile=/etc/profile || profile=/etc_ro/profile
        mount -t tmpfs -o remount,rw,size=45M tmpfs /tmp #增加/tmp空间以适配新的内核压缩方式
        sed -i '' $profile                               #将软链接转化为一般文件
    elif [ -d "/jffs" ]; then
        sleep 60
        if [ -w /etc/profile ]; then
            profile=/etc/profile
        else
            profile=$(cat /etc/profile | grep -oE '\-f.*jffs.*profile' | awk '{print $2}')
        fi
    fi
    [ -z "$my_alias" ] && my_alias=crash
    sed -i "/ShellCrash\/menu.sh/"d "$profile"
    echo "alias ${my_alias}=\"sh $CRASHDIR/menu.sh\"" >>"$profile"
    sed -i "/export CRASHDIR/d" "$profile"
    echo "export CRASHDIR=\"$CRASHDIR\"" >>"$profile"
    [ -f "$CRASHDIR"/.dis_startup ] && cronset "保守模式守护进程" || $0 start
    ;;
webget)
    #设置临时代理
    if pidof CrashCore >/dev/null; then
		[ -n "$authentication" ] && auth="$authentication@" || auth=""
        export all_proxy="http://${auth}127.0.0.1:$mix_port"
		url=$(printf '%s\n' "$3" |
        sed -e 's#https://.*jsdelivr.net/gh/juewuy/ShellCrash[@|/]#https://raw.githubusercontent.com/juewuy/ShellCrash/#' \
            -e 's#https://gh.jwsc.eu.org/#https://raw.githubusercontent.com/juewuy/ShellCrash/#')
	else
		url=$(printf '%s\n' "$3" |
        sed 's#https://raw.githubusercontent.com/juewuy/ShellCrash/#https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@#')
	fi
    #参数【$2】代表下载目录，【$3】代表在线地址
    #参数【$4】代表输出显示，【$5】不启用重定向
    #参数【$6】代表验证证书，【$7】使用自定义UA
    [ -n "$7" ] && agent="--user-agent \"$7\""
	if wget --help 2>&1 | grep -q 'show-progress' >/dev/null 2>&1; then
		[ "$4" = "echooff" ] && progress='-q' || progress='-q --show-progress'
		[ "$5" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
		[ "$6" = "skipceroff" ] && certificate='' || certificate='--no-check-certificate'
        wget -Y on $agent $progress $redirect $certificate --timeout=3 -O "$2" "$url" && exit 0 #成功则退出否则重试
		wget -Y off $agent $progress $redirect $certificate --timeout=5 -O "$2" "$3"
		exit $?
    elif curl --version >/dev/null 2>&1; then
        [ "$4" = "echooff" ] && progress='-s' || progress='-#'
        [ "$5" = "rediroff" ] && redirect='' || redirect='-L'
        [ "$6" = "skipceroff" ] && certificate='' || certificate='-k'
        if curl --version | grep -q '^curl 8.' && ckcmd base64; then
            auth_b64=$(printf '%s' "$authentication" | base64)
            result=$(curl $agent -w '%{http_code}' --connect-timeout 3 --proxy-header "Proxy-Authorization: Basic $auth_b64" $progress $redirect $certificate -o "$2" "$url")
        else
            result=$(curl $agent -w '%{http_code}' --connect-timeout 3 $progress $redirect $certificate -o "$2" "$url")
        fi
        [ "$result" = "200" ] && exit 0 #成功则退出否则重试
		export all_proxy=""
		result=$(curl $agent -w '%{http_code}' --connect-timeout 5 $progress $redirect $certificate -o "$2" "$3")
		[ "$result" = "200" ]
		exit $?
    elif ckcmd wget;then
        [ "$4" = "echooff" ] && progress='-q'
        wget -Y on $progress -O "$2" "$url" && exit 0 #成功则退出否则重试
        wget -Y off $progress -O "$2" "$3"
		exit $?
	else
		echo "找不到可用下载工具！！！请安装Curl或Wget！！！"
		exit 1
    fi
    ;;
*)
    "$1" "$2" "$3" "$4" "$5" "$6" "$7"
    ;;

esac
