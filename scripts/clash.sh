 #!/bin/sh
# Copyright (C) Juewuy

echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**             Clash for Miwifi              **"
echo "**                             by  Juewuy    **"
echo "***********************************************"

getconfig(){
#文件路径
cpath=$clashdir #clash目录地址
sed -i "/^cpath\=*/ccpath\=$cpath" /etc/init.d/clash #同步service文件中的clash路径
ccfg=$cpath/mark
yaml=$cpath/config.yaml
#检查标识文件
if [ ! -f "$ccfg" ]; then
echo mark文件不存在，正在创建！
cat >$ccfg<<EOF
#标识clash运行状态的文件，请勿改动！
EOF
fi
source $ccfg
#获取自启状态
if [ $auto_start = true ] > /dev/null 2>&1; then 
auto="\033[32m已设置开机启动！\033[0m"
auto1="禁用clash开机启动"
else
auto="\033[31m未设置开机启动！\033[0m"
auto1="允许clash开机启动"
fi
#获取运行模式
if [ ! -n "$redir_mod" ]; then
sed -i "2i\redir_mod=Redir模式" $ccfg
redir_mod=Redir模式
fi
#获取运行状态
uid=`ps |grep -w 'clash -d'|grep -v grep|awk '{print $1}'`
if [ $uid > 0 ];then
run="\033[32m正在运行（$redir_mod）\033[0m"
VmRSS=`cat /proc/$uid/status|grep -w VmRSS|awk '{print $2,$3}'`
  #获取运行时长
  if [ "$start_time" > 0 ] > /dev/null 2>&1; then 
  time=$((`date +%s`-$start_time))
  day=$(($time/86400))
    if [[ $day != 0 ]]; then 
    day=$day天
    else
    day=""
    fi
  time=`date -u -d @${time} +"%-H小时%-M分%-S秒"`
  fi
else
run="\033[31m没有运行（$redir_mod）\033[0m"
fi
#输出状态
echo -----------------------------------------------
echo -e "Clash服务"$run"，"$auto""
if [ $uid > 0 ];then
echo -e "当前内存占用：\033[44m"$VmRSS"\033[0m，已运行：\033[46;30m"$day"\033[44;37m"$time"\033[0m"
fi
}

