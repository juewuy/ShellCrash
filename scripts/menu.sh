#!/bin/sh
# Copyright (C) Juewuy

CRASHDIR=$(
    cd $(dirname $0)
    pwd
)
CFG_PATH="$CRASHDIR"/configs/ShellCrash.cfg
YAMLSDIR="$CRASHDIR"/yamls
JSONSDIR="$CRASHDIR"/jsons
#加载执行目录，失败则初始化
. "$CRASHDIR"/configs/command.env 2>/dev/null
[ -z "$BINDIR" -o -z "$TMPDIR" -o -z "$COMMAND" ] && . "$CRASHDIR"/init.sh >/dev/null 2>&1
[ ! -f "$TMPDIR" ] && mkdir -p "$TMPDIR"
[ -n "$(tar --help 2>&1 | grep -o 'no-same-owner')" ] && tar_para='--no-same-owner' #tar命令兼容

#加载工具
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/check_cmd.sh
errornum() {
    echo "-----------------------------------------------"
    echo -e "\033[31m请输入正确的字母或数字！\033[0m"
}
checkrestart() {
    echo "-----------------------------------------------"
    echo -e "\033[32m检测到已变更的内容，请重启服务！\033[0m"
    echo "-----------------------------------------------"
    read -p "是否现在重启服务？(1/0) > " res
    [ "$res" = 1 ] && start_service
}
checkport() { #自动检查端口冲突
    for portx in $dns_port $mix_port $redir_port $((redir_port + 1)) $db_port; do
        if [ -n "$(netstat -ntul 2>&1 | grep ':$portx ')" ]; then
            echo "-----------------------------------------------"
            echo -e "检测到端口【$portx】被以下进程占用！内核可能无法正常启动！\033[33m"
            echo $(netstat -ntul | grep :$portx | head -n 1)
            echo -e "\033[0m-----------------------------------------------"
            echo -e "\033[36m请修改默认端口配置！\033[0m"
            setport
            . "$CFG_PATH" >/dev/null
            checkport
        fi
    done
}
#脚本启动前检查
ckstatus() {
    #检查/读取脚本配置文件
    if [ -f "$CFG_PATH" ]; then
        [ -n "$(awk 'a[$0]++' $CFG_PATH)" ] && awk '!a[$0]++' "$CFG_PATH" >"$CFG_PATH" #检查重复行并去除
        . "$CFG_PATH" 2>/dev/null
    else
        . "$CRASHDIR"/init.sh >/dev/null 2>&1
    fi
    versionsh=$(cat "$CRASHDIR"/init.sh | grep -E ^version= | head -n 1 | sed 's/version=//')
    [ -n "$versionsh" ] && versionsh_l=$versionsh
    #服务器缺省地址
    [ -z "$mix_port" ] && mix_port=7890
    [ -z "$redir_port" ] && redir_port=7892
    [ -z "$fwmark" ] && fwmark=$redir_port
    [ -z "$db_port" ] && db_port=9999
    [ -z "$dns_port" ] && dns_port=1053
    [ -z "$multiport" ] && multiport='22,80,143,194,443,465,587,853,993,995,5222,8080,8443'
    [ -z "$redir_mod" ] && redir_mod=纯净模式
    #检查mac地址记录
    [ ! -f "$CRASHDIR"/configs/mac ] && touch "$CRASHDIR"/configs/mac
    #获取本机host地址
    [ -z "$host" ] && host=$(ubus call network.interface.lan status 2>&1 | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    [ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep 'lan' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
    [ -z "$host" ] && host=$(ip a 2>&1 | grep -w 'inet' | grep 'global' | grep -E ' 1(92|0|72)\.' | sed 's/.*inet.//g' | sed 's/\/[0-9][0-9].*$//g' | head -n 1)
    [ -z "$host" ] && host='设备IP地址'
    #dashboard目录位置
    if [ -f /www/clash/index.html ]; then
        dbdir=/www/clash
        hostdir=/clash
    else
        dbdir="$CRASHDIR"/ui
        hostdir=":$db_port/ui"
    fi
    #开机自启检测
    if [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
        [ -n "$(find /etc/rc.d -name '*shellcrash')" ] && autostart=enable || autostart=disable
    elif ckcmd systemctl; then
        [ "$(systemctl is-enabled shellcrash.service 2>&1)" = enabled ] && autostart=enable || autostart=disable
	elif grep -q 's6' /proc/1/comm; then
		[ -f /etc/s6-overlay/s6-rc.d/user/contents.d/afstart ] && autostart=enable || autostart=disable
    elif rc-status -r >/dev/null 2>&1; then
        rc-update show default | grep -q "shellcrash" && autostart=enable || autostart=disable
    else
        [ -f "$CRASHDIR"/.dis_startup ] && autostart=disable || autostart=enable
    fi
    #开机自启描述
    if [ "$autostart" = "enable" ]; then
        auto="\033[32m已设置开机启动！\033[0m"
        auto1="\033[36m禁用\033[0mShellCrash开机启动"
    else
        auto="\033[31m未设置开机启动！\033[0m"
        auto1="\033[36m允许\033[0mShellCrash开机启动"
    fi
    #获取运行状态
    PID=$(pidof CrashCore | awk '{print $NF}')
    if [ -n "$PID" ]; then
        run="\033[32m正在运行（$redir_mod）\033[0m"
        VmRSS=$(cat /proc/$PID/status | grep -w VmRSS | awk 'unit="MB" {printf "%.2f %s\n", $2/1000, unit}')
        #获取运行时长
        touch "$TMPDIR"/crash_start_time #用于延迟启动的校验
        start_time=$(cat "$TMPDIR"/crash_start_time)
        if [ -n "$start_time" ]; then
            time=$(($(date +%s) - start_time))
            day=$((time / 86400))
            [ "$day" = "0" ] && day='' || day="$day天"
            time=$(date -u -d @${time} +%H小时%M分%S秒)
        fi
    elif [ "$firewall_area" = 5 ] && [ -n "$(ip route list table 100)" ]; then
        run="\033[32m已设置（$redir_mod）\033[0m"
    else
        run="\033[31m没有运行（$redir_mod）\033[0m"
        #检测系统端口占用
        checkport
    fi
    corename=$(echo $crashcore | sed 's/singboxr/SingBoxR/' | sed 's/singbox/SingBox/' | sed 's/clash/Clash/' | sed 's/meta/Mihomo/')
    [ "$firewall_area" = 5 ] && corename='转发'
    [ -f "$TMPDIR"/debug.log -o -f "$CRASHDIR"/debug.log -a -n "$PID" ] && auto="\033[33m并处于debug状态！\033[0m"
    #输出状态
    echo "-----------------------------------------------"
    echo -e "\033[30;46m欢迎使用ShellCrash！\033[0m		版本：$versionsh_l"
    echo -e "$corename服务"$run"，"$auto""
    if [ -n "$PID" ]; then
        echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
    fi
    echo -e "TG频道：\033[36;4mhttps://t.me/ShellClash\033[0m"
    echo "-----------------------------------------------"
    #检查新手引导
    if [ -z "$userguide" ]; then
        setconfig userguide 1
        . "$CRASHDIR"/webget.sh && userguide
    fi
    #检查执行权限
    [ ! -x "$CRASHDIR"/start.sh ] && chmod +x "$CRASHDIR"/start.sh
    #检查/tmp内核文件
    for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -Ev ".*(gz|zip|7z|tar)$" | grep -iE 'CrashCore|^clash$|^clash-linux.*|^mihomo.*|^sing.*box|meta.*'); do
        chmod +x /tmp/$file
        echo -e "发现可用的内核文件： \033[36m/tmp/$file\033[0m "
        read -p "是否加载(会停止当前服务)？(1/0) > " res
        [ "$res" = 1 ] && {
            "$CRASHDIR"/start.sh stop
            core_v=$(/tmp/$file -v 2>/dev/null | head -n 1 | sed 's/ linux.*//;s/.* //')
            [ -z "$core_v" ] && core_v=$(/tmp/$file version 2>/dev/null | grep -Eo 'version .*' | sed 's/version //')
            if [ -n "$core_v" ]; then
                . "$CRASHDIR"/webget.sh && setcoretype &&
                    mv -f /tmp/$file "$TMPDIR"/CrashCore &&
                    tar -zcf "$BINDIR"/CrashCore.tar.gz ${tar_para} -C "$TMPDIR" CrashCore &&
                    echo -e "\033[32m内核加载完成！\033[0m " &&
                    setconfig crashcore $crashcore &&
                    setconfig core_v $core_v &&
                    switch_core
                sleep 1
            else
                echo -e "\033[33m检测到不可用的内核文件！可能是文件受损或CPU架构不匹配！\033[0m"
                rm -rf /tmp/$file
                echo -e "\033[33m内核文件已移除，请认真检查后重新上传！\033[0m"
                sleep 2
            fi
        }
        echo "-----------------------------------------------"
    done
    #检查/tmp配置文件
    for file in $(ls /tmp | grep -v [/$] | grep -v ' ' | grep -iE '.yaml$|.yml$|config.json$'); do
        tmp_file=/tmp/$file
        echo -e "发现内核配置文件： \033[36m/tmp/$file\033[0m "
        read -p "是否加载为$crashcore的配置文件？(1/0) > " res
        [ "$res" = 1 ] && {
            if [ -n "$(echo /tmp/$file | grep -iE '.json$')" ]; then
                mv -f /tmp/$file "$CRASHDIR"/jsons/config.json
            else
                mv -f /tmp/$file "$CRASHDIR"/yamls/config.yaml
            fi
            echo -e "\033[32m配置文件加载完成！\033[0m "
            sleep 1
        }
    done
    #检查禁用配置覆写
    [ "$disoverride" = "1" ] && {
        echo -e "\033[33m你已经禁用了配置文件覆写功能，这会导致大量脚本功能无法使用！\033[0m "
        read -p "是否取消禁用？(1/0) > " res
        [ "$res" = 1 ] && unset disoverride && setconfig disoverride
        echo "-----------------------------------------------"
    }
}
#启动相关
startover() {
    echo -ne "                                   \r"
    echo -e "\033[32m服务已启动！\033[0m"
    echo -e "请使用 \033[4;36mhttp://$host$hostdir\033[0m 管理内置规则"
    if [ "$redir_mod" = "纯净模式" ]; then
        echo "-----------------------------------------------"
        echo -e "其他设备可以使用PAC配置连接：\033[4;32mhttp://$host:$db_port/ui/pac\033[0m"
        echo -e "或者使用HTTP/SOCK5方式连接：IP{\033[36m$host\033[0m}端口{\033[36m$mix_port\033[0m}"
    fi
    return 0
}
start_core() {
    if echo "$crashcore" | grep -q 'singbox'; then
        core_config="$CRASHDIR"/jsons/config.json
    else
        core_config="$CRASHDIR"/yamls/config.yaml
    fi
    echo "-----------------------------------------------"
    if [ ! -s $core_config -a -s "$CRASHDIR"/configs/providers.cfg ]; then
        echo -e "\033[33m没有找到${crashcore}配置文件，尝试生成providers配置文件！\033[0m"
        [ "$crashcore" = singboxr ] && coretype=singbox
        [ "$crashcore" = meta -o "$crashcore" = clashpre ] && coretype=clash
        . "$CRASHDIR"/webget.sh && gen_${coretype}_providers
    elif [ -s $core_config -o -n "$Url" -o -n "$Https" ]; then
        "$CRASHDIR"/start.sh start
        #设置循环检测以判定服务启动是否成功
        i=1
        while [ -z "$test" -a "$i" -lt 30 ]; do
            sleep 1
            if curl --version >/dev/null 2>&1; then
                test=$(curl -s -H "Authorization: Bearer $secret" http://127.0.0.1:${db_port}/configs | grep -o port)
            else
                test=$(wget -q --header="Authorization: Bearer $secret" -O - http://127.0.0.1:${db_port}/configs | grep -o port)
            fi
            i=$((i + 1))
        done
        [ -n "$test" -o -n "$(pidof CrashCore)" ] && startover
    else
        echo -e "\033[31m没有找到${crashcore}配置文件，请先导入配置文件！\033[0m"
        . "$CRASHDIR"/webget.sh && set_core_config
    fi
}
start_service() {
    if [ "$firewall_area" = 5 ]; then
        "$CRASHDIR"/start.sh start
        echo -e "\033[32m已完成防火墙设置！\033[0m"
    else
        start_core
    fi
}
#卸载
uninstall() {
    read -p "确认卸载ShellCrash？(警告：该操作不可逆！)[1/0] > " res
    if [ "$res" = '1' ]; then
        #停止服务
        "$CRASHDIR"/start.sh stop 2>/dev/null
        "$CRASHDIR"/start.sh cronset "clash服务" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "订阅链接" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "ShellCrash初始化" 2>/dev/null
        "$CRASHDIR"/start.sh cronset "task.sh" 2>/dev/null
        #移除安装目录
        if [ -n "$CRASHDIR" ] && [ "$CRASHDIR" != '/' ]; then
            read -p "是否保留脚本配置及订阅文件？[1/0] > " res
            if [ "$res" = '1' ]; then
                mv -f "$CRASHDIR"/configs /tmp/ShellCrash/configs_bak
                mv -f "$CRASHDIR"/yamls /tmp/ShellCrash/yamls_bak
                mv -f "$CRASHDIR"/jsons /tmp/ShellCrash/jsons_bak
                rm -rf "$CRASHDIR"/*
                mv -f /tmp/ShellCrash/configs_bak "$CRASHDIR"/configs
                mv -f /tmp/ShellCrash/yamls_bak "$CRASHDIR"/yamls
                mv -f /tmp/ShellCrash/jsons_bak "$CRASHDIR"/jsons
            else
                rm -rf "$CRASHDIR"
            fi
        else
            echo -e "\033[31m环境变量配置有误，请尝试手动移除安装目录！\033[0m"
            sleep 1
        fi
        #移除其他内容
        [ -w ~/.bashrc ] && profile=~/.bashrc
        [ -w /etc/profile ] && profile=/etc/profile
        sed -i "/alias $my_alias=*/"d $profile
        sed -i '/alias crash=*/'d $profile
        sed -i '/export CRASHDIR=*/'d $profile
        sed -i '/export crashdir=*/'d $profile
        [ -w ~/.zshrc ] && {
            sed -i "/alias $my_alias=*/"d ~/.zshrc
            sed -i '/export CRASHDIR=*/'d ~/.zshrc
        }
        sed -i '/all_proxy/'d $profile
        sed -i '/ALL_PROXY/'d $profile
        sed -i "/启用外网访问SSH服务/d" /etc/firewall.user 2>/dev/null
        sed -i '/ShellCrash初始化/'d /etc/storage/started_script.sh 2>/dev/null
        sed -i '/ShellCrash初始化/'d /jffs/.asusrouter 2>/dev/null
        [ "$BINDIR" != "$CRASHDIR" ] && rm -rf "$BINDIR"
        rm -rf /etc/init.d/shellcrash
        rm -rf /etc/systemd/system/shellcrash.service
        rm -rf /usr/lib/systemd/system/shellcrash.service
        rm -rf /www/clash
        rm -rf /tmp/ShellCrash
        rm -rf /usr/bin/crash
        sed -i '/0:7890/d' /etc/passwd
        userdel -r shellcrash 2>/dev/null
        nvram set script_usbmount="" 2>/dev/null
        nvram commit 2>/dev/null
        uci delete firewall.ShellCrash 2>/dev/null
        uci commit firewall 2>/dev/null
        echo "-----------------------------------------------"
        echo -e "\033[36m已卸载ShellCrash相关文件！有缘再会！\033[0m"
        echo -e "\033[33m请手动关闭当前窗口以重置环境变量！\033[0m"
        echo "-----------------------------------------------"
        exit
    else
        echo -e "\033[31m操作已取消！\033[0m"
    fi
}
#主菜单
main_menu() {
    #############################
    ckstatus
    #############################
    echo -e " 1 \033[32m启动/重启服务\033[0m"
    echo -e " 2 \033[36m功能设置\033[0m"
    echo -e " 3 \033[31m停止服务\033[0m"
    echo -e " 4 \033[33m启动设置\033[0m"
    echo -e " 5 设置\033[32m自动任务\033[0m"
    echo -e " 6 管理\033[36m配置文件\033[0m"
    echo -e " 7 \033[33m访问与控制\033[0m"
    echo -e " 8 \033[0m工具与优化\033[0m"
    echo -e " 9 \033[32m更新与支持\033[0m"
    echo "-----------------------------------------------"
    echo -e " 0 \033[0m退出脚本\033[0m"
    read -p "请输入对应数字 > " num

    case "$num" in
    0)
        exit
	;;
    1)
        start_service
        exit
	;;
    2)
        checkcfg=$(cat "$CFG_PATH")
        . "$CRASHDIR"/menus/settings.sh && settings
        if [ -n "$PID" ]; then
            checkcfg_new=$(cat "$CFG_PATH")
            [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
        fi
        main_menu
	;;
    3)
        "$CRASHDIR"/start.sh stop
        sleep 1
        echo "-----------------------------------------------"
        echo -e "\033[31m$corename服务已停止！\033[0m"
        main_menu
	;;
    4)
        . "$CRASHDIR"/menus/setboot.sh && setboot
        main_menu
	;;
    5)
        . "$CRASHDIR"/menus/task.sh && task_menu
        main_menu
	;;
    6)
        . "$CRASHDIR"/menus/core_config.sh && set_core_config
        main_menu
	;;
    7)
		GT_CFG_PATH="$CRASHDIR"/configs/gateway.cfg
		touch "$GT_CFG_PATH"
        checkcfg=$(cat $GT_CFG_PATH)
        . "$CRASHDIR"/menus/gateway.sh && gateway
        if [ -n "$PID" ]; then
            checkcfg_new=$(cat $GT_CFG_PATH)
            [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
        fi
        main_menu
	;;
    8)
        . "$CRASHDIR"/menus/tools.sh && tools
        main_menu
	;;
    9)
        checkcfg=$(cat "$CFG_PATH")
        . "$CRASHDIR"/menus/upgrade.sh && upgrade
        if [ -n "$PID" ]; then
            checkcfg_new=$(cat "$CFG_PATH")
            [ "$checkcfg" != "$checkcfg_new" ] && checkrestart
        fi
        main_menu
	;;
    *)
        errornum
        exit
	;;
    esac
}

