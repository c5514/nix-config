pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    IpcHandler {
        target: "theme"
        function wallpaper(image: string): void {
            root.updateAccentFromImage(image);
        }
    }
    property string accent: "#49A0E6"
    readonly property color bgBase: "#99121212"
    readonly property color bgSurface: "#26ffffff"
    readonly property color bgHover: "#40ffffff"
    readonly property color bgSelected: "#4dffffff"
    readonly property color bgBorder: "#22ffffff"
    readonly property color bgOverlay: "#88000000"
    readonly property color textPrimary: "#cdd6f4"
    readonly property color textSecondary: "#bac2de"
    readonly property color textMuted: "#a6adc8"
    readonly property color textOnAccent: "#121212"
    readonly property color accentPrimary: accent
    readonly property color accentCyan: "#26BED9"
    readonly property color accentGreen: "#5DF553"
    readonly property color accentOrange: "#fe640b"
    readonly property color accentRed: "#d20f39"
    readonly property color urgencyLow: textMuted
    readonly property color urgencyNormal: accentPrimary
    readonly property color urgencyCritical: accentRed
    readonly property color batteryGood: accentGreen
    readonly property color batteryWarning: accentOrange
    readonly property color batteryCritical: accentRed
    function updateAccentFromImage(image) {
        if (!image || image.length === 0)
            return;
        accentGenProc.command = [Quickshell.env("HOME") + "/.config/quickshell/theme-switcher/get-accent.sh", image];
        accentGenProc.running = true;
    }
    function writeNiriColors(hex) {
        if (!/^#[0-9a-fA-F]{6}$/.test(hex))
            return;
        niriColorsProc.command = ["sh", "-c", 'f="$HOME/.config/niri-colors.kdl"; ' + 'new=$(printf \'layout {\\n    border {\\n        active-color "%s"\\n    }\\n}\\n\' "$1"); ' + '[ "$(cat "$f" 2>/dev/null)" = "$new" ] || printf "%s\\n" "$new" > "$f"', "sh", hex];
        niriColorsProc.running = true;
    }
    Process {
        id: niriColorsProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("Theme: couldn't write niri-colors.kdl:", text.trim());
            }
        }
    }
    Process {
        id: saveAccentProc
        running: false
    }
    Process {
        id: loadAccentProc
        command: ["sh", "-c", "cat $HOME/.config/accent.conf 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = text.trim();
                if (/^#[0-9a-fA-F]{6}$/.test(hex))
                    root.accent = hex;
                root.writeNiriColors(root.accent);
            }
        }
    }
    Process {
        id: accentGenProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = text.trim();
                if (!/^#[0-9a-fA-F]{6}$/.test(hex)) {
                    console.warn("Theme: get-accent.sh returned an invalid color:", hex);
                    return;
                }
                root.accent = hex;
                saveAccentProc.command = ["sh", "-c", 'printf "%s" "$1" > "$HOME/.config/accent.conf"', "sh", hex];
                saveAccentProc.running = true;
                root.writeNiriColors(hex);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const error = text.trim();
                if (error !== "")
                    console.warn("Theme: get-accent.sh error:", error);
            }
        }
    }
    Component.onCompleted: loadAccentProc.running = true
}
