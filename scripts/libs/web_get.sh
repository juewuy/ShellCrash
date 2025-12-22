. "$CRASHDIR"/libs/set_proxy.sh

webget(){	
	if pidof CrashCore >/dev/null; then
		setproxy #设置临时代理
		url=$(printf '%s\n' "$3" |
		sed -e 's#https://.*jsdelivr.net/gh/juewuy/ShellCrash[@|/]#https://raw.githubusercontent.com/juewuy/ShellCrash/#' \
			-e 's#https://gh.jwsc.eu.org/#https://raw.githubusercontent.com/juewuy/ShellCrash/#')
	else
		url=$(printf '%s\n' "$3" |
		sed 's#https://raw.githubusercontent.com/juewuy/ShellCrash/#https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@#')
	fi
	#参数【$2】代表下载目录，【$3】代表在线地址
	#参数【$4】代表输出显示，【$5】不启用重定向
	#参数【$6】代表验证证书，【$7】使用自定义UA
	[ -n "$7" ] && agent="--user-agent \"$7\""
	if wget --help 2>&1 | grep -q 'show-progress' >/dev/null 2>&1; then
		[ "$4" = "echooff" ] && progress='-q' || progress='-q --show-progress'
		[ "$5" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
		[ "$6" = "skipceroff" ] && certificate='' || certificate='--no-check-certificate'
		wget -Y on $agent $progress $redirect $certificate --timeout=3 -O "$2" "$url" && return 0 #成功则退出否则重试
		wget -Y off $agent $progress $redirect $certificate --timeout=5 -O "$2" "$3"
		return $?
	elif curl --version >/dev/null 2>&1; then
		[ "$4" = "echooff" ] && progress='-s' || progress='-#'
		[ "$5" = "rediroff" ] && redirect='' || redirect='-L'
		[ "$6" = "skipceroff" ] && certificate='' || certificate='-k'
		if curl --version | grep -q '^curl 8.' && ckcmd base64; then
			auth_b64=$(printf '%s' "$authentication" | base64)
			result=$(curl $agent -w '%{http_code}' --connect-timeout 3 --proxy-header "Proxy-Authorization: Basic $auth_b64" $progress $redirect $certificate -o "$2" "$url")
		else
			result=$(curl $agent -w '%{http_code}' --connect-timeout 3 $progress $redirect $certificate -o "$2" "$url")
		fi
		[ "$result" = "200" ] && return 0 #成功则退出否则重试
		export all_proxy=""
		result=$(curl $agent -w '%{http_code}' --connect-timeout 5 $progress $redirect $certificate -o "$2" "$3")
		[ "$result" = "200" ]
		return $?
	elif ckcmd wget;then
		[ "$4" = "echooff" ] && progress='-q'
		wget -Y on $progress -O "$2" "$url" && return 0 #成功则退出否则重试
		wget -Y off $progress -O "$2" "$3"
		return $?
	else
		echo "找不到可用下载工具！！！请安装Curl或Wget！！！"
		return 1
	fi
}