#!/usr/bin/env fish

set SCRATCHPAD_NAME "yazi_scratchpad"
set FOOT_CLASS "yazi"
set SELECTOR "class:^($FOOT_CLASS)"'$'
set TARGET_WORKSPACE "special:$SCRATCHPAD_NAME"

function window_exists
    test (hyprctl repl "hl.get_window('$SELECTOR') ~= nil") = "true"
end

function wait_for_window
    for i in (seq 1 40)
        if window_exists
            return 0
        end
        sleep 0.05
    end
    return 1
end

if window_exists
    hyprctl dispatch "hl.dsp.workspace.toggle_special('$SCRATCHPAD_NAME')"
else
    hyprctl dispatch "hl.dsp.exec_cmd('foot --app-id=$FOOT_CLASS -e $FOOT_CLASS', { workspace = '$TARGET_WORKSPACE silent' })"

    if not wait_for_window
        echo "yazi-scratchpad: window never appeared, giving up" >&2
        exit 1
    end
    hyprctl dispatch "hl.dsp.workspace.toggle_special('$SCRATCHPAD_NAME')"
end
