#!/bin/bash
# Copyright (C) Juewuy

error_down(){
	echo -e  "\033[33m请尝试切换至其他安装源后重新下载！\033[0m" 
	sleep 1
	setserver
}
dir_avail(){
	df $2 $1 |awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' |grep -E 'Ava|可用' |awk '{print $2}'
	}
#导入订阅、配置文件相关
linkconfig(){
	echo -----------------------------------------------
	echo 当前使用规则为：$(grep -aE '^5' $clashdir/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $2}')
	grep -aE '^5' $clashdir/configs/servers.list | awk '{print " "NR"	"$2$4}'
	echo -----------------------------------------------
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^5' $clashdir/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo 
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入mark
		rule_link=$num
		setconfig rule_link $rule_link
		echo -----------------------------------------------	  
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
linkserver(){
	echo -----------------------------------------------
	echo -e "\033[36m以下为互联网采集的第三方服务器，具体安全性请自行斟酌！\033[0m"
	echo -e "\033[32m感谢以下作者的无私奉献！！！\033[0m"
	echo 当前使用后端为：$(grep -aE '^3|^4' $clashdir/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	grep -aE '^3|^4' $clashdir/configs/servers.list | awk '{print " "NR"	"$3"	"$2}'
	echo -----------------------------------------------
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^3|^4' $clashdir/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入mark
		server_link=$num
		setconfig server_link $server_link
		echo -----------------------------------------------	  
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
linkfilter(){
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
linkfilter2(){
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
getyaml(){
	$clashdir/start.sh getyaml
	if [ "$?" = 0 ];then
		if [ "$inuserguide" != 1 ];then
			read -p "是否启动clash服务以使配置文件生效？(1/0) > " res 
			[ "$res" = 1 ] && clashstart || clashsh
			exit;
		fi
	fi
}
getlink(){
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
		link=`echo ${link/*\&url\=/""}`   #将clash完整链接还原成单一链接
		link=`echo ${link/\&config\=*/""}`   #将clash完整链接还原成单一链接
		
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
				#将用户链接写入mark
				setconfig Https
				setconfig Url \'$Url_link\'
				#获取在线yaml文件
				getyaml
			else
				echo -----------------------------------------------
				echo -e "\033[31m请先输入订阅或分享链接！\033[0m"
				sleep 1
			fi
			
		elif [ "$link" = '2' ]; then
			linkfilter
			
		elif [ "$link" = '3' ]; then
			linkfilter2
			
		elif [ "$link" = '4' ]; then
			linkconfig
			
		elif [ "$link" = '5' ]; then
			linkserver
			
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
getlink2(){
	echo -----------------------------------------------
	echo -e "\033[32m仅限导入完整clash配置文件链接！！！\033[0m"
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
		read -p "确认导入配置文件？原配置文件将被更名为config.yaml.bak![1/0] > " res
			if [ "$res" = '1' ]; then
				#将用户链接写入mark
				sed -i '/Url=*/'d $CFG_PATH
				setconfig Https \'$link\'
				setconfig Url
				#获取在线yaml文件
				getyaml
			else
				getlink2
			fi
	elif [ "$link" = 0 ];then
		i=
	else
		echo -----------------------------------------------
		echo -e "\033[31m请输入正确的配置文件链接地址！！！\033[0m"
		echo -e "\033[33m仅支持http、https、ftp以及ftps链接！\033[0m"
		sleep 1
		getlink2
	fi
}
setrules(){
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
			if [ $num -le $(cat $YAMLSDIR/rules.yaml | grep -Ev '^#' | grep -Ev '^ *$' | wc -l) ];then
				sed -i "$num{/^\s*[^#]/d}" $YAMLSDIR/rules.yaml
				del_rule_type
			else
				errornum
			fi
		;;
		esac
	}
	echo -----------------------------------------------
	echo -e "\033[33m你可以在这里快捷管理自定义规则\033[0m"
	echo -e "\033[36m如需批量操作，请手动编辑：$YAMLSDIR/rules.yaml\033[0m"
	echo -----------------------------------------------
	echo -e " 1 新增自定义规则"
	echo -e " 2 管理自定义规则"
	echo -e " 3 清空规则列表"
	echo -e " 4 配置节点绕过:	\033[36m$proxies_bypass\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	1)
		rule_type="DOMAIN-SUFFIX DOMAIN-KEYWORD IP-CIDR SRC-IP-CIDR DST-PORT SRC-PORT GEOIP GEOSITE IP-CIDR6 DOMAIN MATCH"
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
			echo -e "\033[33m请确保下游设备使用的节点与ShellClash中使用的节点相同，否则无法生效！\033[0m"
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
setgroups(){
	set_group_type(){
		echo -----------------------------------------------	
		echo -e "\033[33m注意策略组名称必须和【自定义规则】或【自定义节点】功能中指定的策略组一致！\033[0m"
		echo -e "\033[33m建议先创建策略组，之后可在【自定义规则】或【自定义节点】功能中智能指定\033[0m"
		echo -e "\033[33m如需在当前策略组下添加节点，请手动编辑$YAMLSDIR/proxy-groups.yaml\033[0m"
		read -p "请输入自定义策略组名称(不支持纯数字) > " new_group_name
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
setproxies(){
	set_proxy_type(){
		echo -----------------------------------------------	
		echo -e "\033[33m注意节点格式必须是单行,不包括括号,name:必须写在最前,例如：\033[0m"
		echo -e "\033[36m【name: \"test\", server: 192.168.1.1, port: 12345, type: socks5, udp: true】\033[0m"
		echo -e "更多写法请参考：\033[32m https://juewuy.github.io/ \033[0m"
		read -p "请输入节点 > " proxy_state_set
		[ -n "$(echo $proxy_state_set | grep -E "^name:")" ] && set_group_add || errornum
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
			echo -e "\033[33m请确保下游设备使用的节点与ShellClash中使用的节点相同，否则无法生效！\033[0m"
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
override(){
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	echo -----------------------------------------------
	echo -e "\033[30;47m 欢迎使用配置文件覆写功能！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 自定义\033[32m端口及秘钥\033[0m"
	echo -e " 2 管理\033[36m自定义规则\033[0m"
	echo -e " 3 管理\033[33m自定义节点\033[0m"
	echo -e " 4 管理\033[36m自定义策略组\033[0m"
	echo -e " 5 \033[32m自定义\033[0m高级功能"
	[ "$disoverride" != 1 ] && echo -e " 9 \033[33m禁用\033[0m配置文件覆写"
	echo -----------------------------------------------
	[ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	1)
		source $CFG_PATH
		if [ -n "$(pidof clash)" ];then
			echo -----------------------------------------------
			echo -e "\033[33m检测到clash服务正在运行，需要先停止clash服务！\033[0m"
			read -p "是否停止clash服务？(1/0) > " res
			if [ "$res" = "1" ];then
				$clashdir/start.sh stop
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
		sleep 3
		override
	;;
	9)
		echo -----------------------------------------------
		echo -e "\033[33m此功能可能会导致严重问题！启用后脚本中大部分功能都将禁用！！！\033[0m"
		echo -e "如果你不是非常了解Clash的运行机制，切勿开启！\033[0m"
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

clashlink(){
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	echo -----------------------------------------------
	echo -e "\033[30;47m 欢迎使用导入配置文件功能！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 在线\033[32m生成Clash配置文件\033[0m"
	echo -e " 2 导入\033[33mClash配置文件链接\033[0m"
	echo -e " 3 \033[36m管理\033[0m配置文件"
	echo -e " 4 \033[33m更新\033[0m配置文件"
	echo -e " 5 设置\033[36m自动更新\033[0m"
	echo -e " 6 配置文件\033[32m覆写\033[0m"
	echo -----------------------------------------------
	[ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
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
		getlink
	;;
	2)
		echo -----------------------------------------------
		echo -e "\033[33m此功能可能会导致严重bug！！！\033[0m"
		echo -e "强烈建议你使用\033[32m在线生成配置文件功能！\033[0m"
		echo -e "\033[33m继续后如出现任何问题，请务必自行解决，一切提问恕不受理！\033[0m"
		echo -----------------------------------------------
		sleep 1
		read -p "我确认遇到问题可以自行解决[1/0] > " res
		if [ "$res" = '1' ]; then
			getlink2
		else
			echo -----------------------------------------------
			echo -e "\033[32m正在跳转……\033[0m"
			sleep 1
			getlink
		fi
	;;
	3)
		if [ ! -f $YAMLSDIR/config.yaml.bak ];then
			echo -----------------------------------------------
			echo -e "\033[31m没有找到配置文件的备份！\033[0m"
			clashlink
		else
			echo -----------------------------------------------
			echo -e 备份文件共有"\033[32m`wc -l < $YAMLSDIR/config.yaml.bak`\033[0m"行内容，当前文件共有"\033[32m`wc -l < $YAMLSDIR/config.yaml`\033[0m"行内容
			read -p "确认还原配置文件？此操作不可逆！[1/0] > " res
			if [ "$res" = '1' ]; then
				mv $YAMLSDIR/config.yaml.bak $YAMLSDIR/config.yaml
				echo -----------------------------------------------
				echo -e "\033[32m配置文件已还原！请手动重启clash服务！\033[0m"
				sleep 1
			else 
				echo -----------------------------------------------
				echo -e "\033[31m操作已取消！返回上级菜单！\033[0m"
				clashlink
			fi
		fi
	;;
	4)
		if [ -z "$Url" -a -z "$Https" ];then
			echo -----------------------------------------------
			echo -e "\033[31m没有找到你的配置文件/订阅链接！请先输入链接！\033[0m"
			sleep 1
			clashlink
		else
			echo -----------------------------------------------
			echo -e "\033[33m当前系统记录的链接为：\033[0m"
			echo -e "\033[4;32m$Url$Https\033[0m"
			echo -----------------------------------------------
			read -p "确认更新配置文件？[1/0] > " res
			if [ "$res" = '1' ]; then
				getyaml
			else
				clashlink
			fi
		fi
	;;
	5)
		clashcron
	;;
	6)
		checkcfg=$(cat $CFG_PATH)
		override
		if [ -n "$PID" ];then
			checkcfg_new=$(cat $CFG_PATH)
			[ "$checkcfg" != "$checkcfg_new" ] && checkrestart
		fi
	;;
	*)
		errornum
	esac
}
#下载更新相关
gettar(){
	$clashdir/start.sh webget $TMPDIR/clashfm.tar.gz $tarurl
	if [ "$?" != "0" ];then
		echo -e "\033[33m文件下载失败！\033[0m"
		error_down
	else
		$clashdir/start.sh stop 2>/dev/null
		#解压
		echo -----------------------------------------------
		echo 开始解压文件！
		mkdir -p $clashdir > /dev/null
		tar -zxvf "$TMPDIR/clashfm.tar.gz" -C $clashdir/
		if [ $? -ne 0 ];then
			rm -rf $TMPDIR/clashfm.tar.gz
			echo -e "\033[33m文件解压失败！\033[0m"
			error_down
		else
			source $clashdir/init.sh >/dev/null
			echo -e "\033[32m脚本更新成功！\033[0m"
		fi		
	fi
	exit
}
getsh(){
	echo -----------------------------------------------
	echo -e "当前脚本版本为：\033[33m $versionsh_l \033[0m"
	echo -e "最新脚本版本为：\033[32m $release_new \033[0m"
	echo -e "注意更新时会停止clash服务！"
	echo -----------------------------------------------
	read -p "是否更新脚本？[1/0] > " res
	if [ "$res" = '1' ]; then
		tarurl=$update_url/bin/clashfm.tar.gz
		#下载更新
		gettar
		#提示
		echo -----------------------------------------------
		echo -e "\033[32m管理脚本更新成功!\033[0m"
		echo -----------------------------------------------
		exit;
	fi
}

getcpucore(){
	cputype=$(uname -ms | tr ' ' '_' | tr '[A-Z]' '[a-z]')
	[ -n "$(echo $cputype | grep -E "linux.*armv.*")" ] && cpucore="armv5"
	[ -n "$(echo $cputype | grep -E "linux.*armv7.*")" ] && [ -n "$(cat /proc/cpuinfo | grep vfp)" ] && [ ! -d /jffs/clash ] && cpucore="armv7"
	[ -n "$(echo $cputype | grep -E "linux.*aarch64.*|linux.*armv8.*")" ] && cpucore="armv8"
	[ -n "$(echo $cputype | grep -E "linux.*86.*")" ] && cpucore="386"
	[ -n "$(echo $cputype | grep -E "linux.*86_64.*")" ] && cpucore="amd64"
	if [ -n "$(echo $cputype | grep -E "linux.*mips.*")" ];then
		mipstype=$(echo -n I | hexdump -o 2>/dev/null | awk '{ print substr($2,6,1); exit}') #通过判断大小端判断mips或mipsle
		[ "$mipstype" = "0" ] && cpucore="mips-softfloat" || cpucore="mipsle-softfloat"
	fi
	[ -n "$cpucore" ] && setconfig cpucore $cpucore
}
setcpucore(){
	cpucore_list="armv5 armv7 armv8 386 amd64 mipsle-softfloat mipsle-hardfloat mips-softfloat"
	echo -----------------------------------------------
	echo -e "\033[31m仅适合脚本无法正确识别核心或核心无法正常运行时使用！\033[0m"
	echo -e "当前可供在线下载的处理器架构为："
	echo $cpucore_list | awk -F " " '{for(i=1;i<=NF;i++) {print i" "$i }}'
	echo -e "不知道如何获取核心版本？请参考：\033[36;4mhttps://juewuy.github.io/bdaz\033[0m"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	setcpucore=$(echo $cpucore_list | awk '{print $"'"$num"'"}' )
	if [ -z "$setcpucore" ];then
		echo -e "\033[31m请输入正确的处理器架构！\033[0m"
		sleep 1
		cpucore=""
	else
		cpucore=$setcpucore
		setconfig cpucore $cpucore
	fi
}
getcore(){
	[ -z "$clashcore" ] && clashcore=clashpre
	[ -z "$cpucore" ] && getcpucore
	#生成链接
	[ -z "$custcorelink" ] && corelink="$update_url/bin/$clashcore/clash-linux-$cpucore" || corelink="$custcorelink"
	#获取在线clash核心文件
	echo -----------------------------------------------
	echo 正在在线获取clash核心文件……
	$clashdir/start.sh webget $TMPDIR/clash.new $corelink
	if [ "$?" = "1" ];then
		echo -e "\033[31m核心文件下载失败！\033[0m"
		rm -rf $TMPDIR/clash.new
		[ -z "$custcorelink" ] && error_down
	else
		chmod +x $TMPDIR/clash.new 
		clashv=$($TMPDIR/clash.new -v 2>/dev/null | sed 's/ linux.*//;s/.* //')
		if [ -z "$clashv" ];then
			echo -e "\033[31m核心文件下载成功但校验失败！请尝试手动指定CPU版本\033[0m"
			rm -rf $TMPDIR/clash.new
			setcpucore
		else
			echo -e "\033[32m$clashcore核心下载成功！\033[0m"
			mv -f $TMPDIR/clash.new $bindir/clash
			chmod +x $bindir/clash 
			setconfig clashcore $clashcore
			setconfig clashv $version
		fi
	fi
}
setcustcore(){
	[ -z "$cpucore" ] && getcpucore
	echo -----------------------------------------------
	echo -e "\033[36m自定义内核均未经过适配，可能存在部分功能不兼容的问题！\033[0m"
	echo -e "\033[36m如你不熟悉clash的运行机制，请使用脚本已经适配过的内核！\033[0m"
	echo -e "\033[36m自定义内核不兼容小闪存模式，且下载可能依赖clash服务！\033[0m"
	echo -e "\033[33m继续后如出现任何问题，请务必自行解决，一切提问恕不受理！\033[0m"
	echo -----------------------------------------------
	sleep 1
	read -p "我确认遇到问题可以自行解决[1/0] > " res
	[ "$res" = '1' ] && {
		echo -e "\033[33m请选择需要使用的核心！\033[0m"
		echo -e "1 \033[32m 测试版ClashPre内核 \033[0m"
		echo -e "2 \033[32m 最新Meta.Alpha内核  \033[0m"
		echo -e "3 \033[33m 自定义内核链接 \033[0m"
		read -p "请输入对应数字 > " num	
		case "$num" in
		1)
			clashcore=clashpre
			custcorelink=https://github.com/juewuy/ShellClash/releases/download/clash.premium.latest/clash-linux-$cpucore
			getcore			
		;;
		2)
			clashcore=clash.meta
			custcorelink=https://github.com/juewuy/ShellClash/releases/download/clash.meta.alpha/clash-linux-$cpucore
			getcore			
		;;
		3)
			read -p "请输入自定义内核的链接地址(必须是二进制文件) > " link
			[ -n "$link" ] && custcorelink="$link"
			clashcore=clash.meta
			getcore
		;;
		*)
			errornum
		;;
		esac
	}
}
setcore(){
	#获取核心及版本信息
	[ ! -f $clashdir/clash ] && clashcore="未安装核心"
	###
	echo -----------------------------------------------
	[ -z "$cpucore" ] && getcpucore
	echo -e "当前clash核心：\033[42;30m $clashcore \033[47;30m$clashv\033[0m"
	echo -e "当前系统处理器架构：\033[32m $cpucore \033[0m"
	echo -e "\033[33m请选择需要使用的核心版本！\033[0m"
	echo -----------------------------------------------
	echo -e "1 \033[43;30m  Clash  \033[0m：	\033[32m占用低\033[0m"
	echo -e " (开源基础内核)  \033[33m不支持Tun、Rule-set等\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://lancellc.gitbook.io\033[0m"
	echo
	echo -e "2 \033[43;30m Clashpre \033[0m：	\033[32m支持Tun、Rule-set\033[0m"
	echo -e " (官方高级内核)  \033[33m不支持vless、hy协议\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://lancellc.gitbook.io\033[0m"
	echo
	echo -e "3 \033[43;30mClash.Meta\033[0m：	\033[32m多功能，支持最全面\033[0m"
	echo -e " (Meta稳定内核)  \033[33m内存占用较高\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://docs.metacubex.one\033[0m"
	echo
	echo -e "4 \033[32m自定义内核\033[0m：	\033[33m仅限专业用户使用\033[0m"
	echo
	echo "5 手动指定处理器架构"
	echo -----------------------------------------------
	echo 0 返回上级菜单 
	read -p "请输入对应数字 > " num
	case "$num" in
	1)
		clashcore=clash
		custcorelink=''
		getcore
	;;
	2)
		clashcore=clashpre
		custcorelink=''
		getcore
	;;
	3)
		clashcore=clash.meta
		custcorelink=''
		getcore
	;;
	4)
		setcustcore
	;;
	5)
		setcpucore
		setcore
	;;
	*)
		errornum
	;;
	esac
}

