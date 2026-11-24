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

    property bool open: false

    IpcHandler {
        target: "quickSettings"
        function toggle(): void {
            root.open = !root.open;
        }
    }

    // The whole panel (Wi-Fi/Bluetooth lists, media cards, sliders, the
    // fullscreen layer surface) only exists while it is open. Before, all of
    // it was instantiated at startup and kept alive hidden.
    LazyLoader {
        active: root.open

    PanelWindow {
        id: panel
        BackgroundEffect.blurRegion: Region {
            item: box
            radius: 16
        }
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
        // Refresh state that may have changed while the panel was closed.
        Component.onCompleted: WifiService.queryRadio()
        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
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
            Keys.onEscapePressed: root.open = false
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
                    height: wifiLoader.item ? wifiLoader.item.implicitHeight + 24 : 0
                    radius: 12
                    color: root.theme.bgSurface
                    border.color: root.theme.bgBorder
                    border.width: 1
                    Loader {
                        id: wifiLoader
                        anchors.fill: parent
                        anchors.margins: 12
                        active: wifiRow.expanded
                        sourceComponent: WifiPanelContent {
                            theme: root.theme
                            font: root.font
                        }
                    }
                }
                Rectangle {
                    width: content.width
                    visible: bluetoothRow.expanded
                    height: bluetoothLoader.item ? bluetoothLoader.item.implicitHeight + 24 : 0
                    radius: 12
                    color: root.theme.bgSurface
                    border.color: root.theme.bgBorder
                    border.width: 1
                    Loader {
                        id: bluetoothLoader
                        anchors.fill: parent
                        anchors.margins: 12
                        active: bluetoothRow.expanded
                        sourceComponent: BluetoothPanelContent {
                            theme: root.theme
                            font: root.font
                        }
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
}
