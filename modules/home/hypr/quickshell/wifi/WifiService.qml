pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// All Wi-Fi state/logic, extracted out of what used to be Wifi.qml's own
// Scope-local properties. Nothing here changed behaviorally — this is the
// same nmcli-based implementation, just made into a proper singleton so it
// can be shared by any UI (now only the embedded Quick Settings section,
// previously also a standalone panel).
Singleton {
    id: root

    property bool scanning: false
    property string connectingSsid: ""
    property string errorMessage: ""
    property string passwordPromptSsid: ""
    property bool radioEnabled: true
    onRadioEnabledChanged: {
        if (radioEnabled)
            root.scanWifi();
    }

    ListModel {
        id: _wifiModel
    }
    ListModel {
        id: _knownModel
    }
    readonly property alias wifiModel: _wifiModel
    readonly property alias knownModel: _knownModel

    // --- helpers -----------------------------------------------------

    function queryRadio() {
        radioQueryProcess.running = true;
    }

    function toggleRadio() {
        radioSetProcess.command = ["nmcli", "radio", "wifi", root.radioEnabled ? "off" : "on"];
        radioSetProcess.running = true;
    }

    function signalBars(signal) {
        if (signal >= 80)
            return 4;
        if (signal >= 55)
            return 3;
        if (signal >= 30)
            return 2;
        if (signal > 0)
            return 1;
        return 0;
    }

    function isKnown(ssid) {
        for (let i = 0; i < knownModel.count; i++) {
            if (knownModel.get(i).name === ssid)
                return true;
        }
        return false;
    }

    function isSecure(security) {
        return security && security !== "--" && security !== "";
    }

    function scanWifi() {
        scanning = true;
        errorMessage = "";
        rescanProcess.running = true;
    }

    function refreshKnown() {
        knownProcess.running = true;
    }

    // Manually split an nmcli -t line on unescaped ':' characters.
    // (Avoids regex lookbehind, which QML's JS engine does not reliably support.)
    function splitNmcliLine(line) {
        const fields = [];
        let current = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                current += line[i + 1];
                i++;
            } else if (ch === ":") {
                fields.push(current);
                current = "";
            } else {
                current += ch;
            }
        }
        fields.push(current);
        return fields;
    }

    function parseWifiList(text) {
        wifiModel.clear();
        const lines = text.split("\n");
        const seen = {};
        for (const line of lines) {
            if (!line.trim())
                continue;
            const fields = splitNmcliLine(line);
            if (fields.length < 4)
                continue;
            const ssid = fields[0].trim();
            const signal = parseInt(fields[1]) || 0;
            const security = fields[2].trim();
            const inUse = fields[3].trim() === "*";
            if (!ssid)
                continue;
            if (seen[ssid] && seen[ssid].signal >= signal)
                continue;
            seen[ssid] = {
                ssid: ssid,
                signal: signal,
                security: security,
                inUse: inUse
            };
        }
        const arr = Object.values(seen).sort((a, b) => b.signal - a.signal);
        for (const net of arr) {
            wifiModel.append(net);
        }
    }

    function connectToNetwork(ssid, password) {
        connectingSsid = ssid;
        errorMessage = "";
        connectProcess.targetSsid = ssid;
        if (password && password.length > 0) {
            connectProcess.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password];
        } else {
            connectProcess.command = ["nmcli", "dev", "wifi", "connect", ssid];
        }
        connectProcess.running = true;
    }

    function onNetworkClicked(ssid, security, inUse) {
        if (inUse || connectingSsid.length > 0)
            return;
        if (isSecure(security) && !isKnown(ssid)) {
            passwordPromptSsid = ssid;
            errorMessage = "";
        } else {
            connectToNetwork(ssid, "");
        }
    }

    function cancelPasswordPrompt() {
        passwordPromptSsid = "";
        errorMessage = "";
    }

    // --- processes -----------------------------------------------------

    Process {
        id: radioQueryProcess
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.radioEnabled = text.trim() === "enabled";
            }
        }
    }

    Process {
        id: radioSetProcess
        onExited: (exitCode, exitStatus) => root.queryRadio()
    }

    Process {
        id: rescanProcess
        command: ["nmcli", "dev", "wifi", "rescan"]
        onExited: (exitCode, exitStatus) => {
            listProcess.running = true;
        }
    }

    Process {
        id: listProcess
        command: ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parseWifiList(text);
                root.scanning = false;
            }
        }
    }

    Process {
        id: knownProcess
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                knownModel.clear();
                const lines = text.split("\n");
                for (const line of lines) {
                    const name = line.trim();
                    if (name)
                        knownModel.append({
                            name: name
                        });
                }
            }
        }
    }

    Process {
        id: connectProcess
        property string targetSsid: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: connectStderr
        }
        onExited: (exitCode, exitStatus) => {
            root.connectingSsid = "";
            if (exitCode !== 0) {
                root.errorMessage = "Failed to connect to " + connectProcess.targetSsid + (connectStderr.text ? (": " + connectStderr.text.trim()) : "");
            } else {
                root.errorMessage = "";
                root.passwordPromptSsid = "";
                root.refreshKnown();
                root.scanWifi();
            }
        }
    }

    // Initial population — nothing was querying this on its own before
    // (the standalone panel's IPC toggle used to kick it off); now that
    // there's no dedicated open/toggle moment, do it once on startup.
    Component.onCompleted: {
        root.queryRadio();
        root.refreshKnown();
        root.scanWifi();
    }
}
