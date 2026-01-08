#!/bin/sh
# Copyright (C) Juewuy

. "$CRASHDIR"/libs/urlencode.sh
. "$CRASHDIR"/libs/check_target.sh
. "$CRASHDIR"/libs/web_get_bin.sh
. "$CRASHDIR"/libs/compare.sh
. "$CRASHDIR"/libs/set_config.sh

update_servers() { #更新servers.list
    get_bin "$TMPDIR"/servers.list public/servers.list
    [ "$?" = 0 ] && mv -f "$TMPDIR"/servers.list "$CRASHDIR"/configs/servers.list
}
gen_ua(){  #自动生成ua
    [ -z "$user_agent" -o "$user_agent" = "auto" ] && {
        if echo "$crashcore" | grep -q 'singbox'; then
            user_agent="sing-box/singbox/$core_v"
        elif [ "$crashcore" = meta ]; then
            user_agent="clash.meta/mihomo/$core_v"
        else
            user_agent="clash"
        fi
    }
    [ "$user_agent" = "none" ] && unset user_agent
}
get_core_config() { #下载内核配置文件
    [ -z "$rule_link" ] && rule_link=1
    [ -z "$server_link" ] || [ $server_link -gt $(grep -aE '^4' "$CRASHDIR"/configs/servers.list | wc -l) ] && server_link=1
    Server=$(grep -aE '^3|^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $3}')
    Server_ua=$(grep -aE '^4' "$CRASHDIR"/configs/servers.list | sed -n ""$server_link"p" | awk '{print $4}')
    Config=$(grep -aE '^5' "$CRASHDIR"/configs/servers.list | sed -n ""$rule_link"p" | awk '{print $3}')
    gen_ua
	#如果传来的是Url链接则合成Https链接，否则直接使用Https链接
    if [ -z "$Https" ]; then
        #Urlencord转码处理保留字符
        if ckcmd hexdump;then
			Url=$(echo $Url | sed 's/%26/\&/g')   #处理分隔符
			urlencodeUrl="exclude=$(urlencode "$exclude")&include=$(urlencode "$include")&url=$(urlencode "$Url")&config=$(urlencode "$Config")"
		else
			urlencodeUrl="exclude=$exclude&include=$include&url=$Url&config=$Config"
		fi
        Https="${Server}/sub?target=${target}&${Server_ua}=${user_agent}&insert=true&new_name=true&scv=true&udp=true&${urlencodeUrl}"
        url_type=true
    fi
    #输出
    echo "-----------------------------------------------"
    logger "正在连接服务器获取【$target】配置文件…………"
    echo -e "链接地址为：\033[4;32m$Https\033[0m"
    echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
    #获取在线config文件
    core_config_new="$TMPDIR"/"$target"_config."$format"
    rm -rf "$core_config_new"
    webget "$core_config_new" "$Https" echoon rediron skipceron "$user_agent"
    if [ "$?" != "0" ]; then
        if [ -z "$url_type" ]; then
            echo "-----------------------------------------------"
            logger "配置文件获取失败！" 31
            echo -e "\033[31m请尝试使用【在线生成配置文件】功能！\033[0m"
            echo "-----------------------------------------------"
            exit 1
        else
            if [ -n "$retry" ] && [ "$retry" -ge 3 ]; then
                logger "无法获取配置文件，请检查链接格式以及网络连接状态！" 31
                echo -e "\033[32m也可用浏览器下载以上链接后，使用WinSCP手动上传到/tmp目录后执行crash命令本地导入！\033[0m"
                exit 1
            else
                retry=$((retry + 1))
                logger "配置文件获取失败！" 31
                if [ "$retry" = 1 ]; then
                    echo -e "\033[32m尝试更新服务器列表并使用其他服务器获取配置！\033[0m"
                    update_servers
                else
                    echo -e "\033[32m尝试使用其他服务器获取配置！\033[0m"
                fi
                echo -e "正在重试\033[33m第$retry次/共3次！\033[0m"
                if [ "$server_link" -ge 4 ]; then
                    server_link=0
                fi
                server_link=$((server_link + 1))
                setconfig server_link $server_link
                Https=""
                get_core_config
            fi
        fi
    else
        Https=""
        if echo "$crashcore" | grep -q 'singbox'; then
            . "$CRASHDIR"/starts/singbox_config_check.sh
        else
            . "$CRASHDIR"/starts/clash_config_check.sh
        fi
		check_config
        #如果不同则备份并替换文件
        if [ -s "$core_config" ]; then
            compare "$core_config_new" "$core_config"
            [ "$?" = 0 ] || mv -f "$core_config" "$core_config".bak && mv -f "$core_config_new" "$core_config"
        else
            mv -f "$core_config_new" "$core_config"
        fi
        echo -e "\033[32m已成功获取配置文件！\033[0m"
    fi
    return 0
}
