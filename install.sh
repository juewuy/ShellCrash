#!/usr/bin/env bash
# Copyright (C) Juewuy

# ================================= table format tools =================================
# >>>>>>>>>>>>>>

# set the total width of the menu
# (adjusting this number will automatically change the entire menu, including the separator lines)
# note: The number represents the number of columns that appear when the "||" appears on the right
TABLE_WIDTH=60

# define two extra-long template strings in advance
# (the length should be greater than the expected TABLE_WIDTH)
FULL_EQ="===================================================================================================="
FULL_DASH="- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "

# function to print content lines
# (using cursor jump)
content_line() {
    echo -e " ${1}\033[${TABLE_WIDTH}G||"
}

# function to print sub content lines
# for printing accompanying instructions
sub_content_line() {
    echo -e "    ${1}\033[${TABLE_WIDTH}G||"
    content_line
}

# increase the spacing between the front
# and back forms to improve readability
double_line_break() {
    printf "\n\n"
}

# function to print separators
# (using string slicing)
# parameter $1: pass in "=" or "-"
separator_line() {
    local separator_type="$1"
    local output_line=""
    local len=$((TABLE_WIDTH - 1))

    if [ "$separator_type" == "=" ]; then
        output_line="${FULL_EQ:0:$len}"
    else
        output_line="${FULL_DASH:0:$len}"
    fi

    echo "${output_line}||"
}
# <<<<<<<<<<<<<<
# ================================= table format tools =================================

# =============================== display prompt message ===============================
# >>>>>>>>>>>>>>

abort_install() {
    double_line_break
    separator_line "="
    content_line "安装已取消"
    separator_line "="
    double_line_break

    exit 1
}

invalid_input_retry() {
    double_line_break
    separator_line "="
    content_line "\033[31m输入错误！\033[0m"
    content_line "\033[31m请重新设置！\033[0m"
    separator_line "="

    sleep 1
}

# <<<<<<<<<<<<<<
# =============================== display prompt message ===============================

[ -z "$url" ] && url="https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@dev"
type bash &>/dev/null && shtype=bash || shtype=sh

error_down() {
    content_line "\033[33m请参考：\033[0m"
    content_line "\033[33mgithub.com/juewuy/ShellCrash/blob/master/README_CN.md\033[0m"
    content_line "\033[33m或使用其他安装源重新安装！\033[0m"
}

# check available capacity
dir_avail() {
    df -h >/dev/null 2>&1 && h="$2"
    df -P $h "${1:-.}" 2>/dev/null | awk 'NR==2 {print $4}'
}

# 检查命令
ckcmd() {
    if command -v sh >/dev/null 2>&1; then
        command -v "$1" >/dev/null 2>&1
    else
        type "$1" >/dev/null 2>&1
    fi
}

webget() {
    #参数【$1】代表下载目录，【$2】代表在线地址
    #参数【$3】代表输出显示，【$4】不启用重定向
    if curl --version >/dev/null 2>&1; then
        [ "$3" = "echooff" ] && progress='-s' || progress='-#'
        [ -z "$4" ] && redirect='-L' || redirect=''
        result=$(curl -w %{http_code} --connect-timeout 5 "$progress" "$redirect" -ko "$1" "$2")

        # === original version ===
        # [ -n "$(echo $result | grep -e ^2)" ] && result="200"

        # === fixed version ===
        # strictly match the 200 status code to avoid 204 (empty content)
        # or 202 being mistakenly interpreted as success
        if [ "$result" = "200" ]; then
            result="200"
        fi

    else
        if wget --version >/dev/null 2>&1; then
            [ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
            [ "$4" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
            certificate='--no-check-certificate'
            timeout='--timeout=3'
        fi
        [ "$3" = "echoon" ] && progress=''
        [ "$3" = "echooff" ] && progress='-q'
        wget "$progress" "$redirect" "$certificate" "$timeout" -O "$1" "$2"
        [ $? -eq 0 ] && result="200"
    fi
}

# 安装及初始化
set_alias() {
    while true; do
        double_line_break
        separator_line "="
        content_line "\033[36m请选择一个别名\033[0m"
        content_line "\033[36m或直接输入自定义别名\033[0m"
        separator_line "-"
        content_line "1) 【\033[32mcrash\033[0m】"
        content_line "2) 【\033[32m sc  \033[0m】"
        content_line "3) 【\033[32m mm  \033[0m】"
        content_line "E) 退出安装"
        separator_line "="
        read -p "请输入相应数字/自定义别名> " res
        case "$res" in
        1)
            my_alias=crash
            ;;
        2)
            my_alias=sc
            ;;
        3)
            my_alias=mm
            ;;
        "E" | "e")
            abort_install
            ;;
        *)
            my_alias=$res
            ;;
        esac
        cmd=$(ckcmd "$my_alias" | grep 'menu.sh')
        ckcmd "$my_alias" && [ -z "$cmd" ] && {
            double_line_break
            separator_line "="
            content_line "该别名【\033[32m$my_alias\033[0m】和当前系统内置命令／别名\033[33m冲突\033[0m，请更换"
            separator_line "="

            sleep 1
            continue
        }
        break 1
    done
}

