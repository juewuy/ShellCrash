#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_OVERRIDE" ] && return
__IS_MODULE_OVERRIDE=1

# 配置文件覆写
override() {
    while true; do
        [ -z "$rule_link" ] && rule_link=1
        [ -z "$server_link" ] && server_link=1
        echo "-----------------------------------------------"
        echo -e "\033[30;47m 欢迎使用配置文件覆写功能！\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 自定义\033[32m端口及秘钥\033[0m"
        echo -e " 2 管理\033[36m自定义规则\033[0m"
        echo "$crashcore" | grep -q 'singbox' || {
            echo -e " 3 管理\033[33m自定义节点\033[0m"
            echo -e " 4 管理\033[36m自定义策略组\033[0m"
        }
        echo -e " 5 \033[32m自定义\033[0m高级功能"
        [ "$disoverride" != 1 ] && echo -e " 9 \033[33m禁用\033[0m配置文件覆写"
        echo "-----------------------------------------------"
        [ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            if [ -n "$(pidof CrashCore)" ]; then
                echo "-----------------------------------------------"
                echo -e "\033[33m检测到服务正在运行，需要先停止服务！\033[0m"
                read -p "是否停止服务？(1/0) > " res
                if [ "$res" = "1" ]; then
                    "$CRASHDIR"/start.sh stop
                    setport
                fi
            else
                setport
            fi
            ;;
        2)
            setrules
            ;;
        3)
            setproxies
            ;;
        4)
            setgroups
            ;;
        5)
            echo "$crashcore" | grep -q 'singbox' && set_singbox_adv || set_clash_adv
            sleep 3
            ;;
        9)
            echo "-----------------------------------------------"
            echo -e "\033[33m此功能可能会导致严重问题！启用后脚本中大部分功能都将禁用！！！\033[0m"
            echo -e "如果你不是非常了解$crashcore的运行机制，切勿开启！\033[0m"
            echo -e "\033[33m继续后如出现任何问题，请务必自行解决，一切提问恕不受理！\033[0m"
            echo "-----------------------------------------------"
            sleep 2
            read -p "我确认遇到问题可以自行解决[1/0] > " res
            [ "$res" = '1' ] && {
                disoverride=1
                setconfig disoverride $disoverride
                echo "-----------------------------------------------"
                echo -e "\033[32m设置成功！\033[0m"
            }
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}

