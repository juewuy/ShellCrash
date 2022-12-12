#!/bin/bash
# Copyright (C) Juewuy

#导入订阅、配置文件相关
linkconfig(){
	echo -----------------------------------------------
	echo 当前使用规则为：$rule_link
	echo " 1	Acl4SSR全能优化版（推荐）"
	echo " 2	Acl4SSR精简优化版（推荐）"
	echo " 3	Acl4SSR全能优化+去广告增强"
	echo " 4	Acl4SSR极简版（适合自建节点）"
	echo " 5	Acl4SSR分流&游戏增强"
	echo " 6	Acl4SSR分流&游戏&去广告增强（低性能设备慎用）"
	echo " 7	洞主规则精简版（推荐）"
	echo " 8	洞主规则重度完整版"
	echo " 9	神机规则高级版"
	echo " 10	神机规则-回国专用"
	echo " 11	李哥规则-墙洞专用"
	echo -----------------------------------------------
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	if [ -z "$num" ] || [ "$num" -gt 17 ];then
		errornum
	elif [ "$num" = 0 ];then
		echo 
	elif [ "$num" -le 17 ];then
		#将对应标记值写入mark
		rule_link=$num
		setconfig rule_link $rule_link
		echo -----------------------------------------------	  
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
linkserver(){
	echo -----------------------------------------------
	echo -e "\033[36m以下为互联网采集的第三方服务器，具体安全性请自行斟酌！\033[0m"
	echo -e "\033[32m感谢以下作者的无私奉献！！！\033[0m"
	echo 当前使用后端为：$server_link
	echo 1 api.dler.io			（墙洞提供）
	echo 2 api.v1.mk			（肥羊提供,支持vless）
	echo 3 sub.xeton.dev		（SUB作者提供）
	echo 4 v.id9.cc				（品云提供,支持vless）
	echo 5 sub.maoxiongnet.com	（猫熊提供）
	echo -----------------------------------------------
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	if [ -z "$num" ] || [ "$num" -gt 5 ];then
		errornum
	elif [ "$num" = 0 ];then
		echo
	elif [ "$num" -le 5 ];then
		#将对应标记值写入mark
		server_link=$num
		setconfig server_link $server_link
		echo -----------------------------------------------	  
		echo -e "\033[32m设置成功！返回上级菜单\033[0m"
	fi
}
linkfilter(){
	[ -z "$exclude" ] && exclude="未设置"
	echo -----------------------------------------------
	echo -e "\033[33m当前过滤关键字：\033[47;30m$exclude\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m匹配关键字的节点会在导入时被【屏蔽】！！！\033[0m"
	echo -e "多个关键字可以用\033[30;47m | \033[0m号分隔"
	echo -e "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	echo -----------------------------------------------
	echo -e " 000   \033[31m删除\033[0m关键字"
	echo -e " 回车  取消输入并返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入关键字 > " exclude
	if [ "$exclude" = '000' ]; then
		echo -----------------------------------------------
		exclude=''
		echo -e "\033[31m 已删除节点过滤关键字！！！\033[0m"
	fi
	setconfig exclude \'$exclude\'
}
linkfilter2(){
	[ -z "$include" ] && include="未设置"
	echo -----------------------------------------------
	echo -e "\033[33m当前筛选关键字：\033[47;30m$include\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m仅有匹配关键字的节点才会被【导入】！！！\033[0m"
	echo -e "多个关键字可以用\033[30;47m | \033[0m号分隔"
	echo -e "\033[32m支持正则表达式\033[0m，空格请使用\033[30;47m + \033[0m号替代"
	echo -----------------------------------------------
	echo -e " 000   \033[31m删除\033[0m关键字"
	echo -e " 回车  取消输入并返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入关键字 > " include
	if [ "$include" = '000' ]; then
		echo -----------------------------------------------
		include=''
		echo -e "\033[31m 已删除节点匹配关键字！！！\033[0m"
	fi
	setconfig include \'$include\'
}
getyaml(){
	$clashdir/start.sh getyaml
	if [ "$?" = 0 ];then
		if [ "$inuserguide" != 1 ];then
			read -p "是否启动clash服务以使配置文件生效？(1/0) > " res 
			[ "$res" = 1 ] && clashstart || clashsh
			exit;
		fi
	fi
}
getlink(){
	echo -----------------------------------------------
	echo -e "\033[30;47m 欢迎使用在线生成配置文件功能！\033[0m"
	echo -----------------------------------------------
	#设置输入循环
	i=1
	while [ $i -le 99 ]
	do
		echo -----------------------------------------------
		echo -e "\033[33m本功能依赖第三方在线subconverter服务实现，脚本本身不提供任何代理服务！\033[0m"
		echo -e "\033[31m严禁使用本脚本从事任何非法活动，否则一切后果请自负！\033[0m"
		echo -----------------------------------------------
		echo -e "支持批量(<=99)导入订阅链接、分享链接"
		echo -----------------------------------------------
		echo -e " 1 \033[36m开始生成配置文件\033[0m（原文件将被备份）"
		echo -e " 2 设置\033[31m节点过滤\033[0m关键字 \033[47;30m$exclude\033[0m"
		echo -e " 3 设置\033[32m节点筛选\033[0m关键字 \033[47;30m$include\033[0m"
		echo -e " 4 选取在线\033[33m配置规则模版\033[0m"
		echo -e " 5 \033[0m选取在线生成服务器\033[0m"
		echo -e " 0 \033[31m撤销输入并返回上级菜单\033[0m"
		echo -----------------------------------------------
		read -p "请直接输入第${i}个链接或对应数字选项 > " link
		test=$(echo $link | grep "://")
		link=`echo ${link/\#*/''}`   #删除链接附带的注释内容
		link=`echo ${link/\ \(*\)/''}`   #删除恶心的超链接内容
		link=`echo ${link/*\&url\=/""}`   #将clash完整链接还原成单一链接
		link=`echo ${link/\&config\=*/""}`   #将clash完整链接还原成单一链接
		link=`echo ${link//\&/\%26}`   #将分隔符 & 替换成urlcode：%26
		if [ -n "$test" ];then
			if [ -z "$Url_link" ];then
				Url_link="$link"
			else
				Url_link="$Url_link"\|"$link"
			fi
			i=$((i+1))
				
		elif [ "$link" = '1' ]; then
			if [ -n "$Url_link" ];then
				i=100
				#将用户链接写入mark
				sed -i '/Https=*/'d $ccfg
				setconfig Url \'$Url_link\'
				Https=""
				#获取在线yaml文件
				getyaml
			else
				echo -----------------------------------------------
				echo -e "\033[31m请先输入订阅或分享链接！\033[0m"
				sleep 1
			fi
			
		elif [ "$link" = '2' ]; then
			linkfilter
			
		elif [ "$link" = '3' ]; then
			linkfilter2
			
		elif [ "$link" = '4' ]; then
			linkconfig
			
		elif [ "$link" = '5' ]; then
			linkserver
			
		elif [ "$link" = 0 ];then
			Url_link=""
			i=100
			
		else
			echo -----------------------------------------------
			echo -e "\033[31m请输入正确的链接或者数字！\033[0m"
			sleep 1
		fi
	done
} 
getlink2(){
	echo -----------------------------------------------
	echo -e "\033[32m仅限导入完整clash配置文件链接！！！\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m有流媒体需求，请使用\033[32m6-1在线生成配置文件功能！！！\033[0m"
	echo -e "\033[33m如不了解机制，请使用\033[32m6-1在线生成配置文件功能！！！\033[0m"
	echo -e "\033[33m如遇任何问题，请使用\033[32m6-1在线生成配置文件功能！！！\033[0m"
	echo -e "\033[31m此功能可能会导致部分节点无法连接或者规则覆盖不完整！！！\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m0 返回上级菜单\033[0m"
	echo -----------------------------------------------
	read -p "请输入完整链接 > " link
	test=$(echo $link | grep -iE "tp.*://" )
	link=`echo ${link/\ \(*\)/''}`   #删除恶心的超链接内容
	link=`echo ${link//\&/\\\&}`   #处理分隔符
	if [ -n "$link" -a -n "$test" ];then
		echo -----------------------------------------------
		echo -e 请检查输入的链接是否正确：
		echo -e "\033[4;32m$link\033[0m"
		read -p "确认导入配置文件？原配置文件将被更名为config.yaml.bak![1/0] > " res
			if [ "$res" = '1' ]; then
				#将用户链接写入mark
				sed -i '/Url=*/'d $ccfg
				setconfig Https \'$link\'
				#获取在线yaml文件
				getyaml
			else
				getlink2
			fi
	elif [ "$link" = 0 ];then
		i=
	else
		echo -----------------------------------------------
		echo -e "\033[31m请输入正确的配置文件链接地址！！！\033[0m"
		echo -e "\033[33m仅支持http、https、ftp以及ftps链接！\033[0m"
		sleep 1
		getlink2
	fi
}
clashlink(){
	[ -z "$rule_link" ] && rule_link=1
	[ -z "$server_link" ] && server_link=1
	echo -----------------------------------------------
	echo -e "\033[30;47m 欢迎使用导入配置文件功能！\033[0m"
	echo -----------------------------------------------
	echo -e " 1 在线\033[32m生成Clash配置文件\033[0m"
	echo -e " 2 导入\033[33mClash配置文件链接\033[0m"
	echo -e " 3 \033[36m还原\033[0m配置文件"
	echo -e " 4 \033[33m更新\033[0m配置文件"
	echo -e " 5 设置\033[36m自动更新\033[0m"
	echo -----------------------------------------------
	[ "$inuserguide" = 1 ] || echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ];then
		errornum
	elif [ "$num" = 0 ];then
		i=
	elif [ "$num" = 1 ];then
		if [ -n "$Url" ];then
			echo -----------------------------------------------
			echo -e "\033[33m检测到已记录的链接内容：\033[0m"
			echo -e "\033[4;32m$Url\033[0m"
			echo -----------------------------------------------
			read -p "清空链接/追加导入？[1/0] > " res
			if [ "$res" = '1' ]; then
				Url_link=""
				echo -----------------------------------------------
				echo -e "\033[31m链接已清空！\033[0m"
			else
				Url_link=$Url
			fi
		fi
		getlink
	  
	elif [ "$num" = 2 ];then
		echo -----------------------------------------------
		echo -e "\033[33m此功能可能会导致严重bug！！！\033[0m"
		sleep 1
		echo -----------------------------------------------
		echo -e "强烈建议你使用\033[32m在线生成配置文件功能！\033[0m"
		sleep 1
		echo -----------------------------------------------
		echo -e "\033[33m继续后如出现任何问题，请务必自行解决，一切提问恕不受理！\033[0m"
		echo -----------------------------------------------
		sleep 2
		read -p "我确认遇到问题可以自行解决[1/0] > " res
		if [ "$res" = '1' ]; then
			getlink2
		else
			echo -----------------------------------------------
			echo -e "\033[32m正在跳转……\033[0m"
			sleep 1
			getlink
		fi
		
	elif [ "$num" = 3 ];then
		yamlbak=$yaml.bak
		if [ ! -f "$yaml".bak ];then
			echo -----------------------------------------------
			echo -e "\033[31m没有找到配置文件的备份！\033[0m"
			clashlink
		else
			echo -----------------------------------------------
			echo -e 备份文件共有"\033[32m`wc -l < $yamlbak`\033[0m"行内容，当前文件共有"\033[32m`wc -l < $yaml`\033[0m"行内容
			read -p "确认还原配置文件？此操作不可逆！[1/0] > " res
			if [ "$res" = '1' ]; then
				mv $yamlbak $yaml
				echo -----------------------------------------------
				echo -e "\033[32m配置文件已还原！请手动重启clash服务！\033[0m"
				sleep 1
			else 
				echo -----------------------------------------------
				echo -e "\033[31m操作已取消！返回上级菜单！\033[0m"
				clashlink
			fi
		fi
		
	elif [ "$num" = 4 ];then
		if [ -z "$Url" -a -z "$Https" ];then
			echo -----------------------------------------------
			echo -e "\033[31m没有找到你的配置文件/订阅链接！请先输入链接！\033[0m"
			sleep 1
			clashlink
		else
			echo -----------------------------------------------
			echo -e "\033[33m当前系统记录的链接为：\033[0m"
			echo -e "\033[4;32m$Url$Https\033[0m"
			echo -----------------------------------------------
			read -p "确认更新配置文件？[1/0] > " res
			if [ "$res" = '1' ]; then
				getyaml
			else
				clashlink
			fi
		fi
		
	elif [ "$num" = 5 ];then
		clashcron
	else
		errornum
	fi
}
#下载更新相关
gettar(){
	$clashdir/start.sh webget /tmp/clashfm.tar.gz $tarurl
	[ "$?" != "0" ] && echo "文件下载失败,请尝试使用其他安装源！" && exit 1
	$clashdir/start.sh stop 2>/dev/null
	#解压
	echo -----------------------------------------------
	echo 开始解压文件！
	mkdir -p $clashdir > /dev/null
	tar -zxvf '/tmp/clashfm.tar.gz' -C $clashdir/
	[ $? -ne 0 ] && echo "文件解压失败！" && rm -rf /tmp/clashfm.tar.gz && exit 1 
	#初始化文件目录
	[ -f "$clashdir/mark" ] || echo '#标识clash运行状态的文件，不明勿动！' > $clashdir/mark
	#判断系统类型写入不同的启动文件
	if [ -f /etc/rc.common ];then
			#设为init.d方式启动
			cp -f $clashdir/clashservice /etc/init.d/clash
			chmod +x /etc/init.d/clash
	else
		[ -w /etc/systemd/system ] && sysdir=/etc/systemd/system
		[ -w /usr/lib/systemd/system ] && sysdir=/usr/lib/systemd/system
		if [ -n "$sysdir" ];then
			#设为systemd方式启动
			mv $clashdir/clash.service $sysdir/clash.service
			sed -i "s%/etc/clash%$clashdir%g" $sysdir/clash.service
			systemctl daemon-reload
		else
			#设为保守模式启动
			setconfig start_old 已开启
		fi
	fi
	#修饰文件及版本号
	shtype=sh && command -v bash &>/dev/null && shtype=bash 
	sed -i "s|/bin/sh|/bin/$shtype|" $clashdir/start.sh
	chmod +x $clashdir/start.sh
	setconfig versionsh_l $release_new
	#设置更新地址
	[ -n "$url" ] && setconfig update_url $url
	#设置环境变量	
	[ -w /opt/etc/profile ] && profile=/opt/etc/profile
	[ -w /jffs/configs/profile.add ] && profile=/jffs/configs/profile.add
	[ -w ~/.bashrc ] && profile=~/.bashrc
	[ -w /etc/profile ] && profile=/etc/profile
	if [ -n "$profile" ];then
		sed -i '/alias clash=*/'d $profile
		echo "alias clash=\"$shtype $clashdir/clash.sh\"" >> $profile #设置快捷命令环境变量
		sed -i '/export clashdir=*/'d $profile
		echo "export clashdir=\"$clashdir\"" >> $profile #设置clash路径环境变量
		#适配zsh环境变量
		[ -n "$(ls -l /bin/sh|grep -oE 'zsh')" ] && { 
			echo "alias clash=\"$shtype $clashdir/clash.sh\"" >> ~/.zshrc
			echo "export clashdir=\"$clashdir\"" >> ~/.zshrc
		}
	else
		echo 无法写入环境变量！请检查安装权限！
		exit 1
	fi
	#梅林/Padavan额外设置
	[ -n "$initdir" ] && {
		sed -i '/ShellClash初始化/'d $initdir
		touch $initdir
		echo "$clashdir/start.sh init #ShellClash初始化脚本" >> $initdir
		setconfig initdir $initdir
		}
	#小米镜像化OpenWrt额外设置
	if [ "$systype" = "mi_snapshot" ];then
		chmod +x $clashdir/misnap_init.sh
		uci set firewall.ShellClash=include
		uci set firewall.ShellClash.type='script'
		uci set firewall.ShellClash.path='/data/clash/misnap_init.sh'
		uci set firewall.ShellClash.enabled='1'
		uci commit firewall
		setconfig systype $systype
	else
		rm -rf $clashdir/misnap_init.sh
		rm -rf $clashdir/clashservice
	fi
	#删除临时文件
	rm -rf /tmp/clashfm.tar.gz 
	rm -rf $clashdir/clash.service
}

