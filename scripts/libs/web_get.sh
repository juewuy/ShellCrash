. "$CRASHDIR"/libs/set_proxy.sh

webget(){	
	if pidof CrashCore >/dev/null; then
		setproxy #设置临时代理
		url=$(printf '%s\n' "$2" |
		sed -e 's#https://.*jsdelivr.net/gh/juewuy/ShellCrash[@|/]#https://raw.githubusercontent.com/juewuy/ShellCrash/#' \
			-e 's#https://gh.jwsc.eu.org/#https://raw.githubusercontent.com/juewuy/ShellCrash/#')
	else
		url=$(printf '%s\n' "$2" |
		sed 's#https://raw.githubusercontent.com/juewuy/ShellCrash/#https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@#')
	fi
	#参数【$1】代表下载目录，【$2】代表在线地址
	#参数【$3】代表输出显示，【$4】不启用重定向
	#参数【$5】代表验证证书，【$6】使用自定义UA
	[ -n "$6" ] && agent="--user-agent \"$6\""
	if wget --help 2>&1 | grep -q 'show-progress' >/dev/null 2>&1; then
		[ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
		[ "$4" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
		[ "$5" = "skipceroff" ] && certificate='' || certificate='--no-check-certificate'
		wget -Y on $agent $progress $redirect $certificate --timeout=3 -O "$1" "$url" && return 0 #成功则退出否则重试
		wget -Y off $agent $progress $redirect $certificate --timeout=5 -O "$1" "$2"
		return $?
	elif curl --version >/dev/null 2>&1; then
		[ "$3" = "echooff" ] && progress='-s' || progress='-#'
		[ "$4" = "rediroff" ] && redirect='' || redirect='-L'
		[ "$5" = "skipceroff" ] && certificate='' || certificate='-k'
		if curl --version | grep -q '^curl 8.' && ckcmd base64; then
			auth_b64=$(printf '%s' "$authentication" | base64)
			result=$(curl $agent -w '%{http_code}' --connect-timeout 3 --proxy-header "Proxy-Authorization: Basic $auth_b64" $progress $redirect $certificate -o "$1" "$url")
		else
			result=$(curl $agent -w '%{http_code}' --connect-timeout 3 $progress $redirect $certificate -o "$1" "$url")
		fi
		[ "$result" = "200" ] && return 0 #成功则退出否则重试
		export https_proxy=""
		export http_proxy=""
		result=$(curl $agent -w '%{http_code}' --connect-timeout 5 $progress $redirect $certificate -o "$1" "$2")
		[ "$result" = "200" ]
		return $?
	elif ckcmd wget;then
		[ "$3" = "echooff" ] && progress='-q'
		wget -Y on $progress -O "$1" "$url" && return 0 #成功则退出否则重试
		wget -Y off $progress -O "$1" "$2"
		return $?
	else
		echo "No Curl or Wget！！！"
		return 1
	fi
}