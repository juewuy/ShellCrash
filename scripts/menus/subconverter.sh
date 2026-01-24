#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_SUBCONVERTER" ] && return
__IS_MODULE_SUBCONVERTER=1

[ -z "$rule_link" ] && rule_link=1
[ -z "$server_link" ] && server_link=1

#Subconverter在线订阅转换
subconverter() { 
	while true; do
		separator_line "-"
		content_line "1) \033[36m开始生成配置文件\033[0m"
		content_line "2) 设置\033[31m排除节点正则\033[0m \033[47;30m$exclude\033[0m"
		content_line "3) 设置\033[32m包含节点正则\033[0m \033[47;30m$include\033[0m"
		content_line "4) 选择\033[33m在线规则模版\033[0m"
		content_line "5) 选择\033[0mSubconverter服务器\033[0m"
		content_line "6) 自定义浏览器UA  \033[32m$user_agent\033[0m"
		common_back
		read -r -p "请输入对应数字 > " num
		case "$num" in
			"" | 0)
			break
			;;
		1)
			providers_link=$(grep -v '^#' "$CRASHDIR"/configs/providers.cfg 2>/dev/null |awk '{print $2}' |paste -sd '|')
			uri_link=$(grep -v '^#' "$CRASHDIR"/configs/providers_uri.cfg 2>/dev/null |awk -F '#' '{print $1}' |paste -sd '|')
			Url=$(echo "$providers_link|$uri_link" |sed 's/^|// ; s/|$//')
			setconfig Url "'$Url'"
			setconfig Https
			# 获取在线文件
			jump_core_config
            ;;
        2)
			gen_link_flt
			;;
        3)
			gen_link_ele
			;;
        4)
			gen_link_config
			;;
        5)
			gen_link_server
			;;	
        6)
			set_sub_ua
			;;	
		*)
			errornum
			break
		;;			
		esac
	done
}

gen_link_flt() { # 排除节点正则
	[ -z "$exclude" ] && exclude="未设置"
	separator_line "-"
	content_line "\033[33m当前过滤关键字：\033[47;30m$exclude\033[0m"
	separator_line "-"
	content_line "\033[33m匹配关键字的节点会在导入时被【屏蔽】！！！\033[0m"
	content_line "多个关键字可以用\033[30;47m | \033[0m号分隔"
	content_line "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	separator_line "-"
	content_line " 000   \033[31m删除\033[0m关键字"
	content_line " 回车  取消输入并返回上级菜单"
	separator_line "-"
	read -r -p "请输入关键字 > " exclude
	if [ "$exclude" = '000' ]; then
		separator_line "-"
		exclude=''
		content_line "\033[31m 已删除节点过滤关键字！！！\033[0m"
	fi
	setconfig exclude "'$exclude'"
}

gen_link_ele() { # 包含节点正则
	[ -z "$include" ] && include="未设置"
	separator_line "-"
	content_line "\033[33m当前筛选关键字：\033[47;30m$include\033[0m"
	separator_line "-"
	content_line "\033[33m仅有匹配关键字的节点才会被【导入】！！！\033[0m"
	content_line "多个关键字可以用\033[30;47m | \033[0m号分隔"
	content_line "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	separator_line "-"
	content_line " 000   \033[31m删除\033[0m关键字"
	content_line " 回车  取消输入并返回上级菜单"
	separator_line "-"
	read -r -p "请输入关键字 > " include
	if [ "$include" = '000' ]; then
		separator_line "-"
		include=''
		content_line "\033[31m 已删除节点匹配关键字！！！\033[0m"
	fi
	setconfig include "'$include'"
}

gen_link_config() { #选择在线规则模版
	separator_line "-"
	echo 当前使用规则为：$(grep -aE '^5' "$CRASHDIR"/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $2}')
	grep -aE '^5' "$CRASHDIR"/configs/servers.list | awk '{print " "NR"	"$2$4}'
	separator_line "-"
	echo 0 返回上级菜单
	read -r -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^5' "$CRASHDIR"/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入配置
		rule_link=$num
		setconfig rule_link $rule_link
		separator_line "-"
		content_line "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}

gen_link_server() { #选择Subconverter服务器
	separator_line "-"
	content_line "\033[36m以下为互联网采集的第三方服务器，具体安全性请自行斟酌！\033[0m"
	content_line "\033[32m感谢以下作者的无私奉献！！！\033[0m"
	echo 当前使用后端为：$(grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
	grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | awk '{print " "NR"	"$3"	"$2}'
	common_back
	read -r -p "请输入对应数字 > " num
	totalnum=$(grep -acE '^3|^4' "$CRASHDIR"/configs/servers.list )
	if [ -z "$num" ] || [ "$num" -gt "$totalnum" ];then
		errornum
	elif [ "$num" = 0 ];then
		echo
	elif [ "$num" -le "$totalnum" ];then
		#将对应标记值写入配置
		server_link=$num
		setconfig server_link $server_link
		separator_line "-"
		content_line "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}

set_sub_ua() {
	separator_line "-"
	content_line "\033[36m无法正确获取配置文件时可尝试使用\033[0m"
	content_line " 1 使用自动UA(默认)"
	content_line " 2 不使用UA"
	content_line " 3 使用自定义UA：\033[32m$user_agent\033[0m"
	separator_line "-"
	read -r -p "请输入对应数字 > " num
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
		read -r -p "请输入自定义UA(不要包含空格和特殊符号！) > " text
		[ -n "$text" ] && user_agent="$text"
		;;
	*)
		errornum
		;;
	esac
	[ "$num" -le 3 ] && setconfig user_agent "$user_agent"
}
