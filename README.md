# clash-for-Miwifi
在小米AX3600/AX1800/AX5等路由器上使用clash做透明代理
=====
更新日志：
--
v0.2
-
•合并Tun和Redir模式为一套文件，可以通过管理脚本直接切换<br>
•同步官方最新premium版核心，全面支持ssr<br>
•优化脚本可用性，增加了部分实用功能<br>

v0.1
-
•之前版本安装的用户可以将clashservice和clashsh两个文件上传到etc/clash下后重新执行安装命令即可使用脚本<br>
•增加redir模式，redir模式速度更快但是不支持UDP转发；tun模式支持UDP转发，但CPU和内存占用相对更高，请根据需求选择<br>
•支持ss,v2ray,trojan，Redir模式有限支持ssr，不支持订阅<br>
•需要自行编辑config.yaml以配置服务器<br>
•可以使用 https://acl4ssr.netlify.app 导入订阅以及去广告规则<br>

使用依赖：
--
•请确认路由器或设备已经开启SSH并获取root权限，小米AX系列可参考：https://www.right.com.cn/forum/thread-4032490-1-1.html 开启<br>
•SSH连接工具，例如putty，bitvise，JuiceSSH（支持安卓手机）等，请自行安装使用<br>
•SCP连接工具，如winscp（内置了putty，只安装这一个其实就可以）<br>

使用方式：
--
•下载 [目录中全部5个文件](https://github.com/juewuy/clash-for-Miwifi/tree/master/clash)到本地电脑 <br>
•**根据自己需求参考文件内的注释，修改config.yaml配置文件并保存`重要！！！`**<br>
•推荐使用notepad++打开yaml文件，如果只添加单个服务器可以直接在原示例上修改即可，多余的示例服务器不用删除<br>
•可以使用 https://clash.skk.moe/proxy 生成单个节点配置；使用 https://acl4ssr.netlify.app 生成订阅或链接的节点配置<br>
*·如有必要，也可以自行前往下载更新clash核心文件并自行改名<br>*
•将下载并修改后的5个文件通过winSCP上传到路由器/etc/clash文件夹（clash文件夹请自行创建）下（最终应该是/etc/clash/"5个文件"）<br>
•登陆SSH，并在SSH中用root用户执行下方的**对应命令**即可使用！<br>

**首次安装**
```Shell
mv /etc/clash/clashservice /etc/init.d/clash #移动clash服务文件
mv /etc/clash/clashsh /bin/clash             #移动clash管理脚本
chmod  777 /etc/clash/clash                  #授予权限
chmod  777 /etc/init.d/clash                 #授予权限
chmod  777 /bin/clash                        #授予权限
clash                                        #使用管理脚本
```
**管理脚本**
```Shell 
clash                                        #使用管理脚本
```
•启用后可以通过 http://clash.razord.top （或者 https://yacd.haishan.me ） （Host为网关IP，端口为9999，密钥为空）管理clash内置规则<br>

故障解决：
--
•部分设备安装时提示bin目录只读（readonly），可以通过输入：chmod  755 /bin 来使bin目录可写，之后重新执行安装命令即可完成安装,/etc/init.d目录同理<br>
•如果 http://clash.razord.top 打不开，请尝试使用 https://clash.razord.top https://yacd.haishan.me http://yacd.haishan.me 或者尝试清理浏览器缓存<br>
•如果能正常连接国内网站而无法访问屏蔽网站，请在浏览器中打开 http://clash.razord.top 并使用测速功能，之后手动指定服务器即可；如果所有服务器都不可用即代表配置文件有问题<br>
•如果能连通http代理（可在浏览器中设置http代理，端口为7890）但是无法使用透明代理，可能是tun网卡启用失败或者dnsmasq启动失败，重启设备通常可以解决<br>
•或者加入tg群询问 https://t.me/joinchat/Q6m08xhJ9iZ6yC__cxmPjw <br>

已知问题：
--
•由于使用了clash的fake-ip模式，故不支持ipv6<br>
•Tun模式下clash服务可能会和小米路由器内置的tx网游加速器冲突，请谨慎同时使用<br>
•Tun模式下部分软件不会经过clash，例如telegram，可以通过设置软件内置sock5（IP=路由IP，port=7891）或http代理（IP=路由IP，port=7890）解决<br>
•Redir模式无法转发udp流量，外服游戏可能会受影响，此功能是由官方系统阉割了Tproxy导致<br>
•全局模式代理无效，同样的配置文件在pc端或者安卓上都可以使用全局模式，疑是clash核心的bug<br>

感谢：
--
•https://lancellc.gitbook.io/clash/start-clash/clash-tun-mode<br>
•https://comzyh.gitbook.io/clash/<br>
•https://h-cheung.gitlab.io/post/使用_clash_和路由表实现透明代理<br>
•https://www.right.com.cn/forum/thread-4042741-1-1.html<br>