getgeo(){
	echo -----------------------------------------------
	echo 正在从服务器获取数据库文件…………
	$clashdir/start.sh webget $TMPDIR/$geoname $update_url/bin/geodata/$geotype
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		error_down
	else
		mv -f $TMPDIR/$geoname $bindir/$geoname
		echo -----------------------------------------------
		echo -e "\033[32mGeoIP/CN_IP数据库文件下载成功！\033[0m"
		Geo_v=$GeoIP_v
		setconfig Geo_v $GeoIP_v
		if [ "$geoname" = "Country.mmdb" ];then
			geotype=$geotype
			setconfig geotype $geotype
		fi
	fi
}
setgeo(){
	echo -----------------------------------------------
	[ "$geotype" = "cn_mini.mmdb" ] && echo -e "当前使用的是\033[47;30m精简版数据库\033[0m" || echo -e "当前使用的是\033[47;30m全球版数据库\033[0m"
	echo -e "\033[36m请选择需要更新/切换的GeoIP/CN_IP数据库：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 由\033[32malecthw\033[0m提供的全球版GeoIP数据库(约6mb)"
	echo -e " 2 由\033[32mHackl0us\033[0m提供的精简版CN-IP数据库(约0.2mb)"
	echo -e " 3 由\033[32m17mon\033[0m提供的CN-IP文件(需启用CN_IP绕过，约0.2mb)"
	echo -e " 4 由\033[32mChanthMiao\033[0m提供的CN-IPV6文件(需ipv6启用CN_IP绕过，约50kb)"
	[ "$clashcore" = "clash.meta" ] && \
	echo -e " 5 由\033[32mLoyalsoldier\033[0m提供的GeoSite数据库(限Meta内核，约4.5mb)"
	echo " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ "$num" = '1' ]; then
		geotype=Country.mmdb
		geoname=Country.mmdb
		getgeo
	elif [ "$num" = '2' ]; then
		geotype=cn_mini.mmdb
		geoname=Country.mmdb
		getgeo
	elif [ "$num" = '3' ]; then
		if [ "$cn_ip_route" = "已开启" ]; then
			geotype=china_ip_list.txt
			geoname=cn_ip.txt
			getgeo
		else
			echo -----------------------------------------------
			echo -e "\033[31m未开启绕过内核功能，无需更新CN-IP文件！！\033[0m"	
			sleep 1
		fi
	elif [ "$num" = '4' ]; then
		if [ "$cn_ipv6_route" = "已开启" -a "$ipv6_redir" = "已开启" ]; then
			geotype=china_ipv6_list.txt
			geoname=cn_ipv6.txt
			getgeo
		else
			echo -----------------------------------------------
			echo -e "\033[31m未开启ipv6下CN绕过功能，无需更新CN-IPV6文件！！\033[0m"	
			sleep 1
		fi
	elif [ "$num" = '5' ]; then
		geotype=geosite.dat
		geoname=GeoSite.dat
		getgeo
	else
		update
	fi
}

