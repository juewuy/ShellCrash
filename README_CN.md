<h1 align="center">
  <img src="https://github.com/Dreamacro/Crash/raw/master/docs/logo.png" alt="Crash" width="200">
  <br>ShellCrash<br>
</h1>


  <p align="center">
	<a target="_blank" href="https://github.com/Dreamacro/Crash/releases">
    <img src="https://img.shields.io/github/release/Dreamacro/Crash.svg?style=flat-square&label=Crash">
  </a>
  <a target="_blank" href="https://github.com/juewuy/ShellCrash/releases">
    <img src="https://img.shields.io/github/release/juewuy/ShellCrash.svg?style=flat-square&label=ShellCrash&colorB=green">
  </a>
</p>

中文 | [English](README.md) 

功能简介：
--

~通过管理脚本在Shell环境下便捷使用[Crash](https://github.com/Dreamacro/Crash)<br>
~支持在Shell环境下管理[Crash各种功能](https://lancellc.gitbook.io/Crash)<br>
~支持在线导入[Crash](https://github.com/Dreamacro/Crash)支持的分享、订阅及配置链接<br>~支持配置定时任务，支持配置文件定时更新<br>~支持在线安装及使用本地网页面板管理内置规则<br>
~支持路由模式、本机模式等多种模式切换<br>~支持在线更新<br>

设备支持：
--

~支持各种基于OpenWrt或使用OpenWrt二次定制开发的路由器设备<br>
~支持各种运行标准Linux系统（如Debian/CenOS/Armbian等）的设备<br>~兼容Padavan固件（保守模式）、潘多拉固件以及华硕/梅林固件<br>~兼容各类使用Linux内核定制开发的各类型设备<br>

——————————<br>
~更多设备支持，请提issue或前往TG群反馈（需提供设备名称及运行uname -a返回的设备核心信息）<br>

## 常见问题：

[ShellCrash常见问题 | Juewuy's Blog](https://juewuy.github.io/chang-jian-wen-ti/)

## 使用方式：

~确认设备已经开启SSH并获取root权限（带GUI桌面的Linux设备可使用自带终端安装）<br>
~使用SSH连接工具（如putty，JuiceSSH，系统自带终端等）路由器或Linux设备的SSH管理界面或终端界面

~之后在SSH界面执行目标设备对应的安装命令，并按照后续提示完成安装<br>

### 在线安装：<br>

（**如无法连接或出现SSL连接错误，请尝试更换各种不同的安装源！**）<br>

~**标准Linux设备安装：**<br>

```shell
sudo -i #切换到root用户，如果需要密码，请输入密码
bash #如已处于bash环境可跳过
export url='https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master' && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh  && bash /tmp/install.sh && source /etc/profile &> /dev/null
```
或者
```shell
sudo -i #切换到root用户，如果需要密码，请输入密码
bash #如已处于bash环境可跳过
export url='https://gh.jwsc.eu.org/master' && bash -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```

~**路由设备使用curl安装**：<br>

```shell
#GitHub源(可能需要代理)
export url='https://raw.githubusercontent.com/juewuy/ShellCrash/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```
或者
```shell
#jsDelivrCDN源
export url='https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```
或者
```shell
#作者私人源
export url='https://gh.jwsc.eu.org/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```

~**路由设备使用wget安装**：<br>

```Shell
#GitHub源(可能需要代理)
export url='https://raw.githubusercontent.com/juewuy/ShellCrash/master' && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh  && sh /tmp/install.sh && source /etc/profile &> /dev/null
```
或者
```shell
#jsDelivrCDN源
export url='https://fastly.jsdelivr.net/gh/juewuy/ShellCrash@master' && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh  && sh /tmp/install.sh && source /etc/profile &> /dev/null
```

~**老旧设备使用低版本wge安装**：<br>

```Shell
#作者私人http内测源
export url='http://t.jwsc.eu.org' && wget -q -O /tmp/install.sh $url/install.sh  && sh /tmp/install.sh && source /etc/profile &> /dev/null
```

~**DOCKER环境下安装：**<br>

请参考 [ShellCrash_docker 一键脚本和镜像](https://github.com/echvoyager/shellCrash_docker)

### **本地安装：**<br>

如使用在线安装出现问题，请参考：[本地安装ShellCrash的教程 | Juewuy's Blog](https://juewuy.github.io/bdaz) 使用本地安装！<br>

### 使用脚本：<br>

安装完成管理脚本后，执行如下命令使用~

```Shell
Crash 		#进入对话脚本
Crash -h 	#脚本帮助及说明
Crash -u 	#卸载脚本
Crash -t 	#测试模式运行
Crash -s start 	#启动服务
Crash -s stop 	#停止服务
```



#### **运行时的额外依赖**：<br>

> 大部分的设备/系统都已经预装了以下的大部分依赖，使用时如无影响可以无视之

```shell
curl/wget		必须		全部缺少时无法在线安装及更新，无法使用节点保存功能
iptables/nftables	重要		缺少时只能使用纯净模式
crontab			较低		缺少时无法启用定时任务功能
net-tools		极低		缺少时无法正常检测端口占用
ubus/iproute-doc	极低		缺少时无法正常获取本机host地址
```



更新日志：
--

### [点击查看](https://github.com/juewuy/ShellCrash/releases)

交流反馈：
--
### [TG讨论组](https://t.me/ShellCrash) 

机场推荐：
--
#### [大米-群友力荐，流媒体解锁，月付推荐](https://www.bigme.pro/user#/register?code=2PuWY9I7)<br>
#### [Dler-老牌稳定，流媒体解锁，年付推荐](https://dler.best/auth/register?affid=89698)<br>
