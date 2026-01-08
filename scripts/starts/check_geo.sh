
. "$CRASHDIR"/libs/set_config.sh

check_geo() { #查找及下载Geo数据文件
    [ ! -d "$BINDIR"/ruleset ] && mkdir -p "$BINDIR"/ruleset
    find --help 2>&1 | grep -q size && find_para=' -size +20' #find命令兼容
    [ -z "$(find "$BINDIR"/"$1" "$find_para" 2>/dev/null)" ] && {
        if [ -n "$(find "$CRASHDIR"/"$1" "$find_para" 2>/dev/null)" ]; then
            mv "$CRASHDIR"/"$1" "$BINDIR"/"$1" #小闪存模式移动文件
        else
            logger "未找到${1}文件，正在下载！" 33
            get_bin "$BINDIR"/"$1" bin/geodata/"$2"
            [ "$?" = "1" ] && rm -rf "${BINDIR}"/"${1}" && logger "${1}文件下载失败,已退出！请前往更新界面尝试手动下载！" 31 && exit 1
            geo_v="$(echo "$2" | awk -F "." '{print $1}')_v"
            setconfig "$geo_v" "$(date +"%Y%m%d")"
        fi
    }
}