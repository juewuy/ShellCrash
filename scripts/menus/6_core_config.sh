#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_6_CORECONFIG_LOADED" ] && return
__IS_MODULE_6_CORECONFIG_LOADED=1

YAMLSDIR="$CRASHDIR"/yamls
JSONSDIR="$CRASHDIR"/jsons

#导入订阅、配置文件相关
setrules(){ #自定义规则
	set_rule_type(){
		echo "-----------------------------------------------"
		echo -e "\033[33m请选择规则类型\033[0m"
		echo $rule_type | awk -F ' ' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		case "$num" in
		0) ;;
		[0-9]*)
			if [ $num -gt $(echo $rule_type | awk -F " " '{print NF}') ];then
				errornum
			else
				rule_type_set=$(echo $rule_type|cut -d' ' -f$num)
				echo "-----------------------------------------------"
				echo -e "\033[33m请输入规则语句，可以是域名、泛域名、IP网段或者其他匹配规则类型的内容\033[0m"
				read -p "请输入对应规则 > " rule_state_set
				[ -n "$rule_state_set" ] && set_group_type || errornum
			fi
		;;
		*)
			errornum
		;;
		esac
	}
	set_group_type(){
		echo "-----------------------------------------------"
		echo -e "\033[36m请选择具体规则\033[0m"
		echo -e "\033[33m此处规则读取自现有配置文件，如果你后续更换配置文件时运行出错，请尝试重新添加\033[0m"
		echo $rule_group | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		case "$num" in
		0) ;;
		[0-9]*)
			if [ $num -gt $(echo $rule_group | awk -F "#" '{print NF}') ];then
				errornum
			else
				rule_group_set=$(echo $rule_group|cut -d'#' -f$num)
				rule_all="- ${rule_type_set},${rule_state_set},${rule_group_set}"
				[ -n "$(echo IP-CIDR SRC-IP-CIDR IP-CIDR6|grep "$rule_type_set")" ] && rule_all="${rule_all},no-resolve"
				echo "$rule_all" >> "$YAMLSDIR"/rules.yaml
				echo "-----------------------------------------------"
				echo -e "\033[32m添加成功！\033[0m"
			fi
		;;
		*)
			errornum
		;;
		esac
	}
	del_rule_type(){
		echo -e "输入对应数字即可移除相应规则:"
		sed -i '/^ *$/d; /^#/d' "$YAMLSDIR"/rules.yaml
		cat "$YAMLSDIR"/rules.yaml | grep -Ev '^#' | awk -F "#" '{print " "NR" "$1$2$3}'
		echo "-----------------------------------------------"
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		case "$num" in
		0)	;;
		'')	;;
		*)
			if [ "$num" -le "$(wc -l < "$YAMLSDIR"/rules.yaml)" ];then
				sed -i "${num}d" "$YAMLSDIR"/rules.yaml
				sleep 1
				del_rule_type
			else
				errornum
			fi
		;;
		esac
	}
	get_rule_group(){
		. "$CRASHDIR"/libs/web_save.sh
		get_save http://127.0.0.1:${db_port}/proxies | sed 's/:{/!/g' | awk -F '!' '{for(i=1;i<=NF;i++) print $i}' | grep -aE '"Selector|URLTest|LoadBalance"' | grep -aoE '"name":.*"now":".*",' | awk -F '"' '{print "#"$4}' | tr -d '\n'
	}
	echo "-----------------------------------------------"
	echo -e "\033[33m你可以在这里快捷管理自定义规则\033[0m"
	echo -e "如需批量操作，请手动编辑：\033[36m $YAMLSDIR/rules.yaml\033[0m"
	echo -e "\033[33msingbox和clash共用此处规则，可无缝切换！\033[0m"
	echo -e "大量规则请尽量使用rule-set功能添加，\033[31m此处过量添加可能导致启动卡顿！\033[0m"
	echo "-----------------------------------------------"
	echo -e " 1 新增自定义规则"
	echo -e " 2 移除自定义规则"
	echo -e " 3 清空规则列表"
	echo "$crashcore" | grep -q 'singbox' || echo -e " 4 配置节点绕过:	\033[36m$proxies_bypass\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	1)
		rule_type="DOMAIN-SUFFIX DOMAIN-KEYWORD IP-CIDR SRC-IP-CIDR DST-PORT SRC-PORT GEOIP GEOSITE IP-CIDR6 DOMAIN PROCESS-NAME"
		rule_group="DIRECT#REJECT$(get_rule_group)"
		set_rule_type
		setrules
	;;
	2)
		echo "-----------------------------------------------"
		if [ -s "$YAMLSDIR"/rules.yaml ];then
			del_rule_type
		else
			echo -e "请先添加自定义规则！"
			sleep 1
		fi
		setrules
	;;
	3)
		read -p "确认清空全部自定义规则？(1/0) > " res
		[ "$res" = "1" ] && sed -i '/^\s*[^#]/d' "$YAMLSDIR"/rules.yaml
		setrules
	;;
	4)
		echo "-----------------------------------------------"
		if [ "$proxies_bypass" = "OFF" ];then
			echo -e "\033[33m本功能会自动将当前配置文件中的节点域名或IP设置为直连规则以防止出现双重流量！\033[0m"
			echo -e "\033[33m请确保下游设备使用的节点与ShellCrash中使用的节点相同，否则无法生效！\033[0m"
			read -p "启用节点绕过？(1/0) > " res
			[ "$res" = "1" ] && proxies_bypass=ON
		else
			proxies_bypass=OFF
		fi
		setconfig proxies_bypass $proxies_bypass
		sleep 1
		setrules
	;;
	*)
		errornum
	;;
	esac
}
setgroups(){ #自定义clash策略组
	set_group_type(){
		echo "-----------------------------------------------"
		echo -e "\033[33m注意策略组名称必须和【自定义规则】或【自定义节点】功能中指定的策略组一致！\033[0m"
		echo -e "\033[33m建议先创建策略组，之后可在【自定义规则】或【自定义节点】功能中智能指定\033[0m"
		echo -e "\033[33m如需在当前策略组下添加节点，请手动编辑$YAMLSDIR/proxy-groups.yaml\033[0m"
		read -p "请输入自定义策略组名称(不支持纯数字且不要包含特殊字符！) > " new_group_name
		echo "-----------------------------------------------"
		echo -e "\033[32m请选择策略组【$new_group_name】的类型！\033[0m"
		echo $group_type_cn | awk '{for(i=1;i<=NF;i++){print i" "$i}}'
		read -p "请输入对应数字 > " num
		new_group_type=$(echo $group_type | awk '{print $'"$num"'}')
		if [ "$num" = "1" ];then
			unset new_group_url interval
		else
			read -p "请输入测速地址，回车则默认使用https://www.gstatic.com/generate_204 > " new_group_url
			[ -z "$new_group_url" ] && new_group_url=https://www.gstatic.com/generate_204
			new_group_url="url: '$new_group_url'"
			interval="interval: 300"
		fi
		set_group_add
		#添加自定义策略组
		cat >> "$YAMLSDIR"/proxy-groups.yaml <<EOF
  - name: $new_group_name
    type: $new_group_type
    $new_group_url
    $interval
    proxies:
     - DIRECT
EOF
		sed -i "/^ *$/d" "$YAMLSDIR"/proxy-groups.yaml
		echo "-----------------------------------------------"
		echo -e "\033[32m添加成功！\033[0m"

	}
	set_group_add(){
		echo "-----------------------------------------------"
		echo -e "\033[36m请选择想要将本策略添加到的策略组\033[0m"
		echo -e "\033[32m如需添加到多个策略组，请一次性输入多个数字并用空格隔开\033[0m"
		echo "-----------------------------------------------"
		echo $proxy_group | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo "-----------------------------------------------"
		echo -e " 0 跳过添加"
		read -p "请输入对应数字(多个用空格隔开) > " char
		case "$char" in
		0) ;;
		*)
			for num in $char;do
				rule_group_set=$(echo $proxy_group|cut -d'#' -f$num)
				rule_group_add="${rule_group_add}#${rule_group_set}"
			done
			if [ -n "$rule_group_add" ];then
				new_group_name="$new_group_name$rule_group_add"
				unset rule_group_add
			else
				errornum
			fi
		;;
		esac
	}
	echo "-----------------------------------------------"
	echo -e "\033[33m你可以在这里快捷管理自定义策略组\033[0m"
	echo -e "\033[36m如需修改或批量操作，请手动编辑：$YAMLSDIR/proxy-groups.yaml\033[0m"
	echo "-----------------------------------------------"
	echo -e " 1 添加自定义策略组"
	echo -e " 2 查看自定义策略组"
	echo -e " 3 清空自定义策略组"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	1)
		group_type="select url-test fallback load-balance"
		group_type_cn="手动选择 自动选择 故障转移 负载均衡"
		proxy_group="$(cat "$YAMLSDIR"/proxy-groups.yaml "$YAMLSDIR"/config.yaml 2>/dev/null | sed "/#自定义策略组开始/,/#自定义策略组结束/d" | grep -Ev '^#' | grep -o '\- name:.*' | sed 's/#.*//' | sed 's/- name: /#/g' | tr -d '\n' | sed 's/#//')"
		set_group_type
		setgroups
	;;
	2)
		echo "-----------------------------------------------"
		cat "$YAMLSDIR"/proxy-groups.yaml
		setgroups
	;;
	3)
		read -p "确认清空全部自定义策略组？(1/0) > " res
		[ "$res" = "1" ] && echo '#用于添加自定义策略组' > "$YAMLSDIR"/proxy-groups.yaml
		setgroups
	;;
	*)
		errornum
	;;
	esac
}
setproxies(){ #自定义clash节点
	set_proxy_type(){
		echo "-----------------------------------------------"
		echo -e "\033[33m注意节点格式必须是单行,不包括括号,name:必须写在最前,例如：\033[0m"
		echo -e "\033[36m【name: \"test\", server: 192.168.1.1, port: 12345, type: socks5, udp: true】\033[0m"
		echo -e "更多写法请参考：\033[32m https://juewuy.github.io/ \033[0m"
		read -p "请输入节点 > " proxy_state_set
		if [ -n "$(echo $proxy_state_set | grep "#" )" ];then
			echo -e "\033[33m绝对禁止包含【#】号！！！\033[0m"
		elif [ -n "$(echo $proxy_state_set | grep -E "^name:" )" ];then
			set_group_add
		else
			errornum
		fi
	}
	set_group_add(){
		echo "-----------------------------------------------"
		echo -e "\033[36m请选择想要将节点添加到的策略组\033[0m"
		echo -e "\033[32m如需添加到多个策略组，请一次性输入多个数字并用空格隔开\033[0m"
		echo -e "\033[33m如需自定义策略组，请先使用【管理自定义策略组功能】添加\033[0m"
		echo "-----------------------------------------------"
		echo $proxy_group | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo "-----------------------------------------------"
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字(多个用空格隔开) > " char
		case "$char" in
		0) ;;
		*)
			for num in $char;do
				rule_group_set=$(echo $proxy_group|cut -d'#' -f$num)
				rule_group_add="${rule_group_add}#${rule_group_set}"
			done
			if [ -n "$rule_group_add" ];then
				echo "- {$proxy_state_set}$rule_group_add" >> "$YAMLSDIR"/proxies.yaml
				echo "-----------------------------------------------"
				echo -e "\033[32m添加成功！\033[0m"
				unset rule_group_add
			else
				errornum
			fi
		;;
		esac
	}
	echo "-----------------------------------------------"
	echo -e "\033[33m你可以在这里快捷管理自定义节点\033[0m"
	echo -e "\033[36m如需批量操作，请手动编辑：$YAMLSDIR/proxies.yaml\033[0m"
	echo "-----------------------------------------------"
	echo -e " 1 添加自定义节点"
	echo -e " 2 管理自定义节点"
	echo -e " 3 清空自定义节点"
	echo -e " 4 配置节点绕过:	\033[36m$proxies_bypass\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	1)
		proxy_type="DOMAIN-SUFFIX DOMAIN-KEYWORD IP-CIDR SRC-IP-CIDR DST-PORT SRC-PORT GEOIP GEOSITE IP-CIDR6 DOMAIN MATCH"
		proxy_group="$(cat "$YAMLSDIR"/proxy-groups.yaml "$YAMLSDIR"/config.yaml 2>/dev/null | sed "/#自定义策略组开始/,/#自定义策略组结束/d" | grep -Ev '^#' | grep -o '\- name:.*' | sed 's/#.*//' | sed 's/- name: /#/g' | tr -d '\n' | sed 's/#//')"
		set_proxy_type
		setproxies
	;;
	2)
		echo "-----------------------------------------------"
		sed -i '/^ *$/d' "$YAMLSDIR"/proxies.yaml 2>/dev/null
		if [ -s "$YAMLSDIR"/proxies.yaml ];then
			echo -e "当前已添加的自定义节点为:"
			cat "$YAMLSDIR"/proxies.yaml | grep -Ev '^#' | awk -F '[,,}]' '{print NR, $1, $NF}' | sed 's/- {//g'
			echo "-----------------------------------------------"
			echo -e "\033[33m输入节点对应数字可以移除对应节点\033[0m"
			read -p "请输入对应数字 > " num
			if [ $num -le $(cat "$YAMLSDIR"/proxies.yaml | grep -Ev '^#' | wc -l) ];then
				sed -i "$num{/^\s*[^#]/d}" "$YAMLSDIR"/proxies.yaml
			else
				errornum
			fi
		else
			echo -e "请先添加自定义节点！"
			sleep 1
		fi
		setproxies
	;;
	3)
		read -p "确认清空全部自定义节点？(1/0) > " res
		[ "$res" = "1" ] && sed -i '/^\s*[^#]/d' "$YAMLSDIR"/proxies.yaml 2>/dev/null
		setproxies
	;;
	4)
		echo "-----------------------------------------------"
		if [ "$proxies_bypass" = "OFF" ];then
			echo -e "\033[33m本功能会自动将当前配置文件中的节点域名或IP设置为直连规则以防止出现双重流量！\033[0m"
			echo -e "\033[33m请确保下游设备使用的节点与ShellCrash中使用的节点相同，否则无法生效！\033[0m"
			read -p "启用节点绕过？(1/0) > " res
			[ "$res" = "1" ] && proxies_bypass=ON
		else
			proxies_bypass=OFF
		fi
		setconfig proxies_bypass $proxies_bypass
		sleep 1
		setrules
	;;
	*)
		errornum
	;;
	esac
}
gen_clash_providers(){ #生成clash的providers配置文件
	gen_clash_providers_txt(){
		if [ -n "$(echo $2|grep -E '^./')" ];then
			local type=file
			local path=$2
			local download_url=
		else
			local type=http
			local path="./providers/${1}.yaml"
			local download_url=$2
		fi
		cat >> $TMPDIR/providers/providers.yaml <<EOF
  ${1}:
    type: $type
    url: "$download_url"
    path: "$path"
    interval: 43200
    health-check:
      enable: true
      lazy: true
      url: "https://www.gstatic.com/generate_204"
      interval: 600
EOF
		[ "$crashcore" = 'meta' ] && {
		[ "$skip_cert" != "OFF" ] && skip_cert_verify='skip-cert-verify: true'
		cat >> $TMPDIR/providers/providers.yaml <<EOF
    override:
      udp: true
      $skip_cert_verify
EOF
		}
	}
	if [ -z "$(grep "provider_temp_${coretype}" "$CRASHDIR"/configs/ShellCrash.cfg)" ];then
		provider_temp_file="$TMPDIR/$(sed -n "1 p" "$CRASHDIR"/configs/${coretype}_providers.list | awk '{print $2}')"
	else
		provider_temp_file=$(grep "provider_temp_${coretype}" "$CRASHDIR"/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
	fi
	echo "-----------------------------------------------"
	if [ -s "$provider_temp_file" ];then
		ln -sf "$provider_temp_file" "$TMPDIR"/provider_temp_file
	else
		echo -e "\033[33m正在获取在线模版！\033[0m"
		get_bin "$TMPDIR"/provider_temp_file "rules/${coretype}_providers/$provider_temp_file"
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
	#生成providers模块
	if [ -n "$2" ];then
		gen_clash_providers_txt $1 $2
		providers_tags=$1
		echo '  - {name: '${1}', type: url-test, tolerance: 100, lazy: true, use: ['${1}']}' >> "$TMPDIR"/providers/proxy-groups.yaml
	else
		providers_tags=''
		while read line;do
			tag=$(echo $line | awk '{print $1}')
			url=$(echo $line | awk '{print $2}')
			providers_tags=$(echo "$providers_tags, $tag" | sed 's/^, //')
			gen_clash_providers_txt $tag $url
			echo '  - {name: '${tag}', type: url-test, tolerance: 100, lazy: true, use: ['${tag}']}' >> "$TMPDIR"/providers/proxy-groups.yaml
		done < "$CRASHDIR"/configs/providers.cfg
	fi
	#修饰模版文件并合并
	sed -i "s/{providers_tags}/$providers_tags/g" "$TMPDIR"/providers/proxy-groups.yaml
	cut -c 1- "$TMPDIR"/providers/providers.yaml "$TMPDIR"/providers/proxy-groups.yaml "$TMPDIR"/providers/rules.yaml > "$TMPDIR"/config.yaml
	rm -rf "$TMPDIR"/providers
	#调用内核测试
	. "$CRASHDIR"/libs/core_tools.sh && core_find && "$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml
	if [ "$?" = 0 ];then
		echo -e "\033[32m配置文件生成成功！\033[0m"
		mkdir -p "$CRASHDIR"/yamls
		mv -f "$TMPDIR"/config.yaml "$CRASHDIR"/yamls/config.yaml
		read -p "是否立即启动/重启服务？(1/0) > " res
		[ "$res" = 1 ] && {
			start_core && cronset '更新订阅'
			exit
		}
	else
		rm -rf "$TMPDIR"/CrashCore
		rm -rf "$TMPDIR"/config.yaml
		echo -e "\033[31m生成配置文件出错，请仔细检查输入！\033[0m"
	fi
}
gen_singbox_providers(){ #生成singbox的providers配置文件
	gen_singbox_providers_txt(){
		if [ -n "$(echo $2|grep -E '^./')" ];then
			cat >> "$TMPDIR"/providers/providers.json <<EOF
	{
      "tag": "${1}",
      "type": "local",
	  "path": "${2}",
EOF
		else
			cat >> "$TMPDIR"/providers/providers.json <<EOF
	{
      "tag": "${1}",
      "type": "remote",
      "url": "${2}",
      "path": "./providers/${1}.yaml",
      "user_agent": "clash.meta;mihomo",
      "update_interval": "12h",
EOF
		fi
		#通用部分生成
		[ "$skip_cert" != "OFF" ] && override_tls='true' || override_tls='false'
		cat >> "$TMPDIR"/providers/providers.json <<EOF
      "health_check": {
        "enabled": true,
        "url": "https://www.gstatic.com/generate_204",
        "interval": "10m",
        "timeout": "3s"
      },
	  "override_tls": {
		"enabled": true,
		"insecure": $override_tls
	  }
	},
EOF
	}
	if [ -z "$(grep "provider_temp_${coretype}" "$CRASHDIR"/configs/ShellCrash.cfg)" ];then
		provider_temp_file="$TMPDIR/$(sed -n "1 p" "$CRASHDIR"/configs/${coretype}_providers.list | awk '{print $2}')"
	else
		provider_temp_file=$(grep "provider_temp_${coretype}" "$CRASHDIR"/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
	fi
	echo "-----------------------------------------------"
	if [ -s "$provider_temp_file" ];then
		ln -sf "$provider_temp_file" "$TMPDIR"/provider_temp_file
	else
		echo -e "\033[33m正在获取在线模版！\033[0m"
		get_bin "$TMPDIR"/provider_temp_file "rules/${coretype}_providers/$provider_temp_file"
		[ -z "$(grep -o 'route' "$TMPDIR"/provider_temp_file)" ] && {
			echo -e "\033[31m下载失败，请尝试更换安装源！\033[0m"
			. "$CRASHDIR"/menus/9_upgrade.sh && setserver
			setproviders
		}
	fi
	#生成outbound_providers模块
	mkdir -p "$TMPDIR"/providers
	#预创建文件并写入对应文件头
	cat > "$TMPDIR"/providers/providers.json <<EOF
{
  "providers": [
EOF
	cat > "$TMPDIR"/providers/outbounds_add.json <<EOF
{
  "outbounds": [
EOF
	#单独指定节点时使用特殊方式
	if [ -n "$2" ];then
		gen_singbox_providers_txt $1 $2
		providers_tags=\"$1\"
		echo '{ "tag": "'${1}'", "type": "urltest", "tolerance": 100, "providers": ["'${1}'"], "include": ".*" },' >> "$TMPDIR"/providers/outbounds_add.json
	else
		providers_tags=''
		while read line;do
			tag=$(echo $line | awk '{print $1}')
			url=$(echo $line | awk '{print $2}')
			providers_tags=$(echo "$providers_tags, \"$tag\"" | sed 's/^, //')
			gen_singbox_providers_txt $tag $url
			echo '{ "tag": "'${tag}'", "type": "urltest", "tolerance": 100, "providers": ["'${tag}'"], "include": ".*" },' >> "$TMPDIR"/providers/outbounds_add.json
		done < "$CRASHDIR"/configs/providers.cfg
	fi
	#修复文件格式
	sed -i '$s/},/}]}/' "$TMPDIR"/providers/outbounds_add.json
	sed -i '$s/},/}]}/' "$TMPDIR"/providers/providers.json
	#使用模版生成outbounds和rules模块
	cat "$TMPDIR"/provider_temp_file | sed "s/{providers_tags}/$providers_tags/g" > "$TMPDIR"/providers/outbounds.json
	rm -rf "$TMPDIR"/provider_temp_file
	#调用内核测试
	. "$CRASHDIR"/libs/core_tools.sh && core_find && "$TMPDIR"/CrashCore merge "$TMPDIR"/config.json -C "$TMPDIR"/providers
	if [ "$?" = 0 ];then
		echo -e "\033[32m配置文件生成成功！如果启动超时建议更新里手动安装Singbox-srs数据库常用包！\033[0m"
		mkdir -p "$CRASHDIR"/jsons
		mv -f "$TMPDIR"/config.json "$CRASHDIR"/jsons/config.json
		rm -rf "$TMPDIR"/providers
		read -p "是否立即启动/重启服务？(1/0) > " res
		[ "$res" = 1 ] && {
			start_core && cronset '更新订阅'
			exit
		}
	else
		echo -e "\033[31m生成配置文件出错，请仔细检查输入！\033[0m"
		rm -rf "$TMPDIR"/CrashCore
		rm -rf "$TMPDIR"/providers
	fi
}

# 自定义providers
setproviders() {
    . "$CRASHDIR"/libs/set_cron.sh
    . "$CRASHDIR"/libs/web_get_bin.sh
    while true; do
        # 获取模版名称
        if [ -z "$(grep "provider_temp_${coretype}" "$CRASHDIR"/configs/ShellCrash.cfg)" ]; then
            provider_temp_des=$(sed -n "1 p" "$CRASHDIR"/configs/${coretype}_providers.list | awk '{print $1}')
        else
            provider_temp_file=$(grep "provider_temp_${coretype}" "$CRASHDIR"/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
            provider_temp_des=$(grep "$provider_temp_file" "$CRASHDIR"/configs/${coretype}_providers.list | awk '{print $1}')
            [ -z "$provider_temp_des" ] && provider_temp_des=$provider_temp_file
        fi
        echo "-----------------------------------------------"
        echo -e "\033[33m你可以在这里快捷管理与生成自定义的providers服务商\033[0m"
        echo -e "\033[33m支持在线及本地的Yaml格式配置导入\033[0m"
        [ -s "$CRASHDIR"/configs/providers.cfg ] && {
            echo "-----------------------------------------------"
            echo -e "\033[36m输入对应数字可管理providers服务商\033[0m"
            cat "$CRASHDIR"/configs/providers.cfg | awk -F "#" '{print " "NR" "$1" "$2}'
        }
        echo -e " d \033[31m清空\033[0mproviders服务商列表"
        echo -e " e \033[33m清理\033[0mproviders目录文件"
        echo "-----------------------------------------------"
        echo -e "\033[36m按照a-b-c的顺序即可完成配置生成\033[0m"
        echo -e " a \033[36m添加\033[0mproviders服务商/节点"
        echo -e " b 选择\033[33m规则模版\033[0m     \033[32m$provider_temp_des\033[0m"
        echo -e " c \033[32m生成\033[0m基于providers的配置文件"
        echo "-----------------------------------------------"
        echo -e " 0 返回上级菜单"
        read -p "请输入对应字母或数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        [1-9] | [1-9][0-9])
            provider_name=$(sed -n "$num p" "$CRASHDIR"/configs/providers.cfg | awk '{print $1}')
            provider_url=$(sed -n "$num p" "$CRASHDIR"/configs/providers.cfg | awk '{print $2}')
            if [ -z "$provider_name" ]; then
                errornum
            else
                echo "-----------------------------------------------"
                echo -e " 1 修改名称：\033[36m$provider_name\033[0m"
                echo -e " 2 修改链接地址：\033[32m$provider_url\033[0m"
                echo -e " 3 生成\033[33m仅包含此链接\033[0m的配置文件"
                echo -e " 4 \033[31m移除此链接\033[0m"
                echo "-----------------------------------------------"
                echo -e " 0 返回上级菜单"
                read -p "请选择需要执行的操作 > " num
                case "$num" in
                "" | 0) ;;
                1)
                    read -p "请输入名称或者代号(不可重复,不支持纯数字)  > " name
                    if [ -n "$name" ] && [ -z "$(echo "$name" | grep -E '^[0-9]+$')" ] && ! grep -q "$name" "$CRASHDIR"/configs/providers.cfg; then
                        sed -i "s|$provider_name $provider_url|$name $provider_url|" "$CRASHDIR"/configs/providers.cfg
                    else
                        echo -e "\033[31m输入错误，请重新输入！\033[0m"
                    fi
                    ;;
                2)
                    read -p "请输入链接地址或本地相对路径 > " link
                    if [ -n "$(echo $link | grep -E '.*\..*|^\./')" ] && [ -z "$(grep "$link" "$CRASHDIR"/configs/providers.cfg)" ]; then
                        link=$(echo $link | sed 's/\&/\\\&/g') #特殊字符添加转义
                        sed -i "s|$provider_name $provider_url|$provider_name $link|" "$CRASHDIR"/configs/providers.cfg
                    else
                        echo -e "\033[31m输入错误，请重新输入！\033[0m"
                    fi
                    ;;
                3)
                    gen_${coretype}_providers $provider_name $provider_url
                    ;;
                4)
                    sed -i "/^$provider_name /d" "$CRASHDIR"/configs/providers.cfg
                    ;;
                *)
                    errornum
                    ;;
                esac
            fi
            sleep 1
            ;;
        a)
            echo "-----------------------------------------------"
            echo -e "支持填写在线的\033[32mYClash订阅地址\033[0m或者\033[32m本地Clash配置文件\033[0m"
            echo -e "本地配置文件请放在\033[32m$CRASHDIR\033[0m目录下，并填写相对路径如【\033[32m./providers/test.yaml\033[0m】"
            echo "-----------------------------------------------"
            read -p "请输入链接地址或本地相对路径 > " link
            link=$(echo $link | sed 's/ //g') #去空格
            [ -n "$(echo $link | grep -E '.*\..*|^\./')" ] && {
                read -p "请输入名称或代号(不可重复,不支持纯数字) > " name
                name=$(echo $name | sed 's/ //g')
                [ -n "$name" ] && [ -z "$(echo "$name" | grep -E '^[0-9]+$')" ] && ! grep -q "$name" "$CRASHDIR"/configs/providers.cfg && {
                    echo "-----------------------------------------------"
                    echo -e "名称：\033[36m$name\033[0m"
                    echo -e "链接地址/路径：\033[32m$link\033[0m"
                    read -p "确认添加？(1/0) > " res
                    [ "$res" = 1 ] && {
                        echo "$name $link" >>"$CRASHDIR"/configs/providers.cfg
                        echo -e "\033[32mproviders已添加！\033[0m"
                    }
                }
            }
            [ "$?" != 0 ] && echo -e "\033[31m输入错误，操作已取消！\033[0m"
            sleep 1
            ;;
        c)
            echo "-----------------------------------------------"
            if [ -s "$CRASHDIR"/configs/providers.cfg ]; then
                echo -e "\033[33msingboxr与mihomo内核的providers配置文件不互通！\033[0m"
                echo "-----------------------------------------------"
                read -p "确认生成${coretype}配置文件？(1/0) > " res
                [ "$res" = "1" ] && {
                    gen_${coretype}_providers
                }
            else
                echo -e "\033[31m你还未添加链接或本地配置文件，请先添加！\033[0m"
                sleep 1
            fi
            ;;
        b)
            echo "-----------------------------------------------"
            echo -e "当前规则模版为：\033[32m$provider_temp_des\033[0m"
            echo -e "\033[33m请选择在线模版：\033[0m"
            echo "-----------------------------------------------"
            cat "$CRASHDIR"/configs/${coretype}_providers.list | awk '{print " "NR" "$1}'
            echo "-----------------------------------------------"
            echo -e " a 使用\033[36m本地模版\033[0m"
            echo "-----------------------------------------------"
            read -p "请输入对应字母或数字 > " num
            case "$num" in
            "" | 0) ;;
            a)
                read -p "请输入模版的路径(绝对路径) > " dir
                if [ -s $dir ]; then
                    provider_temp_file=$dir
                    setconfig provider_temp_${coretype} $provider_temp_file
                    echo -e "\033[32m设置成功！\033[0m"
                else
                    echo -e "\033[31m输入错误，找不到对应模版文件！\033[0m"
                fi
                sleep 1
                ;;
            *)
                provider_temp_file=$(sed -n "$num p" "$CRASHDIR"/configs/${coretype}_providers.list 2>/dev/null | awk '{print $2}')
                if [ -z "$provider_temp_file" ]; then
                    errornum
                    sleep 1
                else
                    setconfig provider_temp_${coretype} $provider_temp_file
                fi
                ;;
            esac
            ;;
        d)
            read -p "确认清空全部链接？(1/0) > " res
            [ "$res" = "1" ] && rm -rf "$CRASHDIR"/configs/providers.cfg
            ;;
        e)
            echo -e "\033[33m将清空 $CRASHDIR/providers 目录下所有内容\033[0m"
            read -p "是否继续？(1/0) > " res
            [ "$res" = "1" ] && rm -rf "$CRASHDIR"/providers
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}

