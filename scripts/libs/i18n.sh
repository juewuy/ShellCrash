
load_lang() {
    i18n=$(cat "$CRASHDIR"/configs/i18n.cfg 2>/dev/null)
	[ -z "$i18n" ] && i18n=chs
	
    file="$CRASHDIR/lang/$i18n/$1.lang"
    [ -s "$file" ] && . "$file"
}