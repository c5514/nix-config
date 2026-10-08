import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../media"
import "../wifi"
import "../bluetooth"

Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property int barHeight: 32

    IpcHandler {
        target: "quickSettings"
        function toggle(): void {
            panel.visible = !panel.visible;
            if (panel.visible)
                displayRow.refresh();
        }
    }

    PanelWindow {
        id: panel
        visible: false
        focusable: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-quick-settings"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Whenever the panel closes (click outside, Escape, or IPC toggle),
        // collapse the Wi-Fi and Bluetooth sections so it reopens in its
        // initial state.
        onVisibleChanged: {
            if (!visible) {
                wifiRow.expanded = false;
                bluetoothRow.expanded = false;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: panel.visible = false
        }

        Rectangle {
            id: box
            anchors {
                top: parent.top
                topMargin: root.barHeight + 8
                right: parent.right
                rightMargin: 10
            }
            width: 400
            height: Math.min(content.height + 32, 760)
            radius: 16
            color: root.theme.bgBase
            border.color: root.theme.bgBorder
            border.width: 1
            focus: true
            Keys.onEscapePressed: panel.visible = false
            MouseArea {
                anchors.fill: parent
                onClicked: event => event.accepted = true
            }

            Column {
                id: content
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 16
                }
                spacing: 12
                RowLayout {
                    width: content.width
                    spacing: 8

                    WifiRow {
                        id: wifiRow
                        theme: root.theme
                        font: root.font
                        Layout.fillWidth: true
                    }

                    BluetoothRow {
                        id: bluetoothRow
                        theme: root.theme
                        font: root.font
                        Layout.fillWidth: true
                    }
                }
                Rectangle {
                    width: content.width
                    visible: wifiRow.expanded
                    height: visible ? wifiContent.implicitHeight + 24 : 0
                    radius: 12
                    color: root.theme.bgSurface
                    border.color: root.theme.bgBorder
                    border.width: 1

                    WifiPanelContent {
                        id: wifiContent
                        anchors.fill: parent
                        anchors.margins: 12
                        theme: root.theme
                        font: root.font
                    }
                }
                Rectangle {
                    width: content.width
                    visible: bluetoothRow.expanded
                    height: visible ? bluetoothContent.implicitHeight + 24 : 0
                    radius: 12
                    color: root.theme.bgSurface
                    border.color: root.theme.bgBorder
                    border.width: 1

                    BluetoothPanelContent {
                        id: bluetoothContent
                        anchors.fill: parent
                        anchors.margins: 12
                        theme: root.theme
                        font: root.font
                        sectionVisible: bluetoothRow.expanded
                    }
                }
                RowLayout {
                    width: content.width
                    spacing: 8

                    DisplayRow {
                        id: displayRow
                        theme: root.theme
                        font: root.font
                        Layout.fillWidth: true
                    }

                    BatteryRow {
                        theme: root.theme
                        font: root.font
                        Layout.fillWidth: true
                    }
                }
                RowLayout {
                    width: content.width
                    spacing: 8

                    DndRow {
                        theme: root.theme
                        font: root.font
                        Layout.fillWidth: true
                    }

                    MicRow {
                        theme: root.theme
                        font: root.font
                        Layout.fillWidth: true
                    }
                }
                AudioVolumeRow {
                    width: content.width
                    theme: root.theme
                    font: root.font
                }
                BrightnessRow {
                    width: content.width
                    theme: root.theme
                    font: root.font
                }
                MediaPlayer {
                    width: content.width
                    theme: root.theme
                    font: root.font
                    visible: MediaService.mprisSources.length > 0 || MpdService.hasSong
                }
            }
        }
    }
}
