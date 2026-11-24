pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

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
        onExited: brightnessFile.reload()
    }
    FileView {
        id: brightnessFile
        path: ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const val = parseInt(text().trim());
            if (!isNaN(val) && root.max > 0) {
                root.value = val / root.max;
                root.ready = true;
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
                }
            }
        }
    }
}
