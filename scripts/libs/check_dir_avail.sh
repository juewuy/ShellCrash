#检查目录剩余空间——$1:目标路径 $2:-h参数
dir_avail() {
    df -P $2 "${1:-.}" 2>/dev/null | awk 'NR==2 {print $(NF-2)}'
}
