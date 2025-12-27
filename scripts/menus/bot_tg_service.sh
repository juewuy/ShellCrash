	
. "$CRASHDIR"/libs/set_cron.sh

bot_tg_start(){
	. "$CRASHDIR"/starts/start_legacy.sh
	start_legacy "$CRASHDIR/menus/bot_tg.sh" 'bot_tg'
	cronset 'TG_BOT守护进程' "* * * * * /bin/sh $CRASHDIR/starts/start_legacy_wd.sh bot_tg #ShellCrash-TG_BOT守护进程"
}
bot_tg_stop(){
	cronset 'TG_BOT守护进程'
	[ -f "$TMPDIR/bot_tg.pid" ] && kill -TERM "$(cat "$TMPDIR/bot_tg.pid")"
	rm -f "$TMPDIR/bot_tg.pid"
}