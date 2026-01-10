#!/usr/bin/env bash
# Copyright (C) Juewuy

[ -z "$url" ] && url="https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@dev"
type bash &>/dev/null && shtype=bash || shtype=sh
[ -n "$(echo -e | grep e)" ] && echo=echo || echo='echo -e'
echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**                ShellCrash                 **"
echo "**                             by  Juewuy    **"
echo "***********************************************"

# Check available capacity
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
        result=$(curl -w %{http_code} --connect-timeout 5 $progress $redirect -ko $1 $2)
        [ -n "$(echo $result | grep -e ^2)" ] && result="200"
    else
        if wget --version >/dev/null 2>&1; then
            [ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
            [ "$4" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
            certificate='--no-check-certificate'
            timeout='--timeout=3'
        fi
        [ "$3" = "echoon" ] && progress=''
        [ "$3" = "echooff" ] && progress='-q'
        wget $progress $redirect $certificate $timeout -O $1 $2
        [ $? -eq 0 ] && result="200"
    fi
}

error_down() {
    $echo "请参考 \033[32mhttps://github.com/juewuy/ShellCrash/blob/master/README_CN.md"
    $echo "\033[33m使用其他安装源重新安装！\033[0m"
}

# 安装及初始化
set_alias() {
    while true; do
        echo "-----------------------------------------------"
        $echo "\033[36m请选择一个别名，或使用自定义别名：\033[0m"
        echo "-----------------------------------------------"
        $echo " 1 【\033[32mcrash\033[0m】"
        $echo " 2 【\033[32m sc \033[0m】"
        $echo " 3 【\033[32m mm \033[0m】"
        $echo " 0 退出安装"
        echo "-----------------------------------------------"
        read -p "请输入相应数字或自定义别名 > " res
        case "$res" in
        0)
            echo "安装已取消"
            exit 1
            ;;
        1)
            my_alias=crash
            ;;
        2)
            my_alias=sc
            ;;
        3)
            my_alias=mm
            ;;
        *)
            my_alias=$res
            ;;
        esac
        cmd=$(ckcmd "$my_alias" | grep 'menu.sh')
        ckcmd "$my_alias" && [ -z "$cmd" ] && {
            $echo "\033[33m此别名和当前系统内置命令/别名冲突，请换一个！\033[0m"
            sleep 1
            continue
        }
        break
    done
}

gettar() {
    webget /tmp/ShellCrash.tar.gz "$url/ShellCrash.tar.gz"
    if [ "$result" != "200" ]; then
        $echo "\033[33m文件下载失败！\033[0m"
        error_down
        exit 1
    else
        $CRASHDIR/start.sh stop 2>/dev/null
        # 解压
        echo "-----------------------------------------------"
        echo "开始解压文件！"
        mkdir -p $CRASHDIR >/dev/null
        tar -zxf '/tmp/ShellCrash.tar.gz' -C $CRASHDIR/ || tar -zxf '/tmp/ShellCrash.tar.gz' --no-same-owner -C $CRASHDIR/
        if [ -s $CRASHDIR/init.sh ]; then
            set_alias
            . $CRASHDIR/init.sh >/dev/null
            [ "$?" != 0 ] && $echo "\033[33m初始化失败，请尝试本地安装！\033[0m" && exit 1
        else
            rm -rf /tmp/ShellCrash.tar.gz
            $echo "\033[33m文件解压失败！\033[0m"
            error_down
            exit 1
        fi
    fi
}

set_usb_dir() {
    while true; do
        $echo "请选择安装目录"
        du -hL /mnt | awk '{print " "NR" "$2"  "$1}'
        read -p "请输入相应数字 > " num
        dir=$(du -hL /mnt | awk '{print $2}' | sed -n "$num"p)
        if [ -z "$dir" ]; then
            $echo "\033[31m输入错误！请重新设置！\033[0m"
            continue
        fi
        break 1
    done
}

set_asus_dir() {
    while true; do
        echo -e "请选择U盘目录"
        du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print " "NR" "$2"  "$1}'
        read -p "请输入相应数字 > " num
        dir=$(du -hL /tmp/mnt | awk -F/ 'NF<=4' | awk '{print $2}' | sed -n "$num"p)
        if [ ! -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ]; then
            echo -e "\033[31m未找到下载大师自启文件：$dir/asusware.arm/etc/init.d/S50downloadmaster，请检查设置！\033[0m"
            continue
        fi
        break 1
    done
}

