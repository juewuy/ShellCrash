#日志工具
#$1日志内容$2显示颜色$3是否推送
logger() { 
	TMPDIR=/tmp/ShellCrash
    [ -n "$2" -a "$2" != 0 ] && echo -e "\033[$2m$1\033[0m"
    log_text="$(date "+%G-%m-%d_%H:%M:%S")~$1"
    echo "$log_text" >>"$TMPDIR"/ShellCrash.log
    [ "$(wc -l "$TMPDIR"/ShellCrash.log | awk '{print $1}')" -gt 99 ] && sed -i '1,50d' "$TMPDIR"/ShellCrash.log
    #推送工具
    webpush() {
        [ -n "$(pidof CrashCore)" ] && {
            [ -n "$authentication" ] && auth="$authentication@"
            export https_proxy="http://${auth}127.0.0.1:$mix_port"
        }
        if curl --version >/dev/null 2>&1; then
            curl -kfsSl -X POST --connect-timeout 3 -H "Content-Type: application/json; charset=utf-8" "$1" -d "$2" >/dev/null 2>&1
        elif wget --version >/dev/null 2>&1; then
            wget -Y on -q --timeout=3 -O - --method=POST --header="Content-Type: application/json; charset=utf-8" --body-data="$2" "$1" >/dev/null 2>&1
        fi
    }
    [ -z "$3" ] && {
        [ -n "$device_name" ] && log_text="$log_text($device_name)"
        [ -n "$push_TG" ] && {
            url="https://api.telegram.org/bot${push_TG}/sendMessage"
            [ "$push_TG" = 'publictoken' ] && url='https://tgbot.jwsc.eu.org/publictoken/sendMessage'
            content="{\"chat_id\":\"${chat_ID}\",\"text\":\"$log_text\"}"
            webpush "$url" "$content" &
        }
        [ -n "$push_bark" ] && {
            url="${push_bark}"
            content="{\"body\":\"${log_text}\",\"title\":\"ShellCrash日志推送\",\"level\":\"passive\",\"badge\":\"1\"}"
            webpush "$url" "$content" &
        }
        [ -n "$push_Deer" ] && {
            url="https://api2.pushdeer.com/message/push"
            content="{\"pushkey\":\"${push_Deer}\",\"text\":\"$log_text\"}"
            webpush "$url" "$content" &
        }
        [ -n "$push_Po" ] && {
            url="https://api.pushover.net/1/messages.json"
            content="{\"token\":\"${push_Po}\",\"user\":\"${push_Po_key}\",\"title\":\"ShellCrash日志推送\",\"message\":\"$log_text\"}"
            webpush "$url" "$content" &
        }
        [ -n "$push_PP" ] && {
            url="http://www.pushplus.plus/send"
            content="{\"token\":\"${push_PP}\",\"title\":\"ShellCrash日志推送\",\"content\":\"$log_text\"}"
            webpush "$url" "$content" &
        }
        [ -n "$push_Gotify" ] && {
            url="${push_Gotify}"
            content="{\"title\":\"ShellCrash日志推送\",\"message\":\"$log_text\",\"priority\":5}"
            webpush "$url" "$content" &
        }
        [ -n "$push_SynoChat" ] && {
            url="${push_ChatURL}/webapi/entry.cgi?api=SYNO.Chat.External&method=chatbot&version=2&token=${push_ChatTOKEN}"
            content="payload={\"text\":\"${log_text}\", \"user_ids\":[${push_ChatUSERID}]}"
            webpush "$url" "$content" &
		}
    } &
}
