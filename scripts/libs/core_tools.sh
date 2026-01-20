

[ -n "$(find --help 2>&1 | grep -o size)" ] && find_para=' -size +2000'             #find命令兼容

core_unzip() { #$1:需要解压的文件 $2:目标文件名
	if echo "$1" |grep -q 'tar.gz$' ;then
		[ "$BINDIR" = "$TMPDIR" ] && rm -rf "$TMPDIR"/CrashCore #小闪存模式防止空间不足
		[ -n "$(tar --help 2>&1 | grep -o 'no-same-owner')" ] && tar_para='--no-same-owner' #tar命令兼容
		mkdir -p "$TMPDIR"/core_tmp
		tar -zxf "$1" ${tar_para} -C "$TMPDIR"/core_tmp/
		for file in $(find "$TMPDIR"/core_tmp $find_para 2>/dev/null); do
			[ -f "$file" ] && [ -n "$(echo $file | sed 's#.*/##' | grep -iE '(CrashCore|sing|meta|mihomo|clash|pre)')" ] && mv -f "$file" "$TMPDIR"/"$2"
		done
		rm -rf "$TMPDIR"/core_tmp
	elif echo "$1" |grep -q '.gz$' ;then
		gunzip -c "$1" > "$TMPDIR"/"$2"
	elif echo "$1" |grep -q '.upx$' ;then
		ln -sf "$1" "$TMPDIR"/"$2"
	else
		mv -f "$1" "$TMPDIR"/"$2"
	fi
	chmod +x "$TMPDIR"/"$2"
}
core_find(){
	if [ ! -f "$TMPDIR"/CrashCore ];then
		core_dir=$(find "$BINDIR"/CrashCore.* $find_para 2>/dev/null)
		[ -n "$core_dir" ] && core_unzip "$core_dir" CrashCore
	fi
}
core_check(){
	[ -n "$(pidof CrashCore)" ] && "$CRASHDIR"/start.sh stop #停止内核服务防止内存不足
	core_unzip "$1" core_new
	sbcheck=$(echo "$crashcore" | grep 'singbox')
	v=''
	if [ -n "$sbcheck" ] && "$TMPDIR"/core_new -h 2>&1 | grep -q 'sing-box'; then
		v=$("$TMPDIR"/core_new version 2>/dev/null | grep version | awk '{print $3}')
		COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
	elif [ -z "$sbcheck" ] && "$TMPDIR"/core_new -h 2>&1 | grep -q '\-t';then
		v=$("$TMPDIR"/core_new -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
		COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
	fi
	if [ -z "$v" ]; then
		rm -rf "$1" "$TMPDIR"/core_new
		return 2
	else
		rm -f "$BINDIR"/CrashCore.tar.gz "$BINDIR"/CrashCore.gz "$BINDIR"/CrashCore.upx
		mv -f "$TMPDIR/Coretmp.$zip_type" "$BINDIR/CrashCore.$zip_type"
		mv -f "$TMPDIR/core_new" "$TMPDIR/CrashCore"
		core_v="$v"
		setconfig COMMAND "$COMMAND" "$CRASHDIR"/configs/command.env && . "$CRASHDIR"/configs/command.env
		setconfig crashcore "$crashcore"
		setconfig core_v "$core_v"
		setconfig custcorelink "$custcorelink"
		return 0
	fi
}
core_webget(){
	. "$CRASHDIR"/libs/web_get_bin.sh
	. "$CRASHDIR"/libs/check_target.sh
	if [ -z "$custcorelink" ];then
		[ -z "$zip_type" ] && zip_type='tar.gz'
		get_bin "$TMPDIR/Coretmp.$zip_type" "bin/$crashcore/${target}-linux-${cpucore}.$zip_type"
	else
		zip_type=$(echo "$custcorelink" | grep -oE 'tar.gz$')
		[ -z "$zip_type" ] && zip_type=$(echo "$custcorelink" | grep -oE 'gz$')
		[ -n "$zip_type" ] && webget "$TMPDIR/Coretmp.$zip_type" "$custcorelink"
	fi
	#校验内核
	if [ "$?" = 0 ];then
		core_check "$TMPDIR/Coretmp.$zip_type"
	else
		rm -rf "$TMPDIR/Coretmp.$zip_type"
		return 1
	fi
}
