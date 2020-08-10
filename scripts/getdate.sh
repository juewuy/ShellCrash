#!/bin/sh
# Copyright (C) Juewuy

getyaml(){
source $ccfg
#前后端订阅服务器地址索引，可在此处添加！
Server=`sed -n ""$server_link"p"<<EOF
subconverter-web.now.sh
subconverter.herokuapp.com
subcon.py6.pw
api.dler.io
api.wcc.best
skapi.cool
subconvert.dreamcloud.pw
EOF`
Config=`sed -n ""$rule_link"p"<<EOF
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Mini_MultiMode.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_AdblockPlus.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Mini_AdblockPlus.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_NoReject.ini
EOF`
#如果传来的是Url链接则合成Https链接，否则直接使用Https链接
if [ -z $Https ];then
	Https="https://$Server/sub?target=clashr&new_name=true&url=$Url&insert=false&config=$Config"
	markhttp=1
fi
#
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo 正在连接服务器获取配置文件…………链接地址为：
echo -e "\033[4;32m$Https\033[0m"
echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
echo -e "\033[36m~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo -e "|                                             |"
echo -e "|         需要一点时间，请耐心等待！          |"
echo -e "|       \033[0m如长时间没有数据请用ctrl+c退出\033[36m        |"
echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\033[0m"
#获取在线yaml文件
yamlnew=$yaml.new
rm -rf $yamlnew > /dev/null 2>&1
result=$(curl -w %{http_code} -kLo $yamlnew $Https)
if [ "$result" != "200" ];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m配置文件获取失败！\033[0m"
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo
	if [ -z $markhttp ];then
		exit;
	else
		read -p "是否更换后端地址后重试？[1/0] > " res
		if [ "$res" = '1' ]; then
			sed -i '/server_link=*/'d $ccfg
			if [ "$server_link" = '7' ]; then
				server_link=0
			fi
			server_link=$(($server_link + 1))
			#echo $server_link
			sed -i "1i\server_link=$server_link" $ccfg
			getyaml
		fi
		exit;
	fi
else
	if cat $yamlnew | grep ', server:' >/dev/null;then
		#替换文件
		if [ -f $yaml ];then
			mv $yaml $yaml.bak
		fi
		mv $yamlnew $yaml
		echo 配置文件已生成！正在重启clash使其生效！
		#重启clash服务
		/etc/init.d/clash restart
		sleep 1
		status=`ps |grep -w 'clash -d'|grep -v grep|wc -l`
		if [[ $status -gt 0 ]];then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e "\033[32mclash服务已启动！\033[0m"
			echo -e "可以使用\033[30;47m http://clash.razord.top \033[0m管理clash内置规则"
			host=$(ubus call network.interface.lan status | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
			echo -e "Host地址:\033[30;46m $host \033[0m;端口:\033[30;46m 9999 \033[0m"
			#将用户链接写入mark
			sed -i '/Https=*/'d $ccfg
			sed -i "7i\Https=\'$Https\'" $ccfg
			clashsh
		else
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			if [ -f $yaml.bak ];then
				echo -e "\033[31mclash服务启动失败！已还原配置文件并重启clash！\033[0m"
				mv $yaml.bak $yaml
				/etc/init.d/clash start
				clashsh
			else
				echo -e "\033[31mclash服务启动失败！请利用测试菜单排查问题！\033[0m"
				clashsh
			fi
		fi
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[33m获取到了配置文件，但格式似乎不对！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		sed -n '1,20p' $yamlnew
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[33m请检查如上配置文件信息:\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	fi
	exit;
fi
exit
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
	echo -e "支持批量导入\033[30;42m Vmess/SSR/SS/Trojan/Sock5 \033[0m等格式的节点链接"
	echo -e "\033[31m使用SSR节点请务必使用支持SSR的clash核心！\033[0m"
	echo -e "多个较短的链接可以用\033[30;47m | \033[0m分隔以一次性输入"
	echo -e "多个较长的链接请尽量分多次输入，可支持多达\033[30;47m 99 \033[0;36m次输入"
	echo -e "\033[32m直接输入回车以结束输入并开始导入链接！\033[0m"
	echo -----------------------------------------------
	echo -e "\033[33m 0 返回上级目录！\033[0m"
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
		if [ -n $Url ];then
			echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
			echo -e 请检查输入的链接是否正确：
			echo -e "\033[4m$Url\033[0m"
			read -p "确认导入配置文件？原配置文件将被更名为config.yaml.bak![1/0] > " res
			if [ "$res" = '1' ]; then
				#将用户链接写入mark
				sed -i '/Url=*/'d $ccfg
				sed -i '/Https=*/'d $ccfg
				sed -i "6i\Url=\'$Url\'" $ccfg
				#获取在线yaml文件
				getyaml
			fi
			clashlink
		fi
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
echo -e "请检查输入的链接是否正确：\033[4m$Url\033[0m"
read -p "确认导入配置文件？原配置文件将被更名为config.bak![1/0] > " res
if [ "$res" = '1' ]; then
	#将用户链接写入mark
	sed -i '/Url=*/'d $ccfg
	sed -i '/Https=*/'d $ccfg
	sed -i "6i\Url=\'$Url\'" $ccfg
	#获取在线yaml文件
	getyaml
else
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo 操作已取消！返回上级菜单！
	clashlink
fi
	clashlink
} 
getlink2(){
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[44m 遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -----------------------------------------------
echo -e "\033[33m仅支持导入可直接在clash中使用的完整订阅链接"
echo -e "\033[36m非完整链接请使用【导入节点/订阅链接】功能"
echo -e "\033[31m注意如节点使用了chacha20加密协议，需将核心更新为clashr核心\033[0m"
echo -----------------------------------------------
echo -e "\033[33m0 返回上级目录！\033[0m"
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
				getyaml
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
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[33m正在检查更新！\033[0m"
result=$(curl -w %{http_code} -skLo /tmp/clashversion $update_url/bin/version)
[ "$result" != "200" ] && echo "检查更新失败！" && exit 1
source /tmp/clashversion
echo -----------------------------------------------
echo -e "当前脚本版本为：\033[33m $versionsh_l \033[0m"
echo -e "最新脚本版本为：\033[32m $versionsh \033[0m"
echo -----------------------------------------------
read -p "是否更新脚本？[1/0] > " res
if [ "$res" = '1' ]; then
	if command -v curl &> /dev/null; then
		echo 正在获取更新文件
		result=$(curl -w %{http_code} -kLo /tmp/clashfm.tar.gz $update_url/bin/clashfm.tar.gz)
	else $result
		wget-ssl -q --no-check-certificate --tries=1 --timeout=10 -O /tmp/clashfm.tar.gz $tarurl
		[ $? -eq 0 ] && result="200"
	fi
	[ "$result" != "200" ] && echo "文件下载失败！" && exit 1
	#解压
	echo -----------------------------------------------
	echo 开始解压文件！
	mkdir -p $dir/clash > /dev/null
	tar -zxvf '/tmp/clashfm.tar.gz' -C $dir/clash/ > /dev/null
	[ $? -ne 0 ] && echo "文件解压失败！" && exit 1 
	#初始化文件目录
	mv $dir/clash/clashservice /etc/init.d/clash #将clash服务文件移动到系统目录
	chmod  777 $dir/clash/clash  #授予权限
	chmod  777 /etc/init.d/clash #授予权限

	#删除临时文件
	rm -rf /tmp/clashfm.tar.gz 
	rm -rf /tmp/clashversion
	#提示
	echo -----------------------------------------------
	echo -e "\033[32m管理脚本更新成功!\033[0m"
	echo -----------------------------------------------
	exit;
else
clashsh
fi
}
getcore(){
source $ccfg
#获取核心及版本信息
if [ ! -f $clashdir/clash ]; then
	clashcore=没有安装核心！
	clashv=''
fi

cpucore=armv7
clashcore_n=$clashcore
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "当前clash核心：\033[47;30m $clashcore \033[46;30m$clashv\033[0m"
echo -e "\033[32m请选择需要下载的核心版本！\033[0m"
echo -----------------------------------------------
echo "1 clash：     运行稳定，内存占用小"
echo "(官方正式版)  不支持SSR，不支持Tun模式"
echo
echo "2 clashr：    稳定，内存占用小，支持SSR"
echo "(clashR修改版)不支持Tun模式"
echo
echo "3 clashpre：  支持SSR，支持Tun模式"
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
echo -e "\033[30;46m感谢Alecthw大神提供的优质GeoIP数据库！！！\033[0m"
echo -----------------------------------------------
echo -e "\033[33m请选择下载源：\033[0m"
echo -e " 1 默认源：$update_url"
echo -e " 2 Alecthw大神提供的服务器"
echo -e " 0 返回上级菜单"
read -p "请输入对应数字 > " num
	if	[ -z $num ]; then 
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m请输入正确的数字！\033[0m"
		update
	elif [[ $num == 0 ]]; then
		update
	elif [[ $num == 1 ]]; then
		geolink="$update_url/bin/Country.mmdb"
		#echo $geolink
	elif [[ $num == 2 ]]; then
		geolink="http://www.ideame.top/mmdb/Country.mmdb"
	else
		echo -e "\033[31m请输入正确的数字！\033[0m"
		update
		exit;
	fi
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo 正在从服务器获取数据库文件…………
	result=$(curl -w %{http_code} -kLo $clashdir/Country.mmdb $geolink)
	if [ "$result" != "200" ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m文件下载失败！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		getgeo
	else
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[32mGeoIP数据库文件下载成功！\033[0m"
			update
	fi
update
}
getdb(){
host=$(ubus call network.interface.lan status | grep \"address\" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}';)
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[36m安装本地版dashboard管理面板\033[0m"
echo -----------------------------------------------
echo -e "\033[32m打开管理面板的速度更快且更稳定"
echo -e "\033[33m需要占用约500kb的本地空间(目录：/www/clash)\033[0m"
echo -e "\033[36m可以使用\033[32;4mhttp://$host/clash\033[0;36m访问面板\033[0m"
echo -----------------------------------------------
read -p "是否安装本地面板？[1/0] > " res
if [ "$res" = '1' ]; then
	if [ -d /www/clash ];then
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[31m检测到您已经安装过本地面板了！\033[0m"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		read -p "是否覆盖安装？[1/0] > " res
		if [ -z "$res" ]; then
			update
		elif [ "$res" = 1 ]; then
			rm -rf /www/clash
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
		mkdir -p /www/clash > /dev/null
		tar -zxvf '/tmp/clashdb.tar.gz' -C /www/clash > /dev/null
		[ $? -ne 0 ] && echo "文件解压失败！" && exit 1 
		echo -e "\033[32m面板安装成功！"
		echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		echo -e "\033[36m请使用\033[32;4mhttp://$host/clash\033[0;36m访问面板\033[0m"
		rm -rf /tmp/clashdb.tar.gz
		update
	fi
fi		
update
}
setserver(){

echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[30;47m您可以在此处切换在线更新时使用的资源地址\033[0m"
echo -e "当前源：\033[4;32m$update_url\033[0m"
echo -----------------------------------------------
echo -e " 1 CDN源(感谢\033[4;32mwww.jsdelivr.com\033[0m，推荐)"
echo -e " 2 Github源(不稳定，不推荐)"
echo -e " 3 Github源+clash代理(需开启clash服务，推荐)"
echo -e " 4 自定义输入"
echo -e " 0 返回上级菜单"
read -p "请输入对应数字 > " num
if	[ -z $num ]; then 
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo -e "\033[31m请输入正确的数字！\033[0m"
	update
elif [[ $num == 1 ]]; then
	update_url="https://cdn.jsdelivr.net/gh/juewuy/clash-for-Miwifi"
elif [[ $num == 9 ]]; then
	update_url="https://juewuy.xyz/clash"
elif [[ $num == 2 ]]; then
	update_url="https://raw.githubusercontent.com/juewuy/clash-for-Miwifi/master"
elif [[ $num == 3 ]]; then
	update_url="-x 127.0.0.1:7890 https://raw.githubusercontent.com/juewuy/clash-for-Miwifi/master"
elif [[ $num == 4 ]]; then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	read -p "请输入个人源路径 > " update_url
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