setrules() { # 自定义规则

    set_rule_type() {
        echo "-----------------------------------------------"
        echo -e "\033[33m请选择规则类型\033[0m"
        echo "$rule_type" | awk -F ' ' '{for(i=1;i<=NF;i++){print i" "$i}}'
        echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0) ;;
        [0-9]*)
            if [ "$num" -gt $(echo $rule_type | awk -F " " '{print NF}') ]; then
                errornum
                sleep 1
            else
                rule_type_set=$(echo "$rule_type" | cut -d' ' -f"$num")
                echo "-----------------------------------------------"
                echo -e "\033[33m请输入规则语句，可以是域名、泛域名、IP网段或者其他匹配规则类型的内容\033[0m"
                read -p "请输入对应规则 > " rule_state_set
                if [ -n "$rule_state_set" ]; then
                    set_group_type
                else
                    errornum
                    slepp 1
                fi
            fi
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    }

    set_group_type() {
        echo "-----------------------------------------------"
        echo -e "\033[36m请选择具体规则\033[0m"
        echo -e "\033[33m此处规则读取自现有配置文件，如果你后续更换配置文件时运行出错，请尝试重新添加\033[0m"
        echo "$rule_group" | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
        echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0) ;;
        [0-9]*)
            if [ "$num" -gt "$(echo "$rule_group" | awk -F "#" '{print NF}')" ]; then
                errornum
                sleep 1
            else
                rule_group_set=$(echo "$rule_group" | cut -d'#' -f"$num")
                rule_all="- ${rule_type_set},${rule_state_set},${rule_group_set}"
                echo "IP-CIDR SRC-IP-CIDR IP-CIDR6" | grep -q -- "$rule_type_set" && rule_all="${rule_all},no-resolve"

                echo "$rule_all" >>"$YAMLSDIR"/rules.yaml
                echo "-----------------------------------------------"
                echo -e "\033[32m添加成功！\033[0m"
            fi
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    }

    del_rule_type() {
        while true; do
            echo -e "输入对应数字即可移除相应规则:"
            sed -i '/^ *$/d; /^#/d' "$YAMLSDIR"/rules.yaml
            cat "$YAMLSDIR"/rules.yaml | grep -Ev '^#' | awk -F "#" '{print " "NR" "$1$2$3}'
            echo "-----------------------------------------------"
            echo -e " 0 返回上级菜单"
            read -p "请输入对应数字 > " num
            case "$num" in
            "" | 0)
                break
                ;;
            *)
                if [ "$num" -le "$(wc -l <"$YAMLSDIR"/rules.yaml)" ]; then
                    sed -i "${num}d" "$YAMLSDIR"/rules.yaml
                    sleep 1
                else
                    errornum
                    sleep 1
                    break
                fi
                ;;
            esac
        done
    }

    get_rule_group() {
        . "$CRASHDIR"/libs/web_save.sh
        get_save http://127.0.0.1:${db_port}/proxies | sed 's/:{/!/g' | awk -F '!' '{for(i=1;i<=NF;i++) print $i}' | grep -aE '"Selector|URLTest|LoadBalance"' | grep -aoE '"name":.*"now":".*",' | awk -F '"' '{print "#"$4}' | tr -d '\n'
    }

    while true; do
        echo "-----------------------------------------------"
        echo -e "\033[33m你可以在这里快捷管理自定义规则\033[0m"
        echo -e "如需批量操作，请手动编辑：\033[36m $YAMLSDIR/rules.yaml\033[0m"
        echo -e "\033[33msingbox和clash共用此处规则，可无缝切换！\033[0m"
        echo -e "大量规则请尽量使用rule-set功能添加，\033[31m此处过量添加可能导致启动卡顿！\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 新增自定义规则"
        echo -e " 2 移除自定义规则"
        echo -e " 3 清空规则列表"
        echo "$crashcore" | grep -q 'singbox' || echo -e " 4 配置节点绕过:	\033[36m$proxies_bypass\033[0m"
        echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            rule_type="DOMAIN-SUFFIX DOMAIN-KEYWORD IP-CIDR SRC-IP-CIDR DST-PORT SRC-PORT GEOIP GEOSITE IP-CIDR6 DOMAIN PROCESS-NAME"
            rule_group="DIRECT#REJECT$(get_rule_group)"
            set_rule_type
            ;;
        2)
            echo "-----------------------------------------------"
            if [ -s "$YAMLSDIR"/rules.yaml ]; then
                del_rule_type
            else
                echo -e "请先添加自定义规则！"
                sleep 1
            fi
            ;;
        3)
            read -p "确认清空全部自定义规则？(1/0) > " res
            [ "$res" = "1" ] && sed -i '/^\s*[^#]/d' "$YAMLSDIR"/rules.yaml
            ;;
        4)
            echo "-----------------------------------------------"
            if [ "$proxies_bypass" = "OFF" ]; then
                echo -e "\033[33m本功能会自动将当前配置文件中的节点域名或IP设置为直连规则以防止出现双重流量！\033[0m"
                echo -e "\033[33m请确保下游设备使用的节点与ShellCrash中使用的节点相同，否则无法生效！\033[0m"
                read -p "启用节点绕过？(1/0) > " res
                [ "$res" = "1" ] && proxies_bypass=ON
            else
                proxies_bypass=OFF
            fi
            setconfig proxies_bypass "$proxies_bypass"
            sleep 1
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}

