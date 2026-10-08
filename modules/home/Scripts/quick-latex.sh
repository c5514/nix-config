#!/usr/bin/env fish

set -l temp_file (mktemp --suffix=.tex)
printf '' > "$temp_file"

foot --title="quick-latex" \
    -e fish -c "
        set -x NVIM_TEXTEXT 1
        nvim-minimal '$temp_file' \
            -c 'normal! ggA' \
            -c 'startinsert'
        and cat '$temp_file' | wl-copy
        and rm '$temp_file'
    "
