#!/bin/bash
# Copyright (C) Juewuy

webget(){
	[ -n "$(pidof clash)" ] && export all_proxy="http://$authentication@127.0.0.1:$mix_port" #设置临时http代理 
	#参数【$1】代表下载目录，【$2】代表在线地址
	#参数【$3】代表输出显示，【$4】不启用重定向
	#参数【$5】代表验证证书
	if curl --version > /dev/null 2>&1;then
		[ "$3" = "echooff" ] && progress='-s' || progress='-#'
		[ "$4" = "rediroff" ] && redirect='' || redirect='-L'
		[ "$5" = "skipceroff" ] && certificate='' || certificate='-k'
		result=$(curl -w %{http_code} --connect-timeout 3 $progress $redirect $certificate -o $1 $2)
		[ "$result" != "200" ] && export all_proxy="" && result=$(curl -w %{http_code} --connect-timeout 3 $progress $redirect $certificate -o $1 $2)
	else
		[ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
		[ "$3" = "echoon" ] && progress=''
		[ "$4" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
		[ "$5" = "skipceroff" ] && certificate='' || certificate='--no-check-certificate'
		wget -Y on $progress $redirect $certificate --timeout=3 -O $1 $2 
		if [ "$?" != "0" ];then
			wget $progress $redirect $certificate --timeout=3 -O $1 $2
			[ "$?" = "0" ] && result="200"
		else
			result="200"
		fi
	fi
	export all_proxy=""
}
#导入订阅、配置文件相关
linkconfig(){
	echo -----------------------------------------------
	echo 当前使用规则为：$rule_link
	echo 1	ACL4SSR通用版无去广告（推荐）
	echo 2	ACL4SSR精简全能版（推荐）
	echo 3	ACL4SSR通用版+去广告加强
	echo 4	ACL4SSR精简版+去广告加强
	echo 5	ACL4SSR重度全分组+奈飞分流
	echo 6	ACL4SSR重度全分组+去广告加强
	echo 7	洞主规则精简版（推荐）
	echo 8	洞主规则重度完整版
	echo 9	神机规则高级版
	echo 10	神机规则-回国专用
	echo 11	李哥规则-墙洞专用
	echo 12	基础规则-仅Geoip CN+Final
	echo 13	网易云解锁-仅规则分组
	echo 14	ACL4SSR重度全分组+谷歌优化
	echo -----------------------------------------------
	echo 0 返回上级菜单
	read -p "请输入对应数字 > " num
	if [ -z "$num" ] || [ "$num" -gt 14 ];then
		errornum
	elif [ "$num" = 0 ];then
		echo 
	elif [ "$num" -le 14 ];then
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
	echo 当前使用后端为：$server_link
	echo 1 subcon.dlj.tf
	echo 2 subconverter.herokuapp.com
	echo 3 subconverter-web.now.sh
	echo 4 api.dler.io
	echo 5 api.wcc.best
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
	echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
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
	echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
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
	#设置输入循环
	i=1
	while [ $i -le 99 ]
	do
		echo -----------------------------------------------
		echo -e "\033[44m 遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
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
	echo -e "\033[33m仅限导入完整clash配置文件链接！！！\033[0m"
	echo -e "可使用\033[4;32mhttps://acl4ssr.netlify.app\033[0m在线生成配置文件"
	echo -----------------------------------------------
	echo -e "\033[33m0 返回上级菜单\033[0m"
	echo -----------------------------------------------
	read -p "请输入完整链接 > " link
	test=$(echo $link | grep -iE "tp.*://" )
	link=`echo ${link/\ \(*\)/''}`   #删除恶心的超链接内容
	link=`echo ${link//\&/\\\&}`   #为分隔符 & 添加转义
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
		clashlink
	  
	elif [ "$num" = 2 ];then
		getlink2
		clashlink
		
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
		clashlink
	else
		errornum
		clashlink
	fi
}
#下载更新相关
gettar(){
	webget /tmp/clashfm.tar.gz $tarurl
	[ "$result" != "200" ] && echo "文件下载失败！" && exit 1
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
			mv $clashdir/clashservice /etc/init.d/clash
			chmod  777 /etc/init.d/clash
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
			sed -i '/start_old=*/'d $clashdir/mark
			echo start_old=已开启 >> $clashdir/mark
		fi
	fi
	#修饰文件及版本号
	shtype=sh && [ -n "$(ls -l /bin/sh|grep -o dash)" ] && shtype=bash 
	sed -i "s|/bin/sh|/bin/$shtype|" $clashdir/start.sh
	chmod  777 $clashdir/start.sh
	sed -i '/versionsh_l=*/'d $clashdir/mark
	echo versionsh_l=$release_new >> $clashdir/mark
	#设置环境变量
	[ -w ~/.bashrc ] && profile=~/.bashrc
	[ -w /etc/profile ] && profile=/etc/profile
	if [ -n "$profile" ];then
		sed -i '/alias clash=*/'d $profile
		echo "alias clash=\"$shtype $clashdir/clash.sh\"" >> $profile #设置快捷命令环境变量
		sed -i '/export clashdir=*/'d $profile
		echo "export clashdir=\"$clashdir\"" >> $profile #设置clash路径环境变量
	else
		echo 无法写入环境变量！请检查安装权限！
		exit 1
	fi
	#删除临时文件
	rm -rf /tmp/clashfm.tar.gz 
	rm -rf $clashdir/clashservice
	rm -rf $clashdir/clash.service
}
getsh(){
	echo -----------------------------------------------
	echo -e "当前脚本版本为：\033[33m $versionsh_l \033[0m"
	echo -e "最新脚本版本为：\033[32m $release_new \033[0m"
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
	[ -n "$(echo $cputype | grep -E "linux.*armv7.*")" ] && [ -n "$(cat /proc/cpuinfo | grep vfp)" ] && cpucore="armv7"
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
	echo -e "之后前往 t.me/clashfm 群提交或 github.com/juewuy/ShellClash 提交issue"
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
	webget /tmp/clash.new $corelink
	if [ "$result" != "200" ];then
		echo -e "\033[31m核心文件下载失败！\033[0m"
	else
		echo -e "\033[32m$clashcore核心下载成功！\033[0m"
		mv -f /tmp/clash.new $bindir/clash
		chmod  777 $bindir/clash  #授予权限
		setconfig clashcore $clashcore
		setconfig clashv $version
	fi
}
setcore(){
	#获取核心及版本信息
	[ ! -f $clashdir/clash ] && clashcore="未安装核心"
	###
	echo -----------------------------------------------
	[ -z "$cpucore" ] && getcpucore
	echo -e "当前clash核心：\033[47;30m $clashcore \033[46;30m$clashv\033[0m"
	echo -e "当前系统处理器架构：\033[32m $cpucore \033[0m"
	echo -e "\033[33m请选择需要使用的核心版本！\033[0m"
	echo -----------------------------------------------
	echo "1 clash：     稳定，内存占用小，推荐！"
	echo "(官方正式版)  不支持Tun模式、混合模式"
	echo
	echo "2 clashpre：  支持Tun模式、混合模式"
	echo "(高级预览版)  内存占用更高"
	echo
	echo "3 手动指定处理器架构"
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
	webget /tmp/Country.mmdb $update_url/bin/$geotype
	if [ "$result" != "200" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
		exit 1
	else
		mv -f /tmp/Country.mmdb $bindir/Country.mmdb
		echo -----------------------------------------------
		echo -e "\033[32mGeoIP数据库文件下载成功！\033[0m"
		Geo_v=$GeoIP_v
		setconfig Geo_v $GeoIP_v
		setconfig geotype $geotype
	fi
}
setgeo(){
	echo -----------------------------------------------
	[ "$geotype" = "Country.mmdb" ] && geo_type=全球版 || geo_type=精简版
	[ -n "$geo_type" ] && echo -e "当前使用的是\033[47;30m$geo_type数据库\033[0m"
	echo -e "\033[36m请选择需要更新的GeoIP数据库：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 由\033[32malecthw\033[0m提供的全球版GeoIP数据库(约4mb)"
	echo -e " 2 由\033[32mHackl0us\033[0m提供的精简版CN-IP数据库(约0.1mb)"
	echo " 0 返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ "$num" = '1' ]; then
		geotype=Country.mmdb
		getgeo
	elif [ "$num" = '2' ]; then
		geotype=cn_mini.mmdb
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
		fi
	fi
	dblink="${update_url}/bin/${db_type}.tar.gz"
	echo -----------------------------------------------
	echo 正在连接服务器获取安装文件…………
	webget /tmp/clashdb.tar.gz $dblink
	if [ "$result" != "200" ];then
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
		if [ "$db_type" = "clashdb" ];then
			sed -i "s/127.0.0.1/${host}/g" $dbdir/assets/*.js
			sed -i "s/9090/${db_port}/g" $dbdir/assets/*.js
		else
			sed -i "s/127.0.0.1:9090/${host}:${db_port}/g" $dbdir/*.html
			#sed -i "s/7892/${db_port}/g" $dbdir/app*.js
		fi
		#如果clash在运行则重启clash服务
		[ "$dbdir" != "/www/clash" ] && [ -n "$PID" ] && $clashdir/start.sh restart
		#写入配置文件
		setconfig hostdir \'$hostdir\'
		echo -----------------------------------------------
		echo -e "\033[32m面板安装成功！\033[0m"
		echo -e "\033[36m请使用\033[32;4mhttp://$host$hostdir\033[0;36m访问面板\033[0m"
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
	echo -e " 2 安装\033[32mYacd面板\033[0m(约1.1mb)"
	echo -e " 3 卸载\033[33m本地面板\033[0m"
	echo " 0 返回上级菜单"
	read -p "请输入对应数字 > " num

	if [ "$num" = '1' ]; then
		db_type=clashdb
		dbdir
		getdb
	elif [ "$num" = '2' ]; then
		db_type=yacd
		dbdir
		getdb
	elif [ "$num" = '3' ]; then
		read -p "确认卸载本地面板？(1/0) > " res
		if [ "$res" = 1 ];then
			rm -rf /www/clash
			rm -rf $clashdir/ui
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
	webget /tmp/ca-certificates.crt $crtlink
	if [ "$result" != "200" ];then
		echo -----------------------------------------------
		echo -e "\033[31m文件下载失败！\033[0m"
	else
		echo -----------------------------------------------
		mv -f /tmp/ca-certificates.crt $crtdir
		echo -e "\033[32m证书安装成功！\033[0m"
		sleep 1
	fi
}
setcrt(){
	openssldir=$(openssl version -a 2>&1 | grep OPENSSLDIR | awk -F "\"" '{print $2}')
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
		echo -----------------------------------------------
		echo -e "\033[32m源地址更新成功！\033[0m"
		release_new=""
	}
	echo -----------------------------------------------
	echo -e "\033[30;47m您可以在此处切换在线更新时使用的资源地址\033[0m"
	echo -e "当前源：\033[4;32m$update_url\033[0m"
	echo -----------------------------------------------
	echo -e " 1 Jsdelivr-CDN源(test版本)"
	echo -e " 2 Jsdelivr-CDN源(release版本)"
	echo -e " 3 Github源(test版本，需开启clash服务)"
	echo -e " 5 自定义输入(请务必确保路径正确)"
	echo -e " 6 切换版本(仅支持切换至release分支)"
	echo -e " 0 返回上级菜单"
	read -p "请输入对应数字 > " num
	if	[ -z "$num" ]; then 
		errornum
	elif [ "$num" = 1 ]; then
		update_url='https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master'
		saveserver
	elif [ "$num" = 2 ]; then
		update_url='https://cdn.jsdelivr.net/gh/juewuy/ShellClash'
		saveserver
	elif [ "$num" = 3 ]; then
		update_url='https://raw.githubusercontent.com/juewuy/ShellClash/master'
		saveserver
	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		read -p "请输入个人源路径 > " update_url
		if [ -z "$update_url" ];then
			echo -----------------------------------------------
			echo -e "\033[31m取消输入，返回上级菜单\033[0m"
		else
			saveserver
		fi
	elif [ "$num" = 6 ]; then
		echo -----------------------------------------------
		webget /tmp/clashrelease https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master/bin/release_version echooff rediroff 2>/tmp/clashrelease
		echo -e "\033[32m请选择想要更新至的版本：\033[0m"
		cat /tmp/clashrelease | awk '{print " "NR" "$1}'
		echo -e " 0 返回上级菜单"
		read -p "请输入对应数字 > " num
		if [ -z "$num" -o "$num" = 0 ]; then
			setserver
		elif [ $num -le $(cat /tmp/clashrelease | awk 'END{print NR}') 2>/dev/null ]; then
			release_version=$(cat /tmp/clashrelease | awk '{print $1}' | sed -n "$num"p)
			update_url="https://cdn.jsdelivr.net/gh/juewuy/ShellClash@$release_version"
			saveserver
		else
			echo -----------------------------------------------
			echo -e "\033[31m输入有误，请重新输入！\033[0m"
		fi
		
	elif [ "$num" = 9 ]; then
		update_url='http://192.168.31.31:8080/ShellClash'
	else
		errornum
	fi
}
checkupdate(){
if [ -z "$release_new" ];then
	if [ "$update_url" = "https://cdn.jsdelivr.net/gh/juewuy/ShellClash" ];then
		webget /tmp/clashrelease $update_url@master/bin/release_version echoon rediroff 2>/tmp/clashrelease
		[ "$result" = "200" ] && release_new=$(cat /tmp/clashrelease | head -1)
		[ -z "$release_new" ] && release_new=master
		update_url=$update_url@$release_new
	fi
	webget /tmp/clashversion $update_url/bin/version echooff
	[ "$result" = "200" ] && source /tmp/clashversion || echo -e "\033[31m检查更新失败！请检查网络连接或切换安装源！\033[0m"
	[ -z "$release_new" ] && release_new=$versionsh
	rm -rf /tmp/clashversion
	rm -rf /tmp/clashrelease
fi
}
update(){
	echo -----------------------------------------------
	echo -ne "\033[32m正在检查更新！\033[0m\r"
	checkupdate
	[ "$clashcore" = "clash" ] && clash_n=$clash_v || clash_n=$clashpre_v
	clash_v=$($bindir/clash -v 2>/dev/null | awk '{print $2}')
	[ -z "$clash_v" ] && clash_v=$clashv
	echo -e "\033[30;47m欢迎使用更新功能：\033[0m"
	echo -----------------------------------------------
	echo -e " 1 更新\033[36m管理脚本  	\033[33m$versionsh_l\033[0m > \033[32m$versionsh\033[0m"
	echo -e " 2 切换\033[33mclash核心 	\033[33m$clash_v\033[0m > \033[32m$clash_n\033[0m"
	echo -e " 3 更新\033[32mGeoIP数据库	\033[33m$Geo_v\033[0m > \033[32m$GeoIP_v\033[0m"
	echo -e " 4 安装本地\033[35mDashboard\033[0m面板"
	echo -e " 5 安装/更新本地\033[33m根证书文件\033[0m"
	echo -e " 6 查看\033[32mPAC\033[0m自动代理配置"
	echo -----------------------------------------------
	echo -e " 7 切换\033[36m安装源\033[0m地址"
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
		echo -e "感谢：\033[32myacd \033[0m作者\033[36m haishanh\033[0m 项目地址：\033[32mhttps://github.com/haishanh/yacd\033[0m"
		echo -e "感谢：\033[32m更多的帮助过我的人！\033[0m"
		sleep 2
		update
		
	elif [ "$num" = 9 ]; then
		read -p "确认卸载ShellClash？（警告：该操作不可逆！）[1/0] " res
		if [ "$res" = '1' ]; then
			$clashdir/start.sh stop
			$clashdir/start.sh cronset "clash服务"
			$clashdir/start.sh cronset "订阅链接"
			[ -w ~/.bashrc ] && profile=~/.bashrc
			[ -w /etc/profile ] && profile=/etc/profile
			sed -i '/alias clash=*/'d $profile
			sed -i '/export clashdir=*/'d $profile
			sed -i '/all_proxy/'d $profile
			sed -i '/ALL_PROXY/'d $profile
			rm -rf $clashdir
			rm -rf /etc/init.d/clash
			rm -rf /etc/systemd/system/clash.service
			rm -rf /usr/lib/systemd/system/clash.service
			rm -rf /www/clash
			echo -----------------------------------------------
			echo -e "\033[36m已卸载ShellClash相关文件！有缘再会！\033[0m"
			echo -e "\033[33m请手动关闭当前窗口以重置环境变量！\033[0m"
			echo -----------------------------------------------
			exit
		fi
		echo -e "\033[31m操作已取消！\033[0m"
		update
	else
		errornum
	fi
}
#新手引导
userguide(){
	whichmod(){	
		echo -----------------------------------------------
		echo -e "\033[33m是否需要代理UDP流量(主要用于游戏)？ \033[0m"
		echo -----------------------------------------------
		echo -e " 1 \033[33m不代理UDP流量\033[0m(可能会导致一部分游戏/应用无法连接)"
		modinfo tun >/dev/null 2>&1 && [ "$?" = 0 ] && \
		echo -e " 2 \033[32m使用Tun虚拟网卡\033[0m代理UDP流量(更低的延迟但更多的CPU消耗)" || \
		echo -e " - \033[0m使用Tun模式(你的设备不支持此模式，如为虚拟机运行请调整虚拟网卡设置)\033[0m"
		[ -n "$(iptables -j TPROXY 2>&1 | grep 'on-port')" ] && \
		echo -e " 3 \033[32m使用Tproxy模式\033[0m代理UDP流量(较低CPU消耗但相对高的延迟)"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ] || [ "$num" -gt 4 ];then
			errornum
			whichmod
		elif [ "$num" = 1 ];then
			setconfig redir_mod "Redir模式"
			setconfig clashcore "clash"
		elif [ "$num" = 2 ];then
			setconfig redir_mod "混合模式"
			setconfig clashcore "clashpre"
		elif [ "$num" = 3 ];then
			setconfig redir_mod "Redir模式"
			setconfig clashcore "clash"
			setconfig tproxy_mod "已开启"
		fi		
	}
	forwhat(){
		echo -----------------------------------------------
		echo -e "\033[30;46m 欢迎使用ShellClash新手引导！ \033[0m"
		echo -----------------------------------------------
		echo -e "\033[33m请先选择你的使用环境： \033[0m"
		echo -e "\033[0m(你之后依然可以在设置中更改各种配置)\033[0m"
		echo -----------------------------------------------
		echo -e " 1 \033[32m各类路由设备\033[0m，配置局域网透明路由"
		echo -e " 2 \033[36m桌面版Linux系统\033[0m，仅配置本机路由"
		echo -e " 3 \033[32m服务器Linux系统\033[0m，仅配置本机路由"
		echo -e " 4 \033[36m多功能设备\033[0m，配置本机及局域网路由"
		echo -----------------------------------------------
		read -p "请输入对应数字 > " num
		if [ -z "$num" ] || [ "$num" -gt 4 ];then
			errornum
			forwhat
		elif [ "$num" = 1 ];then
			whichmod
		elif [ "$num" = 2 -o "$num" = 3 ];then
			setconfig redir_mod "纯净模式"
			setconfig clashcore "clash"
			echo -----------------------------------------------
			echo -e "\033[36m请选择设置本机代理的方式\033[0m"
			localproxy
		elif [ "$num" = 4 ];then
			whichmod
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
	webget /tmp/ssl_test https://baidu.com echooff rediron skipceroff
	if [ "$result" = "200" ];then
		dns_nameserver='https://223.5.5.5/dns-query, https://doh.pub/dns-query, tls://dns.rubyfish.cn:853'
		dns_fallback='https://1.0.0.1/dns-query, https://8.8.4.4/dns-query, https://doh.opendns.com/dns-query'
		setconfig dns_nameserver \'"$dns_nameserver"\'
		setconfig dns_fallback \'"$dns_fallback"\' 
	fi
	rm -rf /tmp/ssl_test
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
	echo -e "磁盘占用/所在目录："
	du -sh $clashdir
	echo -----------------------------------------------
	echo " 1 查看clash运行时的报错信息"
	echo " 2 查看系统DNS端口(:53)占用 "
	echo " 3 测试ssl加密（aes-128-gcm）跑分"
	echo " 4 查看iptables端口转发详情"
	echo " 5 查看config.yaml前40行"
	echo " 6 测试代理服务器连通性（google.tw)"
	echo " 7 重新进入新手引导"
	echo " 9 查看后台脚本运行日志"
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
		$clashdir/clash -t -d $clashdir	
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
		echo -----------------------------------------------
		iptables  -t nat  -L PREROUTING --line-numbers
		echo -----------------------------------------------
		iptables  -t nat  -L clash --line-numbers
		echo -----------------------------------------------
		iptables  -t nat  -L clash_dns --line-numbers
		echo -----------------------------------------------
		ip6tables  -t nat  -L PREROUTING --line-numbers
		echo -----------------------------------------------
		ip6tables  -t nat  -L clashv6 --line-numbers
		echo -----------------------------------------------
		ip6tables  -t nat  -L clashv6_dns --line-numbers
		exit;
	elif [ "$num" = 5 ]; then
		echo -----------------------------------------------
		sed -n '1,40p' $yaml
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
	elif [ "$num" = 7 ]; then
		userguide
	elif [ "$num" = 9 ]; then
		echo -----------------------------------------------
		cat $clashdir/log
		exit;
	else
		errornum
		clashsh
	fi
}