setgroups() { # 自定义clash策略组
    set_group_type() {
        echo "-----------------------------------------------"
        echo -e "\033[33m注意策略组名称必须和【自定义规则】或【自定义节点】功能中指定的策略组一致！\033[0m"
        echo -e "\033[33m建议先创建策略组，之后可在【自定义规则】或【自定义节点】功能中智能指定\033[0m"
        echo -e "\033[33m如需在当前策略组下添加节点，请手动编辑$YAMLSDIR/proxy-groups.yaml\033[0m"
        read -r -p "请输入自定义策略组名称(不支持纯数字且不要包含特殊字符！) > " new_group_name

        echo "-----------------------------------------------"
        echo -e "\033[32m请选择策略组【$new_group_name】的类型！\033[0m"
        echo "$group_type_cn" | awk '{for(i=1;i<=NF;i++){print i" "$i}}'
        read -r -p "请输入对应数字 > " num
        new_group_type=$(echo "$group_type" | awk '{print $'"$num"'}')
        if [ "$num" = "1" ]; then
            unset new_group_url interval
        else
            read -r -p "请输入测速地址，回车则默认使用https://www.gstatic.com/generate_204 > " new_group_url
            [ -z "$new_group_url" ] && new_group_url=https://www.gstatic.com/generate_204
            new_group_url="url: '$new_group_url'"
            interval="interval: 300"
        fi
        set_group_add
        # 添加自定义策略组
        cat >>"$YAMLSDIR"/proxy-groups.yaml <<EOF
  - name: $new_group_name
    type: $new_group_type
    $new_group_url
    $interval
    proxies:
     - DIRECT
EOF
        sed -i "/^ *$/d" "$YAMLSDIR"/proxy-groups.yaml
        echo "-----------------------------------------------"
        echo -e "\033[32m添加成功！\033[0m"

    }

    set_group_add() {
        echo "-----------------------------------------------"
        echo -e "\033[36m请选择想要将本策略添加到的策略组\033[0m"
        echo -e "\033[32m如需添加到多个策略组，请一次性输入多个数字并用空格隔开\033[0m"
        echo "-----------------------------------------------"
        echo "$proxy_group" | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
        echo "-----------------------------------------------"
        echo -e " 0 跳过添加"
        read -r -p "请输入对应数字(多个用空格隔开) > " char
        case "$char" in
        "" | 0) ;;
        *)
            for num in $char; do
                rule_group_set=$(echo "$proxy_group" | cut -d'#' -f"$num")
                rule_group_add="${rule_group_add}#${rule_group_set}"
            done
            if [ -n "$rule_group_add" ]; then
                new_group_name="$new_group_name$rule_group_add"
                unset rule_group_add
            else
                errornum
                sleep 1
            fi
            ;;
        esac
    }

    while true; do
        echo "-----------------------------------------------"
        echo -e "\033[33m你可以在这里快捷管理自定义策略组\033[0m"
        echo -e "\033[36m如需修改或批量操作，请手动编辑：$YAMLSDIR/proxy-groups.yaml\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 添加自定义策略组"
        echo -e " 2 查看自定义策略组"
        echo -e " 3 清空自定义策略组"
        echo -e " 0 返回上级菜单"
        read -r -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            group_type="select url-test fallback load-balance"
            group_type_cn="手动选择 自动选择 故障转移 负载均衡"
            proxy_group="$(cat "$YAMLSDIR"/proxy-groups.yaml "$YAMLSDIR"/config.yaml 2>/dev/null | sed "/#自定义策略组开始/,/#自定义策略组结束/d" | grep -Ev '^#' | grep -o '\- name:.*' | sed 's/#.*//' | sed 's/- name: /#/g' | tr -d '\n' | sed 's/#//')"
            set_group_type
            ;;
        2)
            echo "-----------------------------------------------"
            cat "$YAMLSDIR"/proxy-groups.yaml
            ;;
        3)
            read -p "确认清空全部自定义策略组？(1/0) > " res
            [ "$res" = "1" ] && echo '#用于添加自定义策略组' >"$YAMLSDIR"/proxy-groups.yaml
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}

