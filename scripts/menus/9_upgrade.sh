#!/bin/sh
# Copyright (C) Juewuy

[ -n "$__IS_MODULE_9_UPGRADE_LOADED" ] && return
__IS_MODULE_9_UPGRADE_LOADED=1

. "$CRASHDIR"/libs/check_dir_avail.sh
. "$CRASHDIR"/libs/check_cpucore.sh
. "$CRASHDIR"/libs/web_get_bin.sh

error_down() {
    btm_box "\033[33m请尝试切换至其他安装源后重新下载！\033[0m" \
        "或者参考 \033[32;4mhttps://juewuy.github.io/bdaz\033[0m 进行本地安装！"
    sleep 1
}

# 更新/卸载功能菜单
upgrade() {
    while true; do
        if [ -z "$version_new" ]; then
            checkupdate
        fi
        [ -z "$core_v" ] && core_v=$crashcore
        core_v_new=$(eval echo \$"$crashcore"_v)

        comp_box "\033[30;47m更新与支持\033[0m" \
            "" \
            "当前目录(\033[32m$CRASHDIR\033[0m)剩余空间：\033[36m$(dir_avail "$CRASHDIR" -h)\033[0m"
        [ "$(dir_avail "$CRASHDIR")" -le 5120 ] && [ "$CRASHDIR" = "$BINDIR" ] && {
            content_line "\033[33m当前目录剩余空间较低，建议开启小闪存模式！\033[0m"
        }
        content_line "1) 更新\033[36m管理脚本\t\033[33m$versionsh_l\033[0m > \033[32m$version_new \033[36m$release_type\033[0m"
        content_line "2) 切换/更新\033[33m内核文件\t\033[33m$core_v\033[0m > \033[32m$core_v_new\033[0m"
        content_line "3) 安装/更新本地\033[32m数据库文件\033[0m"
        content_line "4) 安装/更新本地\033[35mDashboard面板\033[0m"
        content_line "5) 安装/更新本地\033[33m根证书文件\033[0m"
        content_line "6) \033[32mPAC\033[0m自动代理查看"
        content_line "7) 切换\033[36m安装源及版本分支\033[0m"
        content_line "8) \033[31m卸载ShellCrash\033[0m"
        content_line "9) \033[36m感谢列表！\033[0m"
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="

        read -r -p "请输入对应数字> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            setscripts
            ;;
        2)
            setcore
            ;;
        3)
            setgeo
            ;;
        4)
            setdb
            ;;
        5)
            setcrt
            ;;
        6)
            msg_alert -t 2 "PAC配置链接为：\033[30;47m http://$host:$db_port/ui/pac \033[0m" \
                "PAC的使用教程请参考：\033[4;32mhttps://juewuy.github.io/ehRUeewcv\033[0m"
            ;;
        7)
            setserver
            ;;
        8)
            . "$CRASHDIR"/menus/uninstall.sh && uninstall
            ;;
        9)
            comp_box "感谢以下项目及其开发者们的无私奉献！"

            content_line "\033[32mClash              \033[0m开发：\033[36mDreamacro\033[0m"
            content_line ""

            content_line "\033[32msing-box           \033[0m开发：\033[36mSagerNet\033[0m"
            content_line "项目地址：\033[32mhttps://github.com/SagerNet/sing-box\033[0m"
            content_line ""

            content_line "\033[32mMetaCubeX          \033[0m开发：\033[36mMetaCubeX\033[0m"
            content_line "项目地址：\033[32mhttps://github.com/MetaCubeX\033[0m"
            content_line ""

            content_line "\033[32mYACD面板           \033[0m开发：\033[36mhaishanh\033[0m"
            content_line "项目地址：\033[32mhttps://github.com/haishanh/yacd\033[0m"
            content_line ""

            content_line "\033[32mZashboard          \033[0m开发：\033[36mZephyruso\033[0m"
            content_line "项目地址：\033[32mhttps://github.com/Zephyruso/zashboard\033[0m"
            content_line ""

            content_line "\033[32mSubconverter       \033[0m开发：\033[36mtindy2013\033[0m"
            content_line "项目地址：\033[32mhttps://github.com/tindy2013/subconverter\033[0m"
            content_line ""

            content_line "\033[32msing-box-reF1nd    \033[0m开发：\033[36mreF1nd\033[0m"
            content_line "项目地址：\033[32mhttps://github.com/reF1nd/sing-box\033[0m"
            content_line ""

            content_line "\033[32mDustinWin          \033[0m开发：\033[36mDustinWin\033[0m"
            content_line "开发者地址：\033[32mhttps://github.com/DustinWin\033[0m"
            content_line ""

            comp_box "特别感谢：\033[36m所有帮助及赞助过此项目的同仁们！\033[0m"
            sleep 2
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 检查更新
checkupdate() {
    line_break
    separator_line "="
    content_line "\033[32m正在检查更新......\033[0m"
    get_bin "$TMPDIR"/version_new version echooff
    [ "$?" = "0" ] && {
        version_new=$(cat "$TMPDIR"/version_new)
        get_bin "$TMPDIR"/version_new bin/version echooff
        content_line "\033[32m检查更新成功\033[0m"
        separator_line "="
    }
    if [ "$?" = "0" ]; then
        . "$TMPDIR"/version_new 2>/dev/null
    else
        content_line "\033[31m检查更新失败！请尝试切换其他安装源！\033[0m"
        separator_line "="
        setserver
        if [ "$checkupdate" != false ]; then
            checkupdate
        fi
    fi
    rm -rf "$TMPDIR"/version_new
}

