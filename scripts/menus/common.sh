error_report() {
    line_break
    separator_line "="
    content_line "\033[31m$1\033[0m"
    separator_line "="
    sleep 1
}

format_box() {
    line_break
    separator_line "="
    for line in "$@"; do
        content_line "$line"
    done
    separator_line "="
}

common_back() {
    content_line "0) $COMMON_BACK"
    separator_line "="
}

errornum() {
    error_report "\033[31m$COMMON_ERR_NUM\033[0m"
}

error_letter() {
    error_report "\033[31m$COMMON_ERR_LETTER\033[0m"
}

error_input() {
    error_report "\033[31m$COMMON_ERR_INPUT\033[0m"
}

cancel_back() {
    separator_line "-"
    content_line "$COMMON_CANCEL"
    sleep 1
}

common_success() {
    separator_line "-"
    content_line "\033[32m$COMMON_SUCCESS\033[0m"
    sleep 1
}
