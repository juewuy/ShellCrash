#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_PROVIDERS" ] && return
__IS_MODULE_PROVIDERS=1

if [ "$crashcore" = singboxr ]; then
	coretype=singbox
else
	coretype=clash
fi

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
		provider_temp_file="$(sed -n "1 p" "$CRASHDIR"/configs/${coretype}_providers.list | awk '{print $2}')"
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
	. "$CRASHDIR"/starts/check_core.sh && check_core && "$TMPDIR"/CrashCore -t -d "$BINDIR" -f "$TMPDIR"/config.yaml
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
		provider_temp_file="$(sed -n "1 p" "$CRASHDIR"/configs/${coretype}_providers.list | awk '{print $2}')"
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
	cat "$TMPDIR"/provider_temp_file | sed "s/{providers_tags}/$providers_tags/g" | sed "s/\"providers_tags\"/$providers_tags/g" > "$TMPDIR"/providers/outbounds.json
	rm -rf "$TMPDIR"/provider_temp_file
	#调用内核测试
	. "$CRASHDIR"/starts/check_core.sh && check_core && "$TMPDIR"/CrashCore merge "$TMPDIR"/config.json -C "$TMPDIR"/providers
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

#providers
providers() {
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
		echo -e " 1 \033[32m生成\033[0m包含全部节点/订阅的配置文件"
        echo -e " 2 选择\033[33m规则模版\033[0m     \033[32m$provider_temp_des\033[0m"
        echo -e " 3 \033[33m清理\033[0mproviders目录文件"
        echo "-----------------------------------------------"
        echo -e " 0 返回上级菜单"
        read -p "请输入对应字母或数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
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
        2)
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
        3)
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
