	
. "$CRASHDIR"/libs/set_cron.sh

bot_tg_start(){
	. "$CRASHDIR"/starts/start_legacy.sh
	start_legacy "$CRASHDIR/menus/bot_tg.sh" 'bot_tg'
	bot_tg_cron
}
bot_tg_stop(){
	cronload | grep -q 'TG_BOT' && cronset 'TG_BOT'
	[ -f "$TMPDIR/bot_tg.pid" ] && kill -TERM "$(cat "$TMPDIR/bot_tg.pid")" 2>/dev/null
	killall bot_tg.sh 2>/dev/null
	rm -f "$TMPDIR/bot_tg.pid"
}
bot_tg_cron(){
	cronset 'TG_BOT守护进程' "* * * * * /bin/sh $CRASHDIR/starts/start_legacy_wd.sh bot_tg #ShellCrash-TG_BOT守护进程"
}
