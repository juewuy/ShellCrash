# ShellClash（原Clash for Miwifi）
在Shell环境下一键部署及管理[Clash](https://github.com/Dreamacro/clash)
=====

功能简介：
--
~通过管理脚本在Shell环境下便捷使用[Clash](https://github.com/Dreamacro/clash)<br>
~支持在Shell环境下管理[Clash各种功能](https://lancellc.gitbook.io/clash)<br>
~支持批量导入[Clash](https://github.com/Dreamacro/clash)支持的节点链接及订阅链接<br>~支持配置定时任务，以及定时更新订阅<br>~支持在线安装及使用网页面板管理规则组<br>
~支持局域网透明代理/纯净模式等多种模式切换<br>~支持在线更新管理脚本及升级Clash核心<br>

设备支持：
--

~支持小米/红米全系使用官方系统或官方开发版系统的路由器设备<br>
~支持各种基于OpenWrt或使用OpenWrt二次定制开发的路由器设备<br>
~支持各种运行标准Linux系统（如Debian/CenOS/Armbian等）的设备<br>~兼容Padavan固件（保守模式）、潘多拉固件<br>——————————
~暂不支持高恪、梅林等固件<br>
~更多设备支持，请提issue或前往TG群反馈（需提供设备名称及运行uname -a返回的设备核心信息）<br>

使用方式：
--
~确认路由器或设备已经开启SSH并获取root权限<br>
~使用SSH连接工具（如putty，JuiceSSH，系统自带终端等）路由器或设备的SSH管理界面，并切换到root用户<br>
~在SSH界面执行如下安装命令，并按照后续提示完成安装<br>

```Shell
#Release版本-github直连
sh -c "$(curl -kfsSl --resolve raw.githubusercontent.com:443:199.232.68.133 https://raw.githubusercontent.com/juewuy/ShellClash/master/install.sh)" && source /etc/profile &> /dev/null
#Release版本-jsdelivrCDN源
sh -c "$(curl -kfsSl https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master/install.sh)" && source /etc/profile &> /dev/null
#Test版本-github直连
sh -c "$(curl -kfsSl --resolve raw.githubusercontent.com:443:199.232.68.133 https://raw.githubusercontent.com/juewuy/ShellClash/master/install.sh)" -s 1 && source /etc/profile &> /dev/null
```

~安装完成管理脚本后，执行如下命令以运行管理脚本<br>

```Shell
clash
```

更新日志：
--
https://github.com/juewuy/ShellClash/releases

交流反馈：
--
### https://t.me/clashfm 

已知问题：
--
~Tun模式下clash服务可能会和路由器内置的网游加速器冲突，请谨慎同时使用<br>
~Redir模式暂不支持转发udp流量，外服游戏可能会受影响，外服游戏用户建议使用Tun模式<br>
~部分设备长时间使用会出现内存占用偏高——此为golang内存回收不及时导致，可以通过屏蔽p2p流量及设置每日定时重启核心以缓解<br>
~节点无法连接——在【clash功能设置】中打开【跳过本地证书验证】或者升级clash核心<br>

友情推广：
--
[顶级8K专线机场-墙洞](https://dler.best/auth/register?affid=89698)
