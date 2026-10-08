import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."
import "../theme-switcher"

// Compact display-management widget, in the spirit of GNOME Displays.
//
// Deliberately independent from monitor-manager/: that widget already covers
// canvas drag-to-arrange with a batch Apply workflow and hotplug auto-detection.
// This one is a separate, simpler entry point: it scans hyprctl only when opened,
// shows one compact card per connected display, and applies each change
// immediately — no polling, no hotplug listener, no "Apply" button.
Scope {
    id: root

    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property int barHeight: 30

    property var monitors: []
    property bool loading: false
    property string errorText: ""

    IpcHandler {
        target: "displays"
        function toggle(): void {
            displayPanel.visible = !displayPanel.visible;
            if (displayPanel.visible)
                root.scan();
        }
        function refresh(): void {
            root.scan();
        }
    }

    // ── Query ────────────────────────────────────────────────────────────────

    function scan() {
        if (queryProc.running)
            return;
        root.loading = true;
        root.errorText = "";
        queryProc.running = true;
    }

    Process {
        id: queryProc
        command: ["hyprctl", "-j", "monitors", "all"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(text);
                    root.monitors = raw.map(m => ({
                                name: m.name,
                                description: m.description ?? "",
                                width: m.width,
                                height: m.height,
                                x: m.x,
                                y: m.y,
                                refreshRate: m.refreshRate ?? 60,
                                scale: m.scale ?? 1,
                                transform: m.transform ?? 0,
                                disabled: !!m.disabled,
                                focused: !!m.focused,
                                availableModes: m.availableModes ?? [],
                                // hyprctl -j reports mirrorOf as a numeric monitor id (as a string),
                                // not a name — resolve it here so the rest of the widget only
                                // ever deals with names.
                                mirrorOf: (() => {
                                        if (!m.mirrorOf || m.mirrorOf === "none")
                                            return "";
                                        const asId = parseInt(m.mirrorOf, 10);
                                        if (!isNaN(asId))
                                            return raw.find(x => x.id === asId)?.name ?? "";
                                        return m.mirrorOf;
                                    })()
                            }));
                } catch (e) {
                    console.error("DisplayManager: failed to parse hyprctl monitors output:", e);
                    root.errorText = "Couldn't read monitor info from Hyprland.";
                }
                root.loading = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    console.warn("DisplayManager queryProc:", text.trim());
                    root.errorText = text.trim();
                }
                root.loading = false;
            }
        }
    }

    // ── Apply ────────────────────────────────────────────────────────────────
    // Every mutation below rebuilds the full monitor set and pushes it to Hyprland
    // immediately, one call per display.
    //
    // Since Hyprland 0.55, a config loaded through the new Lua parser
    // (hyprland.lua) rejects the old `hyprctl keyword monitor ...` runtime API
    // outright ("keyword can't work with non-legacy parsers. Use eval."). The
    // replacement is `hyprctl eval 'hl.monitor({...})'`. We try that first —
    // it's the current, non-deprecated mechanism — and fall back automatically
    // to the legacy `keyword`/`--batch` form only if `eval`/`hl` isn't
    // available at all (i.e. an older Hyprland still on hyprlang). Either way,
    // the Lua/keyword string is passed as a single argv element, never through
    // a shell, so monitor names with unusual characters can't break parsing.

    function escapeLuaString(s) {
        return String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"");
    }

    function buildMonitorLuaCall(m) {
        const name = root.escapeLuaString(m.name);
        if (m.disabled)
            return `hl.monitor({ output = "${name}", disabled = true })`;

        const mode = `${m.width}x${m.height}@${Number(m.refreshRate ?? 60).toFixed(2)}`;
        const position = `${m.x}x${m.y}`;
        const fields = [`output = "${name}"`, `mode = "${mode}"`, `position = "${position}"`, `scale = ${m.scale}`];
        if (m.transform)
            fields.push(`transform = ${m.transform}`);
        if (m.mirrorOf)
            fields.push(`mirror = "${root.escapeLuaString(m.mirrorOf)}"`);
        return `hl.monitor({ ${fields.join(", ")} })`;
    }

    function buildLegacyMonitorLine(m) {
        if (m.disabled)
            return `keyword monitor ${m.name},disable`;
        const res = `${m.width}x${m.height}`;
        const rate = Number(m.refreshRate ?? 60).toFixed(2);
        let line = `keyword monitor ${m.name},${res}@${rate},${m.x}x${m.y},${m.scale}`;
        if (m.transform)
            line += `,transform,${m.transform}`;
        if (m.mirrorOf)
            line += `,mirror,${m.mirrorOf}`;
        return line;
    }

    function applyAll(list) {
        if (applyProc.running || legacyApplyProc.running)
            return;
        root.errorText = "";
        applyProc._list = list;
        const calls = list.map(root.buildMonitorLuaCall);
        applyProc.command = ["hyprctl", "eval", calls.join("; ")];
        applyProc.running = true;
    }

    function applyLegacy(list) {
        if (legacyApplyProc.running)
            return;
        const parts = list.map(root.buildLegacyMonitorLine);
        legacyApplyProc.command = ["hyprctl", "--batch", parts.join(" ; ")];
        legacyApplyProc.running = true;
    }

    // Primary path: hyprctl eval + hl.monitor(...)
    Process {
        id: applyProc
        property var _list: []
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                if (out === "" || out.toLowerCase() === "ok")
                    return;
                // `eval` itself doesn't exist on pre-Lua Hyprland builds — fall back
                if (out.toLowerCase().includes("unknown request"))
                    root.applyLegacy(applyProc._list);
                else
                    root.errorText = out;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err === "")
                    return;
                if (err.toLowerCase().includes("unknown request"))
                    root.applyLegacy(applyProc._list);
                else
                    root.errorText = err;
            }
        }
    }

    // Fallback path: legacy hyprlang `keyword monitor ...` — only used if
    // `hyprctl eval` reports it doesn't recognize the request at all.
    Process {
        id: legacyApplyProc
        running: false
        stdout: StdioCollector {
            // hyprctl always exits 0 for --batch — real errors come back on stdout as text
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.trim() !== "" && l.trim() !== "ok");
                if (lines.length > 0)
                    root.errorText = lines.join("; ");
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root.errorText = text.trim();
            }
        }
    }

    // ── Mutations ────────────────────────────────────────────────────────────

    function patchMonitor(name, patch) {
        const updated = root.monitors.map(m => m.name === name ? Object.assign({}, m, patch) : m);
        root.monitors = updated;
        root.applyAll(updated);
    }

    function setEnabled(name, enabled) {
        if (!enabled) {
            const stillOn = root.monitors.filter(m => m.name !== name && !m.disabled).length;
            if (stillOn === 0) {
                root.errorText = "At least one display needs to stay on.";
                return;
            }
        }
        root.patchMonitor(name, {
            disabled: !enabled
        });
    }

    function setScale(name, scale) {
        root.patchMonitor(name, {
            scale: scale
        });
    }

    function setMirrorMode(name, w, h, rate) {
        root.patchMonitor(name, {
            width: w,
            height: h,
            refreshRate: parseFloat(rate)
        });
    }

    // "This display only" — disable every other display, enable and un-mirror this one
    function setOnly(name) {
        const updated = root.monitors.map(m => m.name === name ? Object.assign({}, m, {
                disabled: false,
                mirrorOf: ""
            }) : Object.assign({}, m, {
                disabled: true
            }));
        root.monitors = updated;
        root.applyAll(updated);
    }

    // "Extend" — enable this display as its own, non-mirrored desktop region.
    // Auto-nudges it to the right of the other enabled displays if it would
    // otherwise land exactly on top of one (e.g. it just came back from Mirror/Only).
    function setExtend(name) {
        let updated = root.monitors.map(m => m.name === name ? Object.assign({}, m, {
                disabled: false,
                mirrorOf: ""
            }) : m);

        const target = updated.find(m => m.name === name);
        const others = updated.filter(m => m.name !== name && !m.disabled && !m.mirrorOf);
        const overlapping = others.some(o => o.x === target.x && o.y === target.y);
        if (overlapping) {
            const rightEdge = others.reduce((max, m) => Math.max(max, m.x + Math.round(m.width / (m.scale || 1))), 0);
            updated = updated.map(m => m.name === name ? Object.assign({}, m, {
                    x: rightEdge,
                    y: 0
                }) : m);
        }

        root.monitors = updated;
        root.applyAll(updated);
    }

    // "Mirror" — this display mirrors the first other known display. Its OWN
    // resolution is left untouched here (see DisplayCard's mirror-resolution
    // picker), which is what lets a 16:9 projector mirror a 16:10 laptop panel
    // without being forced into the laptop's exact geometry.
    function setMirror(name) {
        const source = root.monitors.find(m => m.name !== name);
        if (!source) {
            root.errorText = "No other display to mirror.";
            return;
        }
        const updated = root.monitors.map(m => {
            if (m.name === name)
                return Object.assign({}, m, {
                    disabled: false,
                    mirrorOf: source.name,
                    x: source.x,
                    y: source.y
                });
            if (m.name === source.name)
                // A mirror source can't itself be mirroring something else (no chained mirrors)
                return Object.assign({}, m, {
                    disabled: false,
                    mirrorOf: ""
                });
            return m;
        });
        root.monitors = updated;
        root.applyAll(updated);
    }

    // ── UI ───────────────────────────────────────────────────────────────────

    PanelWindow {
        id: displayPanel
        visible: false
        focusable: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-displays"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: displayPanel.visible = false

            // Rectangle {
            //     anchors.fill: parent
            //     color: root.theme.bgOverlay
            // }
        }

        Rectangle {
            id: box
            anchors {
                top: parent.top
                topMargin: root.barHeight + 8
                horizontalCenter: parent.horizontalCenter
            }
            width: 420
            height: Math.min(mainColumn.implicitHeight + 32, 620)
            radius: 16
            color: root.theme.bgBase
            border.color: root.theme.bgBorder
            border.width: 1
            focus: true

            Keys.onEscapePressed: displayPanel.visible = false

            // absorb clicks inside the box so the outer overlay doesn't close it
            MouseArea {
                anchors.fill: parent
                onClicked: event => event.accepted = true
            }

            ColumnLayout {
                id: mainColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "󰍹  Displays"
                        color: root.theme.textPrimary
                        font {
                            pixelSize: 15
                            bold: true
                            family: root.font
                        }
                    }

                    Text {
                        visible: root.loading
                        text: "Scanning…"
                        color: root.theme.textMuted
                        font {
                            pixelSize: 11
                            family: root.font
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    // Refresh — re-scans without closing the widget or reloading Quickshell
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: refreshArea.containsMouse ? root.theme.bgHover : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: root.loading ? root.theme.textMuted : root.theme.textSecondary
                            font {
                                pixelSize: 13
                                family: root.font
                            }
                        }

                        MouseArea {
                            id: refreshArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.scan()
                        }
                    }
                }

                // Error banner — auto-dismisses, same convention as elsewhere in the config
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.errorText !== ""
                    height: 36
                    radius: 8
                    color: Qt.rgba(root.theme.accentRed.r, root.theme.accentRed.g, root.theme.accentRed.b, 0.15)
                    border.color: root.theme.accentRed
                    border.width: 1

                    onVisibleChanged: if (visible)
                        errorDismiss.restart()

                    Timer {
                        id: errorDismiss
                        interval: 4000
                        onTriggered: root.errorText = ""
                    }

                    Text {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        verticalAlignment: Text.AlignVCenter
                        text: root.errorText
                        color: root.theme.accentRed
                        elide: Text.ElideRight
                        font {
                            pixelSize: 11
                            family: root.font
                        }
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: box.width - 32
                        spacing: 8

                        Repeater {
                            model: root.monitors
                            DisplayCard {
                                required property var modelData
                                monitor: modelData
                                allMonitors: root.monitors
                                theme: root.theme
                                font: root.font

                                onEnableToggled: enabled => root.setEnabled(monitor.name, enabled)
                                onScaleSelected: scale => root.setScale(monitor.name, scale)
                                onExtendSelected: root.setExtend(monitor.name)
                                onMirrorSelected: root.setMirror(monitor.name)
                                onOnlySelected: root.setOnly(monitor.name)
                                onMirrorModeSelected: (w, h, rate) => root.setMirrorMode(monitor.name, w, h, rate)
                            }
                        }

                        Text {
                            visible: root.monitors.length === 0 && !root.loading
                            text: "No displays found."
                            color: root.theme.textMuted
                            font {
                                pixelSize: 12
                                family: root.font
                            }
                        }
                    }
                }
            }
        }
    }
}
