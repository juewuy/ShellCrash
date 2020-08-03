 #!/bin/sh
# Copyright (C) Juewuy

echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**             Clash for Miwifi              **"
echo "**                             by  Juewuy    **"
echo "***********************************************"

url="https://juewuy.xyz/clash"

echo -e "\033[44m 使用中如遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -e "\033[37m 目前仅支持小米AX系列3款路由器"
echo -e "\033[44m 其余型号可到TG群报名参与测试\033[0m"
echo -----------------------------------------------
echo -e "\033[32m1 在默认目录(/etc)安装Clash for Miwifi"
echo -e "\033[33m2 手动设置安装目录（请不要设为/tmp,重启会消失）"
echo -e "\033[0m0 退出安装"
echo -----------------------------------------------
read -p "请输入相应数字 > " num

if [ -z $num ];then
	echo 安装已取消
	exit;
elif [[ $num == 1 ]];then
	clashdir=/etc/clash
elif [[ $num == 2 ]];then
	echo -----------------------------------------------
	echo '可用路径 剩余空间:'
	df -h | awk '{print $6,$2}'| sed 1d 
	read -p "请输入自定义路径 > " dir
	if [ -z $dir ];then
		echo 路径错误！已取消安装！
		exit;
	fi
else
	echo 安装已取消
	exit;
fi


echo 开始从服务器获取安装文件！
tarurl=$url/bin/clashfm.tar.gz



if command -v curl &> /dev/null; then
	result=$(curl -w %{http_code} -skLo /tmp/clashfm.tar.gz $tarurl)
else
	wget-ssl -q --no-check-certificate --tries=1 --timeout=10 -O /tmp/clashfm.tar.gz $tarurl
	[ $? -eq 0 ] && result="200"
fi
[ "$result" != "200" ] && echo "文件下载失败！" && exit 1


echo 开始解压文件！
tar -zxvf /tmp/clashfm.tar.gz -C $dir > /dev/null
[ $? -ne 0 ] && echo "文件解压失败！" && exit 1 

mv $dir/clashservice /etc/init.d/clash #将clash服务文件移动到系统目录
chmod  777 $dir/clash  #授予权限
chmod  777 /etc/init.d/clash #授予权限
sed -i '/alias clash=*/'d /etc/profile
sed -i '$aalias\ clash=\"sh \/etc\/clash\/clash.sh\"' /etc/profile
alias clash="sh /etc/clash/clash.sh" #设置系统变量

rm -rf /tmp/clashfm.tar.gz #删除临时文件

echo clash for Miwifi 已经安装成功!
echo -e "\033[33m直接输入\033[32mclash命令即可管理！！！\033[0m"

