#生成指定位数的加密秘钥，符合ss2022协议
gen_random() {
    if ckcmd openssl;then
		openssl rand --base64 "$1"
	elif ckcmd base64;then
		head -c "$1" /dev/urandom | base64 | tr -d '\n'
	elif busybox base64 --help >/dev/null 2>&1;then
		head -c "$1" /dev/urandom | base64 | tr -d '\n'
	elif ckcmd uuencode;then
		head -c "$1" /dev/urandom | uuencode -m - | sed -n '2p'
	else
		return 1
	fi
}
#对指定字符串进行base64转码
gen_base64() {
	if ckcmd base64;then
		echo -n "$1" | base64 | tr -d '\n'
	elif busybox base64 --help >/dev/null 2>&1;then
		echo -n "$1" | busybox base64 | tr -d '\n'
	elif ckcmd openssl;then
		echo -n "$1" | openssl base64 -A
	else
		return 1
	fi
}