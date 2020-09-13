#! /bin/bash
# Copyright (C) Juewuy

echo "***********************************************"
echo "**                 欢迎使用                  **"
echo "**                ShellClash                 **"
echo "**                             by  Juewuy    **"
echo "***********************************************"
url="https://cdn.jsdelivr.net/gh/juewuy/ShellClash@latest"
result=$(curl -w %{http_code} -skLo /tmp/clashversion $url/bin/version)
[ "$result" != "200" ] && echo "无法连接到服务器！" && exit 1
source /tmp/clashversion
echo -e "~~~~版本：\033[32m$versionsh\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[44m如遇问题请加TG群反馈：\033[42;30m t.me/clashfm \033[0m"
echo -e "\033[37m支持各种基于openwrt的路由器设备"
echo -e "\033[33m有限支持debian、centos等Linux系统\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[32m 1 在默认目录(/etc)安装ShellClash"
echo -e "\033[33m 2 手动设置安装目录（不明勿用！）"
echo -e "\033[0m 0 退出安装"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
read -p "请输入相应数字 > " num

if [ -z $num ];then
	echo 安装已取消
	exit;
elif [ "$num" = "1" ];then
	dir=/etc
elif [ "$num" = "2" ];then
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
shtype=sh&&[ -n $(ls -l /bin/sh|grep -o dash) ]&&shtype=bash
sed -i '/alias clash=*/'d /etc/profile
echo "alias clash=\"$shtype $dir/clash/clash.sh\"" >> /etc/profile #设置快捷命令环境变量
sed -i '/export clashdir=*/'d /etc/profile
echo "export clashdir=\"$dir/clash\"" >> /etc/profile #设置clash路径环境变量
#删除临时文件
rm -rf /tmp/clashfm.tar.gz 
#提示
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo ShellClash 已经安装成功!
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo -e "\033[33m输入\033[30;47m clash \033[0;33m命令即可管理！！！\033[0m"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

