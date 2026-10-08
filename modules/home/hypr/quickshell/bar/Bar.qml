import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick.Controls
import "../theme-switcher"
import "../media"
import "../quick-settings"

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

    IpcHandler {
        target: "bar"
        function toggle(): void {
            root.barVisible = !root.barVisible;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.barVisible

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

                // Left section: Workspaces + Now Playing
                Row {
                    id: leftSection
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Workspaces
                    Row {
                        spacing: 4

                        Repeater {
                            model: (Hyprland.workspaces?.values ?? []).filter(w => w.id > 0)

                            Rectangle {
                                id: wsPill
                                required property var modelData
                                property bool urgentBlink: false

                                height: 26
                                radius: 12
                                color: modelData.focused ? root.theme.accentPrimary : modelData.urgent && urgentBlink ? root.theme.accentRed : root.theme.bgSurface

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 150
                                    }
                                }

                                SequentialAnimation {
                                    loops: Animation.Infinite
                                    running: wsPill.modelData.urgent && !wsPill.modelData.focused

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

                                    // Workspace number
                                    MouseArea {
                                        width: workspaceNumber.implicitWidth
                                        height: 20
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: wsPill.modelData.activate()

                                        Text {
                                            id: workspaceNumber
                                            anchors.centerIn: parent
                                            text: wsPill.modelData.id
                                            color: wsPill.modelData.focused ? root.theme.bgBase : root.theme.textPrimary
                                            font.pixelSize: 14
                                            font.family: root.font
                                            font.bold: wsPill.modelData.focused
                                            style: Text.Raised
                                            styleColor: "#80000000"
                                        }
                                    }

                                    // Window indicators (icons + fallback)
                                    Repeater {
                                        model: (Hyprland.toplevels?.values ?? []).filter(w => w.workspace && w.workspace.id === wsPill.modelData.id)

                                        Item {
                                            required property var modelData

                                            property string appId: {
                                                if (modelData.wayland && modelData.wayland.appId)
                                                    return modelData.wayland.appId;
                                                if (modelData.class)
                                                    return modelData.class;
                                                if (modelData.initialClass)
                                                    return modelData.initialClass;
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

                                                onClicked: {
                                                    var ws = modelData.workspace;
                                                    var title = modelData.title;
                                                    var currentAddr = null;

                                                    if (ws && title) {
                                                        var toplevels = Hyprland.toplevels?.values ?? [];
                                                        for (var i = 0; i < toplevels.length; i++) {
                                                            var win = toplevels[i];
                                                            if (win.workspace && win.workspace.id === ws.id && win.title === title) {
                                                                currentAddr = win.address;
                                                                break;
                                                            }
                                                        }
                                                    }

                                                    if (!currentAddr)
                                                        currentAddr = modelData.address;

                                                    if (currentAddr) {
                                                        var hex = currentAddr.startsWith("0x") ? currentAddr : "0x" + currentAddr;

                                                        if (Hyprland.usingLua) {
                                                            // Hyprland 0.55+ lua config: dispatch calls are lua expressions
                                                            Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + hex + "\" })");
                                                        } else {
                                                            // Legacy hyprlang syntax
                                                            Hyprland.dispatch("focuswindow address:" + hex);
                                                        }
                                                    }
                                                }
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
                    // Now Playing
                    Rectangle {
                        height: 24
                        width: nowPlayingContent.width + 16
                        radius: 12
                        color: root.theme.bgSurface
                        visible: MediaService.hasMedia

                        Accessible.role: Accessible.Button
                        Accessible.name: {
                            if (!MediaService.hasMedia)
                                return "No media";
                            const artist = MediaService.artist || "";
                            const title = MediaService.title || "";
                            return "Now playing: " + (artist ? artist + " - " : "") + title + " (" + MediaService.source + ")";
                        }

                        Row {
                            id: nowPlayingContent
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: MediaService.isPlaying ? "󰐊" : "󰏤"
                                color: root.theme.accentPrimary
                                font.pixelSize: 16
                                font.family: root.font
                                style: Text.Raised
                                styleColor: "#80000000"
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (!MediaService.hasMedia)
                                        return "";
                                    const artist = MediaService.artist || "";
                                    const title = MediaService.title || "";
                                    return artist ? artist + " - " + title : title;
                                }
                                color: root.theme.textPrimary
                                font.pixelSize: 13
                                font.family: root.font
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, 400)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: MediaService.playPause()
                        }
                    }
                }

                // Center section: Window Title (truly centered in bar)
                // Time
                Rectangle {
                    height: 24
                    anchors.centerIn: parent
                    width: timeDate.width + 16
                    radius: 12
                    color: root.theme.bgSurface
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            calendarToggle.running = true;
                        }
                    }
                    Row {
                        id: timeDate
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: root.theme.accentPrimary
                            font.pixelSize: 14
                            font.family: root.font
                        }

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
                // Right section:
                Row {
                    id: rightSection
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // System Tray
                    Rectangle {
                        implicitHeight: 24
                        implicitWidth: trayIcons.implicitWidth + 4
                        radius: 12
                        color: root.theme.bgSurface

                        RowLayout {
                            id: trayIcons
                            anchors.centerIn: parent
                            spacing: 2

                            Repeater {
                                model: SystemTray.items

                                MouseArea {
                                    id: trayDelegate
                                    required property SystemTrayItem modelData

                                    Accessible.role: Accessible.Button
                                    Accessible.name: modelData.tooltipTitle || modelData.title || "System tray item"

                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24

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
                    }
                    // System Info
                    Row {
                        id: sysInfo

                        readonly property color batteryColor: {
                            if (SystemInfo.batteryCharging)
                                return root.theme.accentGreen;
                            if (SystemInfo.batteryLevelRaw > 20)
                                return root.theme.batteryGood;
                            if (SystemInfo.batteryLevelRaw > 10)
                                return root.theme.batteryWarning;
                            return root.theme.batteryCritical;
                        }

                        spacing: 4
                        // CPU
                        Rectangle {
                            height: 24
                            width: cpuContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "CPU: " + SystemInfo.cpuUsage

                            Row {
                                id: cpuContent
                                anchors.centerIn: parent
                                spacing: 6

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
                        }

                        // Network
                        Rectangle {
                            height: 24
                            width: netContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: {
                                if (SystemInfo.networkType === "ethernet")
                                    return "Network: Ethernet";
                                if (SystemInfo.networkType === "wifi")
                                    return "Network: WiFi " + SystemInfo.networkInfo;
                                return "Network: Disconnected";
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    openQuickSettings.running = true;
                                }
                            }

                            Row {
                                id: netContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        if (SystemInfo.networkType === "ethernet")
                                            return "󰈀";
                                        if (SystemInfo.networkType === "wifi")
                                            return "󰖩";
                                        return "󰖪";
                                    }
                                    color: SystemInfo.networkType === "disconnected" ? root.theme.textMuted : root.theme.accentGreen
                                    font.pixelSize: 14
                                    font.family: root.font
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.networkInfo
                                    color: root.theme.textPrimary
                                    font.pixelSize: 13
                                    font.family: root.font
                                }
                            }
                        }

                        // Battery
                        Rectangle {
                            height: 24
                            width: battContent.width + 12
                            radius: 12
                            color: root.theme.bgSurface
                            Accessible.role: Accessible.StaticText
                            Accessible.name: "Battery: " + SystemInfo.batteryLevel

                            Row {
                                id: battContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: SystemInfo.batteryIcon
                                    color: sysInfo.batteryColor
                                    font.pixelSize: 14
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

                    // Quick Settings entry point
                    QuickSettingsButton {
                        anchors.verticalCenter: parent.verticalCenter
                        theme: root.theme
                    }
                }
            }
        }
    }
}
