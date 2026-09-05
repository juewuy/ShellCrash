#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_5_TASK_LOADED" ] && return
__IS_MODULE_5_TASK_LOADED=1

# 通用工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/set_cron.sh
[ -z "$TASKCFGDIR" ] && TASKCFGDIR="$CRASHDIR"/configs/task

load_lang 5_task

# 任务工具
set_cron() {
    [ -z "$week" ] && week=*
    [ -z "$hour" ] && hour=*
    [ -z "$min" ] && min=0
    comp_box "\033[33m$cron_time\033[0m$TASK5_RUN_TASK\033[36m$task_name\033[0m" \
        "" \
        "$TASK5_CONFIRM_ADD_CRON"
    btm_box "1) $TASK5_YES" \
        "0) $TASK5_NO"
    read -r -p "$COMMON_INPUT> " res
    if [ "$res" = '1' ]; then
        task_txt="$min $hour * * $week $CRASHDIR/task/task.sh $task_id \"$cron_time$task_name\""
        cronset "$cron_time$task_name" "$task_txt"
        msg_alert -t 0 "$TASK5_TASK_PREFIX$cron_time$task_name$TASK5_TASK_ADDED"
    fi
    unset week hour min
    sleep 1
}

set_service() {
    # 参数1代表要任务类型,参数2代表任务ID,参数3代表任务描述,参数4代表running任务cron时间
    mkdir -p "$TASKCFGDIR"
    task_file="$TASKCFGDIR"/$1
    [ -s "$task_file" ] && sed -i "/$3/d" "$task_file"
    # 运行时每分钟执行的任务特殊处理
    if [ "$1" = "running" ]; then
        task_txt="$4 $CRASHDIR/task/task.sh $2 \"$3\""
        echo "$task_txt" >>"$task_file"
        [ -n "$(pidof CrashCore)" ] && cronset "$3" "$task_txt"
    else
        echo "$CRASHDIR/task/task.sh $2 \"$3\"" >>"$task_file"
    fi
    content_line "【$3】\033[32m$COMMON_SUCCESS\033[0m"
    sleep 1
}

# 任务界面
#
# 自定义命令添加
task_user_add() {
    while true; do
        comp_box "\033[33m$TASK5_USER_ADD_HINT1\033[0m" \
            "\033[36m$TASK5_USER_ADD_HINT2\033[0m" \
            "$TASK5_USER_ADD_HINT3\033[32m${TASKCFGDIR}/task.user\033[0m$TASK5_USER_ADD_HINT4"
        btm_box "\033[36m$TASK5_INPUT_CMD\033[0m" \
            "$TASK5_OR_BACK"
        read -r -p "$TASK5_INPUT> " script
        if [ "$script" = 0 ]; then
            break
        elif [ -n "$script" ]; then
            task_command=$script
            comp_box "$TASK5_CHECK_INPUT\033[32m$task_command\033[0m"
            # 获取本任务ID
            task_max_id=$(awk -F '#' '{print $1}' "$TASKCFGDIR"/task.user 2>/dev/null | sort -n | tail -n 1)
            [ -z "$task_max_id" ] && task_max_id=200
            task_id=$((task_max_id + 1))
            read -r -p "$TASK5_INPUT_REMARK> " txt
            [ -n "$txt" ] && task_name=$txt || task_name="$TASK5_CUSTOM_TASK$task_id"
            echo "$task_id#$task_command#$task_name" >>"$TASKCFGDIR"/task.user
            msg_alert "\033[32m$TASK5_CUSTOM_ADDED\033[0m"
            break
        else
            msg_alert "\033[31m$TASK5_INPUT_ERROR\033[0m"
        fi
    done
}

# 自定义命令删除
task_user_del() {
    while true; do
        if grep -Evq '^#' "$TASKCFGDIR/task.user" 2>/dev/null; then
            comp_box "$TASK5_USER_DEL_HINT1" \
                "$TASK5_USER_DEL_HINT2\033[32m${TASKCFGDIR}/task.user\033[0m"
            grep -Ev '^#' "$TASKCFGDIR/task.user" 2>/dev/null |
                awk -F '#' '{print $1") "$3}' |
                while IFS= read -r line; do
                    content_line "$line"
                done
            btm_box "" \
                "0) $COMMON_BACK"
            read -r -p "$COMMON_INPUT> " num
            if [ "$num" = 0 ]; then
                break
            elif [ -n "$num" ]; then
                sed -i "/^$num#/d" "$TASKCFGDIR"/task.user 2>/dev/null
                common_success
            else
                msg_alert "\033[31m$TASK5_INPUT_ERROR\033[0m"
            fi
        else
            msg_alert "\033[33m$TASK5_NO_CUSTOM_TASK\033[0m"
            break
        fi
    done
}