getsh(){
	echo -----------------------------------------------
	echo -e "当前脚本版本为：\033[33m $versionsh_l \033[0m"
	echo -e "最新脚本版本为：\033[32m $release_new \033[0m"
	echo -e "注意更新时会停止clash服务！"
	echo -----------------------------------------------
	read -p "是否更新脚本？[1/0] > " res
	if [ "$res" = '1' ]; then
		tarurl=$update_url/bin/clashfm.tar.gz
		#下载更新
		gettar
		#提示
		echo -----------------------------------------------
		echo -e "\033[32m管理脚本更新成功!\033[0m"
		echo -----------------------------------------------
		exit;
	fi
}
getcpucore(){
	cputype=$(uname -ms | tr ' ' '_' | tr '[A-Z]' '[a-z]')
	[ -n "$(echo $cputype | grep -E "linux.*armv.*")" ] && cpucore="armv5"
	[ -n "$(echo $cputype | grep -E "linux.*armv7.*")" ] && [ -n "$(cat /proc/cpuinfo | grep vfp)" ] && [ ! -d /jffs/clash ] && cpucore="armv7"
	[ -n "$(echo $cputype | grep -E "linux.*aarch64.*|linux.*armv8.*")" ] && cpucore="armv8"
	[ -n "$(echo $cputype | grep -E "linux.*86.*")" ] && cpucore="386"
	[ -n "$(echo $cputype | grep -E "linux.*86_64.*")" ] && cpucore="amd64"
	if [ -n "$(echo $cputype | grep -E "linux.*mips.*")" ];then
		mipstype=$(echo -n I | hexdump -o 2>/dev/null | awk '{ print substr($2,6,1); exit}') #通过判断大小端判断mips或mipsle
		[ "$mipstype" = "0" ] && cpucore="mips-softfloat" || cpucore="mipsle-softfloat"
	fi
	[ -n "$cpucore" ] && setconfig cpucore $cpucore
}
setcpucore(){
	cpucore_list="armv5 armv7 armv8 386 amd64 mipsle-softfloat mipsle-hardfloat mips-softfloat"
	echo -----------------------------------------------
	echo -e "\033[31m仅适合脚本无法正确识别核心或核心无法正常运行时使用！\033[0m"
	echo -e "当前可供在线下载的处理器架构为："
	echo $cpucore_list | awk -F " " '{for(i=1;i<=NF;i++) {print i" "$i }}'
	echo -e "如果您的CPU架构未在以上列表中，请运行【uname -a】命令,并复制好返回信息"
	echo -e "之后前往 t.me/ShellClash 群提交或 github.com/juewuy/ShellClash 提交issue"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	setcpucore=$(echo $cpucore_list | awk '{print $"'"$num"'"}' )
	if [ -z "$setcpucore" ];then
		echo -e "\033[31m请输入正确的处理器架构！\033[0m"
		sleep 1
		cpucore=""
	else
		cpucore=$setcpucore
		setconfig cpucore $cpucore
	fi
}
getcore(){
	[ -z "$clashcore" ] && clashcore=clashpre
	[ -z "$cpucore" ] && getcpucore
	#生成链接
	corelink="$update_url/bin/$clashcore/clash-linux-$cpucore"
	#获取在线clash核心文件
	echo -----------------------------------------------
	echo 正在在线获取clash核心文件……
	$clashdir/start.sh webget /tmp/clash.new $corelink
	if [ "$?" = "1" ];then
		echo -e "\033[31m核心文件下载失败！\033[0m"
		rm -rf /tmp/clash.new
	else
		chmod +x /tmp/clash.new && /tmp/clash.new -v >/dev/null 2>&1
		if [ "$?" != 0 ];then
			echo -e "\033[31m核心文件下载失败！\033[0m"
			rm -rf /tmp/clash.new
		else
			echo -e "\033[32m$clashcore核心下载成功！\033[0m"
			mv -f /tmp/clash.new $bindir/clash
			chmod +x $bindir/clash 
			setconfig clashcore $clashcore
			setconfig clashv $version
		fi
	fi
}
setcore(){
	#获取核心及版本信息
	[ ! -f $clashdir/clash ] && clashcore="未安装核心"
	###
	echo -----------------------------------------------
	[ -z "$cpucore" ] && getcpucore
	echo -e "当前clash核心：\033[42;30m $clashcore \033[47;30m$clashv\033[0m"
	echo -e "当前系统处理器架构：\033[32m $cpucore \033[0m"
	echo -e "\033[33m请选择需要使用的核心版本！\033[0m"
	echo -----------------------------------------------
	echo -e "1 \033[43;30m  Clash  \033[0m：	\033[32m占用低\033[0m"
	echo -e " (官方基础版)  \033[33m不支持Tun、Rule-set等\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://lancellc.gitbook.io\033[0m"
	echo
	echo -e "2 \033[43;30m Clashpre \033[0m：	\033[32m支持Tun、Rule-set、域名嗅探\033[0m"
	echo -e " (官方高级版)  \033[33m不支持vless、hy协议\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://lancellc.gitbook.io\033[0m"
	echo
	echo -e "3 \033[43;30mClash.Meta\033[0m：	\033[32m多功能，支持最全面\033[0m"
	echo -e " (Meta定制版)  \033[33m第三方定制内核\033[0m"
	echo -e "  说明文档：	\033[36;4mhttps://docs.metacubex.one\033[0m"
	echo
	echo "5 手动指定处理器架构"
	echo -----------------------------------------------
	echo 0 返回上级菜单 
	read -p "请输入对应数字 > " num
		if [ -z "$num" ]; then
			errornum
		elif [ "$num" = 0 ]; then
			i=
		elif [ "$num" = 1 ]; then
			clashcore=clash
			version=$clash_v
			getcore
		elif [ "$num" = 2 ]; then
			clashcore=clashpre
			version=$clashpre_v
			getcore
		elif [ "$num" = 3 ]; then
			clashcore=clash.meta
			version=$meta_v
			getcore
		elif [ "$num" = 5 ]; then
			setcpucore
			setcore
		else
			errornum
			update
		fi
}
getgeo(){
	echo -----------------------------------------------
	echo 正在从服务器获取数据库文件…………
	$clashdir/start.sh webget /tmp/$geoname $update_url/bin/$geotype
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		exit 1
	else
		mv -f /tmp/$geoname $bindir/$geoname
		echo -----------------------------------------------
		echo -e "\033[32mGeoIP/CN_IP数据库文件下载成功！\033[0m"
		Geo_v=$GeoIP_v
		setconfig Geo_v $GeoIP_v
		if [ "$geoname" = "Country.mmdb" ];then
			geotype=$geotype
			setconfig geotype $geotype
		fi
	fi
}
setgeo(){
	echo -----------------------------------------------
	[ "$geotype" = "cn_mini.mmdb" ] && echo -e "当前使用的是\033[47;30m精简版数据库\033[0m" || echo -e "当前使用的是\033[47;30m全球版数据库\033[0m"
	echo -e "\033[36m请选择需要更新/切换的GeoIP/CN_IP数据库：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 由\033[32malecthw\033[0m提供的全球版GeoIP数据库(约6mb)"
	echo -e " 2 由\033[32mHackl0us\033[0m提供的精简版CN-IP数据库(约0.2mb)"
	echo -e " 3 由\033[32m17mon\033[0m提供的CN-IP文件(需启用CN_IP绕过内核功能，约0.2mb)"
	[ "$clashcore" = "clash.meta" ] && \
	echo -e " 4 由\033[32mLoyalsoldier\033[0m提供的GeoSite数据库(限Meta内核，约4.5mb)"
	echo " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ "$num" = '1' ]; then
		geotype=Country.mmdb
		geoname=Country.mmdb
		getgeo
	elif [ "$num" = '2' ]; then
		geotype=cn_mini.mmdb
		geoname=Country.mmdb
		getgeo
	elif [ "$num" = '3' ]; then
		if [ "$cn_ip_route" = "已开启" ]; then
			geotype=china_ip_list.txt
			geoname=cn_ip.txt
			getgeo
		else
			echo -----------------------------------------------
			echo -e "\033[31m未开启绕过内核功能，无需更新CN-IP文件！！\033[0m"	
			sleep 1
		fi
	elif [ "$num" = '4' ]; then
		geotype=geosite.dat
		geoname=geosite.dat
		getgeo
	else
		update
	fi
}
getdb(){
	#下载及安装
	if [ -d /www/clash -o -d $clashdir/ui ];then
		echo -----------------------------------------------
		echo -e "\033[31m检测到您已经安装过本地面板了！\033[0m"
		echo -----------------------------------------------
		read -p "是否覆盖安装？[1/0] > " res
		if [ "$res" = 1 ]; then
			rm -rf /www/clash
			rm -rf $clashdir/ui
			rm -rf $bindir/ui
		fi
	fi
	dblink="${update_url}/bin/${db_type}.tar.gz"
	echo -----------------------------------------------
	echo 正在连接服务器获取安装文件…………
	$clashdir/start.sh webget /tmp/clashdb.tar.gz $dblink
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		echo -----------------------------------------------
		setdb
	else
		echo -e "\033[33m下载成功，正在解压文件！\033[0m"
		mkdir -p $dbdir > /dev/null
		tar -zxvf "/tmp/clashdb.tar.gz" -C $dbdir > /dev/null
		if [ $? -ne 0 ];then
			tar -zxvf "/tmp/clashdb.tar.gz" --no-same-permissions -C $dbdir > /dev/null
			[ $? -ne 0 ] && echo "文件解压失败！" && rm -rf /tmp/clashfm.tar.gz && exit 1 
		fi
		#修改默认host和端口
		if [ "$db_type" = "clashdb" -o "$db_type" = "meta_db" ];then
			sed -i "s/127.0.0.1/${host}/g" $dbdir/assets/*.js
			sed -i "s/9090/${db_port}/g" $dbdir/assets/*.js
		else
			sed -i "s/127.0.0.1:9090/${host}:${db_port}/g" $dbdir/*.html
			#sed -i "s/7892/${db_port}/g" $dbdir/app*.js
		fi
		#写入配置文件
		setconfig hostdir \'$hostdir\'
		echo -----------------------------------------------
		echo -e "\033[32m面板安装成功！\033[0m"
		rm -rf /tmp/clashdb.tar.gz
		sleep 1
	fi
}
setdb(){
	dbdir(){
		if [ -w /www -a -n "$(pidof nginx)" ];then
			echo -----------------------------------------------
			echo -e "请选择面板\033[33m安装目录：\033[0m"
			echo -----------------------------------------------
			echo -e " 1 在$clashdir/ui目录安装"
			echo -e " 2 在/www/clash目录安装"
			echo -----------------------------------------------
			echo " 0 返回上级菜单"
			read -p "请输入对应数字 > " num

			if [ "$num" = '1' ]; then
				dbdir=$clashdir/ui
				hostdir=":$db_port/ui"
			elif [ "$num" = '2' ]; then
				dbdir=/www/clash
				hostdir='/clash'
			else
				setdb
			fi
		else
				dbdir=$clashdir/ui
				hostdir=":$db_port/ui"
		fi
	}

	echo -----------------------------------------------
	echo -e "\033[36m安装本地版dashboard管理面板\033[0m"
	echo -e "\033[32m打开管理面板的速度更快且更稳定\033[0m"
	echo -----------------------------------------------
	echo -e "请选择面板\033[33m安装类型：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 安装\033[32m官方面板\033[0m(约500kb)"
	echo -e " 2 安装\033[32mMeta面板\033[0m(约800kb)"
	echo -e " 3 安装\033[32mYacd面板\033[0m(约1.1mb)"
	echo -e " 4 安装\033[32mYacd-Meta魔改面板\033[0m(约1.5mb)"
	echo -e " 5 卸载\033[33m本地面板\033[0m"
	echo " 0 返回上级菜单"
	read -p "请输入对应数字 > " num

	if [ "$num" = '1' ]; then
		db_type=clashdb
		dbdir
		getdb
	elif [ "$num" = '2' ]; then
		db_type=meta_db
		dbdir
		getdb
	elif [ "$num" = '3' ]; then
		db_type=yacd
		dbdir
		getdb
	elif [ "$num" = '4' ]; then
		db_type=meta_yacd
		dbdir
		getdb
	elif [ "$num" = '5' ]; then
		read -p "确认卸载本地面板？(1/0) > " res
		if [ "$res" = 1 ];then
			rm -rf /www/clash
			rm -rf $clashdir/ui
			rm -rf $bindir/ui
			echo -----------------------------------------------
			echo -e "\033[31m面板已经卸载！\033[0m"
			sleep 1
		fi
	else
		errornum
	fi
}
getcrt(){
	crtlink="${update_url}/bin/ca-certificates.crt"
	echo -----------------------------------------------
	echo 正在连接服务器获取安装文件…………
	$clashdir/start.sh webget /tmp/ca-certificates.crt $crtlink
	if [ "$?" = "1" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
	else
		echo -----------------------------------------------
		mv -f /tmp/ca-certificates.crt $crtdir
		$clashdir/start.sh webget /tmp/ssl_test https://baidu.com echooff rediron skipceroff
		if [ "$?" = "1" ];then
			export CURL_CA_BUNDLE=$crtdir
			echo "export CURL_CA_BUNDLE=$crtdir" >> /etc/profile
		fi
		rm -rf /tmp/ssl_test
		echo -e "\033[32m证书安装成功！\033[0m"
		sleep 1
	fi
}
setcrt(){
	openssldir=$(openssl version -a 2>&1 | grep OPENSSLDIR | awk -F "\"" '{print $2}')
	[ -z "$openssldir" ] && openssldir=/etc/ssl
	if [ -n "$openssldir" ];then
		crtdir="$openssldir/certs/ca-certificates.crt"
		echo -----------------------------------------------
		echo -e "\033[36m安装/更新本地根证书文件(ca-certificates.crt)\033[0m"
		echo -e "\033[33m用于解决证书校验错误，x509报错等问题\033[0m"
		echo -e "\033[31m无上述问题的设备请勿使用！\033[0m"
		echo -----------------------------------------------
		[ -f "$crtdir" ] && echo -e "\033[33m检测到系统已经安装根证书文件了！\033[0m\n-----------------------------------------------"
		read -p "确认安装？(1/0) > " res

		if [ -z "$res" ];then
			errornum
		elif [ "$res" = '0' ]; then
			i=
		elif [ "$res" = '1' ]; then
			getcrt
		else
			errornum
		fi
	else
		echo -----------------------------------------------
		echo -e "\033[33m设备可能尚未安装openssl，无法安装证书文件！\033[0m"
		sleep 1
	fi
}
setserver(){
	saveserver(){
		#写入mark文件
		setconfig update_url \'$update_url\'
		setconfig release_url \'$release_url\'
		echo -----------------------------------------------
		echo -e "\033[32m源地址更新成功！\033[0m"
		release_new=""
	}
	echo -----------------------------------------------
	echo -e "\033[30;47m切换ShellClash版本及更新源地址\033[0m"
	echo -e "当前源地址：\033[4;32m$update_url\033[0m"
	echo -----------------------------------------------
	echo -e " 1 \033[33m稳定版\033[0m&Jsdelivr-CDN源"
	echo -e " 2 \033[33m稳定版\033[0m&Github源(须clash服务启用)"
	echo -e " 3 \033[32m公测版\033[0m&Github源(须clash服务启用)"
	echo -e " 4 \033[32m公测版\033[0m&ShellClash私人源"
	echo -e " 5 \033[32m公测版\033[0m&Jsdelivr-CDN源(推荐)"
	echo -e " 7 \033[31m内测版\033[0m(请加TG讨论组:\033[4;36mhttps://t.me/ShellClash\033[0m)"
	echo -e " 8 自定义源地址(用于本地源或自建源)"
	echo -e " 9 \033[31m版本回退\033[0m"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	if	[ -z "$num" ]; then 
		errornum
	elif [ "$num" = 1 ]; then
		release_url='https://fastly.jsdelivr.net/gh/juewuy/ShellClash'
		saveserver
	elif [ "$num" = 2 ]; then
		release_url='https://raw.githubusercontent.com/juewuy/ShellClash'
		saveserver
	elif [ "$num" = 3 ]; then
		update_url='https://raw.githubusercontent.com/juewuy/ShellClash/master'
		release_url=''
		saveserver
	elif [ "$num" = 4 ]; then
		update_url='https://gh.shellclash.cf/master'
		release_url=''
		saveserver
	elif [ "$num" = 5 ]; then
		update_url='https://fastly.jsdelivr.net/gh/juewuy/ShellClash@master'
		release_url=''
		saveserver
	elif [ "$num" = 6 ]; then
		update_url='https://raw.staticdn.net/juewuy/ShellClash/master'
		release_url=''
		saveserver
	elif [ "$num" = 7 ]; then
		update_url='http://test.shellclash.cf'
		release_url=''
		saveserver
	elif [ "$num" = 8 ]; then
		echo -----------------------------------------------
		read -p "请输入个人源路径 > " update_url
		if [ -z "$update_url" ];then
			echo -----------------------------------------------
			echo -e "\033[31m取消输入，返回上级菜单\033[0m"
		else
			saveserver
			release_url=''
		fi
	elif [ "$num" = 9 ]; then
		echo -----------------------------------------------
		echo -e "\033[33m如无法连接，请务必先启用clash服务！！！\033[0m"
		$clashdir/start.sh webget /tmp/clashrelease https://raw.githubusercontent.com/juewuy/ShellClash/master/bin/release_version echooff rediroff 2>/tmp/clashrelease
		echo -e "\033[31m请选择想要回退至的release版本：\033[0m"
		cat /tmp/clashrelease | awk '{print " "NR" "$1}'
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" -o "$num" = 0 ]; then
			setserver
		elif [ $num -le $(cat /tmp/clashrelease | awk 'END{print NR}') 2>/dev/null ]; then
			release_version=$(cat /tmp/clashrelease | awk '{print $1}' | sed -n "$num"p)
			update_url="https://raw.githubusercontent.com/juewuy/ShellClash/$release_version"
			saveserver
			release_url=''
		else
			echo -----------------------------------------------
			echo -e "\033[31m输入有误，请重新输入！\033[0m"
		fi
		rm -rf /tmp/clashrelease
	else
		errornum
	fi
}
checkupdate(){
if [ -z "$release_new" ];then
	if [ -n "$release_url" ];then
		[ -n "$(echo $release_url|grep 'jsdelivr')" ] && check_url=$release_url@master || check_url=$release_url/master
		$clashdir/start.sh webget /tmp/clashversion $check_url/bin/release_version echoon rediroff 2>/tmp/clashversion
		release_new=$(cat /tmp/clashversion | head -1)
		[ -n "$(echo $release_url|grep 'jsdelivr')" ] && update_url=$release_url@$release_new || update_url=$release_url/$release_new
		setconfig update_url \'$update_url\'
		release_type=正式版
	else
		release_type=测试版
	fi	
	$clashdir/start.sh webget /tmp/clashversion $update_url/bin/version echooff 
	[ "$?" = "0" ] && release_new=$(cat /tmp/clashversion | grep -oE 'versionsh=.*' | awk -F'=' '{ print $2 }')
	[ -n "$release_new" ] && source /tmp/clashversion 2>/dev/null || echo -e "\033[31m检查更新失败！请检查网络连接或切换安装源！\033[0m"
	rm -rf /tmp/clashversion
fi
}
update(){
	echo -----------------------------------------------
	echo -ne "\033[32m正在检查更新！\033[0m\r"
	checkupdate
	[ "$clashcore" = "clash" ] && clash_n=$clash_v || clash_n=$clashpre_v
	[ "$clashcore" = "clashpre" ] && clash_n=$clashpre_v
	[ "$clashcore" = "clash.net" ] && clash_n=$clashnet_v
	[ "$clashcore" = "clash.meta" ] && clash_n=$meta_v
	clash_v=$($bindir/clash -v 2>/dev/null | sed 's/ linux.*//;s/.* //')
	[ -z "$clash_v" ] && clash_v=$clashv
	echo -e "\033[30;47m欢迎使用更新功能：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 更新\033[36m管理脚本  	\033[33m$versionsh_l\033[0m > \033[32m$versionsh$release_type\033[0m"
	echo -e " 2 切换\033[33mclash核心 	\033[33m$clash_v\033[0m > \033[32m$clash_n\033[0m"
	echo -e " 3 更新\033[32mGeoIP/CN-IP	\033[33m$Geo_v\033[0m > \033[32m$GeoIP_v\033[0m"
	echo -e " 4 安装本地\033[35mDashboard\033[0m面板"
	echo -e " 5 安装/更新本地\033[33m根证书文件\033[0m"
	echo -e " 6 查看\033[32mPAC\033[0m自动代理配置"
	echo -----------------------------------------------
	echo -e " 7 切换\033[36m安装源\033[0m及\033[36m安装版本\033[0m"
	echo -e " 8 鸣谢"
	echo -e " 9 \033[31m卸载\033[34mShellClash\033[0m"
	echo -e " 0 返回上级菜单" 
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
	elif [ "$num" = 0 ]; then
		i=
	elif [ "$num" = 1 ]; then	
		getsh	

	elif [ "$num" = 2 ]; then	
		setcore
		update
		
	elif [ "$num" = 3 ]; then	
		setgeo
		update
	
	elif [ "$num" = 4 ]; then	
		setdb
		update
		
	elif [ "$num" = 5 ]; then	
		setcrt
		update	
		
	elif [ "$num" = 6 ]; then	
		echo -----------------------------------------------
		echo -e "PAC配置链接为：\033[30;47m http://$host:$db_port/ui/pac \033[0m"
		echo -e "PAC的使用教程请参考：\033[4;32mhttps://juewuy.github.io/ehRUeewcv\033[0m"
		sleep 2
		update
		
	elif [ "$num" = 7 ]; then	
		setserver
		update
		
	elif [ "$num" = 8 ]; then		
		echo -----------------------------------------------
		echo -e "感谢：\033[32mClash \033[0m作者\033[36m Dreamacro\033[0m 项目地址：\033[32mhttps://github.com/Dreamacro/clash\033[0m"
		echo -e "感谢：\033[32msubconverter \033[0m作者\033[36m tindy2013\033[0m 项目地址：\033[32mhttps://github.com/tindy2013/subconverter\033[0m"
		echo -e "感谢：\033[32malecthw提供的GeoIP数据库\033[0m 项目地址：\033[32mhttps://github.com/alecthw/mmdb_china_ip_list\033[0m"
		echo -e "感谢：\033[32mHackl0us提供的GeoIP精简数据库\033[0m 项目地址：\033[32mhttps://github.com/Hackl0us/GeoIP2-CN\033[0m"
		echo -e "感谢：\033[32m17mon提供的CN-IP列表\033[0m 项目地址：\033[32mhttps://github.com/17mon/china_ip_list\033[0m"
		echo -e "感谢：\033[32myacd \033[0m作者\033[36m haishanh\033[0m 项目地址：\033[32mhttps://github.com/haishanh/yacd\033[0m"
		echo -e "感谢：\033[32m更多的帮助过我的人！\033[0m"
		sleep 2
		update
		
	elif [ "$num" = 9 ]; then
		$0 -u
		update
	else
		errornum
	fi
}
#新手引导
userguide(){

	forwhat(){
		echo -----------------------------------------------
		echo -e "\033[30;46m 欢迎使用ShellClash新手引导！ \033[0m"
		echo -----------------------------------------------
		echo -e "\033[33m请先选择你的使用环境： \033[0m"
		echo -e "\033[0m(你之后依然可以在设置中更改各种配置)\033[0m"
		echo -----------------------------------------------
		echo -e " 1 \033[32m路由设备配置局域网透明代理\033[0m"
		echo -e " 2 \033[36mLinux设备仅配置本机代理\033[0m"
		[ -f "$ccfg.bak" ] && echo -e " 3 \033[33m还原之前备份的设置\033[0m"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ] || [ "$num" -gt 4 ];then
			errornum
			forwhat
		elif [ "$num" = 1 ];then
			if command -v nft &>/dev/null;then
				setconfig redir_mod "Nft模式" 
			else
				setconfig redir_mod "Redir模式"
			fi
			#检测IP转发
			if [ "$(cat /proc/sys/net/ipv4/ip_forward)" = "0" ];then
				echo -----------------------------------------------
				echo -e "\033[33m检测到你的设备尚未开启ip转发，局域网设备将无法正常连接网络，是否立即开启？\033[0m"
				read -p "是否开启？(1/0) > " res
				[ "$res" = 1 ] && echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
				[ "$?" = 0 ] && /etc/init.d/procps restart && echo "已成功开启ipv4转发，如未正常开启，请手动重启设备！" || echo "开启失败！请自行谷歌查找当前设备的开启方法！"
			fi
		elif [ "$num" = 2 ];then
			setconfig redir_mod "纯净模式"
			setconfig clashcore "clash"
			echo -----------------------------------------------
			echo -e "\033[36m请选择设置本机代理的方式\033[0m"
			echo -e " 1 使用\033[32m环境变量\033[0m方式配置(不支持部分应用)"
			echo -e " 2 使用\033[32miptables增强模式\033[0m配置(不支持OpenWrt)"
			echo -e " 0 稍后设置"
			read -p "请输入对应数字 > " num
			if [ "$num" = 1 ]; then
				local_proxy=已开启
				local_type=环境变量
			elif [ "$num" = 2 ]; then
				local_proxy=已开启
				local_type=iptables增强模式
			fi
			setconfig local_proxy $local_proxy
			setconfig local_type $local_type
		elif [ "$num" = 3 ];then
			mv -f $ccfg.bak $ccfg
			echo -e "\033[32m脚本设置已还原！\033[0m"
			echo -e "\033[33m请重新启动脚本！\033[0m"
			exit 0
		fi
	}
	forwhat
	#检测小内存模式
	dir_size=$(df $clashdir | awk '{print $4}' | sed 1d)
	if [ "$dir_size" -lt 10240 ];then
		echo -----------------------------------------------
		echo -e "\033[33m检测到你的安装目录空间不足10M，是否开启小闪存模式？\033[0m"
		echo -e "\033[0m开启后核心及数据库文件将被下载到内存中，这将占用一部分内存空间\033[0m"
		echo -e "\033[0m每次开机后首次运行clash时都会自动的重新下载相关文件\033[0m"
		echo -----------------------------------------------
		read -p "是否开启？(1/0) > " res
		[ "$res" = 1 ] && setconfig bindir "/tmp/clash_$USER"
	fi
	#下载本地面板
	echo -----------------------------------------------
	echo -e "\033[33m安装本地Dashboard面板，可以更快捷的管理clash内置规则！\033[0m"
	echo -----------------------------------------------
	read -p "需要安装本地Dashboard面板吗？(1/0) > " res
	[ "$res" = 1 ] && checkupdate && setdb
	#检测及下载根证书
	if [ -d /etc/ssl/certs -a ! -f '/etc/ssl/certs/ca-certificates.crt' ];then
		echo -----------------------------------------------
		echo -e "\033[33m当前设备未找到根证书文件\033[0m"
		echo -----------------------------------------------
		read -p "是否下载并安装根证书？(1/0) > " res
		[ "$res" = 1 ] && checkupdate && getcrt
	fi
	#设置加密DNS
	$clashdir/start.sh webget /tmp/ssl_test https://doh.pub echooff rediron skipceroff
	if [ "$?" = "0" ];then
		dns_nameserver='https://223.5.5.5/dns-query, https://doh.pub/dns-query, tls://dns.rubyfish.cn:853'
		dns_fallback='https://1.0.0.1/dns-query, https://8.8.4.4/dns-query, https://doh.opendns.com/dns-query'
		setconfig dns_nameserver \'"$dns_nameserver"\'
		setconfig dns_fallback \'"$dns_fallback"\' 
	fi
	rm -rf /tmp/ssl_test
	#开启公网访问
	sethost(){
		read -p "请输入你的公网IP地址 > " host
		echo $host | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
		if [ -z "$host" ];then
			echo -e "\033[31m请输入正确的IP地址！\033[0m"
			sethost
		fi
	}
	if command -v systemd >/dev/null 2>&1 ;then
		echo -----------------------------------------------
		echo -e "\033[32m是否开启公网访问Dashboard面板及socks服务？\033[0m"
		echo -e "注意当前设备必须有公网IP才能从公网正常访问"
		echo -e "\033[31m此功能会增加暴露风险请谨慎使用！\033[0m"
		echo -e "vps设备可能还需要额外在服务商后台开启相关端口"
		read -p "现在开启？(1/0) > " res
		if [ "$res" = 1 ];then
			read -p "请先设置面板访问秘钥 > " secret
			read -p "请先修改Socks服务端口(1-65535) > " mix_port
			read -p "请先设置Socks服务密码(账号默认为clash) > " sec
			[ -z "$sec" ] && authentication=clash:$sec
			host=$(curl ip.sb  2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
			if [ -z "$host" ];then
				sethost
			fi	
			public_support=已开启
			setconfig secret $secret
			setconfig mix_port $mix_port
			setconfig host $host
			setconfig public_support $public_support
			setconfig authentication \'$authentication\'
		fi
	fi
	#小米设备软固化
	if [ "$systype" = "mi_snapshot" ];then
		echo -----------------------------------------------
		read -p "是否启用软固化SSH？(1/0) > " res
		[ "$res" = 1 ] && setconfig mi_autoSSH 已启用
	fi
	#提示导入订阅或者配置文件
	echo -----------------------------------------------
	echo -e "\033[32m是否导入配置文件？\033[0m(这是运行前的最后一步)"
	echo -e "\033[0m你必须拥有一份yaml格式的配置文件才能运行clash服务！\033[0m"
	echo -----------------------------------------------
	read -p "现在开始导入？(1/0) > " res
	[ "$res" = 1 ] && inuserguide=1 && clashlink && inuserguide=""
	#回到主界面
	echo -----------------------------------------------
	echo -e "\033[36m很好！现在只需要执行启动就可以愉快的使用了！\033[0m"
	echo -----------------------------------------------
	read -p "立即启动clash服务？(1/0) > " res 
	[ "$res" = 1 ] && clashstart && sleep 2
	clashsh
}
#测试菜单
testcommand(){
	echo -----------------------------------------------
	echo -e "\033[30;47m这里是测试命令菜单\033[0m"
	echo -e "\033[33m如遇问题尽量运行相应命令后截图发群\033[0m"
	echo -----------------------------------------------
	echo " 1 查看Clash运行时的报错信息(会停止clash服务)"
	echo " 2 查看系统DNS端口(:53)占用 "
	echo " 3 测试ssl加密(aes-128-gcm)跑分"
	echo " 4 查看clash相关路由规则"
	echo " 5 查看config.yaml前30行"
	echo " 6 测试代理服务器连通性（google.tw)"
	echo -----------------------------------------------
	echo " 0 返回上级目录！"
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		errornum
		clashsh
	elif [ "$num" = 0 ]; then
		clashsh
	elif [ "$num" = 1 ]; then
		$clashdir/start.sh stop
		echo -----------------------------------------------
		[ -x $clashdir/clash ] && $clashdir/clash -t -d $clashdir	
		[ "$?" = 0 ] && testover=32m测试通过！|| testover=31m出现错误！请截图后到TG群询问！！！
		echo -e "\033[$testover\033[0m"
		exit;
	elif [ "$num" = 2 ]; then
		echo -----------------------------------------------
		netstat -ntulp |grep 53
		echo -----------------------------------------------
		echo -e "可以使用\033[44m netstat -ntulp |grep xxx \033[0m来查询任意(xxx)端口"
		exit;
	elif [ "$num" = 3 ]; then
		echo -----------------------------------------------
		openssl speed -multi 4 -evp aes-128-gcm
		echo -----------------------------------------------
		exit;
	elif [ "$num" = 4 ]; then

		if [ -n "$(echo $redir_mod | grep 'Nft')" -o "$local_type" = "nftables增强模式" ];then
			nft list table inet shellclash
		else
			echo -------------------Redir---------------------
			iptables  -t nat  -L PREROUTING --line-numbers
			iptables  -t nat -L clash_dns --line-numbers
			iptables  -t nat  -L clash --line-numbers
			[ -n "$(echo $redir_mod | grep 'Tproxy')" ] && {
				echo ----------------Tun/Tproxy-------------------
				iptables  -t mangle -L PREROUTING --line-numbers
				iptables  -t mangle  -L clash --line-numbers
			}
			[ -n "$(echo $redir_mod | grep 'Tproxy')" -a "$ipv6_redir" = "已开启" ] && {
				echo ----------------Tun/Tproxy-------------------
				ip6tables  -t mangle -L PREROUTING --line-numbers
				ip6tables  -t mangle  -L clashv6 --line-numbers
				[ -n "$(lsmod | grep 'ip6table_nat')" ] && {
					echo -------------------Redir---------------------
					ip6tables  -t nat  -L PREROUTING --line-numbers
					ip6tables  -t nat -L clashv6_dns --line-numbers
					ip6tables  -t nat  -L clashv6 --line-numbers
				}
			}
		fi
		exit;
	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		sed -n '1,30p' $yaml
		echo -----------------------------------------------
		exit;
	elif [ "$num" = 6 ]; then
		echo "注意：依赖curl(不支持wget)，且测试结果不保证一定准确！"
		delay=`curl -kx ${authentication}@127.0.0.1:$mix_port -o /dev/null -s -w '%{time_starttransfer}' 'https://google.tw' & { sleep 3 ; kill $! & }` > /dev/null 2>&1
		delay=`echo |awk "{print $delay*1000}"` > /dev/null 2>&1
		echo -----------------------------------------------
		if [ `echo ${#delay}` -gt 1 ];then
			echo -e "\033[32m连接成功！响应时间为："$delay" ms\033[0m"
		else
			echo -e "\033[31m连接超时！请重试或检查节点配置！\033[0m"
		fi
		clashsh

	else
		errornum
		clashsh
	fi
}