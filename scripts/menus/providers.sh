#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_PROVIDERS" ] && return
__IS_MODULE_PROVIDERS=1

if [ "$crashcore" = singboxr ]; then
	CORE_TYPE=singbox
else
	CORE_TYPE=clash
fi

providers() {
    while true; do
        # 获取模版名称
        if [ -z "$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg)" ]; then
            provider_temp_des=$(sed -n "1 p" "$CRASHDIR"/configs/${CORE_TYPE}_providers.list | awk '{print $1}')
        else
            provider_temp_file=$(grep "provider_temp_${CORE_TYPE}" "$CRASHDIR"/configs/ShellCrash.cfg | awk -F '=' '{print $2}')
            provider_temp_des=$(grep "$provider_temp_file" "$CRASHDIR"/configs/${CORE_TYPE}_providers.list | awk '{print $1}')
            [ -z "$provider_temp_des" ] && provider_temp_des=$provider_temp_file
        fi
		echo "-----------------------------------------------"
		echo -e "\033[33msingboxr与mihomo内核的providers配置文件不互通！\033[0m"
        echo "-----------------------------------------------"
		echo -e " 1 \033[32m生成\033[0m包含全部节点/订阅的配置文件"
        echo -e " 2 选择\033[33m规则模版\033[0m     \033[32m$provider_temp_des\033[0m"
        echo -e " 3 \033[33m清理\033[0mproviders目录文件"
        echo "-----------------------------------------------"
        echo -e " 0 返回上级菜单"
        read -p "请输入对应字母或数字 > " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            echo "-----------------------------------------------"
            if [ -s "$CRASHDIR"/configs/providers.cfg ] || [ -s "$CRASHDIR"/configs/providers_uri.cfg ]; then
				. "$CRASHDIR/menus/providers_$CORE_TYPE.sh"
				gen_providers
            else
                echo -e "\033[31m你还未添加链接或本地配置文件，请先添加！\033[0m"
                sleep 1
            fi
            ;;
        2)
            echo "-----------------------------------------------"
            echo -e "当前规则模版为：\033[32m$provider_temp_des\033[0m"
            echo -e "\033[33m请选择在线模版：\033[0m"
            echo "-----------------------------------------------"
            cat "$CRASHDIR/configs/$CORE_TYPE_providers.list" | awk '{print " "NR" "$1}'
            echo "-----------------------------------------------"
            echo -e " a 使用\033[36m本地模版\033[0m"
            echo "-----------------------------------------------"
            read -p "请输入对应字母或数字 > " num
            case "$num" in
            "" | 0) ;;
            a)
                read -p "请输入模版的路径(绝对路径) > " dir
                if [ -s $dir ]; then
                    provider_temp_file=$dir
                    setconfig provider_temp_"$CORE_TYPE" "$provider_temp_file"
                    echo -e "\033[32m设置成功！\033[0m"
                else
                    echo -e "\033[31m输入错误，找不到对应模版文件！\033[0m"
                fi
                sleep 1
                ;;
            *)
                provider_temp_file=$(sed -n "$num p" "$CRASHDIR"/configs/${CORE_TYPE}_providers.list 2>/dev/null | awk '{print $2}')
                if [ -z "$provider_temp_file" ]; then
                    errornum
                    sleep 1
                else
                    setconfig provider_temp_"$CORE_TYPE" "$provider_temp_file"
                fi
                ;;
            esac
            ;;
        3)
            echo -e "\033[33m将清空 $CRASHDIR/providers 目录下所有内容\033[0m"
            read -p "是否继续？(1/0) > " res
            [ "$res" = "1" ] && rm -rf "$CRASHDIR"/providers && common_success
            ;;
        *)
            errornum
            sleep 1
            break
            ;;
        esac
    done
}