# 任务添加
task_add() {
    while true; do
        comp_box "\033[36m$TASK5_SELECT_ADD\033[0m"
        # 输出任务列表
        list=$(cat "$CRASHDIR"/task/task_${i18n}.list "$TASKCFGDIR"/task.user 2>/dev/null | grep -Ev '^(#|$)' | awk -F '#' '{print $3}')
        list_box "$list"
        btm_box "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
        case "$num" in
        0)
            break
            ;;
        [1-9] | [1-9][0-9])
            if [ "$num" -le "$(echo "$list" | wc -l)" ]; then
                task_id=$(cat "$CRASHDIR"/task/task_${i18n}.list "$TASKCFGDIR"/task.user 2>/dev/null | grep -Ev '^(#|$)' | sed -n "$num p" | awk -F '#' '{print $1}')
                task_name=$(cat "$CRASHDIR"/task/task_${i18n}.list "$TASKCFGDIR"/task.user 2>/dev/null | grep -Ev '^(#|$)' | sed -n "$num p" | awk -F '#' '{print $3}')
                task_type
                break
            else
                errornum
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 任务删除
task_del() {
    # 删除定时任务
    cronset "$1"
    # 删除条件任务
    [ -f "$TASKCFGDIR"/cron ] && sed -i "/$1/d" "$TASKCFGDIR"/cron 2>/dev/null
    [ -f "$TASKCFGDIR"/bfstart ] && sed -i "/$1/d" "$TASKCFGDIR"/bfstart 2>/dev/null
    [ -f "$TASKCFGDIR"/afstart ] && sed -i "/$1/d" "$TASKCFGDIR"/afstart 2>/dev/null
    [ -f "$TASKCFGDIR"/running ] && sed -i "/$1/d" "$TASKCFGDIR"/running 2>/dev/null
    [ -f "$TASKCFGDIR"/affirewall ] && sed -i "/$1/d" "$TASKCFGDIR"/affirewall 2>/dev/null
    return 0
}

# 任务条件选择菜单
task_type() {
    comp_box "$TASK5_SELECT_COND\033[36m【$task_name】\033[0m$TASK5_SELECT_COND2"
    btm_box "1) $TASK5_COND_1" \
        "2) $TASK5_COND_2" \
        "3) $TASK5_COND_3" \
        "4) $TASK5_COND_4" \
        "$TASK5_WARN_LINE1" \
        "$TASK5_WARN_LINE2" \
        "$TASK5_WARN_LINE3" \
        "5) $TASK5_COND_5" \
        "6) $TASK5_COND_6" \
        "7) $TASK5_COND_7" \
        "8) $TASK5_COND_8" \
        "" \
        "0) $COMMON_BACK"
    read -r -p "$COMMON_INPUT> " num
    case "$num" in
    0)
        return 1
        ;;
    1)

        comp_box "$TASK5_WEEK_HINT1" \
            "$TASK5_WEEK_HINT2" \
            "$TASK5_WEEK_HINT3"
        read -r -p "$TASK5_WEEK_INPUT> " week
        # week=`echo ${week/7/0}` # 把7换成0
        read -r -p "$TASK5_HOUR_INPUT1> " hour
        cron_time="$TASK5_CRON_WEEK$week$TASK5_CRON_WEEK2$hour$TASK5_OCLOCK"
        # cron_time=`echo ${cron_time/周0/周日}` # 把0换成日
        [ -n "$week" ] && [ -n "$hour" ] && set_cron
        ;;
    2)
        comp_box "$TASK5_DAY_HINT1" \
            "$TASK5_DAY_HINT2"
        read -r -p "$TASK5_HOUR_INPUT2> " hour
        read -r -p "$TASK5_MIN_INPUT> " min
        cron_time="$TASK5_CRON_DAY$hour$TASK5_POINT$min$TASK5_MINUTE"
        [ -n "$min" ] && [ -n "$hour" ] && set_cron
        ;;
    3)
        line_break
        read -r -p "$TASK5_EVERY_HOUR_INPUT> " num
        hour="*/$num"
        cron_time="$TASK5_EVERY$num$TASK5_HOUR"
        [ -n "$hour" ] && set_cron
        ;;
    4)
        line_break
        read -r -p "$TASK5_EVERY_MIN_INPUT> " num
        min="*/$num"
        cron_time="$TASK5_EVERY$num$TASK5_MIN"
        [ -n "$min" ] && set_cron
        ;;
    5)
        set_service bfstart "$task_id" "$TASK5_BFSTART$task_name"
        ;;
    6)
        set_service afstart "$task_id" "$TASK5_AFSTART$task_name"
        ;;
    7)
        comp_box "$TASK5_RUNNING_HINT1" \
            "$TASK5_RUNNING_HINT2"
        read -r -p "$TASK5_RUNNING_INPUT> " num
        if [ "$num" -lt 60 ]; then
            min="$num"
            cron_time="*/$min * * * *"
            time_des="$min$TASK5_MIN"
        else
            hour="$((num / 60))"
            cron_time="0 */$hour * * *"
            time_des="$hour$TASK5_HOUR"
        fi
        [ -n "$cron_time" ] && set_service running "$task_id" "$TASK5_RUNNING_PREFIX$time_des$task_name" "$cron_time"
        ;;
    8)
        comp_box "$TASK5_AFFW_HINT"
        "$TASK5_CONFIRM_CONTINUE"
        btm_box "1) $TASK5_YES" \
            "0) $TASK5_NO"
        read -r -p "$COMMON_INPUT> " res
        [ "$res" = 1 ] && set_service affirewall "$task_id" "$TASK5_AFFW_PREFIX$task_name"
        ;;
    *)
        errornum
        ;;
    esac
}

