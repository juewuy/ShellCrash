#!/bin/sh

[ -z "$CRASHDIR" ] && CRASHDIR=$( cd $(dirname $0);cd ..;pwd)
. "$CRASHDIR"/libs/web_json.sh
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/web_get_lite.sh
. "$CRASHDIR"/libs/i18n.sh
. "$CRASHDIR"/menus/running_status.sh
. "$CRASHDIR"/configs/gateway.cfg
. "$CRASHDIR"/configs/ShellCrash.cfg

load_lang bot_tg

TMPDIR='/tmp/ShellCrash'
API="https://api.telegram.org/bot$TG_TOKEN"
STATE_FILE="$TMPDIR/tgbot_state"
LOGFILE="$TMPDIR/tgbot.log"
OFFSET=0

### --- 基础函数 --- ###
web_download(){
    setproxy
    if curl --version >/dev/null 2>&1; then
        curl -kfsSl "$1" -o "$2"
    else
        wget_proxy on -q --timeout=3 -O "$2" "$1"
    fi
}
web_upload(){
    curl -ksSfl -X POST --connect-timeout 20 "$API/sendDocument" -F "chat_id=$TG_CHATID" -F "document=@$1" >/dev/null
}
send_msg(){
    TEXT="$1"
    web_json_post "$API/sendMessage" "{\"chat_id\":\"$TG_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\"}"
}
send_help(){
    TEXT=$(cat <<EOF
$BOT_TG_HELP_GROUP
https://t.me/+6AElkMDzwPxmMmM1
$BOT_TG_HELP_PROJECT
https://github.com/juewuy/ShellClash
$BOT_TG_HELP_GUIDE
https://juewuy.github.io
$BOT_TG_HELP_COFFEE
https://juewuy.github.io/yOF4Yf06Q/
$BOT_TG_HELP_AIRPORT
https://dler.pro/auth/register?affid=89698
https://pub.bigmeok.me?code=2PuWY9I7
EOF
)
    send_msg "$TEXT"
}
send_menu(){
    #获取运行状态
    PID=$(pidof CrashCore | awk '{print $NF}')
    if [ -n "$PID" ]; then
        run="$BOT_TG_RUN_ON"
        running_status
    else
        run="$BOT_TG_RUN_OFF"
    fi
    corename=$(echo $crashcore | sed 's/singboxr/SingBoxR/' | sed 's/singbox/SingBox/' | sed 's/clash/Clash/' | sed 's/meta/Mihomo/')
    TEXT=$(cat <<EOF
*$BOT_TG_WELCOME*_${versionsh_l}_
$corename$BOT_TG_SERVICE$run
【*$redir_mod*】$BOT_TG_MEM_USED$VmRSS
$BOT_TG_RUNNING_TIME$day$time
$BOT_TG_SELECT_ACTION
EOF
)
    MENU=$(cat <<EOF
{
  "inline_keyboard":[
    [
      {"text":"$BOT_TG_BTN_START","callback_data":"start_redir"},
      {"text":"$BOT_TG_BTN_PURE","callback_data":"stop_redir"},
      {"text":"$BOT_TG_BTN_RESTART","callback_data":"restart"}
    ],
    [
      {"text":"$BOT_TG_BTN_LOG","callback_data":"readlog"},
      {"text":"$BOT_TG_BTN_TRANSFER","callback_data":"transport"}
    ]
  ]
}
EOF
)
web_json_post "$API/sendMessage" "{\"chat_id\":\"$TG_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\",\"reply_markup\":$MENU}"
}
### --- 文件传输 --- ###
send_transport_menu(){ 
    TEXT="$BOT_TG_SELECT_FILE"
    if echo "$crashcore" | grep -q 'singbox';then
        config_type=json
    else
        config_type=yaml
    fi

    if curl -h >/dev/null 2>&1;then
        CURL_KB=$(cat <<EOF
    [
      {"text":"$BOT_TG_BTN_GET_LOG","callback_data":"ts_get_log"},
      {"text":"$BOT_TG_BTN_GET_BAK","callback_data":"ts_get_bak"},
      {"text":"$BOT_TG_BTN_GET_CFG","callback_data":"ts_get_ccf"}
    ],
EOF
)
    else
        CURL_KB='[{"text":"$BOT_TG_NO_CURL","callback_data":"noop"}],'
    fi
    MENU=$(cat <<EOF
{
  "inline_keyboard":[
    $CURL_KB
    [
      {"text":"$BOT_TG_BTN_UP_CORE","callback_data":"ts_up_core"},
      {"text":"$BOT_TG_BTN_UP_BAK","callback_data":"ts_up_bak"},
      {"text":"$BOT_TG_BTN_UP_CFG","callback_data":"ts_up_ccf"}
    ]
  ]
}
EOF
)

web_json_post "$API/sendMessage" "{\"chat_id\":\"$TG_CHATID\",\"text\":\"$TEXT\",\"parse_mode\":\"Markdown\",\"reply_markup\":$MENU}"

}
process_file(){
    case "$FILE_TYPE" in
        1)
            . "$CRASHDIR"/libs/core_tools.sh
            core_check "$TMPDIR/$FILE_NAME" && res="$BOT_TG_UPLOAD_OK" || res="$BOT_TG_UPLOAD_FAIL"
            send_msg "$BOT_TG_CORE_UPDATE$res"
            sleep 2
            "$CRASHDIR"/start.sh start
        ;;
        2)
            tar -zxf "$TMPDIR/$FILE_NAME" -C "$CRASHDIR"/configs && res="$BOT_TG_CFG_RESTORED" || res="$BOT_TG_RESTORE_FAIL"
            send_msg "$res"
        ;;
        3)
            mv -f "$TMPDIR/$FILE_NAME" "$CRASHDIR/${config_type}s/" && res="$BOT_TG_CFG_UPLOADED" || res="$BOT_TG_UPLOAD_FAIL2"
            send_msg "$res"
        ;;
    esac
    rm -f "$TMPDIR/$FILE_NAME"
    send_menu
}
download_file(){
    FILE_NAME=$(echo "$UPDATES" | sed 's/"callback_query".*//g' | grep -o '"file_name":"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//' | grep -E '\.(gz|upx|json|yaml)$')
    if [ -n "$FILE_NAME" ];then
        FILE_PATH=$(web_get_lite "$API/getFile?file_id=$FILE_ID" | grep -o '"file_path":"[^"]*"' | sed 's/.*:"//;s/"$//')
        API_FILE="https://api.telegram.org/file/bot$TG_TOKEN"
        web_download "$API_FILE/$FILE_PATH" "$TMPDIR/$FILE_NAME"
        if [ "$?" = 0 ];then
            process_file
        else
            send_msg "$BOT_TG_NET_UPLOAD_FAIL"
        fi
    else
        send_msg "$BOT_TG_FILE_FORMAT_FAIL"
    fi
}
### --- 具体操作函数 --- ###
do_start_fw(){
    [ -z "$redir_mod_bf" ] && redir_mod_bf='Redir'
    redir_mod=$redir_mod_bf
    setconfig redir_mod $redir_mod
    "$CRASHDIR"/start.sh start_firewall
    echo "$BOT_TG_FW_ENABLED*$redir_mod_bf*$BOT_TG_FW_ENABLED_SUFFIX" > "$LOGFILE"
}
do_stop_fw(){
    redir_mod_bf=$redir_mod
    firewall_area=4
    setconfig firewall_area 4
    "$CRASHDIR"/start.sh stop_firewall
    echo "$BOT_TG_SWITCH_PURE" > "$LOGFILE"
}
do_restart(){
    "$CRASHDIR"/start.sh restart
    echo "$BOT_TG_SERVICE_RESTARTED" > "$LOGFILE"
}
do_set_sub(){
    #echo "$1" "$2" >> "$CRASHDIR"/configs/providers.cfg
    echo "$BOT_TG_UNFINISHED" > "$LOGFILE"

}
transport(){ #文件传输
    case "$CALLBACK" in
        "ts_get_log")
            web_upload "$TMPDIR"/ShellCrash.log
            send_menu 
        ;;
        "ts_get_bak")
            now=$(date +%Y%m%d_%H%M%S)
            FILE="$TMPDIR/configs_$now.tar.gz"
            tar -zcf "$FILE" -C "$CRASHDIR/configs/" .
            web_upload "$FILE"
            rm -rf "$FILE"
            send_menu 
        ;;
        "ts_get_ccf")
            FILE="$TMPDIR/$config_type.tar.gz"
            tar -zcf "$FILE" -C "$CRASHDIR/${config_type}s/" .
            web_upload "$FILE"
            rm -rf "$FILE"
            send_menu 
        ;;
        "ts_up_core")
            FILE_TYPE=1
            send_msg  "$BOT_TG_SEND_CORE ${corename} $BOT_TG_SEND_CORE_SUFFIX"
        ;;
        "ts_up_bak")
            FILE_TYPE=2
            send_msg  "$BOT_TG_SEND_BAK"
        ;;
        "ts_up_ccf")
            FILE_TYPE=3
            send_msg  "$BOT_TG_SEND_CFG .${config_type} $BOT_TG_SEND_CFG_SUFFIX"
        ;;
    esac
}

