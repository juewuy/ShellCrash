#!/bin/sh
# Copyright (C) Juewuy

#特殊固件识别及标记
[ -f "/etc/storage/started_script.sh" ] && { #老毛子固件
    systype=Padavan 
    initdir='/etc/storage/started_script.sh'
}
[ -d "/jffs" ] && { #华硕固件
    systype=asusrouter
    [ -f "/jffs/.asusrouter" ] && initdir='/jffs/.asusrouter'
    [ -d "/jffs/scripts" ] && initdir='/jffs/scripts/nat-start'
    #华硕启用jffs
    nvram set jffs2_scripts="1"
    nvram commit
}
[ -f "/data/etc/crontabs/root" ] && systype=mi_snapshot #小米设备
[ -w "/var/mnt/cfg/firewall" ] && systype=ng_snapshot   #NETGEAR设备
#容器内环境
grep -qE '/(docker|lxc|kubepods|crio|containerd)/' /proc/1/cgroup || [ -f /run/.containerenv ] || [ -f /.dockerenv ] && systype='container'
#检查环境变量
[ "$systype" = 'container' ] && CRASHDIR='/etc/ShellCrash'
[ -z "$CRASHDIR" ] && [ -n "$clashdir" ] && CRASHDIR="$clashdir"
[ -z "$CRASHDIR" ] && [ -d /tmp/SC_tmp ] && . /tmp/SC_tmp/menus/set_crashdir.sh && set_crashdir
#移动文件
mkdir -p "$CRASHDIR"
rm -rf /tmp/SC_tmp/menus/set_crashdir.sh
mv -f /tmp/SC_tmp/* "$CRASHDIR" 2>/dev/null
##############################
#注意目录变更
CFG_PATH="$CRASHDIR"/configs/ShellCrash.cfg
. "$CRASHDIR"/libs/set_config.sh
. "$CRASHDIR"/libs/set_profile.sh
#初始化
mkdir -p "$CRASHDIR"/configs
[ -f "$CFG_PATH" ] || echo '#ShellCrash配置文件，不明勿动！' >"$CFG_PATH"
#判断系统类型写入不同的启动文件
[ -w /usr/lib/systemd/system ] && sysdir=/usr/lib/systemd/system
[ -w /etc/systemd/system ] && sysdir=/etc/systemd/system
if [ -f /etc/rc.common -a "$(cat /proc/1/comm)" = "procd" ]; then
    #设为init.d方式启动
    cp -f "$CRASHDIR"/starts/shellcrash.procd /etc/init.d/shellcrash
    chmod 755 /etc/init.d/shellcrash
elif [ -n "$sysdir" -a "$USER" = "root" -a "$(cat /proc/1/comm)" = "systemd" ]; then
    #创建shellcrash用户
    userdel shellcrash 2>/dev/null
    sed -i '/0:7890/d' /etc/passwd
    sed -i '/x:7890/d' /etc/group
    if useradd -h >/dev/null 2>&1; then
        useradd shellcrash -u 7890 2>/dev/null
        sed -Ei s/7890:7890/0:7890/g /etc/passwd
    else
        echo "shellcrash:x:0:7890::/home/shellcrash:/bin/sh" >>/etc/passwd
    fi
    #配置systemd
    mv -f "$CRASHDIR"/starts/shellcrash.service "$sysdir"/shellcrash.service 2>/dev/null
    sed -i "s%/etc/ShellCrash%$CRASHDIR%g" "$sysdir"/shellcrash.service
    systemctl daemon-reload
	rm -rf "$CRASHDIR"/starts/shellcrash.procd
elif rc-status -r >/dev/null 2>&1; then
    #设为openrc方式启动
    mv -f "$CRASHDIR"/starts/shellcrash.openrc /etc/init.d/shellcrash
    chmod 755 /etc/init.d/shellcrash
    rm -rf "$CRASHDIR"/starts/shellcrash.procd
else
    #设为保守模式启动
    setconfig start_old 已开启
	rm -rf "$CRASHDIR"/starts/shellcrash.procd
fi
rm -rf "$CRASHDIR"/starts/shellcrash.service
rm -rf "$CRASHDIR"/starts/shellcrash.openrc

#修饰文件及版本号
command -v bash >/dev/null 2>&1 && shtype=bash
[ -x /bin/ash ] && shtype=ash
#批量授权
for file in start.sh starts/bfstart.sh starts/afstart.sh starts/fw_stop.sh menu.sh menus/task_cmd.sh menus/bot_tg.sh; do
    sed -i "s|/bin/sh|/bin/$shtype|" "$CRASHDIR/$file" 2>/dev/null
    chmod +x "$CRASHDIR/$file" 2>/dev/null
done
setconfig versionsh_l $version
#生成用于执行启动服务的变量文件
[ ! -f "$CRASHDIR"/configs/command.env ] && {
    TMPDIR='/tmp/ShellCrash'
    BINDIR="$CRASHDIR"
    touch "$CRASHDIR"/configs/command.env
    setconfig TMPDIR "$TMPDIR" "$CRASHDIR"/configs/command.env
    setconfig BINDIR "$BINDIR" "$CRASHDIR"/configs/command.env
}
if [ -n "$(grep 'crashcore=singbox' "$CFG_PATH")" ]; then
    COMMAND='"$TMPDIR/CrashCore run -D $BINDIR -C $TMPDIR/jsons"'
else
    COMMAND='"$TMPDIR/CrashCore -d $BINDIR -f $TMPDIR/config.yaml"'
fi
setconfig COMMAND "$COMMAND" "$CRASHDIR"/configs/command.env
#设置防火墙执行模式
grep -q 'firewall_mod' "$CRASHDIR/configs/ShellClash.cfg" 2>/dev/null || {
    firewall_mod=iptables
    nft add table inet shellcrash 2>/dev/null && firewall_mod=nftables
    setconfig firewall_mod $firewall_mod
}
#设置更新地址
[ -n "$url" ] && setconfig update_url $url
#设置环境变量
[ -w /opt/etc/profile ] && [ "$systype" = "Padavan" ] && profile=/opt/etc/profile
[ -w /jffs/configs/profile.add ] && profile=/jffs/configs/profile.add
[ -z "$profile" ] && profile=/etc/profile
if [ -n "$profile" ]; then
    set_profile "$profile"
    #适配zsh环境变量
    zsh --version >/dev/null 2>&1 && [ -z "$(cat $HOME/.zshrc 2>/dev/null | grep CRASHDIR)" ] && set_profile "$HOME/.zshrc"
    setconfig my_alias "$my_alias"
else
    echo -e "\033[33m无法写入环境变量！请检查安装权限！\033[0m"
    exit 1
fi
#梅林/Padavan额外设置
[ -n "$initdir" ] && {
	touch "$initdir"
    sed -i '/ShellCrash初始化/'d "$initdir"
    echo "$CRASHDIR/starts/general_init.sh & #ShellCrash初始化脚本" >>"$initdir"
	chmod 755 "$CRASHDIR"/starts/general_init.sh
    chmod a+rx "$initdir" 2>/dev/null
    setconfig initdir "$initdir"
}
#Padavan额外设置
[ -f "/etc/storage/started_script.sh" ] && mount -t tmpfs -o remount,rw,size=45M tmpfs /tmp #增加/tmp空间以适配新的内核压缩方式
#镜像化OpenWrt(snapshot)额外设置
if [ "$systype" = "mi_snapshot" -o "$systype" = "ng_snapshot" ]; then
    chmod 755 "$CRASHDIR"/starts/snapshot_init.sh
	if [ "$systype" = "mi_snapshot" ];then
		path="/data/shellcrash_init.sh"
		setconfig CRASHDIR "$CRASHDIR" "$CRASHDIR"/starts/snapshot_init.sh
		mv -f "$CRASHDIR"/starts/snapshot_init.sh "$path"
		[ ! -f /data/auto_start.sh ] && echo '#用于自定义需要开机启动的功能或者命令，会在开机后自动运行' > /data/auto_start.sh
	else
		path="$CRASHDIR"/starts/snapshot_init.sh
	fi
    uci delete firewall.auto_ssh 2>/dev/null
    uci delete firewall.ShellCrash 2>/dev/null
    uci set firewall.ShellCrash=include
    uci set firewall.ShellCrash.type='script'
    uci set firewall.ShellCrash.path="$path"
    uci set firewall.ShellCrash.enabled='1'
    uci commit firewall
else
    rm -rf "$CRASHDIR"/starts/snapshot_init.sh
fi
#华硕USB启动额外设置
[ "$usb_status" = "1" ] && {
    echo "$CRASHDIR/start.sh init & #ShellCrash初始化脚本" >"$CRASHDIR"/asus_usb_mount.sh
    nvram set script_usbmount="$CRASHDIR/asus_usb_mount.sh"
    nvram commit
}
#华硕下载大师启动额外设置
[ -f "$dir/asusware.arm/etc/init.d/S50downloadmaster" ] && [ -z "$(grep 'ShellCrash' $dir/asusware.arm/etc/init.d/S50downloadmaster)" ] &&
    sed -i "/^PATH=/a\\$CRASHDIR/start.sh init & #ShellCrash初始化脚本" "$dir/asusware.arm/etc/init.d/S50downloadmaster"
#容器环境额外设置
[ "$systype" = 'container' ] && {
	setconfig userguide '1'
	setconfig crashcore 'meta'
	setconfig dns_mod 'mix'
	setconfig firewall_area '1'
	setconfig firewall_mod 'nftables'
	setconfig release_type 'master'
	setconfig start_old 'OFF'
	echo "$CRASHDIR/menu.sh" >> /etc/profile
	cat > /usr/bin/crash <<'EOF'
#!/bin/sh
CRASHDIR=${CRASHDIR:-/etc/ShellCrash}
export CRASHDIR
exec "$CRASHDIR/menu.sh" "$@"
EOF
    chmod 755 /usr/bin/crash	
}
setconfig systype $systype
#删除临时文件
rm -rf /tmp/*rash*gz
rm -rf /tmp/SC_tmp
#转换&清理旧版本文件
mkdir -p "$CRASHDIR"/yamls
mkdir -p "$CRASHDIR"/jsons
mkdir -p "$CRASHDIR"/tools
mkdir -p "$CRASHDIR"/task
mkdir -p "$CRASHDIR"/ruleset
for file in config.yaml.bak user.yaml proxies.yaml proxy-groups.yaml rules.yaml others.yaml; do
    mv -f "$CRASHDIR"/"$file" "$CRASHDIR"/yamls/"$file" 2>/dev/null
done
[ ! -L "$CRASHDIR"/config.yaml ] && mv -f "$CRASHDIR"/config.yaml "$CRASHDIR"/yamls/config.yaml 2>/dev/null
for file in fake_ip_filter mac web_save servers.list fake_ip_filter.list fallback_filter.list singbox_providers.list clash_providers.list; do
    mv -f "$CRASHDIR"/"$file" "$CRASHDIR"/configs/"$file" 2>/dev/null
done
#配置文件改名
mv -f "$CRASHDIR"/configs/ShellClash.cfg "$CFG_PATH" 2>/dev/null
#数据库改名
mv -f "$CRASHDIR"/geosite.dat "$CRASHDIR"/GeoSite.dat 2>/dev/null
mv -f "$CRASHDIR"/ruleset/geosite-cn.srs "$CRASHDIR"/ruleset/cn.srs 2>/dev/null
mv -f "$CRASHDIR"/ruleset/geosite-cn.mrs "$CRASHDIR"/ruleset/cn.mrs 2>/dev/null
#数据库移动
mv -f "$CRASHDIR"/*.srs "$CRASHDIR"/ruleset/ 2>/dev/null
mv -f "$CRASHDIR"/*.mrs "$CRASHDIR"/ruleset/ 2>/dev/null
for file in dropbear_rsa_host_key authorized_keys tun.ko ShellDDNS.sh; do
    mv -f "$CRASHDIR"/"$file" "$CRASHDIR"/tools/"$file" 2>/dev/null
done
for file in cron task.list; do
    mv -f "$CRASHDIR"/"$file" "$CRASHDIR"/task/"$file" 2>/dev/null
done
mv -f "$CRASHDIR"/menus/task_cmd.sh "$CRASHDIR"/task/task.sh 2>/dev/null
#旧版文件清理
userdel shellclash >/dev/null 2>&1
sed -i '/shellclash/d' /etc/passwd
sed -i '/shellclash/d' /etc/group
rm -rf /etc/init.d/clash
rm -rf "$CRASHDIR"/rules
[ "$systype" = "mi_snapshot" -a "$CRASHDIR" != '/data/clash' ] && rm -rf /data/clash
for file in webget.sh misnap_init.sh core.new; do
    rm -f "$CRASHDIR/$file"
done
#旧版变量改名
sed -i "s/clashcore/crashcore/g" "$CFG_PATH"
sed -i "s/clash_v/core_v/g" "$CFG_PATH"
sed -i "s/clash.meta/meta/g" "$CFG_PATH"
sed -i "s/ShellClash/ShellCrash/g" "$CFG_PATH"
sed -i "s/cpucore=armv8/cpucore=arm64/g" "$CFG_PATH"
sed -i "s/redir_mod=Nft基础/redir_mod=Redir模式/g" "$CFG_PATH"
sed -i "s/redir_mod=Nft混合/redir_mod=Tproxy模式/g" "$CFG_PATH"
sed -i "s/redir_mod=Tproxy混合/redir_mod=Tproxy模式/g" "$CFG_PATH"
sed -i "s/redir_mod=纯净模式/firewall_area=4/g" "$CFG_PATH"
#变量统一使用ON/OFF
sed -i 's/=\(已启用\|已开启\)$/=ON/'  "$CFG_PATH"
sed -i 's/=\(未启用\|未开启\)$/=OFF/' "$CFG_PATH"

echo -e "\033[32m脚本初始化完成,请输入\033[30;47m $my_alias \033[0;33m命令开始使用！\033[0m"
