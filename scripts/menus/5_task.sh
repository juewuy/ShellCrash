#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_5_TASK_LOADED" ] && return
__IS_MODULE_5_TASK_LOADED=1

#通用工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/set_cron.sh
#任务工具
set_cron(){
	[ -z $week ] && week=*
	[ -z $hour ] && hour=*
	[ -z $min ] && min=0
	echo "-----------------------------------------------"
	echo -e "\033[33m$cron_time\033[0m执行任务:\033[36m$task_name\033[0m"
	read -p  "是否确认添加定时任务？(1/0) > " res
	if [ "$res" = '1' ]; then
		task_txt="$min $hour * * $week $CRASHDIR/task/task.sh $task_id $cron_time$task_name"
		cronset "$cron_time$task_name" "$task_txt"
		echo -e "任务【$cron_time$task_name】\033[32m已添加！\033[0m"
	fi
	unset week hour min
	sleep 1
}
set_service(){
	# 参数1代表要任务类型,参数2代表任务ID,参数3代表任务描述,参数4代表running任务cron时间
	task_file="$CRASHDIR"/task/$1
	[ -s $task_file ] && sed -i "/$3/d" $task_file
	 #运行时每分钟执行的任务特殊处理
	if [ "$1" = "running" ];then
		task_txt="$4 $CRASHDIR/task/task.sh $2 $3"
		echo "$task_txt" >> $task_file
		[ -n "$(pidof CrashCore)" ] && cronset "$3" "$task_txt"
	else
		echo "$CRASHDIR/task/task.sh $2 $3" >> $task_file
	fi
	echo -e "任务【$3】\033[32m添加成功！\033[0m"
	sleep 1
}
#任务界面
task_user_add(){ #自定义命令添加
	echo "-----------------------------------------------"
	echo -e "\033[33m命令可包含空格，请确保命令可执行！\033[0m"
	echo -e "\033[36m此处不要添加执行条件，请在添加完成后返回添加具体执行条件！\033[0m"
	echo -e "也可以手动编辑\033[32m${CRASHDIR}/task/task.user\033[0m添加"
	read -p "请输入命令语句 > " script
	if [ -n "$script" ];then
		task_command=$script
		echo -e "请检查输入：\033[32m$task_command\033[0m"
		#获取本任务ID
		task_max_id=$(awk -F '#' '{print $1}' "$CRASHDIR"/task/task.user 2>/dev/null | sort -n | tail -n 1)
		[ -z "$task_max_id" ] && task_max_id=200
		task_id=$((task_max_id + 1))
		read -p "请输入任务备注 > " txt
		[ -n "$txt" ] && task_name=$txt || task_name=自定义任务$task_id
		echo "$task_id#$task_command#$task_name" >> "$CRASHDIR"/task/task.user
		echo -e "\033[32m自定义任务已添加！\033[0m"
		sleep 1
	else
		echo -e "\033[31m输入错误，请重新输入！\033[0m"
		sleep 1
	fi
}
task_user_del(){ #自定义命令删除
	echo "-----------------------------------------------"
	echo -e "请输入对应ID移除对应自定义任务(不会影响内置任务)"
	echo -e "也可以手动编辑\033[32m${CRASHDIR}/task/task.user\033[0m"
	echo "-----------------------------------------------"
	cat "$CRASHDIR"/task/task.user 2>/dev/null | grep -Ev '^#' | awk -F '#' '{print $1" "$3}'
	echo "-----------------------------------------------"
	echo "0 返回上级菜单"
	echo "-----------------------------------------------"
	read -p "请输入对应数字 > " num
	if [ -n "$num" ];then
		sed -i "/^$num#/d" "$CRASHDIR"/task/task.user 2>/dev/null
		[ "$num" != 0 ] && task_user_del
	else
		echo -e "\033[31m输入错误，请重新输入！\033[0m"
		sleep 1
	fi
}
task_add(){ #任务添加
	echo "-----------------------------------------------"
	echo -e "\033[36m请选择需要添加的任务\033[0m"
	echo "-----------------------------------------------"
	#输出任务列表
	cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | grep -Ev '^(#|$)' | awk -F '#' '{print " "NR" "$3}'
	echo "-----------------------------------------------"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in
	0)
	;;
	[1-9]|[1-9][0-9])
		if [ "$num" -le "$(cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | wc -l)" ];then
			task_id=$(cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | grep -Ev '^(#|$)' | sed -n "$num p" | awk -F '#' '{print $1}')
			task_name=$(cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | grep -Ev '^(#|$)' | sed -n "$num p" | awk -F '#' '{print $3}')
			task_type
		else
			errornum
		fi
	;;
	*)
	errornum
	;;
	esac
}
task_del(){ #任务删除
	#删除定时任务
	croncmd -l > "$TMPDIR"/cron
	sed -i "/$1/d" "$TMPDIR"/cron && croncmd "$TMPDIR"/cron
	rm -f "$TMPDIR"/cron
	#删除条件任务
	sed -i "/$1/d" "$CRASHDIR"/task/cron 2>/dev/null
	sed -i "/$1/d" "$CRASHDIR"/task/bfstart 2>/dev/null
	sed -i "/$1/d" "$CRASHDIR"/task/afstart 2>/dev/null
	sed -i "/$1/d" "$CRASHDIR"/task/running 2>/dev/null
	sed -i "/$1/d" "$CRASHDIR"/task/affirewall 2>/dev/null
}
task_type(){ #任务条件选择菜单
	echo "-----------------------------------------------"
	echo  -e "请选择任务\033[36m【$task_name】\033[0m执行条件："
	echo "-----------------------------------------------"
	echo -e " 1 定时任务\033[32m每周执行\033[0m"
	echo -e " 2 定时任务\033[32m每日执行\033[0m"
	echo -e " 3 定时任务\033[32m每小时执行\033[0m"
	echo -e " 4 定时任务\033[32m每分钟执行\033[0m"
	echo "-----------------------------------------------"
	echo  -e "\033[31m注意：\033[0m逻辑水平不及格的请勿使用下方触发条件！"
	echo "-----------------------------------------------"
	echo -e " 5 服务\033[33m启动前执行\033[0m"
	echo -e " 6 服务\033[33m启动后执行\033[0m"
	echo -e " 7 服务\033[33m运行时每分钟执行\033[0m"
	echo -e " 8 防火墙服务\033[33m重启后执行\033[0m"
	echo "-----------------------------------------------"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	case "$num" in

	0)
		return 1
	;;
	1)
		echo "-----------------------------------------------"
		echo -e " 输入  1-7  对应\033[33m每周的指定某天\033[0m运行(7=周日)"
		echo -e " 输入 1,4,0 代表\033[36m每周一、周四、周日\033[0m运行"
		echo -e " 输入 1-5 代表\033[36m周一至周五\033[0m运行"
		read -p "在每周哪天执行？ > " week
		week=`echo ${week/7/0}` #把7换成0
		echo "-----------------------------------------------"
		read -p "想在该日的具体哪个小时执行？（0-23） > " hour
		cron_time="在每周$week的$hour点整"
		cron_time=`echo ${cron_time/周0/周日}` #把0换成日
		[ -n "$week" ] && [ -n "$hour" ] && set_cron
	;;
	2)
		echo "-----------------------------------------------"
		echo -e " 输入 1,7,15 代表\033[36m每到1,7,15点\033[0m运行"
		echo -e " 输入 6-18 代表\033[36m早6点至晚18点间每小时\033[0m运行"
		read -p "想在每日的具体哪个小时执行？（0-23） > " hour
		echo "-----------------------------------------------"
		read -p "想在具体哪分钟执行？（0-59的整数） > " min
		cron_time="在每日的$hour点$min分"
		[ -n "$min" ] && [ -n "$hour" ] && set_cron
	;;
	3)
		echo "-----------------------------------------------"
		read -p "想每隔多少小时执行一次？（1-23的整数） > " num
		hour="*/$num"
		cron_time="每隔$num小时"
		[ -n "$hour" ] && set_cron
	;;
	4)
		echo "-----------------------------------------------"
		read -p "想每隔多少分钟执行一次？（1-59的整数） > " num
		min="*/$num"
		cron_time="每隔$num分钟"
		[ -n "$min" ] && set_cron
	;;
	5)
		set_service bfstart "$task_id" "服务启动前$task_name"
	;;
	6)
		set_service afstart "$task_id" "服务启动后$task_name"
	;;
	7)
		echo "-----------------------------------------------"
		echo -e " 输入10即每隔10分钟运行一次，1440即每隔24小时运行一次"
		echo -e " 大于60分钟的数值将按小时取整,且按当前时区记时"
		read -p "想每隔多少分钟执行一次？（1-1440的整数） > " num
		if [ "$num" -lt 60 ];then
			min="$num"
			cron_time="*/$min * * * *"
			time_des="$min分钟"
		else
			hour="$((num / 60))"
			cron_time="0 */$hour * * *"
			time_des="$hour小时"
		fi
		[ -n "$cron_time" ] && set_service running "$task_id" "运行时每$time_des$task_name" "$cron_time"
	;;
	8)
		echo -e "该功能会将相关启动代码注入到/etc/init.d/firewall中"
		read -p "是否继续？(1/0) > " res
		[ "$res" = 1 ] && set_service affirewall "$task_id" "防火墙重启后$task_name"
	;;
	*)
		errornum
		return 1
	;;
	esac
}
task_manager(){ #任务管理列表
	echo "-----------------------------------------------"
	#抽取并生成临时列表
	croncmd -l > "$TMPDIR"/task_cronlist
	cat "$TMPDIR"/task_cronlist "$CRASHDIR"/task/running 2>/dev/null | sort -u | grep -oE "task/task.sh .*" | awk -F ' ' '{print $2" "$3}' > "$TMPDIR"/task_list
	cat "$CRASHDIR"/task/bfstart "$CRASHDIR"/task/afstart "$CRASHDIR"/task/affirewall 2>/dev/null | awk -F ' ' '{print $2" "$3}' >> "$TMPDIR"/task_list
	cat "$TMPDIR"/task_cronlist 2>/dev/null | sort -u | grep -oE " #.*" | grep -v "守护" | awk -F '#' '{print "0 旧版任务-"$2}' >> "$TMPDIR"/task_list
	sed -i '/^ *$/d' "$TMPDIR"/task_list
	rm -rf "$TMPDIR"/task_cronlist
	#判断为空则返回
	if [ ! -s "$TMPDIR"/task_list ];then
		echo -e "\033[31m当前没有可供管理的任务！\033[36m"
		sleep 1
	else
		echo -e "\033[33m已添加的任务:\033[0m"
		echo "-----------------------------------------------"
		cat "$TMPDIR"/task_list | awk '{print " " NR " " $2}'
		echo "-----------------------------------------------"
		echo -e " a 清空旧版任务"
		echo -e " d 清空任务列表"
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		case "$num" in
		0)
		;;
		a)
			task_del "#"
			echo -e "\033[31m旧版任务已清空！\033[36m"
			sleep 1
		;;
		d)
			task_del "task.sh"
			echo -e "\033[31m全部任务已清空！\033[36m"
			sleep 1
		;;
		[1-9]|[1-9][0-9])

			task_txt=$(sed -n "$num p" "$TMPDIR"/task_list)
			task_id=$(echo $task_txt | awk '{print $1}')
			if [ "$task_id" = 0 ];then
				read -p "旧版任务不支持管理，是否移除?(1/0) > " res
				[ "$res" = 1 ] && {
					cronname=$(echo $task_txt | awk -F '-' '{print $2}')
					croncmd -l > $TMPDIR/conf && sed -i "/$cronname/d" $TMPDIR/conf && croncmd $TMPDIR/conf
					sed -i "/$cronname/d" $clashdir/tools/cron 2>/dev/null
					rm -f $TMPDIR/conf
				}
			else
				task_des=$(echo $task_txt | awk '{print $2}')
				task_name=$(cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | grep "$task_id" | awk -F '#' '{print $3}')
				echo "-----------------------------------------------"
				echo -e "当前任务为：\033[36m $task_des\033[0m"
				echo -e " 1 \033[33m修改\033[0m当前任务"
				echo -e " 2 \033[31m删除\033[0m当前任务"
				echo -e " 3 \033[32m立即执行\033[0m一次"
				echo -e " 4 查看\033[33m执行记录\033[0m"
				echo "-----------------------------------------------"
				echo -e " 0 返回上级菜单"
				read -p "请选择需要执行的操作 > " num
				case "$num" in
				0)
				;;
				1)
					task_type && task_del $task_des
				;;
				2)
					task_del $task_des
				;;
				3)
					task_command=$(cat "$CRASHDIR"/task/task.list "$CRASHDIR"/task/task.user 2>/dev/null | grep "$task_id" | awk -F '#' '{print $2}')
					eval $task_command && task_res='执行成功！' || task_res='执行失败！'
					echo -e "\033[33m任务【$task_des】$task_res\033[0m"
					sleep 1
				;;
				4)
					echo "-----------------------------------------------"
					if [ -n "$(cat "$TMPDIR"/ShellCrash.log | grep "$task_name")" ];then
						cat "$TMPDIR"/ShellCrash.log | grep "$task_name"
					else
						echo -e "\033[31m未找到相关执行记录！\033[0m"
					fi
					sleep 1
				;;
				*)
					errornum
				;;
				esac
			fi
			task_manager
		;;
		*)
			errornum
		;;
		esac
	fi
}
task_recom(){ #任务推荐
	echo "-----------------------------------------------"
	echo -e "\033[32m启用推荐的自动任务配置？这包括：\033[0m"
	echo "-----------------------------------------------"
	echo -e "每隔10分钟自动保存面板配置"
	echo -e "服务启动后自动同步ntp时间"
	echo -e "在每日的3点0分重启服务"
	echo "-----------------------------------------------"
	read -p "是否启用？(1/0) > " res
	[ "$res" = 1 ] && {
		set_service running "106" "运行时每10分钟自动保存面板配置" "*/10 * * * *"
		set_service afstart "107" "服务启动后自动同步ntp时间"
		cronset "在每日的3点0分重启服务" "0 3 * * * ${CRASHDIR}/task/task.sh 103 在每日的3点0分重启服务" && \
		echo -e "任务【在每日的3点0分重启服务】\033[32m添加成功！\033[0m"
	}
}