set_clash_adv(){ #自定义clash高级规则
		[ ! -f "$YAMLSDIR"/user.yaml ] && cat > "$YAMLSDIR"/user.yaml <<EOF
#用于编写自定义设定(可参考https://lancellc.gitbook.io/clash/clash-config-file/general 或 https://docs.metacubex.one/function/general)
#端口之类请在脚本中修改，否则不会加载
#port: 7890
EOF
		[ ! -f "$YAMLSDIR"/others.yaml ] && cat > "$YAMLSDIR"/others.yaml <<EOF
#用于编写自定义的锚点、入站、proxy-providers、sub-rules、rule-set、script等功能
#可参考 https://github.com/MetaCubeX/Clash.Meta/blob/Meta/docs/config.yaml 或 https://lancellc.gitbook.io/clash/clash-config-file/an-example-configuration-file
#此处内容会被添加在配置文件的“proxy-group：”模块的末尾与“rules：”模块之前的位置
#例如：
#proxy-providers:
#rule-providers:
#sub-rules:
#tunnels:
#script:
#listeners:
EOF
		echo "-----------------------------------------------"
		echo -e "\033[32m已经创建自定义设定文件：$YAMLSDIR/user.yaml ！\033[0m"
		echo -e "\033[33m可用于编写自定义的DNS，等功能\033[0m"
		echo "-----------------------------------------------"
		echo -e "\033[32m已经创建自定义功能文件：$YAMLSDIR/others.yaml ！\033[0m"
		echo -e "\033[33m可用于编写自定义的锚点、入站、proxy-providers、sub-rules、rule-set、script等功能\033[0m"
		echo "-----------------------------------------------"
		echo -e "Windows下请\n使用\033[33mWinSCP软件\033[0m进行编辑！\033[0m"
		echo -e "MacOS下请\n使用\033[33mSecureFX软件\033[0m进行编辑！\033[0m"
		echo -e "Linux本机可\n使用\033[33mvim\033[0m进行编辑(路由设备可能不显示中文请勿使用)！\033[0m"
}
set_singbox_adv(){ #自定义singbox配置文件
		echo "-----------------------------------------------"
		echo -e "支持覆盖脚本设置的模块有：\033[0m"
		echo -e "\033[36mlog dns ntp certificate experimental\033[0m"
		echo -e "支持与内置功能合并(但不可冲突)的模块有：\033[0m"
		echo -e "\033[36mendpoints inbounds outbounds providers route services\033[0m"
		echo -e "将相应json文件放入\033[33m$JSONSDIR\033[0m目录后即可在启动时自动加载"
		echo "-----------------------------------------------"
		echo -e "使用前请务必参考配置教程:\033[32;4m https://juewuy.github.io/nWTjEpkSK \033[0m"
}