gettar() {
    webget /tmp/ShellCrash.tar.gz "$url/ShellCrash.tar.gz" >/dev/null 2>&1
    if [ "$result" != "200" ]; then
        content_line "\033[31m下载失败！\033[0m"
        error_down
        separator_line "="
        double_line_break
        exit 1
    else
        content_line "下载成功"
        "$CRASHDIR"/start.sh stop 2>/dev/null
        # 解压
        content_line "开始解压文件......"
        mkdir -p "$CRASHDIR" >/dev/null
        tar -zxf '/tmp/ShellCrash.tar.gz' -C "$CRASHDIR"/ || tar -zxf '/tmp/ShellCrash.tar.gz' --no-same-owner -C "$CRASHDIR"/
        if [ -s "$CRASHDIR"/init.sh ]; then
            content_line "解压成功"
            separator_line "="
            set_alias
            . $CRASHDIR/init.sh >/dev/null
            if [ $? != 0 ]; then
                content_line "\033[31m初始化失败，请尝试本地安装！\033[0m"
                separator_line "="
                double_line_break

                exit 1
            fi

        else
            rm -rf /tmp/ShellCrash.tar.gz
            content_line "\033[31m解压失败！\033[0m"
            error_down
            separator_line "="
            double_line_break

            exit 1
        fi
    fi
}

set_usb_dir() {
    while true; do
        double_line_break
        separator_line "="
        content_line "请选择安装目录："
        separator_line "-"

        # original version
        # du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
        du -hL /mnt |
            awk '{print NR") "$2"    （已用空间："$1"）"}' |
            while IFS= read -r line; do
                content_line "$line"
            done

        content_line "0) 返回上级菜单"
        separator_line "="
        read -p "请输入相应数字> " num
        case "$num" in
        0)
            return 1
            ;;
        *)
            dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
            if [ -z "$dir" ]; then
                invalid_input_retry
                continue
            fi
            return 0
            ;;
        esac
    done
}

set_asus_dir() {
    while true; do
        double_line_break
        separator_line "="
        content_line "请选择U盘目录："
        separator_line "-"

        # original version
        # du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print " "NR" "$2"  "$1}'
        du -hL /tmp/mnt |
            awk -F/ 'NF<=4 {print NR") "$2"    （已用空间："$1"）"}' |
            while IFS= read -r line; do
                content_line "$line"
            done

        content_line "0) 返回上级菜单"
        separator_line "="
        read -p "请输入相应数字> " num
        case "$num" in
        0)
            return 1
            ;;
        *)
            dir=$(du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print $2}' | sed -n "$num"p)
            if [ ! -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ]; then
                double_line_break
                separator_line "="
                content_line "\033[33m未找到下载大师自启文件：\033[0m"
                content_line "\033[33m$dir/asusware.arm/etc/init.d/S50downloadmaster\033[0m"
                content_line "\033[33m请检查设置！\033[0m"
                separator_line "="

                continue
            fi
            return 0
            ;;
        esac
    done
}

