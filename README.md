# clash_tun-for-Miwifi
在小米AX3600/AX1800/AX5等路由器上使用clash_tun模式做透明代理
=====
PS：
--
小米路由内置的openwrt默认阉割了对tproxy的支持，所以使用redir模式做透明代理时无法转发udp流量，只能采用tun模式转发udp流量<br>
tun模式对udp的转发支持非常好，而且延迟非常低，小米官方内置的tx网游加速器其实就是使用的tun模式<br>
支持ss,v2ray,trojan，但不支持ssr，也不支持订阅<br>
clash对tun模式的官方文档内容不是很完善，折腾了好几天也没搞懂怎么使用真实ip模式进行透明代理，故只能采用较为简单但速度更快的fake-ip模式<br>
fake-ip模式在数据向dns查询时默认会返回例如198.18.0.x这样的虚拟ip地址，故部分必须验证真实ip地址的网站或app可能会受影响<br>
系统默认的dnsmasq非常霸道，会强行劫持所有53端口流量，所以必须修改dnsmasq的默认端口以让流量经过clash内置dns服务<br>
fake-ip+tun模式的透明代理方式可能适用于大部分采用openwrt内核的路由器或者软路由，有需求的可以自行斟酌使用<br>

使用方式：
--
下载clash.zip，并解压<br>
根据自己需求参考备注修改config.yaml配置文件`重要！！！`<br>
也可以自行下载或更新clash-tun模式核心文件并重命名 https://github.com/Dreamacro/clash/releases/tag/premium （小米AX系列都是armv7架构，其他路由器请自查）<br>
将clash文件夹以及内部4个文件通过winSCP上传到路由器/etc文件夹下<br>
在ssh中用root用户执行下列相应命令即可！<br>

启用后可以通过 http://clash.razord.top 管理clash内置规则<br>
默认http代理接口7890，sock5接口7891<br>
启动后无需其他设置即可连接代理服务器<br>
```sh
#首次启用clash
mv /etc/clash/clashservice /etc/init.d/clash #将clash服务文件移动到系统目录
chmod  777 /etc/clash/clash  #授予权限
chmod  777 /etc/init.d/clash #授予权限
service clash enable    #启用clash开机启动
service clash start     #启动clash服务
sed -i "8iport=5335" /etc/dnsmasq.conf #修改dnsmasq监听端口为5335
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视）
```
```sh
#启用clash透明网关
service clash enable    #启用clash开机启动
service clash start     #启动clash服务
sed -i 's|port=53|port=5335|' /etc/dnsmasq.conf #修改dnsmasq监听端口
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视）
```
```sh
#停止clash透明网关
service clash disable   #禁用clash开机启动
service clash stop      #停止clash服务
sed -i '/port=5335/d' /etc/dnsmasq.conf #重置dnsmasq监听端口为默认值（port:53)
service dnsmasq restart #重启dnsmasq服务（报错“cp: can't stat '/etc/dnsmasq.d/*'……”可无视，不放心可重启系统）
```
```sh
#卸载clash相关文件（卸载前请先配合“停止clash透明网关”使用）
rm -rf /etc/clash       #删除clash文件夹及文件
rm /etc/init.d/clash    #删除clash开机启动文件
```

已知问题：
--
a，部分软件不会经过clash，例如telegram，可以通过设置软件内置sock5或http代理解决<br>
b，tun模式的CPU耗用较高，速度不是很理想，而且会影响全局流量（所有tcp和udp流量都会经过tun虚拟网卡和clash），ax1800实测带宽在60M左右，不过p2p流量通常不会进入tun，故速度不受影响<br>
c，使用了clash的fake-ip模式，部分网站可能会出现验证错误，待确认<br>
d，由于变相禁用的dnsmasq的dns解析服务，miwifi.com或www.miwifi.com 无法打开路由器管理界面，只能使用192.168.31.1进入（app不受影响）<br>
e，可能会和小米路由器内置的网游加速器冲突，请谨慎同时使用<br>
f，不支持订阅，由于clash本身不支持对v2ray，ss，trojan等协议的订阅，所以订阅只能通过更新config.yaml来进行，有条件的可以自行写脚本<br>
g，不支持ssr，clash官方不支持ssr，而支持ssr的clashr又不支持tun，so……<br>

