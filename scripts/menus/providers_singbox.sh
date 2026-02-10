#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_PROVIDERS_SINGBOX" ] && return
__IS_PROVIDERS_SINGBOX=1

. "$CRASHDIR"/libs/web_get_bin.sh

# 生成singbox的providers配置文件
gen_providers() {
    if [ -z "$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg)" ]; then
        provider_temp_file="$(sed -n "1 p" "$CRASHDIR"/configs/"${CORE_TYPE}"_providers.list | awk '{print $2}')"
    else
        provider_temp_file=$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
    fi
    if [ -s "$provider_temp_file" ]; then
        ln -sf "$provider_temp_file" "$TMPDIR"/provider_temp_file
    else
        msg_alert "\033[33m正在获取在线模版......\033[0m"
        get_bin "$TMPDIR"/provider_temp_file "rules/${CORE_TYPE}_providers/$provider_temp_file"
        [ -z "$(grep -o 'route' "$TMPDIR"/provider_temp_file)" ] && {
            msg_alert "\033[31m下载失败，请尝试更换安装源！\033[0m"
            . "$CRASHDIR"/menus/9_upgrade.sh && setserver
            setproviders
        }
    fi
    # 生成outbound_providers模块
    mkdir -p "$TMPDIR"/providers
    # 预创建文件并写入对应文件头
    cat >"$TMPDIR"/providers/providers.json <<EOF
{
  "providers": [
EOF
    cat >"$TMPDIR"/providers/outbounds_add.json <<EOF
{
  "outbounds": [
EOF
    # 基于单订阅生成providers模块
    if [ -n "$1" ]; then
        gen_providers_txt "$@"
        providers_tags=\"$1\"
    else
        # 基于全部订阅/本地文件生成
        [ -s "$CRASHDIR"/configs/providers.cfg ] && {
            providers_tags=''
            while read -r line; do
                gen_providers_txt $line
                providers_tags=$(echo "$providers_tags, \"$tag\"" | sed 's/^, //')
            done <"$CRASHDIR"/configs/providers.cfg
        }
        # 基于全部节点分享链接生成
        [ -s "$CRASHDIR"/configs/providers_uri.cfg ] && {
            mkdir -p "$CRASHDIR"/providers
            awk '{ print ($1=="vmess" ? $2 : $2 "#" $1) }' "$CRASHDIR"/configs/providers_uri.cfg >"$CRASHDIR"/providers/uri_group
            gen_providers_txt "Uri_group" "./providers/uri_group" "3" "12"
            providers_tags=$(echo "$providers_tags, \"Uri_group\"" | sed 's/^, //')
        }
    fi
    # 修复文件格式
    sed -i '$s/},/}]}/' "$TMPDIR"/providers/outbounds_add.json
    sed -i '$s/},/}]}/' "$TMPDIR"/providers/providers.json
    # 使用模版生成outbounds和rules模块
    cat "$TMPDIR"/provider_temp_file | sed "s/{providers_tags}/$providers_tags/g" | sed "s/\"providers_tags\"/$providers_tags/g" >"$TMPDIR"/providers/outbounds.json
    rm -rf "$TMPDIR"/provider_temp_file
    # 调用内核测试
    . "$CRASHDIR"/starts/check_core.sh && check_core && "$TMPDIR"/CrashCore merge "$TMPDIR"/config.json -C "$TMPDIR"/providers
    if [ "$?" = 0 ]; then
        msg_alert "\033[32m配置文件生成成功！如果启动超时建议更新里手动安装Singbox-srs数据库常用包！\033[0m"
        mkdir -p "$CRASHDIR"/jsons
        mv -f "$TMPDIR"/config.json "$CRASHDIR"/jsons/config.json
        rm -rf "$TMPDIR"/providerss
        comp_box "是否立即启动/重启服务？"
        btm_box "1) 是" \
            "0) 否"
        read -r -p "$COMMON_INPUT> " res
        [ "$res" = 1 ] && {
            start_core && . "$CRASHDIR"/libs/set_cron.sh && cronset '更新订阅'
            exit
        }
    else
        rm -rf "$TMPDIR"/CrashCore
        msg_alert "\033[31m生成配置文件出错，请仔细检查输入！\033[0m"
        # rm -rf "$TMPDIR"/providers
    fi
}

gen_providers_txt() {
    tag=$1
    interval=${3:-3}
    interval2=${4:-12}
    ua=${5:-clash.meta}
    exclude=${6#\#}
    include=${7#\#}
    [ -n "$exclude" ] && exclude_ele="\"exclude\": \"$exclude\","
    [ -n "$include" ] && include_ele="\"include\": \"$include\","
    if [ -n "$(echo "$2" | grep -E '^./')" ]; then
        cat >>"$TMPDIR"/providers/providers.json <<EOF
	{
      "tag": "$tag",
      "type": "local",
	  "path": "$2",
EOF
    else
        cat >>"$TMPDIR"/providers/providers.json <<EOF
	{
      "tag": "$tag",
      "type": "remote",
      "url": "$2",
      "path": "./providers/$tag.yaml",
      "user_agent": "$ua",
      "update_interval": "${interval2}h",
	  $exclude_ele
      $include_ele
EOF
    fi
    # 通用部分生成
    [ "$skip_cert" != "OFF" ] && override_tls='true' || override_tls='false'
    cat >>"$TMPDIR"/providers/providers.json <<EOF
      "health_check": {
        "enabled": true,
        "url": "https://www.gstatic.com/generate_204",
        "interval": "${interval}m",
        "timeout": "3s"
      },
	  "override_tls": {
		"enabled": true,
		"insecure": $override_tls
	  }
	},
EOF
    # 写入提供者
    echo '{ "tag": "'"$tag"'", "type": "urltest", "tolerance": 100, "providers": ["'"$tag"'"], "include": ".*" },' >>"$TMPDIR"/providers/outbounds_add.json
}
