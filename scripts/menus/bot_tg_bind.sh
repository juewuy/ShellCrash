#!/bin/sh

. "$CRASHDIR"/libs/web_json.sh

private_bot() {
	echo "-----------------------------------------------"
	echo -e "请先通过 \033[32;4mhttps://t.me/BotFather\033[0m 申请TG机器人并获取其\033[36mAPI TOKEN\033[0m"
	echo "-----------------------------------------------"
	read -p "请输入你获取到的API TOKEN > " TOKEN
	echo "-----------------------------------------------"
	echo -e "请向\033[32m你申请的机器人\033[33m而不是BotFather！\033[0m"
	url_tg=https://api.telegram.org/bot${TOKEN}/getUpdates
}
public_bot() {
	echo -e "请向机器人：\033[32;4mhttps://t.me/ShellCrashtg_bot\033[0m"
	TOKEN=publictoken
	url_tg=https://tgbot.jwsc.eu.org/publictoken/getUpdates
}
tg_push_token(){
	push_TG="$TOKEN"
	setconfig push_TG "$TOKEN"
	setconfig chat_ID "$chat_ID"
	"$CRASHDIR"/start.sh logger "已完成Telegram日志推送设置！" 32
}
set_bot() {
	public_key=$(cat /proc/sys/kernel/random/boot_id | sed 's/.*-//')
	echo -e "发送此秘钥:        \033[30;46m$public_key\033[0m"
	echo "-----------------------------------------------"
	read -p "我已经发送完成(1/0) > " res
	if [ "$res" = 1 ]; then
		chat=$(web_json_get $url_tg 2>/dev/null)
		[ -n "$chat" ] && chat_ID=$(echo $chat | sed 's/"update_id":/{\n"update_id":/g' | grep "$public_key" | head -n1 | grep -oE '"id":.*,"is_bot' | sed s'/"id"://' | sed s'/,"is_bot//')
		[ -z "$chat_ID" ] && [ "$TOKEN" != 'publictoken' ] && {
			echo -e "\033[31m无法获取对话ID，请返回重新设置或手动输入ChatID！\033[0m"
			echo -e "通常访问 \033[32;4m$url_tg\033[0m \n\033[36m即可看到ChatID\033[0m"
			read -p "请手动输入ChatID > " chat_ID
		}
		if echo "$chat_ID" | grep -qE '^[0-9]{8,}$'; then
			return 0
		else
			echo -e "\033[31m无法获取对话ID，请重新配置！\033[0m"
			sleep 1
			return 1
		fi
	fi
}

