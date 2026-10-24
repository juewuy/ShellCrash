crondir="$(crond -h 2>&1 | grep -oE 'Default:.*' | awk -F ":" '{print $2}'| tr -d ' ')"
[ ! -w "$crondir" ] && crondir="/etc/storage/cron/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron/crontabs"
[ ! -w "$crondir" ] && crondir="/var/spool/cron"
[ -z "$USER" ] && USER=$(id -un)
[ -z "$TASKCFGDIR" ] && TASKCFGDIR="$CRASHDIR"/configs/task

# ShellCrash 使用的 ash/bash（以及 dash）均支持 test -O。
# shellcheck disable=SC3067
croncheck() { #在任何写操作前检查实例管理权限，保留普通用户自己的安装
    cron_uid=$(id -u) || return 1
    [ "$cron_uid" = 0 ] && return 0
    if [ ! -O "$CRASHDIR/configs/ShellCrash.cfg" ] || [ ! -w "$CRASHDIR/configs/ShellCrash.cfg" ]; then
        echo '无权管理此 ShellCrash 实例，请使用安装用户或 root。' >&2
        return 1
    fi
    for cron_pid in $(pidof CrashCore 2>/dev/null); do
        if [ ! -O "/proc/$cron_pid" ]; then
            echo '无权管理其他用户启动的 CrashCore。' >&2
            return 1
        fi
    done
}

cronadd() ( #定时任务工具；子 shell 隔离临时变量和清理 trap
    croncheck || exit 1
    [ -f "$1" ] && [ -r "$1" ] || exit 1
    if crontab -h 2>&1 | grep -q '\-l'; then
        crontab "$1"
    elif [ -w "$crondir" ]; then
        cron_user=$(id -un) || exit 1
        cron_stage=$(mktemp "$crondir/.shellcrash.XXXXXX") || exit 1
        trap 'rm -f "$cron_stage"' 0
        trap 'exit 1' 1 2 3 15
        [ ! -e "$crondir/$cron_user" ] || cp -p "$crondir/$cron_user" "$cron_stage" || exit 1
        cat "$1" >"$cron_stage" && mv -f "$cron_stage" "$crondir/$cron_user" || exit 1
        if command -v cru >/dev/null 2>&1; then
            cru a REFRESH "0 0 1 1 * /bin/true"
        fi
    else
        echo '找不到可用的 crond 或 crontab！No available crond or crontab!' >&2
        exit 1
    fi
)

cronload() (
    cron_user=$(id -un) || exit 1
    if crontab -h 2>&1 | grep -q '\-l'; then
        cron_text=$(LC_ALL=C crontab -l 2>&1)
        cron_status=$?
        if [ "$cron_status" = 0 ]; then
            [ -z "$cron_text" ] || printf '%s\n' "$cron_text"
            exit 0
        fi
        #首次使用没有 crontab 是合法空表，其他错误必须传回调用者。
        case "$cron_text" in
            "no crontab for $cron_user" | "crontab: can't open '$cron_user': No such file or directory") exit 0 ;;
        esac
        printf '%s\n' "$cron_text" >&2
        exit "$cron_status"
    elif [ -d "$crondir" ] && [ -r "$crondir" ] && [ -x "$crondir" ]; then
        [ -e "$crondir/$cron_user" ] || [ -L "$crondir/$cron_user" ] || exit 0
        cat "$crondir/$cron_user"
    else
        echo '无法读取原有 crontab，已取消修改。' >&2
        exit 1
    fi
)

cronupdate() ( #成功读取、生成后才提交；参数是读取 stdin 的过滤命令
    croncheck || exit 1
    cron_tmp=$(mktemp -d /tmp/ShellCrash-cron.XXXXXX) || exit 1
    cron_saved=
    trap 'rm -rf "$cron_tmp"; [ -z "$cron_saved" ] || rm -f "$cron_saved"' 0
    trap 'exit 1' 1 2 3 15
    cronload >"$cron_tmp/old" || exit 1
    "$@" <"$cron_tmp/old" >"$cron_tmp/new" || exit 1
    #先准备华硕/Padavan 的持久化副本；任何提交前的写入失败都保留原表。
    if [ "$cron_persist" = true ] && { [ -d /jffs ] || [ -d /etc/storage/ShellCrash ]; }; then
        mkdir -p "$TASKCFGDIR" || exit 1
        cron_saved=$(mktemp "$TASKCFGDIR/.cron.XXXXXX") || exit 1
        cat "$cron_tmp/new" >"$cron_saved" || exit 1
    fi
    cronadd "$cron_tmp/new" || exit 1
    [ -z "$cron_saved" ] || mv -f "$cron_saved" "$TASKCFGDIR/cron"
)

cronset() ( #参数1：移除的文字；参数2：新增任务。空结果也是合法 crontab。
    cron_persist=true
    # shellcheck disable=SC2016
    CRON_KEY="$1" CRON_TASK="$2" cronupdate awk '
        NF && !index($0, ENVIRON["CRON_KEY"]) { print }
        END { if (ENVIRON["CRON_TASK"] != "") print ENVIRON["CRON_TASK"] }
    '
)