# 更新脚本
getscripts() {
    line_break
    separator_line "="
    get_bin "$TMPDIR"/ShellCrash.tar.gz ShellCrash.tar.gz

    if [ "$?" != "0" ]; then
        content_line "\033[33m文件下载失败！\033[0m"
        error_down
    else
        "$CRASHDIR"/start.sh stop 2>/dev/null
        # 解压
        content_line "开始解压文件......"
        mkdir -p "$CRASHDIR" >/dev/null
        tar -zxf "$TMPDIR/ShellCrash.tar.gz" ${tar_para} -C "$CRASHDIR"/
        if [ $? -ne 0 ]; then
            content_line "\033[33m文件解压失败！\033[0m"
            error_down
        else
            . "$CRASHDIR"/init.sh >/dev/null
            echo "$release_type" | grep -qE '^[0-9]' && setconfig userguide #回退时重新新手引导
            content_line "\033[32m脚本更新成功！\033[0m"
            separator_line "="
        fi
    fi
    rm -rf "$TMPDIR"/ShellCrash.tar.gz
    exit
}

setscripts() {
    while true; do
        comp_box "\033[33m注意：更新时会停止服务！\033[0m" \
            "" \
            "当前脚本版本为：\033[36m$versionsh_l\033[0m" \
            "最新脚本版本为：\033[32m$version_new\033[0m"
        btm_box "1) 立即更新" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " res
        case "$res" in
        "" | 0)
            break
            ;;
        1)
            # 下载更新
            getscripts
            # 提示
            msg_alert "\033[32m管理脚本更新成功!\033[0m"
            exit 0
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 更新内核
# 手动设置内核架构
setcpucore() {
    cpucore_list="armv5 armv7 arm64 386 amd64 mipsle-softfloat mipsle-hardfloat mips-softfloat"

    comp_box "\033[31m仅适合脚本无法正确识别核心或核心无法正常运行时使用！\033[0m" \
        "不知道如何获取核心版本？\033[0m" \
        "请参考：\033[36;4mhttps://juewuy.github.io/bdaz\033[0m"
    content_line "当前可供在线下载的处理器架构为："
    separator_line "-"

    echo "$cpucore_list" |
        awk '{for(i=1;i<=NF;i++) print i") "$i}' |
        while IFS= read -r line; do
            content_line "$line"
        done

    separator_line "="
    read -r -p "请输入对应标号> " num
    [ -n "$num" ] && setcpucore=$(echo "$cpucore_list" | awk '{print $"'"$num"'"}')
    if [ -z "$setcpucore" ]; then
        cpucore=""
        msg_alert "\033[31m请输入正确的处理器架构！\033[0m"
    else
        cpucore=$setcpucore
        setconfig cpucore "$cpucore"
    fi
}

# 手动指定内核类型
setcoretype() {
    while true; do
        echo "$crashcore" | grep -q 'singbox' && core_old=singbox || core_old=clash
        comp_box "\033[33m请确认该自定义内核的类型：\033[0m"
        content_line "1) Mihomo(Meta)"
        content_line "2) Singbox-reF1nd"
        content_line "3) Singbox"
        content_line "4) Clash"
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0) ;;
        1)
            crashcore=meta
            ;;
        2)
            crashcore=singboxr
            ;;
        3)
            crashcore=singbox
            ;;
        4)
            crashcore=clash
            ;;
        *)
            errornum
            continue
            ;;
        esac
        echo "$crashcore" | grep -q 'singbox' && core_new=singbox || core_new=clash
        break
    done
}

# clash与singbox内核切换
switch_core() {
    # singbox和clash内核切换时提示是否保留文件
    [ "$core_new" != "$core_old" ] && {
        [ "$dns_mod" = "redir_host" ] && [ "$core_old" = "clash" ] && setconfig dns_mod mix                               #singbox自动切换dns
        [ "$dns_mod" = "mix" ] && [ "$crashcore" = 'clash' -o "$crashcore" = 'clashpre' ] && setconfig dns_mod redir_host #singbox自动切换dns
        comp_box "\033[33m已从$core_old内核切换至$core_new内核\033[0m" \
            "\033[33m二者Geo数据库及yaml/json配置文件不通用\033[0m" \
            "是否保留相关数据库文件？"
        btm_box "1) 保留" \
            "0) 不保留"
        read -r -p "请输入对应标号> " res
        [ "$res" = '0' ] && {
            [ "$core_old" = "clash" ] && {
                geodate='Country.mmdb GeoSite.dat ruleset/*.mrs ruleset/*.yaml ruleset/*.yml'
                geodate_v='Country_v cn_mini_v geosite_v mrs_geosite_cn_v'
            }
            [ "$core_old" = "singbox" ] && {
                geodate='geoip.db geosite.db ruleset/*.srs ruleset/*.json'
                geodate_v='geoip_cn_v geosite_cn_v srs_geoip_cn_v srs_geosite_cn_v'
            }
            for text in ${geodate}; do
                rm -rf "$CRASHDIR"/${text}
            done
            for text in ${geodate_v}; do
                setconfig "$text"
            done
        }
    }
}

