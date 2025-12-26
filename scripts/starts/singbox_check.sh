
singbox_check() { #singbox启动前检查
    #检测singboxr专属功能
    [ "$crashcore" != "singboxr" ] && [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oE '"shadowsocksr"|"providers"')" ] && {
		. "$CRASHDIR"/starts/core_exchange.sh && core_exchange singboxr 'singboxr内核专属功能'
	}
    check_core
    #预下载cn.srs数据库
    [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ] && ! grep -Eq '"tag" *:[[:space:]]*"cn"' "$CRASHDIR"/jsons/*.json && check_geo ruleset/cn.srs srs_geosite_cn.srs
    return 0
}