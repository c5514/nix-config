import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Scope {
    id: root

    // --- Pin your own apps here -------------------------------------
    // Each entry is shown even when the app isn't running. `id` is matched
    // (case-insensitively) against Hyprland's window class/appId AND
    // against installed desktop-entry ids, so it doubles as both "how do
    // I recognise this app when it's running" and "how do I launch it".
    // `exec` is only used as a launch fallback if no matching desktop
    // entry is found. Left empty by default — fill in the apps you want
    // pinned; anything already running will still show up automatically
    // even if you never add it here.
    //
    // Example:
    // property var pinnedApps: [
    //     { id: "firefox", label: "Firefox" },
    //     { id: "org.gnome.Nautilus", label: "Files" },
    //     { id: "foot", label: "Terminal", exec: "foot" }
    // ]
    property var pinnedApps: [
        {
            id: "org.gnome.Nautilus",
            label: "Files"
        },
        {
            id: "firefox",
            label: "Firefox"
        },
        {
            id: "org.wezfurlong.wezterm",
            label: "Terminal",
            exec: "wezterm"
        },
        {
            id: "emacs",
            label: "emacs"
        },
        {
            id: "Spotify",
            label: "spotify"
        },
    ]

    readonly property color panelColor: "#662b2b2b"
    readonly property color borderColor: "#22ffffff"
    readonly property color textColor: "#ffffff"
    readonly property color dimTextColor: "#b3ffffff"
    readonly property color runningDotColor: "#ffffff"
    readonly property color elsewhereDotColor: "#80ffffff"
    readonly property int iconSize: 46
    readonly property int iconSpacing: 10
    readonly property int panelPadding: 10
    readonly property int panelRadius: 22
    readonly property int activationWidth: 520
    readonly property int activationHeight: 6
    readonly property int hideDelayMs: 350
    readonly property int previewMaxWidth: 220
    readonly property int previewMaxHeight: 140
    readonly property int previewOpenDelayMs: 300
    readonly property int previewCloseDelayMs: 250
    readonly property int previewAreaHeight: 230

    Process {
        id: launchProc
    }

    Process {
        id: openLauncher
        command: ["qs", "ipc", "call", "launcher", "toggle"]
    }

    // Hyprland/Quickshell's incremental toplevel tracking can occasionally
    // leave a stale entry behind after a window closes (observed with
    // Spotify/TwintailLauncher: `hyprctl clients` shows nothing, but
    // Hyprland.toplevels still lists the old address, and focusing it
    // fails with "window not found"). The closewindow-triggered resync
    // alone did not clear these reliably, so a short periodic resync
    // backs it up - cheap (a single IPC round-trip), and just frequent
    // enough that a ghost never lingers for more than a few seconds.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "closewindow" || event.name === "openwindow")
                Hyprland.refreshToplevels();
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: Hyprland.refreshToplevels()
    }

    // Windows on special workspaces (scratchpads) are not shown in the dock.
    // Special workspaces are named "special:*" and have negative ids.
    function isSpecialWorkspace(ws) {
        if (!ws)
            return false;
        return ws.id < 0 || (ws.name || "").startsWith("special");
    }

    // Deliberately does NOT fall back to guessing an identity from the
    // window title. Some Electron apps (Spotify, TwintailLauncher) create
    // an extra, invisible helper surface alongside the real window - used
    // internally for things like drag-and-drop or GPU compositing - which
    // often has no real appId/class of its own but can still carry the
    // app's name as its title. Grouping by title used to merge that
    // helper surface into the real app's icon: it never has capturable
    // content, doesn't respond normally to focus (hence "window not
    // found"), and can outlive the real window entirely. Excluding
    // anything without a genuine appId/class avoids that, at the cost of
    // not showing the rare window that has neither.
    function dockAppId(tl) {
        if (tl.wayland && tl.wayland.appId)
            return tl.wayland.appId;
        if (tl.class)
            return tl.class;
        if (tl.initialClass)
            return tl.initialClass;
        return "";
    }

    // The raw appId is only used for display/icon lookup, both of which
    // already fold case themselves. Grouping, however, needs a single
    // canonical key: some apps (Electron ones especially - Spotify,
    // TwintailLauncher) expose one window natively on Wayland and another
    // via XWayland, and those two paths often disagree on case (e.g.
    // "spotify" vs "Spotify"), which used to create two separate dock
    // icons for the same app.
    function dockGroupKey(appId) {
        return appId.trim().toLowerCase();
    }

    function findDesktopEntry(appId) {
        if (!appId)
            return null;
        const all = DesktopEntries.applications.values;
        const lower = appId.toLowerCase();
        for (let i = 0; i < all.length; i++) {
            if ((all[i].id || "").toLowerCase() === lower)
                return all[i];
        }
        for (let i = 0; i < all.length; i++) {
            const eid = (all[i].id || "").toLowerCase();
            if (eid && (eid.includes(lower) || lower.includes(eid)))
                return all[i];
        }
        return null;
    }

    function resolveIcon(appId, entry) {
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, true);
        return appId ? Quickshell.iconPath(appId, true) : "";
    }

    // Group all toplevels (across every workspace, not just the focused
    // one - the dock is global) by derived appId.
    property var runningGroups: {
        const groups = {};
        const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        const workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        const focused = workspaces.find(w => w.focused);
        const focusedId = focused ? focused.id : -1;

        for (let i = 0; i < toplevels.length; i++) {
            const tl = toplevels[i];
            if (root.isSpecialWorkspace(tl.workspace))
                continue;
            const rawAppId = root.dockAppId(tl);
            if (!rawAppId)
                continue;
            const key = root.dockGroupKey(rawAppId);
            if (!groups[key])
                groups[key] = {
                    appId: rawAppId,
                    toplevels: [],
                    onFocusedWorkspace: false
                };
            groups[key].toplevels.push(tl);
            if (tl.workspace && tl.workspace.id === focusedId)
                groups[key].onFocusedWorkspace = true;
        }
        return groups;
    }

    // Pinned apps (in configured order) merged with their running state,
    // followed by any other running apps not explicitly pinned.
    property var dockItems: {
        const items = [];
        const seen = {};

        for (let i = 0; i < root.pinnedApps.length; i++) {
            const pin = root.pinnedApps[i];
            const pinKey = root.dockGroupKey(pin.id);
            const group = root.runningGroups[pinKey] || null;
            const entry = root.findDesktopEntry(pin.id);
            items.push({
                key: pinKey,
                label: pin.label || (entry ? entry.name : pin.id),
                iconSource: root.resolveIcon(pin.id, entry),
                desktopEntry: entry,
                exec: pin.exec || "",
                toplevels: group ? group.toplevels : [],
                onFocusedWorkspace: group ? group.onFocusedWorkspace : false
            });
            seen[pinKey] = true;
        }

        const runningKeys = Object.keys(root.runningGroups).filter(k => !seen[k]).sort();
        for (let j = 0; j < runningKeys.length; j++) {
            const key = runningKeys[j];
            const group = root.runningGroups[key];
            const entry = root.findDesktopEntry(key);
            items.push({
                key: key,
                label: entry ? entry.name : key,
                iconSource: root.resolveIcon(key, entry),
                desktopEntry: entry,
                exec: "",
                toplevels: group.toplevels,
                onFocusedWorkspace: group.onFocusedWorkspace
            });
        }

        return items;
    }

    // Per-app "which window focuses next" cursor, kept outside dockItems
    // since that model is rebuilt from scratch whenever windows change.
    property var cycleIndices: ({})

    function focusToplevel(tl) {
        if (!tl || !tl.address)
            return;
        const hex = tl.address.startsWith("0x") ? tl.address : "0x" + tl.address;
        if (Hyprland.usingLua) {
            // Hyprland 0.55+ lua config: dispatch calls are lua expressions
            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + hex + "\" })");
        } else {
            // Legacy hyprlang syntax
            Hyprland.dispatch("focuswindow address:" + hex);
        }
    }

    function closeToplevel(tl) {
        // Foreign-toplevel close request; avoids guessing Hyprland's
        // lua/hyprlang close dispatcher syntax. Compositor/app may ignore it.
        if (tl && tl.wayland && tl.wayland.close)
            tl.wayland.close();
    }

    function activateDockItem(item) {
        if (item.toplevels.length > 0) {
            let idx = root.cycleIndices[item.key] || 0;
            if (idx >= item.toplevels.length)
                idx = 0;
            root.focusToplevel(item.toplevels[idx]);

            const next = Object.assign({}, root.cycleIndices);
            next[item.key] = (idx + 1) % item.toplevels.length;
            root.cycleIndices = next;
            return;
        }

        if (item.desktopEntry) {
            item.desktopEntry.execute();
            return;
        }

        if (item.exec) {
            launchProc.command = ["sh", "-c", item.exec];
            launchProc.running = true;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData

            property bool hoverRevealed: false
            readonly property bool hoveringAny: activationHover.hovered || dockHover.hovered || previewHover.hovered

            // Per-screen: the workspace currently shown on THIS monitor, and
            // whether any window lives on it. Empty workspace -> dock stays
            // visible; occupied workspace -> hover-to-reveal.
            readonly property var hyprMonitor: Hyprland.monitorFor(dockWindow.screen)
            readonly property var activeWs: hyprMonitor ? hyprMonitor.activeWorkspace : null
            readonly property bool workspaceHasWindows: {
                const ws = dockWindow.activeWs;
                if (!ws)
                    return false;
                const tls = Hyprland.toplevels ? Hyprland.toplevels.values : [];
                return tls.some(t => t.workspace && t.workspace.id === ws.id && !root.isSpecialWorkspace(t.workspace));
            }

            // True while a special workspace (scratchpad) is shown on THIS
            // monitor. The dock is completely disabled then: not shown, and
            // no hover strip either. Tracked from Hyprland's activespecial
            // events (empty name == special workspace closed).
            property bool specialActive: false

            Component.onCompleted: {
                // Sync once at startup in case a special workspace is
                // already open when Quickshell loads.
                try {
                    const sw = dockWindow.hyprMonitor.lastIpcObject.specialWorkspace;
                    dockWindow.specialActive = !!(sw && sw.name);
                } catch (e) {
                    dockWindow.specialActive = false;
                }
            }

            Connections {
                target: Hyprland

                function onRawEvent(event) {
                    if (event.name !== "activespecial" && event.name !== "activespecialv2")
                        return;
                    const parts = event.data.split(",");
                    // activespecial:   NAME,MONITOR
                    // activespecialv2: ID,NAME,MONITOR
                    const isV2 = event.name === "activespecialv2";
                    const name = isV2 ? parts[1] : parts[0];
                    const monitor = isV2 ? parts[2] : parts[1];
                    if (monitor !== dockWindow.screen.name)
                        return;
                    dockWindow.specialActive = !!name;
                }
            }

            onSpecialActiveChanged: {
                if (specialActive) {
                    hideTimer.stop();
                    hoverRevealed = false;
                }
            }

            readonly property bool dockRevealed: !specialActive && (!workspaceHasWindows || hoverRevealed)

            onHoveringAnyChanged: {
                if (hoveringAny) {
                    hideTimer.stop();
                    hoverRevealed = true;
                } else {
                    hideTimer.restart();
                }
            }

            Timer {
                id: hideTimer
                interval: root.hideDelayMs
                onTriggered: dockWindow.hoverRevealed = false
            }

            // --- Window previews ------------------------------------
            property string hoverKey: ""      // icon currently under the pointer
            property string previewKey: ""    // icon whose preview is open
            property real previewCenterX: 0

            readonly property var previewItem: previewKey === "" ? null : (root.dockItems.find(i => i.key === previewKey) ?? null)
            readonly property bool previewVisible: dockRevealed && previewItem !== null && previewItem.toplevels.length > 0

            onDockRevealedChanged: {
                if (!dockRevealed) {
                    previewKey = "";
                    hoverKey = "";
                }
            }

            function requestPreview(key, centerX) {
                hoverKey = key;
                previewCenterX = centerX;
                previewCloseTimer.stop();
                if (previewKey === key)
                    return;
                if (previewKey !== "")
                    previewKey = key;
                else
                    // already open: switch instantly
                    previewOpenTimer.restart();
            }

            function releasePreview() {
                hoverKey = "";
                previewOpenTimer.stop();
                previewCloseTimer.restart();
            }

            Timer {
                id: previewOpenTimer
                interval: root.previewOpenDelayMs
                onTriggered: if (dockWindow.hoverKey !== "")
                    dockWindow.previewKey = dockWindow.hoverKey
            }

            Timer {
                id: previewCloseTimer
                interval: root.previewCloseDelayMs
                onTriggered: if (!previewHover.hovered && dockWindow.hoverKey === "")
                    dockWindow.previewKey = ""
            }

            visible: true
            focusable: false
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-dock"

            exclusionMode: ExclusionMode.Ignore

            anchors {
                bottom: true
                left: true
                right: true
            }

            implicitHeight: root.activationHeight + dockPanel.implicitHeight + 10 + root.previewAreaHeight

            // Empty mask by default; swapped for one that actually covers
            // the activation strip + dock only while relevant, so clicks
            // everywhere else always reach the windows/desktop below.
            mask: dockWindow.specialActive ? emptyMask : (dockWindow.previewVisible ? previewMask : (dockWindow.dockRevealed ? revealedMask : hiddenMask))

            // Nothing clickable/hoverable: used while a special workspace is open.
            Region {
                id: emptyMask
            }

            Region {
                id: hiddenMask
                item: activationZone
            }

            Region {
                id: revealedMask
                Region {
                    item: activationZone
                }
                Region {
                    item: dockPanel
                }
            }

            Region {
                id: previewMask
                Region {
                    item: activationZone
                }
                Region {
                    item: dockPanel
                }
                Region {
                    item: previewPopover
                }
            }

            // Bottom-edge hover strip. Always present (even while the
            // dock itself is invisible) so the mouse has something to hit.
            Item {
                id: activationZone
                width: root.activationWidth
                height: root.activationHeight
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                HoverHandler {
                    id: activationHover
                }
            }

            Rectangle {
                id: dockPanel
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.activationHeight
                implicitWidth: dockRow.implicitWidth + root.panelPadding * 2
                implicitHeight: dockRow.implicitHeight + root.panelPadding * 2
                radius: root.panelRadius
                color: root.panelColor
                border.color: root.borderColor
                border.width: 1

                opacity: dockWindow.dockRevealed ? 1 : 0
                scale: dockWindow.dockRevealed ? 1 : 0.94

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler {
                    id: dockHover
                }

                Row {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: root.iconSpacing

                    // Pinned "show all applications" tile - always
                    // present, reuses the existing launcher IPC target.
                    Item {
                        width: root.iconSize
                        height: root.iconSize

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: launcherHover.containsMouse ? "#26ffffff" : "#14ffffff"

                            Text {
                                anchors.centerIn: parent
                                text: "󱗼"
                                color: root.textColor
                                font.pixelSize: 40
                            }
                        }

                        MouseArea {
                            id: launcherHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openLauncher.running = true

                            ToolTip.visible: containsMouse
                            ToolTip.delay: 400
                            ToolTip.text: "Applications"
                        }
                    }

                    Rectangle {
                        width: 1
                        height: root.iconSize * 0.7
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.borderColor
                        visible: root.dockItems.length > 0
                    }

                    Repeater {
                        model: root.dockItems

                        Item {
                            id: dockIcon
                            required property var modelData
                            width: root.iconSize
                            height: root.iconSize + 6

                            readonly property bool running: modelData.toplevels.length > 0
                            readonly property int windowCount: modelData.toplevels.length

                            Item {
                                id: iconVisual
                                width: root.iconSize
                                height: root.iconSize
                                anchors.top: parent.top

                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: dockIcon.modelData.iconSource
                                    visible: source !== "" && status === Image.Ready
                                    implicitSize: root.iconSize
                                    asynchronous: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    visible: !appIcon.visible
                                    color: {
                                        const str = dockIcon.modelData.label || dockIcon.modelData.key || "?";
                                        let hash = 0;
                                        for (let i = 0; i < str.length; i++)
                                            hash = str.charCodeAt(i) + ((hash << 5) - hash);
                                        const hue = Math.abs(hash) % 360;
                                        return Qt.hsla(hue / 360, 0.55, 0.5, 1.0);
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: (dockIcon.modelData.label || dockIcon.modelData.key || "?")[0].toUpperCase()
                                        color: root.textColor
                                        font.pixelSize: 18
                                        font.bold: true
                                    }
                                }
                            }

                            // Running / multi-window indicator dots.
                            Row {
                                anchors.top: iconVisual.bottom
                                anchors.topMargin: 3
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3
                                visible: dockIcon.running

                                Repeater {
                                    model: Math.min(dockIcon.windowCount, 3)

                                    Rectangle {
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: dockIcon.modelData.onFocusedWorkspace ? root.runningDotColor : root.elsewhereDotColor
                                    }
                                }
                            }

                            MouseArea {
                                id: iconMouse
                                anchors.fill: iconVisual
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateDockItem(dockIcon.modelData)

                                onContainsMouseChanged: {
                                    if (!dockIcon.running)
                                        return;
                                    if (containsMouse)
                                        dockWindow.requestPreview(dockIcon.modelData.key, dockIcon.mapToItem(null, dockIcon.width / 2, 0).x);
                                    else
                                        dockWindow.releasePreview();
                                }

                                ToolTip.visible: containsMouse && !dockIcon.running
                                ToolTip.delay: 400
                                ToolTip.text: dockIcon.windowCount > 1 ? dockIcon.modelData.label + " (" + dockIcon.windowCount + " windows)" : dockIcon.modelData.label
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 100
                                }
                            }
                            scale: iconMouse.containsMouse ? 1.12 : 1.0
                        }
                    }
                }
            }

            // Live window previews, shown above the hovered dock icon.
            // Content is created only while the popover is open, so no
            // capture requests are issued while it is hidden.
            Rectangle {
                id: previewPopover
                visible: dockWindow.previewVisible
                anchors.bottom: dockPanel.top
                anchors.bottomMargin: 8
                x: Math.max(8, Math.min(dockWindow.width - width - 8, dockWindow.previewCenterX - width / 2))
                implicitWidth: previewLoader.implicitWidth + 24
                implicitHeight: previewLoader.implicitHeight + 24
                radius: 18
                color: root.panelColor
                border.color: root.borderColor
                border.width: 1

                onVisibleChanged: if (visible)
                    fadeIn.restart()

                NumberAnimation {
                    id: fadeIn
                    target: previewPopover
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 150
                    easing.type: Easing.OutCubic
                }

                HoverHandler {
                    id: previewHover
                }

                Loader {
                    id: previewLoader
                    anchors.centerIn: parent
                    active: dockWindow.previewVisible

                    sourceComponent: Row {
                        spacing: 12

                        Repeater {
                            model: dockWindow.previewItem ? dockWindow.previewItem.toplevels : []

                            Item {
                                id: card
                                required property var modelData

                                readonly property int count: dockWindow.previewItem ? dockWindow.previewItem.toplevels.length : 1
                                readonly property real cardWidth: Math.min(root.previewMaxWidth, Math.max(110, (dockWindow.width * 0.9 - 24) / count - 12))

                                width: cardWidth
                                height: root.previewMaxHeight + 26

                                Rectangle {
                                    id: thumbBox
                                    width: parent.width
                                    height: root.previewMaxHeight
                                    radius: 10
                                    color: "#22ffffff"
                                    border.color: cardMouse.containsMouse ? "#80ffffff" : root.borderColor
                                    border.width: 1
                                    clip: true

                                    ScreencopyView {
                                        id: shot
                                        anchors.centerIn: parent
                                        captureSource: card.modelData.wayland ?? null
                                        live: true
                                        constraintSize.width: thumbBox.width - 2
                                        constraintSize.height: thumbBox.height - 2
                                        visible: hasContent
                                    }

                                    // Shown until the first frame arrives, or if the
                                    // compositor gives no capture for this window.
                                    IconImage {
                                        anchors.centerIn: parent
                                        implicitSize: 40
                                        source: dockWindow.previewItem ? dockWindow.previewItem.iconSource : ""
                                        visible: !shot.hasContent
                                    }

                                    MouseArea {
                                        id: cardMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.focusToplevel(card.modelData);
                                            dockWindow.previewKey = "";
                                            dockWindow.hoverKey = "";
                                        }
                                    }

                                    // Close button, only offered when Quickshell has
                                    // a foreign-toplevel handle for this window.
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        color: closeMouse.containsMouse ? "#e6d9433f" : "#99000000"
                                        visible: cardMouse.containsMouse || closeMouse.containsMouse
                                        enabled: card.modelData.wayland !== null && card.modelData.wayland !== undefined

                                        Text {
                                            anchors.centerIn: parent
                                            text: "\u2715"
                                            color: root.textColor
                                            font.pixelSize: 11
                                        }

                                        MouseArea {
                                            id: closeMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.closeToplevel(card.modelData)
                                        }
                                    }
                                }

                                Text {
                                    anchors.top: thumbBox.bottom
                                    anchors.topMargin: 6
                                    width: parent.width
                                    text: card.modelData.title || (dockWindow.previewItem ? dockWindow.previewItem.label : "")
                                    color: root.textColor
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
