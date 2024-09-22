#!/bin/sh
# Copyright (C) Juewuy

error_down(){
	echo -e  "\033[33m请尝试切换至其他安装源后重新下载！\033[0m" 
	echo -e  "或者参考 \033[32;4mhttps://juewuy.github.io/bdaz\033[0m 进行本地安装！" 
	sleep 1
}
dir_avail(){
	df -h >/dev/null 2>&1 && h=$2
	df $h $1 |awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' |grep -E 'Ava|可用' |awk '{print $2}'
	}

#导入订阅、配置文件相关
setrules(){ #自定义规则
	set_rule_type(){
		echo -----------------------------------------------	
		echo -e "\033[33m请选择规则类型\033[0m"
		echo $rule_type | awk -F ' ' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num	
		case $num in
		0) ;;
		[0-9]*) 
			if [ $num -gt $(echo $rule_type | awk -F " " '{print NF}') ];then
				errornum
			else
				rule_type_set=$(echo $rule_type|cut -d' ' -f$num)
				echo -----------------------------------------------	
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
		echo -----------------------------------------------	
		echo -e "\033[36m请选择具体规则\033[0m"
		echo -e "\033[33m此处规则读取自现有配置文件，如果你后续更换配置文件时运行出错，请尝试重新添加\033[0m"
		echo $rule_group | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num	
		case $num in
		0) ;;
		[0-9]*) 
			if [ $num -gt $(echo $rule_group | awk -F "#" '{print NF}') ];then
				errornum
			else
				rule_group_set=$(echo $rule_group|cut -d'#' -f$num)
				rule_all="- ${rule_type_set},${rule_state_set},${rule_group_set}"
				[ -n "$(echo IP-CIDR SRC-IP-CIDR IP-CIDR6|grep "$rule_type_set")" ] && rule_all="${rule_all},no-resolve"
				echo $rule_all >> $YAMLSDIR/rules.yaml
				echo -----------------------------------------------	
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
		sed -i '/^ *$/d' $YAMLSDIR/rules.yaml
		cat $YAMLSDIR/rules.yaml | grep -Ev '^#' | awk -F "#" '{print " "NR" "$1$2$3}'
		echo -----------------------------------------------	
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		case $num in
		0)	;;
		'')	;;
		*)
			text=$(cat $YAMLSDIR/rules.yaml | grep -Ev '^#' | sed -n "$num p" | awk '{print $2}')
			if [ -n "$text" ];then	
				sed -i "/$text/d" $YAMLSDIR/rules.yaml
				sleep 1
				del_rule_type
			else
				errornum
			fi
		;;
		esac
	}
	echo -----------------------------------------------
	echo -e "\033[33m你可以在这里快捷管理自定义规则\033[0m"
	echo -e "如需批量操作，请手动编辑：\033[36m $YAMLSDIR/rules.yaml\033[0m"
	echo -e "\033[33msingbox和clash共用此处规则，可无缝切换！\033[0m"
	echo -e "大量规则请尽量使用rule-set功能添加，\033[31m此处过量添加可能导致启动卡顿！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 新增自定义规则"
	echo -e " 2 移除自定义规则"
	echo -e " 3 清空规则列表"
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] || echo -e " 4 配置节点绕过:	\033[36m$proxies_bypass\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	0)
	;;
	1)
		rule_type="DOMAIN-SUFFIX DOMAIN-KEYWORD IP-CIDR SRC-IP-CIDR DST-PORT SRC-PORT GEOIP GEOSITE IP-CIDR6 DOMAIN"
		rule_group="DIRECT#REJECT$(cat $YAMLSDIR/proxy-groups.yaml $YAMLSDIR/config.yaml 2>/dev/null | grep -Ev '^#' | grep -o '\- name:.*' | sed 's/- name: /#/g' | tr -d '\n')"
		set_rule_type
		setrules
	;;
	2)
		echo -----------------------------------------------
		if [ -s $YAMLSDIR/rules.yaml ];then
			del_rule_type
		else
			echo -e "请先添加自定义规则！"
			sleep 1
		fi
		setrules
	;;
	3)
		read -p "确认清空全部自定义规则？(1/0) > " res
		[ "$res" = "1" ] && sed -i '/^\s*[^#]/d' $YAMLSDIR/rules.yaml
		setrules
	;;
	4)
		echo -----------------------------------------------
		if [ "$proxies_bypass" = "未启用" ];then
			echo -e "\033[33m本功能会自动将当前配置文件中的节点域名或IP设置为直连规则以防止出现双重流量！\033[0m"
			echo -e "\033[33m请确保下游设备使用的节点与ShellCrash中使用的节点相同，否则无法生效！\033[0m"
			read -p "启用节点绕过？(1/0) > " res
			[ "$res" = "1" ] && proxies_bypass=已启用
		else
			proxies_bypass=未启用
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
		echo -----------------------------------------------	
		echo -e "\033[33m注意策略组名称必须和【自定义规则】或【自定义节点】功能中指定的策略组一致！\033[0m"
		echo -e "\033[33m建议先创建策略组，之后可在【自定义规则】或【自定义节点】功能中智能指定\033[0m"
		echo -e "\033[33m如需在当前策略组下添加节点，请手动编辑$YAMLSDIR/proxy-groups.yaml\033[0m"
		read -p "请输入自定义策略组名称(不支持纯数字且不要包含特殊字符！) > " new_group_name
		echo -----------------------------------------------	
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
		cat >> $YAMLSDIR/proxy-groups.yaml <<EOF
  - name: $new_group_name
    type: $new_group_type
    $new_group_url
    $interval
    proxies:
     - DIRECT
EOF
		sed -i "/^ *$/d" $YAMLSDIR/proxy-groups.yaml
		echo -----------------------------------------------	
		echo -e "\033[32m添加成功！\033[0m"
		
	}
	set_group_add(){
		echo -----------------------------------------------	
		echo -e "\033[36m请选择想要将本策略添加到的策略组\033[0m"
		echo -e "\033[32m如需添加到多个策略组，请一次性输入多个数字并用空格隔开\033[0m"
		echo -----------------------------------------------	
		echo $proxy_group | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo -----------------------------------------------	
		echo -e " 0 跳过添加"
		read -p "请输入对应数字(多个用空格隔开) > " char	
		case $char in
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
	echo -----------------------------------------------
	echo -e "\033[33m你可以在这里快捷管理自定义策略组\033[0m"
	echo -e "\033[36m如需修改或批量操作，请手动编辑：$YAMLSDIR/proxy-groups.yaml\033[0m"
	echo -----------------------------------------------
	echo -e " 1 添加自定义策略组"
	echo -e " 2 查看自定义策略组"
	echo -e " 3 清空自定义策略组"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	0)
	;;
	1)
		group_type="select url-test fallback load-balance"
		group_type_cn="手动选择 自动选择 故障转移 负载均衡"
		proxy_group="$(cat $YAMLSDIR/proxy-groups.yaml $YAMLSDIR/config.yaml 2>/dev/null | sed "/#自定义策略组开始/,/#自定义策略组结束/d" | grep -Ev '^#' | grep -o '\- name:.*' | sed 's/#.*//' | sed 's/- name: /#/g' | tr -d '\n' | sed 's/#//')"
		set_group_type
		setgroups
	;;
	2)
		echo -----------------------------------------------
		cat $YAMLSDIR/proxy-groups.yaml
		setgroups
	;;
	3)
		read -p "确认清空全部自定义策略组？(1/0) > " res
		[ "$res" = "1" ] && echo '#用于添加自定义策略组' > $YAMLSDIR/proxy-groups.yaml
		setgroups
	;;
	*)
		errornum
	;;
	esac
}
setproxies(){ #自定义clash节点
	set_proxy_type(){
		echo -----------------------------------------------	
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
		echo -----------------------------------------------	
		echo -e "\033[36m请选择想要将节点添加到的策略组\033[0m"
		echo -e "\033[32m如需添加到多个策略组，请一次性输入多个数字并用空格隔开\033[0m"
		echo -e "\033[33m如需自定义策略组，请先使用【管理自定义策略组功能】添加\033[0m"
		echo -----------------------------------------------	
		echo $proxy_group | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
		echo -----------------------------------------------	
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字(多个用空格隔开) > " char	
		case $char in
		0) ;;
		*) 
			for num in $char;do
				rule_group_set=$(echo $proxy_group|cut -d'#' -f$num)
				rule_group_add="${rule_group_add}#${rule_group_set}"
			done
			if [ -n "$rule_group_add" ];then
				echo "- {$proxy_state_set}$rule_group_add" >> $YAMLSDIR/proxies.yaml
				echo -----------------------------------------------	
				echo -e "\033[32m添加成功！\033[0m"
				unset rule_group_add
			else
				errornum
			fi
		;;
		esac
	}
	echo -----------------------------------------------
	echo -e "\033[33m你可以在这里快捷管理自定义节点\033[0m"
	echo -e "\033[36m如需批量操作，请手动编辑：$YAMLSDIR/proxies.yaml\033[0m"
	echo -----------------------------------------------
	echo -e " 1 添加自定义节点"
	echo -e " 2 管理自定义节点"
	echo -e " 3 清空自定义节点"
	echo -e " 4 配置节点绕过:	\033[36m$proxies_bypass\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	0)
	;;
	1)
		proxy_type="DOMAIN-SUFFIX DOMAIN-KEYWORD IP-CIDR SRC-IP-CIDR DST-PORT SRC-PORT GEOIP GEOSITE IP-CIDR6 DOMAIN MATCH"
		proxy_group="$(cat $YAMLSDIR/proxy-groups.yaml $YAMLSDIR/config.yaml 2>/dev/null | sed "/#自定义策略组开始/,/#自定义策略组结束/d" | grep -Ev '^#' | grep -o '\- name:.*' | sed 's/#.*//' | sed 's/- name: /#/g' | tr -d '\n' | sed 's/#//')"
		set_proxy_type
		setproxies
	;;
	2)	
		echo -----------------------------------------------
		sed -i '/^ *$/d' $YAMLSDIR/proxies.yaml 2>/dev/null
		if [ -s $YAMLSDIR/proxies.yaml ];then
			echo -e "当前已添加的自定义节点为:"
			cat $YAMLSDIR/proxies.yaml | grep -Ev '^#' | awk -F '[,,}]' '{print NR, $1, $NF}' | sed 's/- {//g'
			echo -----------------------------------------------	
			echo -e "\033[33m输入节点对应数字可以移除对应节点\033[0m"
			read -p "请输入对应数字 > " num
			if [ $num -le $(cat $YAMLSDIR/proxies.yaml | grep -Ev '^#' | wc -l) ];then
				sed -i "$num{/^\s*[^#]/d}" $YAMLSDIR/proxies.yaml
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
		[ "$res" = "1" ] && sed -i '/^\s*[^#]/d' $YAMLSDIR/proxies.yaml 2>/dev/null
		setproxies
	;;
	4)
		echo -----------------------------------------------
		if [ "$proxies_bypass" = "未启用" ];then
			echo -e "\033[33m本功能会自动将当前配置文件中的节点域名或IP设置为直连规则以防止出现双重流量！\033[0m"
			echo -e "\033[33m请确保下游设备使用的节点与ShellCrash中使用的节点相同，否则无法生效！\033[0m"
			read -p "启用节点绕过？(1/0) > " res
			[ "$res" = "1" ] && proxies_bypass=已启用
		else
			proxies_bypass=未启用
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
		[ "$skip_cert" != "未开启" ] && skip_cert_verify='skip-cert-verify: true'
		cat >> $TMPDIR/providers/providers.yaml <<EOF
    override:
      udp: true
      $skip_cert_verify
