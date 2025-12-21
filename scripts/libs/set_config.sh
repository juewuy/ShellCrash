#参数1代表变量名，参数2代表变量值,参数3即文件路径
setconfig() {
    [ -z "$3" ] && configpath="$CRASHDIR"/configs/ShellCrash.cfg || configpath="${3}"
    if grep -q "^${1}=" "$configpath"; then
        sed -i "s#^${1}=.*#^${1}=${2}#g" "$configpath"
    else
        printf '%s=%s\n' "$1" "$2" >>"$configpath"
    fi
}