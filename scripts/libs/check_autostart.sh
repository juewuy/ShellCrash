# s6 / Docker：自启状态以 configs 卷内标记为准，并同步到 s6 contents.d

enable_s6_autostart_marks() {
    mkdir -p "$CRASHDIR/configs" /etc/s6-overlay/s6-rc.d/user/contents.d
    touch "$CRASHDIR/configs/.autostart" /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
}

disable_s6_autostart_marks() {
    rm -f "$CRASHDIR/configs/.autostart" /etc/s6-overlay/s6-rc.d/user/contents.d/afstart
}

# 将旧版仅写在可写层的 s6 标记迁移到 configs
migrate_s6_autostart_mark() {
    if [ -f /etc/s6-overlay/s6-rc.d/user/contents.d/afstart ] && [ ! -f "$CRASHDIR/configs/.autostart" ]; then
        mkdir -p "$CRASHDIR/configs"
        touch "$CRASHDIR/configs/.autostart"
    fi
}

check_autostart(){
    if [ "$start_old" = ON ];then
        [ ! -f "$CRASHDIR"/.dis_startup ] && return 0
    elif [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
        [ -n "$(find /etc/rc.d -name '*shellcrash')" ] && return 0
        [ ! -f "$CRASHDIR"/.dis_startup ] && return 0
    elif ckcmd systemctl; then
        [ "$(systemctl is-enabled shellcrash.service 2>&1)" = enabled ] && return 0
    elif grep -q 's6' /proc/1/comm; then
        migrate_s6_autostart_mark
        [ -f "$CRASHDIR/configs/.autostart" ] && [ ! -f "$CRASHDIR"/.dis_startup ] && return 0
    elif rc-status -r >/dev/null 2>&1; then
        rc-update show default | grep -q "shellcrash" && return 0
    else
        return 1
    fi
    return 1
}