EOF
		}
	}
	if [ -z "$(grep "provider_temp_${coretype}" ${CRASHDIR}/configs/ShellCrash.cfg)" ];then
		provider_temp_file=$(sed -n "1 p" ${CRASHDIR}/configs/${coretype}_providers.list | awk '{print $2}')
	else
		provider_temp_file=$(grep "provider_temp_${coretype}" ${CRASHDIR}/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
	fi
	echo -----------------------------------------------
	if [ -s ${provider_temp_file} ];then
		ln -sf ${provider_temp_file} ${TMPDIR}/provider_temp_file
	else
		echo -e "\033[33m正在获取在线模版！\033[0m"
		${CRASHDIR}/start.sh get_bin ${TMPDIR}/provider_temp_file rules/${coretype}_providers/${provider_temp_file}
		[ -z "$(grep -o 'rules' ${TMPDIR}/provider_temp_file)" ] && {
			echo -e "\033[31m下载失败，请尝试更换安装源！\033[0m"
			setserver
			setproviders
		}
	fi
	#生成proxy_providers模块
	mkdir -p ${TMPDIR}/providers
	#预创建文件并写入对应文件头
	echo 'proxy-providers:' > ${TMPDIR}/providers/providers.yaml
	#切割模版文件
	sed -n '/^proxy-groups:/,/^[a-z]/ { /^rule/d; p; }' ${TMPDIR}/provider_temp_file > ${TMPDIR}/providers/proxy-groups.yaml
	sed -n '/^rule/,$p' ${TMPDIR}/provider_temp_file > ${TMPDIR}/providers/rules.yaml
	rm -rf ${TMPDIR}/provider_temp_file
	#生成providers模块
	if [ -n "$2" ];then
		gen_clash_providers_txt $1 $2
		providers_tags=$1
		echo '  - {name: '${1}', type: url-test, tolerance: 100, lazy: true, use: ['${1}']}' >> ${TMPDIR}/providers/proxy-groups.yaml
	else
		providers_tags=''
		while read line;do
			tag=$(echo $line | awk '{print $1}')
			url=$(echo $line | awk '{print $2}')
			providers_tags=$(echo "$providers_tags, $tag" | sed 's/^, //')
			gen_clash_providers_txt $tag $url
			echo '  - {name: '${tag}', type: url-test, tolerance: 100, lazy: true, use: ['${tag}']}' >> ${TMPDIR}/providers/proxy-groups.yaml
		done < ${CRASHDIR}/configs/providers.cfg
	fi
	#修饰模版文件并合并
	sed -i "s/{providers_tags}/$providers_tags/g" ${TMPDIR}/providers/proxy-groups.yaml
	cut -c 1- ${TMPDIR}/providers/providers.yaml ${TMPDIR}/providers/proxy-groups.yaml ${TMPDIR}/providers/rules.yaml > ${TMPDIR}/config.yaml
	rm -rf ${TMPDIR}/providers
	#调用内核测试
	${CRASHDIR}/start.sh core_check && ${TMPDIR}/CrashCore -t -d ${BINDIR} -f ${TMPDIR}/config.yaml
	if [ "$?" = 0 ];then
		echo -e "\033[32m配置文件生成成功！\033[0m"
		mv -f ${TMPDIR}/config.yaml ${CRASHDIR}/yamls/config.yaml
		read -p "是否立即启动/重启服务？(1/0) > " res
		[ "$res" = 1 ] && {
			start_core && $CRASHDIR/start.sh cronset '更新订阅'
			exit
		}
	else
		rm -rf ${TMPDIR}/CrashCore
		rm -rf ${TMPDIR}/config.yaml
		echo -e "\033[31m生成配置文件出错，请仔细检查输入！\033[0m"
	fi
}
gen_singbox_providers(){ #生成singbox的providers配置文件
	gen_singbox_providers_txt(){ 
		if [ -n "$(echo $2|grep -E '^./')" ];then
			cat >> ${TMPDIR}/providers/providers.json <<EOF
	{
      "tag": "${1}",
      "type": "local",
      "healthcheck_url": "https://www.gstatic.com/generate_204",
      "healthcheck_interval": "10m",
	  "path": "${2}"
	},
EOF
		else
			cat >> ${TMPDIR}/providers/providers.json <<EOF
	{
      "tag": "${1}",
      "type": "remote",
      "healthcheck_url": "https://www.gstatic.com/generate_204",
      "healthcheck_interval": "10m",
      "download_url": "${2}",
      "path": "./providers/${1}.yaml",
      "download_ua": "clash.meta",
      "download_interval": "24h",
      "download_detour": "DIRECT"
	},
EOF
		fi

	}
	if [ -z "$(grep "provider_temp_${coretype}" ${CRASHDIR}/configs/ShellCrash.cfg)" ];then
		provider_temp_file=$(sed -n "1 p" ${CRASHDIR}/configs/${coretype}_providers.list | awk '{print $2}')
	else
		provider_temp_file=$(grep "provider_temp_${coretype}" ${CRASHDIR}/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
	fi
	echo -----------------------------------------------
	if [ -s ${provider_temp_file} ];then
		ln -sf ${provider_temp_file} ${TMPDIR}/provider_temp_file
	else
		echo -e "\033[33m正在获取在线模版！\033[0m"
		${CRASHDIR}/start.sh get_bin ${TMPDIR}/provider_temp_file rules/${coretype}_providers/${provider_temp_file}
		[ -z "$(grep -o 'route' ${TMPDIR}/provider_temp_file)" ] && {
			echo -e "\033[31m下载失败，请尝试更换安装源！\033[0m"
			setserver
			setproviders
		}
	fi
	#生成outbound_providers模块
	mkdir -p ${TMPDIR}/providers
	#预创建文件并写入对应文件头
	cat > ${TMPDIR}/providers/providers.json <<EOF
{
  "outbound_providers": [
EOF
	cat > ${TMPDIR}/providers/outbounds_add.json <<EOF
{
  "outbounds": [
EOF
	#单独指定节点时使用特殊方式
	if [ -n "$2" ];then
		gen_singbox_providers_txt $1 $2
		providers_tags=\"$1\"
		echo '{ "tag": "'${1}'", "type": "urltest", "tolerance": 100, "providers": "'${1}'", "includes": ".*" },' >> ${TMPDIR}/providers/outbounds_add.json
	else
		providers_tags=''
		while read line;do
			tag=$(echo $line | awk '{print $1}')
			url=$(echo $line | awk '{print $2}')
			providers_tags=$(echo "$providers_tags, \"$tag\"" | sed 's/^, //')
			gen_singbox_providers_txt $tag $url
			echo '{ "tag": "'${tag}'", "type": "urltest", "tolerance": 100, "providers": "'${tag}'", "includes": ".*" },' >> ${TMPDIR}/providers/outbounds_add.json
		done < ${CRASHDIR}/configs/providers.cfg
	fi
	#修复文件格式
	sed -i '$s/},/}]}/' ${TMPDIR}/providers/outbounds_add.json
	sed -i '$s/},/}]}/' ${TMPDIR}/providers/providers.json
	#使用模版生成outbounds和rules模块
	cat ${TMPDIR}/provider_temp_file | sed "s/{providers_tags}/$providers_tags/g" >> ${TMPDIR}/providers/outbounds.json
	rm -rf ${TMPDIR}/provider_temp_file
	#调用内核测试
	${CRASHDIR}/start.sh core_check && ${TMPDIR}/CrashCore merge ${TMPDIR}/config.json -C ${TMPDIR}/providers
	if [ "$?" = 0 ];then
		echo -e "\033[32m配置文件生成成功！\033[0m"
		mv -f ${TMPDIR}/config.json ${CRASHDIR}/jsons/config.json
		rm -rf ${TMPDIR}/providers
		read -p "是否立即启动/重启服务？(1/0) > " res
		[ "$res" = 1 ] && {
			start_core && $CRASHDIR/start.sh cronset '更新订阅'
			exit
		}
	else
		echo -e "\033[31m生成配置文件出错，请仔细检查输入！\033[0m"
		rm -rf ${TMPDIR}/CrashCore
		rm -rf ${TMPDIR}/providers
	fi
}
setproviders(){ #自定义providers
	#获取模版名称
	if [ -z "$(grep "provider_temp_${coretype}" ${CRASHDIR}/configs/ShellCrash.cfg)" ];then
		provider_temp_des=$(sed -n "1 p" ${CRASHDIR}/configs/${coretype}_providers.list | awk '{print $1}')
	else
		provider_temp_file=$(grep "provider_temp_${coretype}" ${CRASHDIR}/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
		provider_temp_des=$(grep "$provider_temp_file" ${CRASHDIR}/configs/${coretype}_providers.list | awk '{print $1}')
		[ -z "$provider_temp_des" ] && provider_temp_des=$provider_temp_file
	fi
	echo -----------------------------------------------
	echo -e "\033[33m你可以在这里快捷管理与生成自定义的providers提供者\033[0m"
	echo -e "\033[36m支持在线及本地的Yaml格式配置导入\033[0m"
	echo -e "\033[33msingboxp内核暂不支持跳过证书验证功能\033[0m"
	[ -s $CRASHDIR/configs/providers.cfg ] && { 
		echo -----------------------------------------------
		echo -e "\033[36m输入对应数字可管理providers提供者\033[0m"
		cat $CRASHDIR/configs/providers.cfg | awk -F "#" '{print " "NR" "$1" "$2}'
	}
	echo -----------------------------------------------
	echo -e " a \033[36m添加\033[0mproviders提供者"
	echo -e " b \033[32m生成\033[0m基于providers的配置文件"
	echo -e " c 选择\033[33m规则模版\033[0m     \033[32m$provider_temp_des\033[0m"
	echo -e " d \033[31m清空\033[0mproviders列表"
	echo -e " e \033[33m清理\033[0mproviders目录"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	0)
	;;	
	[1-9]|[1-9][0-9])
		provider_name=$(sed -n "$num p" $CRASHDIR/configs/providers.cfg | awk '{print $1}')
		provider_url=$(sed -n "$num p" $CRASHDIR/configs/providers.cfg | awk '{print $2}')
		if [ -z "$provider_name" ];then
			errornum
		else
			echo -----------------------------------------------
			echo -e " 1 修改代理提供者：\033[36m$provider_name\033[0m"
			echo -e " 2 修改链接地址：\033[32m$provider_url\033[0m"
			echo -e " 3 生成\033[33m仅包含此提供者\033[0m的配置文件"
			echo -e " 4 \033[31m移除此提供者\033[0m"
			echo -----------------------------------------------
			echo -e " 0 返回上级菜单" 
			read -p "请选择需要执行的操作 > " num
			case "$num" in
			0)
			;;
			1)
				read -p "请输入代理提供者的名称或者代称(如有多个提供者不可重复) > " name
				if [ -n "$name" ] && [ -z "$(grep "$name" $CRASHDIR/configs/providers.cfg)" ];then
					sed -i "s|$provider_name $provider_url|$name $provider_url|" $CRASHDIR/configs/providers.cfg
				else
					echo -e "\033[31m输入错误，请重新输入！\033[0m" 
				fi
			;;	
			2)
				read -p "请输入providers订阅地址或本地相对路径 > " link
				if [ -n "$(echo $link | grep -E '.*\..*|^\./')" ] && [ -z "$(grep "$link" $CRASHDIR/configs/providers.cfg)" ];then
					link=$(echo $link | sed 's/\&/\\\&/g') #特殊字符添加转义
					sed -i "s|$provider_name $provider_url|$provider_name $link|" $CRASHDIR/configs/providers.cfg
				else
					echo -e "\033[31m输入错误，请重新输入！\033[0m" 
				fi
			;;	
			3)
				gen_${coretype}_providers $provider_name $provider_url
			;;	
			4)
				sed -i "/^$provider_name /d" $CRASHDIR/configs/providers.cfg
			;;
			*)
				errornum
			;;
			esac
			sleep 1
		fi
		setproviders
	;;
	a)
		echo -----------------------------------------------
		echo -e "支持填写在线的\033[32mYClash订阅地址\033[0m或者\033[32m本地Clash配置文件\033[0m"
		echo -e "本地配置文件请放在\033[32m$CRASHDIR\033[0m目录下，并填写相对路径如【\033[32m./providers/test.yaml\033[0m】"
		echo -----------------------------------------------
		read -p "请输入providers订阅地址或本地相对路径 > " link
		[ -n "$(echo $link | grep -E '.*\..*|^\./')" ] && {
			read -p "请输入代理提供者的名称或者代号(不可重复) > " name
			[ -n "$name" ] && [ -z "$(grep "name" $CRASHDIR/configs/providers.cfg)" ] && { 
				echo -----------------------------------------------
				echo -e "代理提供者：\033[36m$name\033[0m"
				echo -e "链接地址/路径：\033[32m$link\033[0m"
				read -p "确认添加？(1/0) > " res
					[ "$res" = 1 ] && {
						echo "$name $link" >> $CRASHDIR/configs/providers.cfg
						echo -e "\033[32mproviders已添加！\033[0m" 
					}
			}
		}
		[ "$?" != 0 ] && echo -e "\033[31m操作已取消！\033[0m"
		sleep 1
		setproviders
	;;
	b)	
		echo -----------------------------------------------
		if [ -s $CRASHDIR/configs/providers.cfg ];then
			echo -e "\033[33msingboxp与mihomo内核的providers配置文件不互通！\033[0m"
			echo -----------------------------------------------
			read -p "确认生成${coretype}配置文件？(1/0) > " res
			[ "$res" = "1" ] && {
				gen_${coretype}_providers
			}
		else
			echo -e "\033[31m你还未添加providers提供者，请先添加！\033[0m"
			sleep 1
		fi
		setproviders
	;;
	c)	
		echo -----------------------------------------------
		echo -e "当前规则模版为：\033[32m$provider_temp_des\033[0m"
		echo -e "\033[33m请选择在线模版：\033[0m"
		echo -----------------------------------------------
		cat ${CRASHDIR}/configs/${coretype}_providers.list | awk '{print " "NR" "$1}'
		echo -----------------------------------------------
		echo -e " a 使用\033[36m本地模版\033[0m"
		echo -----------------------------------------------
		read -p "请输入对应字母或数字 > " num
		case $num in
		0)
		;;
		a)
			read -p "请输入模版的路径(绝对路径) > " dir
			if [ -s $dir ];then
				provider_temp_file=$dir
				setconfig provider_temp_${coretype} $provider_temp_file
				echo -e "\033[32m设置成功！\033[0m"
			else
				echo -e "\033[31m输入错误，找不到对应模版文件！\033[0m"
			fi
			sleep 1
		;;
		*)
			provider_temp_file=$(sed -n "$num p" ${CRASHDIR}/configs/${coretype}_providers.list 2>/dev/null | awk '{print $2}')
			if [ -z "$provider_temp_file" ];then
				errornum
			else
				setconfig provider_temp_${coretype} $provider_temp_file
			fi
		;;
		esac
		setproviders
	;;
	d)
		read -p "确认清空全部providers提供者？(1/0) > " res
		[ "$res" = "1" ] && rm -rf $CRASHDIR/configs/providers.cfg
		setproviders
	;;
	e)
		echo -e "\033[33m将清空 $CRASHDIR/providers 目录下所有内容\033[0m"
		read -p "是否继续？(1/0) > " res
		[ "$res" = "1" ] && rm -rf $CRASHDIR/providers
		setproviders
	;;
	*)
		errornum
	;;
	esac
}

