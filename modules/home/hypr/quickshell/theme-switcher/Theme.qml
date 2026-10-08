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
        function toggle(): void {
            root.toggleLightDark();
        }
    }

    property int currentIndex: 0
    property string accent: "#49A0E6"
    readonly property var current: (currentIndex >= 0 && currentIndex < themes.length) ? themes[currentIndex] : themes[0]
    readonly property int count: themes.length
    readonly property string currentName: current.name
    readonly property bool isDark: !isLightColor(current.bgBase)
    property bool themeLoaded: false
    property bool accentLoaded: false

    function finishLoading() {
        if (!themeLoaded || !accentLoaded)
            return;

        applyTheme(current);
    }
    function isLightColor(hex) {
        hex = hex.toString().replace("#", "");
        const r = parseInt(hex.substr(0, 2), 16);
        const g = parseInt(hex.substr(2, 2), 16);
        const b = parseInt(hex.substr(4, 2), 16);
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.5;
    }
    function hexToRgba(hex) {
        return "rgba(" + hex.toString().replace("#", "") + "ff)";
    }
    function escapeLuaString(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }
    readonly property color bgBase: current.bgBase
    readonly property color bgSurface: current.bgSurface
    readonly property color bgHover: current.bgHover
    readonly property color bgSelected: current.bgSelected
    readonly property color bgBorder: current.bgBorder
    readonly property color bgOverlay: "#88000000"
    readonly property color textPrimary: current.textPrimary
    readonly property color textSecondary: current.textSecondary
    readonly property color textMuted: current.textMuted
    readonly property color accentPrimary: accent
    readonly property color accentCyan: current.accentCyan
    readonly property color accentGreen: current.accentGreen
    readonly property color accentOrange: current.accentOrange
    readonly property color accentRed: current.accentRed
    readonly property color urgencyLow: textMuted
    readonly property color urgencyNormal: accentPrimary
    readonly property color urgencyCritical: accentRed
    readonly property color batteryGood: accentGreen
    readonly property color batteryWarning: accentOrange
    readonly property color batteryCritical: accentRed

    function applyTheme(t) {
        applyHyprlandBorders(t);
    }
    function setTheme(index) {
        if (index < 0 || index >= themes.length)
            return;
        currentIndex = index;
        saveThemeProc.command = ["sh", "-c", 'printf "%s" "$1" > "$HOME/.config/quickshell/theme.conf"', "sh", String(index)];
        saveThemeProc.running = true;
        if (themeLoaded && accentLoaded)
            applyTheme(current);
    }

    function toggleLightDark() {
        const targetName = current.name === "Dark" ? "Light" : "Dark";
        const index = themes.findIndex(function (theme) {
            return theme.name === targetName;
        });
        if (index >= 0)
            setTheme(index);
    }
    function updateAccentFromImage(image) {
        if (!image || image.length === 0)
            return;
        accentGenProc.command = [Quickshell.env("HOME") + "/.config/quickshell/theme-switcher/get-accent.sh", image];
        accentGenProc.running = true;
    }

    function applyHyprlandBorders(t) {
        const active = hexToRgba(accent);
        const inactive = hexToRgba(t.bgBorder);
        const lua = `hl.config({ general = { ` + `[\"col.active_border\"] = \"${escapeLuaString(active)}\", ` + `[\"col.inactive_border\"] = \"${escapeLuaString(inactive)}\" ` + `} })`;

        borderProc._legacy = {
            active: active,
            inactive: inactive
        };
        borderProc.command = ["hyprctl", "eval", lua];
        borderProc.running = true;
    }

    function applyHyprlandBordersLegacy(colors) {
        legacyBorderProc.command = ["hyprctl", "--batch", `keyword general:col.active_border "${colors.active}" ; ` + `keyword general:col.inactive_border "${colors.inactive}"`];
        legacyBorderProc.running = true;
    }

    Process {
        id: saveThemeProc
        running: false
    }

    Process {
        id: saveAccentProc
        running: false
    }

    Process {
        id: loadThemeProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/theme.conf 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                const index = parseInt(raw);
                if (!isNaN(index) && index >= 0 && index < root.themes.length) {
                    root.currentIndex = index;
                }
                root.themeLoaded = true;
                root.finishLoading();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.themeLoaded = true;
                root.finishLoading();
            }
        }
    }

    Process {
        id: loadAccentProc
        command: ["sh", "-c", "cat $HOME/.config/quickshell/accent.conf 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const hex = text.trim();
                if (/^#[0-9a-fA-F]{6}$/.test(hex))
                    root.accent = hex;
                root.accentLoaded = true;
                root.finishLoading();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                root.accentLoaded = true;
                root.finishLoading();
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
                saveAccentProc.command = ["sh", "-c", 'printf "%s" "$1" > "$HOME/.config/quickshell/accent.conf"', "sh", hex];
                saveAccentProc.running = true;
                if (root.themeLoaded && root.accentLoaded)
                    root.applyTheme(root.current);
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

    Process {
        id: borderProc
        property var _legacy: null
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output === "" || output.toLowerCase() === "ok") {
                    return;
                }
                if (output.toLowerCase().includes("unknown request") && borderProc._legacy) {
                    root.applyHyprlandBordersLegacy(borderProc._legacy);
                } else {
                    console.warn("Theme: hyprctl eval (borders) error:", output);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const error = text.trim();
                if (error === "")
                    return;
                if (error.toLowerCase().includes("unknown request") && borderProc._legacy) {
                    root.applyHyprlandBordersLegacy(borderProc._legacy);
                } else {
                    console.warn("Theme: hyprctl eval (borders) error:", error);
                }
            }
        }
    }

    Process {
        id: legacyBorderProc
        running: false
    }

    Component.onCompleted: {
        loadThemeProc.running = true;
        loadAccentProc.running = true;
    }

    property var themes: [
        {
            name: "Dark",
            bgBase: "#121212",
            bgSurface: "#39393C",
            bgHover: "#45475a",
            bgSelected: "#444447",
            bgBorder: "#232324",
            textPrimary: "#cdd6f4",
            textSecondary: "#bac2de",
            textMuted: "#a6adc8",
            accentCyan: "#26BED9",
            accentGreen: "#5DF553",
            accentOrange: "#fe640b",
            accentRed: "#d20f39"
        },
        {
            name: "Light",
            bgBase: "#eff1f5",
            bgSurface: "#ccd0da",
            bgHover: "#dce0e8",
            bgSelected: "#bcc0cc",
            bgBorder: "#acb0be",
            textPrimary: "#4c4f69",
            textSecondary: "#5c5f77",
            textMuted: "#6c6f85",
            accentCyan: "#209fb5",
            accentGreen: "#40a02b",
            accentOrange: "#fe640b",
            accentRed: "#d20f39"
        }
    ]
}