[ -z "$CRASHDIR" ] && {
    echo "环境变量配置有误！正在初始化~~~"
    CRASHDIR=$(
        cd $(dirname $0)
        pwd
    )
    . "$CRASHDIR"/init.sh
    sleep 1
    echo "请重启SSH窗口以完成初始化！"
    exit
}

[ -z "$1" ] && main_menu

case "$1" in
-h)
    echo -----------------------------------------
    echo "欢迎使用ShellCrash"
    echo -----------------------------------------
    echo "	-t 测试模式"
    echo "	-h 帮助列表"
    echo "	-u 卸载脚本"
    echo "	-i 初始化脚本"
    echo "	-d 测试运行"
    echo -----------------------------------------
    echo "	crash -s start	启动服务"
    echo "	crash -s stop	停止服务"
    echo "	安装目录/start.sh init		开机初始化"
    echo -----------------------------------------
    echo "在线求助：t.me/ShellClash"
    echo "官方博客：juewuy.github.io"
    echo "发布页面：github.com/juewuy/ShellCrash"
    echo -----------------------------------------
    ;;
-t)
    shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
    $shtype -x "$CRASHDIR"/menu.sh
    ;;
-s)
    "$CRASHDIR"/start.sh $2 $3 $4 $5 $6
    ;;