getyaml(){
source $ccfg
#前后端订阅服务器地址索引，可在此处添加！
Server=`sed -n ""$server_link"p"<<EOF
subconverter-web.now.sh
subcon.py6.pw
api.dler.io
api.wcc.best
EOF`
Config=`sed -n ""$rule_link"p"<<EOF
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Mini_MultiMode.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_AdblockPlus.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_Mini_AdblockPlus.ini
https://raw.githubusercontent.com/ACL4SSR/ACL4SSR/master/Clash/config/ACL4SSR_Online_NoReject.ini
EOF`
Https="https://$Server/sub?target=clashr&new_name=true&url=$Url&insert=false&config=$Config"
echo -----------------------------------------------
echo 正在连接服务器获取配置文件…………链接地址为：
echo -e "\033[4;32m$Https\033[0m"
echo 可以手动复制该链接到浏览器打开并查看数据是否正常！
echo -e "\033[36m-----------------------------------------------"
echo -e "|                                             |"
echo -e "|         需要一点时间，请耐心等待！          |"
echo -e "|       \033[0m如长时间没有数据请用ctrl+c退出        |"
echo -e "-----------------------------------------------\033[0m"
#获取在线yaml文件
yamlnew=$yaml.new
rm $yamlnew > /dev/null 2>&1

result=$(curl -w %{http_code} -kLo $yamlnew $Https)
if [ "$result" != "200" ];then
echo -----------------------------------------------
echo -e "\033[31m配置文件获取失败！\033[0m"
echo -----------------------------------------------
echo
read -p "是否更换后端地址后重试？[1/0] > " res
  if [ "$res" = '1' ]; then
  	sed -i '/server_link=*/'d $ccfg
	if [ "$server_link" = '4' ]; then
	server_link=0
	fi
	server_link=$(($server_link + 1))
	#echo $server_link
    sed -i "5i\server_link=$server_link" $ccfg
	getyaml
  fi
exit;
else
  if cat $yamlnew | grep ', server:' >/dev/null;then
##########需要变更的配置###########
redir='redir-port: 7892'
external='external-controller: 0.0.0.0:9999'
dns='dns: {enable: true, listen: 0.0.0.0:1053, fake-ip-range: 198.18.0.1/16, enhanced-mode: fake-ip, nameserver: [114.114.114.114, 127.0.0.1:53], fallback: [tcp://1.0.0.1, tls://dns.google:853]}'
tun='tun: {enable: false, stack: system}' 
exper='experimental: {ignore-resolve-fail: true, interface-name: en0}'
###################################
	#预删除需要添加的项目
	sed -i '/redir-port:*/'d $yamlnew
	sed -i '/external-controller:*/'d $yamlnew
	sed -i '/dns:*/'d $yamlnew
	sed -i '/tun:*/'d $yamlnew
	sed -i '/experimental:*/'d $yamlnew
	#添加配置
	sed -i "2a$redir" $yamlnew
	sed -i "6a$external" $yamlnew
	sed -i "7a$dns" $yamlnew
	sed -i "8a$tun" $yamlnew
	sed -i "9a$exper" $yamlnew
	if [ "$skip_cert" != "未开启" ];then
	sed -i "10,99s/sni: \S*/\1skip-cert-verify: true}/" $yamlnew  #跳过trojan本地证书验证
	sed -i '10,99s/}}/}, skip-cert-verify: true}/' $yamlnew  #跳过v2+ssl本地证书验证
	fi
	#替换文件
	mv $yaml $yaml.bak
	mv $yamlnew $yaml
	echo 配置文件已生成！正在重启clash使其生效！
	#重启clash服务
	/etc/init.d/clash stop
	/etc/init.d/clash start
	sleep 1
	uid=`ps |grep -w 'clash -d'|grep -v grep|awk '{print $1}'`
		if [ $uid > 0 ];then
		echo -----------------------------------------------
		echo -e "\033[32mclash服务已启动！\033[0m"
		echo 可以使用 http://clash.razord.top （IP为网关IP，端口为9999）管理clash内置规则
		clashsh
		else
		echo -----------------------------------------------
		echo -e "\033[31mclash服务启动失败！请检查配置文件！\033[0m"
		clashsh
		fi
		exit;
  else
  echo -----------------------------------------------
  echo -e "\033[33m囧囧囧 获取到了配置文件，但格式似乎不对 囧囧囧\033[0m"
  echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  sed -n '1,20p' $yamlnew
  echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  echo -e "\033[33m请检查如上配置文件信息:\033[0m"
  echo -----------------------------------------------
  fi
  exit;
fi
exit
}
getlink(){
#设置输入循环
i=1
while [ $i -le 9 ]
do
echo -----------------------------------------------
echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -----------------------------------------------
echo -e "\033[33m支持批量导入\033[30;46m Http/Https/Clash \033[0;33m等格式的订阅链接"
echo -e "支持批量导入\033[30;42m Vmess/SSR/SS/Trojan/Sock5 \033[0;33m等格式的节点链接"
echo -e "\033[36m多个较短的链接可以用\033[30;47m | \033[0;36m分隔以一次性输入"
echo -e "多个较长的链接请尽量分多次输入，可支持多达\033[30;47m 9 \033[0;36m次输入"
echo -e "\033[0m注意SSR/SS不支持\033[30;47m chacha20加密 \033[0m"
echo -e "\033[44;37m直接输入回车以结束输入并开始导入链接！\033[0m"
echo -e "\033[33m 0 返回上级目录！\033[0m"
echo
url=""
read -p "请输入第"$i"个链接 > " url
  test=$(echo $url | grep "://")
  url=`echo ${url/\ \(*\)/''}`   #删除恶心的超链接内容
  url=`echo ${url/*\&url\=/""}`   #将clash完整链接还原成单一链接
  url=`echo ${url/\&config\=*/""}`   #将clash完整链接还原成单一链接
  url=`echo ${url//\&/\%26}`   #将分隔符 & 替换成urlcode：%26
  if [[ "$test" != "" ]];then
	if [[ $i == 1 ]];then
	Url="$url"
	else
	Url="$Url"\|"$url"
	fi
  i=$(($i+1))
  elif [ -z $url ];then
	  if [ -n $Url ];then
	  echo -----------------------------------------------
	  echo -e 请检查输入的链接是否正确：
      echo -e "\033[4m$Url\033[0m"
	  read -p "确认导入配置文件？原配置文件将被更名为config.bak![1/0] > " res
	    if [ "$res" = '1' ]; then
		#将用户链接写入mark
		sed -i '/Url=*/'d $ccfg
		sed -i "6i\Url=\'$Url\'" $ccfg
		#获取在线yaml文件
		getyaml
		exit;
	    fi
		clashlink
	  fi
  elif [[ $url == 0 ]];then
    clashlink
  else
    echo -----------------------------------------------
    echo -e "\033[31m请输入正确的订阅/分享链接！！！\033[0m"
  fi
done
echo -----------------------------------------------
echo 输入太多啦，可能会导致订阅失败！
echo "多个较短的链接请尽量用“|”分隔以一次性输入！"
echo -e "请检查输入的链接是否正确：\033[4m$Url\033[0m"
read -p "确认导入配置文件？原配置文件将被更名为config.bak![1/0] > " res
	    if [ "$res" = '1' ]; then
		#将用户链接写入mark
		sed -i '/Url=*/'d $ccfg
		sed -i "6i\Url=\'$Url\'" $ccfg
		#获取在线yaml文件
		getyaml
		exit;
		else
		echo -----------------------------------------------
		echo 操作已取消！返回上级菜单！
		clashlink
	    fi
		clashlink
} 
clashlink(){
#获取订阅规则
if [ ! -n "$rule_link" ]; then
sed -i '/rule_link=*/'d $ccfg
sed -i "4i\rule_link=1" $ccfg
rule_link=1
fi
#获取后端服务器地址
if [ ! -n "$server_link" ]; then
sed -i '/server_link=*/'d $ccfg
sed -i "5i\server_link=3" $ccfg
server_link=3
fi
echo -----------------------------------------------
echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -e "\033[32m 欢迎使用订阅功能！\033[0m"
echo -e 1 输入订阅链接
echo -e 2 选取规则模版
echo -e 3 选择后端地址
echo -e 4 还原配置文件
echo -e 5 手动更新订阅
echo -e 6 设置自动更新（未完成）
echo -e 0 返回上级菜单
read -p "请输入对应数字 > " num
if [ -z $num ];then
  echo -----------------------------------------------
  echo -e "\033[31m请输入正确的数字！\033[0m"
  clashsh
elif [[ $num == 1 ]];then
  getlink
elif [[ $num == 2 ]];then
  echo -----------------------------------------------
  echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
  echo 当前使用规则为：$rule_link
  echo 1 ACL4SSR默认通用版（推荐）
  echo 2 ACL4SSR精简全能版（推荐）
  echo 3 ACL4SSR通用版去广告加强
  echo 4 ACL4SSR精简版去广告加强
  echo 5 ACL4SSR通用版无去广告
  echo 0 返回上级菜单
  read -p "请输入对应数字 > " num
    if [ -z $num ];then
	  echo -----------------------------------------------
	  echo -e "\033[31m请输入正确的数字！\033[0m"
	  clashlink
	else
	  #将对应标记值写入mark
	  sed -i '/rule_link*/'d $ccfg
      sed -i "4i\rule_link="$num"" $ccfg	
	  echo -----------------------------------------------	  
	  echo -e "\033[32m设置成功！返回上级菜单！\033[0m"
	  clashlink
	fi
elif [[ $num == 3 ]];then
  echo -----------------------------------------------
  echo -e "\033[44m 实验性功能，遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
  echo 当前使用后端为：$server_link
  echo 1 subconverter-web.now.sh
  echo 2 subcon.py6.pw
  echo 3 api.dler.io
  echo 4 api.wcc.best
  echo 0 返回上级菜单
  read -p "请输入对应数字 > " num
    if [ -z $num ];then
	  echo -----------------------------------------------
	  echo -e "\033[31m请输入正确的数字！\033[0m"
	  clashlink
	else
	  if [[ $num == 0 ]];then
	  clashlink
	  fi
	  #将对应标记值写入mark
	  sed -i '/server_link*/'d $ccfg
      sed -i "4i\server_link="$num"" $ccfg		
      echo -----------------------------------------------	  
	  echo -e "\033[32m设置成功！返回上级菜单！\033[0m"
	  clashlink
	fi
elif [[ $num == 4 ]];then
  yamlbak=$yaml.bak
  if [ ! -f "$yaml".bak ];then
  echo -----------------------------------------------
  echo -e "\033[31m没有找到配置文件的备份！\033[0m"
  else
  echo -----------------------------------------------
  echo -e 备份文件共有"\033[32m`wc -l < $yamlbak`\033[0m"行内容，当前文件共有"\033[32m`wc -l < $yaml`\033[0m"行内容
  read -p "确认还原配置文件？此操作不可逆！[1/0] > " res
	if [ "$res" = '1' ]; then
	mv $yamlbak $yaml
    echo -----------------------------------------------
	echo -e "\033[32m配置文件已还原！请手动重启clash服务！\033[0m"
	else 
    echo -----------------------------------------------
	echo -e "\033[31m操作已取消！返回上级菜单！\033[0m"
	fi
  fi
  clashsh
elif [[ $num == 5 ]];then
  if [ ! -n "$Url" ];then
    echo -----------------------------------------------
    echo 没有找到你的订阅链接！请先输入链接！
  clashlink
  else
    echo -----------------------------------------------
    echo -----------------------------------------------
    echo -e "\033[33m当前系统记录的订阅链接为：\033[0m"
    echo -e "\033[4;32m$Url\033[0m"
    echo -----------------------------------------------
	read -p "确认更新配置文件？[1/0] > " res
	  if [ "$res" = '1' ]; then
      getyaml
	  fi
	  clashlink
  fi
elif [[ $num == 0 ]];then
  clashsh
else
  echo -----------------------------------------------
  echo -e "\033[31m请输入正确的数字！\033[0m"
  exit;
fi
}
clashadv(){
#获取高级配置
if [ ! -n "$skip_cert" ]; then
sed -i "2i\skip_cert=已开启" $ccfg
skip_cert=已开启
fi
#
echo -----------------------------------------------
echo -e "\033[33m欢迎使用高级模式菜单：\033[0m"
echo 1 切换代理模式（Tun/Redir）
echo 2 跳过本地证书验证（用于解决自建节点出现证书验证错误）：$skip_cert
echo 3 更新clash核心文件（施工中）
echo 3 更新GeoIP数据库（施工中）
echo 4 更新管理脚本（施工中）
echo 9 卸载clash
echo 0 返回上级菜单 
read -p "请输入对应数字 > " num
if [[ $num -le 9 ]] > /dev/null 2>&1; then 
  if [[ $num == 0 ]]; then
    clashsh
  
  elif [[ $num == 1 ]]; then
    echo -----------------------------------------------
    echo -e "当前代理模式为：\033[47;30m $redir_mod \033[0m"
	echo -e "\033[33m切换模式时会重启clash服务，可能会导致短时间的网络中断！\033[0m"
	echo "1 Tun模式：  支持UDP转发且延迟低"
	echo "             但CPU及内存占用更高"
	echo "             适合外服游戏用户"
	echo "2 Redir模式：CPU以及内存占用较低"
	echo "             但不支持UDP流量转发"
	echo "             日常使用推荐此模式"
	echo 0 返回上级菜单 
	read -p "请输入对应数字 > " num
	if [[ $num == 0 ]]; then
	  clashadv
	elif [[ $num == 1 ]]; then
	  if [[ $redir_mod = "Redir模式" ]]; then
	    sed -i '/redir_mod*/'d $ccfg
		sed -i "2i\redir_mod=Tun模式" $ccfg	#修改redir_mod标记
	    sed -i '5,20s/tun: {enable: false/tun: {enable: true/' $yaml		#修改配置文件
		if [ $uid > 0 ];then > /dev/null 2>&1
		echo -----------------------------------------------
		echo -e "\033[33m正在重启clash进程……\033[0m"
		/etc/init.d/clash stop > /dev/null 2>&1
		fi	  
		/etc/init.d/clash start
		sleep 1
		uid=`ps |grep -w 'clash -d'|grep -v grep|awk '{print $1}'`	  
		if [ $uid > 0 ];then
		echo -----------------------------------------------
		echo -e "\033[32mclash服务已启动！\033[0m"
		echo -e "\033[33mclash已成功切换为：\033[47;34m Tun模式! \033[0m"
		echo -e 可以使用 "\033[32mhttp://clash.razord.top\033[0m"（IP为网关IP，端口为9999）管理clash内置规则
		clashsh
		else
		echo -----------------------------------------------
		echo -e "\033[31mclash服务启动失败！请检查配置文件！\033[0m"
		clashsh
		fi  
	  else
	    echo -----------------------------------------------
		echo -e "\033[33m当前已经处于Tun模式，无需重复设置！\033[0m"
		clashadv
	  fi
	  
	elif [[ $num == 2 ]]; then
	  if [[ $redir_mod = "Tun模式" ]]; then
	    sed -i '/redir_mod*/'d $ccfg
		sed -i "2i\redir_mod=Redir模式" $ccfg	#修改redir_mod标记
	    sed -i '5,20s/tun: {enable: true/tun: {enable: false/' $yaml		#修改配置文件
		if [ $uid > 0 ];then
		echo -----------------------------------------------
		echo -e "\033[33m正在重启clash进程……\033[0m"
		/etc/init.d/clash stop > /dev/null 2>&1
		fi	  
		/etc/init.d/clash start
		sleep 1
		uid=`ps |grep -w 'clash -d'|grep -v grep|awk '{print $1}'`	  
		if [ $uid > 0 ];then
		echo -----------------------------------------------
		echo -e "\033[32mclash服务已启动！\033[0m"
		echo -e "\033[33mclash已成功切换为：\033[47;34m Redir模式! \033[0m"
		echo -e 可以使用 "\033[32mhttp://clash.razord.top\033[0m"（IP为网关IP，端口为9999）管理clash内置规则
		clashsh
		else
		echo -----------------------------------------------
		echo -e "\033[31mclash服务启动失败！请检查配置文件！\033[0m"
		clashsh
		fi  
	  else
	    echo -----------------------------------------------
		echo -e "\033[33m当前已经处于Redir模式，无需重复设置！\033[0m"
		clashadv
	  fi
	else
	  echo -----------------------------------------------
	  echo -e "\033[31m请输入正确的数字！\033[0m"
      clashadv
	fi
  elif [[ $num == 2 ]]; then	
	sed -i '/skip_cert*/'d $ccfg
	echo -----------------------------------------------
	  if [ "$skip_cert" = "未开启" ] > /dev/null 2>&1; then 
	  sed -i "1i\skip_cert=已开启" $ccfg
	  echo -e "\033[33m已设为开启跳过本地证书验证！！\033[0m"
	  skip_cert=已开启
	  else
	  /etc/init.d/clash enable
	  sed -i "1i\skip_cert=未开启" $ccfg
	  echo -e "\033[33m已设为禁止跳过本地证书验证！！\033[0m"
	  skip_cert=未开启
	  fi
	clashadv
  
  elif [[ $num == 9 ]]; then
    read -p "确认卸载clash？（警告：该操作不可逆！）[1/0] " res
	if [ "$res" = '1' ]; then
    /etc/init.d/clash disable
    /etc/init.d/clash stop
    rm -rf $cpath
    rm /etc/init.d/clash
    rm $csh
    echo 已卸载clash相关文件！
	fi
    exit;
  else
    echo -e "\033[31m暂未支持的选项！\033[0m"
    clashadv
  fi
else
  echo -----------------------------------------------
  echo -e "\033[31m请输入正确的数字！\033[0m"
  clashsh
fi
exit;
}
clashsh(){
#############################
getconfig
#############################
echo 1 启动/重启clash服务
echo 2 测试代理服务器连通性
echo 3 停止clash服务
echo 4 $auto1
echo 5 设置定时任务（施工中）
echo 6 使用链接导入节点/订阅
echo 7 高级设置
echo 8 测试菜单
echo 0 退出脚本
read -p "请输入对应数字 > " num
if [[ $num -le 8 ]] > /dev/null 2>&1; then 
  if [[ $num == 0 ]]; then
  exit;
  
  elif [[ $num == 1 ]]; then
	if [ ! -f "$yaml" ];then
	echo -----------------------------------------------
	echo -e "\033[31m没有找到配置文件，请先导入节点/订阅链接！\033[0m"
	clashlink
	fi
    if [ $uid > 0 ];then
	echo -----------------------------------------------
	/etc/init.d/clash stop > /dev/null 2>&1
	echo -e "\033[31mClash服务已停止！\033[0m"
	fi
    /etc/init.d/clash start
	sleep 1
    uid=`ps |grep -w 'clash -d'|grep -v grep|awk '{print $1}'`
      if [ $uid > 0 ];then
	  echo -----------------------------------------------
      echo -e "\033[32mclash服务已启动！\033[0m"
	  echo 可以使用 http://clash.razord.top （IP为网关IP，端口为9999）管理clash内置规则
	  clashsh
      else
	  echo -----------------------------------------------
      echo -e "\033[31mclash服务启动失败！请检查配置文件！\033[0m"
	  clashsh
      fi
	  exit;
  
  elif [[ $num == 2 ]]; then
      echo 注意：测试结果不保证一定准确！
      delay=`curl -kx socks5://127.0.0.1:7891 -o /dev/null -s -w '%{time_starttransfer}' 'https://google.tw' & { sleep 3 ; kill $! & }` > /dev/null 2>&1
	  delay=`echo |awk "{print $delay*1000}"` > /dev/null 2>&1
	  echo -----------------------------------------------
	  if [ `echo ${#delay}` -gt 1 ];then
	  echo -e "\033[32m连接成功！响应时间为："$delay" ms\033[0m"
	  else
	  echo -e "\033[31m连接超时！请重试或检查节点配置！\033[0m"
	  fi
	  clashsh
  elif [[ $num == 3 ]]; then
  /etc/init.d/clash stop > /dev/null 2>&1
  echo -----------------------------------------------
  echo -e "\033[31mClash服务已停止！\033[0m"
  echo -----------------------------------------------
  exit;

  elif [[ $num == 4 ]]; then
    sed -i '/auto_start*/'d $ccfg
	echo -----------------------------------------------
	  if [ $auto_start = true ] > /dev/null 2>&1; then 
	  /etc/init.d/clash disable
	  sed -i "1i\auto_start=false" $ccfg
	  echo -e "\033[33m已禁止Clash开机启动！\033[0m"
	  else
	  /etc/init.d/clash enable
	  sed -i "1i\auto_start=true" $ccfg
	  echo -e "\033[32m已设置Clash开机启动！\033[0m"
	  fi
	clashsh

  elif [[ $num == 5 ]]; then
echo -----------------------------------------------
echo -e "\033[31m正在施工中，敬请期待！\033[0m"
echo -e "\033[32m正在施工中，敬请期待！\033[0m"
echo -e "\033[33m正在施工中，敬请期待！\033[0m"
echo -e "\033[34m正在施工中，敬请期待！\033[0m"
echo -e "\033[35m正在施工中，敬请期待！\033[0m"
echo -e "\033[36m正在施工中，敬请期待！\033[0m"

  clashsh
    
  elif [[ $num == 6 ]]; then
  clashlink

  elif [[ $num == 7 ]]; then
  clashadv
  elif [[ $num == 8 ]]; then
	echo -----------------------------------------------
	echo -e "\033[31m这里是隐藏的测试命令菜单\033[0m"
	echo 1 不能正常运行时，手动运行clash查看报错信息：
	echo 2 查看系统53端口占用 
	echo 3 测试ssl加密（aes-128-gcm）跑分
	echo 4 查看iptables端口转发详情
	echo 5 查看config.yaml前40行
	echo 0 返回上级目录！
	read -p "请输入对应数字 > " num
	if [[ $num == 0 ]]; then
		clashsh
	elif [[ $num == 1 ]]; then
	echo -e "\033[31m如有报错请截图后到TG群询问！！！\033[0m"
	$cpath/clash -d $cpath & { sleep 3 ; kill $! & }
	echo -e "\033[31m如有报错请截图后到TG群询问！！！\033[0m"
	exit;
	elif [[ $num == 2 ]]; then
	echo -----------------------------------------------
	netstat -ntulp |grep 53
	echo -----------------------------------------------
	exit;
	elif [[ $num == 3 ]]; then
	echo -----------------------------------------------
	openssl speed -multi 4 -evp aes-128-gcm
	echo -----------------------------------------------
	exit;
	elif [[ $num == 4 ]]; then
	echo -----------------------------------------------
	iptables  -t nat  -L PREROUTING --line-numbers
	echo -----------------------------------------------
	exit;
	elif [[ $num == 5 ]]; then
	echo -----------------------------------------------
	sed -n '1,40p' $yaml
	echo -----------------------------------------------
	exit;
	else
	echo -----------------------------------------------
	echo -e "\033[31m请输入正确的数字！\033[0m"
	clashadv
	fi
  else
  echo -----------------------------------------------
  echo -e "\033[31m请输入正确的数字！\033[0m"
  fi
  exit 1
else
echo -----------------------------------------------
echo -e "\033[31m请输入正确的数字！\033[0m"
fi
exit 1
}
clashsh