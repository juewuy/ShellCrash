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
# (using cursor jump with auto-wrapping and color handling)
content_line() {
    local param="${1:-}"

    # Calculate Available Text Width
    local text_width=$((TABLE_WIDTH - 3))

    # 1. Extract color codes (if present)
    # Use sed to capture the leading ANSI Escape Code (\x1b is the hexadecimal representation of ESC)
    # This line extracts \033[33m... from \033[33m and stores it in color_code
    local color_code
    color_code=$(echo -e "$param" | sed -n 's/^\(\x1b\[[0-9;]*m\).*/\1/p')

    # 2. Generate Clean Text
    # Use sed to remove all ANSI color codes, retaining only plain text content
    # This allows fold to accurately count characters without premature line breaks
    local clean_text
    clean_text=$(echo -e "$param" | sed 's/\x1b\[[0-9;]*m//g')

    if [ -z "$clean_text" ]; then
        echo -e " \033[${TABLE_WIDTH}G||"
    else
        # 3. Insert line breaks in plain text
        echo "$clean_text" | fold -s -w "$text_width" | while IFS= read -r line; do
            # 4. Output Restructuring
            # Force the addition of color_code to each line and append \033[0m to reset at the end
            echo -e " ${color_code}${line}\033[0m\033[${TABLE_WIDTH}G||"
        done
    fi
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