-i)
    . "$CRASHDIR"/init.sh
    ;;
-st)
    shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
    $shtype -x "$CRASHDIR"/start.sh $2 $3 $4 $5 $6
    ;;
-d)
    shtype=sh && [ -n "$(ls -l /bin/sh | grep -o dash)" ] && shtype=bash
    echo -e "正在测试运行！如发现错误请截图后前往\033[32;4mt.me/ShellClash\033[0m咨询"
    $shtype "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh_bug.log
    $shtype -x "$CRASHDIR"/start.sh debug >/dev/null 2>"$TMPDIR"/debug_sh.log
    echo -----------------------------------------
    cat "$TMPDIR"/debug_sh_bug.log | grep 'start\.sh' >"$TMPDIR"/sh_bug
    if [ -s "$TMPDIR"/sh_bug ]; then
        while read line; do
            echo -e "发现错误：\033[33;4m$line\033[0m"
            grep -A 1 -B 3 "$line" "$TMPDIR"/debug_sh.log
            echo -----------------------------------------
        done <"$TMPDIR"/sh_bug
        rm -rf "$TMPDIR"/sh_bug
        echo -e "\033[32m测试完成！\033[0m完整执行记录请查看：\033[36m$TMPDIR/debug_sh.log\033[0m"
    else
        echo -e "\033[32m测试完成！没有发现问题，请重新启动服务~\033[0m"
        rm -rf "$TMPDIR"/debug_sh.log
    fi
    "$CRASHDIR"/start.sh stop
    ;;
-u)
    uninstall
    ;;
*)
    $0 -h
    ;;
esac