### --- 轮询主进程 --- ###
polling(){
    while true; do
        UPDATES=$(web_get_lite "$API/getUpdates?timeout=25&offset=$OFFSET")

        echo "$UPDATES" | grep -q '"update_id"' || {
            sleep 10 #防止网络不佳时疯狂请求
            continue
        }
        
        OFFSET=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n1 | cut -d: -f2)
        OFFSET=$((OFFSET + 1))
        
        ### --- 校验ChatID --- ###
        CHATID=$(echo "$UPDATES" | grep -o '"id":[0-9]*' | tail -n1 | cut -d: -f2)
        [ "$CHATID" != "$TG_CHATID" ] && continue
        
        ### --- 处理按钮事件 --- ###
        CALLBACK=$(echo "$UPDATES" | grep -o '"data":"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')
        FILE_ID=$(echo "$UPDATES" | sed 's/"callback_query".*//g' | grep -o '"file_id":"[^"]*"' | head -n1 | sed 's/.*:"//;s/"$//')
        
        [ -n "$FILE_ID" ] && {
            download_file
            continue
        }
        [ -n "$CALLBACK" ] && case "$CALLBACK" in
            "start_redir")
                if [ "$firewall_area" = 4 ];then
                    do_start_fw
                    send_msg  "$BOT_TG_SWITCH_TO$redir_mod_bf！"
                else
                    send_msg  "$BOT_TG_ALREADY$redir_mod！"
                fi
                send_menu 
                continue
            ;;
            "stop_redir")
                if [ "$firewall_area" != 4 ];then
                    do_stop_fw
                    send_msg  "$BOT_TG_SWITCH_PURE"
                else
                    send_msg  "$BOT_TG_ALREADY_PURE"
                fi
                send_menu 
                continue
            ;;
            "restart")
                do_restart
                send_msg  "$BOT_TG_SERVICE_RESTARTED_SHORT"
                sleep 10
                send_menu 
                continue
            ;;
            "readlog")
                send_msg  "$BOT_TG_LOG_CONTENT\n\`\`\`$(grep -v "$BOT_TG_TASK_WORD" $TMPDIR/ShellCrash.log |tail -n 20)\`\`\`"
                sleep 3
                send_menu 
                continue
            ;;
            "transport")
                send_transport_menu
                continue
            ;;
            "set_sub")
                echo "await_sub" > "$STATE_FILE"
                send_msg  "$BOT_TG_INPUT_SUB"
                continue
            ;;
            ts_*)
                transport
                continue
            ;;
        esac


        ### --- 处理订阅输入 --- ###
        TEXT=$(echo "$UPDATES" | grep -o '"text":"[^"]*"' | tail -n1 | sed 's/.*"text":"//;s/"$//')

        if [ "$(cat "$STATE_FILE" 2>/dev/null)" = "await_sub" ]; then
            echo "" > "$STATE_FILE"
            do_set_sub "$TEXT"
            send_msg  "$BOT_TG_SUB_UPDATED\n$(cat "$LOGFILE")"
            send_menu 
            continue
        fi


        ### 处理命令 ###
        case "$TEXT" in
        /crash)
            send_menu
        ;;
        /"$my_alias")
            send_menu
        ;;
        /help)
            send_help
        ;;
        esac

    done
}

[ "$TG_menupush" = ON ] && send_menu

polling

