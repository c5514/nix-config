import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."
import "../theme-switcher"

Scope {
    id: root

    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property int barHeight: 30

    property var monitors: []
    property bool loading: false
    property bool applying: false
    property string errorText: ""
    property bool open: false

    IpcHandler {
        target: "displays"
        function toggle(): void {
            root.open = !root.open;
            if (root.open)
                root.scan();
        }
        function refresh(): void {
            root.scan();
        }
    }

    property var _rawOutputs: ({})

    function scan() {
        if (queryProc.running || focusedProc.running)
            return;
        root.loading = true;
        root.errorText = "";
        queryProc.running = true;
    }

    // Turn niri's output object into the flat per-display records the cards use.
    function buildMonitors(raw, focusedName) {
        // niri returns an object keyed by connector name; tolerate an array too.
        const byName = {};
        if (Array.isArray(raw)) {
            for (const o of raw)
                byName[o.name] = o;
        } else {
            Object.assign(byName, raw);
        }

        const result = [];
        for (const name of Object.keys(byName).sort()) {
            const o = byName[name];
            const rawModes = o.modes ?? [];
            const modes = rawModes.map(md => ({
                        w: md.width,
                        h: md.height,
                        rate: md.refresh_rate / 1000,
                        // niri wants the refresh rate to match to three decimals
                        rateStr: (md.refresh_rate / 1000).toFixed(3),
                        preferred: !!md.is_preferred
                    }));
            const cur = (o.current_mode !== null && o.current_mode !== undefined) ? modes[o.current_mode] : null;
            const lg = o.logical ?? null;
            const label = [o.make, o.model].filter(x => x && x !== "Unknown").join(" ");

            result.push({
                name: name,
                description: label,
                width: cur ? cur.w : 0,
                height: cur ? cur.h : 0,
                refreshRate: cur ? cur.rate : 0,
                // logical (scaled, rotated) size and position in the global space
                x: lg ? lg.x : 0,
                y: lg ? lg.y : 0,
                lw: lg ? lg.width : 0,
                lh: lg ? lg.height : 0,
                scale: lg ? lg.scale : 1,
                disabled: !lg,
                focused: name === focusedName,
                modes: modes
            });
        }
        return result;
    }

    Process {
        id: queryProc
        command: ["niri", "msg", "-j", "outputs"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._rawOutputs = JSON.parse(text);
                    // second step: which output is focused
                    focusedProc.running = true;
                } catch (e) {
                    console.error("DisplayManager: failed to parse niri outputs:", e);
                    root.errorText = "Couldn't read monitor info from niri.";
                    root.loading = false;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "") {
                    console.warn("DisplayManager queryProc:", text.trim());
                    root.errorText = text.trim();
                    root.loading = false;
                }
            }
        }
    }

    Process {
        id: focusedProc
        command: ["niri", "msg", "-j", "focused-output"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let focusedName = "";
                try {
                    const f = JSON.parse(text);
                    focusedName = f && f.name ? f.name : "";
                } catch (e) {}
                root.monitors = root.buildMonitors(root._rawOutputs, focusedName);
                root.loading = false;

                // The display showing the mirror was turned off or unplugged.
                if (root.mirrorTarget !== "") {
                    const t = root.findMonitor(root.mirrorTarget);
                    if (!t || t.disabled)
                        root.stopMirror();
                }
            }
        }
    }

    // ── Apply ────────────────────────────────────────────────────────────────
    // Each mutation produces a list of `niri msg output ...` argument arrays.
    // They run one after another (stopping at the first failure), then the
    // state is re-read so the UI reflects what niri really ended up with.
    // Arguments go straight to argv, never through a shell.

    property var queue: []

    function runCommands(cmds) {
        if (root.applying)
            return;
        root.errorText = "";
        root.queue = cmds.slice();
        root.applying = true;
        root.runNext();
    }

    function runNext() {
        if (root.queue.length === 0) {
            root.applying = false;
            rescanTimer.restart();
            return;
        }
        const next = root.queue[0];
        root.queue = root.queue.slice(1);
        runner.command = ["niri", "msg", "output"].concat(next);
        runner.running = true;
    }

    Process {
        id: runner
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err !== "")
                    root.errorText = err;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.queue = [];
            root.runNext();
        }
    }

    // Give niri a moment to settle the new output configuration before re-reading.
    Timer {
        id: rescanTimer
        interval: 200
        onTriggered: root.scan()
    }

    // ── Mutations ────────────────────────────────────────────────────────────

    function findMonitor(name) {
        return root.monitors.find(m => m.name === name) ?? null;
    }

    function setEnabled(name, enabled) {
        if (!enabled) {
            const stillOn = root.monitors.filter(m => m.name !== name && !m.disabled).length;
            if (stillOn === 0) {
                root.errorText = "At least one display needs to stay on.";
                return;
            }
        }
        root.runCommands([[name, enabled ? "on" : "off"]]);
    }

    function setScale(name, scale) {
        root.runCommands([[name, "scale", String(scale)]]);
    }

    function setMode(name, w, h, rate) {
        root.runCommands([[name, "mode", w + "x" + h + "@" + rate]]);
    }

    // "Only" - turn this display on first (so there is never zero outputs),
    // then turn every other display off.
    function setOnly(name) {
        const cmds = [[name, "on"]];
        for (const m of root.monitors) {
            if (m.name !== name && !m.disabled)
                cmds.push([m.name, "off"]);
        }
        root.runCommands(cmds);
    }

    // "Extend" - make sure this display is on and not sitting on top of
    // another one; if it is, park it to the right of everything else.
    function setExtend(name) {
        const target = root.findMonitor(name);
        if (!target)
            return;
        const others = root.monitors.filter(m => m.name !== name && !m.disabled);
        const cmds = [];
        if (target.disabled)
            cmds.push([name, "on"]);

        const overlaps = !target.disabled && others.some(o => target.x < o.x + o.lw && o.x < target.x + target.lw && target.y < o.y + o.lh && o.y < target.y + target.lh);
        if (target.disabled || overlaps) {
            const rightEdge = others.reduce((max, m) => Math.max(max, m.x + m.lw), 0);
            cmds.push([name, "position", "set", String(rightEdge), "0"]);
        }

        if (cmds.length === 0) {
            root.scan();
            return;
        }
        root.runCommands(cmds);
    }

    // ── Mirroring (wl-mirror) ────────────────────────────────────────────────
    // niri can't mirror displays itself, so this does what
    //     wl-mirror $(niri msg --json focused-output | jq -r .name)
    // does, then puts the window where you want it: the focused display is the
    // source (already known from the scan, so no jq), a wl-mirror window is
    // started, found by its process id, moved to the chosen display and made
    // fullscreen. Toggling it off ends the process, which closes the window.
    // One mirror at a time: picking another display moves it there.

    property string mirrorBinary: "wl-mirror"
    property string mirrorTarget: ""        // display showing the mirror ("" = off)
    property string mirrorSource: ""        // display being mirrored
    property bool mirrorStarting: false     // started, window not placed yet
    property var pendingMirror: null        // {target, source} to start once the old one exits
    property bool mirrorStopRequested: false
    property int mirrorTries: 0
    property int previousFocusId: -1

    function mirrorStateFor(name) {
        if (name !== root.mirrorTarget)
            return "";
        return root.mirrorStarting ? "starting" : "active";
    }

    function mirrorNoteFor(name) {
        return name === root.mirrorTarget ? "Mirroring " + root.mirrorSource : "";
    }

    function toggleMirror(target) {
        if (root.mirrorTarget === target) {
            root.stopMirror();
            return;
        }
        const source = root.monitors.find(m => m.focused);
        if (!source || source.name === target) {
            root.errorText = "Focus the display to mirror, then pick a different display as the target.";
            return;
        }
        root.errorText = "";
        const req = {
            target: target,
            source: source.name
        };
        if (mirrorProc.running) {
            // Switching displays: let the old window go first.
            root.pendingMirror = req;
            root.mirrorStopRequested = true;
            mirrorProc.running = false;
        } else {
            root.beginMirror(req);
        }
    }

    function beginMirror(req) {
        root.mirrorTarget = req.target;
        root.mirrorSource = req.source;
        root.mirrorStarting = true;
        root.mirrorStopRequested = false;
        root.mirrorTries = 0;
        root.previousFocusId = -1;
        // Note which window has focus so it can be handed back afterwards,
        // then start wl-mirror (see onFocusSnapshot).
        mirrorWinProc.purpose = "focus";
        mirrorWinProc.running = true;
    }

    function stopMirror() {
        mirrorPoll.stop();
        root.pendingMirror = null;
        if (mirrorProc.running) {
            root.mirrorStopRequested = true;
            mirrorProc.running = false;     // SIGTERM: wl-mirror exits, its window closes
        } else {
            root.resetMirror();
        }
    }

    function resetMirror() {
        root.mirrorTarget = "";
        root.mirrorSource = "";
        root.mirrorStarting = false;
    }

    function onFocusSnapshot(wins) {
        if (!root.mirrorStarting)
            return;     // toggled off in the meantime
        const f = wins.find(w => w.is_focused);
        root.previousFocusId = f ? f.id : -1;
        // argv, never a shell: output names can't be misread as anything else.
        mirrorProc.command = [root.mirrorBinary, root.mirrorSource];
        mirrorProc.running = true;
        mirrorPoll.restart();
    }

    // Prefer the window owned by the process we started; fall back to
    // wl-mirror's app id in case the pid isn't known.
    function findMirrorWindow(wins) {
        const pid = mirrorProc.processId;
        let byApp = null;
        for (const w of wins) {
            if (pid && w.pid === pid)
                return w;
            if (/wl[_-]?mirror/i.test(w.app_id || "") && (!byApp || w.id > byApp.id))
                byApp = w;
        }
        return byApp;
    }

    function onWindowSnapshot(wins) {
        if (!root.mirrorStarting)
            return;
        const w = root.findMirrorWindow(wins);
        if (!w)
            return;     // not mapped yet; the poll timer will ask again

        mirrorPoll.stop();
        root.mirrorStarting = false;

        const cmds = [
            {
                args: ["move-window-to-monitor", "--id", String(w.id), root.mirrorTarget]
            },
            {
                args: ["fullscreen-window", "--id", String(w.id)]
            }
        ];
        // Best effort: give focus back to what you were working in.
        if (root.previousFocusId >= 0 && root.previousFocusId !== w.id)
            cmds.push({
                args: ["focus-window", "--id", String(root.previousFocusId)],
                soft: true
            });
        root.runActions(cmds);
    }

    Process {
        id: mirrorProc
        running: false

        onExited: (exitCode, exitStatus) => {
            mirrorPoll.stop();
            // Dying before its window was placed, without us asking, is a failure.
            if (root.mirrorStarting && !root.mirrorStopRequested && root.pendingMirror === null)
                root.errorText = root.mirrorBinary + " exited before its window appeared.";
            root.mirrorStopRequested = false;
            root.resetMirror();
            if (root.pendingMirror !== null) {
                const req = root.pendingMirror;
                root.pendingMirror = null;
                root.beginMirror(req);
            }
        }
    }

    // Looks at niri's window list: once before starting (to remember focus),
    // then repeatedly until the mirror window shows up.
    Process {
        id: mirrorWinProc
        property string purpose: "find"
        command: ["niri", "msg", "-j", "windows"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let wins = [];
                try {
                    wins = JSON.parse(text);
                } catch (e) {}
                if (mirrorWinProc.purpose === "focus")
                    root.onFocusSnapshot(wins);
                else
                    root.onWindowSnapshot(wins);
            }
        }
    }

    Timer {
        id: mirrorPoll
        interval: 150
        repeat: true
        onTriggered: {
            if (!root.mirrorStarting) {
                stop();
                return;
            }
            if (!mirrorProc.running) {
                // It never started (usually: wl-mirror isn't installed).
                root.errorText = "Couldn't start " + root.mirrorBinary + " - is it installed?";
                root.resetMirror();
                stop();
                return;
            }
            if (++root.mirrorTries > 30) {
                root.errorText = "The mirror window never appeared.";
                root.stopMirror();
                return;
            }
            if (!mirrorWinProc.running) {
                mirrorWinProc.purpose = "find";
                mirrorWinProc.running = true;
            }
        }
    }

    // `niri msg action ...` steps (move, fullscreen, refocus), one after another.
    // A failing step stops the mirror so no stray window is left behind;
    // steps marked `soft` are allowed to fail quietly.
    property var actionQueue: []

    function runActions(cmds) {
        root.actionQueue = cmds.slice();
        root.nextAction();
    }

    function nextAction() {
        if (root.actionQueue.length === 0)
            return;
        const next = root.actionQueue[0];
        root.actionQueue = root.actionQueue.slice(1);
        actionRunner.softFail = !!next.soft;
        actionRunner.command = ["niri", "msg", "action"].concat(next.args);
        actionRunner.running = true;
    }

    Process {
        id: actionRunner
        property bool softFail: false
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (err !== "" && !actionRunner.softFail)
                    root.errorText = err;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !actionRunner.softFail) {
                root.actionQueue = [];
                root.stopMirror();
                return;
            }
            root.nextAction();
        }
    }

    // ── UI ───────────────────────────────────────────────────────────────────

    // Created on open, destroyed on close: a closed panel keeps no window,
    // scene graph or item tree alive.
    LazyLoader {
        active: root.open

        PanelWindow {
            id: displayPanel

            // Blur only the visible panel (niri ext-background-effect), not the whole layer.
            BackgroundEffect.blurRegion: Region {
                item: box
                radius: 16
            }

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
                onClicked: root.open = false

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

                Keys.onEscapePressed: root.open = false

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
                                    onOnlySelected: root.setOnly(monitor.name)
                                    onModeSelected: (w, h, rate) => root.setMode(monitor.name, w, h, rate)
                                    mirrorState: root.mirrorStateFor(modelData.name)
                                    mirrorNote: root.mirrorNoteFor(modelData.name)
                                    onMirrorToggled: root.toggleMirror(monitor.name)
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
}
