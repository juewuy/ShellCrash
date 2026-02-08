
bar_max=42 #进度条长度

curl_fsize(){ # 获取文件大小
	fsize_raw=0
	header=$(curl -sIL --connect-timeout 2 "$url")
	# 代理容错
	[ -z "$header" ] && { export https_proxy=""; export http_proxy=""; header=$(curl -sIL --connect-timeout 2 "$url"); }
	# 提取大小 (优先 Content-Length，其次 ETag)
	fsize_raw=$(echo "$header" | grep -i 'Content-Length' | tail -n 1 | awk '{print $2}' | tr -d '\r' | awk '{print int($1)}')
	if [ -z "$fsize_raw" ] || [ "$fsize_raw" -eq 0 ]; then
		etag=$(echo "$header" | grep -i 'etag' | tail -n 1 | cut -d '"' -f2 | cut -d '-' -f1)
		[ -n "$etag" ] && fsize_raw=$(printf "%d" 0x$etag 2>/dev/null)
	fi
}

execute_curl(){ # 手搓curl进度条
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
			local num=$(awk -v p=$pct -v w=$bar_max 'BEGIN {printf "%d", p*w/100}')
			local bar=$(printf "%${num}s" | tr ' ' '#'); local spc_n=$((bar_max - num))
			local spc=""; [ "$spc_n" -gt 0 ] && spc=$(printf "%${spc_n}s")
			local size=$(( fsize_raw * 100 / 1048576 ))
			local fs="$((size / 100)).$((size % 100)) MB"
			printf "\r\033[2K%s%s %6s%%(%s)" "$bar" "$spc" "$pct" "$fs" >&2
		fi
		usleep 200000 2>/dev/null || sleep 1
	done
	
	local code=$(cat /tmp/webget_res 2>/dev/null)
	if [ "$code" = "200" ] || [ "$code" = "206" ]; then
		local full=$(printf "%${bar_max}s" | tr ' ' '#')
		printf "\r\033[2K%s 100.0%%(%s)\n" "$full" "$fs" >&2
	else
		printf "\r\033[2K" >&2; [ -f "$path" ] && rm -f "$path"
	fi
	echo "$code"
}