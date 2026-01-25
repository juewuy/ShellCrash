#!/bin/sh
# Copyright (C) Juewuy

#加载全局变量
[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
. "$CRASHDIR"/libs/get_config.sh
#加载工具
. "$CRASHDIR"/libs/check_cmd.sh
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/web_get_bin.sh
. "$CRASHDIR"/libs/logger.sh

task_logger(){
	[ "$task_push" = 1 ] && push= || push=off
	[ -n "$2" -a "$2" != 0 ] && echo -e "\033[$2m$1\033[0m"
	[ "$3" = 'off' ] && push=off
	echo "$1" |grep -qE '(每隔|时每)([1-9]|[1-9][0-9])分钟' || logger "$1" 0 "$push"
}

#任务命令
check_update(){ #检查更新工具
	get_bin "$TMPDIR"/crashversion "$1" echooff
	[ "$?" = "0" ] && . "$TMPDIR"/crashversion 2>/dev/null
	rm -rf "$TMPDIR"/crashversion
}
update_core(){ #自动更新内核
	#检查版本
	check_update bin/version
	crash_v_new=$(eval echo \$${crashcore}_v)
	if [ -z "$crash_v_new" -o "$crash_v_new" = "$core_v" ];then
		task_logger "任务【自动更新内核】中止-未检测到版本更新"
		return 0
	else
		. "$CRASHDIR"/libs/core_webget.sh && core_webget #调用下载工具
		case "$?" in
		0)
			task_logger "任务【自动更新内核】下载完成，正在重启服务！"
			"$CRASHDIR"/start.sh start
			return 0
		;;
		1)
			task_logger "任务【自动更新内核】出错-下载失败！"
			return 1
		;;
		*)
			task_logger "任务【自动更新内核】出错-内核校验失败！"
			"$CRASHDIR"/start.sh start
			return 1
		;;
		esac
	fi
}
update_scripts(){ #自动更新脚本
	#检查版本
	check_update version
	if [ -z "$versionsh" -o "$versionsh" = "versionsh_l" ];then
		task_logger "任务【自动更新脚本】中止-未检测到版本更新"
		return 0
	else
		get_bin "$TMPDIR"/clashfm.tar.gz "bin/update.tar.gz"
		if [ "$?" != "0" ];then
			rm -rf "$TMPDIR"/clashfm.tar.gz
			task_logger "任务【自动更新内核】出错-下载失败！"
			return 1
		else
			#停止服务
			"$CRASHDIR"/start.sh stop
			#解压
			tar -zxf "$TMPDIR"/clashfm.tar.gz ${tar_para} -C "$CRASHDIR"/
			if [ $? -ne 0 ];then
				rm -rf "$TMPDIR"/clashfm.tar.gz
				task_logger "任务【自动更新内核】出错-解压失败！"
				"$CRASHDIR"/start.sh start
				return 1
			else
				. "$CRASHDIR"/init.sh >/dev/null
				"$CRASHDIR"/start.sh start
				return 0
			fi
		fi
	fi
}
update_mmdb(){ #自动更新数据库
	getgeo(){
		#检查版本
		check_update bin/version
		geo_v="$(echo $2 | awk -F "." '{print $1}')_v" #获取版本号类型比如Country_v
		geo_v_new=$GeoIP_v
		geo_v_now=$(eval echo \$$geo_v)
		if [ -z "$geo_v_new" -o "$geo_v_new" = "$geo_v_now" ];then
			task_logger "任务【自动更新数据库文件】跳过-未检测到$2版本更新"
		else
			#更新文件
			get_bin "$TMPDIR"/$1 "bin/geodata/$2"
			if [ "$?" != "0" ];then
				task_logger "任务【自动更新数据库文件】更新【$2】下载失败！"
				rm -rf "$TMPDIR"/$1
			else
				mv -f "$TMPDIR"/$1 "$BINDIR"/$1
				setconfig $geo_v $GeoIP_v
				task_logger "任务【自动更新数据库文件】更新【$2】成功！"
			fi
		fi
	}
	[ -n "${cn_mini_v}" -a -s "$CRASHDIR"/Country.mmdb ] && getgeo Country.mmdb cn_mini.mmdb
	[ -n "${china_ip_list_v}" -a -s "$CRASHDIR"/cn_ip.txt ] && getgeo cn_ip.txt china_ip_list.txt
	[ -n "${china_ipv6_list_v}" -a -s "$CRASHDIR"/cn_ipv6.txt ] && getgeo cn_ipv6.txt china_ipv6_list.txt
	[ -n "${geosite_v}" -a -s "$CRASHDIR"/GeoSite.dat ] && getgeo GeoSite.dat geosite.dat
	[ -n "${geoip_cn_v}" -a -s "$CRASHDIR"/geoip.db ] && getgeo geoip.db geoip_cn.db
	[ -n "${geosite_cn_v}" -a -s "$CRASHDIR"/geosite.db ] && getgeo geosite.db geosite_cn.db
	return 0
}
reset_firewall(){ #重设透明路由防火墙
	"$CRASHDIR"/start.sh stop_firewall
	"$CRASHDIR"/start.sh afstart
}
ntp(){
	[ "$crashcore" != singbox ] && ckcmd ntpd && ntpd -n -q -p 203.107.6.88 >/dev/null 2>&1 || exit 0
}
web_save_auto(){
	. "$CRASHDIR"/libs/web_save.sh && web_save
}
update_config() { #更新订阅并重启
    . "$CRASHDIR"/starts/core_config.sh && get_core_config && "$CRASHDIR"/start.sh start
}
hotupdate() { #热更新订阅
    . "$CRASHDIR"/starts/core_config.sh && get_core_config &&
    . "$CRASHDIR"/starts/check_core.sh && check_core &&
    . "$CRASHDIR"/starts/"$target"_modify.sh && modify_"$format" && rm -rf "$TMPDIR"/CrashCore &&
    . "$CRASHDIR"/libs/web_restore.sh && put_save "http://127.0.0.1:$db_port/configs" "{\"path\":\"$CRASHDIR/config.$format\"}"
    exit $?
}

case "$1" in
	[1-9][0-9][0-9])
		task_command=$(cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | grep "$1" | awk -F '#' '{print $2}')
		task_name=$(cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | grep "$1" | awk -F '#' '{print $3}')
		#task_logger "任务$task_name 开始执行"
		eval $task_command && task_res=成功 || task_res=失败
		task_logger "任务【$2】执行$task_res"
	;;
	*)
		"$1"
	;;
esac