getdb(){
	#下载及安装
	if [ -f /www/clash/index.html -o -f $clashdir/ui/index.html ];then
		echo -----------------------------------------------
		echo -e "\033[31m检测到您已经安装过本地面板了！\033[0m"
		echo -----------------------------------------------
		read -p "是否覆盖安装？[1/0] > " res
		if [ "$res" = 1 ]; then
			rm -rf /www/clash
			rm -rf $clashdir/ui
			rm -rf $bindir/ui
		fi
	fi
	dblink="${update_url}/bin/dashboard/${db_type}.tar.gz"
	echo -----------------------------------------------
	echo 正在连接服务器获取安装文件…………
	$clashdir/start.sh webget $TMPDIR/clashdb.tar.gz $dblink
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		echo -----------------------------------------------
		error_down
		setdb
	else
		echo -e "\033[33m下载成功，正在解压文件！\033[0m"
		mkdir -p $dbdir > /dev/null
		tar -zxvf "$TMPDIR/clashdb.tar.gz" -C $dbdir > /dev/null
		if [ $? -ne 0 ];then
			tar -zxvf "$TMPDIR/clashdb.tar.gz" --no-same-permissions -C $dbdir > /dev/null
			[ $? -ne 0 ] && echo "文件解压失败！" && rm -rf $TMPDIR/clashfm.tar.gz && exit 1 
		fi
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
		rm -rf $TMPDIR/clashdb.tar.gz
		sleep 1
	fi
}
setdb(){
	dbdir(){
		if [ -w /www -a -n "$(pidof nginx)" ];then
			echo -----------------------------------------------
			echo -e "请选择面板\033[33m安装目录：\033[0m"
			echo -----------------------------------------------
			echo -e " 1 在$clashdir/ui目录安装"
			echo -e " 2 在/www/clash目录安装"
			echo -----------------------------------------------
			echo " 0 返回上级菜单"
			read -p "请输入对应数字 > " num

			if [ "$num" = '1' ]; then
				dbdir=$clashdir/ui
				hostdir=":$db_port/ui"
			elif [ "$num" = '2' ]; then
				dbdir=/www/clash
				hostdir='/clash'
			else
				setdb
			fi
		else
				dbdir=$clashdir/ui
				hostdir=":$db_port/ui"
		fi
	}

	echo -----------------------------------------------
	echo -e "\033[36m安装本地版dashboard管理面板\033[0m"
	echo -e "\033[32m打开管理面板的速度更快且更稳定\033[0m"
	echo -----------------------------------------------
	echo -e "请选择面板\033[33m安装类型：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 安装\033[32m官方面板\033[0m(约500kb)"
	echo -e " 2 安装\033[32mMeta面板\033[0m(约800kb)"
	echo -e " 3 安装\033[32mYacd面板\033[0m(约1.1mb)"
	echo -e " 4 安装\033[32mYacd-Meta魔改面板\033[0m(约1.5mb)"
	echo -e " 5 安装\033[32mMetaXD面板\033[0m(约1.5mb)"
	echo -e " 6 卸载\033[33m本地面板\033[0m"
	echo " 0 返回上级菜单"
	read -p "请输入对应数字 > " num

	if [ "$num" = '1' ]; then
		db_type=clashdb
		dbdir
		getdb
	elif [ "$num" = '2' ]; then
		db_type=meta_db
		dbdir
		getdb
	elif [ "$num" = '3' ]; then
		db_type=yacd
		dbdir
		getdb
	elif [ "$num" = '4' ]; then
		db_type=meta_yacd
		dbdir
		getdb
	elif [ "$num" = '5' ]; then
		db_type=meta_xd
		dbdir
		getdb
	elif [ "$num" = '6' ]; then
		read -p "确认卸载本地面板？(1/0) > " res
		if [ "$res" = 1 ];then
			rm -rf /www/clash
			rm -rf $clashdir/ui
			rm -rf $bindir/ui
			echo -----------------------------------------------
			echo -e "\033[31m面板已经卸载！\033[0m"
			sleep 1
		fi
	else
		errornum
	fi
}

