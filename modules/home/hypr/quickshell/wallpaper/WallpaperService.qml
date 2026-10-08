pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<string> wallpapers: []
    property string currentWallpaper: ""
    property string backend: "awww"

    // Scan wallpaper directories
    Process {
        id: scanner
        command: ["sh", "-c", "find -L ~/Pictures/Nix ~/Pictures/Wallpapers -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \\) 2>/dev/null | sort -u | head -200"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                const path = data.trim();
                if (path !== "") {
                    root.wallpapers = [...root.wallpapers, path];
                }
            }
        }
    }

    // Load saved wallpaper path
    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/quickshell/wallpaper.conf"
        onTextChanged: {
            const saved = configFile.text().trim();
            if (saved !== "")
                root.currentWallpaper = saved;
        }
    }

    Component.onCompleted: {
        scanner.running = true;
    }

    function rescan() {
        wallpapers = [];
        scanner.running = true;
    }

    function setWallpaper(path) {
        currentWallpaper = path;

        setProcess.command = ["awww", "img", path, "--transition-type", "grow", "--transition-pos", "center", "--transition-duration", "1"];
        setProcess.running = true;

        // Save to config
        saveProcess.command = ["sh", "-c", 'printf "%s" "$1" > "$HOME/.config/quickshell/wallpaper.conf"', "sh", path];
        saveProcess.running = true;

        // Regenerate the matugen accent color from the new wallpaper. Goes through
        // the theme widget's own IPC target (same cross-widget convention used
        // elsewhere in this config) rather than importing theme-switcher/Theme.qml
        // directly, since each widget directory here stays self-contained.
        accentProcess.command = ["qs", "ipc", "call", "theme", "wallpaper", path];
        accentProcess.running = true;
    }

    Process {
        id: setProcess
        command: []
        running: false
    }

    Process {
        id: saveProcess
        command: []
        running: false
    }

    Process {
        id: accentProcess
        command: []
        running: false
    }
}


