import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme-switcher"

// Pure presentation over BluetoothService — no window, no state of its
// own. Same content BluetoothTest.qml had, just sized to live inside
// Quick Settings' expandable Bluetooth section: the three device-list
// sections now sit inside one scrollable, height-capped area instead of
// growing the whole panel taller with every device.
ColumnLayout {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    // Discovery is expensive and shouldn't run forever — same discipline
    // as before, just triggered by this component's own lifecycle instead
    // of a standalone panel's visibility.
    property bool sectionVisible: true
    onSectionVisibleChanged: {
        if (!sectionVisible)
            BluetoothService.stopDiscovery();
    }

    Timer {
        id: scanTimeout
        interval: 30000
        onTriggered: BluetoothService.stopDiscovery()
    }

    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            visible: BluetoothService.available
            width: 40
            height: 20
            radius: 10
            color: BluetoothService.powered ? root.theme.accentPrimary : root.theme.bgHover

            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: root.theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
                x: BluetoothService.powered ? parent.width - width - 3 : 3
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.togglePower()
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Text {
        visible: !BluetoothService.available
        Layout.fillWidth: true
        text: "No Bluetooth adapter found."
        color: root.theme.textMuted
        font.pixelSize: 12
        font.family: root.font
        horizontalAlignment: Text.AlignHCenter
    }

    Text {
        visible: BluetoothService.available && !BluetoothService.powered
        Layout.fillWidth: true
        text: "Bluetooth is off."
        color: root.theme.textMuted
        font.pixelSize: 12
        font.family: root.font
        horizontalAlignment: Text.AlignHCenter
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: BluetoothService.available && BluetoothService.powered
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: BluetoothService.adapterName
            color: root.theme.textMuted
            font.pixelSize: 10
            font.family: root.font
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(deviceListColumn.implicitHeight, 220)
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                id: deviceListColumn
                width: parent.width
                spacing: 12

                // -- Connected --
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: BluetoothService.connectedDevices.length > 0
                    spacing: 4

                    Text {
                        text: "Connected"
                        color: root.theme.textMuted
                        font.pixelSize: 10
                        font.family: root.font
                    }

                    Repeater {
                        model: BluetoothService.connectedDevices
                        delegate: BluetoothDeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            theme: root.theme
                            font: root.font
                            device: modelData
                        }
                    }
                }

                // -- Paired (not connected) --
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: BluetoothService.pairedDevices.length > 0
                    spacing: 4

                    Text {
                        text: "Paired"
                        color: root.theme.textMuted
                        font.pixelSize: 10
                        font.family: root.font
                    }

                    Repeater {
                        model: BluetoothService.pairedDevices
                        delegate: BluetoothDeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            theme: root.theme
                            font: root.font
                            device: modelData
                        }
                    }
                }

                // -- Available (discovered, unpaired) --
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: BluetoothService.availableDevices.length > 0
                    spacing: 4

                    Text {
                        text: "Available"
                        color: root.theme.textMuted
                        font.pixelSize: 10
                        font.family: root.font
                    }

                    Repeater {
                        model: BluetoothService.availableDevices
                        delegate: BluetoothDeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            theme: root.theme
                            font: root.font
                            device: modelData
                        }
                    }
                }

                Text {
                    visible: BluetoothService.connectedDevices.length === 0 && BluetoothService.pairedDevices.length === 0 && BluetoothService.availableDevices.length === 0
                    Layout.fillWidth: true
                    text: "No devices. Tap Scan to search."
                    color: root.theme.textMuted
                    font.pixelSize: 11
                    font.family: root.font
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: BluetoothService.discovering ? "Scanning..." : "Scan"
            font.family: root.font
            enabled: !BluetoothService.discovering
            onClicked: {
                BluetoothService.startDiscovery();
                scanTimeout.restart();
            }
        }
    }
}
