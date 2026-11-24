import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme-switcher"

Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property var options: [
        {
            text: "Lock",
            icon: "",
            command: ["sh", "-c", "sleep 0.5 && qs ipc call lock lock"]
        },
        {
            text: "Suspend",
            icon: "󰤄",
            command: ["sh", "-c", "sleep 0.5 && qs ipc call lock lock && sleep 0.5 && systemctl suspend"]
        },
        {
            text: "Exit",
            icon: "󰈆",
            command: ["sh", "-c", "sleep 0.5 && niri msg action quit"]
        },
        {
            text: "Shutdown",
            icon: "⏻",
            command: ["sh", "-c", "sleep 0.5 && systemctl poweroff"]
        },
        {
            text: "Reboot",
            icon: "󰑓",
            command: ["sh", "-c", "sleep 0.5 && systemctl reboot"]
        },
        {
            text: "Hibernate",
            icon: "󰤁",
            command: ["sh", "-c", "sleep 1 && systemctl hibernate"]
        }
    ]
    property int selectedIndex: 0
    property bool open: false
    Process {
        id: launcher
    }
    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            root.open = !root.open;
        }
    }
    function runOption(option) {
        launcher.command = option.command;
        launcher.running = true;
        root.open = false;
    }
    // Created on open, destroyed on close: a closed panel keeps no window,
    // scene graph or item tree alive.
    LazyLoader {
        active: root.open

        PanelWindow {
            id: powerPanel
            Component.onCompleted: {
                root.selectedIndex = 0;
                keyCatcher.forceActiveFocus();
            }
            BackgroundEffect.blurRegion: Region {
                item: powerBox
                radius: 20
            }
            focusable: true
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-power"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            Rectangle {
                anchors.fill: parent
                color: root.theme.bgOverlay
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }
            Rectangle {
                id: powerBox
                anchors.centerIn: parent
                width: 700
                height: 150
                radius: 20
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    Repeater {
                        model: root.options
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            radius: 24
                            color: root.selectedIndex === index ? root.theme.accentPrimary : root.theme.bgSurface
                            border.color: root.theme.bgBorder
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.family: root.font
                                font.pixelSize: 75
                                font.bold: true

                                color: root.selectedIndex === index ? "white" : root.theme.textPrimary
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    root.selectedIndex = index;
                                }
                                onClicked: {
                                    root.runOption(modelData);
                                }
                            }
                        }
                    }
                }
            }
            TextInput {
                id: keyCatcher
                visible: false
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Left:
                        root.selectedIndex = Math.max(0, root.selectedIndex - 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Right:
                        root.selectedIndex = Math.min(root.options.length - 1, root.selectedIndex + 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.runOption(root.options[root.selectedIndex]);
                        event.accepted = true;
                        break;
                    case Qt.Key_Escape:
                        root.open = false;
                        event.accepted = true;
                        break;
                    }
                }
            }
        }
    }
}
