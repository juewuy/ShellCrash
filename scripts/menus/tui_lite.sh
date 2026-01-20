
content_line() {
    printf '%b' "$1\n"
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
