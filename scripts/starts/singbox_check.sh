
singbox_check() { #singbox启动前检查
    #检测singboxr专属功能
    [ "$crashcore" != "singboxr" ] && [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oE '"shadowsocksr"|"providers"')" ] && {
		. "$CRASHDIR"/starts/core_exchange.sh && core_exchange singboxr 'singboxr内核专属功能'
	}
    check_core
    #预下载geoip-cn.srs数据库
    [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"rule_set" *: *"geoip-cn"')" ] && check_geo ruleset/geoip-cn.srs srs_geoip_cn.srs
    #预下载cn.srs数据库
    [ -n "$(cat "$CRASHDIR"/jsons/*.json | grep -oEi '"rule_set" *: *"cn"')" ] || [ "$dns_mod" = "mix" ] || [ "$dns_mod" = "route" ] && check_geo ruleset/cn.srs srs_geosite_cn.srs
    return 0
}