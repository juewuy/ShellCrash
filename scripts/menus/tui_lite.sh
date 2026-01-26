
TABLE_WIDTH=60

content_line() {
    printf '%b' " $1\n"
}

content_right() {
	printf "%$((TABLE_WIDTH - 13))s\n" "$1"
}
sub_content_line() {
    content_line "   $1"
}

separator_line() {
    echo "-----------------------------------------------"
}

line_break() {
    return
}