# 配置文件覆写
override() {
    while true; do
        [ -z "$rule_link" ] && rule_link=1
        [ -z "$server_link" ] && server_link=1
        echo "-----------------------------------------------"
        echo -e "\033[30;47m 欢迎使用配置文件覆写功能！\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 自定义\033[32m端口及秘钥\033[0m"
        echo -e " 2 管理\033[36m自定义规则\033[0m"
        echo "$crashcore" | grep -q 'singbox' || {
            echo -e " 3 管理\033[33m自定义节点\033[0m"
            echo -e " 4 管理\033[36m自定义策略组\033[0m"
        }
        echo -e " 5 \033[32m自定义\033[0m高级功能"
        [ "$disoverride" != 1 ] && echo -e " 9 \033[33m禁用\033[0m配置文件覆写"
        echo "-----------------------------------------------"
        [ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$(pidof CrashCore)" ]; then
                echo "-----------------------------------------------"
                echo -e "\033[33m检测到服务正在运行，需要先停止服务！\033[0m"
                read -p "是否停止服务？(1/0) > " res
                if [ "$res" = "1" ]; then
                    "$CRASHDIR"/start.sh stop
                    setport
                fi
            else
                setport
            fi
            ;;
        2)
            setrules
            ;;
        3)
            setproxies
            ;;
        4)
            setgroups
            ;;
        5)
            echo "$crashcore" | grep -q 'singbox' && set_singbox_adv || set_clash_adv
            sleep 3
            ;;
        9)
            echo "-----------------------------------------------"
            echo -e "\033[33m此功能可能会导致严重问题！启用后脚本中大部分功能都将禁用！！！\033[0m"
            echo -e "如果你不是非常了解$crashcore的运行机制，切勿开启！\033[0m"
            echo -e "\033[33m继续后如出现任何问题，请务必自行解决，一切提问恕不受理！\033[0m"
            echo "-----------------------------------------------"
            sleep 2
            read -p "我确认遇到问题可以自行解决[1/0] > " res
            [ "$res" = '1' ] && {
                disoverride=1
                setconfig disoverride $disoverride
                echo "-----------------------------------------------"
                echo -e "\033[32m设置成功！\033[0m"
            }
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}