set_cust_dir() {
    while true; do
        double_line_break
        separator_line "="
        content_line "\033[33m注意：\033[0m"
        content_line "\033[33m路径必须是带 / 的格式\033[0m"
        content_line "\033[33m写入虚拟内存（/tmp，/opt，/sys...）的文件会在重启后消失！\033[0m"
        separator_line "-"
        content_line "参考路经："
        separator_line "-"

        # original version
        # df -h | awk '{print $6,$4}' | sed 1d
        df -h |
            awk 'NR>1 {
                path="";
                for(i=6;i<=NF;i++) path=path $i " ";
                sub(/ $/, "", path);
                print path "|" $4
            }' |
            while IFS='|' read -r mount_point path_avail; do
                if [ -n "$mount_point" ]; then
                    i=$((i + 1))
                    printf -v line_content "%-3s %s" "$i)" "$mount_point"
                    content_line "$line_content"
                    sub_content_line " （可用空间：$path_avail）"
                fi
            done

        content_line "0) 返回上级菜单"
        separator_line "="
        read -p "请输入自定义路径> " dir
        case "$dir" in
        0)
            return 1
            ;;
        *)
            if [ "$(dir_avail "$dir")" = 0 ] || [ -n "$(echo "$dir" | grep -E 'tmp|opt|sys')" ]; then
                invalid_input_retry
                continue
            fi
            return 0
            ;;
        esac
    done
}

