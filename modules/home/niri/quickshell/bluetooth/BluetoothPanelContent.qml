import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme-switcher"
import "../components"

// Pure presentation over BluetoothService — no window, no state of its own.
// Sized to live inside Quick Settings' expandable Bluetooth section: the
// device-list sections sit inside one scrollable, height-capped area instead
// of growing the whole panel taller with every device.
ColumnLayout {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    spacing: 10

    // Discovery is expensive and must never outlive this view. The Quick
    // Settings section is created when expanded and destroyed when collapsed
    // (or the panel closes), so tie the cleanup to that lifecycle rather than
    // to a flag the parent has to remember to flip.
    Component.onDestruction: BluetoothService.stopDiscovery()

    Timer {
        id: scanTimeout
        interval: 30000
        onTriggered: BluetoothService.stopDiscovery()
    }

    // One titled group of devices. (Inline components don't see the outer
    // document's ids, so theme/font are passed in.)
    component DeviceSection: ColumnLayout {
        id: section
        property string title: ""
        property var devices: []
        property var theme
        property string font

        Layout.fillWidth: true
        visible: section.devices.length > 0
        spacing: 4

        Text {
            text: section.title
            color: section.theme.textMuted
            font.pixelSize: 10
            font.family: section.font
        }

        Repeater {
            // ScriptModel diffs by object identity, so a device changing
            // state moves its row between sections instead of every row in
            // every section being destroyed and recreated.
            model: ScriptModel {
                values: section.devices
            }
            delegate: BluetoothDeviceRow {
                required property var modelData
                Layout.fillWidth: true
                theme: section.theme
                font: section.font
                device: modelData
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ToggleSwitch {
            visible: BluetoothService.available
            theme: root.theme
            checked: BluetoothService.powered
            onToggled: BluetoothService.togglePower()
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

                DeviceSection {
                    title: "Connected"
                    devices: BluetoothService.connectedDevices
                    theme: root.theme
                    font: root.font
                }

                DeviceSection {
                    title: "Paired"
                    devices: BluetoothService.pairedDevices
                    theme: root.theme
                    font: root.font
                }

                DeviceSection {
                    title: "Available"
                    devices: BluetoothService.availableDevices
                    theme: root.theme
                    font: root.font
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
