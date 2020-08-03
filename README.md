# clash-for-Miwifi
在小米AX3600/AX1800/AX5等路由器上使用clash做透明代理
=====
更新日志：
--

#### v0.7 
~新增一键安装脚本，具体功能内测中，请加群获取！<br>
~优化导入订阅流程<br>
~增加跳过本地证书验证<br>
~增加功能测试菜单<br>
~其他bug修复及使用优化<br>

#### v0.5
~新增订阅功能，功能强大，欢迎体验！<br>
~修改了配置记录的位置和格式，大幅度增加了脚本可用性<br>
~clash核心使用upx压缩，大幅度缩减了体积<br>
~更新到新版本clash核心，修复Tun模式电报无法正常代理的bug<br>
~新增若干小功能及使用优化<br>

#### v0.2
~合并Tun和Redir模式为一套文件，可以通过管理脚本直接切换<br>
~同步官方最新premium版核心，全面支持ssr<br>
~大幅度优化管理脚本，增加部分实用功能<br>

#### v0.1
~支持redir模式<br>
~增加了一个简单的管理脚本<br>
~支持ss、v2ray以及trojan协议，Redir模式额外支持ssr协议<br>
~支持Tun模式<br>

使用依赖：
--
~请确认路由器或设备已经开启SSH并获取root权限，小米AX系列可参考：https://www.right.com.cn/forum/thread-4032490-1-1.html 开启<br>
~SSH连接工具，例如putty，bitvise，JuiceSSH（支持安卓手机）等，请自行安装使用<br>
~SCP连接工具，如winscp（使用一键脚本则无需SCP工具）<br>
~以上都不了解或者看不懂的朋友暂不推荐使用<br>

使用方式：
--
~下载 [压缩包文件](https://github.com/juewuy/clash-for-Miwifi/raw/master/bin/clashfm.tar.gz)到本地电脑并解压<br>
~将解压后的5个文件通过winSCP上传到路由器/etc/clash文件夹（clash文件夹请自行创建）下（最终应该是/etc/clash/"5个文件"）<br>
~登陆SSH，并在SSH中用root用户执行下方的命令即可使用！<br>

**首次安装**
```Shell
mv /etc/clash/clashservice /etc/init.d/clash #移动clash服务文件
chmod  777 /etc/clash/clash                  #授予权限
chmod  777 /etc/init.d/clash                 #授予权限
sh /etc/clash/clash.sh                       #使用管理脚本
```
**管理脚本**
```Shell 
sh /etc/clash/clash.sh                       #使用管理脚本
```
~启用后可以通过 http://clash.razord.top （或者 https://yacd.haishan.me http://app.tossp.com ） （Host为网关IP，端口为9999，密钥为空）管理clash内置规则<br>

问题反馈：
--
### https://t.me/clashfm 

故障解决：
--
~部分设备安装时提示bin目录只读（readonly）：可以通过sh /etc/clash/clashsh 命令来运行管理脚本，或者加群获取一键安装脚本<br>
~如果能正常连接国内网站而无法访问屏蔽网站：请在浏览器中打开 http://clash.razord.top 并使用测速功能，之后手动指定服务器即可；如果所有服务器都不可用即代表配置文件有问题<br>

已知问题：
--
~由于使用了clash的fake-ip模式，故两种模式均不支持ipv6<br>
~Tun模式下clash服务可能会和小米路由器内置的tx网游加速器冲突，请谨慎同时使用<br>
~Redir模式无法转发udp流量，外服游戏可能会受影响，此功能是由官方系统阉割了Tproxy导致，暂时无解，外服游戏用户建议使用Tun模式<br>

ToDo：
--
~~管理脚本增加订阅功能~~<br>
~~添加一键安装脚本~~<br>
~增加屏蔽P2P流量功能<br>
~管理脚本增加更新功能<br>
~尝试更新openssl版本<br>
~修复redir-host DNS以及IPV6支持<br>
~……<br>


感谢：
--
~https://lancellc.gitbook.io/clash/start-clash/clash-tun-mode<br>
~https://comzyh.gitbook.io/clash/<br>
~https://h-cheung.gitlab.io/post/使用_clash_和路由表实现透明代理<br>
~https://www.right.com.cn/forum/thread-4042741-1-1.html<br>