getcrt(){
	crtlink="${update_url}/bin/fix/ca-certificates.crt"
	echo -----------------------------------------------
	echo 正在连接服务器获取安装文件…………
	$clashdir/start.sh webget $TMPDIR/ca-certificates.crt $crtlink
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		error_down
	else
		echo -----------------------------------------------
		mkdir -p $openssldir
		mv -f $TMPDIR/ca-certificates.crt $crtdir
		$clashdir/start.sh webget $TMPDIR/ssl_test https://baidu.com echooff rediron skipceroff
		if [ "$?" = "1" ];then
			export CURL_CA_BUNDLE=$crtdir
			echo "export CURL_CA_BUNDLE=$crtdir" >> /etc/profile
		fi
		rm -rf $TMPDIR/ssl_test
		echo -e "\033[32m证书安装成功！\033[0m"
		sleep 1
	fi
}
setcrt(){
	openssldir=$(openssl version -a 2>&1 | grep OPENSSLDIR | awk -F "\"" '{print $2}')
	[ -z "$openssldir" ] && openssldir=/etc/ssl
	if [ -n "$openssldir" ];then
		crtdir="$openssldir/certs/ca-certificates.crt"
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
	saveserver(){
		#写入mark文件
		setconfig update_url \'$update_url\'
		setconfig release_url \'$release_url\'
		echo -----------------------------------------------
		echo -e "\033[32m源地址更新成功！\033[0m"
		release_new=""
	}
	echo -----------------------------------------------
	echo -e "\033[30;47m切换ShellClash版本及更新源地址\033[0m"
	echo -e "当前源地址：\033[4;32m$update_url\033[0m"
	echo -----------------------------------------------
	grep -aE '^1|^2' $clashdir/configs/servers.list | awk '{print " "NR" "$4" "$2}'
	echo -----------------------------------------------
	echo -e " a 自定义源地址(用于本地源或自建源)"
	echo -e " b \033[31m版本回退\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case $num in
	[0-99])
		release_type=$(grep -aE '^1|^2' $clashdir/configs/servers.list | sed -n ""$num"p" | awk '{print $4}')
		if [ "release_type" = "稳定版" ];then
			release_url=$(grep -aE '^1' $clashdir/configs/servers.list | sed -n ""$num"p" | awk '{print $3}')
		else
			update_url=$(grep -aE '^1|^2' $clashdir/configs/servers.list | sed -n ""$num"p" | awk '{print $3}')
			unset release_url
		fi
		saveserver
	;;
	a)
		echo -----------------------------------------------
		read -p "请输入个人源路径 > " update_url
		if [ -z "$update_url" ];then
			echo -----------------------------------------------
			echo -e "\033[31m取消输入，返回上级菜单\033[0m"
		else
			saveserver
			unset release_url
		fi
	;;
	b)
		echo -----------------------------------------------
		echo -e "\033[33m如无法连接，请务必先启用clash服务！！！\033[0m"
		$clashdir/start.sh webget $TMPDIR/clashrelease https://raw.githubusercontent.com/juewuy/ShellClash/master/bin/release_version echooff rediroff 2>$TMPDIR/clashrelease
		echo -e "\033[31m请选择想要回退至的release版本：\033[0m"
		cat $TMPDIR/clashrelease | awk '{print " "NR" "$1}'
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" -o "$num" = 0 ]; then
			setserver
		elif [ $num -le $(cat $TMPDIR/clashrelease 2>/dev/null | awk 'END{print NR}') ]; then
			release_version=$(cat $TMPDIR/clashrelease | awk '{print $1}' | sed -n "$num"p)
			update_url="https://raw.githubusercontent.com/juewuy/ShellClash/$release_version"
			saveserver
			unset release_url
		else
			echo -----------------------------------------------
			echo -e "\033[31m输入有误，请重新输入！\033[0m"
		fi
		rm -rf $TMPDIR/clashrelease
	;;
	*)
		errornum
	;;
	esac
}
#检查更新
checkupdate(){
if [ -z "$release_new" ];then
	if [ -n "$release_url" ];then
		[ -n "$(echo $release_url|grep 'jsdelivr')" ] && check_url=$release_url@master || check_url=$release_url/master
		$clashdir/start.sh webget $TMPDIR/clashversion $check_url/bin/release_version echoon rediroff 2>$TMPDIR/clashversion
		release_new=$(cat $TMPDIR/clashversion | head -1)
		[ -n "$(echo $release_url|grep 'jsdelivr')" ] && update_url=$release_url@$release_new || update_url=$release_url/$release_new
		setconfig update_url \'$update_url\'
		release_type=正式版
	else
		release_type=测试版
	fi	
	$clashdir/start.sh webget $TMPDIR/clashversion $update_url/bin/version echooff 
	[ "$?" = "0" ] && release_new=$(cat $TMPDIR/clashversion | grep -oE 'versionsh=.*' | awk -F'=' '{ print $2 }')
	if [ -n "$release_new" ];then
		source $TMPDIR/clashversion 2>/dev/null
	else
		echo -e "\033[31m检查更新失败！请切换其他安装源！\033[0m"
		echo -e "\033[36m如全部安装源都无法使用，请先运行clash服务后再使用更新功能！\033[0m"
		sleep 1
		setserver
	fi
	rm -rf $TMPDIR/clashversion
fi
}
update(){
	echo -----------------------------------------------
	echo -ne "\033[32m正在检查更新！\033[0m\r"
	checkupdate
	[ "$clashcore" = "clash" ] && clash_n=$clash_v || clash_n=$clashpre_v
	[ "$clashcore" = "clashpre" ] && clash_n=$clashpre_v
	[ "$clashcore" = "clash.net" ] && clash_n=$clashnet_v
	[ "$clashcore" = "clash.meta" ] && clash_n=$meta_v
	clash_v=$($bindir/clash -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
	[ -z "$clash_v" ] && clash_v=$clashv
	echo -e "\033[30;47m欢迎使用更新功能：\033[0m"
	echo -----------------------------------------------
	echo -e "当前目录(\033[32m$clashdir\033[0m)剩余空间：\033[36m$(dir_avail $clashdir -h)\033[0m" 
	[ "$(dir_avail $clashdir)" -le 5120 ] && {
		echo -e "\033[33m当前目录剩余空间较低，建议开启小闪存模式！\033[0m" 
		sleep 1
	}
	echo -----------------------------------------------
	echo -e " 1 更新\033[36m管理脚本  	\033[33m$versionsh_l\033[0m > \033[32m$versionsh$release_type\033[0m"
	echo -e " 2 切换\033[33mclash核心 	\033[33m$clash_v\033[0m > \033[32m$clash_n\033[0m"
	echo -e " 3 更新\033[32mGeoIP/CN-IP	\033[33m$Geo_v\033[0m > \033[32m$GeoIP_v\033[0m"
	echo -e " 4 安装本地\033[35mDashboard\033[0m面板"
	echo -e " 5 安装/更新本地\033[33m根证书文件\033[0m"
	echo -e " 6 查看\033[32mPAC\033[0m自动代理配置"
	echo -----------------------------------------------
	echo -e " 7 切换\033[36m安装源\033[0m及\033[36m安装版本\033[0m"
	echo -e " 8 \033[32m重新初始化运行环境\033[0m"
	echo -e " 9 \033[31m卸载\033[34mShellClash\033[0m"
	echo -----------------------------------------------
	echo -e "99 \033[36m鸣谢！\033[0m"
	echo -e " 0 返回上级菜单" 
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then	
		getsh	

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
		source $clashdir/init.sh
		update		
		
	elif [ "$num" = 9 ]; then
		$0 -u
		exit
		
	elif [ "$num" = 99 ]; then		
		echo -----------------------------------------------
		echo -e "感谢：\033[32mClash项目 \033[0m作者\033[36m Dreamacro\033[0m 项目地址：\033[32mhttps://github.com/Dreamacro/clash\033[0m"
		echo -e "感谢：\033[32mClash.meta项目 \033[0m作者\033[36m MetaCubeX\033[0m 项目地址：\033[32mhttps://github.com/MetaCubeX/Clash.Meta\033[0m"
		echo -e "感谢：\033[32mYACD面板项目 \033[0m作者\033[36m haishanh\033[0m 项目地址：\033[32mhttps://github.com/haishanh/yacd\033[0m"
		echo -e "感谢：\033[32mSubconverter \033[0m作者\033[36m tindy2013\033[0m 项目地址：\033[32mhttps://github.com/tindy2013/subconverter\033[0m"
		echo -e "感谢：\033[32m由alecthw提供的GeoIP数据库\033[0m 项目地址：\033[32mhttps://github.com/alecthw/mmdb_china_ip_list\033[0m"
		echo -e "感谢：\033[32m由Hackl0us提供的GeoIP精简数据库\033[0m 项目地址：\033[32mhttps://github.com/Hackl0us/GeoIP2-CN\033[0m"
		echo -e "感谢：\033[32m由17mon提供的CN-IP列表\033[0m 项目地址：\033[32mhttps://github.com/17mon/china_ip_list\033[0m"
		echo -e "感谢：\033[32m由ChanthMiao提供的CN-IPV6列表\033[0m 项目地址：\033[32mhttps://github.com/ChanthMiao/China-IPv6-List\033[0m"
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
		echo -e "\033[30;46m 欢迎使用ShellClash新手引导！ \033[0m"
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
			ckcmd nft && redir_mod="Nft基础"
			modprobe nft_tproxy &> /dev/null && redir_mod="Nft混合"
			setconfig redir_mod "$redir_mod"
			#自动识别IPV6
			[ -n "$(ip a 2>&1 | grep -w 'inet6' | grep -E 'global' | sed 's/.*inet6.//g' | sed 's/scope.*$//g')" ] && {
				setconfig ipv6_redir 已开启
				setconfig ipv6_support 已开启
				setconfig ipv6_dns 已开启
			}
			#设置开机启动
			[ -f /etc/rc.common ] && /etc/init.d/clash enable
			ckcmd systemctl && systemctl enable clash.service > /dev/null 2>&1
			rm -rf $clashdir/.dis_startup
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
			setconfig redir_mod "纯净模式"
			setconfig clashcore "clash"
			setconfig common_ports "未开启"
			echo -----------------------------------------------
			echo -e "\033[36m请选择设置本机代理的方式\033[0m"
			localproxy
		elif [ "$num" = 3 ];then
			mv -f $CFG_PATH.bak $CFG_PATH
			echo -e "\033[32m脚本设置已还原！\033[0m"
			echo -e "\033[33m请重新启动脚本！\033[0m"
			exit 0
		fi
	}
	forwhat
	#检测小内存模式
	dir_size=$(df $clashdir | awk '{print $4}' | sed 1d)
	if [ "$dir_size" -lt 10240 ];then
		echo -----------------------------------------------
		echo -e "\033[33m检测到你的安装目录空间不足10M，是否开启小闪存模式？\033[0m"
		echo -e "\033[0m开启后核心及数据库文件将被下载到内存中，这将占用一部分内存空间\033[0m"
		echo -e "\033[0m每次开机后首次运行clash时都会自动的重新下载相关文件\033[0m"
		echo -----------------------------------------------
		read -p "是否开启？(1/0) > " res
		[ "$res" = 1 ] && setconfig bindir "/tmp/clash_$USER"
	fi
	#下载本地面板
	# echo -----------------------------------------------
	# echo -e "\033[33m安装本地Dashboard面板，可以更快捷的管理clash内置规则！\033[0m"
	# echo -----------------------------------------------
	# read -p "需要安装本地Dashboard面板吗？(1/0) > " res
	# [ "$res" = 1 ] && checkupdate && setdb
	#检测及下载根证书
	if [ -d /etc/ssl/certs -a ! -f '/etc/ssl/certs/ca-certificates.crt' ];then
		echo -----------------------------------------------
		echo -e "\033[33m当前设备未找到根证书文件\033[0m"
		echo -----------------------------------------------
		read -p "是否下载并安装根证书？(1/0) > " res
		[ "$res" = 1 ] && checkupdate && getcrt
	fi
	#设置加密DNS
	$clashdir/start.sh webget $TMPDIR/ssl_test https://doh.pub echooff rediron
	if [ "$?" = "0" ];then
		dns_nameserver='https://223.5.5.5/dns-query, https://doh.pub/dns-query, tls://dns.rubyfish.cn:853'
		dns_fallback='https://1.0.0.1/dns-query, https://8.8.4.4/dns-query, https://doh.opendns.com/dns-query'
		setconfig dns_nameserver \'"$dns_nameserver"\'
		setconfig dns_fallback \'"$dns_fallback"\' 
	fi
	rm -rf $TMPDIR/ssl_test
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
			read -p "请先设置Socks服务密码(账号默认为clash) > " sec
			[ -z "$sec" ] && authentication=clash:$sec
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
	#小米设备软固化
	if [ "$systype" = "mi_snapshot" ];then
		echo -----------------------------------------------
		echo -e "\033[33m检测到为小米路由设备，启用软固化可防止路由升级后丢失SSH\033[0m"
		read -p "是否启用软固化功能？(1/0) > " res
		[ "$res" = 1 ] && autoSSH
	fi
	#提示导入订阅或者配置文件
	echo -----------------------------------------------
	echo -e "\033[32m是否导入配置文件？\033[0m(这是运行前的最后一步)"
	echo -e "\033[0m你必须拥有一份yaml格式的配置文件才能运行clash服务！\033[0m"
	echo -----------------------------------------------
	read -p "现在开始导入？(1/0) > " res
	[ "$res" = 1 ] && inuserguide=1 && clashlink && inuserguide=""
	#回到主界面
	echo -----------------------------------------------
	echo -e "\033[36m很好！现在只需要执行启动就可以愉快的使用了！\033[0m"
	echo -----------------------------------------------
	read -p "立即启动clash服务？(1/0) > " res 
	[ "$res" = 1 ] && clashstart && sleep 2
	clashsh
}
#测试菜单
testcommand(){
	echo -----------------------------------------------
	echo -e "\033[30;47m这里是测试命令菜单\033[0m"
	echo -e "\033[33m如遇问题尽量运行相应命令后截图提交issue或TG讨论组\033[0m"
	echo -----------------------------------------------
	echo " 1 查看Clash运行时的报错信息(会停止clash服务)"
	echo " 2 查看系统DNS端口(:53)占用 "
	echo " 3 测试ssl加密(aes-128-gcm)跑分"
	echo " 4 查看clash相关路由规则"
	echo " 5 查看config.yaml前40行"
	echo " 6 测试代理服务器连通性(google.tw)"
	echo -----------------------------------------------
	echo " 0 返回上级目录！"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
		clashsh
	elif [ "$num" = 0 ]; then
		clashsh
	elif [ "$num" = 1 ]; then
		$clashdir/start.sh stop
		echo -----------------------------------------------
		if $clashdir/clash -v &>/dev/null;then
			clash -s modify_yaml &>/dev/null
			$clashdir/clash -t -d $clashdir	-f $TMPDIR/config.yaml
			[ "$?" = 0 ] && testover=32m测试通过！|| testover=31m出现错误！请截图后到TG群询问！！！
			echo -e "\033[$testover\033[0m"
		else
			echo -e "\033[31m你没有安装clash内核或内核不完整，请先前往更新界面安装内核！\033[0m"
			update
			testcommand
		fi
		exit;
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

		if [ -n "$(echo $redir_mod | grep 'Nft')" -o "$local_type" = "nftables增强模式" ];then
			nft list table inet shellclash
		else
			echo -------------------Redir---------------------
			iptables -t nat -L PREROUTING --line-numbers
			iptables -t nat -L clash_dns --line-numbers
			iptables -t nat -L clash --line-numbers
			[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
				echo ----------------Tun/Tproxy-------------------
				iptables -t mangle -L PREROUTING --line-numbers
				iptables -t mangle -L clash --line-numbers
			}
			[ "$local_proxy" = "已开启" ] && [ "$local_type" = "iptables增强模式" ] && {
				echo ----------------OUTPUT-------------------
				iptables -t nat -L OUTPUT --line-numbers
				iptables -t nat -L clash_out --line-numbers
			}
			[ "$ipv6_redir" = "已开启" ] && {
				[ -n "$(lsmod | grep 'ip6table_nat')" ] && {
					echo -------------------Redir---------------------
					ip6tables -t nat -L PREROUTING --line-numbers
					ip6tables -t nat -L clashv6_dns --line-numbers
					ip6tables -t nat -L clashv6 --line-numbers
				}
				[ -n "$(echo $redir_mod | grep -E 'Tproxy模式|混合模式|Tun模式')" ] && {
					echo ----------------Tun/Tproxy-------------------
					ip6tables -t mangle -L PREROUTING --line-numbers
					ip6tables -t mangle -L clashv6 --line-numbers
				}
			}
		fi
		exit;
	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		sed -n '1,40p' $clashdir/config.yaml
		echo -----------------------------------------------
		exit;
	elif [ "$num" = 6 ]; then
		echo "注意：依赖curl(不支持wget)，且测试结果不保证一定准确！"
		delay=`curl -kx ${authentication}@127.0.0.1:$mix_port -o /dev/null -s -w '%{time_starttransfer}' 'https://google.tw' & { sleep 3 ; kill $! & }` > /dev/null 2>&1
		delay=`echo |awk "{print $delay*1000}"` > /dev/null 2>&1
		echo -----------------------------------------------
		if [ `echo ${#delay}` -gt 1 ];then
			echo -e "\033[32m连接成功！响应时间为："$delay" ms\033[0m"
		else
			echo -e "\033[31m连接超时！请重试或检查节点配置！\033[0m"
		fi
		clashsh

	else
		errornum
		clashsh
	fi
}