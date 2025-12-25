#!/bin/sh
# Copyright (C) Juewuy

check_config() { #检查clash配置文件
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
        cat "$core_config_new" | sed '/^rules:/,$d' | grep -A 15 "\- name:" | xargs | sed 's/- name: /\n/g' | sed 's/ type: .*proxies: /#/g' | sed 's/- //g' | grep -E '#DIRECT $|#DIRECT$' | grep -Ev '全球直连|direct|Direct' | awk -F '#' '{print $1}' >"$TMPDIR"/clash_proxies
        while read line; do
            sed -i "/- $line/d" "$core_config_new"
            sed -i "/- name: $line/,/- DIRECT/d" "$core_config_new"
        done <"$TMPDIR"/clash_proxies
        rm -rf "$TMPDIR"/clash_proxies
    }
}