# 任务菜单
task_menu() {
    while true; do
        #检测并创建自定义任务文件
        [ -f "$CRASHDIR"/task/task.user ] || echo '#任务ID(必须>200并顺序排列)#任务命令#任务说明(#号隔开，任务命令和说明中都不允许包含#号)' >"$CRASHDIR"/task/task.user
        echo "-----------------------------------------------"
        echo -e "\033[30;47m欢迎使用自动任务功能：\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 添加\033[32m自动任务\033[0m"
        echo -e " 2 管理\033[33m任务列表\033[0m"
        echo -e " 3 查看\033[36m任务日志\033[0m"
        echo -e " 4 配置\033[36m日志推送\033[0m"
        echo -e " 5 添加\033[33m自定义任务\033[0m"
        echo -e " 6 删除\033[33m自定义任务\033[0m"
        echo -e " 7 使用\033[32m推荐设置\033[0m"
        echo "-----------------------------------------------"
        echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            task_add
            ;;
        2)
            task_manager
            rm -rf "$TMPDIR"/task_list
            ;;
        3)
            if [ -n "$(cat "$TMPDIR"/ShellCrash.log | grep '任务【')" ]; then
                echo "-----------------------------------------------"
                cat "$TMPDIR"/ShellCrash.log | grep '任务【'
            else
                echo -e "\033[31m未找到任务相关执行日志！\033[0m"
            fi
            sleep 1
            ;;
        4)
            echo "-----------------------------------------------"
            echo -e "\033[36m请在日志工具中配置相关推送通道及推送开关\033[0m"
            . "$CRASHDIR"/menus/8_tools.sh && log_pusher
            ;;
        5)
            task_user_add
            ;;
        6)
            task_user_del
            ;;
        7)
            task_recom
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}
