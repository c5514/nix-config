pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../bar"

// All Wi-Fi state/logic (nmcli based), shared by the Quick Settings section.
//
// Compared to the previous version:
//   - Nothing scans at startup any more. The radio is only scanned while the
//     Wi-Fi list is actually on screen (`panelOpen`), which also saves power.
//   - Duplicate SSIDs (several APs / bands) no longer lose the "in use" flag
//     when a stronger AP of the same network is seen first.
//   - "Saved" only considers Wi-Fi profiles (ethernet/VPN/bridge profiles with
//     the same name used to count).
//   - A failed first-time connection with a password no longer leaves a bad
//     saved profile behind (which made the next click skip the password
//     prompt and fail again).
//   - The network list is updated in place instead of clear()+append(), so
//     delegates are not torn down and rebuilt on every scan.
//   - Radio state / list are refreshed when NetworkManager reports a change
//     (via SystemInfo's `nmcli monitor`), not only on user action.
Singleton {
    id: root

    property bool scanning: false
    property string connectingSsid: ""
    property string errorMessage: ""
    property string passwordPromptSsid: ""
    property bool radioEnabled: true

    // Number of Wi-Fi lists currently visible; scanning only happens while > 0.
    property int _viewers: 0
    readonly property bool panelOpen: _viewers > 0

    // SSIDs that have a saved Wi-Fi connection profile.
    property var knownSsids: new Set()

    ListModel {
        id: _wifiModel
    }
    readonly property alias wifiModel: _wifiModel

    // --- view lifecycle ----------------------------------------------

    function attachView() {
        root._viewers++;
        if (root._viewers === 1) {
            root.queryRadio();
            root.refreshKnown();
            root.scanWifi();
        }
    }

    function detachView() {
        root._viewers = Math.max(0, root._viewers - 1);
        if (root._viewers === 0) {
            root.passwordPromptSsid = "";
            root.errorMessage = "";
        }
    }

    onRadioEnabledChanged: {
        if (!radioEnabled) {
            _wifiModel.clear();
            scanning = false;
        } else if (panelOpen) {
            // The interface needs a moment after being switched on before it
            // can scan; scanning immediately returns an empty list.
            scanDelay.restart();
        }
    }

    Timer {
        id: scanDelay
        interval: 1500
        onTriggered: root.scanWifi()
    }

    // NetworkManager says something changed (connect/disconnect/roam).
    Connections {
        target: SystemInfo
        function onNetworkInfoChanged() {
            root.queryRadio();
            if (root.panelOpen && !root.scanning)
                root.listNetworks();
        }
    }

    // --- helpers -----------------------------------------------------

    function queryRadio() {
        if (!radioQueryProcess.running)
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
        return root.knownSsids.has(ssid);
    }

    function isSecure(security) {
        return security && security !== "--" && security !== "";
    }

    function scanWifi() {
        if (!radioEnabled) {
            scanning = false;
            return;
        }
        scanning = true;
        errorMessage = "";
        rescanProcess.running = true;
    }

    function listNetworks() {
        if (!listProcess.running)
            listProcess.running = true;
    }

    function refreshKnown() {
        if (!knownProcess.running)
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
        // One entry per SSID: strongest signal wins, but "in use" sticks if
        // *any* AP of that SSID is the active one.
        const best = new Map();
        for (const line of text.split("\n")) {
            if (!line.trim())
                continue;
            const fields = splitNmcliLine(line);
            if (fields.length < 4)
                continue;
            const ssid = fields[0].trim();
            if (!ssid)
                continue;
            const signal = parseInt(fields[1]) || 0;
            const security = fields[2].trim();
            const inUse = fields[3].trim() === "*";
            const cur = best.get(ssid);
            if (!cur) {
                best.set(ssid, {
                    ssid: ssid,
                    signal: signal,
                    security: security,
                    inUse: inUse
                });
            } else {
                if (signal > cur.signal) {
                    cur.signal = signal;
                    cur.security = security;
                }
                cur.inUse = cur.inUse || inUse;
            }
        }
        const rows = Array.from(best.values()).sort((a, b) => b.signal - a.signal);

        // Update in place when the set/order of networks is unchanged.
        const sameShape = _wifiModel.count === rows.length && rows.every((r, i) => _wifiModel.get(i).ssid === r.ssid);
        if (!sameShape) {
            _wifiModel.clear();
            for (const r of rows)
                _wifiModel.append(r);
            return;
        }
        for (let i = 0; i < rows.length; i++) {
            const cur = _wifiModel.get(i);
            for (const key of ["signal", "security", "inUse"]) {
                if (cur[key] !== rows[i][key])
                    _wifiModel.setProperty(i, key, rows[i][key]);
            }
        }
    }

    function connectToNetwork(ssid, password) {
        connectingSsid = ssid;
        errorMessage = "";
        connectProcess.targetSsid = ssid;
        connectProcess.usedPassword = !!(password && password.length > 0);
        connectProcess.wasKnown = isKnown(ssid);
        if (connectProcess.usedPassword) {
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
        // A rescan can be refused ("not allowed immediately following previous
        // scan"); the cached list is still worth showing, so list regardless.
        onExited: (exitCode, exitStatus) => root.listNetworks()
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
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = new Set();
                for (const line of text.split("\n")) {
                    if (!line.trim())
                        continue;
                    const f = root.splitNmcliLine(line);
                    if (f.length >= 2 && f[1] === "802-11-wireless")
                        names.add(f[0]);
                }
                root.knownSsids = names;
            }
        }
    }

    Process {
        id: connectProcess
        property string targetSsid: ""
        property bool usedPassword: false
        property bool wasKnown: false
        stderr: StdioCollector {
            id: connectStderr
        }
        onExited: (exitCode, exitStatus) => {
            root.connectingSsid = "";
            if (exitCode !== 0) {
                root.errorMessage = "Failed to connect to " + connectProcess.targetSsid + (connectStderr.text ? (": " + connectStderr.text.trim()) : "");
                // nmcli keeps the profile it created for a wrong password, so
                // the next click would skip the prompt and fail again.
                if (connectProcess.usedPassword && !connectProcess.wasKnown) {
                    deleteProcess.command = ["nmcli", "connection", "delete", "id", connectProcess.targetSsid];
                    deleteProcess.running = true;
                }
            } else {
                root.errorMessage = "";
                root.passwordPromptSsid = "";
                root.refreshKnown();
                root.scanWifi();
            }
        }
    }

    Process {
        id: deleteProcess
        onExited: (exitCode, exitStatus) => root.refreshKnown()
    }

    // Only the radio state is needed up front (for the Quick Settings tile).
    Component.onCompleted: root.queryRadio()
}
