<h1 align="center">
  <img src="https://github.com/Dreamacro/clash/raw/master/docs/logo.png" alt="Clash" width="200">
  <br>ShellClash<br>
</h1>


  <p align="center">
	<a target="_blank" href="https://github.com/Dreamacro/clash/releases">
    <img src="https://img.shields.io/github/release/Dreamacro/Clash.svg?style=flat-square&label=Clash">
  </a>
  <a target="_blank" href="https://github.com/juewuy/ShellClash/releases">
    <img src="https://img.shields.io/github/release/juewuy/ShellClash.svg?style=flat-square&label=ShellClash&colorB=green">
  </a>
</p>

[中文](README_CN.md) | English

## Function introduction: 

~Convenient use in Shell environment through management script [Clash](https://github.com/Dreamacro/clash)<br>~Support management of [Clash functions](https://lancellc.gitbook.io/clash)<br>~Support online import [Clash](https://github.com/Dreamacro/clash) supports sharing, subscription and configuration links<br>~Support configuration timing tasks, support configuration file timing updates<br>~Support online installation and Use local web panel to manage built-in rules<br>~Support routing mode, native mode and other mode switching<br>~Support online update<br>

## Equipment support:

~Support various router devices based on OpenWrt or secondary custom development using OpenWrt<br>~Support various devices running standard Linux systems (such as Debian/CenOS/Armbian, etc.)<br>~Compatible with Padavan firmware (conservative mode), Pandora firmware<br>~Compatible with various types of devices customized and developed using the Linux kernel<br>——————————<br>~For more device support, please submit an issue or go to the TG group for feedback (the device name and the device core information returned by running uname -a must be provided)<br>

How to use:
--

~Confirm that the router device has enabled SSH and obtained root privileges (Linux devices with GUI desktops can be installed using their own terminal)<br>~Use SSH connection tools (such as putty, JuiceSSH, system built-in terminal, etc.) router or Linux device SSH management interface or terminal interface, and switch to the root user<br>~Confirm that the curl or wget download tool has been installed on the device. If not installed, please [refer to here](https://www.howtoforge.com/install-curl-in-linux) for LInux devices to install curl. For devices based on OpenWrt (Xiaomi official system, Pandora, Gaoke, etc.), please Use the following command to install curl:<br>

```Shell
opkg update && opkg install curl
```

~ Then execute the following installation commands on the SSH interface, and follow the subsequent prompts to complete the installation<br>

##### ~Use curl:<br>

```Shell
#by fastgit.org
export url='https://raw.fastgit.org/juewuy/ShellClash/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```

```shell
#by GitHub
export url='https://raw.githubusercontent.com/juewuy/ShellClash/master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```

```shell
#by jsDelivr-CDN
export url='https://fastly.jsdelivr.net/gh/juewuy/ShellClash@master' && sh -c "$(curl -kfsSl $url/install.sh)" && source /etc/profile &> /dev/null
```




##### ~Use wget：<br>

```Shell
#by GitHub
export url='https://raw.githubusercontent.com/juewuy/ShellClash/master' && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh  && sh /tmp/install.sh && source /etc/profile &> /dev/null
```

```shell
#By jsDelivrCDN
export url='https://fastly.jsdelivr.net/gh/juewuy/ShellClash@master' && wget -q --no-check-certificate -O /tmp/install.sh $url/install.sh  && sh /tmp/install.sh && source /etc/profile &> /dev/null
```

~**Use a low version of wget (prompt not to support https) local installation**:<br>

```Shell
#by shellclash.cf
export url='http://shellclash.cf/' && wget -q -O /tmp/install.sh $url/install.sh  && sh /tmp/install.sh && source /etc/profile &> /dev/null
```

~**After installation by non-root users**, please execute the following additional commands to read environment variables:<br>

```Shell
source ~/.bashrc &> /dev/null
```

~After installing the management script, execute the following command to **run the management script**<br>

```Shell
clash #normal mode
clash -h #help
clash -u #uninstall
clash -t #test mode
```

~**Install in Docker：**<br>

Use: https://github.com/echvoyager/shellclash_docker

~**Additional dependencies at runtime**：<br>

> Most of the equipment/systems are pre-installed with most of the following dependencies, you can ignore them if there is no impact when you use them.

```Text
bash/ash		necessary		Cannot install and run scripts when all are missing
curl/wget		necessary		When all are missing, it cannot be installed and updated online
iptables		important		Only use pure mode when missing
systemd/rc.common	general		Only use conservative mode when all are missing
iptables-mod-nat	general		Cannot use redir mode, mixed mode when missing
ip6tables-mod-nat	lower		Affects redir mode when missing, mixed mode support for ipv6
crontab			lower		Cannot enable timing task function when missing
net-tools		minimal		Cannot detect port occupancy normally when missing
ubus/iproute-doc	minimal		The host address of the machine cannot be obtained normally when missing
```



## Update log: 

### [Click to view](https://github.com/juewuy/ShellClash/releases) 

## Exchange feedback: 

### [TG Discussion Group](https://t.me/ShellClash)

## Related Q&A:

### [See blog for details](https://juewuy.github.io)

## Donate：

​		Alipay									WeChat

##### <img src="http://juewuy.github.io/post-images/1604390977172.png" style="zoom:50%;" /><img src="http://juewuy.github.io/post-images/1604391042406.png" style="zoom:50%;" />

机场推荐：
--
#### [Catnet](https://dash.catnet.uk/#/register?code=KOhfH9qD)<br>
#### [Dler](https://dler.best/auth/register?affid=89698)<br>

