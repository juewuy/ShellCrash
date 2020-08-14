 #!/bin/sh
# Copyright (C) Juewuy

echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**             Clash for Miwifi              **"
echo "**                             by  Juewuy    **"
echo "***********************************************"

url="https://juewuy.xyz/clash/"
result=$(curl -w %{http_code} -skLo /tmp/clashversion $url/bin/version)
[ "$result" != "200" ] && echo "无法连接到服务器！" && exit 1
source /tmp/clashversion
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "~~~~版本：\033[32m$versionsh\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[44m使用中如遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -e "\033[37m目前仅支持小米AX系列3款路由器"
echo -e "\033[44m其余型号可到TG群报名参与测试\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[32m 1 在默认目录(/etc)安装Clash for Miwifi"
echo -e "\033[33m 2 手动设置安装目录（不明勿用！）"
echo -e "\033[0m 0 退出安装"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
read -p "请输入相应数字 > " num

if [ -z $num ];then
	echo 安装已取消
	exit;
elif [[ $num == 1 ]];then
	dir=/etc
elif [[ $num == 2 ]];then
	echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	echo '可用路径 剩余空间:'
	df -h | awk '{print $6,$2}'| sed 1d 
	echo '路径是必须带 / 的格式，写入虚拟内存(/tmp,/sys,..)的文件会在重启后消失！！！'
	read -p "请输入自定义路径 > " dir
	if [ -z $dir ];then
		echo 路径错误！已取消安装！
		exit;
	fi
else
	echo 安装已取消
	exit;
fi
#下载文件包
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo 开始从服务器获取安装文件！
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
tarurl=$url/bin/clashfm.tar.gz
if command -v curl &> /dev/null; then
	result=$(curl -w %{http_code} -kLo /tmp/clashfm.tar.gz $tarurl)
else $result
	wget-ssl -q --no-check-certificate --tries=1 --timeout=10 -O /tmp/clashfm.tar.gz $tarurl
	[ $? -eq 0 ] && result="200"
fi
[ "$result" != "200" ] && echo "文件下载失败！" && exit 1
#解压
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo 开始解压文件！
mkdir -p $dir/clash > /dev/null
tar -zxvf '/tmp/clashfm.tar.gz' -C $dir/clash/
[ $? -ne 0 ] && echo "文件解压失败！" && exit 1 
#初始化文件目录
mv $dir/clash/clashservice /etc/init.d/clash #将clash服务文件移动到系统目录
chmod  777 /etc/init.d/clash #授予权限
if [ ! -f "$dir/clash/mark" ]; then
cat >$dir/clash/mark<<EOF
#标识clash运行状态的文件，不明勿动！
EOF
fi
sed -i '/versionsh_l=*/'d $dir/clash/mark
sed -i "1i\versionsh_l=$versionsh" $dir/clash/mark
#设置环境变量
sed -i '/alias clash=*/'d /etc/profile
echo "alias clash=\"sh $dir/clash/clash.sh\"" >> /etc/profile #设置快捷命令环境变量
sed -i '/export clashdir=*/'d /etc/profile
echo "export clashdir=\"$dir/clash\"" >> /etc/profile #设置clash路径环境变量
#删除临时文件
rm -rf /tmp/clashfm.tar.gz 
#提示
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo clash for Miwifi 已经安装成功!
echo -e "\033[33m直接输入\033[30;47m clash \033[0;33m命令即可管理！！！\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

