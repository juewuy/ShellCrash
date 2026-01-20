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
content_line() {
    raw_input="$1"

    if [ -z "$raw_input" ]; then
        printf " \033[%dG||\n" "$TABLE_WIDTH"
        return
    fi

    printf '%b' "$raw_input" | awk -v table_width="$TABLE_WIDTH" '
    BEGIN {
        textWidth = table_width - 3

        currentDisplayWidth = 0
        wordWidth = 0
        currentLine = ""
        wordBuffer = ""

        lastColor = ""

        ESC = sprintf("%c", 27)
    }

    {
        n = split($0, chars, "")

        for (i = 1; i <= n; i++) {
            r = chars[i]

            if (r == ESC && i+1 <= n && chars[i+1] == "[") {
                # Scan forward until "m"
                ansiSeq = ""
                for (j = i; j <= n; j++) {
                    ansiSeq = ansiSeq chars[j]
                    if (chars[j] == "m") {
                        i = j # Advance main loop
                        break
                    }
                }
                wordBuffer = wordBuffer ansiSeq
                lastColor = ansiSeq # Remember color for wrapping
                continue
            }

            charWidth = 1
            if (r ~ /[^\001-\177]/) {
                charWidth = 2
            }

            if (r == " " || charWidth == 2) {
                if (currentDisplayWidth + wordWidth + charWidth > textWidth) {
                    printf " %s\033[0m\033[%dG||\n", currentLine, table_width
                    currentLine = lastColor wordBuffer
                    currentDisplayWidth = wordWidth
                    wordBuffer = r
                    wordWidth = charWidth
                } else {
                    currentLine = currentLine wordBuffer r
                    currentDisplayWidth += wordWidth + charWidth
                    wordBuffer = ""
                    wordWidth = 0
                }
            } else {
                wordBuffer = wordBuffer r
                wordWidth += charWidth

                if (wordWidth > textWidth) {
                    printf " %s%s\033[0m\033[%dG||\n", currentLine, wordBuffer, table_width
                    currentLine = lastColor
                    currentDisplayWidth = 0
                    wordBuffer = ""
                    wordWidth = 0
                }
            }
        }
    }

    END {
        if (wordWidth > 0) {
            if (currentDisplayWidth + wordWidth > textWidth) {
                printf " %s\033[0m\033[%dG||\n", currentLine, table_width
                currentLine = lastColor wordBuffer
            } else {
                currentLine = currentLine wordBuffer
            }
        }

        cleanText = currentLine
        gsub(/\033\[[0-9;]*m/, "", cleanText)
        gsub(/^[ \t]+|[ \t]+$/, "", cleanText)

        if (cleanText != "") {
            printf " %s\033[0m\033[%dG||\n", currentLine, table_width
        }
    }
    '
}

# function to print sub content lines
# for printing accompanying instructions
sub_content_line() {
    param="$1"
    if [ -z "$param" ]; then
        printf " \033[%dG||\n" "$TABLE_WIDTH"
        return
    fi
    content_line "   $param"
    printf " \033[%dG||\n" "$TABLE_WIDTH"
}

# function to print separators
# (using string slicing)
# parameter $1: pass in "=" or "-"
separator_line() {
    separatorType="$1"
    lenLimit=$((TABLE_WIDTH - 1))
    outputLine=""
    if [ "$separatorType" = "=" ]; then
        outputLine=$(printf "%.${lenLimit}s" "$FULL_EQ")
    else
        outputLine=$(printf "%.${lenLimit}s" "$FULL_DASH")
    fi
    printf "%s||\n" "$outputLine"
}

# increase the spacing between the front
# and back forms to improve readability
line_break() {
    printf "\n\n"
}
