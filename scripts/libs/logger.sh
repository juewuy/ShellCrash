#日志工具
. "$CRASHDIR"/libs/web_json.sh
#$1日志内容$2显示颜色$3是否推送
logger() { 
	TMPDIR=/tmp/ShellCrash
    [ -n "$2" -a "$2" != 0 ] && printf "\033[%sm%s\033[0m\n" "$2" "$1"
    log_text="$(date "+%G-%m-%d_%H:%M:%S")~$1"
    echo "$log_text" >>"$TMPDIR"/ShellCrash.log
    [ "$(wc -l "$TMPDIR"/ShellCrash.log | awk '{print $1}')" -gt 199 ] && sed -i '1,20d' "$TMPDIR"/ShellCrash.log
	#推送远程日志
    [ -z "$3" ] && {
        [ -n "$device_name" ] && log_text="$log_text($device_name)"
        [ -n "$push_TG" ] && {
            url="https://api.telegram.org/bot${push_TG}/sendMessage"
            [ "$push_TG" = 'publictoken' ] && url='https://tgbot.jwsc.eu.org/publictoken/sendMessage'
            content="{\"chat_id\":\"${chat_ID}\",\"text\":\"$log_text\"}"
            web_json_post "$url" "$content" &
        }
        [ -n "$push_bark" ] && {
            url="${push_bark}"
            content="{\"body\":\"${log_text}\",\"title\":\"ShellCrash_log\",\"level\":\"passive\",\"badge\":\"1\"}"
            web_json_post "$url" "$content" &
        }
        [ -n "$push_Deer" ] && {
            url="https://api2.pushdeer.com/message/push"
            content="{\"pushkey\":\"${push_Deer}\",\"text\":\"$log_text\"}"
            web_json_post "$url" "$content" &
        }
        [ -n "$push_Po" ] && {
            url="https://api.pushover.net/1/messages.json"
            content="{\"token\":\"${push_Po}\",\"user\":\"${push_Po_key}\",\"title\":\"ShellCrash_log\",\"message\":\"$log_text\"}"
            web_json_post "$url" "$content" &
        }
        [ -n "$push_PP" ] && {
            url="http://www.pushplus.plus/send"
            content="{\"token\":\"${push_PP}\",\"title\":\"ShellCrash_log\",\"content\":\"$log_text\"}"
            web_json_post "$url" "$content" &
        }
        [ -n "$push_Gotify" ] && {
            url="${push_Gotify}"
            content="{\"title\":\"ShellCrash_log\",\"message\":\"$log_text\",\"priority\":5}"
            web_json_post "$url" "$content" &
        }
        [ -n "$push_SynoChat" ] && {
            url="${push_ChatURL}/webapi/entry.cgi?api=SYNO.Chat.External&method=chatbot&version=2&token=${push_ChatTOKEN}"
            content="payload={\"text\":\"${log_text}\", \"user_ids\":[${push_ChatUSERID}]}"
            web_json_post "$url" "$content" &
		}
    } &
}