# 下载内核文件
getcore() {
    # 调用下载工具
    . "$CRASHDIR"/libs/core_tools.sh

    [ -z "$crashcore" ] && crashcore=meta
    [ -z "$cpucore" ] && check_cpucore
    [ "$crashcore" = unknow ] && setcoretype
    if echo "$crashcore" | grep -q 'singbox'; then
        core_new=singbox
    else
        core_new=clash
    fi
    # 获取在线内核文件
    line_break
    separator_line "="
    content_line "正在在线获取$crashcore核心文件......"
    core_webget
    case "$?" in
    0)
        content_line "\033[32m$crashcore核心下载成功！\033[0m"
        separator_line "="
        sleep 1
        switch_core
        ;;
    1)
        content_line "\033[31m核心文件下载失败！\033[0m"
        separator_line "="
        [ -z "$custcorelink" ] && error_down
        ;;
    *)
        content_line "\033[31m核心文件下载成功但校验失败\033[0m"
        content_line "\033[31m请尝试手动指定CPU版本\033[0m"
        separator_line "="
        sleep 1
        rm -rf "${TMPDIR}"/core_new
        rm -rf "${TMPDIR}"/core_new.tar.gz
        setcpucore
        ;;
    esac
}

checkcustcore() {
    [ "$api_tag" = "latest" ] && api_url=latest || api_url="tags/$api_tag"
    # 通过githubapi获取内核信息
    line_break
    separator_line "="
    content_line "\033[32m正在获取内核文件链接......\033[0m"
    webget "$TMPDIR"/github_api https://api.github.com/repos/"${project}"/releases/"${api_url}"
    if [ "$?" = 0 ]; then
        release_tag=$(cat "$TMPDIR"/github_api | grep '"tag_name":' | awk -F '"' '{print $4}')
        release_date=$(cat "$TMPDIR"/github_api | grep '"published_at":' | awk -F '"' '{print $4}')
        update_date=$(cat "$TMPDIR"/github_api | grep '"updated_at":' | head -n 1 | awk -F '"' '{print $4}')
        echo "$cpucore" | grep -q 'mips' && cpu_type=mips || cpu_type=$cpucore
        cat "$TMPDIR"/github_api | grep "browser_download_url" | grep -oE "https://github.com/${project}/releases/download.*linux.*${cpu_type}.*\.gz\"$" | sed 's/"//' >"$TMPDIR"/core.list
        rm -rf "$TMPDIR"/github_api

        if [ -s "$TMPDIR"/core.list ]; then
            separator_line "="

            comp_box "内核版本：\033[36m$release_tag\033[0m" \
                "发布时间：\033[33m$release_date\033[0m" \
                "更新时间：\033[32m$update_date\033[0m"
            content_line "\033[33m请确认内核信息并选择：\033[0m"
            separator_line "-"
            grep -oE "$release_tag.*" "$TMPDIR/core.list" |
                sed 's|.*/||' |
                awk '{print NR") "$1}' |
                while IFS= read -r line; do
                    content_line "$line"
                done

            content_line ""
            content_line "0) 返回上级菜单"
            separator_line "="
            read -r -p "请输入对应标号> " num
            case "$num" in
            0)
                return 0
                ;;
            [1-9] | [1-9][0-9])
                if [ "$num" -le "$(wc -l <"$TMPDIR"/core.list)" ]; then
                    custcorelink=$(sed -n "$num"p "$TMPDIR"/core.list)
                    getcore
                else
                    errornum
                fi
                ;;
            *)
                errornum
                ;;
            esac
        else
            content_line "\033[31m找不到可用内核，可能是开发者没有编译相关CPU架构版本的内核文件！\033[0m"
            separator_line "="
            sleep 1
        fi
    else
        content_line "\033[31m查找失败，请尽量在服务启动后再使用本功能！\033[0m"
        separator_line "="
        sleep 1
    fi
    rm -rf "$TMPDIR"/core.list
}

# 自定义内核
setcustcore() {
    while true; do
        [ -z "$cpucore" ] && check_cpucore
        line_break
        separator_line "="
        content_line "\033[36m此处内核通常源自互联网采集，此处致谢各位开发者！\033[0m"
        content_line "\033[33m自定义内核未经过完整适配，使用出现问题请自行解决！\033[0m"
        content_line "\033[31m自定义内核已适配定时任务，但不支持小闪存模式！\033[0m"
        content_line "\033[32m如遇到网络错误请先启动ShellCrash服务！\033[0m"
        [ -n "$custcore" ] && {
            content_line "当前内核为：\033[36m$custcore\033[0m"
        }
        separator_line "="
        content_line "请选择需要使用的核心："
        separator_line "-"
        content_line "1) \033[36mMetaCubeX/mihomo\033[32m@release\033[0m版本官方内核"
        content_line "2) \033[36mvernesong/mihomo\033[32m@alpha\033[0m版本内核(支持Smart策略)"
        content_line "3) \033[36mSagerNet/sing-box\033[32m@release\033[0m版本官方内核"
        content_line "4) Premium-2023.08.17内核(已停止维护)"
        content_line "9) \033[33m自定义内核链接 \033[0m"
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            project=MetaCubeX/mihomo
            api_tag=latest
            crashcore=meta
            checkcustcore
            ;;
        2)
            project=vernesong/mihomo
            api_tag=Prerelease-Alpha
            crashcore=meta
            checkcustcore
            ;;
        3)
            project=SagerNet/sing-box
            api_tag=latest
            crashcore=singbox
            checkcustcore
            ;;
        4)
            project=juewuy/ShellCrash
            api_tag=clash.premium.latest
            crashcore=clashpre
            checkcustcore
            ;;
        9)
            comp_box "请输入自定义内核的链接地址" \
                "（必须是以.tar.gz或.gz结尾的压缩文件）" \
                "" \
                "或者输入 0 返回上级菜单"
            read -r -p "请输入> " link
            if [ "$link" = 0 ]; then
                continue
            elif [ -n "$link" ]; then
                custcorelink="$link"
                setcoretype
                getcore
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}

