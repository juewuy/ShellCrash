#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_PROVIDERS_CLASH" ] && return
__IS_PROVIDERS_CLASH=1

. "$CRASHDIR"/libs/web_get_bin.sh

#生成clash的providers配置文件
gen_providers(){ 
	if [ -z "$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg)" ];then
		provider_temp_file="$(sed -n "1 p" "$CRASHDIR"/configs/${CORE_TYPE}_providers.list | awk '{print $2}')"
	else
		provider_temp_file=$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
	fi
	echo "-----------------------------------------------"
	if [ -s "$provider_temp_file" ];then
		ln -sf "$provider_temp_file" "$TMPDIR"/provider_temp_file
	else
		echo -e "\033[33m正在获取在线模版！\033[0m"
		get_bin "$TMPDIR"/provider_temp_file "rules/${CORE_TYPE}_providers/$provider_temp_file"
		[ -z "$(grep -o 'rules' "$TMPDIR"/provider_temp_file)" ] && {
			echo -e "\033[31m下载失败，请尝试更换安装源！\033[0m"
			. "$CRASHDIR"/menus/9_upgrade.sh && setserver
			setproviders
		}
	fi
	#生成proxy_providers模块
	mkdir -p "$TMPDIR"/providers
	#预创建文件并写入对应文件头
	echo 'proxy-providers:' > "$TMPDIR"/providers/providers.yaml
	#切割模版文件
	sed -n '/^proxy-groups:/,/^[a-z]/ { /^rule/d; p; }' "$TMPDIR"/provider_temp_file > "$TMPDIR"/providers/proxy-groups.yaml
	sed -n '/^rule/,$p' "$TMPDIR"/provider_temp_file > "$TMPDIR"/providers/rules.yaml
	rm -rf "$TMPDIR"/provider_temp_file
	#基于单订阅生成providers模块
	if [ -n "$1" ];then
		gen_providers_txt $@
		providers_tags=$1
	else
		#基于全部订阅/本地文件生成
		[ -s "$CRASHDIR"/configs/providers.cfg ] && {
			providers_tags=''
			while read line;do
				gen_providers_txt $line
				providers_tags=$(echo "$providers_tags, $tag" | sed 's/^, //')
			done < "$CRASHDIR"/configs/providers.cfg
		}
		#基于全部节点分享链接生成
		[ -s "$CRASHDIR"/configs/providers_uri.cfg ] && {
			mkdir -p "$CRASHDIR"/providers
			awk '{ print ($1=="vmess" ? $2 : $2 "#" $1) }' "$CRASHDIR"/configs/providers_uri.cfg > "$CRASHDIR"/providers/uri_group
			gen_providers_txt "Uri_group" "./providers/uri_group" "3" "12"
			providers_tags=$(echo "$providers_tags, Uri_group" | sed 's/^, //')
		}
	fi
	#修饰模版文件并合并
	sed -i "s/{providers_tags}/$providers_tags/g" "$TMPDIR"/providers/proxy-groups.yaml
	cut -c 1- "$TMPDIR"/providers/providers.yaml "$TMPDIR"/providers/proxy-groups.yaml "$TMPDIR"/providers/rules.yaml > "$TMPDIR"/config.yaml
	rm -rf "$TMPDIR"/providers
	#调用内核测试
	. "$CRASHDIR"/starts/check_core.sh && check_core && "$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml
	if [ "$?" = 0 ];then
		echo -e "\033[32m配置文件生成成功！\033[0m"
		mkdir -p "$CRASHDIR"/yamls
		mv -f "$TMPDIR"/config.yaml "$CRASHDIR"/yamls/config.yaml
		read -p "是否立即启动/重启服务？(1/0) > " res
		[ "$res" = 1 ] && {
			start_core && . "$CRASHDIR"/libs/set_cron.sh && cronset '更新订阅'
			exit
		}
	else
		rm -rf "$TMPDIR"/CrashCore
		rm -rf "$TMPDIR"/config.yaml
		echo -e "\033[31m生成配置文件出错，请仔细检查输入！\033[0m"
	fi
}

gen_providers_txt(){
	if [ -n "$(echo $2|grep -E '^./')" ];then
		type=file
		path=$2
		download_url=
	else
		type=http
		path="./providers/$1.yaml"
		download_url=$2
	fi
	tag=$1
	interval=${3:-3}
	interval2=${4:-12}
	ua=${5:-clash.meta}
	exclude=${6#\#}
	include=${7#\#}
	
	cat >> "$TMPDIR"/providers/providers.yaml <<EOF
  ${1}:
    type: $type
    url: "$download_url"
    path: "$path"
    interval: $((interval2 * 3600))
    health-check:
      enable: true
      lazy: true
      url: "https://www.gstatic.com/generate_204"
      interval: $((interval * 60))
EOF
	[ "$crashcore" = 'meta' ] && {
		[ "$skip_cert" != "OFF" ] && skip_cert_verify='skip-cert-verify: true'
		cat >> "$TMPDIR"/providers/providers.yaml <<EOF
    header:
      User-Agent: ["$ua"]
    override:
      udp: true
      $skip_cert_verify
    filter: "$include"
    exclude-filter: "$exclude"
EOF
	}
	#写入提供者
	echo '  - {name: '"$tag"', type: url-test, tolerance: 100, lazy: true, use: ['"$tag"']}' >> "$TMPDIR"/providers/proxy-groups.yaml
}
	