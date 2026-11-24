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
    property var options: [
        {
            icon: Quickshell.env("HOME") + "/.config/quickshell/icons/math.svg",
            command: ["sh", "-c", "~/Scripts/quick-latex.sh"]
        },
        {
            icon: Quickshell.env("HOME") + "/.config/quickshell/icons/wljs.svg",
            command: ["wljs"]
        },
        {
            icon: Quickshell.env("HOME") + "/.config/quickshell/icons/projector.svg",
            command: ["qs", "ipc", "call", "displays", "toggle"]
        },
    // {
    //     icon: Quickshell.env("HOME") + "/.config/quickshell/icons/youtube.svg",
    //     command: ["sh", "-c", "foot -e youtube-tui"]
    // }
    ]
    property int selectedIndex: 0
    property bool open: false
    Process {
        id: launcher
    }
    IpcHandler {
        target: "picker"
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
            id: pickerPanel
            Component.onCompleted: {
                root.selectedIndex = 0;
                keyCatcher.forceActiveFocus();
            }
            BackgroundEffect.blurRegion: Region {
                item: pickerBox
                radius: 16
            }
            focusable: true
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-picker"
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
                id: pickerBox
                anchors.centerIn: parent
                width: 420
                height: 100
                radius: 16
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    Repeater {
                        model: root.options
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            radius: 10
                            color: root.selectedIndex === index ? root.theme.accentPrimary : root.theme.bgSurface
                            border.color: root.theme.bgBorder
                            border.width: 1
                            Image {
                                anchors.centerIn: parent
                                width: 40
                                height: 40
                                source: modelData.icon
                                fillMode: Image.PreserveAspectFit
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