setproxies() { # 自定义clash节点
    set_proxy_type() {
        echo "-----------------------------------------------"
        echo -e "\033[33m注意节点格式必须是单行,不包括括号,name:必须写在最前,例如：\033[0m"
        echo -e "\033[36m【name: \"test\", server: 192.168.1.1, port: 12345, type: socks5, udp: true】\033[0m"
        echo -e "更多写法请参考：\033[32m https://juewuy.github.io/ \033[0m"
        read -r -p "请输入节点 > " proxy_state_set
        if echo "$proxy_state_set" | grep -q "#"; then
            echo -e "\033[33m绝对禁止包含【#】号！！！\033[0m"
        elif echo "$proxy_state_set" | grep -Eq "^name:"; then
            set_group_add
        else
            errornum
            sleep 1
        fi
    }

    set_group_add() {
        echo "-----------------------------------------------"
        echo -e "\033[36m请选择想要将节点添加到的策略组\033[0m"
        echo -e "\033[32m如需添加到多个策略组，请一次性输入多个数字并用空格隔开\033[0m"
        echo -e "\033[33m如需自定义策略组，请先使用【管理自定义策略组功能】添加\033[0m"
        echo "-----------------------------------------------"
        echo "$proxy_group" | awk -F '#' '{for(i=1;i<=NF;i++){print i" "$i}}'
        echo "-----------------------------------------------"
        echo -e " 0 返回上级菜单"
        read -r -p "请输入对应数字(多个用空格隔开) > " char
        case "$char" in
        "" | 0) ;;
        *)
            for num in $char; do
                rule_group_set=$(echo "$proxy_group" | cut -d'#' -f"$num")
                rule_group_add="${rule_group_add}#${rule_group_set}"
            done
            if [ -n "$rule_group_add" ]; then
                echo "- {$proxy_state_set}$rule_group_add" >>"$YAMLSDIR"/proxies.yaml
                echo "-----------------------------------------------"
                echo -e "\033[32m添加成功！\033[0m"
                unset rule_group_add
            else
                errornum
                sleep 1
            fi
            ;;
        esac
    }

    while true; do
        echo "-----------------------------------------------"
        echo -e "\033[33m你可以在这里快捷管理自定义节点\033[0m"
        echo -e "\033[36m如需批量操作，请手动编辑：$YAMLSDIR/proxies.yaml\033[0m"
        echo "-----------------------------------------------"
        echo -e " 1 添加自定义节点"
        echo -e " 2 管理自定义节点"
        echo -e " 3 清空自定义节点"
        echo -e " 4 配置节点绕过:	\033[36m$proxies_bypass\033[0m"
        echo -e " 0 返回上级菜单"
        read -r -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            proxy_type="DOMAIN-SUFFIX DOMAIN-KEYWORD IP-CIDR SRC-IP-CIDR DST-PORT SRC-PORT GEOIP GEOSITE IP-CIDR6 DOMAIN MATCH"
            proxy_group="$(cat "$YAMLSDIR"/proxy-groups.yaml "$YAMLSDIR"/config.yaml 2>/dev/null | sed "/#自定义策略组开始/,/#自定义策略组结束/d" | grep -Ev '^#' | grep -o '\- name:.*' | sed 's/#.*//' | sed 's/- name: /#/g' | tr -d '\n' | sed 's/#//')"
            set_proxy_type
            ;;
        2)
            echo "-----------------------------------------------"
            sed -i '/^ *$/d' "$YAMLSDIR"/proxies.yaml 2>/dev/null
            if [ -s "$YAMLSDIR"/proxies.yaml ]; then
                echo -e "当前已添加的自定义节点为:"
                cat "$YAMLSDIR"/proxies.yaml | grep -Ev '^#' | awk -F '[,,}]' '{print NR, $1, $NF}' | sed 's/- {//g'
                echo "-----------------------------------------------"
                echo -e "\033[33m输入节点对应数字可以移除对应节点\033[0m"
                read -r -p "请输入对应数字 > " num
                if [ "$num" -le $(cat "$YAMLSDIR"/proxies.yaml | grep -Ev '^#' | wc -l) ]; then
                    sed -i "$num{/^\s*[^#]/d}" "$YAMLSDIR"/proxies.yaml
                else
                    errornum
                fi
            else
                echo -e "请先添加自定义节点！"
                sleep 1
            fi
            ;;
        3)
            read -r -p "确认清空全部自定义节点？(1/0) > " res
            [ "$res" = "1" ] && sed -i '/^\s*[^#]/d' "$YAMLSDIR"/proxies.yaml 2>/dev/null
            ;;
        4)
            echo "-----------------------------------------------"
            if [ "$proxies_bypass" = "OFF" ]; then
                echo -e "\033[33m本功能会自动将当前配置文件中的节点域名或IP设置为直连规则以防止出现双重流量！\033[0m"
                echo -e "\033[33m请确保下游设备使用的节点与ShellCrash中使用的节点相同，否则无法生效！\033[0m"
                read -r -p "启用节点绕过？(1/0) > " res
                [ "$res" = "1" ] && proxies_bypass=ON
            else
                proxies_bypass=OFF
            fi
            setconfig proxies_bypass "$proxies_bypass"
            sleep 1
            setrules
            break
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}

