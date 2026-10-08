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
    // },
    // {
    //     icon: Quickshell.env("HOME") + "/.config/quickshell/icons/game.svg",
    //     command: ["sh", "-c", "~/.config/quickshell/utils/gamemode.sh"]
    // }
    ]

    property int selectedIndex: 0

    Process {
        id: launcher
    }

    IpcHandler {
        target: "picker"

        function toggle(): void {
            pickerPanel.visible = !pickerPanel.visible;

            if (pickerPanel.visible) {
                root.selectedIndex = 0;
                keyCatcher.forceActiveFocus();
            }
        }
    }

    function runOption(option) {
        if (option.action === "toggle-theme") {
            root.theme.toggleLightDark();
            pickerPanel.visible = false;
            return;
        }
        launcher.command = option.command;
        launcher.running = true;
        pickerPanel.visible = false;
    }

    PanelWindow {
        id: pickerPanel
        visible: false
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
                onClicked: pickerPanel.visible = false
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
                    pickerPanel.visible = false;
                    event.accepted = true;
                    break;
                }
            }
        }
    }
}