setziptype() {
    comp_box "请选择内核内核分支及压缩方式：\033[0m"
    content_line "1) \033[36m最简编译release版本，upx压缩\033[0m"
    sub_content_line "不支持Gvisor、Tailscale、Wireguard、NaiveProxy"
    content_line "2) \033[32m标准编译release版本，tar.gz压缩\033[0m"
    sub_content_line "完整支持脚本全部内置功能"
    content_line "3) \033[33m完整编译alpha版本，gz压缩\033[0m"
    sub_content_line "占用可能略高，稳定性自测"
    content_line "0) 返回上级菜单"
    separator_line "="
    read -r -p "请输入对应标号> " num
    case "$num" in
    "" | 0) ;;
    1)
        zip_type='upx'
        ;;
    2)
        zip_type='tar.gz'
        ;;
    3)
        zip_type='gz'
        ;;
    *)
        errornum
        ;;
    esac
    setconfig zip_type "$zip_type"
}

# 内核选择菜单
setcore() {
    while true; do
        # 获取核心及版本信息
        [ -z "$crashcore" ] && crashcore="unknow"
        [ -z "$zip_type" ] && zip_type="tar.gz"
        echo "$crashcore" | grep -q 'singbox' && core_old=singbox || core_old=clash
        [ -n "$custcorelink" ] && custcore="$(echo "$custcorelink" | sed 's#.*github.com##; s#/releases/download/#@#; s#-linux.*$##')"

        [ -z "$cpucore" ] && check_cpucore

        comp_box "当前内核：\033[42;30m$crashcore\033[47;30m $core_v\033[0m" \
            "当前系统处理器架构：\033[32m$cpucore\033[0m" \
            "\033[36m如需本地上传，请将.upx .gz .tar.gz文件上传至 /tmp 目录后重新运行crash命令\033[0m"

        content_line "\033[33m请选择需要使用的核心版本：\033[0m"
        separator_line "-"
        content_line "1) \033[43;30mMihomo\033[0m：\033[32m$meta_v \033[32m（原meta内核）支持全面\033[0m \033[33m占用略高\033[0m"
        sub_content_line "说明文档：\033[36;4mhttps://wiki.metacubex.one\033[0m"

        content_line "2) \033[43;30mSingBoxR\033[0m：\033[32m$singboxr_v \033[32m支持全面\033[0m \033[33m使用reF1nd增强分支\033[0m"
        sub_content_line "说明文档：\033[36;4mhttps://sing-boxr.dustinwin.us.kg\033[0m"

        [ "$zip_type" = 'upx' ] && {
            content_line "3) \033[43;30mSingBox\033[0m：\033[32m$singbox_v \033[32m占用较低\033[0m \033[33m不支持providers\033[0m"
            sub_content_line "说明文档：\033[36;4mhttps://sing-box.sagernet.org\033[0m"
        }
        [ "$zip_type" = 'upx' ] && {
            content_line "4) \033[43;30mClash\033[0m：\033[32m$clash_v \033[32m占用低\033[0m \033[33m不安全,已停止维护\033[0m"
            sub_content_line "说明文档：\033[36;4mhttps://lancellc.gitbook.io\033[0m"
        }
        content_line "5) 切换版本分支及压缩方式：\033[32m$zip_type\033[0m"
        content_line "6) \033[36m使用自定义内核\033[0m $custcore"
        content_line "7) \033[32m更新当前内核\033[0m"
        content_line "9) 手动指定处理器架构"
        content_line ""
        content_line "0 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            [ -d "/jffs" ] && {
                msg_alert -t 2 "\033[31mMeta内核使用的GeoSite.dat数据库在华硕设备存在被系统误删的问题，可能无法使用!\033[0m"
            }
            crashcore=meta
            custcorelink=''
            getcore
            break
            ;;
        2)
            crashcore=singboxr
            custcorelink=''
            getcore
            break
            ;;
        3)
            crashcore=singbox
            custcorelink=''
            getcore
            break
            ;;
        4)
            crashcore=clash
            custcorelink=''
            getcore
            break
            ;;
        5)
            setziptype
            ;;
        6)
            setcustcore
            ;;
        7)
            getcore
            break
            ;;
        9)
            setcpucore
            break
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 数据库
# 下载Geo文件
getgeo() {
    # 生成链接
    line_break
    separator_line "="
    content_line "正在从服务器获取数据库文件......"
    get_bin "$TMPDIR"/"${geoname}" bin/geodata/"$geotype"
    if [ "$?" = "1" ]; then
        content_line "\033[31m文件下载失败！\033[0m"
        error_down
    else
        echo "$geoname" | grep -Eq '.mrs|.srs|.tar.gz' && {
            geofile='ruleset/'
            [ ! -d "$BINDIR"/ruleset ] && mkdir -p "$BINDIR"/ruleset
        }
        if echo "$geoname" | grep -Eq '.tar.gz'; then
            tar -zxf "$TMPDIR"/"${geoname}" ${tar_para} -C "$BINDIR"/"${geofile}" >/dev/null
            if [ $? -ne 0 ]; then
                content_line "文件解压失败！"
                separator_line "="
                sleep 1
                line_break
                rm -rf "$TMPDIR"/${geoname}
                exit 1
            fi
            rm -rf "$TMPDIR"/${geoname}
        else
            mv -f "$TMPDIR"/"${geoname}" "$BINDIR"/"${geofile}""${geoname}"
        fi
        content_line "\033[32m$geotype数据库文件下载成功！\033[0m"
        geo_v="$(echo "$geotype" | awk -F "." '{print $1}')_v"
        setconfig "$geo_v" "$GeoIP_v"
    fi
    sleep 1
}

