#!/bin/sh
# Copyright (C) Juewuy

check_port(){
	if [ "$1" -gt 65535 -o "$1" -le 1 ]; then
		echo -e "\033[31m输入错误！请输入正确的数值(1-65535)！\033[0m"
		return 1
	elif [ -n "$(echo "|$mix_port|$redir_port|$dns_port|$db_port|" | grep "|$1|")" ]; then
		echo -e "\033[31m输入错误！请不要输入重复的端口！\033[0m"
		return 1
	elif [ -n "$(netstat -ntul | grep -E ":$1[[:space:]]")" ]; then
		echo -e "\033[31m当前端口已被其他进程占用，请重新输入！\033[0m"
		return 1
	else
		return 0
	fi
}
