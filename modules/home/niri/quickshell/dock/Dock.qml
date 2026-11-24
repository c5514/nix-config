import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../niri"

Scope {
    id: root
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
            id: "foot",
            label: "Terminal",
            exec: "foot"
        },
        // {
        //     id: "org.wezfurlong.wezterm",
        //     label: "Terminal",
        //     exec: "wezterm"
        // },
        {
            id: "emacs",
            label: "emacs"
        },
        {
            id: "Spotify",
            label: "spotify"
        },
        {
            id: "freetube",
            label: "freetube"
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
    readonly property int previewCardWidth: 300
    readonly property int previewOpenDelayMs: 300
    readonly property int previewCloseDelayMs: 250
    readonly property int previewAreaHeight: 360
    Process {
        id: launchProc
    }
    Process {
        id: openLauncher
        command: ["qs", "ipc", "call", "launcher", "toggle"]
    }
    // Shared with the bar: one event stream and one pair of fetches for the
    // whole shell (see niri/NiriService.qml).
    readonly property var niriWindows: NiriService.windows
    readonly property var niriWorkspaces: NiriService.workspaces
    Process {
        id: niriActionProc
    }
    function niriAction(args) {
        niriActionProc.command = ["niri", "msg", "action"].concat(args);
        niriActionProc.running = true;
    }
    function dockAppId(win) {
        return win.app_id || "";
    }
    function dockGroupKey(appId) {
        return appId.trim().toLowerCase();
    }
    // Lower-cased id -> entry, rebuilt only when the application list changes
    // (the old lookup lower-cased every desktop entry on every call).
    readonly property var _entryIndex: {
        const map = new Map();
        const list = [];
        for (const e of DesktopEntries.applications.values) {
            const id = (e.id || "").toLowerCase();
            if (!id)
                continue;
            if (!map.has(id))
                map.set(id, e);
            list.push([id, e]);
        }
        return {
            map: map,
            list: list
        };
    }
    function findDesktopEntry(appId) {
        if (!appId)
            return null;
        const lower = appId.toLowerCase();
        const idx = root._entryIndex;
        const exact = idx.map.get(lower);
        if (exact)
            return exact;
        for (const pair of idx.list) {
            if (pair[0].includes(lower) || lower.includes(pair[0]))
                return pair[1];
        }
        return null;
    }
    function resolveIcon(appId, entry) {
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, true);
        return appId ? Quickshell.iconPath(appId, true) : "";
    }
    property var runningGroups: {
        const groups = {};
        const wins = root.niriWindows;
        const focusedWs = root.niriWorkspaces.find(w => w.is_focused);
        const focusedId = focusedWs ? focusedWs.id : -1;
        const sorted = wins.slice().sort((x, y) => x.id - y.id);
        for (let i = 0; i < sorted.length; i++) {
            const win = sorted[i];
            const rawAppId = root.dockAppId(win);
            if (!rawAppId)
                continue;
            const key = root.dockGroupKey(rawAppId);
            if (!groups[key])
                groups[key] = {
                    appId: rawAppId,
                    toplevels: [],
                    onFocusedWorkspace: false
                };
            groups[key].toplevels.push(win);
            if (win.workspace_id === focusedId)
                groups[key].onFocusedWorkspace = true;
        }
        return groups;
    }
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
    property var cycleIndices: ({})
    function focusToplevel(tl) {
        if (!tl || tl.id === undefined)
            return;
        root.niriAction(["focus-window", "--id", String(tl.id)]);
    }
    function closeToplevel(tl) {
        if (!tl || tl.id === undefined)
            return;
        root.niriAction(["close-window", "--id", String(tl.id)]);
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
            readonly property var activeWs: root.niriWorkspaces.find(w => w.output === dockWindow.screen.name && w.is_active) ?? null
            readonly property bool workspaceHasWindows: {
                const ws = dockWindow.activeWs;
                if (!ws)
                    return false;
                return root.niriWindows.some(w => w.workspace_id === ws.id);
            }
            readonly property bool dockRevealed: !workspaceHasWindows || hoverRevealed
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
            property string hoverKey: ""
            property string previewKey: ""
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
            mask: dockWindow.previewVisible ? previewMask : (dockWindow.dockRevealed ? revealedMask : hiddenMask)
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
                id: blurDock
                item: dockPanel
                radius: root.panelRadius
            }
            Region {
                id: blurDockPreview
                Region {
                    item: dockPanel
                    radius: root.panelRadius
                }
                Region {
                    item: previewPopover
                    radius: previewPopover.radius
                }
            }
            BackgroundEffect.blurRegion: dockWindow.previewVisible ? blurDockPreview : (dockWindow.dockRevealed ? blurDock : null)
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
                            scale: iconMouse.containsMouse ? 1.15 : 1.0
                        }
                    }
                }
            }
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
                    sourceComponent: Column {
                        spacing: 6
                        Repeater {
                            model: dockWindow.previewItem ? dockWindow.previewItem.toplevels : []
                            Rectangle {
                                id: card
                                required property var modelData
                                readonly property var ws: root.niriWorkspaces.find(w => w.id === modelData.workspace_id) ?? null
                                width: root.previewCardWidth
                                height: 48
                                radius: 12
                                color: cardMouse.containsMouse ? "#26ffffff" : "#14ffffff"
                                border.color: modelData.is_focused ? "#80ffffff" : root.borderColor
                                border.width: 1
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
                                IconImage {
                                    id: cardIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 28
                                    source: dockWindow.previewItem ? dockWindow.previewItem.iconSource : ""
                                    visible: source !== ""
                                }
                                Column {
                                    anchors.left: cardIcon.right
                                    anchors.leftMargin: 10
                                    anchors.right: closeBtn.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: card.modelData.title || (dockWindow.previewItem ? dockWindow.previewItem.label : "")
                                        color: root.textColor
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        width: parent.width
                                        text: {
                                            const name = card.ws ? (card.ws.name || ("Workspace " + card.ws.idx)) : "";
                                            return name + (card.modelData.is_floating ? " \u00b7 floating" : "");
                                        }
                                        color: root.dimTextColor
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                    }
                                }
                                Rectangle {
                                    id: closeBtn
                                    width: 22
                                    height: 22
                                    radius: 11
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: closeMouse.containsMouse ? "#e6d9433f" : "#33ffffff"
                                    opacity: cardMouse.containsMouse || closeMouse.containsMouse ? 1 : 0
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
                        }
                    }
                }
            }
        }
    }
}