getcustgeo() {
    line_break
    separator_line "="
    content_line "正在获取数据库文件......"
    webget "$TMPDIR"/"$geoname" "$custgeolink"
    if [ "$?" = "1" ]; then
        content_line "\033[31m文件下载失败！\033[0m"
        error_down
    else
        echo "$geoname" | grep -Eq '.mrs|.srs' && {
            geofile='ruleset/'
            [ ! -d "$BINDIR"/ruleset ] && mkdir -p "$BINDIR"/ruleset
        }
        mv -f "$TMPDIR"/"${geoname}" "$BINDIR"/"${geofile}""${geoname}"
        content_line "\033[32m$geotype数据库文件下载成功！\033[0m"
        separator_line "="
    fi
    sleep 1
}

checkcustgeo() {
    while true; do
        [ "$api_tag" = "latest" ] && api_url=latest || api_url="tags/$api_tag"
        [ ! -s "$TMPDIR"/geo.list ] && {
            comp_box "\033[32m正在查找可更新的数据库文件......\033[0m"
            webget "$TMPDIR"/github_api https://api.github.com/repos/${project}/releases/${api_url}
            release_tag=$(cat "$TMPDIR"/github_api | grep '"tag_name":' | awk -F '"' '{print $4}')
            cat "$TMPDIR"/github_api | grep "browser_download_url" | grep -oE 'releases/download.*' | grep -oiE 'geosite.*\.dat"$|country.*\.mmdb"$|.*.mrs|.*.srs' | sed 's|.*/||' | sed 's/"//' >"$TMPDIR"/geo.list
            rm -rf "$TMPDIR"/github_api
        }
        if [ -s "$TMPDIR"/geo.list ]; then
            comp_box "请选择需要更新的数据库文件："
            awk '{print NR") "$1}' "$TMPDIR/geo.list" |
                while IFS= read -r line; do
                    content_line "$line"
                done
            content_line ""
            content_line "0) 返回上级菜单"
            separator_line "="
            read -r -p "请输入对应标号> " num
            case "$num" in
            "" | 0)
                break
                ;;
            [1-99])
                if [ "$num" -le "$(wc -l <"$TMPDIR"/geo.list)" ]; then
                    geotype=$(sed -n "$num"p "$TMPDIR"/geo.list)
                    [ -n "$(echo "$geotype" | grep -oiE 'GeoSite.*dat')" ] && geoname=GeoSite.dat
                    [ -n "$(echo "$geotype" | grep -oiE 'Country.*mmdb')" ] && geoname=Country.mmdb
                    [ -n "$(echo "$geotype" | grep -oiE '.*(.srs|.mrs)')" ] && geoname=$geotype
                    custgeolink=https://github.com/${project}/releases/download/${release_tag}/${geotype}
                    getcustgeo
                else
                    errornum
                    break
                fi
                ;;
            *)
                errornum
                ;;
            esac
        else
            msg_alert "\033[31m查找失败，请尽量在服务启动后再使用本功能！\033[0m"
        fi
    done
}

# 下载自定义数据库文件
setcustgeo() {
    while true; do
        rm -rf "$TMPDIR"/geo.list
        comp_box "\033[36m此处数据库均源自互联网采集，此处致谢各位开发者！\033[0m" \
            "\033[32m请点击或复制链接前往项目页面查看具体说明！\033[0m" \
            "\033[31m自定义数据库不支持定时任务及小闪存模式！\033[0m" \
            "\033[33m如遇到网络错误请先启动ShellCrash服务！\033[0m"

        content_line "\033[0m请选择需要更新的数据库项目来源：\033[0m"
        separator_line "-"
        content_line "1) \033[36;4mhttps://github.com/MetaCubeX/meta-rules-dat\033[0m"
        sub_content_line "（仅限Clash/Mihomo）"

        content_line "2) \033[36;4mhttps://github.com/DustinWin/ruleset_geodata\033[0m"
        sub_content_line "（仅限Clash/Mihomo）"

        content_line "3) \033[36;4mhttps://github.com/DustinWin/ruleset_geodata\033[0m"
        sub_content_line "（仅限SingBox-srs）"

        content_line "4) \033[36;4mhttps://github.com/DustinWin/ruleset_geodata\033[0m"
        sub_content_line "（仅限Mihomo-mrs）"

        content_line "5) \033[36;4mhttps://github.com/Loyalsoldier/geoip\033[0m"
        sub_content_line "（仅限Clash-GeoIP）"

        content_line "9) \033[33m自定义数据库链接 \033[0m"
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            project=MetaCubeX/meta-rules-dat
            api_tag=latest
            checkcustgeo
            ;;
        2)
            project=DustinWin/ruleset_geodata
            api_tag=mihomo-geodata
            checkcustgeo
            ;;
        3)
            project=DustinWin/ruleset_geodata
            api_tag=sing-box-ruleset
            checkcustgeo
            ;;
        4)
            project=DustinWin/ruleset_geodata
            api_tag=mihomo-ruleset
            checkcustgeo
            ;;
        5)
            project=Loyalsoldier/geoip
            api_tag=latest
            checkcustgeo
            ;;
        9)
            line_break
            read -r -p "请输入自定义数据库的链接地址> " link
            [ -n "$link" ] && custgeolink="$link"
            getgeo
            ;;
        *)
            errornum
            ;;
        esac
    done
}

