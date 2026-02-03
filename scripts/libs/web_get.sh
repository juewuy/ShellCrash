. "$CRASHDIR"/libs/set_proxy.sh

webget(){	
	if pidof CrashCore >/dev/null; then
		setproxy #设置临时代理，【$1】代表下载目录，【$2】代表在线地址
		url=$(printf '%s\n' "$2" |
		sed -e 's#https://.*jsdelivr.net/gh/juewuy/ShellCrash[@|/]#https://raw.githubusercontent.com/juewuy/ShellCrash/#' \
			-e 's#https://gh.jwsc.eu.org/#https://raw.githubusercontent.com/juewuy/ShellCrash/#')
	else
		url=$(printf '%s\n' "$2" |
		sed 's#https://raw.githubusercontent.com/juewuy/ShellCrash/#https://testingcf.jsdelivr.net/gh/juewuy/ShellCrash@#')
	fi

	# === 新增模块 1：大小探测 (仅显示用) ===
	fsize_raw=0
	if [ "$3" != "echooff" ]; then
		# 探测头信息
		header=$(curl -sIL --connect-timeout 2 "$url")
		# 代理容错
		[ -z "$header" ] && { export https_proxy=""; export http_proxy=""; header=$(curl -sIL --connect-timeout 2 "$url"); }
		
		# 提取大小 (优先 Content-Length，其次 ETag)
		fsize_raw=$(echo "$header" | grep -i 'Content-Length' | tail -n 1 | awk '{print $2}' | tr -d '\r' | awk '{print int($1)}')
		if [ -z "$fsize_raw" ] || [ "$fsize_raw" -eq 0 ]; then
			etag=$(echo "$header" | grep -i 'etag' | tail -n 1 | cut -d '"' -f2 | cut -d '-' -f1)
			[ -n "$etag" ] && fsize_raw=$(printf "%d" 0x$etag 2>/dev/null)
		fi
		# 显示文件大小
		[ -n "$fsize_raw" ] && [ "$fsize_raw" -gt 0 ] && echo "文件大小: $(awk -v n=$fsize_raw 'BEGIN {printf "%.2f", n/1048576}') MB"
	fi

	# === 新增模块 2：手搓进度条引擎 (函数定义) ===
	execute_curl(){
		local path="$1" target_url="$2" total_size="$3" extra_args="$4"
		rm -f /tmp/webget_res
		# 后台静默下载，状态码写入临时文件
		curl $extra_args -s -L -w '%{http_code}' "$target_url" -o "$path" > /tmp/webget_res &
		local pid=$!
		
		# 循环监控
		while kill -0 $pid 2>/dev/null; do
			if [ -f "$path" ]; then
				local curr=$(wc -c < "$path")
				local pct=$(awk -v c=$curr -v t=$total_size 'BEGIN {p=(c*100/t); if(p>100)p=100; printf "%.1f", p}')
				
				# 40字符安全宽度
				local bar_max=40
				local num=$(awk -v p=$pct -v w=$bar_max 'BEGIN {printf "%d", p*w/100}')
				local bar=$(printf "%${num}s" | tr ' ' '#'); local spc_n=$((bar_max - num))
				local spc=""; [ "$spc_n" -gt 0 ] && spc=$(printf "%${spc_n}s")
				
				# \033[2K 清除整行
				printf "\r\033[2K%s%s %6s%%" "$bar" "$spc" "$pct" >&2
			fi
			usleep 200000 2>/dev/null || sleep 1
		done
		
		local code=$(cat /tmp/webget_res 2>/dev/null)
		if [ "$code" = "200" ] || [ "$code" = "206" ]; then
			local full=$(printf "%40s" | tr ' ' '#')
			printf "\r\033[2K%s 100.0%%\n" "$full" >&2
		else
			printf "\r\033[2K" >&2; [ -f "$path" ] && rm -f "$path"
		fi
		echo "$code"
	}
	# ===============================================

	#参数【$1】代表下载目录，【$2】代表在线地址
	#参数【$3】代表输出显示，【$4】不启用重定向
	#参数【$5】代表验证证书，【$6】使用自定义UA
	[ -n "$6" ] && agent="--user-agent=$6"
	if wget --help 2>&1 | grep -q 'show-progress' >/dev/null 2>&1; then
		[ "$3" = "echooff" ] && progress='-q' || progress='-q --show-progress'
		[ "$4" = "rediroff" ] && redirect='--max-redirect=0' || redirect=''
		if [ "$5" = "skipceroff" ] || [ "$skip_cert" = OFF ];then
			certificate=''
		else
			certificate='--no-check-certificate'
		fi
		wget -Y on $agent $progress $redirect $certificate --timeout=3 -O "$1" "$url" && return 0 #成功则退出否则重试
		wget -Y off $agent $progress $redirect $certificate --timeout=5 -O "$1" "$2"
		return $?
	elif curl --version >/dev/null 2>&1; then
		[ "$3" = "echooff" ] && progress='-s' || progress='-#'
		[ "$4" = "rediroff" ] && redirect='' || redirect='-L'
		if [ "$5" = "skipceroff" ] || [ "$skip_cert" = OFF ];then
			certificate=''
		else
			certificate='-k'
		fi
		
		# 判断是否启用手搓进度条 (CDN 且 非静默 且 有大小)
		use_manual_bar="" # <--- 这里加上了初始化
		has_cl=$(echo "$header" | grep -iq 'Content-Length' && echo "yes")
		[ "$3" != "echooff" ] && [ "$has_cl" != "yes" ] && [ "$fsize_raw" -gt 0 ] && use_manual_bar="yes"

		auth_arg=""
		if curl --version | grep -q '^curl 8.' && ckcmd base64; then
			auth_b64=$(printf '%s' "$authentication" | base64)
			[ -n "$auth_b64" ] && auth_arg="--proxy-header Proxy-Authorization:Basic $auth_b64"
		fi

		# --- 第一次下载 ---
		if [ "$use_manual_bar" = "yes" ]; then
			result=$(execute_curl "$1" "$url" "$fsize_raw" "$agent $auth_arg $redirect $certificate")
		else
			result=$(curl $agent $auth_arg -w '%{http_code}' --connect-timeout 3 $progress $redirect $certificate -o "$1" "$url")
		fi

		[ "$result" = "200" ] && return 0 #成功则退出否则重试

		# --- Fallback 重试 ---
		export https_proxy=""
		export http_proxy=""
		
		if [ "$use_manual_bar" = "yes" ]; then
			result=$(execute_curl "$1" "$2" "$fsize_raw" "$agent $redirect $certificate")
		else
			result=$(curl $agent -w '%{http_code}' --connect-timeout 5 $progress $redirect $certificate -o "$1" "$2")
		fi
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