set_clash_adv(){ #自定义clash高级规则
		[ ! -f $YAMLSDIR/user.yaml ] && cat > $YAMLSDIR/user.yaml <<EOF
#用于编写自定义设定(可参考https://lancellc.gitbook.io/clash/clash-config-file/general 或 https://docs.metacubex.one/function/general)
#端口之类请在脚本中修改，否则不会加载
#port: 7890
EOF
		[ ! -f $YAMLSDIR/others.yaml ] && cat > $YAMLSDIR/others.yaml <<EOF
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
		echo -----------------------------------------------
		echo -e "\033[32m已经创建自定义设定文件：$YAMLSDIR/user.yaml ！\033[0m"
		echo -e "\033[33m可用于编写自定义的DNS，等功能\033[0m"
		echo -----------------------------------------------
		echo -e "\033[32m已经创建自定义功能文件：$YAMLSDIR/others.yaml ！\033[0m"
		echo -e "\033[33m可用于编写自定义的锚点、入站、proxy-providers、sub-rules、rule-set、script等功能\033[0m"		
		echo -----------------------------------------------
		echo -e "Windows下请\n使用\033[33mWinSCP软件\033[0m进行编辑！\033[0m"
		echo -e "MacOS下请\n使用\033[33mSecureFX软件\033[0m进行编辑！\033[0m"
		echo -e "Linux本机可\n使用\033[33mvim\033[0m进行编辑(路由设备可能不显示中文请勿使用)！\033[0m"
}
set_singbox_adv(){ #自定义singbox配置文件
		echo -----------------------------------------------
		echo -e "singbox配置文件中，支持自定义的模块有：\033[0m"
		echo -e "\033[36mlog dns ntp inbounds outbounds outbound_providers route experimental\033[0m"
		echo -e "将相应json文件放入\033[33m$JSONSDIR\033[0m目录后即可在启动时加载"
		echo -----------------------------------------------
		echo -e "使用前请务必参考配置教程:\033[32;4m https://juewuy.github.io/nWTjEpkSK \033[0m"
}
override(){ #配置文件覆写
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	echo -----------------------------------------------
	echo -e "\033[30;47m 欢迎使用配置文件覆写功能！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 自定义\033[32m端口及秘钥\033[0m"
	echo -e " 2 管理\033[36m自定义规则\033[0m"
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] || {
		echo -e " 3 管理\033[33m自定义节点\033[0m"
		echo -e " 4 管理\033[36m自定义策略组\033[0m"
	}
	echo -e " 5 \033[32m自定义\033[0m高级功能"
	[ "$disoverride" != 1 ] && echo -e " 9 \033[33m禁用\033[0m配置文件覆写"
	echo -----------------------------------------------
	[ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	1)
		if [ -n "$(pidof CrashCore)" ];then
			echo -----------------------------------------------
			echo -e "\033[33m检测到服务正在运行，需要先停止服务！\033[0m"
			read -p "是否停止服务？(1/0) > " res
			if [ "$res" = "1" ];then
				${CRASHDIR}/start.sh stop
				setport
			fi
		else
			setport
		fi
		override
	;;
	2)
		setrules
		override
	;;
	3)
		setproxies
		override
	;;
	4)
		setgroups
		override
	;;
	5)
		[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && set_singbox_adv || set_clash_adv
		sleep 3
		override
	;;
	9)
		echo -----------------------------------------------
		echo -e "\033[33m此功能可能会导致严重问题！启用后脚本中大部分功能都将禁用！！！\033[0m"
		echo -e "如果你不是非常了解$crashcore的运行机制，切勿开启！\033[0m"
		echo -e "\033[33m继续后如出现任何问题，请务必自行解决，一切提问恕不受理！\033[0m"
		echo -----------------------------------------------
		sleep 2
		read -p "我确认遇到问题可以自行解决[1/0] > " res
		[ "$res" = '1' ] && {
			disoverride=1
			setconfig disoverride $disoverride
			echo -----------------------------------------------	  
			echo -e "\033[32m设置成功！\033[0m"
		}
		override
	;;
	*)
		errornum
	;;
	esac
}

gen_link_config(){ #选择在线规则
	echo -----------------------------------------------
	echo 当前使用规则为：$(grep -aE '^5' ${CRASHDIR}/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $2}')
	grep -aE '^5' ${CRASHDIR}/configs/servers.list | awk '{print " "NR"	"$2$4}'
	echo -----------------------------------------------
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^5' ${CRASHDIR}/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo 
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入配置
		rule_link=$num
		setconfig rule_link $rule_link
		echo -----------------------------------------------	  
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
gen_link_server(){ #选择在线服务器
	echo -----------------------------------------------
	echo -e "\033[36m以下为互联网采集的第三方服务器，具体安全性请自行斟酌！\033[0m"
	echo -e "\033[32m感谢以下作者的无私奉献！！！\033[0m"
	echo 当前使用后端为：$(grep -aE '^3|^4' ${CRASHDIR}/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	grep -aE '^3|^4' ${CRASHDIR}/configs/servers.list | awk '{print " "NR"	"$3"	"$2}'
	echo -----------------------------------------------
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^3|^4' ${CRASHDIR}/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入配置
		server_link=$num
		setconfig server_link $server_link
		echo -----------------------------------------------	  
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
gen_link_flt(){ #在线生成节点过滤
	[ -z "$exclude" ] && exclude="未设置"
	echo -----------------------------------------------
	echo -e "\033[33m当前过滤关键字：\033[47;30m$exclude\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m匹配关键字的节点会在导入时被【屏蔽】！！！\033[0m"
	echo -e "多个关键字可以用\033[30;47m | \033[0m号分隔"
	echo -e "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	echo -----------------------------------------------
	echo -e " 000   \033[31m删除\033[0m关键字"
	echo -e " 回车  取消输入并返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入关键字 > " exclude
	if [ "$exclude" = '000' ]; then
		echo -----------------------------------------------
		exclude=''
		echo -e "\033[31m 已删除节点过滤关键字！！！\033[0m"
	fi
	setconfig exclude \'$exclude\'
}
gen_link_ele(){ #在线生成节点筛选
	[ -z "$include" ] && include="未设置"
	echo -----------------------------------------------
	echo -e "\033[33m当前筛选关键字：\033[47;30m$include\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m仅有匹配关键字的节点才会被【导入】！！！\033[0m"
	echo -e "多个关键字可以用\033[30;47m | \033[0m号分隔"
	echo -e "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	echo -----------------------------------------------
	echo -e " 000   \033[31m删除\033[0m关键字"
	echo -e " 回车  取消输入并返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入关键字 > " include
	if [ "$include" = '000' ]; then
		echo -----------------------------------------------
		include=''
		echo -e "\033[31m 已删除节点匹配关键字！！！\033[0m"
	fi
	setconfig include \'$include\'
}
get_core_config(){ #调用工具下载
	${CRASHDIR}/start.sh get_core_config
	if [ "$?" = 0 ];then
		if [ "$inuserguide" != 1 ];then
			read -p "是否启动服务以使配置文件生效？(1/0) > " res 
			[ "$res" = 1 ] && start_core || main_menu
			exit;
		fi
	fi
}
gen_core_config_link(){ #在线生成工具
	echo -----------------------------------------------
	echo -e "\033[30;47m 欢迎使用在线生成配置文件功能！\033[0m"
	echo -----------------------------------------------
	#设置输入循环
	i=1
	while [ $i -le 99 ]
	do
		echo -----------------------------------------------
		echo -e "\033[33m本功能依赖第三方在线subconverter服务实现，脚本本身不提供任何代理服务！\033[0m"
		echo -e "\033[31m严禁使用本脚本从事任何非法活动，否则一切后果请自负！\033[0m"
		echo -----------------------------------------------
		echo -e "支持批量(<=99)导入订阅链接、分享链接"
		echo -----------------------------------------------
		echo -e " 1 \033[36m开始生成配置文件\033[0m（原文件将被备份）"
		echo -e " 2 设置\033[31m节点过滤\033[0m关键字 \033[47;30m$exclude\033[0m"
		echo -e " 3 设置\033[32m节点筛选\033[0m关键字 \033[47;30m$include\033[0m"
		echo -e " 4 选取在线\033[33m配置规则模版\033[0m"
		echo -e " 5 \033[0m选取在线生成服务器\033[0m"
		echo -e " 0 \033[31m撤销输入并返回上级菜单\033[0m"
		echo -----------------------------------------------
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
				setconfig Https
				setconfig Url \'$Url_link\'
				#获取在线yaml文件
				get_core_config
			else
				echo -----------------------------------------------
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
			echo -----------------------------------------------
			echo -e "\033[31m请输入正确的链接或者数字！\033[0m"
			sleep 1
		fi
	done
} 
set_core_config_link(){ #直接导入配置
	echo -----------------------------------------------
	echo -e "\033[32m仅限导入完整的配置文件链接！！！\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m有流媒体需求，请使用\033[32m6-1在线生成配置文件功能！！！\033[0m"
	echo -e "\033[33m如不了解机制，请使用\033[32m6-1在线生成配置文件功能！！！\033[0m"
	echo -e "\033[33m如遇任何问题，请使用\033[32m6-1在线生成配置文件功能！！！\033[0m"
	echo -e "\033[31m此功能可能会导致部分节点无法连接或者规则覆盖不完整！！！\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m0 返回上级菜单\033[0m"
	echo -----------------------------------------------
	read -p "请输入完整链接 > " link
	test=$(echo $link | grep -iE "tp.*://" )
	link=`echo ${link/\ \(*\)/''}`   #删除恶心的超链接内容
	link=`echo ${link//\&/\\\&}`   #处理分隔符
	if [ -n "$link" -a -n "$test" ];then
		echo -----------------------------------------------
		echo -e 请检查输入的链接是否正确：
		echo -e "\033[4;32m$link\033[0m"
		read -p "确认导入配置文件？原配置文件将被备份![1/0] > " res
			if [ "$res" = '1' ]; then
				#将用户链接写入配置
				sed -i '/Url=*/'d $CFG_PATH
				setconfig Https \'$link\'
				setconfig Url
				#获取在线yaml文件
				get_core_config
			else
				set_core_config_link
			fi
	elif [ "$link" = 0 ];then
		i=
	else
		echo -----------------------------------------------
		echo -e "\033[31m请输入正确的配置文件链接地址！！！\033[0m"
		echo -e "\033[33m仅支持http、https、ftp以及ftps链接！\033[0m"
		sleep 1
		set_core_config_link
	fi
}
set_core_config(){ #配置文件功能
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && config_path=${JSONSDIR}/config.json || config_path=${YAMLSDIR}/config.yaml
	echo -----------------------------------------------
	echo -e "\033[30;47m ShellCrash配置文件管理\033[0m"
	echo -----------------------------------------------
	echo -e " 1 在线\033[32m生成$crashcore配置文件\033[0m"
	if [ -f "$CRASHDIR"/v2b_api.sh ];then
		echo -e " 2 登录\033[33m获取订阅(推荐！)\033[0m"
	else
		echo -e " 2 在线\033[33m获取完整配置文件\033[0m"
	fi
	echo -e " 3 本地\033[32m生成providers配置文件\033[0m"	
	echo -e " 4 本地\033[33m上传完整配置文件\033[0m"
	echo -e " 5 设置\033[36m自动更新\033[0m"
	echo -e " 6 \033[32m自定义\033[0m配置文件"
	echo -e " 7 \033[33m更新\033[0m配置文件"
	echo -e " 8 \033[36m还原\033[0m配置文件"
	echo -----------------------------------------------
	[ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	1)
		if [ -n "$Url" ];then
			echo -----------------------------------------------
			echo -e "\033[33m检测到已记录的链接内容：\033[0m"
			echo -e "\033[4;32m$Url\033[0m"
			echo -----------------------------------------------
			read -p "清空链接/追加导入？[1/0] > " res
			if [ "$res" = '1' ]; then
				Url_link=""
				echo -----------------------------------------------
				echo -e "\033[31m链接已清空！\033[0m"
			else
				Url_link=$Url
			fi
		fi
		gen_core_config_link
	;;
	2)
		if [ -f "$CRASHDIR"/v2b_api.sh ];then
			. "$CRASHDIR"/v2b_api.sh
			set_core_config
		else
			echo -----------------------------------------------
			echo -e "\033[33m此功能可能会导致一些bug！！！\033[0m"
			echo -e "强烈建议你使用\033[32m在线生成配置文件功能！\033[0m"
			echo -e "\033[33m继续后如出现任何问题，请务必自行解决，一切提问恕不受理！\033[0m"
			echo -----------------------------------------------
			sleep 1
			read -p "我确认遇到问题可以自行解决[1/0] > " res
			if [ "$res" = '1' ]; then
				set_core_config_link
			else
				echo -----------------------------------------------
				echo -e "\033[32m正在跳转……\033[0m"
				sleep 1
				gen_core_config_link
			fi
		fi
	;;
	3)
		if [ "$crashcore" = meta -o "$crashcore" = clashpre ];then
			coretype=clash
			setproviders
		elif [ "$crashcore" = singboxp ];then
			coretype=singbox
			setproviders
		else
			echo -e "\033[33msingbox官方内核及Clash基础内核不支持此功能，请先更换内核！\033[0m"
			sleep 1
			checkupdate && setcore
		fi
		set_core_config
	;;
	4)
		echo -----------------------------------------------
		echo -e "\033[33m请将本地配置文件上传到/tmp目录并重命名为config.yaml或者config.json\033[0m"
		echo -e "\033[32m之后重新运行本脚本即可自动弹出导入提示！\033[0m"
		exit
	;;
	5)
		source ${CRASHDIR}/task/task.sh && task_menu
		set_core_config
	;;
	6)
		checkcfg=$(cat $CFG_PATH)
		override
		if [ -n "$PID" ];then
			checkcfg_new=$(cat $CFG_PATH)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
	;;
	7)
		if [ -z "$Url" -a -z "$Https" ];then
			echo -----------------------------------------------
			echo -e "\033[31m没有找到你的配置文件/订阅链接！请先输入链接！\033[0m"
			sleep 1
			set_core_config
		else
			echo -----------------------------------------------
			echo -e "\033[33m当前系统记录的链接为：\033[0m"
			echo -e "\033[4;32m$Url$Https\033[0m"
			echo -----------------------------------------------
			read -p "确认更新配置文件？[1/0] > " res
			if [ "$res" = '1' ]; then
				get_core_config
			else
				set_core_config
			fi
		fi
	;;
	8)
		if [ ! -f ${config_path}.bak ];then
			echo -----------------------------------------------
			echo -e "\033[31m没有找到配置文件的备份！\033[0m"
			set_core_config
		else
			echo -----------------------------------------------
			echo -e 备份文件共有"\033[32m`wc -l < ${config_path}.bak`\033[0m"行内容，当前文件共有"\033[32m`wc -l < ${config_path}`\033[0m"行内容
			read -p "确认还原配置文件？此操作不可逆！[1/0] > " res
			if [ "$res" = '1' ]; then
				mv ${config_path}.bak ${config_path}
				echo -----------------------------------------------
				echo -e "\033[32m配置文件已还原！请手动重启服务！\033[0m"
				sleep 1
			else 
				echo -----------------------------------------------
				echo -e "\033[31m操作已取消！返回上级菜单！\033[0m"
				set_core_config
			fi
		fi
	;;
	*)
		errornum
	esac
}
#下载更新相关
getscripts(){ #更新脚本文件
	${CRASHDIR}/start.sh get_bin ${TMPDIR}/update.tar.gz bin/clashfm.tar.gz
	if [ "$?" != "0" ];then
		echo -e "\033[33m文件下载失败！\033[0m"
		error_down
	else
		${CRASHDIR}/start.sh stop 2>/dev/null
		#解压
		echo -----------------------------------------------
		echo 开始解压文件！
		mkdir -p ${CRASHDIR} > /dev/null
		tar -zxf "${TMPDIR}/update.tar.gz" ${tar_para} -C ${CRASHDIR}/ 
		if [ $? -ne 0 ];then
			echo -e "\033[33m文件解压失败！\033[0m"
			error_down
		else
			source ${CRASHDIR}/init.sh >/dev/null
			echo -e "\033[32m脚本更新成功！\033[0m"
		fi		
	fi
	rm -rf ${TMPDIR}/update.tar.gz
	exit
}
setscripts(){
	echo -----------------------------------------------
	echo -e "当前脚本版本为：\033[33m $versionsh_l \033[0m"
	echo -e "最新脚本版本为：\033[32m $version_new \033[0m"
	echo -e "注意更新时会停止服务！"
	echo -----------------------------------------------
	read -p "是否更新脚本？[1/0] > " res
	if [ "$res" = '1' ]; then
		#下载更新
		getscripts
		#提示
		echo -----------------------------------------------
		echo -e "\033[32m管理脚本更新成功!\033[0m"
		echo -----------------------------------------------
		exit;
	fi
}

