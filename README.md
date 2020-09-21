# ShellClash（原Clash for Miwifi）
在Shell环境下一键部署及管理[Clash](https://github.com/Dreamacro/clash)
=====

功能简介：
--
~通过管理脚本在shell环境下便捷使用[Clash](https://github.com/Dreamacro/clash)<br>
~支持在Shell环境下管理[Clash各种功能](https://lancellc.gitbook.io/clash)<br>
~支持批量导入SS/SSR/v2ray/trojan等节点链接及订阅链接<br>~支持配置定时任务，以及定时更新订阅<br>~支持使用以及安装网页面板管理规则组<br>
~支持局域网透明代理/纯净模式等多种模式切换<br>~支持在线更新管理脚本及升级Clash核心<br>

设备支持：
--

~支持小米/红米全系使用官方系统或官方开发版系统的路由器设备（Ac2100系列除外）<br>
~支持各种基于OpenWrt或使用OpenWrt二次定制开发的路由器设备<br>
~支持各种运行标准Linux系统（如Debian/CenOS/Armbian等）的设备<br>
~更多设备，请提issue或前往TG群反馈（需提供设备名称及运行uname -a返回的设备核心信息）<br>

使用方式：
--
~确认路由器或设备已经开启SSH并获取root权限<br>
~使用SSH连接工具（如putty，JuiceSSH，系统自带终端等）路由器或设备的SSH管理界面，并切换到root用户<br>
~在SSH界面执行如下安装命令，并按照后续提示完成安装<br>

```Shell
sh -c "$(curl -kfsSl --resolve raw.githubusercontent.com:443:199.232.68.133 https://raw.githubusercontent.com/juewuy/ShellClash/master/install.sh)" && source /etc/profile &> /dev/null
```
或者
```Shell
sh -c "$(curl -kfsSl https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master/install_cdn.sh)" && source /etc/profile &> /dev/null
```
Debian/CenOS/Armbian等Linux系统如果默认使用dash，请使用

```sh
bash -c "$(curl -kfsSl https://cdn.jsdelivr.net/gh/juewuy/ShellClash@master/install_cdn.sh)" && source /etc/profile &> /dev/null
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
https://dler.best/auth/register?affid=89698
