#!/bin/bash
# Copyright (C) Juewuy

linkconfig(){
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo 当前使用规则为：$rule_link
echo 1 ACL4SSR默认通用版
echo 2 ACL4SSR精简全能版（推荐）
echo 3 ACL4SSR通用版+去广告加强
echo 4 ACL4SSR精简版+去广告加强
echo 5 ACL4SSR通用版无去广告
echo 6 ACL4SSR通用版无自动测速
echo 7 ACL4SSR精简版无自动测速
echo 8 ACL4SSR全分组+奈飞（慎用）
echo 9 ACL4SSR全分组+去广告（慎用）
echo -----------------------------------------------
echo 0 返回上级菜单
read -p "请输入对应数字 > " num
if [ -z "$num" ] || [[ $num -gt 9 ]];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
elif [[ "$num" = 0 ]];then
	echo 
elif [[ $num -le 9 ]];then
	#将对应标记值写入mark
	sed -i '/rule_link*/'d $ccfg
	sed -i "4i\rule_link="$num"" $ccfg	
	rule_link=$num
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	  
	echo -e "\033[32m设置成功！返回上级菜单\033[0m"
fi
}
linkserver(){
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo 当前使用后端为：$server_link
echo 1 subconverter-web.now.sh
echo 2 subconverter.herokuapp.com
echo 3 subcon.py6.pw
echo 4 api.dler.io
echo 5 api.wcc.best
echo 6 skapi.cool
echo -----------------------------------------------
echo 0 返回上级菜单
read -p "请输入对应数字 > " num
if [ -z "$num" ] || [[ $num -gt 6 ]];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
elif [[ "$num" = 0 ]];then
	echo
elif [[ $num -le 6 ]];then
	#将对应标记值写入mark
	sed -i '/server_link*/'d $ccfg
	sed -i "4i\server_link="$num"" $ccfg	
	server_link=$num
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~	  
	echo -e "\033[32m设置成功！返回上级菜单\033[0m"
fi
}
linkfilter(){
[ -z "$exclude" ] && exclude="未设置"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -e "\033[33m当前过滤关键字：\033[47;30m$exclude\033[0m"
echo -----------------------------------------------
echo -e "\033[36m匹配关键字的节点会在导入时被屏蔽\033[0m"
echo -e "多个关键字可以用\033[30;47m | \033[0m号分隔"
echo -e "\033[32m支持正则表达式\033[0m，特殊符号请使用\033[30;47m \ \033[0m号转义"
echo -----------------------------------------------
echo -e " 000   \033[31m删除\033[0m关键字"
echo -e " 回车  取消输入并返回上级菜单"
echo -----------------------------------------------
read -p "请输入关键字 > " exclude
if [ -z "$exclude" ]; then
	linkset
elif [ "$exclude" = '000' ]; then
	echo -----------------------------------------------
	exclude=''
	echo -e "\033[31m 已删除节点过滤关键字！！！\033[0m"
fi
sed -i '/exclude=*/'d $ccfg
sed -i "1i\exclude=\'$exclude\'" $ccfg
linkset
}
linkset(){
if [ -n $Url ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[47;30m请检查输入的链接是否正确：\033[0m"
	echo -e "\033[32;4m$Url\033[0m"
	echo -----------------------------------------------
	echo -e " 1 \033[32m生成配置文件（原文件将被备份）\033[0m"
	echo -e " 2 \033[36m添加/修改节点过滤关键字 \033[47;30m$exclude\033[0m"
	echo -e " 3 \033[33m选取配置规则模版\033[0m"
	echo -e " 4 \033[0m选取在线生成服务器\033[0m"
	echo -e " 5 \033[0m跳过本地证书验证：	\033[36m$skip_cert\033[0m   ————解决节点证书验证错误"
	echo -----------------------------------------------
	echo -e " 0 \033[31m取消导入\033[0m并返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入对应数字 > " num
	if [ -z "$num" ]; then
		clashlink
	elif [ "$num" = '0' ]; then
		clashlink
	elif [ "$num" = '1' ]; then
		#将用户链接写入mark
		sed -i '/Url=*/'d $ccfg
		sed -i '/Https=*/'d $ccfg
		sed -i "6i\Url=\'$Url\'" $ccfg
		Https=""
		#获取在线yaml文件
		$sh_type $clashdir/start.sh getyaml
	elif [ "$num" = '2' ]; then
		linkfilter
		linkset
	elif [ "$num" = '3' ]; then
		linkconfig
		linkset
	elif [ "$num" = '4' ]; then
		linkserver
		linkset
	elif [ "$num" = '5' ]; then
		sed -i '/skip_cert*/'d $ccfg
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		if [ "$skip_cert" = "未开启" ] > /dev/null 2>&1; then 
			sed -i "1i\skip_cert=已开启" $ccfg
			#echo -e "\033[33m已设为开启跳过本地证书验证！！\033[0m"
			skip_cert=已开启
		else
			sed -i "1i\skip_cert=未开启" $ccfg
			#echo -e "\033[33m已设为禁止跳过本地证书验证！！\033[0m"
			skip_cert=未开启
		fi
		linkset
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		linkset
	fi
	clashlink
fi
}
getlink(){
#设置输入循环
i=1
while [ $i -le 99 ]
do
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[44m 遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
	echo -----------------------------------------------
	echo -e "支持批量导入\033[30;46m Http/Https/Clash \033[0m等格式的订阅链接"
	echo -e "以及\033[30;42m Vmess/SSR/SS/Trojan/Sock5 \033[0m等格式的节点链接"
	echo -----------------------------------------------
	echo -e "多个较短的链接可以用\033[30;47m | \033[0m号分隔以一次性输入"
	echo -e "多个较长的链接可分次输入，支持多达\033[30;47m 99 \033[0m次输入"
	echo -----------------------------------------------
	echo -e "回车 \033[32m完成输入\033[0m并开始导入链接！"
	echo -e " 0   \033[33m取消输入\033[0m并返回上级菜单"
	echo -----------------------------------------------
	read -p "请输入第"$i"个链接 > " url
	test=$(echo $url | grep "://")
	url=`echo ${url/\ \(*\)/''}`   #删除恶心的超链接内容
	url=`echo ${url/*\&url\=/""}`   #将clash完整链接还原成单一链接
	url=`echo ${url/\&config\=*/""}`   #将clash完整链接还原成单一链接
	url=`echo ${url//\&/\%26}`   #将分隔符 & 替换成urlcode：%26
	if [[ "$test" != "" ]];then
		if [[ -z $Url ]];then
			Url="$url"
		else
			Url="$Url"\|"$url"
		fi
		i=$(($i+1))
	elif [ -z $url ];then
		linkset
	elif [[ $url == 0 ]];then
		clashlink
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的订阅/分享链接！！！\033[0m"
	fi
done
####
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo 输入太多啦，可能会导致订阅失败！
echo "多个较短的链接请尽量用“|”分隔以一次性输入！"
clashlink
} 
getlink2(){
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m 此功能不明勿用，出问题自行解决！\033[0m"
echo -----------------------------------------------
echo -e "\033[33m仅限导入完整clash链接！！！\033[0m"
echo -e "可以使用\033[32m https://acl4ssr.netlify.app \033[0m在线转换"
echo -e "\033[36m导入后如无法运行，请使用【导入节点/订阅链接】功能"
echo -e "\033[31m注意如节点使用了chacha20加密协议，需将核心更新为clashr核心\033[0m"
echo -----------------------------------------------
echo -e "\033[33m0 返回上级菜单\033[0m"
echo -----------------------------------------------
read -p "请输入完整链接 > " Https
test=$(echo $Https | grep "://")
Https=`echo ${Https/\ \(*\)/''}`   #删除恶心的超链接内容
#Https=`echo ${Https//\&/\%26}`   #将分隔符 & 替换成Httpscode：%26
if [ -n $Https ];then
	if [ -n $test ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e 请检查输入的链接是否正确：
		echo -e "\033[4m$Https\033[0m"
		read -p "确认导入配置文件？原配置文件将被更名为config.yaml.bak![1/0] > " res
			if [ "$res" = '1' ]; then
				#将用户链接写入mark
				sed -i '/Url=*/'d $ccfg
				sed -i '/Https=*/'d $ccfg
				sed -i "6i\Https=\'$Https\'" $ccfg
				#获取在线yaml文件
				$sh_type $clashdir/start.sh getyaml
			fi
			clashlink
	fi
elif [[ $Https == 0 ]];then
	clashlink
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的链接地址！！！\033[0m"
fi
}
getsh(){
echo -----------------------------------------------
echo -e "当前脚本版本为：\033[33m $versionsh_l \033[0m"
echo -e "最新脚本版本为：\033[32m $release_new \033[0m"
echo -----------------------------------------------
read -p "是否更新脚本？[1/0] > " res
if [ "$res" = '1' ]; then
	if command -v curl &> /dev/null; then
		echo 正在获取更新文件
		result=$(curl -w %{http_code} -kLo /tmp/clashfm.tar.gz $update_url/bin/clashfm.tar.gz)
	else $result
		wget-ssl -q --no-check-certificate --tries=1 --timeout=10 -O /tmp/clashfm.tar.gz $update_url/bin/clashfm.tar.gz
		[ $? -eq 0 ] && result="200"
	fi
	[ "$result" != "200" ] && echo "文件下载失败！" && exit 1
	#解压
	echo -----------------------------------------------
	echo 开始解压文件！
	mkdir -p $clashdir > /dev/null
	tar -zxvf '/tmp/clashfm.tar.gz' -C $clashdir/ > /dev/null
	[ $? -ne 0 ] && echo "文件解压失败！" && exit 1 
	#判断系统类型写入不同的启动文件
	if [ -n "$(cat /proc/version | grep -i openwrt)" ];then
		mv $dir/clash/clashservice /etc/init.d/clash #将rc服务文件移动到系统目录
		chmod  777 /etc/init.d/clash #授予权限
		rm -rf $dir/clash/clash.service 
	else
		[ -d /etc/systemd/system ] && sysdir=/etc/systemd/system
		[ -d /usr/lib/systemd/system/ ] && sysdir=/usr/lib/systemd/system/ 
		mv $dir/clash/clash.service $sysdir/clash.service #将service服务文件移动到系统目录
		sed -i "s%/etc/clash%${dir}/clash%g" $sysdir/clash.service
		rm -rf $dir/clash/clashservice
		rm -rf /etc/init.d/clash
	fi
	#写入版本号
	sed -i '/versionsh_l=*/'d $ccfg
	sed -i "1i\versionsh_l=$release_new" $ccfg
	#删除临时文件
	rm -rf /tmp/clashfm.tar.gz 
	rm -rf /tmp/clashversion
	#提示
	echo -----------------------------------------------
	echo -e "\033[32m管理脚本更新成功!\033[0m"
	echo -----------------------------------------------
	exit;
else
update
fi
}
getcore(){
source $ccfg
#获取核心及版本信息
if [ ! -f $clashdir/clash ]; then
	clashcore=没有安装核心！
	clashv=''
fi
clashcore_n=$clashcore
#获取设备处理器架构
cpucore=$(uname -ms | tr ' ' '_' | tr '[A-Z]' '[a-z]')
[ -n "$(echo $cpucore | grep -E "linux.*armv.*")" ] && cpucore="armv5"
[ -n "$(echo $cpucore | grep -E "linux.*aarch64.*")" ] && cpucore="armv8"
[ -n "$(echo $cpucore | grep -E "linux.*armv8.*")" ] && cpucore="armv8"
[ -n "$(echo $cpucore | grep -E "linux.*armv7.*")" ] && cpucore="armv7"
[ -n "$(echo $cpucore | grep -E "linux.*mips.*")" ] && cpucore="mipsle-softfloat"
[ -n "$(echo $cpucore | grep -E "linux.*x86.*")" ] && cpucore="386"
[ -n "$(echo $cpucore | grep -E "linux.*amd64.*")" ] && cpucore="amd64"
[ -n "$(echo $cpucore | grep -E "linux.*x86_64.*")" ] && cpucore="amd64"
###
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "当前clash核心：\033[47;30m $clashcore \033[46;30m$clashv\033[0m"
echo -e "\033[32m请选择需要下载的核心版本！\033[0m"
echo -----------------------------------------------
echo "1 clash：     稳定，内存占用小，推荐！"
echo "(官方正式版)  不支持chacha20加密，不支持Tun模式"
echo
echo "2 clashr：    内存占用小，支持chacha20加密"
echo "(clashR修改版)不支持Tun模式"
echo
echo "3 clashpre：  支持Tun模式"
echo "(高级预览版)  内存占用高，不支持chacha20加密"
echo -----------------------------------------------
echo 0 返回上级菜单 
read -p "请输入对应数字 > " num
	if [ -z $num ]; then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		update
	elif [[ $num == 0 ]]; then
		update
	elif [[ $num == 1 ]]; then
		clashcore=clash
	elif [[ $num == 2 ]]; then
		clashcore=clashr
	elif [[ $num == 3 ]]; then
		clashcore=clashpre
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		update
	fi
#生成链接
corelink="$update_url/bin/$clashcore/clash-linux-$cpucore"
versionlink="$update_url/bin/$clashcore/version"
#检测版本
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[33m正在检查更新！\033[0m"
result=$(curl -w %{http_code} -skLo /tmp/clashversion $versionlink)
[ "$result" != "200" ] && echo "检查更新失败！" && exit 1
source /tmp/clashversion
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "当前clash核心：\033[0m $clashcore_n \033[33m$clashv\033[0m"
echo -e "最新clash核心：\033[32m $clashcore \033[36m$version\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
read -p "是否更新？[1/0] > " res
if [ "$res" = '1' ]; then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo 正在连接服务器获取clash核心文件…………链接地址为：
	echo -e "\033[4;32m$corelink\033[0m"
	echo 如无法正常下载可以手动复制到浏览器下载核心文件！
	echo -e "\033[36m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	echo -e "|                                             |"
	echo -e "|         需要一点时间，请耐心等待！          |"
	echo -e "|       \033[0m如长时间没有数据请用ctrl+c退出        |"
	echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m"
	#获取在线clash核心文件
	result=$(curl -w %{http_code} -kLo /tmp/clash.new $corelink)
	if [ "$result" != "200" ];then
		echo -----------------------------------------------
		echo -e "\033[31m核心文件下载失败！\033[0m"
		echo -----------------------------------------------
		getcore
	else
		echo -e "\033[32m$clashcore核心下载成功，正在替换！\033[0m"
		mv /tmp/clash.new $clashdir/clash
		chmod  777 $clashdir/clash  #授予权限
		sed -i '/clashcore=*/'d $ccfg
		sed -i "1i\clashcore=$clashcore" $ccfg
		sed -i '/clashv=*/'d $ccfg
		sed -i "1i\clashv=$version" $ccfg
		rm -rf /tmp/clashversion
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[32m$clashcore核心替换成功，请手动启动clash服务！\033[0m"
		clashsh
	fi	
else
getcore
fi			
}
getgeo(){
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[33m正在检查更新！\033[0m"
echo $update_url
result=$(curl -w %{http_code} -skLo /tmp/clashversion $update_url/bin/version)
[ "$result" != "200" ] && echo "检查更新失败！" && exit 1
source /tmp/clashversion
echo -----------------------------------------------
echo -e "当前GeoIP版本为：\033[33m $Geo_v \033[0m"
echo -e "最新GeoIP版本为：\033[32m $GeoIP_v \033[0m"
echo -----------------------------------------------
read -p "是否更新数据库文件？[1/0] > " res
if [ "$res" = '1' ]; then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo 正在从服务器获取数据库文件…………
	result=$(curl -w %{http_code} -kLo /tmp/Country.mmdb $update_url/bin/Country.mmdb)
	if [ "$result" != "200" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m文件下载失败！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		getgeo
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[32mGeoIP数据库文件下载成功！\033[0m"
		mv /tmp/Country.mmdb $clashdir/Country.mmdb
		sed -i '/Geo_v=*/'d $ccfg
		sed -i "1i\Geo_v=$GeoIP_v" $ccfg
		rm -rf /tmp/clashversion
		clashsh
	fi
else
clashsh
fi
}
getdb(){
#host=$(ubus call network.interface.lan status | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[36m安装本地版dashboard管理面板\033[0m"
echo -----------------------------------------------
echo -e "\033[32m打开管理面板的速度更快且更稳定"
echo -e "\033[33m需要占用约500kb的本地空间\033[0m"
echo -----------------------------------------------
echo " 1 在/www/clash目录安装(http://$host/clash，可能安装失败！)"
echo " 2 在$clashdir/ui目录安装(http://$host:9999/ui，安装后需重启clash)"
echo -----------------------------------------------
echo " 0 返回上级菜单"
read -p "请输入对应数字 > " num

if [ -z "$num" ];then
	update
elif [ "$num" = '1' ]; then
	dbdir=/www/clash
	hostdir='/clash\033[0;36m访问面板'
elif [ "$num" = '2' ]; then
	dbdir=$clashdir/ui
	hostdir=':9999/ui\033[0;36m访问面板(需重启clash服务！)'
else
	update
fi
	#下载及安装
	if [ -d /www/clash -o -d $clashdir/ui ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m检测到您已经安装过本地面板了！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		read -p "是否覆盖安装？[1/0] > " res
		if [ -z "$res" ]; then
			update
		elif [ "$res" = 1 ]; then
			rm -rf /www/clash
			rm -rf $clashdir/ui
		else
			update
		fi
	fi
	dblink="$update_url/bin/clashdb.tar.gz"
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo 正在连接服务器获取安装文件…………
	result=$(curl -w %{http_code} -kLo /tmp/clashdb.tar.gz $dblink)
	if [ "$result" != "200" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m文件下载失败！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		getdb
	else
		echo -e "\033[33m下载成功，正在解压文件！\033[0m"
		mkdir -p $dbdir > /dev/null
		tar -zxvf '/tmp/clashdb.tar.gz' -C $dbdir > /dev/null
		[ $? -ne 0 ] && echo "文件解压失败！" && exit 1 
		#修改默认host和端口
		sed -i "s/127.0.0.1/$host/g" $dbdir/js/*.js
		sed -i "s/9090/9999/g" $dbdir/js/*.js
		#
		echo -e "\033[32m面板安装成功！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[36m请使用\033[32;4mhttp://$host$hostdir\033[0m"
		rm -rf /tmp/clashdb.tar.gz
		update
	fi
	
update
}
catpac(){
#检测目录
[ ! -d /www/clash -a ! -d $clashdir/ui ]&&echo 未检测到本地Dashboard面板，请先安装面板！&&sleep 1&&getdb
#host=$(ubus call network.interface.lan status | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
[ -d /www/clash ]&&dir="/www/clash"&&pac=http://$host/clash/pac
[ -d $clashdir/ui ]&&dir="$clashdir/ui"&&pac=http://$host:9999/ui/pac
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m生成用于设备WIFI或浏览器的自动PAC代理文件\033[0m"
echo -e "\033[33m非纯净模式不推荐使用此功能\033[0m"
[ -f $dir/pac ]&&echo -e "PAC地址：\033[32m$pac\033[0m"
echo -----------------------------------------------
echo -e " 1 生成PAC文件"
echo -e " 2 清除PAC文件"
echo -----------------------------------------------
echo -e " 0 返回上级菜单"
read -p "请输入对应数字 > " num
	if [ "$num" = '1' ]; then
		echo 'function FindProxyForURL(url, host) {' > $dir/pac
		echo "    return \"SOCKS $host:7890; PROXY $host:7890; DIRECT;\"" >> $dir/pac
		echo '}' >> $dir/pac
		echo -e "\033[33mPAC文件已生成！\033[0m"
		echo -e "PAC地址：\033[32m$pac\033[0m"
		echo "使用教程：https://baike.baidu.com/item/PAC/16292100"
		sleep 2
	elif [[ $num == 2 ]]; then
		rm -rf $dir/pac
		echo -----------------------------------------------
		echo -e "\033[33mPAC文件已清除！\033[0m"
		sleep 1
	fi
}
setserver(){

echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m您可以在此处切换在线更新时使用的资源地址\033[0m"
echo -e "当前源：\033[4;32m$update_url\033[0m"
echo -----------------------------------------------
echo -e " 1 Github源(使用host指定IP)"
echo -e " 2 CDN源(版本同步较慢)"
echo -e " 3 Github源+clash代理(需开启clash服务)"
echo -e " 4 自定义输入(请务必确保路径正确)"
echo -e " 0 返回上级菜单"
read -p "请输入对应数字 > " num
if	[ -z $num ]; then 
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	update
elif [[ $num == 1 ]]; then
	update_url='--resolve raw.githubusercontent.com:443:199.232.68.133 https://raw.githubusercontent.com/juewuy/ShellClash/master'
elif [[ $num == 2 ]]; then
	update_url='https://cdn.jsdelivr.net/gh/juewuy/ShellClash' 
elif [[ $num == 3 ]]; then
	update_url='-x 127.0.0.1:7890 https://raw.githubusercontent.com/juewuy/ShellClash/master'
elif [[ $num == 4 ]]; then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	read -p "请输入个人源路径 > " update_url
	if [ -n $update_url ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m取消输入，返回上级菜单\033[0m"
		update
	fi
elif [[ $num == 9 ]]; then
	update_url='http://127.0.0.1:8080/clash-for-Miwifi'
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	update
fi
#写入mark文件
sed -i '/update_url*/'d $ccfg
sed -i "1i\update_url=\'$update_url\'" $ccfg
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[32m源地址更新成功！\033[0m"
update
}