urlencode() {
    LC_ALL=C
    printf '%s' "$1" \
    | hexdump -v -e '/1 "%02X\n"' \
    | while read -r hex; do
        case "$hex" in
            2D|2E|5F|7E|3[0-9]|4[1-9A-F]|5[0-9A]|6[1-9A-F]|7[0-9A-E])
                printf "\\$(printf '%03o' "0x$hex")"
                ;;
            *)
                printf "%%%s" "$hex"
                ;;
        esac
    done
}