set_cust_dir() {
    while true; do
        echo "-----------------------------------------------"
        echo '可用路径 剩余空间：'
        df -h | awk '{print $6,$4}' | sed 1d
        echo '路径是必须带 / 的格式，注意写入虚拟内存(/tmp,/opt,/sys...)的文件会在重启后消失！！！'
        read -p "请输入自定义路径 > " dir
        if [ "$(dir_avail $dir)" = 0 ] || [ -n "$(echo $dir | grep -E 'tmp|opt|sys')" ]; then
            $echo "\033[31m路径错误！请重新设置！\033[0m"
            continue
        fi
        break 1
    done
}

setdir() {
    while true; do
        echo "-----------------------------------------------"
        $echo "\033[33m注意：安装ShellCrash至少需要预留约1MB的磁盘空间\033[0m"
        if [ -n "$systype" ]; then
            [ "$systype" = "Padavan" ] && dir=/etc/storage
            [ "$systype" = "mi_snapshot" ] && {
                $echo "\033[33m检测到当前设备为小米官方系统，请选择安装位置\033[0m"
                [ -d /data ] && $echo " 1 安装到 /data 目录,剩余空间：$(dir_avail /data -h)(支持软固化功能)"
                [ -d /userdisk ] && $echo " 2 安装到 /userdisk 目录,剩余空间：$(dir_avail /userdisk -h)(支持软固化功能)"
                [ -d /data/other_vol ] && $echo " 3 安装到 /data/other_vol 目录,剩余空间：$(dir_avail /data/other_vol -h)(支持软固化功能)"
                $echo " 4 安装到自定义目录(不推荐，不明勿用！)"
                $echo " 0 退出安装"
                echo "-----------------------------------------------"
                read -p "请输入相应数字 > " num
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
                    ;;
                *)
                    exit 1
                    ;;
                esac
            }
            [ "$systype" = "asusrouter" ] && {
                $echo "\033[33m检测到当前设备为华硕固件，请选择安装方式\033[0m"
                $echo " 1 基于USB设备安装(限23年9月之前固件，须插入\033[31m任意\033[0mUSB设备)"
                $echo " 2 基于自启脚本安装(仅支持梅林及部分非koolshare官改固件)"
                $echo " 3 基于U盘+下载大师安装(支持所有固件，限ARM设备，须插入U盘或移动硬盘)"
                $echo " 0 退出安装"
                echo "-----------------------------------------------"
                read -p "请输入相应数字 > " num
                case "$num" in
                1)
                    read -p "将脚本安装到USB存储/系统闪存？(1/0) > " res
                    [ "$res" = "1" ] && set_usb_dir || dir=/jffs
                    usb_status=1
                    ;;
                2)
                    $echo "如无法正常开机启动，请重新使用USB方式安装！"
                    sleep 2
                    dir=/jffs
                    ;;
                3)
                    echo -e "请先在路由器网页后台安装下载大师并启用，之后选择外置存储所在目录！"
                    sleep 2
                    set_asus_dir
                    ;;
                *)
                    exit 1
                    ;;
                esac
            }
            [ "$systype" = "ng_snapshot" ] && dir=/tmp/mnt
        else
            $echo " 1 在\033[32m/etc目录\033[0m下安装(适合root用户)"
            $echo " 2 在\033[32m/usr/share目录\033[0m下安装(适合Linux系统)"
            $echo " 3 在\033[32m当前用户目录\033[0m下安装(适合非root用户)"
            $echo " 4 在\033[32m外置存储\033[0m中安装"
            $echo " 5 手动设置安装目录"
            $echo " 0 退出安装"
            echo "----------------------------------------------"
            read -p "请输入相应数字 > " num
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
                ;;
            5)
                set_cust_dir
                ;;
            *)
                echo "安装已取消"
                exit 1
                ;;
            esac
        fi

        if [ ! -w $dir ]; then
            $echo "\033[31m没有$dir目录写入权限！请重新设置！\033[0m"
            sleep 1
        else
            $echo "目标目录\033[32m$dir\033[0m空间剩余：$(dir_avail $dir -h)"
            read -p "确认安装？(1/0) > " res
            if [ "$res" = "1" ]; then
                CRASHDIR=$dir/ShellCrash
                break
            fi
        fi
    done
}

