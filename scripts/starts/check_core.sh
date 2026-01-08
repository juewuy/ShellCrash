
. "$CRASHDIR"/libs/check_target.sh
. "$CRASHDIR"/libs/core_tools.sh
. "$CRASHDIR"/configs/command.env

check_core() { #检查及下载内核文件
    [ -n "$(find --help 2>&1 | grep -o size)" ] && find_para=' -size +2000'             #find命令兼容
	[ -z "$(find "$TMPDIR"/CrashCore $find_para 2>/dev/null)" ] && core_find
    [ -z "$(find "$TMPDIR"/CrashCore 2>/dev/null)" ] && {
        logger "未找到【$crashcore】核心，正在下载！" 33
        [ -z "$cpucore" ] && . "$CRASHDIR"/libs/check_cpucore.sh && check_cpucore
        [ -z "$cpucore" ] && logger 找不到设备的CPU信息，请手动指定处理器架构类型！ 31 && exit 1
        core_webget || logger "核心下载失败，请重新运行或更换安装源！" 31  
    }
    [ ! -x "$TMPDIR"/CrashCore ] && chmod +x "$TMPDIR"/CrashCore 2>/dev/null                               #自动授权
    [ "$start_old" != "ON" -a "$(cat /proc/1/comm)" = "systemd" ] && restorecon -RF "$CRASHDIR" 2>/dev/null #修复SELinux权限问题
    return 0
}