set_clash_adv(){ #自定义clash高级规则
		[ ! -f "$YAMLSDIR"/user.yaml ] && cat > "$YAMLSDIR"/user.yaml <<EOF
#用于编写自定义设定(可参考https://lancellc.gitbook.io/clash/clash-config-file/general 或 https://docs.metacubex.one/function/general)
#端口之类请在脚本中修改，否则不会加载
#port: 7890
EOF
		[ ! -f "$YAMLSDIR"/others.yaml ] && cat > "$YAMLSDIR"/others.yaml <<EOF
#用于编写自定义的锚点、入站、proxy-providers、sub-rules、rule-set、script等功能
#可参考 https://github.com/MetaCubeX/Clash.Meta/blob/Meta/docs/config.yaml 或 https://lancellc.gitbook.io/clash/clash-config-file/an-example-configuration-file
#此处内容会被添加在配置文件的“proxy-group：”模块的末尾与“rules：”模块之前的位置
#例如：
#proxy-providers:
#rule-providers:
#sub-rules:
#tunnels:
#script:
#listeners:
EOF
		echo "-----------------------------------------------"
		echo -e "\033[32m已经创建自定义设定文件：$YAMLSDIR/user.yaml ！\033[0m"
		echo -e "\033[33m可用于编写自定义的DNS，等功能\033[0m"
		echo "-----------------------------------------------"
		echo -e "\033[32m已经创建自定义功能文件：$YAMLSDIR/others.yaml ！\033[0m"
		echo -e "\033[33m可用于编写自定义的锚点、入站、proxy-providers、sub-rules、rule-set、script等功能\033[0m"
		echo "-----------------------------------------------"
		echo -e "Windows下请\n使用\033[33mWinSCP软件\033[0m进行编辑！\033[0m"
		echo -e "MacOS下请\n使用\033[33mSecureFX软件\033[0m进行编辑！\033[0m"
		echo -e "Linux本机可\n使用\033[33mvim\033[0m进行编辑(路由设备可能不显示中文请勿使用)！\033[0m"
}

set_singbox_adv(){ #自定义singbox配置文件
		echo "-----------------------------------------------"
		echo -e "支持覆盖脚本设置的模块有：\033[0m"
		echo -e "\033[36mlog dns ntp certificate experimental\033[0m"
		echo -e "支持与内置功能合并(但不可冲突)的模块有：\033[0m"
		echo -e "\033[36mendpoints inbounds outbounds providers route services\033[0m"
		echo -e "将相应json文件放入\033[33m$JSONSDIR\033[0m目录后即可在启动时自动加载"
		echo "-----------------------------------------------"
		echo -e "使用前请务必参考配置教程:\033[32;4m https://juewuy.github.io/nWTjEpkSK \033[0m"
}
