
core_exchange() { #升级为高级内核
    #$1：目标内核  $2：提示语句
    logger "检测到${2}！将改为使用${1}核心启动！" 33
    rm -rf "$TMPDIR"/CrashCore
    rm -rf "$BINDIR"/CrashCore
    rm -rf "$BINDIR"/CrashCore.tar.gz
    crashcore="$1"
    setconfig crashcore "$1"
    echo "-----------------------------------------------"
}
