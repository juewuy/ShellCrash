
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
    check_core
    #预下载GeoIP数据库并排除存在自定义数据库链接的情况
    [ -n "$(grep -oEi 'geoip:' "$CRASHDIR"/yamls/config.yaml)" ] && check_geo Country.mmdb cn_mini.mmdb
    #预下载GeoSite数据库并排除存在自定义数据库链接的情况
    [ -n "$(grep -oEi 'geosite:' "$CRASHDIR"/yamls/config.yaml)" ] && check_geo GeoSite.dat geosite.dat
    #预下载cn.mrs数据库
    [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ] && ! grep -Eq '^[[:space:]]*cn:' "$CRASHDIR"/yamls/*.yaml && check_geo ruleset/cn.mrs mrs_geosite_cn.mrs
    return 0
}
