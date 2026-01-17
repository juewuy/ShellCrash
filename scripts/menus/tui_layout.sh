# tui/layout.sh
# Terminal UI layout helpers
# Provides menu/table formatting utilities


# set the total width of the menu
# (adjusting this number will automatically change the entire menu, including the separator lines)
# note: The number represents the number of columns that appear when the "||" appears on the right
TABLE_WIDTH=60

# define two extra-long template strings in advance
# (the length should be greater than the expected TABLE_WIDTH)
FULL_EQ="===================================================================================================="
FULL_DASH="- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - "

# function to print content lines
# (using cursor jump)
content_line() {
    local param="${1:-}"
    echo -e " ${param}\033[${TABLE_WIDTH}G||"
}

# function to print sub content lines
# for printing accompanying instructions
sub_content_line() {
    local param="${1:-}"
    echo -e "    ${param}\033[${TABLE_WIDTH}G||"
    content_line
}

# increase the spacing between the front
# and back forms to improve readability
double_line_break() {
    printf "\n\n"
}

# function to print separators
# (using string slicing)
# parameter $1: pass in "=" or "-"
separator_line() {
    local separator_type="$1"
    local output_line=""
    local len=$((TABLE_WIDTH - 1))

    if [ "$separator_type" == "=" ]; then
        output_line="${FULL_EQ:0:$len}"
    else
        output_line="${FULL_DASH:0:$len}"
    fi

    echo "${output_line}||"
}