setgeo() {
    while true; do
        . $CFG_PATH >/dev/null
        [ -n "$cn_mini_v" ] && geo_type_des=精简版 || geo_type_des=全球版
        comp_box "\033[33m注意：Mihomo内核和SingBox内核的数据库文件不通用\033[0m" \
            "在线数据库最新版本（每日同步上游）：\033[32m$GeoIP_v\033[0m" \
            "" \
            "请选择需要更新的Geo数据库文件："

        content_line "1) CN-IP绕过文件（约0.1mb）	\033[33m$china_ip_list_v\033[0m"
        content_line "2) CN-IPV6绕过文件（约30kb）	\033[33m$china_ipv6_list_v\033[0m"
        content_line ""
        content_line "3) Mihomo精简版GeoIP_cn数据库（约0.1mb）	\033[33m$cn_mini_v\033[0m"
        content_line "4) Mihomo完整版GeoSite数据库（约5mb）	\033[33m$geosite_v\033[0m"
        content_line ""
        content_line "5) Mihomo-mrs数据库常用包（约1mb,非必要勿用）"
        content_line "6) Singbox-srs数据库常用包（约0.8mb,非必要勿用）"
        content_line ""
        content_line "8) \033[36m自定义数据库文件\033[0m"
        content_line "9) \033[31m清理数据库文件\033[0m"
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            geotype=china_ip_list.txt
            geoname=cn_ip.txt
            getgeo
            ;;
        2)
            geotype=china_ipv6_list.txt
            geoname=cn_ipv6.txt
            getgeo
            ;;
        3)
            geotype=cn_mini.mmdb
            geoname=Country.mmdb
            getgeo
            ;;
        4)
            geotype=geosite.dat
            geoname=GeoSite.dat
            getgeo
            ;;
        5)
            geotype=mrs.tar.gz
            geoname=mrs.tar.gz
            getgeo
            ;;
        6)
            geotype=srs.tar.gz
            geoname=srs.tar.gz
            getgeo
            ;;
        8)
            setcustgeo
            ;;
        9)
            while true; do
                comp_box "\033[33m这将清理$CRASHDIR目录及/ruleset目录下所有数据库文件！\033[0m" \
                    "清理后启动服务即可自动下载所需文件"
                btm_box "1) 确认清理" \
                    "0) 返回上级菜单"
                read -r -p "请输入对应标号> " res
                case "$res" in
                "" | 0)
                    break
                    ;;
                1)
                    for file in cn_ip.txt cn_ipv6.txt Country.mmdb GeoSite.dat geoip.db geosite.db; do
                        rm -rf $CRASHDIR/$file
                    done
                    for var in Country_v cn_mini_v china_ip_list_v china_ipv6_list_v geosite_v geoip_cn_v geosite_cn_v mrs_geosite_cn_v srs_geoip_cn_v srs_geosite_cn_v mrs_v srs_v; do
                        setconfig $var
                    done
                    rm -rf "$CRASHDIR"/ruleset/*
                    msg_alert "\033[33m所有数据库文件均已清理！\033[0m"
                    break
                    ;;
                *)
                    errornum
                    ;;
                esac
            done
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# Dashboard
getdb() {
    dblink="${update_url}/"
    line_break
    separator_line "="
    content_line "正在连接服务器获取安装文件......"
    get_bin "$TMPDIR"/clashdb.tar.gz bin/dashboard/${db_type}.tar.gz
    if [ "$?" = "1" ]; then
        content_line "\033[31m文件下载失败！\033[0m"
        error_down
        return 1
    else
        content_line "\033[33m下载成功，正在解压文件......\033[0m"
        mkdir -p "$dbdir" >/dev/null
        tar -zxf "$TMPDIR/clashdb.tar.gz" ${tar_para} -C "$dbdir" >/dev/null
        if [ $? -ne 0 ]; then
            content_line "文件解压失败！"
            separator_line "="
            line_break
            sleep 1
            rm -rf "$TMPDIR"/clashfm.tar.gz
            exit 1
        fi

        #修改默认host和端口
        if [ "$db_type" = "clashdb" -o "$db_type" = "meta_db" -o "$db_type" = "zashboard" ]; then
            sed -i "s/127.0.0.1/${host}/g" "$dbdir"/assets/*.js
            sed -i "s/9090/${db_port}/g" "$dbdir"/assets/*.js
        elif [ "$db_type" = "meta_xd" ]; then
            sed -i "s/127.0.0.1:9090/${host}:${db_port}/g" "$dbdir"/_nuxt/*.js
        else
            sed -i "s/127.0.0.1:9090/${host}:${db_port}/g" "$dbdir"/*.html
        fi
        #写入配置文件
        setconfig hostdir "'$hostdir'"
        content_line "\033[32m面板安装成功！\033[0m"
        content_line "\033[36m如未生效，请使用【Ctrl+F5】强制刷新浏览器！\033[0m"
        separator_line "="
        sleep 1
        rm -rf "$TMPDIR"/clashdb.tar.gz
    fi
    sleep 1
}

dbdir() {
    if [ -f /www/clash/CNAME ] || [ -f "$CRASHDIR"/ui/CNAME ]; then
        comp_box "\033[33m检测到已经安装过本地面板\033[0m"
        btm_box "1) 升级/覆盖安装" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " res
        if [ "$res" = 1 ]; then
            rm -rf "$BINDIR"/ui
            [ -f /www/clash/CNAME ] && rm -rf /www/clash && dbdir=/www/clash
            [ -f "$CRASHDIR"/ui/CNAME ] && rm -rf "$CRASHDIR"/ui && dbdir="$CRASHDIR"/ui
            getdb
        else
            msg_alert "\033[33m安装已取消\033[0m"
            return 1
        fi
    elif [ -w /www ] && [ -n "$(pidof nginx)" ]; then
        comp_box "请选择面板\033[33m安装目录：\033[0m"
        btm_box "1) 在${CRASHDIR}/ui目录安装" \
            "2) 在/www/clash目录安装" \
            "" \
            "0) 返回上级菜单"
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            return 0
            ;;
        1)
            dbdir="$CRASHDIR"/ui
            hostdir=": $db_port/ui"
            getdb
            ;;
        2)
            dbdir=/www/clash
            hostdir='/clash'
            getdb
            ;;
        *)
            errornum
            return 1
            ;;
        esac
    else
        dbdir="$CRASHDIR"/ui
        hostdir=":$db_port/ui"
        getdb
    fi
}

setdb() {
    while true; do
        comp_box "\033[36m安装 dashboard 管理面板到本地\033[0m" \
            "\033[32m打开管理面板的速度更快且更稳定\033[0m" \
            "" \
            "请选择面板安装类型："
        content_line "   - - - - - - -维护中- - - - - - -"
        content_line "1) 安装\033[32mzashboard面板\033[0m（约2.2mb）"
        content_line "2) 安装\033[32mMetaXD面板\033[0m（约1.5mb）"
        content_line "3) 安装\033[32mYacd-Meta魔改面板\033[0m（约1.7mb）"
        content_line "   - - - - - -已停止维护- - - - - -"
        content_line "4) 安装\033[32m基础面板\033[0m（约500kb）"
        content_line "5) 安装\033[32mMeta基础面板\033[0m（约800kb）"
        content_line "6) 安装\033[32mYacd面板\033[0m（约1.1mb）"
        content_line "9) \033[31m卸载本地面板\033[0m"
        content_line ""
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            break
            ;;
        1)
            db_type=zashboard
            setconfig external_ui_url "https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip"
            dbdir
            ;;
        2)
            db_type=meta_xd
            setconfig external_ui_url "https://raw.githubusercontent.com/juewuy/ShellCrash/update/bin/dashboard/meta_xd.tar.gz"
            dbdir
            ;;
        3)
            db_type=meta_yacd
            dbdir
            ;;
        4)
            db_type=clashdb
            dbdir
            ;;
        5)
            db_type=meta_db
            dbdir
            ;;
        6)
            db_type=yacd
            dbdir
            ;;
        9)
            while true; do
                comp_box "是否卸载本地面板？"
                btm_box "1) 确认卸载" \
                    "0) 返回上级菜单"
                read -r -p "请输入对应标号> " res
                case "$res" in
                "" | 0)
                    break
                    ;;
                1)
                    rm -rf /www/clash
                    rm -rf "$CRASHDIR"/ui
                    rm -rf "$BINDIR"/ui
                    msg_alert "\033[31m面板已经卸载！\033[0m"
                    break
                    ;;
                *)
                    errornum
                    ;;
                esac
            done
            ;;
        *)
            errornum
            ;;
        esac
    done
}

# 根证书
getcrt() {
    line_break
    separator_line "="
    content_line "正在连接服务器获取安装文件......"
    get_bin "$TMPDIR"/ca-certificates.crt bin/fix/ca-certificates.crt echooff
    if [ "$?" = "1" ]; then
        content_line "\033[31m文件下载失败！\033[0m"
        error_down
    else
        [ "$systype" = 'mi_snapshot' ] && cp -f "$TMPDIR"/ca-certificates.crt "$CRASHDIR"/tools #镜像化设备特殊处理
        [ -f "$openssldir"/certs ] && rm -rf "$openssldir"/certs                                #如果certs不是目录而是文件则删除并创建目录
        mkdir -p "$openssldir"/certs
        mv -f "$TMPDIR"/ca-certificates.crt "$crtdir"
        webget /dev/null https://baidu.com echooff rediron skipceroff
        if [ "$?" = "1" ]; then
            export CURL_CA_BUNDLE="$crtdir"
            echo "export CURL_CA_BUNDLE=$crtdir" >>/etc/profile
        fi
        content_line "\033[32m证书安装成功！\033[0m"
        separator_line "="
        sleep 1
    fi
}

setcrt() {
    while true; do
        openssldir="$(openssl version -d 2>&1 | awk -F '"' '{print $2}')"
        if [ -d "$openssldir/certs/" ]; then
            crtdir="$openssldir/certs/ca-certificates.crt"
        else
            crtdir="/etc/ssl/certs/ca-certificates.crt"
        fi

        if [ -n "$openssldir" ]; then
            line_break
            separator_line "="
            content_line "安装/更新本地根证书文件（ca-certificates.crt）"
            content_line "\033[33m用于解决证书校验错误，x509报错等问题\033[0m"
            content_line "\033[31m无上述问题的设备请勿使用！\033[0m"
            if [ -f "$crtdir" ]; then
                content_line ""
                content_line "\033[33m检测到系统已经存在根证书文件：\033[0m"
                content_line "\033[33m（$crtdir）\033[0m"
            fi
            separator_line "="

            if [ -f "$crtdir" ]; then
                content_line "1) 覆盖更新"
            else
                content_line "1) 立即安装"
            fi
            content_line "0) 返回上级菜单"
            separator_line "="
            read -r -p "请输入对应标号> " res
            case "$res" in
            "" | 0)
                break
                ;;
            1)
                getcrt
                break
                ;;
            *)
                errornum
                continue
                ;;
            esac

        else
            msg_alert "\033[33m设备可能尚未安装openssl，无法安装证书文件！\033[0m"
            break
        fi

    done
}

# 写入配置文件
saveserver() {
    setconfig update_url "'$update_url'"
    setconfig url_id "$url_id"
    setconfig release_type "$release_type"
    version_new=''
    msg_alert -t 0 "\033[32m源地址切换成功！\033[0m"
}

# 安装源
setserver() {
    while true; do
        line_break
        [ -z "$release_type" ] && release_name=未指定
        [ -n "$release_type" ] && release_name="$release_type(回退)"
        [ "$release_type" = stable ] && release_name=稳定版
        [ "$release_type" = master ] && release_name=公测版
        [ "$release_type" = dev ] && release_name=开发版
        [ -n "$url_id" ] && url_name=$(grep "$url_id" "$CRASHDIR"/configs/servers.list 2>/dev/null | awk '{print $2}') || url_name="$update_url"

        comp_box "\033[30;47m切换ShellCrash版本及更新源地址\033[0m" \
            "" \
            "当前版本：\033[4;33m$release_name\033[0m" \
            "当前源：\n\033[4;32m$url_name\033[0m"

        grep -E "^1|$release_name" "$CRASHDIR"/configs/servers.list |
            awk '{print NR") "$2}' |
            while IFS= read -r line; do
                content_line "$line"
            done

        content_line
        content_line "a) 切换至\033[32m稳定版-stable\033[0m"
        content_line "b) 切换至\033[36m公测版-master\033[0m"
        content_line "c) 切换至\033[33m开发版-dev\033[0m"
        content_line
        content_line "d) 自定义源地址（用于本地源或自建源）"
        content_line "e) \033[31m版本回退\033[0m"
        content_line
        content_line "0) 返回上级菜单"
        separator_line "="
        read -r -p "请输入对应标号> " num
        case "$num" in
        "" | 0)
            checkupdate=false
            break
            ;;
        [1-99])
            url_id_new=$(grep -E "^1|$release_name" "$CRASHDIR"/configs/servers.list | sed -n "$num"p | awk '{print $1}')
            if [ -z "$url_id_new" ]; then
                errornum
                sleep 1
                continue
            elif [ "$url_id_new" -ge 200 ]; then
                update_url=$(grep -E "^1|$release_name" "$CRASHDIR"/configs/servers.list | sed -n "$num"p | awk '{print $3}')
                url_id=''
                saveserver
                break
            else
                url_id=$url_id_new
                update_url=''
                saveserver
                break
            fi
            unset url_id_new
            ;;
        a)
            release_type=stable
            [ -z "$url_id" ] && url_id=101
            saveserver
            ;;
        b)
            release_type=master
            [ -z "$url_id" ] && url_id=101
            saveserver
            ;;
        c)
            while true; do
                comp_box "\033[33m开发版未经过妥善测试，可能依然存在大量bug！！！\033[0m" \
                    "\033[33m如果你没有足够的耐心或者测试经验，切勿使用此版本！\033[0m" \
                    "请务必加入我们的讨论组：\033[36;4mhttps://t.me/ShellClash\033[0m"
                content_line "是否依然切换到开发版："
                separator_line "-"
                content_line "1) 确认切换"
                content_line "0) 返回上级菜单"
                separator_line "="
                read -r -p "请输入对应标号> " res
                case "$res" in
                "" | 0)
                    break
                    ;;
                1)
                    release_type=dev
                    [ -z "$url_id" ] && url_id=101
                    saveserver
                    break
                    ;;
                *)
                    errornum
                    ;;
                esac
            done
            ;;
        d)
            comp_box "请直接输入个人源路径" \
                "或者输入 0 返回上级菜单"
            read -r -p "请输入个人源路径> " update_url
            if [ "$update_url" = 0 ]; then
                continue
            elif [ ! -z "$update_url" ]; then
                url_id=''
                release_type=''
                saveserver
            fi
            ;;
        e)
            if [ -n "$url_id" ] && [ "$url_id" -lt 200 ]; then
                line_break
                separator_line "="
                content_line "\033[32m正在获取版本信息......\033[0m"
                . "$CRASHDIR"/libs/web_get_lite.sh
                web_get_lite https://github.com/juewuy/ShellCrash/tags | grep -o 'releases/tag/.*data' | awk -F '/' '{print $3}' | sed 's/".*//g' >"$TMPDIR"/tags
                if [ "$?" = "0" ]; then
                    content_line "\033[32m获取版本信息成功\033[0m"
                    separator_line "="

                    line_break
                    separator_line "="
                    content_line "\033[31m请选择想要回退至的具体版本：\033[0m"

                    cat "$TMPDIR"/tags |
                        awk '{print NR") "$1}' |
                        while IFS= read -r line; do
                            content_line "$line"
                        done

                    content_line
                    content_line "0) 返回上级菜单"
                    read -r -p "请输入对应标号> " num
                    if [ -z "$num" ] || [ "$num" = 0 ]; then
                        continue
                    elif [ "$num" -le $(cat "$TMPDIR"/tags 2>/dev/null | awk 'END{print NR}') ]; then
                        release_type=$(cat "$TMPDIR"/tags | awk '{print $1}' | sed -n "$num"p)
                        update_url=''
                        saveserver
                    else
                        errornum
                        continue
                    fi
                else
                    content_line "\033[31m版本回退信息获取失败，请尝试更换其他安装源！\033[0m"
                    separator_line "="
                    sleep 1
                    continue
                fi
                rm -rf "$TMPDIR"/tags
            else
                msg_alert "\033[31m当前源不支持版本回退\033[0m" \
                    "\033[31m请尝试更换其他安装源！\033[0m"
                continue
            fi
            ;;
        *)
            errornum
            ;;
        esac
    done
}
