pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// The one shared brightness backend. Backlight discovery, the live file
// watch, and read/write both live here now — extracted directly from what
// was previously private to OSD.qml, so OSD and Quick Settings' brightness
// slider share a single watcher instead of each running their own.
//
// OSD stays responsible for transient visual feedback (it decides *when*
// to show/hide itself); this service is only responsible for *what the
// current brightness actually is* and letting it be changed.
Singleton {
    id: root

    property real value: 0 // 0..1
    property real max: 1
    property bool ready: false
    property string devicePath: ""

    function setBrightness(fraction) {
        const pct = Math.round(Math.max(0, Math.min(1, fraction)) * 100);
        setProc.command = ["brightnessctl", "set", pct + "%"];
        setProc.running = true;
    }

    Process {
        id: setProc
    }

    FileView {
        id: brightnessFile
        path: ""
        watchChanges: true
        onFileChanged: readProc.running = true
    }

    Process {
        id: readProc
        command: ["brightnessctl", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const val = parseInt(text.trim());
                if (!isNaN(val) && root.max > 0) {
                    // Order matters: value changes first (while `ready` is
                    // still false on the very first read), so a listener
                    // watching for real changes vs. the initial population
                    // can tell them apart the same way OSD always could.
                    root.value = val / root.max;
                    root.ready = true;
                }
            }
        }
    }

    Process {
        id: backlightDiscovery
        command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines.length >= 2) {
                    const max = parseInt(lines[1]);
                    if (!isNaN(max) && max > 0)
                        root.max = max;
                    root.devicePath = lines[0];
                    brightnessFile.path = lines[0];
                    readProc.running = true;
                }
            }
        }
    }
}