gen_link_config(){ #选择在线规则
	echo "-----------------------------------------------"
	echo 当前使用规则为：$(grep -aE '^5' "$CRASHDIR"/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $2}')
	grep -aE '^5' "$CRASHDIR"/configs/servers.list | awk '{print " "NR"	"$2$4}'
	echo "-----------------------------------------------"
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^5' "$CRASHDIR"/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入配置
		rule_link=$num
		setconfig rule_link $rule_link
		echo "-----------------------------------------------"
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
gen_link_server(){ #选择在线服务器
	echo "-----------------------------------------------"
	echo -e "\033[36m以下为互联网采集的第三方服务器，具体安全性请自行斟酌！\033[0m"
	echo -e "\033[32m感谢以下作者的无私奉献！！！\033[0m"
	echo 当前使用后端为：$(grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | awk '{print " "NR"	"$3"	"$2}'
	echo "-----------------------------------------------"
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^3|^4' "$CRASHDIR"/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入配置
		server_link=$num
		setconfig server_link $server_link
		echo "-----------------------------------------------"
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
gen_link_flt(){ #在线生成节点过滤
	[ -z "$exclude" ] && exclude="未设置"
	echo "-----------------------------------------------"
	echo -e "\033[33m当前过滤关键字：\033[47;30m$exclude\033[0m"
	echo "-----------------------------------------------"
	echo -e "\033[33m匹配关键字的节点会在导入时被【屏蔽】！！！\033[0m"
	echo -e "多个关键字可以用\033[30;47m | \033[0m号分隔"
	echo -e "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	echo "-----------------------------------------------"
	echo -e " 000   \033[31m删除\033[0m关键字"
	echo -e " 回车  取消输入并返回上级菜单"
	echo "-----------------------------------------------"
	read -p "请输入关键字 > " exclude
	if [ "$exclude" = '000' ]; then
		echo "-----------------------------------------------"
		exclude=''
		echo -e "\033[31m 已删除节点过滤关键字！！！\033[0m"
	fi
	setconfig exclude "'$exclude'"
}
gen_link_ele(){ #在线生成节点筛选
	[ -z "$include" ] && include="未设置"
	echo "-----------------------------------------------"
	echo -e "\033[33m当前筛选关键字：\033[47;30m$include\033[0m"
	echo "-----------------------------------------------"
	echo -e "\033[33m仅有匹配关键字的节点才会被【导入】！！！\033[0m"
	echo -e "多个关键字可以用\033[30;47m | \033[0m号分隔"
	echo -e "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	echo "-----------------------------------------------"
	echo -e " 000   \033[31m删除\033[0m关键字"
	echo -e " 回车  取消输入并返回上级菜单"
	echo "-----------------------------------------------"
	read -p "请输入关键字 > " include
	if [ "$include" = '000' ]; then
		echo "-----------------------------------------------"
		include=''
		echo -e "\033[31m 已删除节点匹配关键字！！！\033[0m"
	fi
	setconfig include "'$include'"
}
jump_core_config(){ #调用工具下载
	. "$CRASHDIR"/starts/core_config.sh && get_core_config
	if [ "$?" = 0 ];then
		if [ "$inuserguide" != 1 ];then
			read -p "是否启动服务以使配置文件生效？(1/0) > " res
			[ "$res" = 1 ] && start_core || main_menu
			exit;
		fi
	fi
}
gen_core_config_link(){ #在线生成工具
	echo "-----------------------------------------------"
	echo -e "\033[30;47m 欢迎使用在线生成配置文件功能！\033[0m"
	echo "-----------------------------------------------"
	#设置输入循环
	i=1
	while [ $i -le 99 ]
	do
		echo "-----------------------------------------------"
		echo -e "\033[33m本功能依赖第三方在线subconverter服务实现，脚本本身不提供任何代理服务！\033[0m"
		echo -e "\033[31m严禁使用本脚本从事任何非法活动，否则一切后果请自负！\033[0m"
		echo "-----------------------------------------------"
		echo -e "支持批量(<=99)导入订阅链接、分享链接"
		echo "-----------------------------------------------"
		echo -e " 1 \033[36m开始生成配置文件\033[0m（原文件将被备份）"
		echo -e " 2 设置\033[31m节点过滤\033[0m关键字 \033[47;30m$exclude\033[0m"
		echo -e " 3 设置\033[32m节点筛选\033[0m关键字 \033[47;30m$include\033[0m"
		echo -e " 4 选取在线\033[33m配置规则模版\033[0m"
		echo -e " 5 \033[0m选取在线生成服务器\033[0m"
		echo -e " 0 \033[31m撤销输入并返回上级菜单\033[0m"
		echo "-----------------------------------------------"
		read -p "请直接输入第${i}个链接或对应数字选项 > " link
		link=$(echo $link | sed 's/\&/%26/g')   #处理分隔符
		test=$(echo $link | grep "://")
		link=`echo ${link/\#*/''}`   #删除链接附带的注释内容
		link=`echo ${link/\ \(*\)/''}`   #删除恶心的超链接内容
		link=`echo ${link/*\&url\=/""}`   #将完整链接还原成单一链接
		link=`echo ${link/\&config\=*/""}`   #将完整链接还原成单一链接

		if [ -n "$test" ];then
			if [ -z "$Url_link" ];then
				Url_link="$link"
			else
				Url_link="$Url_link"\|"$link"
			fi
			i=$((i+1))

		elif [ "$link" = '1' ]; then
			if [ -n "$Url_link" ];then
				i=100
				#将用户链接写入配置
				Url="$Url_link"
				Https=''
				setconfig Https
				setconfig Url "'$Url'"
				#获取在线yaml文件
				jump_core_config
			else
				echo "-----------------------------------------------"
				echo -e "\033[31m请先输入订阅或分享链接！\033[0m"
				sleep 1
			fi

		elif [ "$link" = '2' ]; then
			gen_link_flt

		elif [ "$link" = '3' ]; then
			gen_link_ele

		elif [ "$link" = '4' ]; then
			gen_link_config

		elif [ "$link" = '5' ]; then
			gen_link_server

		elif [ "$link" = 0 ];then
			Url_link=""
			i=100

		else
			echo "-----------------------------------------------"
			echo -e "\033[31m请输入正确的链接或者数字！\033[0m"
			sleep 1
		fi
	done
}
set_core_config_link(){ #直接导入配置
	echo "-----------------------------------------------"
	echo -e "\033[32m仅限导入完整的配置文件链接！！！\033[0m"
	echo "-----------------------------------------------"
	echo -e "注意：\033[31m此功能不兼容“跳过证书验证”功能，部分老旧\n设备可能出现x509报错导致节点不通\033[0m"
	echo -e "你也可以搭配在线订阅转换网站或者自建SubStore使用"
	echo "$crashcore" | grep -q 'singbox' &&echo -e "singbox内核建议使用\033[32;4mhttps://subv.jwsc.eu.org/\033[0m转换"
	echo "-----------------------------------------------"
	echo -e "\033[33m0 返回上级菜单\033[0m"
	echo "-----------------------------------------------"
	read -p "请输入完整链接 > " link
	test=$(echo $link | grep -iE "tp.*://" )
	link=`echo ${link/\ \(*\)/''}`   #删除恶心的超链接内容
	link=`echo ${link//\&/\\\&}`   #处理分隔符
	if [ -n "$link" -a -n "$test" ];then
		echo "-----------------------------------------------"
		echo -e 请检查输入的链接是否正确：
		echo -e "\033[4;32m$link\033[0m"
		read -p "确认导入配置文件？原配置文件将被备份![1/0] > " res
			if [ "$res" = '1' ]; then
				#将用户链接写入配置
				Url=''
				Https="$link"
				setconfig Https "'$Https'"
				setconfig Url
				#获取在线yaml文件
				jump_core_config
			else
				set_core_config_link
			fi
	elif [ "$link" = 0 ];then
		i=
	else
		echo "-----------------------------------------------"
		echo -e "\033[31m请输入正确的配置文件链接地址！！！\033[0m"
		echo -e "\033[33m仅支持http、https、ftp以及ftps链接！\033[0m"
		sleep 1
		set_core_config_link
	fi
}

# 配置文件主界面
set_core_config() {
    while true; do
        [ -z "$rule_link" ] && rule_link=1
        [ -z "$server_link" ] && server_link=1
        echo "$crashcore" | grep -q 'singbox' && config_path="$JSONSDIR"/config.json || config_path="$YAMLSDIR"/config.yaml
        echo "-----------------------------------------------"
        echo -e "\033[30;47m ShellCrash配置文件管理\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 在线\033[32m生成配置文件\033[0m(基于Subconverter订阅转换)"
        if [ -f "$CRASHDIR"/v2b_api.sh ]; then
            echo -e " 2 登录\033[33m获取订阅(推荐！)\033[0m"
        else
            echo -e " 2 在线\033[33m获取配置文件\033[0m(基于订阅提供者)"
        fi
        echo -e " 3 本地\033[32m生成配置文件\033[0m(基于内核providers,推荐！)"
        echo -e " 4 本地\033[33m上传完整配置文件\033[0m"
        echo -e " 5 设置\033[36m自动更新\033[0m"
        echo -e " 6 \033[32m自定义\033[0m配置文件"
        echo -e " 7 \033[33m更新\033[0m配置文件"
        echo -e " 8 \033[36m还原\033[0m配置文件"
        echo -e " 9 自定义浏览器UA  \033[32m$user_agent\033[0m"
        echo "-----------------------------------------------"
        [ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$Url" ]; then
                echo "-----------------------------------------------"
                echo -e "\033[33m检测到已记录的链接内容：\033[0m"
                echo -e "\033[4;32m$Url\033[0m"
                echo "-----------------------------------------------"
                read -p "清空链接/追加导入？[1/0] > " res
                if [ "$res" = '1' ]; then
                    Url_link=""
                    echo "-----------------------------------------------"
                    echo -e "\033[31m链接已清空！\033[0m"
                else
                    Url_link=$Url
                fi
            fi
            gen_core_config_link
            ;;
        2)
            if [ -f "$CRASHDIR"/v2b_api.sh ]; then
                . "$CRASHDIR"/v2b_api.sh
            else
                set_core_config_link
            fi
            ;;
        3)
            if [ "$crashcore" = meta -o "$crashcore" = clashpre ]; then
                coretype=clash
                setproviders
            elif [ "$crashcore" = singboxr ]; then
                coretype=singbox
                setproviders
            else
                echo -e "\033[33msingbox官方内核及Clash基础内核不支持此功能，请先更换内核！\033[0m"
                sleep 1
                checkupdate && setcore
            fi
            ;;
        4)
            echo "-----------------------------------------------"
            echo -e "\033[33m请将本地配置文件上传到/tmp目录并重命名为config.yaml或者config.json\033[0m"
            echo -e "\033[32m之后重新运行本脚本即可自动弹出导入提示！\033[0m"
            sleep 2
            exit
            ;;
        5)
            . "$CRASHDIR"/menus/5_task.sh && task_menu
            break
            ;;
        6)
            checkcfg=$(cat $CFG_PATH)
            override
            if [ -n "$PID" ]; then
                checkcfg_new=$(cat $CFG_PATH)
                [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
            fi
            ;;
        7)
            if [ -z "$Url" -a -z "$Https" ]; then
                echo "-----------------------------------------------"
                echo -e "\033[31m没有找到你的配置文件/订阅链接！请先输入链接！\033[0m"
                sleep 1
            else
                echo "-----------------------------------------------"
                echo -e "\033[33m当前系统记录的链接为：\033[0m"
                echo -e "\033[4;32m$Url$Https\033[0m"
                echo "-----------------------------------------------"
                read -p "确认更新配置文件？[1/0] > " res
                if [ "$res" = '1' ]; then
                    jump_core_config
                    break
                fi
            fi
            ;;
        8)
            if [ ! -f ${config_path}.bak ]; then
                echo "-----------------------------------------------"
                echo -e "\033[31m没有找到配置文件的备份！\033[0m"
            else
                echo "-----------------------------------------------"
                echo -e 备份文件共有"\033[32m$(wc -l <${config_path}.bak)\033[0m"行内容，当前文件共有"\033[32m$(wc -l <${config_path})\033[0m"行内容
                read -p "确认还原配置文件？此操作不可逆！[1/0] > " res
                if [ "$res" = '1' ]; then
                    mv ${config_path}.bak ${config_path}
                    echo "----------------------------------------------"
                    echo -e "\033[32m配置文件已还原！请手动重启服务！\033[0m"
                    sleep 1
                    break
                else
                    echo "-----------------------------------------------"
                    echo -e "\033[31m操作已取消！返回上级菜单！\033[0m"
                    sleep 1
                fi
            fi
            ;;
        9)
            echo "-----------------------------------------------"
            echo -e "\033[36m如果6-1或者6-2无法正确获取配置文件时可以尝试使用\033[0m"
            echo -e " 1 使用自动UA"
            echo -e " 2 不使用UA"
            echo -e " 3 使用自定义UA：\033[32m$user_agent\033[0m"
            echo "-----------------------------------------------"
            read -p "请输入对应数字 > " num
            case "$num" in
            0)
                user_agent=''
                ;;
            1)
                user_agent='auto'
                ;;
            2)
                user_agent='none'
                ;;
            3)
                read -p "请输入自定义UA(不要包含空格和特殊符号！) > " text
                [ -n "$text" ] && user_agent="$text"
                ;;
            *)
                errornum
                ;;
            esac
            [ "$num" -le 3 ] && setconfig user_agent "$user_agent"
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}
