
set_profile() {
    [ -z "$my_alias" ] && my_alias=crash
    sed -i "/ShellCrash\/menu.sh/"d "$1"
    echo "alias ${my_alias}=\"$shtype $CRASHDIR/menu.sh\"" >>"$1" #设置快捷命令环境变量
    sed -i '/export CRASHDIR=*/'d "$1"
    echo "export CRASHDIR=\"$CRASHDIR\"" >>"$1" #设置路径环境变量
}