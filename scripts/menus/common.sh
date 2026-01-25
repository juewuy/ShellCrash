msg_alert() {
    # Default sleep time
    _sleep_time=1

    if [ "$1" = "-t" ] && [ -n "$2" ]; then
        _sleep_time="$2"
        shift 2
    fi

    line_break
    separator_line "="
    for line in "$@"; do
        content_line "$line"
    done
    separator_line "="
    sleep "$_sleep_time"
}

# complete box
comp_box() {
    line_break
    separator_line "="
    for line in "$@"; do
        content_line "$line"
    done
    separator_line "="
}

top_box() {
    line_break
    separator_line "="
    for line in "$@"; do
        content_line "$line"
    done
}

# bottom box
btm_box() {
    for line in "$@"; do
        content_line "$line"
    done
    separator_line "="
}

# =================================================

common_back() {
    content_line "0) $COMMON_BACK"
    separator_line "="
}

errornum() {
    msg_alert "\033[31m$COMMON_ERR_NUM\033[0m"
}

error_letter() {
    msg_alert "\033[31m$COMMON_ERR_LETTER\033[0m"
}

error_input() {
    msg_alert "\033[31m$COMMON_ERR_INPUT\033[0m"
}

error_cancel() {
    error_report "\033[31m$COMMON_ERR_CANCEL\033[0m"
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
