#检查目录剩余空间——$1:目标路径 $2:-h参数
dir_avail(){
	df -h >/dev/null 2>&1 && h="$2"
	df $h "$1" |awk '{ for(i=1;i<=NF;i++){ if(NR==1){ arr[i]=$i; }else{ arr[i]=arr[i]" "$i; } } } END{ for(i=1;i<=NF;i++){ print arr[i]; } }' |grep -E 'Ava|可用' |awk '{print $2}'
}