getcpucore(){ #自动获取内核架构
	cputype=$(uname -ms | tr ' ' '_' | tr '[A-Z]' '[a-z]')
	[ -n "$(echo $cputype | grep -E "linux.*armv.*")" ] && cpucore="armv5"
	[ -n "$(echo $cputype | grep -E "linux.*armv7.*")" ] && [ -n "$(cat /proc/cpuinfo | grep vfp)" ] && [ ! -d /jffs ] && cpucore="armv7"
	[ -n "$(echo $cputype | grep -E "linux.*aarch64.*|linux.*armv8.*")" ] && cpucore="arm64"
	[ -n "$(echo $cputype | grep -E "linux.*86.*")" ] && cpucore="386"
	[ -n "$(echo $cputype | grep -E "linux.*86_64.*")" ] && cpucore="amd64"
	if [ -n "$(echo $cputype | grep -E "linux.*mips.*")" ];then
		mipstype=$(echo -n I | hexdump -o 2>/dev/null | awk '{ print substr($2,6,1); exit}') #通过判断大小端判断mips或mipsle
		[ "$mipstype" = "0" ] && cpucore="mips-softfloat" || cpucore="mipsle-softfloat"
	fi
	[ -n "$cpucore" ] && setconfig cpucore $cpucore
}
setcpucore(){ #手动设置内核架构
	cpucore_list="armv5 armv7 arm64 386 amd64 mipsle-softfloat mipsle-hardfloat mips-softfloat"
	echo -----------------------------------------------
	echo -e "\033[31m仅适合脚本无法正确识别核心或核心无法正常运行时使用！\033[0m"
	echo -e "当前可供在线下载的处理器架构为："
	echo $cpucore_list | awk -F " " '{for(i=1;i<=NF;i++) {print i" "$i }}'
	echo -e "不知道如何获取核心版本？请参考：\033[36;4mhttps://juewuy.github.io/bdaz\033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	[ -n "$num" ] && setcpucore=$(echo $cpucore_list | awk '{print $"'"$num"'"}' )
	if [ -z "$setcpucore" ];then
		echo -e "\033[31m请输入正确的处理器架构！\033[0m"
		sleep 1
		cpucore=""
	else
		cpucore=$setcpucore
		setconfig cpucore $cpucore
	fi
}
setcoretype(){ #手动指定内核类型
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && core_old=singbox || core_old=clash
	echo -e "\033[33m请确认该自定义内核的类型：\033[0m"
	echo -e " 1 Clash基础内核"
	echo -e " 2 Clash-Premium内核"
	echo -e " 3 Clash-Meta内核"
	echo -e " 4 Sing-Box内核"
	echo -e " 5 Sing-Box-Puer内核"
	read -p "请输入对应数字 > " num
	case "$num" in
		2) crashcore=clashpre ;;
		3) crashcore=meta ;;
		4) crashcore=singbox ;;
		5) crashcore=singboxp ;;
		*) crashcore=clash ;;
	esac
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && core_new=singbox || core_new=clash
}
switch_core(){ #clash与singbox内核切换
	#singbox和clash内核切换时提示是否保留文件
	[ "$core_new" != "$core_old" ] && {
		[ "$dns_mod" = "redir_host" ] && [ "$core_old" = "clash" ] && setconfig dns_mod mix #singbox自动切换dns
		[ "$dns_mod" = "mix" ] && [ "$core_old" = "singbox" ] && setconfig dns_mod fake-ip #singbox自动切换dns
		echo -e "\033[33m已从$core_old内核切换至$core_new内核\033[0m"
		echo -e "\033[33m二者Geo数据库及yaml/json配置文件不通用\033[0m"
		read -p "是否保留相关数据库文件？(1/0) > " res
		[ "$res" = '0' ] && [ "$core_old" = "clash" ] && {
			 rm -rf ${CRASHDIR}/Country.mmdb
			 rm -rf ${CRASHDIR}/GeoSite.dat
			 setconfig Country_v
			 setconfig cn_mini_v
			 setconfig geosite_v
		}
		[ "$res" = '0' ] && [ "$core_old" = "singbox" ] && {
			 rm -rf ${CRASHDIR}/geoip.db
			 rm -rf ${CRASHDIR}/geosite.db
			 setconfig geoip_cn_v
			 setconfig geosite_cn_v
		}
	}
	if [ "$crashcore" = singbox -o "$crashcore" = singboxp ];then
		COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
	else
		COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
	fi
	setconfig COMMAND "$COMMAND" ${CRASHDIR}/configs/command.env && source ${CRASHDIR}/configs/command.env
}
getcore(){ #下载内核文件
	[ -z "$crashcore" ] && crashcore=singbox
	[ -z "$cpucore" ] && getcpucore
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && core_new=singbox || core_new=clash
	#获取在线内核文件
	echo -----------------------------------------------
	echo 正在在线获取$crashcore核心文件……
	if [ -n "$custcorelink" ];then
		zip_type=$(echo $custcorelink | grep -oE 'tar.gz$')
		[ -z "$zip_type" ] && zip_type=$(echo $custcorelink | grep -oE 'gz$')
		if [ -n "$zip_type" ];then
			${CRASHDIR}/start.sh webget ${TMPDIR}/core_new.${zip_type} "$custcorelink"
		else
			echo -e "\033[31m链接不是以.tar.gz或.gz结尾！下载已取消！\033[0m"
			exit
		fi
	else
		${CRASHDIR}/start.sh get_bin ${TMPDIR}/core_new.tar.gz bin/${crashcore}/${core_new}-linux-${cpucore}.tar.gz
	fi
	if [ "$?" = "1" ];then
		echo -e "\033[31m核心文件下载失败！\033[0m"
		rm -rf ${TMPDIR}/core_new.tar.gz
		[ -z "$custcorelink" ] && error_down
	else
		[ -n "$(pidof CrashCore)" ] && ${CRASHDIR}/start.sh stop #停止内核服务防止内存不足
		[ -f ${TMPDIR}/core_new.tar.gz ] && {
			mkdir -p ${TMPDIR}/core_tmp
			[ "$BINDIR" = "$TMPDIR" ] && rm -rf ${TMPDIR}/CrashCore #小闪存模式防止空间不足
			tar -zxf "${TMPDIR}/core_new.tar.gz" ${tar_para} -C ${TMPDIR}/core_tmp/
			for file in $(find ${TMPDIR}/core_tmp 2>/dev/null);do
				[ -f $file ] && [ -n "$(echo $file | sed 's#.*/##' | grep -iE '(CrashCore|sing|meta|mihomo|clash|premium)')" ] && mv -f $file ${TMPDIR}/core_new
			done
			rm -rf ${TMPDIR}/core_tmp
		}
		[ -f ${TMPDIR}/core_new.gz ] && gunzip ${TMPDIR}/core_new.gz && rm -rf ${TMPDIR}/core_new.gz
		chmod +x ${TMPDIR}/core_new
		[ "$crashcore" = unknow ] && setcoretype
		if [ "$crashcore" = singbox -o "$crashcore" = singboxp ];then
			core_v=$(${TMPDIR}/core_new version 2>/dev/null | grep version | awk '{print $3}')
		else
			core_v=$(${TMPDIR}/core_new -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
		fi
		if [ -z "$core_v" ];then
			echo -e "\033[31m核心文件下载成功但校验失败！请尝试手动指定CPU版本\033[0m"
			rm -rf ${TMPDIR}/core_new
			rm -rf ${TMPDIR}/core_new.tar.gz
			setcpucore
		else
			echo -e "\033[32m$crashcore核心下载成功！\033[0m"
			sleep 1
			mv -f ${TMPDIR}/core_new ${TMPDIR}/CrashCore
			if [ -f ${TMPDIR}/core_new.tar.gz ];then
				mv -f ${TMPDIR}/core_new.tar.gz ${BINDIR}/CrashCore.tar.gz
			else
				tar -zcf ${BINDIR}/CrashCore.tar.gz ${tar_para} -C ${TMPDIR} CrashCore
			fi
			setconfig crashcore $crashcore
			setconfig core_v $core_v
			setconfig custcorelink $custcorelink
			switch_core
		fi
	fi
}
setcustcore(){ #自定义内核
	checkcustcore(){
		[ "$api_tag" = "latest" ] && api_url=latest || api_url="tags/$api_tag"
		#通过githubapi获取内核信息
		echo -e "\033[32m正在获取内核文件链接！\033[0m"
		${CRASHDIR}/start.sh webget ${TMPDIR}/github_api https://api.github.com/repos/${project}/releases/${api_url}
		if [ "$?" = 0 ];then
			release_tag=$(cat ${TMPDIR}/github_api | grep '"tag_name":' | awk -F '"' '{print $4}')
			release_date=$(cat ${TMPDIR}/github_api | grep '"published_at":' | awk -F '"' '{print $4}')
			[ -n "$(echo $cpucore | grep mips)" ] && cpu_type=mips || cpu_type=$cpucore
			cat ${TMPDIR}/github_api | grep "browser_download_url" | grep -oE "https://github.com/${project}/releases/download.*linux.*${cpu_type}.*\.gz\"$"  | sed 's/"//' > ${TMPDIR}/core.list
			rm -rf ${TMPDIR}/github_api
			#
			if [ -s ${TMPDIR}/core.list ];then
				echo -----------------------------------------------
				echo -e "内核版本：\033[36m$release_tag\033[0m"
				echo -e "发布时间：\033[32m$release_date\033[0m"
				echo -----------------------------------------------
				echo -e "\033[33m请确认内核信息并选择：\033[0m"
				cat ${TMPDIR}/core.list | grep -oE "$release_tag.*" | sed 's|.*/||' | awk '{print " "NR" "$1}'
				echo -e " 0 返回上级菜单"
				echo -----------------------------------------------
				read -p "请输入对应数字 > " num	
				case "$num" in
				0)
					setcustcore
				;;
				[1-9]|[1-9][0-9])
					if [ "$num" -le "$(wc -l < ${TMPDIR}/core.list)" ];then
						custcorelink=$(sed -n "$num"p ${TMPDIR}/core.list)
						getcore
					else
						errornum
					fi
				;;
				*)
					errornum
				;;
				esac			
			else
				echo -e "\033[31m找不到可用内核，可能是作者没有编译相关CPU架构版本的内核文件！\033[0m"
				sleep 1
			fi
		else
			echo -e "\033[31m查找失败，请尽量在服务启动后再使用本功能！\033[0m"
			sleep 1		
		fi
		rm -rf ${TMPDIR}/core.list
	}
	[ -z "$cpucore" ] && getcpucore
	echo -----------------------------------------------
	echo -e "\033[36m此处内核通常源自互联网采集，此处致谢各位开发者！\033[0m"
	echo -e "\033[33m自定义内核未经过完整适配，使用出现问题请自行解决！\033[0m"
	echo -e "\033[31m自定义内核已适配定时任务，但不支持小闪存模式！\033[0m"
	echo -e "\033[32m如遇到网络错误请先启动ShellCrash服务！\033[0m"
	[ -n "$custcore" ] && {
	echo -----------------------------------------------
	echo -e "当前内核为：\033[36m$custcore\033[0m"
	}
	echo -----------------------------------------------
	echo -e "\033[33m请选择需要使用的核心！\033[0m"
	echo -e "1 \033[36mMetaCubeX/mihomo\033[32m@release\033[0m版本内核"
	echo -e "2 \033[36mMetaCubeX/mihomo\033[32m@alpha\033[0m版本内核"
	echo -e "3 \033[36myaling888/clash\033[32m@release\033[0m版本内核"
	echo -e "4 \033[36mSagerNet/sing-box\033[32m@release\033[0m版本内核"
	echo -e "5 \033[36mPuerNya/sing-box\033[0m内核(with_gvisor,with_wireguard)"
	echo -e "6 \033[36mSagerNet/sing-box\033[32m@1.7.8\033[0m版本内核(不支持rule-set)"
	echo -e "7 Premium-2023.08.17内核(已停止维护)"
	echo -e "a \033[33m自定义内核链接 \033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num	
	case "$num" in
	1)
		project=MetaCubeX/mihomo
		api_tag=latest
		crashcore=meta
		checkcustcore
	;;
	2)
		project=MetaCubeX/mihomo
		api_tag=Prerelease-Alpha
		crashcore=meta
		checkcustcore
	;;
	3)
		project=yaling888/clash
		api_tag=latest
		crashcore=clashpre
		checkcustcore	
	;;
	4)
		project=SagerNet/sing-box
		api_tag=latest
		crashcore=singbox
		checkcustcore
	;;
	5)
		project=juewuy/ShellCrash
		api_tag=singbox_core_PuerNya
		crashcore=singboxp
		checkcustcore
	;;
	6)
		project=SagerNet/sing-box
		api_tag=v1.7.8
		crashcore=singbox
		checkcustcore
	;;
	7)
		project=juewuy/ShellCrash
		api_tag=clash.premium.latest
		crashcore=clashpre
		checkcustcore
	;;
	a)
		read -p "请输入自定义内核的链接地址(必须是以.tar.gz或.gz结尾的压缩文件) > " link
		[ -n "$link" ] && custcorelink="$link"
		crashcore=unknow
		getcore
	;;
	*)
		errornum
	;;
	esac
}
setcore(){ #内核选择菜单
	#获取核心及版本信息
	[ -z "$crashcore" ] && crashcore="unknow" 
	[ ! -f ${CRASHDIR}/CrashCore.tar.gz ] && crashcore="未安装核心"
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && core_old=singbox || core_old=clash
	[ -n "$custcorelink" ] && custcore="$(echo $custcorelink | sed 's#.*github.com##; s#/releases/download/#@#; s#-linux.*$##')"
	###
	echo -----------------------------------------------
	[ -z "$cpucore" ] && getcpucore
	echo -e "当前内核：\033[42;30m $crashcore \033[47;30m$core_v\033[0m"
	echo -e "当前系统处理器架构：\033[32m $cpucore \033[0m"
	echo -e "\033[33m请选择需要使用的核心版本！\033[0m"
	echo -e "\033[36m如需本地上传，请将二进制文件上传至 /tmp 目录后重新运行crash命令\033[0m"
	echo -----------------------------------------------
	echo -e "1 \033[43;30m Clash \033[0m：	\033[32m占用低\033[0m"
	echo -e " >>\033[32m$clash_v  	\033[33m不支持Tun、Rule-set等\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://lancellc.gitbook.io\033[0m"
	echo -e "2 \033[43;30m SingBox \033[0m：	\033[32m支持全面占用低\033[0m"
	echo -e " >>\033[32m$singbox_v  	\033[33m不支持providers\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://sing-box.sagernet.org\033[0m"
	echo -e "3 \033[43;30m  Meta  \033[0m：	\033[32m多功能，支持全面\033[0m"
	echo -e " >>\033[32m$meta_v   	\033[33m占用略高，GeoSite可能不兼容华硕固件\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://wiki.metacubex.one\033[0m"
	echo -e "4 \033[43;30m SingBoxP \033[0m：	\033[32m支持ssr、providers、dns并发……\033[0m"
	echo -e " >>\033[32m$singboxp_v  \033[33mPuerNya分支版本\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://sing-boxp.dustinwin.top\033[0m"
	echo -----------------------------------------------
	echo -e "5 \033[36m自定义内核\033[0m	$custcore"
	echo -----------------------------------------------
	echo "9 手动指定处理器架构"
	echo -----------------------------------------------
	echo 0 返回上级菜单 
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	1)
		crashcore=clash
		custcorelink=''
		getcore
	;;
	2)
		crashcore=singbox
		custcorelink=''
		getcore
	;;
	3)
		[ -d "/jffs" ] && {
			echo -e "\033[31mMeta内核使用的GeoSite.dat数据库在华硕设备存在被系统误删的问题，可能无法使用!\033[0m"
			sleep 3
		}
		crashcore=meta
		custcorelink=''
		getcore
	;;
	4)
		crashcore=singboxp
		custcorelink=''
		getcore
	;;
	5)
		setcustcore
		setcore
	;;
	9)
		setcpucore
	;;
	*)
		errornum
	;;
	esac
}

