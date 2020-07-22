# clash-for-Miwifi
在小米AX3600/AX1800/AX5等路由器上使用clash做透明代理
=====
PS：
--
•新增了redir模式，redir模式速度更快但是不支持UDP转发；tun模式支持UDP转发，但CPU和内存占用相对更高，请根据需求选择<br>
•支持ss,v2ray,trojan，但不支持ssr，也不支持订阅<br>
•需要自行编辑config.yaml以配置服务器<br>
•本内容中的透明代理方式可能适用于大部分同样采用openwrt内核的路由器或者软路由，有需求的可以自行斟酌使用<br>
•clash支持通过内置规则去广告，有需求的可以参考https://github.com/ACL4SSR/ACL4SSR 使用

使用依赖：
--
•请确认路由器或设备已经开启ssh并获取root权限，小米AX系列可参考：https://www.right.com.cn/forum/thread-4032490-1-1.html<br>
•SSH连接工具，例如putty，bitvise等，请自行安装使用<br>
•SCP连接工具，如winscp（内置了putty，只安装这一个其实就可以）<br>

使用方式：
--
•根据**个人需求**下载 [Tun模式](https://github.com/juewuy/clash_tun-for-Miwifi/tree/master/clash_tun_config)**或者** [Redir模式](https://github.com/juewuy/clash_tun-for-Miwifi/tree/master/clash_redir_config)中的全部4个文件到本地电脑 <br>
•**根据自己需求参考文件内的注释，修改config.yaml配置文件并保存`重要！！！`**<br>
•推荐使用notepad++打开yaml文件，如果只添加单个服务器可以直接在原示例上修改即可，多余的示例服务器不用删除<br>
*·如有必要，也可以自行前往下载更新clash核心文件并自行改名 https://github.com/Dreamacro/clash/releases/tag/premium （小米AX3600是armv8，ax1800/ax5是armv7，其他路由器请自查）<br>*
•将下载并修改后的4个文件通过winSCP上传到路由器/etc/clash文件夹（clash文件夹请自行创建）下（最终应该是/etc/clash/"4个文件"）<br>
•登陆SSH，并在SSH中用root用户执行下方的**对应命令**即可使用！<br>
```Shell
#首次启用clash
mv /etc/clash/clashservice /etc/init.d/clash #将clash服务文件移动到系统目录
chmod  777 /etc/clash/clash  #授予权限
chmod  777 /etc/init.d/clash #授予权限
sed -i "8iport=5335" /etc/dnsmasq.conf #修改dnsmasq监听端口为5335
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视）
service clash enable    #启用clash开机启动
service clash start     #启动clash服务
```
```Shell 
#停止clash透明网关-Tun模式
service clash disable   #禁用clash开机启动
service clash stop      #停止clash服务
sed -i '/port=5335/d' /etc/dnsmasq.conf #重置dnsmasq监听端口为默认值（port:53)
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视，不放心可重启系统）
```
```Shell 
#停止clash透明网关-Redir模式
service clash disable   #禁用clash开机启动
service clash stop      #停止clash服务
sed -i '/port=5335/d' /etc/dnsmasq.conf #重置dnsmasq监听端口为默认值（port:53)
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视，不放心可重启系统）
service firewall restart #重启防火墙以重置iptables规则
```
```Shell
#停止后再次启用clash透明网关
sed -i "8iport=5335" /etc/dnsmasq.conf #修改dnsmasq监听端口为5335
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视）
service clash enable    #启用clash开机启动
service clash start     #启动clash服务
```
```Shell  
#完全卸载clash相关文件
service clash disable   #禁用clash开机启动
service clash stop      #停止clash服务
sed -i '/port=5335/d' /etc/dnsmasq.conf #重置dnsmasq监听端口为默认值（port:53)
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视，不放心可重启系统）
rm -rf /etc/clash       #删除clash文件夹及文件
rm /etc/init.d/clash    #删除clash开机启动文件
```
•启用后可以通过 http://clash.razord.top （IP为网关IP，端口为9999）管理clash内置规则，通常无需额外设置即可正常使用，且设备重启后会保持自动运行<br>

故障解决：
--
•在浏览器或设备WiFi管理的高级选项中配置http代理（IP为路由器IP，端口7890），如果能连通外网则说明clash服务运行正常，不能连通则说明clash运行失败或者配置错误<br>
•如果能正常连接国内网站而无法访问屏蔽网站，请在浏览器中打开 http://clash.razord.top 并使用测速功能，之后手动指定服务器即可；如果所有服务器都不可用即代表配置文件有问题<br>
•如果能连通http代理但是无法使用透明代理，可能是tun网卡启用失败或者dnsmasq启动失败，重启设备通常可以解决，或重新执行安装命令<br>

已知问题：
--
•部分软件不会经过clash，例如telegram，可以通过设置软件内置sock5或http代理解决<br>
•部分系统版本较低（安卓6.0以下）的安卓设备可能无法正确通过dhcp服务获取dns地址，需要手动在WIFI中设置dns为路由器网关地址<br>
•由于使用了clash的fake-ip模式，暂不支持ipv6<br>
•tun模式下clash服务可能会和小米路由器内置的tx网游加速器冲突，请谨慎同时使用<br>
•全局模式代理无效，原因不明，同样的配置文件在pc端或者安卓上都可以使用全局模式，怀疑是clash核心的bug<br>
•小米路由内置的openwrt默认阉割了对tproxy的支持，所以使用redir模式做透明代理时无法转发udp流量<br>

感谢：
--
•https://lancellc.gitbook.io/clash/start-clash/clash-tun-mode<br>
•https://comzyh.gitbook.io/clash/<br>
•https://h-cheung.gitlab.io/post/使用_clash_和路由表实现透明代理/<br>

