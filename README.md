# clash-for-Miwifi
在小米AX3600/AX1800/AX5等路由器上使用clash做透明代理
=====

功能简介：
--
~支持小米全系列路由器设备使用clash做透明代理，更多的设备支持可以前往TG群报名参与测试<br>
~支持SS、SSR、v2ray、trojan、sock5等协议<br>
~支持批量导入节点链接及订阅链接<br>
~支持使用网页面板管理规则组<br>
~支持多种模式切换，支持在线更新<br>
~支持部署内置的管理面板<br>
~更多功能可在使用中发掘<br>

使用依赖：
--
~路由器或设备已经开启SSH并获取root权限<br>
~SSH连接工具，例如putty，bitvise，JuiceSSH（支持安卓手机）等<br>

一键安装：
--
```Shell
sh -c "$(curl -kfsSl https://juewuy.xyz/clash/install.sh)" && source /etc/profile &> /dev/null
```

交流反馈：
--
### https://t.me/clashfm 

已知问题：
--
~Tun模式下clash服务可能会和小米路由器内置的tx网游加速器冲突，请谨慎同时使用<br>
~Redir模式无法转发udp流量，外服游戏可能会受影响，此功能是由官方系统阉割了Tproxy导致，暂时无解，外服游戏用户建议使用Tun模式<br>

ToDo：
--
~~增加订阅功能~~<br>
~~添加一键安装脚本~~<br>
~~增加屏蔽P2P流量功能~~<br>
~~增加更新功能~~<br>
~~修复redir-host DNS以及IPV6支持~~<br>
~~增加定时功能~~<br>
~~增加屏蔽局域网设备~~<br>
~~增加更多设备支持~~<br>

感谢：
--
~https://lancellc.gitbook.io/clash/start-clash/clash-tun-mode<br>
~https://comzyh.gitbook.io/clash/<br>
~https://h-cheung.gitlab.io/post/使用_clash_和路由表实现透明代理<br>
~https://www.right.com.cn/forum/thread-4042741-1-1.html<br>

请喝杯茶：
--
 ![](https://cdn.jsdelivr.net/gh/juewuy/clash-for-Miwifi/others/qrcodevx.png)