setdir() {
    while true; do
        double_line_break
        separator_line "="
        content_line "\033[33m注意：\033[0m"
        content_line "\033[33m安装ShellCrash至少需要预留约 1MB 的磁盘空间\033[0m"
        if [ -n "$systype" ]; then
            [ "$systype" = "Padavan" ] && dir=/etc/storage

            [ "$systype" = "mi_snapshot" ] && {
                content_line "\033[33m检测到当前设备为小米官方系统\033[0m"

                separator_line "-"
                content_line "请选择安装位置："
                separator_line "-"

                if [ -d /data ]; then
                    content_line "1) 安装到 /data 目录"
                    sub_content_line "剩余空间：$(dir_avail /data -h)（支持软固化功能）"
                fi

                if [ -d /userdisk ]; then
                    content_line "2) 安装到 /userdisk 目录"
                    sub_content_line "剩余空间：$(dir_avail /userdisk -h)（支持软固化功能）"
                fi

                if [ -d /data/other_vol ]; then
                    content_line "3) 安装到 /data/other_vol 目录"
                    sub_content_line "剩余空间：$(dir_avail /data/other_vol -h)（支持软固化功能）"
                fi

                content_line "4) 安装到自定义目录"
                sub_content_line "（不推荐，不明勿用！）"

                content_line "E) 退出安装"
                separator_line "="
                read -p "请输入相应数字> " num
                case "$num" in
                1)
                    dir=/data
                    ;;
                2)
                    dir=/userdisk
                    ;;
                3)
                    dir=/data/other_vol
                    ;;
                4)
                    set_cust_dir
                    ret=$?
                    [ "$ret" -eq 1 ] && continue
                    ;;
                "E" | "e")
                    abort_install
                    ;;
                *)
                    invalid_input_retry
                    continue
                    ;;
                esac
            }

            [ "$systype" = "asusrouter" ] && {

                content_line "\033[33m检测到当前设备为华硕固件\033[0m"
                separator_line "-"
                content_line "请选择安装方式："
                separator_line "-"

                content_line "1) 基于USB设备安装"
                sub_content_line "（限23年9月之前固件，须插入任意USB设备）"

                content_line "2) 基于自启脚本安装"
                sub_content_line "（仅支持梅林及部分非koolshare官改固件）"

                content_line "3) 基于U盘 + 下载大师安装"
                sub_content_line "（支持所有固件，限ARM设备，须插入U盘或移动硬盘）"

                content_line "E) 退出安装"
                separator_line "="

                read -p "请输入相应数字> " num
                case "$num" in
                1)
                    double_line_break
                    separator_line "="
                    content_line "请选择脚本安装位置："
                    separator_line "-"
                    content_line "1) USB存储"
                    content_line "2) 系统闪存"
                    separator_line "="
                    read -p "请输入相应数字> " num
                    case "$num" in
                    1)
                        set_usb_dir
                        ;;
                    *)
                        dir=/jffs
                        ;;
                    esac

                    usb_status=1
                    ;;
                2)
                    double_line_break
                    separator_line "="
                    content_line "如无法正常开机启动，请重新使用USB方式安装！"
                    separator_line "="
                    sleep 2

                    dir=/jffs
                    ;;
                3)
                    double_line_break
                    separator_line "="
                    content_line "请先在路由器网页后台安装下载大师并启用，"
                    content_line "之后选择外置存储所在目录！"
                    separator_line "="
                    sleep 2

                    set_asus_dir
                    ret=$?
                    [ "$ret" -eq 1 ] && continue
                    ;;
                "E" | "e")
                    abort_install
                    ;;
                *)
                    invalid_input_retry
                    continue
                    ;;
                esac
            }

            [ "$systype" = "ng_snapshot" ] && dir=/tmp/mnt
        else
            separator_line "-"
            content_line "请选择安装目录："
            separator_line "-"
            content_line "1) \033[32m/etc目录\033[0m        （适合root用户）"
            content_line "2) \033[32m/usr/share目录\033[0m  （适合Linux系统）"
            content_line "3) \033[32m当前用户目录\033[0m    （适合非root用户）"
            content_line "4) \033[32m外置存储\033[0m"
            content_line "5) 手动设置"
            content_line "E) 退出安装"
            separator_line "="
            read -p "请输入相应数字> " num
            # 设置目录
            case "$num" in
            1)
                dir=/etc
                ;;
            2)
                dir=/usr/share
                ;;
            3)
                dir=~/.local/share
                mkdir -p ~/.config/systemd/user
                ;;
            4)
                set_usb_dir
                ret=$?
                [ "$ret" -eq 1 ] && continue
                ;;
            5)
                set_cust_dir
                ret=$?
                [ "$ret" -eq 1 ] && continue
                ;;
            "E" | "e")
                abort_install
                ;;
            *)
                invalid_input_retry
                continue
                ;;
            esac
        fi

        if [ ! -w "$dir" ]; then
            double_line_break
            separator_line "="
            content_line "\033[31m没有$dir目录写入权限！\033[0m"
            content_line "\033[31m请重新设置！\033[0m"
            separator_line "="
            sleep 2
        else
            while true; do
                double_line_break
                separator_line "="
                content_line "目标目录：\033[32m$dir\033[0m"
                content_line "可用空间：$(dir_avail $dir -h)"
                separator_line "-"
                content_line "1) 确认安装"
                content_line "E) 退出安装"
                content_line "0) 返回上级菜单"
                separator_line "="
                read -p "请输入相应数字> " num
                case "$num" in
                0)
                    break 1
                    ;;
                1)
                    CRASHDIR="${dir}/ShellCrash"
                    break 2
                    ;;
                "E" | "e")
                    abort_install
                    ;;
                *)
                    invalid_input_retry
                    continue
                    ;;
                esac
            done
        fi
    done
}

install() {
    double_line_break
    separator_line "="
    content_line "下载安装文件......"
    gettar
    double_line_break
    separator_line "="
    content_line "ShellCrash 已经安装成功！"
    [ "$profile" = "~/.bashrc" ] && content_line "请执行【. ~/.bashrc > /dev/null】命令以更新环境变量！"
    [ -n "$(ls -l /bin/sh | grep -oE 'zsh')" ] && content_line "请执行【. ~/.zshrc > /dev/null】命令以更新环境变量！"
    content_line "输入\033[32m $my_alias \033[0m命令即可管理！"
    separator_line "="
    double_line_break
}