# 任务管理列表
task_manager() {
    while true; do
        # 抽取并生成临时列表
        cronload >"$TMPDIR"/task_cronlist
        cat "$TMPDIR"/task_cronlist "$TASKCFGDIR"/running 2>/dev/null | sort -u | grep -oE "task/task.sh .*" | cut -d ' ' -f 2- >"$TMPDIR"/task_list
        cat "$TASKCFGDIR"/bfstart "$TASKCFGDIR"/afstart "$TASKCFGDIR"/affirewall 2>/dev/null | cut -d ' ' -f 2- >>"$TMPDIR"/task_list
        cat "$TMPDIR"/task_cronlist 2>/dev/null | sort -u | grep -oE " #.*" | grep -v "$TASK5_GUARD_WORD" | awk -F '#' '{print "0 '$TASK5_OLD_PREFIX'"$2}' >>"$TMPDIR"/task_list
        sed -i '/^ *$/d' "$TMPDIR"/task_list
        rm -rf "$TMPDIR"/task_cronlist
        # 判断为空则返回
        if [ ! -s "$TMPDIR"/task_list ]; then
            msg_alert "\033[31m$TASK5_NONE_TO_MANAGE\033[36m"
            break
        else
            comp_box "\033[33m$TASK5_ADDED_TASKS\033[0m"
            list_box "$(cat "$TMPDIR"/task_list)"
            separator_line "-"
            btm_box "a) $TASK5_CLEAR_OLD" \
                "d) $TASK5_CLEAR_ALL" \
                "" \
                "0) $COMMON_BACK"
            read -r -p "$COMMON_INPUT> " num
            case "$num" in
            "" | 0)
                break
                ;;
            a)
                task_del "#"
                msg_alert "\033[31m$TASK5_OLD_CLEARED\033[36m"
                ;;
            d)
                task_del "task.sh"
                msg_alert "\033[31m$TASK5_ALL_CLEARED\033[36m"
                ;;
            [1-9] | [1-9][0-9])
                task_txt=$(sed -n "$num p" "$TMPDIR"/task_list)
                task_id=$(echo "$task_txt" | awk '{print $1}')

                if [ "$task_id" = 0 ]; then
                    comp_box "$TASK5_OLD_NOT_SUPPORT"
                    btm_box "1) $TASK5_YES" \
                        "0) $TASK5_NO_BACK"
                    read -r -p "$COMMON_INPUT> " res
                    if [ "$res" = 1 ]; then
                        cronname=$(echo "$task_txt" | awk -F '-' '{print $2}')
                        cronset "$cronname"
                        sed -i "/$cronname/d" "$TASKCFGDIR"/cron 2>/dev/null

                        break
                    fi
                else
                    task_des=${task_txt#* }
                    task_des=${task_des#"${task_des%%[! ]*}"}
                    task_des=${task_des#\"}
                    task_des=${task_des%\"}
                    task_name=$(cat "$CRASHDIR"/task/task_${i18n}.list "$TASKCFGDIR"/task.user 2>/dev/null | grep "$task_id" | awk -F '#' '{print $3}')
                    comp_box "$TASK5_CURRENT_TASK\033[36m$task_des\033[0m"
                    btm_box "1) $TASK5_EDIT_TASK" \
                        "2) $TASK5_DEL_TASK" \
                        "3) $TASK5_RUN_ONCE" \
                        "4) $TASK5_VIEW_RECORD" \
                        "" \
                        "0) $COMMON_BACK"
                    read -r -p "$COMMON_INPUT> " num
                    case "$num" in
                    "" | 0)
                        continue
                        ;;
                    1)
                        task_type && task_del "$task_des"
                        ;;
                    2)
                        task_del "$task_des"
                        common_success
                        ;;
                    3)
                        task_command=$(cat "$CRASHDIR"/task/task_${i18n}.list "$TASKCFGDIR"/task.user 2>/dev/null | grep "$task_id" | awk -F '#' '{print $2}')
                        eval "$task_command" && task_res="$TASK5_RUN_OK" || task_res="$TASK5_RUN_FAIL"
                        msg_alert "\033[33m$TASK5_TASK_PREFIX$task_des】$task_res\033[0m"
                        ;;
                    4)
                        if cat "$TMPDIR"/ShellCrash.log | grep -q "$task_name"; then
                            line_break
                            echo "==========================================================="
                            cat "$TMPDIR"/ShellCrash.log | grep "$task_name"
                            echo "==========================================================="
                        else
                            msg_alert "\033[31m$TASK5_RECORD_NOT_FOUND\033[0m"
                        fi
                        ;;
                    *)
                        errornum
                        ;;
                    esac
                fi
                ;;
            *)
                errornum
                ;;
            esac
        fi
    done
}

