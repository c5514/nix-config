#!/usr/bin/env fish
set ANIM_STATE (hyprctl getoption animations:enabled | head -n1 | string split -f2 ' ')
set POWER_STATE (powerprofilesctl get)

if contains -- "$ANIM_STATE" true 1
    hyprctl eval 'hl.config({
        animations = { enabled = false },
        decoration = {
            shadow   = { enabled = false },
            blur     = { enabled = false },
            rounding = 0,
        },
        general = {
            gaps_in  = 0,
            gaps_out = 0,
        },
    })'
    powerprofilesctl set performance
    notify-send "Gamemode on" &
else
    hyprctl eval 'hl.config({
        animations = { enabled = true },
        decoration = {
            shadow   = { enabled = true },
            blur     = { enabled = true },
            rounding = 15,
        },
        general = {
            gaps_in  = 2,
            gaps_out = 4,
        },
    })'
    powerprofilesctl set balanced
    notify-send "Gamemode off" &
end
