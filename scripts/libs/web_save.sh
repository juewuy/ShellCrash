
#
get_save() { #获取面板信息
    if curl --version >/dev/null 2>&1; then
        curl -s -H "Authorization: Bearer ${secret}" -H "Content-Type:application/json" "$1"
    elif [ -n "$(wget --help 2>&1 | grep '\-\-method')" ]; then
        wget -q --header="Authorization: Bearer ${secret}" --header="Content-Type:application/json" -O - "$1"
    fi
}
web_save() { #最小化保存面板节点选择
    #使用get_save获取面板节点设置
	get_save "http://127.0.0.1:${db_port}/proxies" | sed 's/{}//g' | sed 's/:{/\
/g'| grep -aE '"Selector"' >"$TMPDIR"/web_proxies
    [ -s "$TMPDIR"/web_proxies ] && while read line; do
        def=$(echo $line | grep -oE '"all".*",' | awk -F "[\"]" '{print $4}')
        now=$(echo $line | grep -oE '"now".*",' | awk -F "[\"]" '{print $4}')
        [ "$def" != "$now" ] && {
            name=$(echo $line | grep -oE '"name".*",' | awk -F "[\"]" '{print $4}')
            echo "${name},${now}" >>"$TMPDIR"/web_save
        }
    done <"$TMPDIR"/web_proxies
    rm -rf "$TMPDIR"/web_proxies
    #对比文件，如果有变动则写入磁盘，否则清除缓存
    for file in web_save; do
        if [ -s "$TMPDIR/$file" ]; then
            . "$CRASHDIR"/libs/compare.sh && compare "$TMPDIR/$file" "$CRASHDIR/configs/$file"
            [ "$?" = 0 ] && rm -f "$TMPDIR/$file" || mv -f "$TMPDIR/$file" "$CRASHDIR/configs/$file"
		else
			rm -f "$CRASHDIR/configs/$file" #空文件时移除旧文件
        fi
    done
}