# 任务推荐
task_recom() {
    comp_box "\033[36m$TASK_RECOM_TITLE\033[0m" \
        "" \
        "$TASK_RECOM_ITEM_1" \
        "$TASK_RECOM_ITEM_2" \
        "$TASK_RECOM_ITEM_3"
    btm_box "1) $TASK5_YES" \
        "0) $TASK5_NO"
    read -r -p "$COMMON_INPUT>" res

    [ "$res" = 1 ] && {
        line_break
        separator_line "="
        set_service running "106" "$TASK_RECOM_ITEM_1" "*/10 * * * *"
        set_service afstart "107" "$TASK_RECOM_ITEM_2"
        cronset "$TASK_RECOM_ITEM_3" "0 3 * * * ${CRASHDIR}/task/task.sh 103 \"$TASK_RECOM_ITEM_3\"" &&
            content_line "【$TASK_RECOM_ITEM_3】\033[32m$COMMON_SUCCESS\033[0m"
        separator_line "="
    }
}

# 任务菜单
task_menu() {
    while true; do
        # 检测并创建自定义任务文件
        mkdir -p "$TASKCFGDIR"
        [ -f "$TASKCFGDIR"/task.user ] || echo "$TASK5_USER_FILE_HEADER" >"$TASKCFGDIR"/task.user
        comp_box "\033[30;47m$TASK5_MENU_TITLE\033[0m"
        btm_box "1) $TASK5_MENU_1" \
            "2) $TASK5_MENU_2" \
            "3) $TASK5_MENU_3" \
            "4) $TASK5_MENU_4" \
            "5) $TASK5_MENU_5" \
            "6) $TASK5_MENU_6" \
            "7) $TASK5_MENU_7" \
            "" \
            "0) $COMMON_BACK"
        read -r -p "$COMMON_INPUT> " num
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
            if cat "$TMPDIR"/ShellCrash.log | grep -q "$TASK5_TASK_GREP"; then
                line_break
                echo "==========================================================="
                cat "$TMPDIR"/ShellCrash.log | grep "$TASK5_TASK_GREP"
                echo "==========================================================="
            else
                msg_alert "\033[31m$TASK5_LOG_NOT_FOUND\033[0m"
            fi
            ;;
        4)
            msg_alert "\033[36m$TASK5_PUSH_HINT\033[0m"
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
            ;;
        esac
    done
}
