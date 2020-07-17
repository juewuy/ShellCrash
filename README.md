# clash_tun-for-Miwifi
在小米AX3600/AX1800/AX5等路由器上使用clash_tun模式做透明代理
=====
PS：
--
•支持ss,v2ray,trojan，但不支持ssr，也不支持订阅<br>
•需要自行编辑config.yaml以配置服务器<br>
•小米路由内置的openwrt默认阉割了对tproxy的支持，所以使用redir模式做透明代理时无法转发udp流量，只能采用tun模式转发udp流量<br>
•tun模式对udp的转发支持好，且延迟低可以用于游戏加速，但是对CPU占用较高<br>
•clash对tun模式的官方文档内容不是很完善，折腾了好几天也没搞懂怎么使用真实ip模式进行透明代理，故只能采用配置相对简单的fake-ip模式<br>
•fake-ip模式在数据向dns查询时默认会返回例如198.18.0.x这样的虚拟ip地址，故部分必须验证真实ip地址的网站或app可能会受影响<br>
•系统默认的dnsmasq会强行劫持所有53端口流量，所以必须修改dnsmasq的默认端口以让流量经过clash内置的dns服务以使用fake-ip模式<br>
•fake-ip+tun模式的透明代理方式可能适用于大部分同样采用openwrt内核的路由器或者软路由，有需求的可以自行斟酌使用<br>
•理论上clash可以通过内置规则去广告，这里提供的规则没有包括，有需求的可以参考https://github.com/ACL4SSR/ACL4SSR 使用

使用依赖：
--
•请确认路由器或设备已经开启ssh并获取root权限，小米AX系列可参考：https://www.right.com.cn/forum/thread-4032490-1-1.html<br>
•SSH连接工具，例如putty，bitvise等，请自行安装使用<br>
•SCP连接工具，如winscp（内置了putty，只安装这一个其实就可以）<br>

使用方式：
--
•下载 [clash_tun.zip](https://github.com/juewuy/clash_tun-for-Miwifi/raw/master/clash_tun.zip) 并解压<br>
•**根据自己需求参考文件内的注释，修改config.yaml配置文件并保存`重要！！！`**<br>
•推荐使用notepad++打开yaml文件，如果只添加单个服务器可以直接在原示例上修改即可，多余的示例服务器不用删除<br>
*·如有必要，也可以自行前往下载更新clash核心文件 https://github.com/Dreamacro/clash/releases/tag/premium （小米AX3600是armv8，ax1800/ax5是armv7，其他路由器请自查）<br>*
•将clash文件夹以及内部4个文件通过winSCP上传到路由器/etc文件夹下（最终应该是/etc/clash/"4个文件"）<br>
•登陆SSH，并在SSH中用root用户执行下方的相应命令即可！（理论上非root用户也可以运行，请参考官方文档自行研究）<br>
•启用后可以通过 http://clash.razord.top 管理clash内置规则，通常无需额外设置即可正常使用，且设备重启后会保持自动运行<br>
*•也可以自行配置http代理（端口7890）或者sock5代理（端口7891）（速度比tun模式更快但是相对延迟可能略高）<br>*
```Shell
#首次启用clash
mv /etc/clash/clashservice /etc/init.d/clash #将clash服务文件移动到系统目录
chmod  777 /etc/clash/clash  #授予权限
chmod  777 /etc/init.d/clash #授予权限
service clash enable    #启用clash开机启动
service clash start     #启动clash服务
sed -i "8iport=5335" /etc/dnsmasq.conf #修改dnsmasq监听端口为5335
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视）
```
```Shell 
#停止clash透明网关
service clash disable   #禁用clash开机启动
service clash stop      #停止clash服务
sed -i '/port=5335/d' /etc/dnsmasq.conf #重置dnsmasq监听端口为默认值（port:53)
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视，不放心可重启系统）
```
```Shell
#停止后再次启用clash透明网关
service clash enable    #启用clash开机启动
service clash start     #启动clash服务
sed -i "8iport=5335" /etc/dnsmasq.conf #修改dnsmasq监听端口为5335
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视）
```
```Shell  
#卸载clash相关文件（执行前必须先输入“停止clash透明网关”相关命令，否则可能导致上不了网）
rm -rf /etc/clash       #删除clash文件夹及文件
rm /etc/init.d/clash    #删除clash开机启动文件
```

已知问题：
--
•部分软件不会经过clash，例如telegram，可以通过设置软件内置sock5或http代理解决<br>
•tun模式的CPU耗用较高，速度不是很理想，而且会影响全局流量（所有tcp和udp流量都会经过tun虚拟网卡和clash），ax1800实测带宽在60M左右。不过p2p流量通常不会进入tun，故P2Peye.com下载速度不受影响<br>
•由于使用了clash的fake-ip模式，暂不支持ipv6，且部分v4网站可能会出现验证错误，待确认<br>
•由于同样使用了tun模式虚拟网卡，clash服务可能会和小米路由器内置的tx网游加速器冲突，请谨慎同时使用<br>
•不支持订阅，由于clash本身不支持对v2ray，ss，trojan等协议的订阅，所以订阅只能通过更新clash的配置文件config.yaml来进行，有条件的可以自行写更新脚本<br>
•全局模式代理无效，原因不明，同样的配置文件在pc端或者安卓上都可以使用全局模式，怀疑是clash核心的bug

参考：
--
•https://lancellc.gitbook.io/clash/start-clash/clash-tun-mode<br>
•https://comzyh.gitbook.io/clash/<br>
•https://h-cheung.gitlab.io/post/使用_clash_和路由表实现透明代理/<br>

