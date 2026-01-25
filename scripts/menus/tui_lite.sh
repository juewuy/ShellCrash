
content_line() {
    printf '%b' " $1\n"
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

content_list() {
	i=1
	printf '%s\n' "$1" | while IFS= read -r f; do
		content_line "$i) $f$2"
		i=$(( i + 1 ))
	done
}