getgeo(){ #下载Geo文件
	#生成链接
	echo -----------------------------------------------
	echo 正在从服务器获取数据库文件…………
	${CRASHDIR}/start.sh get_bin ${TMPDIR}/$geoname bin/geodata/$geotype
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		error_down
	else
		mv -f ${TMPDIR}/$geoname ${BINDIR}/$geoname
		echo -----------------------------------------------
		echo -e "\033[32m$geotype数据库文件下载成功！\033[0m"
		#全球版GeoIP和精简版CN-IP数据库不共存
		[ "$geoname" = "Country.mmdb" ] && {
			setconfig Country_v
			setconfig cn_mini_v
		}
		geo_v="$(echo $geotype | awk -F "." '{print $1}')_v"
		setconfig $geo_v $GeoIP_v
	fi
	sleep 1
}
setcustgeo(){ #下载自定义数据库文件
	getcustgeo(){
		echo -----------------------------------------------
		echo 正在获取数据库文件…………
		${CRASHDIR}/start.sh webget ${TMPDIR}/$geoname $custgeolink
		if [ "$?" = "1" ];then
			echo -----------------------------------------------
			echo -e "\033[31m文件下载失败！\033[0m"
			error_down
		else
			mv -f ${TMPDIR}/$geoname ${BINDIR}/$geoname
			echo -----------------------------------------------
			echo -e "\033[32m$geotype数据库文件下载成功！\033[0m"
		fi
		sleep 1
	}
	checkcustgeo(){
		[ "$api_tag" = "latest" ] && api_url=latest || api_url="tags/$api_tag"
		[ ! -s ${TMPDIR}/geo.list ] && { 
			echo -e "\033[32m正在查找可更新的数据库文件！\033[0m"
			${CRASHDIR}/start.sh webget ${TMPDIR}/github_api https://api.github.com/repos/${project}/releases/${api_url}
			release_tag=$(cat ${TMPDIR}/github_api | grep '"tag_name":' | awk -F '"' '{print $4}')
			cat ${TMPDIR}/github_api | grep "browser_download_url" | grep -oE 'releases/download.*' | grep -oiE 'geosite.*\.dat"$|country.*\.mmdb"$|geosite.*\.db"$|geoip.*\.db"$' | sed 's/"//' > ${TMPDIR}/geo.list
			rm -rf ${TMPDIR}/github_api
		}
		if [ -s ${TMPDIR}/geo.list ];then
			echo -e "请选择需要更新的数据库文件："
			echo -----------------------------------------------
			cat ${TMPDIR}/geo.list | awk '{print " "NR" "$1}'
			echo -e " 0 返回上级菜单"
			echo -----------------------------------------------
			read -p "请输入对应数字 > " num	
			case "$num" in
			0)
			;;
			[1-99])
				if [ "$num" -le "$(wc -l < ${TMPDIR}/geo.list)" ];then
					geotype=$(sed -n "$num"p ${TMPDIR}/geo.list)
					[ -n "$(echo $geotype | grep -oiE 'GeoSite.*dat')" ] && geoname=GeoSite.dat
					[ -n "$(echo $geotype | grep -oiE 'Country.*mmdb')" ] && geoname=Country.mmdb
					[ -n "$(echo $geotype | grep -oiE 'geosite.*db')" ] && geoname=geosite.db
					[ -n "$(echo $geotype | grep -oiE 'geoip.*db')" ] && geoname=geoip.db
					custgeolink=https://github.com/${project}/releases/download/${release_tag}/${geotype}
					getcustgeo
					checkcustgeo
				else
					errornum
				fi
			;;
			*)
				errornum
			;;
			esac
		else
			echo -e "\033[31m查找失败，请尽量在服务启动后再使用本功能！\033[0m"
			sleep 1
		fi
	}
	rm -rf ${TMPDIR}/geo.list
	echo -----------------------------------------------
	echo -e "\033[36m此处数据库均源自互联网采集，此处致谢各位开发者！\033[0m"
	echo -e "\033[32m请点击或复制链接前往项目页面查看具体说明！\033[0m"
	echo -e "\033[31m自定义数据库不支持定时任务及小闪存模式！\033[0m"
	echo -e "\033[33m如遇到网络错误请先启动ShellCrash服务！\033[0m"
	echo -e "\033[0m请选择需要更新的数据库项目来源：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 \033[36;4mhttps://github.com/MetaCubeX/meta-rules-dat\033[0m (Clash及SingBox)"
	echo -e " 2 \033[36;4mhttps://github.com/DustinWin/ruleset_geodata\033[0m (仅限Clash)"
	echo -e " 3 \033[36;4mhttps://github.com/DustinWin/ruleset_geodata\033[0m (仅限SingBox)"
	echo -e " 4 \033[36;4mhttps://github.com/lyc8503/sing-box-rules\033[0m (仅限SingBox)"
	echo -e " 5 \033[36;4mhttps://github.com/Loyalsoldier/geoip\033[0m (仅限Clash-GeoIP)"
	echo -----------------------------------------------
	echo -e " 9 \033[33m自定义数据库链接 \033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num	
	case "$num" in
	0)
	;;
	1)
		project=MetaCubeX/meta-rules-dat
		api_tag=latest
		checkcustgeo
		setcustgeo
	;;
	2)
		project=DustinWin/ruleset_geodata
		api_tag=clash
		checkcustgeo
		setcustgeo
	;;
	3)
		project=DustinWin/ruleset_geodata
		api_tag=sing-box
		checkcustgeo
		setcustgeo
	;;
	4)
		project=lyc8503/sing-box-rules
		api_tag=latest
		checkcustgeo	
		setcustgeo
	;;
	5)
		project=Loyalsoldier/geoip
		api_tag=latest
		checkcustgeo	
		setcustgeo
	;;
	9)
		read -p "请输入自定义数据库的链接地址 > " link
		[ -n "$link" ] && custgeolink="$link"
		getgeo
		setcustgeo
	;;
	*)
		errornum
	;;
	esac
}
setgeo(){ #数据库选择菜单
	source $CFG_PATH > /dev/null
	[ -n "$cn_mini_v" ] && geo_type_des=精简版 || geo_type_des=全球版 
	echo -----------------------------------------------
	echo -e "\033[36m请选择需要更新的Geo/CN数据库文件：\033[0m"
	echo -e "\033[36m全球版GeoIP和精简版CN-IP数据库不共存\033[0m"
	echo -e "\033[36mClash内核和SingBox内核的数据库文件不通用\033[0m"
	echo -e "在线数据库最新版本：\033[32m$GeoIP_v\033[0m"
	echo -----------------------------------------------
	[ "$cn_ip_route" = "已开启" ] && {
		echo -e " 1 CN-IP绕过文件(约0.1mb)	\033[33m$china_ip_list_v\033[0m"
		echo -e " 2 CN-IPV6绕过文件(约30kb)	\033[33m$china_ipv6_list_v\033[0m"
	}
	[ -z "$(echo "$crashcore" | grep sing)" ] && {
		echo -e " 3 Clash全球版GeoIP数据库(约6mb)	\033[33m$Country_v\033[0m"
		echo -e " 4 Clash精简版GeoIP_cn数据库(约0.1mb)	\033[33m$cn_mini_v\033[0m"
		echo -e " 5 Meta完整版GeoSite数据库(约5mb)	\033[33m$geosite_v\033[0m"
	}
	[ -n "$(echo "$crashcore" | grep sing)" ] && {
		echo -e " 6 SingBox精简版GeoIP_cn数据库(约0.3mb)	\033[33m$geoip_cn_v\033[0m"
		echo -e " 7 SingBox精简版GeoSite数据库(约0.8mb)	\033[33m$geosite_cn_v\033[0m"
		echo -e " 8 Rule_Set_geoip_cn数据库(约0.1mb)	\033[33m$srs_geoip_cn_v\033[0m"
		echo -e " 9 Rule_Set_geosite_cn数据库(约0.1mb)	\033[33m$srs_geosite_cn_v\033[0m"
	}
	echo -----------------------------------------------
	echo -e " a \033[32m自定义数据库文件\033[0m"
	echo -e " b \033[31m清理数据库文件\033[0m"
	echo " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	1)
		geotype=china_ip_list.txt
		geoname=cn_ip.txt
		getgeo
		setgeo
	;;
	2)
		geotype=china_ipv6_list.txt
		geoname=cn_ipv6.txt
		getgeo
		setgeo
	;;
	3)
		geotype=Country.mmdb
		geoname=Country.mmdb
		getgeo
		setgeo
	;;
	4)
		geotype=cn_mini.mmdb
		geoname=Country.mmdb
		getgeo
		setgeo
	;;
	5)
		geotype=geosite.dat
		geoname=GeoSite.dat
		getgeo
		setgeo
	;;
	6)
		geotype=geoip_cn.db
		geoname=geoip.db
		getgeo
		setgeo
	;;
	7)
		geotype=geosite_cn.db
		geoname=geosite.db
		getgeo
		setgeo
	;;
	8)
		geotype=srs_geoip_cn.srs
		geoname=geoip-cn.srs
		getgeo
		setgeo
	;;
	9)
		geotype=srs_geosite_cn.srs
		geoname=geosite-cn.srs
		getgeo
		setgeo
	;;
	a)
		setcustgeo
		setgeo
	;;	
	b)
		echo -----------------------------------------------
		echo -e "\033[33m这将清理$CRASHDIR目录下所有数据库文件！\033[0m"
		echo -e "\033[36m清理后启动服务即可自动下载所需文件~\033[0m"
		echo -----------------------------------------------
		read -p "确认清理？[1/0] > " res
		[ "$res" = '1' ] && {
			for file in cn_ip.txt cn_ipv6.txt Country.mmdb GeoSite.dat geoip.db geosite.db ;do
				rm -rf $CRASHDIR/$file
			done
			for var in Country_v cn_mini_v china_ip_list_v china_ipv6_list_v geosite_v geoip_cn_v geosite_cn_v ;do
				setconfig $var
			done
			rm -rf $CRASHDIR/*.srs
			echo -e "\033[33m所有数据库文件均已清理！\033[0m"
			sleep 1
		}
		setgeo
	;;	
	*)
		errornum
	;;
esac
}

getdb(){ #下载Dashboard文件
	dblink="${update_url}/"
	echo -----------------------------------------------
	echo 正在连接服务器获取安装文件…………
	${CRASHDIR}/start.sh get_bin ${TMPDIR}/clashdb.tar.gz bin/dashboard/${db_type}.tar.gz
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		echo -----------------------------------------------
		error_down
		setdb
	else
		echo -e "\033[33m下载成功，正在解压文件！\033[0m"
		mkdir -p $dbdir > /dev/null
		tar -zxf "${TMPDIR}/clashdb.tar.gz" ${tar_para} -C $dbdir > /dev/null
		[ $? -ne 0 ] && echo "文件解压失败！" && rm -rf ${TMPDIR}/clashfm.tar.gz && exit 1 
		#修改默认host和端口
		if [ "$db_type" = "clashdb" -o "$db_type" = "meta_db" -o "$db_type" = "meta_xd" ];then
			sed -i "s/127.0.0.1/${host}/g" $dbdir/assets/*.js
			sed -i "s/9090/${db_port}/g" $dbdir/assets/*.js
		else
			sed -i "s/127.0.0.1:9090/${host}:${db_port}/g" $dbdir/*.html
			#sed -i "s/7892/${db_port}/g" $dbdir/app*.js
		fi
		#写入配置文件
		setconfig hostdir \'$hostdir\'
		echo -----------------------------------------------
		echo -e "\033[32m面板安装成功！\033[0m"
		rm -rf ${TMPDIR}/clashdb.tar.gz
	fi
	sleep 1
}
setdb(){
	dbdir(){
		if [ -f /www/clash/CNAME -o -f ${CRASHDIR}/ui/CNAME ];then
			echo -----------------------------------------------
			echo -e "\033[31m检测到您已经安装过本地面板了！\033[0m"
			echo -----------------------------------------------
			read -p "是否覆盖安装？[1/0] > " res
			if [ "$res" = 1 ]; then
				rm -rf ${BINDIR}/ui
				[ -f /www/clash/CNAME ] && rm -rf /www/clash && dbdir=/www/clash
				[ -f ${CRASHDIR}/ui/CNAME ] && rm -rf ${CRASHDIR}/ui && dbdir=${CRASHDIR}/ui
				getdb
			else
				setdb
				echo -e "\033[33m安装已取消！\033[0m"
			fi
		elif [ -w /www -a -n "$(pidof nginx)" ];then
			echo -----------------------------------------------
			echo -e "请选择面板\033[33m安装目录：\033[0m"
			echo -----------------------------------------------
			echo -e " 1 在${CRASHDIR}/ui目录安装"
			echo -e " 2 在/www/clash目录安装"
			echo -----------------------------------------------
			echo " 0 返回上级菜单"
			read -p "请输入对应数字 > " num

			if [ "$num" = '1' ]; then
				dbdir=${CRASHDIR}/ui
				hostdir=":$db_port/ui"
				getdb
			elif [ "$num" = '2' ]; then
				dbdir=/www/clash
				hostdir='/clash'
				getdb
			else
				setdb
				echo -e "\033[33m安装已取消！\033[0m"
			fi
		else
				dbdir=${CRASHDIR}/ui
				hostdir=":$db_port/ui"
				getdb
		fi
	}

	echo -----------------------------------------------
	echo -e "\033[36m安装本地版dashboard管理面板\033[0m"
	echo -e "\033[32m打开管理面板的速度更快且更稳定\033[0m"
	echo -----------------------------------------------
	echo -e "请选择面板\033[33m安装类型：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 安装\033[32mYacd面板\033[0m(约1.1mb)"
	echo -e " 2 安装\033[32mYacd-Meta魔改面板\033[0m(约1.5mb)"
	echo -e " 3 安装\033[32mMetaXD面板\033[0m(约1.5mb)"
	[ "$crashcore" != singbox ] && {
		echo -e " 4 安装\033[32m基础面板\033[0m(约500kb)"
		echo -e " 5 安装\033[32mMeta基础面板\033[0m(约800kb)"
	}
	echo -e " 9 卸载\033[33m本地面板\033[0m"
	echo " 0 返回上级菜单"
	read -p "请输入对应数字 > " num

	case "$num" in
	0) ;;
	1)
		db_type=yacd
		dbdir
	;;
	2)
		db_type=meta_yacd
		dbdir
	;;
	3)
		db_type=meta_xd
		dbdir
	;;
	4)
		db_type=clashdb
		dbdir
	;;
	5)
		db_type=meta_db
		dbdir
	;;
	9)
		read -p "确认卸载本地面板？(1/0) > " res
		if [ "$res" = 1 ];then
			rm -rf /www/clash
			rm -rf ${CRASHDIR}/ui
			rm -rf ${BINDIR}/ui
			echo -----------------------------------------------
			echo -e "\033[31m面板已经卸载！\033[0m"
			sleep 1
		fi
	;;
	*)
		errornum
	;;
	esac
}

getcrt(){ #下载根证书文件
	echo -----------------------------------------------
	echo 正在连接服务器获取安装文件…………
	${CRASHDIR}/start.sh get_bin ${TMPDIR}/ca-certificates.crt bin/fix/ca-certificates.crt
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		error_down
	else
		echo -----------------------------------------------
		[ "$systype" = 'mi_snapshot' ] && cp -f ${TMPDIR}/ca-certificates.crt $CRASHDIR/tools #镜像化设备特殊处理
		[ -f $openssldir/certs ] && rm -rf $openssldir/certs #如果certs不是目录而是文件则删除并创建目录
		mkdir -p $openssldir/certs
		mv -f ${TMPDIR}/ca-certificates.crt $crtdir
		${CRASHDIR}/start.sh webget /dev/null https://baidu.com echooff rediron skipceroff
		if [ "$?" = "1" ];then
			export CURL_CA_BUNDLE=$crtdir
			echo "export CURL_CA_BUNDLE=$crtdir" >> /etc/profile
		fi
		echo -e "\033[32m证书安装成功！\033[0m"
		sleep 1
	fi
}
setcrt(){
	openssldir="$(openssl version -d 2>&1 | awk -F '"' '{print $2}')"
	if [ -d "$openssldir/certs/" ];then
 		crtdir="$openssldir/certs/ca-certificates.crt"
   	else
    		crtdir="/etc/ssl/certs/ca-certificates.crt"
 	fi
	if [ -n "$openssldir" ];then
		echo -----------------------------------------------
		echo -e "\033[36m安装/更新本地根证书文件(ca-certificates.crt)\033[0m"
		echo -e "\033[33m用于解决证书校验错误，x509报错等问题\033[0m"
		echo -e "\033[31m无上述问题的设备请勿使用！\033[0m"
		echo -----------------------------------------------
		[ -f "$crtdir" ] && echo -e "\033[33m检测到系统已经存在根证书文件($crtdir)了！\033[0m\n-----------------------------------------------"
		read -p "是否覆盖更新？(1/0) > " res

		if [ -z "$res" ];then
			errornum
		elif [ "$res" = '0' ]; then
			i=
		elif [ "$res" = '1' ]; then
			getcrt
		else
			errornum
		fi
	else
		echo -----------------------------------------------
		echo -e "\033[33m设备可能尚未安装openssl，无法安装证书文件！\033[0m"
		sleep 1
	fi
}
#安装源
setserver(){
	[ -z "$release_type" ] && release_name=未指定
	[ -n "$release_type" ] && release_name=${release_type}'(回退)'
	[ "$release_type" = stable ] && release_name=稳定版
	[ "$release_type" = master ] && release_name=公测版
	[ "$release_type" = dev ] && release_name=开发版
	[ -n "$url_id" ] && url_name=$(grep "$url_id" ${CRASHDIR}/configs/servers.list 2>/dev/null | awk '{print $2}') || url_name=$update_url
	saveserver(){
		#写入配置文件
		setconfig update_url \'$update_url\'
		setconfig url_id $url_id
		setconfig release_type $release_type
		echo -----------------------------------------------
		echo -e "\033[32m源地址切换成功！\033[0m"
	}
	echo -----------------------------------------------
	echo -e "\033[30;47m切换ShellCrash版本及更新源地址\033[0m"
	echo -e "当前版本：\033[4;33m$release_name\033[0m 当前源：\033[4;32m$url_name\033[0m"
	echo -----------------------------------------------
	grep -E "^1|$release_name" ${CRASHDIR}/configs/servers.list | awk '{print " "NR" "$2}'
	echo -----------------------------------------------
	echo -e " a 切换至\033[32m稳定版-stable\033[0m"
	echo -e " b 切换至\033[36m公测版-master\033[0m"
	echo -e " c 切换至\033[33m开发版-dev\033[0m"
	echo -----------------------------------------------
	echo -e " d 自定义源地址(用于本地源或自建源)"
	echo -e " e \033[31m版本回退\033[0m"
	echo -e " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应字母或数字 > " num
	case $num in
	0)
		checkupdate=false
	;;
	[1-99])
		url_id_new=$(grep -E "^1|$release_name" ${CRASHDIR}/configs/servers.list | sed -n ""$num"p" | awk '{print $1}')
		if [ -z "$url_id_new" ];then
			errornum
			sleep 1
			setserver
		elif [ "$url_id_new" -ge 200 ];then
			update_url=$(grep -E "^1|$release_name" ${CRASHDIR}/configs/servers.list | sed -n ""$num"p" | awk '{print $3}')
			url_id=''
			saveserver
		else
			url_id=$url_id_new
			update_url=''
			saveserver
		fi
		unset url_id_new
	;;
	a)
		release_type=stable
		[ -z "$url_id" ] && url_id=101
		saveserver
		setserver
	;;
	b)
		release_type=master
		[ -z "$url_id" ] && url_id=101
		saveserver
		setserver
	;;
	c)
		echo -----------------------------------------------
		echo -e "\033[33m开发版未经过妥善测试，可能依然存在大量bug！！！\033[0m"
		echo -e "\033[36m如果你没有足够的耐心或者测试经验，切勿使用此版本！\033[0m"
		echo -e "请务必加入我们的讨论组：\033[32;4mhttps://t.me/ShellClash\033[0m"
		read -p "是否依然切换到开发版？(1/0) > " res
		if [ "$res" = 1 ];then
			release_type=dev
			[ -z "$url_id" ] && url_id=101
			saveserver
		fi
		setserver
	;;
	d)
		echo -----------------------------------------------
		read -p "请输入个人源路径 > " update_url
		if [ -z "$update_url" ];then
			echo -----------------------------------------------
			echo -e "\033[31m取消输入，返回上级菜单\033[0m"
		else
			url_id=''
			release_type=''
			saveserver
		fi
	;;
	e)
		echo -----------------------------------------------
		if [ -n "$url_id" ] && [ "$url_id" -lt 200 ];then
			echo -ne "\033[32m正在获取版本信息！\033[0m\r"	
			${CRASHDIR}/start.sh get_bin ${TMPDIR}/release_version bin/release_version
			if [ "$?" = "0" ];then
				echo -e "\033[31m请选择想要回退至的稳定版版本：\033[0m"
				cat ${TMPDIR}/release_version | awk '{print " "NR" "$1}'
				echo -e " 0 返回上级菜单"
				read -p "请输入对应数字 > " num
				if [ -z "$num" -o "$num" = 0 ]; then
					setserver
				elif [ $num -le $(cat ${TMPDIR}/release_version 2>/dev/null | awk 'END{print NR}') ]; then
					release_type=$(cat ${TMPDIR}/release_version | awk '{print $1}' | sed -n "$num"p)
					update_url=''
					saveserver
				else
					echo -----------------------------------------------
					errornum
					sleep 1
					setserver
				fi
			else
				echo -----------------------------------------------
				echo -e "\033[31m版本回退信息获取失败，请尝试更换其他安装源！\033[0m"
				sleep 1
				setserver		
			fi
			rm -rf ${TMPDIR}/release_version
		else
			echo -e "\033[31m当前源不支持版本回退，请尝试更换其他安装源！\033[0m"
			sleep 1
			setserver
		fi
	;;
	*)
		errornum
	;;
	esac
}
#检查更新
checkupdate(){
	${CRASHDIR}/start.sh get_bin ${TMPDIR}/version_new bin/version echooff 
	[ "$?" = "0" ] && version_new=$(cat ${TMPDIR}/version_new | grep -oE 'versionsh=.*' | awk -F'=' '{ print $2 }')
	if [ -n "$version_new" ];then
		source ${TMPDIR}/version_new 2>/dev/null
	else
		echo -e "\033[31m检查更新失败！请尝试切换其他安装源！\033[0m"
		setserver
		[ "$checkupdate" = false ] || checkupdate
	fi
	rm -rf ${TMPDIR}/version_new
}
update(){
	echo -----------------------------------------------
	echo -ne "\033[32m正在检查更新！\033[0m\r"
	checkupdate
	[ -z "$core_v" ] && core_v=$crashcore
	core_v_new=$(eval echo \$${crashcore}_v)
	echo -e "\033[30;47m欢迎使用更新功能：\033[0m"
	echo -----------------------------------------------
	echo -e "当前目录(\033[32m${CRASHDIR}\033[0m)剩余空间：\033[36m$(dir_avail ${CRASHDIR} -h)\033[0m" 
	[ "$(dir_avail ${CRASHDIR})" -le 5120 ] && [ "$CRASHDIR" = "$BINDIR" ] && {
		echo -e "\033[33m当前目录剩余空间较低，建议开启小闪存模式！\033[0m" 
		sleep 1
	}
	echo -----------------------------------------------
	echo -e " 1 更新\033[36m管理脚本    \033[33m$versionsh_l\033[0m > \033[32m$version_new \033[36m$release_type\033[0m"
	echo -e " 2 切换\033[33m内核文件    \033[33m$core_v\033[0m > \033[32m$core_v_new\033[0m"
	echo -e " 3 更新\033[32m数据库文件\033[0m	> \033[32m$GeoIP_v\033[0m"
	echo -e " 4 安装本地\033[35mDashboard\033[0m面板"
	echo -e " 5 安装/更新本地\033[33m根证书文件\033[0m"
	echo -e " 6 查看\033[32mPAC\033[0m自动代理配置"
	echo -----------------------------------------------
	echo -e " 7 切换\033[36m安装源\033[0m及\033[36m安装版本\033[0m"
	echo -e " 8 \033[32m配置自动更新\033[0m"
	echo -e " 9 \033[31m卸载ShellCrash\033[0m"
	echo -----------------------------------------------
	echo -e "99 \033[36m鸣谢！\033[0m"
	echo -----------------------------------------------
	echo -e " 0 返回上级菜单" 
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then	
		setscripts	

	elif [ "$num" = 2 ]; then	
		setcore
		update
		
	elif [ "$num" = 3 ]; then	
		setgeo
		update
	
	elif [ "$num" = 4 ]; then	
		setdb
		update
		
	elif [ "$num" = 5 ]; then	
		setcrt
		update	
		
	elif [ "$num" = 6 ]; then	
		echo -----------------------------------------------
		echo -e "PAC配置链接为：\033[30;47m http://$host:$db_port/ui/pac \033[0m"
		echo -e "PAC的使用教程请参考：\033[4;32mhttps://juewuy.github.io/ehRUeewcv\033[0m"
		sleep 2
		update
		
	elif [ "$num" = 7 ]; then	
		setserver
		update
	elif [ "$num" = 8 ]; then
		source ${CRASHDIR}/task/task.sh && task_add
		update		
		
	elif [ "$num" = 9 ]; then
		uninstall
		exit
		
	elif [ "$num" = 99 ]; then		
		echo -----------------------------------------------
		echo -e "感谢：\033[32mClash项目 \033[0m作者\033[36m Dreamacro\033[0m"
		echo -e "感谢：\033[32msing-box项目 \033[0m作者\033[36m SagerNet\033[0m 项目地址：\033[32mhttps://github.com/SagerNet/sing-box\033[0m"
		echo -e "感谢：\033[32mMetaCubeX项目 \033[0m作者\033[36m MetaCubeX\033[0m 项目地址：\033[32mhttps://github.com/MetaCubeX\033[0m"
		echo -e "感谢：\033[32mYACD面板项目 \033[0m作者\033[36m haishanh\033[0m 项目地址：\033[32mhttps://github.com/haishanh/yacd\033[0m"
		echo -e "感谢：\033[32mSubconverter \033[0m作者\033[36m tindy2013\033[0m 项目地址：\033[32mhttps://github.com/tindy2013/subconverter\033[0m"
		echo -e "感谢：\033[32msing-box分支项目 \033[0m作者\033[36m PuerNya\033[0m 项目地址：\033[32mhttps://github.com/PuerNya/sing-box\033[0m"
		echo -e "感谢：\033[32mDustinWin相关项目 \033[0m作者\033[36m DustinWin\033[0m 作者地址：\033[32mhttps://github.com/DustinWin\033[0m"
		echo -----------------------------------------------
		echo -e "特别感谢：\033[36m所有帮助及赞助过此项目的同仁们！\033[0m"
		echo -----------------------------------------------
		sleep 2
		update
	else
		errornum
	fi
}
#新手引导
userguide(){

	forwhat(){
		echo -----------------------------------------------
		echo -e "\033[30;46m 欢迎使用ShellCrash新手引导！ \033[0m"
		echo -----------------------------------------------
		echo -e "\033[33m请先选择你的使用环境： \033[0m"
		echo -e "\033[0m(你之后依然可以在设置中更改各种配置)\033[0m"
		echo -----------------------------------------------
		echo -e " 1 \033[32m路由设备配置局域网透明代理\033[0m"
		echo -e " 2 \033[36mLinux设备仅配置本机代理\033[0m"
		[ -f "$CFG_PATH.bak" ] && echo -e " 3 \033[33m还原之前备份的设置\033[0m"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ] || [ "$num" -gt 4 ];then
			errornum
			forwhat
		elif [ "$num" = 1 ];then
			#设置运行模式
			redir_mod="Redir模式"
			setconfig redir_mod "$redir_mod"
			#自动识别IPV6
			[ -n "$(ip a 2>&1 | grep -w 'inet6' | grep -E 'global' | sed 's/.*inet6.//g' | sed 's/scope.*$//g')" ] && {
				setconfig ipv6_redir 已开启
				setconfig ipv6_support 已开启
				setconfig ipv6_dns 已开启
			}
			#设置开机启动
			[ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ] && /etc/init.d/shellcrash enable
			ckcmd systemctl && [ "$(cat /proc/1/comm)" = "systemd" ] && systemctl enable shellcrash.service > /dev/null 2>&1
			rm -rf ${CRASHDIR}/.dis_startup
			autostart=enable
			#检测IP转发
			if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "0" ];then
				echo -----------------------------------------------
				echo -e "\033[33m检测到你的设备尚未开启ip转发，局域网设备将无法正常连接网络，是否立即开启？\033[0m"
				read -p "是否开启？(1/0) > " res
				[ "$res" = 1 ] && {
					echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
					sysctl -w net.ipv4.ip_forward=1
				} && echo "已成功开启ipv4转发，如未正常开启，请手动重启设备！" || echo "开启失败！请自行谷歌查找当前设备的开启方法！"
			fi
		elif [ "$num" = 2 ];then
			setconfig redir_mod "Redir模式"
			setconfig crashcore "clash"
			setconfig common_ports "未开启"
			setconfig firewall_area '2'
			
		elif [ "$num" = 3 ];then
			mv -f $CFG_PATH.bak $CFG_PATH
			echo -e "\033[32m脚本设置已还原！\033[0m"
			echo -e "\033[33m请重新启动脚本！\033[0m"
			exit 0
		fi
	}
	forwhat
	#检测小内存模式
	dir_size=$(dir_avail ${CRASHDIR})
	if [ "$dir_size" -lt 10240 ];then
		echo -----------------------------------------------
		echo -e "\033[33m检测到你的安装目录空间不足10M，是否开启小闪存模式？\033[0m"
		echo -e "\033[0m开启后核心及数据库文件将被下载到内存中，这将占用一部分内存空间\033[0m"
		echo -e "\033[0m每次开机后首次运行服务时都会自动的重新下载相关文件\033[0m"
		echo -----------------------------------------------
		read -p "是否开启？(1/0) > " res
		[ "$res" = 1 ] && {
			BINDIR=/tmp/ShellCrash
			setconfig BINDIR /tmp/ShellCrash ${CRASHDIR}/configs/command.env
		}
	fi
	#检测及下载根证书
	openssldir="$(openssl version -d 2>&1 | awk -F '"' '{print $2}')"
	[ ! -d "$openssldir/certs" ] && openssldir=/etc/ssl
	if [ -d $openssldir/certs -a ! -f $openssldir/certs/ca-certificates.crt ];then
		echo -----------------------------------------------
		echo -e "\033[33m当前设备未找到根证书文件\033[0m"
		echo -----------------------------------------------
		read -p "是否下载并安装根证书？(1/0) > " res
		[ "$res" = 1 ] && checkupdate && getcrt
	fi
	#设置加密DNS
	if [ -s $openssldir/certs/ca-certificates.crt ];then
		dns_nameserver='https://223.5.5.5/dns-query, https://doh.pub/dns-query, tls://dns.rubyfish.cn:853'
		dns_fallback='https://1.0.0.1/dns-query, https://8.8.4.4/dns-query, https://doh.opendns.com/dns-query'
		setconfig dns_nameserver \'"$dns_nameserver"\'
		setconfig dns_fallback \'"$dns_fallback"\' 
	fi
	#开启公网访问
	sethost(){
		read -p "请输入你的公网IP地址 > " host
		echo $host | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
		if [ -z "$host" ];then
			echo -e "\033[31m请输入正确的IP地址！\033[0m"
			sethost
		fi
	}
	if ckcmd systemctl;then
		echo -----------------------------------------------
		echo -e "\033[32m是否开启公网访问Dashboard面板及socks服务？\033[0m"
		echo -e "注意当前设备必须有公网IP才能从公网正常访问"
		echo -e "\033[31m此功能会增加暴露风险请谨慎使用！\033[0m"
		echo -e "vps设备可能还需要额外在服务商后台开启相关端口"
		read -p "现在开启？(1/0) > " res
		if [ "$res" = 1 ];then
			read -p "请先设置面板访问秘钥 > " secret
			read -p "请先修改Socks服务端口(1-65535) > " mix_port
			read -p "请先设置Socks服务密码(账号默认为crash) > " sec
			[ -z "$sec" ] && authentication=crash:$sec
			host=$(curl ip.sb  2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
			if [ -z "$host" ];then
				sethost
			fi	
			public_support=已开启
			setconfig secret $secret
			setconfig mix_port $mix_port
			setconfig host $host
			setconfig public_support $public_support
			setconfig authentication \'$authentication\'
		fi
	fi
	#启用推荐的自动任务配置
	source ${CRASHDIR}/task/task.sh && task_recom
	#小米设备软固化
	if [ "$systype" = "mi_snapshot" ];then
		echo -----------------------------------------------
		echo -e "\033[33m检测到为小米路由设备，启用软固化可防止路由升级后丢失SSH\033[0m"
		read -p "是否启用软固化功能？(1/0) > " res
		[ "$res" = 1 ] && autoSSH
	fi
	#提示导入订阅或者配置文件
	[ ! -s $CRASHDIR/yamls/config.yaml -a ! -s $CRASHDIR/jsons/config.json ] && {
		echo -----------------------------------------------
		echo -e "\033[32m是否导入配置文件？\033[0m(这是运行前的最后一步)"
		echo -e "\033[0m你必须拥有一份配置文件才能运行服务！\033[0m"
		echo -----------------------------------------------
		read -p "现在开始导入？(1/0) > " res
		[ "$res" = 1 ] && inuserguide=1 && {
			if [ -f "$CRASHDIR"/v2b_api.sh ];then
				. "$CRASHDIR"/v2b_api.sh
			else
				set_core_config
			fi
			set_core_config
			inuserguide=""
		}
	}
	#回到主界面
	echo -----------------------------------------------
	echo -e "\033[36m很好！现在只需要执行启动就可以愉快的使用了！\033[0m"
	echo -----------------------------------------------
	read -p "立即启动服务？(1/0) > " res 
	[ "$res" = 1 ] && start_core && sleep 2
	main_menu
}
#测试菜单
debug(){
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && config_tmp=$TMPDIR/jsons || config_tmp=$TMPDIR/config.yaml
	echo -----------------------------------------------
	echo -e "\033[36m注意：Debug运行均会停止原本的内核服务\033[0m"
	echo -e "后台运行日志地址：\033[32m$TMPDIR/debug.log\033[0m"
	echo -e "如长时间运行后台监测，日志等级推荐error！防止文件过大！"
	echo -e "你也可以通过：\033[33mcrash -s debug 'warning'\033[0m 命令使用其他日志等级"
	echo -----------------------------------------------
	echo -e " 1 仅测试\033[32m$config_tmp\033[0m配置文件可用性"
	echo -e " 2 前台运行\033[32m$config_tmp\033[0m配置文件,不配置防火墙劫持(\033[33m使用Ctrl+C手动停止\033[0m)"
	echo -e " 3 后台运行完整启动流程,并配置防火墙劫持,日志等级:\033[31merror\033[0m"
	echo -e " 4 后台运行完整启动流程,并配置防火墙劫持,日志等级:\033[32minfo\033[0m"
	echo -e " 5 后台运行完整启动流程,并配置防火墙劫持,日志等级:\033[33mdebug\033[0m"
	echo -e " 6 后台运行完整启动流程,并配置防火墙劫持,且将错误日志打印到闪存：\033[32m$CRASHDIR/debug.log\033[0m"
	echo -----------------------------------------------
	echo -e " 8 后台运行完整启动流程,输出执行错误并查找上下文,之后关闭进程"
	[ -s $TMPDIR/jsons/inbounds.json ] && echo -e " 9 将\033[32m$config_tmp\033[0m下json文件合并为$TMPDIR/debug.json"
	echo -----------------------------------------------
	echo " 0 返回上级目录！"
	read -p "请输入对应数字 > " num	
	case "$num" in
	0) ;;
	1)
		$CRASHDIR/start.sh stop
		$CRASHDIR/start.sh bfstart
		if [ "$crashcore" = singbox -o "$crashcore" = singboxp ] ;then
			$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons &
			{ sleep 4 ; kill $! >/dev/null 2>&1 & }
			wait
		else
			${TMPDIR}/CrashCore -t -d ${BINDIR} -f ${TMPDIR}/config.yaml
		fi
		rm -rf ${TMPDIR}/CrashCore
		echo -----------------------------------------------
		exit
	;;
	2)
		$CRASHDIR/start.sh stop
		$CRASHDIR/start.sh bfstart
		$COMMAND
		rm -rf ${TMPDIR}/CrashCore
		echo -----------------------------------------------
		exit
	;;
	3)
		$CRASHDIR/start.sh debug error
		main_menu
	;;
	4)
		$CRASHDIR/start.sh debug info
		main_menu
	;;
	5)
		$CRASHDIR/start.sh debug debug
		main_menu
	;;
	6)
		echo -e "频繁写入闪存会导致闪存寿命降低，如非遇到会导致设备死机或重启的bug，请勿使用此功能！"
		read -p "是否继续？(1/0) > " res	
		[ "$res" = 1 ] && $CRASHDIR/start.sh debug debug flash
		main_menu
	;;
	8)
		$0 -d
		main_menu
	;;
	9)
		${CRASHDIR}/start.sh core_check && $TMPDIR/CrashCore merge $TMPDIR/debug.json -C $TMPDIR/jsons && echo -e "\033[32m合并成功！\033[0m"
		rm -rf ${TMPDIR}/CrashCore
		main_menu
	;;
	*)
		errornum
	;;	
	esac
}
testcommand(){
	[ "$crashcore" = singbox -o "$crashcore" = singboxp ] && config_path=${JSONSDIR}/config.json || config_path=${YAMLSDIR}/config.yaml
	echo -----------------------------------------------
	echo -e "\033[30;47m这里是测试命令菜单\033[0m"
	echo -e "\033[33m如遇问题尽量运行相应命令后截图提交issue或TG讨论组\033[0m"
	echo -----------------------------------------------
	echo " 1 Debug模式运行内核"
	echo " 2 查看系统DNS端口(:53)占用 "
	echo " 3 测试ssl加密(aes-128-gcm)跑分"
	echo " 4 查看ShellCrash相关路由规则"
	echo " 5 查看内核配置文件前40行"
	echo " 6 测试代理服务器连通性(google.tw)"
	echo -----------------------------------------------
	echo " 0 返回上级目录！"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
		main_menu
	elif [ "$num" = 0 ]; then
		main_menu
	elif [ "$num" = 1 ]; then
		debug
		testcommand
	elif [ "$num" = 2 ]; then
		echo -----------------------------------------------
		netstat -ntulp |grep 53
		echo -----------------------------------------------
		echo -e "可以使用\033[44m netstat -ntulp |grep xxx \033[0m来查询任意(xxx)端口"
		exit;
	elif [ "$num" = 3 ]; then
		echo -----------------------------------------------
		openssl speed -multi 4 -evp aes-128-gcm
		echo -----------------------------------------------
		exit;
	elif [ "$num" = 4 ]; then

		if [ "$firewall_mod" = "nftables" ];then
			nft list table inet shellcrash
		else
			[ "$firewall_area" = 1 -o "$firewall_area" = 3 -o "$firewall_area" = 5 -o "$vm_redir" = "已开启" ] && {
				echo ----------------Redir+DNS---------------------
				iptables -t nat -L PREROUTING --line-numbers
				iptables -t nat -L shellcrash_dns --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Redir模式|混合模式')" ] && iptables -t nat -L shellcrash --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
					echo ----------------Tun/Tproxy-------------------
					iptables -t mangle -L PREROUTING --line-numbers
					iptables -t mangle -L shellcrash_mark --line-numbers
				}
			}
			[ "$firewall_area" = 2 -o "$firewall_area" = 3 ] && {
				echo -------------OUTPUT-Redir+DNS----------------
				iptables -t nat -L OUTPUT --line-numbers
				iptables -t nat -L shellcrash_dns_out --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Redir模式|混合模式')" ] && iptables -t nat -L shellcrash_out --line-numbers
				[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
					echo ------------OUTPUT-Tun/Tproxy---------------
					iptables -t mangle -L OUTPUT --line-numbers
					iptables -t mangle -L shellcrash_mark_out --line-numbers
				}
			}
			[ "$ipv6_redir" = "已开启" ] && {
				[ "$firewall_area" = 1 -o "$firewall_area" = 3 ] && {
					ip6tables -t nat -L >/dev/null 2>&1 && {
						echo -------------IPV6-Redir+DNS-------------------
						ip6tables -t nat -L PREROUTING --line-numbers
						ip6tables -t nat -L shellcrashv6_dns --line-numbers
						[ -n "$(echo $redir_mod | grep -E 'Redir模式|混合模式')" ] && ip6tables -t nat -L shellcrashv6 --line-numbers
					}
					[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
						echo -------------IPV6-Tun/Tproxy------------------
						ip6tables -t mangle -L PREROUTING --line-numbers
						ip6tables -t mangle -L shellcrashv6_mark --line-numbers
					}
				}
			}
			[ "$vm_redir" = "已开启" ] && {
						echo -------------vm-Redir-------------------
						iptables -t nat -L shellcrash_vm --line-numbers
						iptables -t nat -L shellcrash_vm_dns --line-numbers
			}
		fi
		exit;
	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		sed -n '1,40p' ${config_path}
		echo -----------------------------------------------
		exit;
	elif [ "$num" = 6 ]; then
		echo "注意：依赖curl(不支持wget)，且测试结果不保证一定准确！"
		delay=`curl -kx ${authentication}@127.0.0.1:$mix_port -o /dev/null -s -w '%{time_starttransfer}' 'https://google.tw' & { sleep 3 ; kill $! >/dev/null 2>&1 & }` > /dev/null 2>&1
		delay=`echo |awk "{print $delay*1000}"` > /dev/null 2>&1
		echo -----------------------------------------------
		if [ `echo ${#delay}` -gt 1 ];then
			echo -e "\033[32m连接成功！响应时间为："$delay" ms\033[0m"
		else
			echo -e "\033[31m连接超时！请重试或检查节点配置！\033[0m"
		fi
		main_menu

	else
		errornum
		main_menu
	fi
}

case "$1" in
	*)
		$1
	;;
esac
