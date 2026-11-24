import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick.Controls
import "../theme-switcher"
import "../quick-settings"
import "../input-method"
import "../niri"

Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property bool barVisible: true
    Process {
        id: calendarToggle
        command: ["qs", "ipc", "call", "calendar", "toggle"]
    }
    Process {
        id: openQuickSettings
        command: ["qs", "ipc", "call", "quickSettings", "toggle"]
    }
    Process {
        id: openInputMethodMenu
    }
    IpcHandler {
        target: "bar"
        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }
    property var niriWindows: []
    property string _windowsSig: ""
    ListModel {
        id: workspaceModel
    }
    function applyWorkspaces(list) {
        const sorted = list.slice().sort((a, b) => (a.output || "").localeCompare(b.output || "") || a.idx - b.idx);
        const rows = sorted.map(w => ({
                    wsId: w.id,
                    idx: w.idx,
                    wsName: w.name ?? "",
                    output: w.output ?? "",
                    isActive: !!w.is_active,
                    isFocused: !!w.is_focused,
                    isUrgent: !!w.is_urgent
                }));
        const sameShape = workspaceModel.count === rows.length && rows.every((r, i) => workspaceModel.get(i).wsId === r.wsId);
        if (!sameShape) {
            workspaceModel.clear();
            for (const r of rows)
                workspaceModel.append(r);
            return;
        }
        for (let i = 0; i < rows.length; i++) {
            const cur = workspaceModel.get(i);
            for (const key of Object.keys(rows[i])) {
                if (cur[key] !== rows[i][key])
                    workspaceModel.setProperty(i, key, rows[i][key]);
            }
        }
    }
    function applyWindows(list) {
        const layoutPos = w => (w.layout && w.layout.pos_in_scrolling_layout) ?? w.pos_in_scrolling_layout ?? null;
        const sorted = list.filter(w => w.workspace_id !== null && w.workspace_id !== undefined).sort((a, b) => {
            const pa = layoutPos(a);
            const pb = layoutPos(b);
            if (pa && pb)
                return (pa[0] - pb[0]) || (pa[1] - pb[1]);
            if (pa)
                return -1;
            if (pb)
                return 1;
            return a.id - b.id;
        });
        const sig = sorted.map(w => w.id + "|" + (w.app_id || "") + "|" + (w.app_id ? "" : (w.title || "")) + "|" + w.workspace_id).join(";");
        if (sig === root._windowsSig)
            return;
        root._windowsSig = sig;
        root.niriWindows = sorted.map(w => ({
                    id: w.id,
                    appId: w.app_id || "",
                    title: w.title || "",
                    workspaceId: w.workspace_id
                }));
    }
    Connections {
        target: NiriService
        function onWorkspacesChanged() {
            root.applyWorkspaces(NiriService.workspaces);
        }
        function onWindowsChanged() {
            root.applyWindows(NiriService.windows);
        }
    }

    Component.onCompleted: {
        root.applyWorkspaces(NiriService.workspaces);
        root.applyWindows(NiriService.windows);
    }
    property var _queue: []
    function niriRun(cmds) {
        root._queue = root._queue.concat(cmds);
        if (!actionProc.running)
            root._nextAction();
    }
    function _nextAction() {
        if (root._queue.length === 0)
            return;
        const next = root._queue[0];
        root._queue = root._queue.slice(1);
        actionProc.command = ["niri", "msg"].concat(next);
        actionProc.running = true;
    }
    Process {
        id: actionProc
        running: false
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root._queue = [];
            root._nextAction();
        }
    }
    function focusWindow(id) {
        root.niriRun([["action", "focus-window", "--id", String(id)]]);
    }
    function focusWorkspace(output, idx) {
        const cmds = [];
        if (output !== "")
            cmds.push(["action", "focus-monitor", output]);
        cmds.push(["action", "focus-workspace", String(idx)]);
        root.niriRun(cmds);
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: barWindow
            required property var modelData
            screen: modelData
            visible: root.barVisible
            BackgroundEffect.blurRegion: Region {
                width: barWindow.width
                height: barWindow.height
            }
            anchors {
                top: true
                left: true
                right: true
            }
            implicitHeight: 32
            color: root.theme.bgBase
            Item {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                // Left section: Workspaces
                Row {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    // Workspaces
                    Row {
                        spacing: 4
                        Repeater {
                            model: workspaceModel
                            Rectangle {
                                id: wsPill
                                required property int wsId
                                required property int idx
                                required property string wsName
                                required property string output
                                required property bool isActive
                                required property bool isFocused
                                required property bool isUrgent
                                property bool urgentBlink: false
                                readonly property var wins: root.niriWindows.filter(w => w.workspaceId === wsPill.wsId)
                                visible: wsPill.output === barWindow.screen.name && (wsPill.isActive || wsPill.isFocused || wsPill.wins.length > 0)
                                height: 26
                                radius: 12
                                color: isFocused ? root.theme.accentPrimary : isUrgent && urgentBlink ? root.theme.accentRed : isActive ? root.theme.bgHover : root.theme.bgSurface
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }
                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    running: wsPill.isUrgent && !wsPill.isFocused
                                    PropertyAction {
                                        target: wsPill
                                        property: "urgentBlink"
                                        value: true
                                    }
                                    PauseAnimation {
                                        duration: 500
                                    }
                                    PropertyAction {
                                        target: wsPill
                                        property: "urgentBlink"
                                        value: false
                                    }
                                    PauseAnimation {
                                        duration: 500
                                    }
                                    onStopped: wsPill.urgentBlink = false
                                }

                                Row {
                                    id: workspaceContent
                                    anchors.centerIn: parent
                                    spacing: 4
                                    // Workspace number (or name, if it has one)
                                    MouseArea {
                                        width: workspaceNumber.implicitWidth
                                        height: 20
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.focusWorkspace(wsPill.output, wsPill.idx)
                                        Text {
                                            id: workspaceNumber
                                            anchors.centerIn: parent
                                            text: wsPill.wsName !== "" ? wsPill.wsName : wsPill.idx
                                            color: wsPill.isFocused ? root.theme.textOnAccent : root.theme.textPrimary
                                            font.pixelSize: 14
                                            font.family: root.font
                                            font.bold: wsPill.isFocused
                                            style: Text.Raised
                                            styleColor: "#80000000"
                                        }
                                    }
                                    // Window indicators (icons + fallback)
                                    Repeater {
                                        model: wsPill.wins
                                        Item {
                                            required property var modelData
                                            property string appId: {
                                                if (modelData.appId)
                                                    return modelData.appId;
                                                if (modelData.title) {
                                                    var words = modelData.title.split(" ");
                                                    return words.length ? words[0].toLowerCase() : "";
                                                }
                                                return "";
                                            }
                                            property string customIconSource: {
                                                var id = appId.toLowerCase();
                                                var iconDir = "file://" + Quickshell.env("HOME") + "/.config/quickshell/icons/";
                                                if (id.includes("emacs"))
                                                    return iconDir + "emacs.svg";
                                                if (id.includes("twintail"))
                                                    return iconDir + "twintail.svg";
                                                if (id.includes("obsidian"))
                                                    return iconDir + "obsidian.svg";
                                                return "";
                                            }
                                            property string iconSource: customIconSource !== "" ? customIconSource : (appId ? Quickshell.iconPath(appId, true) : "")
                                            width: 20
                                            height: 20
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.focusWindow(modelData.id)
                                            }
                                            // App icon
                                            IconImage {
                                                id: appIcon
                                                anchors.fill: parent
                                                source: parent.iconSource
                                                visible: source !== "" && status === Image.Ready
                                                implicitSize: 18
                                            }
                                            // Fallback coloured square
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 3
                                                visible: !appIcon.visible
                                                color: {
                                                    var str = parent.appId || modelData.title || "?";
                                                    var hash = 0;
                                                    for (var i = 0; i < str.length; i++)
                                                        hash = str.charCodeAt(i) + ((hash << 5) - hash);
                                                    var hue = Math.abs(hash) % 360;
                                                    return Qt.hsla(hue / 360, 0.6, 0.5, 1.0);
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: parent.appId ? parent.appId[0].toUpperCase() : "?"
                                                    color: "white"
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }
                                }
                                width: workspaceContent.implicitWidth + 12
                                Behavior on width {
                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                            }
                        }
                    }
                }
                // Center: Date and clock
                Item {
                    anchors.centerIn: parent
                    width: clockRow.implicitWidth
                    height: 24
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calendarToggle.running = true
                    }
                    Row {
                        id: clockRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.timeString
                            color: root.theme.textPrimary
                            font.pixelSize: 14
                            font.family: root.font
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Time.dateString
                            color: root.theme.textPrimary
                            font.pixelSize: 13
                            font.family: root.font
                        }
                    }
                }
                // Right: tray, CPU, Input, status (network + battery), quick settings
                Row {
                    id: rightSection
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16
                    // System tray
                    Row {
                        id: trayIcons
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Repeater {
                            model: SystemTray.items
                            MouseArea {
                                id: trayDelegate
                                required property SystemTrayItem modelData
                                Accessible.role: Accessible.Button
                                Accessible.name: modelData.tooltipTitle || modelData.title || "System tray item"
                                width: 24
                                height: 24
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.LeftButton) {
                                        modelData.activate();
                                    } else if (mouse.button === Qt.RightButton) {
                                        if (modelData.hasMenu) {
                                            menuAnchor.open();
                                        }
                                    } else if (mouse.button === Qt.MiddleButton) {
                                        modelData.secondaryActivate();
                                    }
                                }
                                IconImage {
                                    anchors.centerIn: parent
                                    source: trayDelegate.modelData.icon
                                    implicitSize: 16
                                }
                                QsMenuAnchor {
                                    id: menuAnchor
                                    menu: trayDelegate.modelData.menu
                                    anchor.window: trayDelegate.QsWindow.window
                                    anchor.adjustment: PopupAdjustment.Flip
                                    anchor.onAnchoring: {
                                        const window = trayDelegate.QsWindow.window;
                                        const widgetRect = window.contentItem.mapFromItem(trayDelegate, 0, trayDelegate.height, trayDelegate.width, trayDelegate.height);
                                        menuAnchor.anchor.rect = widgetRect;
                                    }
                                }
                            }
                        }
                    }
                    // CPU
                    Row {
                        id: cpuContent
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Accessible.role: Accessible.StaticText
                        Accessible.name: "CPU: " + SystemInfo.cpuUsage
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: root.theme.accentOrange
                            font.pixelSize: 14
                            font.family: root.font
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: SystemInfo.cpuUsage
                            color: root.theme.textPrimary
                            font.pixelSize: 13
                            font.family: root.font
                        }
                    }

                    // Input method (Fcitx5)
                    Item {
                        id: imIndicator
                        anchors.verticalCenter: parent.verticalCenter
                        visible: InputMethodService.available
                        width: imLabel.implicitWidth
                        height: 24
                        Accessible.role: Accessible.Button
                        Accessible.name: "Input method: " + InputMethodService.current
                        Text {
                            id: imLabel
                            anchors.centerIn: parent
                            text: InputMethodService.label
                            color: InputMethodService.mode === "en" ? root.theme.textPrimary : root.theme.accentPrimary
                            font.pixelSize: 14
                            font.bold: InputMethodService.mode !== "en"
                            font.family: root.font
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const x = Math.round(imIndicator.mapToItem(null, imIndicator.width / 2, 0).x);
                                openInputMethodMenu.command = ["qs", "ipc", "call", "inputmethod", "toggle", barWindow.screen.name, String(x)];
                                openInputMethodMenu.running = true;
                            }
                            onWheel: wheel => InputMethodService.next()
                        }
                    }
                    // Status: network and battery
                    Item {
                        id: statusGroup
                        anchors.verticalCenter: parent.verticalCenter
                        width: statusRow.implicitWidth
                        height: 24
                        readonly property color batteryColor: {
                            if (SystemInfo.batteryCharging)
                                return root.theme.accentGreen;
                            if (SystemInfo.batteryLevelRaw > 20)
                                return root.theme.textPrimary;
                            if (SystemInfo.batteryLevelRaw > 10)
                                return root.theme.batteryWarning;
                            return root.theme.batteryCritical;
                        }
                        Accessible.role: Accessible.Button
                        Accessible.name: {
                            const net = SystemInfo.networkType === "ethernet" ? "Ethernet" : SystemInfo.networkType === "wifi" ? "WiFi" : "Disconnected";
                            return "Network: " + net + ", Battery: " + SystemInfo.batteryLevel;
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: openQuickSettings.running = true
                        }
                        Row {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 14
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (SystemInfo.networkType === "ethernet")
                                        return "󰈀";
                                    if (SystemInfo.networkType === "wifi")
                                        return "";
                                    return "󰖪";
                                }
                                color: SystemInfo.networkType === "disconnected" ? root.theme.textMuted : root.theme.textPrimary
                                font.pixelSize: 14
                                font.family: root.font
                            }
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                visible: SystemInfo.batteryPresent
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.batteryIcon
                                    color: statusGroup.batteryColor
                                    font.pixelSize: 16
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.batteryLevel
                                    color: root.theme.textPrimary
                                    font.pixelSize: 13
                                    font.family: root.font
                                }
                            }
                        }
                    }
                    QuickSettingsButton {
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                    }
                }
            }
        }
    }
}
