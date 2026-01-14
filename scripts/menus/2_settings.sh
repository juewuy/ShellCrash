inputport() {
    read -p "请输入端口号(1-65535) > " portx
    . "$CRASHDIR"/menus/check_port.sh # 加载测试函数
    if check_port "$portx"; then
        setconfig "$xport" "$portx"
        echo -e "\033[32m设置成功！！！\033[0m"
        return 0
    else
        echo -e "\033[31m设置失败！！！\033[0m"
        sleep 1
        return 1
    fi
}

# 端口设置
set_adv_config() {
    while true; do
        . "$CFG_PATH" >/dev/null
        [ -z "$secret" ] && secret=未设置
        [ -z "$table" ] && table=100
        [ -z "$authentication" ] && auth=未设置 || auth=******
        echo "-----------------------------------------------"
        echo -e " 1 修改Http/Sock5端口：	\033[36m$mix_port\033[0m"
        echo -e " 2 设置Http/Sock5密码：	\033[36m$auth\033[0m"
        echo -e " 3 修改Redir/Tproxy端口：\033[36m$redir_port,$((redir_port + 1))\033[0m"
        echo -e " 4 修改DNS监听端口：	\033[36m$dns_port\033[0m"
        echo -e " 5 修改面板访问端口：	\033[36m$db_port\033[0m"
        echo -e " 6 设置面板访问密码：	\033[36m$secret\033[0m"
        echo -e " 8 自定义本机host地址：	\033[36m$host\033[0m"
        echo -e " 9 自定义路由表：	\033[36m$table,$((table + 1))\033[0m"
        echo -e " 0 返回上级菜单"
        read -p "请输入对应数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            xport=mix_port
            inputport
            ret=$?
            if [ "$ret" -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        2)
            echo "-----------------------------------------------"
            echo -e "格式必须是\033[32m 用户名:密码 \033[0m的形式，注意用小写冒号分隔！"
            echo -e "请尽量不要使用特殊符号！避免产生未知错误！"
            echo "输入 0 删除密码"
            echo "-----------------------------------------------"
            read -p "请输入Http/Sock5用户名及密码 > " input
            if [ "$input" = "0" ]; then
                authentication=""
                setconfig authentication
                echo "密码已移除！"
            else
                if [ "$local_proxy" = "ON" ] && [ "$local_type" = "环境变量" ]; then
                    echo "-----------------------------------------------"
                    echo -e "\033[33m请先禁用本机劫持功能或使用增强模式！\033[0m"
                    sleep 1
                else
                    authentication=$(echo "$input" | grep :)
                    if [ -n "$authentication" ]; then
                        setconfig authentication "'$authentication'"
                        echo -e "\033[32m设置成功！！！\033[0m"
                    else
                        echo -e "\033[31m输入有误，请重新输入！\033[0m"
                    fi
                fi
            fi

            ret=$?
            if [ "$ret" -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        3)
            xport=redir_port
            inputport

            ret=$?
            if [ "$ret" -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        4)
            xport=dns_port
            inputport

            ret=$?
            if [ "$ret" -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        5)
            xport=db_port
            inputport

            ret=$?
            if [ "$ret" -eq 1 ]; then
                break
            else
                continue
            fi
            ;;
        6)
            read -p "请输入面板访问密码(输入0删除密码) > " secret
            if [ -n "$secret" ]; then
                [ "$secret" = "0" ] && secret=""
                setconfig secret "$secret"
                echo -e "\033[32m设置成功！！！\033[0m"
            fi
            ;;
        8)
            echo "-----------------------------------------------"
            echo -e "\033[33m如果你的局域网网段不是192.168.x或172.16.x或10.x开头，请务必修改！\033[0m"
            echo -e "\033[31m设置后如本机host地址有变动，请务必重新修改！\033[0m"
            echo "-----------------------------------------------"
            read -p "请输入自定义host地址(输入0移除自定义host) > " host
            if [ "$host" = "0" ]; then
                host=""
                setconfig host "$host"
                echo -e "\033[32m已经移除自定义host地址，请重新运行脚本以自动获取host！！！\033[0m"
                exit 0
            elif [ -n "$(echo "$host" | grep -E -o '\<([1-9]|[1-9][0-9]|1[0-9]{2}|2[01][0-9]|22[0-3])\>(\.\<([0-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\>){2}\.\<([1-9]|[0-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-4])\>')" ]; then
                setconfig host "$host"
                echo -e "\033[32m设置成功！！！\033[0m"
            else
                host=""
                echo -e "\033[31m输入错误，请仔细核对！！！\033[0m"
            fi
            sleep 1
            ;;
        9)
            echo "-----------------------------------------------"
            echo -e "\033[33m仅限Tproxy、Tun或混合模式路由表出现冲突时才需要设置！\033[0m"
            read -p "请输入路由表地址(不明勿动！建议102-125之间) > " table
            if [ -n "$table" ]; then
                [ "$table" = "0" ] && table="100"
                setconfig table "$table"
                echo -e "\033[32m设置成功！！！\033[0m"
            fi
            ;;
        *)
            errornum
            sleep 1
            ;;
        esac
    done
}
