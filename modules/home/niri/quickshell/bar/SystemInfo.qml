pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    property string cpuUsage: "0%"
    property string memoryUsage: "0%"
    property string networkInfo: "Disconnected"
    property string networkType: "disconnected"
    // False on machines without a battery (the old code showed a fake 99%).
    property bool batteryPresent: false
    property int batteryLevelRaw: 0
    property string batteryStatus: "Discharging"
    readonly property string batteryLevel: batteryLevelRaw + "%"
    readonly property bool batteryCharging: batteryStatus === "Charging"
    readonly property string batteryIcon: !batteryPresent ? "󰂎" : root._iconFor(batteryLevelRaw, batteryCharging)
    function _iconFor(level, charging) {
        if (charging)
            return "";
        if (level >= 90)
            return "󰁹";
        if (level >= 80)
            return "󰂂";
        if (level >= 70)
            return "󰂁";
        if (level >= 60)
            return "󰂀";
        if (level >= 50)
            return "󰁿";
        if (level >= 40)
            return "󰁾";
        if (level >= 30)
            return "󰁽";
        if (level >= 20)
            return "󰁼";
        if (level >= 10)
            return "󰁻";
        return "󰁺";
    }
    // ---- CPU / memory (/proc) ---------------------------------------------
    property real _prevTotal: 0
    property real _prevIdle: 0

    function _parseStat(text) {
        const nl = text.indexOf("\n");
        const f = (nl < 0 ? text : text.slice(0, nl)).trim().split(/\s+/);
        // cpu user nice system idle iowait irq softirq steal ...
        let total = 0;
        for (let i = 1; i <= 8 && i < f.length; i++)
            total += Number(f[i]) || 0;
        const idle = (Number(f[4]) || 0) + (Number(f[5]) || 0);
        const dTotal = total - root._prevTotal;
        const dIdle = idle - root._prevIdle;
        if (root._prevTotal > 0 && dTotal > 0)
            root.cpuUsage = Math.round((1 - dIdle / dTotal) * 100) + "%";
        root._prevTotal = total;
        root._prevIdle = idle;
    }
    function _parseMeminfo(text) {
        const total = /MemTotal:\s+(\d+)/.exec(text);
        const avail = /MemAvailable:\s+(\d+)/.exec(text);
        if (!total || !avail)
            return;
        const t = Number(total[1]);
        if (t > 0)
            root.memoryUsage = ((t - Number(avail[1])) / t * 100).toFixed(1) + "%";
    }
    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root._parseStat(statFile.text())
    }
    FileView {
        id: meminfoFile
        path: "/proc/meminfo"
        onLoaded: root._parseMeminfo(meminfoFile.text())
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            statFile.reload();
            meminfoFile.reload();
        }
    }
    // ---- Battery (sysfs) ----------------------------------------------------
    property string _batteryDir: ""
    Process {
        id: batteryDiscovery
        running: true
        command: ["sh", "-c", "for d in /sys/class/power_supply/*; do [ \"$(cat \"$d/type\" 2>/dev/null)\" = Battery ] && echo \"$d\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                root._batteryDir = dir;
                root.batteryPresent = dir !== "";
            }
        }
    }
    FileView {
        id: capacityFile
        path: root._batteryDir !== "" ? root._batteryDir + "/capacity" : ""
        onLoaded: {
            const v = parseInt(capacityFile.text());
            if (!isNaN(v))
                root.batteryLevelRaw = v;
        }
    }

    FileView {
        id: statusFile
        path: root._batteryDir !== "" ? root._batteryDir + "/status" : ""
        onLoaded: {
            const s = statusFile.text().trim();
            if (s !== "")
                root.batteryStatus = s;
        }
    }

    Timer {
        interval: 5000
        running: root.batteryPresent
        repeat: true
        onTriggered: {
            capacityFile.reload();
            statusFile.reload();
        }
    }
    // ---- Network (event-driven) ---------------------------------------------
    property bool _netAgain: false

    function _setNetwork(type, info) {
        root.networkType = type;
        root.networkInfo = info || "Disconnected";
    }

    function refreshNetwork() {
        if (devProc.running || ssidProc.running)
            root._netAgain = true;
        else
            devProc.running = true;
    }

    // Manual split on unescaped ':' (nmcli -t escapes literal colons as \:).
    function _splitNmcli(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (ch === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += ch;
            }
        }
        out.push(cur);
        return out;
    }

    // Ethernet takes priority over Wi-Fi, same as before.
    Process {
        id: devProc
        running: true
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                let eth = false;
                let wifi = false;
                for (const line of text.split("\n")) {
                    if (line.startsWith("ethernet:connected"))
                        eth = true;
                    else if (line.startsWith("wifi:connected"))
                        wifi = true;
                }
                if (eth)
                    root._setNetwork("ethernet", "Ethernet");
                else if (wifi)
                    ssidProc.running = true;
                else
                    root._setNetwork("disconnected", "");
            }
        }
        onExited: {
            if (root._netAgain && !ssidProc.running) {
                root._netAgain = false;
                running = true;
            }
        }
    }
    Process {
        id: ssidProc
        command: ["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let ssid = null;
                for (const line of text.split("\n")) {
                    const f = root._splitNmcli(line);
                    if (f.length >= 2 && f[0] === "yes") {
                        ssid = f[1];
                        break;
                    }
                }
                if (ssid === null || ssid === "")
                    root._setNetwork("disconnected", "");
                else
                    root._setNetwork("wifi", ssid);
            }
        }
        onExited: {
            if (root._netAgain) {
                root._netAgain = false;
                devProc.running = true;
            }
        }
    }
    Process {
        id: netMonitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: data => netDebounce.restart()
        }
        onRunningChanged: if (!running)
            netRestart.start()
    }
    Timer {
        id: netDebounce
        interval: 400
        onTriggered: root.refreshNetwork()
    }
    Timer {
        id: netRestart
        interval: 10000
        onTriggered: netMonitor.running = true
    }
}
