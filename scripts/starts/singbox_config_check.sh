#!/bin/sh
# Copyright (C) Juewuy

check_config() { #检查singbox配置文件
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