install() {
    echo "-----------------------------------------------"
    echo "开始从服务器获取安装文件！"
    echo "-----------------------------------------------"
    gettar
    echo "-----------------------------------------------"
    echo "ShellCrash 已经安装成功!"
    [ "$profile" = "~/.bashrc" ] && echo "请执行【. ~/.bashrc > /dev/null】命令以更新环境变量！"
    [ -n "$(ls -l /bin/sh | grep -oE 'zsh')" ] && echo "请执行【. ~/.zshrc > /dev/null】命令以更新环境变量！"
    echo "-----------------------------------------------"
    $echo "\033[33m输入\033[30;47m $my_alias \033[0;33m命令即可管理！！！\033[0m"
    echo "-----------------------------------------------"
}

setversion() {
    echo "-----------------------------------------------"
    $echo "\033[33m请选择想要安装的版本：\033[0m"
    $echo " 1 \033[32m公测版(推荐)\033[0m"
    $echo " 2 \033[36m稳定版\033[0m"
    $echo " 3 \033[31m开发版\033[0m"
    echo "-----------------------------------------------"
    read -p "请输入相应数字 > " num
    case "$num" in
    2)
        url=$(echo $url | sed 's/master/stable/')
        ;;
    3)
        url=$(echo $url | sed 's/master/dev/')
        ;;
    *) ;;
    esac
}

# 特殊固件识别及标记
[ -f "/etc/storage/started_script.sh" ] && {
    systype=Padavan #老毛子固件
    initdir='/etc/storage/started_script.sh'
}
[ -d "/jffs" ] && {
    systype=asusrouter #华硕固件
    [ -f "/jffs/.asusrouter" ] && initdir='/jffs/.asusrouter'
    [ -d "/jffs/scripts" ] && initdir='/jffs/scripts/nat-start'
}
[ -f "/data/etc/crontabs/root" ] && systype=mi_snapshot #小米设备
[ -w "/var/mnt/cfg/firewall" ] && systype=ng_snapshot   #NETGEAR设备

# 检查root权限
if [ "$USER" != "root" -a -z "$systype" ]; then
    echo "当前用户:$USER"
    $echo "\033[31m请尽量使用root用户（不要直接使用sudo命令！）执行安装!\033[0m"
    echo "-----------------------------------------------"
    read -p "仍要安装？可能会产生未知错误！(1/0) > " res
    [ "$res" != "1" ] && exit 1
fi

if [ -n "$(echo $url | grep master)" ]; then
    setversion
fi

# 获取版本信息
webget /tmp/version "$url/version" echooff
[ "$result" = "200" ] && versionsh=$(cat /tmp/version)
rm -rf /tmp/version

# 输出
$echo "最新版本：\033[32m$versionsh\033[0m"
echo "-----------------------------------------------"
$echo "\033[44m如遇问题请加TG群反馈：\033[42;30m t.me/ShellClash \033[0m"
$echo "\033[37m支持各种基于openwrt的路由器设备"
$echo "\033[33m支持Debian、Centos等标准Linux系统\033[0m"

if [ -n "$CRASHDIR" ]; then
    echo "-----------------------------------------------"
    $echo "检测到旧的安装目录\033[36m$CRASHDIR\033[0m，是否覆盖安装？"
    $echo "\033[32m覆盖安装时不会移除配置文件！\033[0m"
    read -p "覆盖安装/卸载旧版本？(1/0) > " res
    case "$res" in
    1)
        install
        ;;
    0)
        rm -rf $CRASHDIR
        echo "-----------------------------------------------"
        $echo "\033[31m 旧版本文件已卸载！\033[0m"
        setdir
        install
        ;;
    9)
        echo "测试模式，变更安装位置"
        setdir
        install
        ;;
    *)
        $echo "\033[31m输入错误！已取消安装！\033[0m"
        exit 1
        ;;
    esac
else
    setdir
    install
fi