setversion() {
    while true; do
        double_line_break
        separator_line "="
        content_line "请选择安装版本："
        separator_line "-"
        content_line "1) \033[32m公测版（推荐）\033[0m"
        content_line "2) \033[36m稳定版\033[0m"
        content_line "3) \033[31m开发版\033[0m"
        content_line "E) 退出安装"
        separator_line "="
        read -p "请输入相应数字> " num
        case "$num" in
        1)
            break 1
            ;;
        2)
            url=$(echo "$url" | sed 's/master/stable/')
            break 1
            ;;
        3)
            url=$(echo "$url" | sed 's/master/dev/')
            break 1
            ;;
        "E" | "e")
            abort_install
            ;;
        *)
            invalid_input_retry
            continue
            ;;
        esac
    done
}

# =============================== the script start here ================================

# clean screen
printf "\033[H\033[2J"

double_line_break
separator_line "="
content_line "                       欢迎使用"
content_line "                      ShellCrash"
content_line
content_line "            支持各种基于 openwrt 的路由器设备"
content_line "           支持Debian、Centos等标准 Linux 系统"
content_line "          如遇问题请加TG群反馈：t.me/ShellClash"
content_line
content_line "                                            by Juewuy"
separator_line "="

# 特殊固件识别及标记
[ -f "/etc/storage/started_script.sh" ] && {
    systype=Padavan # 老毛子固件
    initdir='/etc/storage/started_script.sh'
}
[ -d "/jffs" ] && {
    systype=asusrouter # 华硕固件
    [ -f "/jffs/.asusrouter" ] && initdir='/jffs/.asusrouter'
    [ -d "/jffs/scripts" ] && initdir='/jffs/scripts/nat-start'
}
[ -f "/data/etc/crontabs/root" ] && systype=mi_snapshot # 小米设备
[ -w "/var/mnt/cfg/firewall" ] && systype=ng_snapshot   # NETGEAR设备

# 检查root权限
if [ "$USER" != "root" ] && [ -z "$systype" ]; then
    while true; do
        double_line_break
        separator_line "="
        content_line "当前用户 $USER 非 root 用户"
        content_line "\033[33m请尽量使用 root 用户（不要直接使用sudo命令）执行安装！\033[0m"
        content_line "\033[31m继续安装，可能会产生未知错误！\033[0m"
        separator_line "-"
        content_line "1) 继续安装"
        content_line "E) 退出安装"
        separator_line "="
        read -p "请输入相应数字> " num
        case "$num" in
        1)
            break 1
            ;;
        "E" | "e")
            abort_install
            ;;
        *)
            invalid_input_retry
            continue
            ;;
        esac
    done
fi

if [ -n "$(echo "$url" | grep master)" ]; then
    setversion
fi

# 获取版本信息
webget /tmp/version "$url/version" echooff
[ "$result" = "200" ] && versionsh=$(cat /tmp/version)
rm -rf /tmp/version

# 输出
double_line_break
separator_line "="
content_line "最新版本：\033[32m$versionsh\033[0m"
separator_line "="

if [ -n "$CRASHDIR" ]; then
    while true; do
        double_line_break
        separator_line "="
        content_line "检测到旧版本安装目录：\033[36m$CRASHDIR\033[0m"
        content_line "\033[33m注意：覆盖安装时不会移除配置文件！\033[0m"
        separator_line "-"
        content_line "1) 覆盖安装"
        content_line "2) 卸载旧版本"
        content_line "E) 退出安装"
        separator_line "="
        read -p "请输入相应数字> " num
        case "$num" in
        1)
            install
            break 1
            ;;
        2)
            rm -rf "$CRASHDIR"

            double_line_break
            separator_line "="
            content_line "\033[31m旧版本文件已卸载！\033[0m"
            separator_line "="

            setdir
            install

            break 1
            ;;
        9)
            double_line_break
            separator_line "="
            content_line "测试模式，变更安装位置"
            separator_line "="

            setdir
            install

            break 1
            ;;
        "E" | "e")
            abort_install
            ;;
        *)
            invalid_input_retry
            continue
            ;;
        esac
    done
else
    setdir
    install
fi
