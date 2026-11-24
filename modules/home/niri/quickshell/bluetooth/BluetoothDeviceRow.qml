import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One Bluetooth device row. Action shown depends on the device's actual
// state (never optimistically — this just reflects whatever
// BluetoothService/BlueZ currently reports), per the "must react to real
// state, not assume the command succeeded" requirement.
RowLayout {
    id: root

    property var theme
    property string font: "JetBrainsMono NF"
    property var device

    spacing: 8
    height: 32

    IconImage {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 18
        source: root.device && root.device.icon ? Quickshell.iconPath(root.device.icon, true) : ""
    }

    Text {
        Layout.fillWidth: true
        text: root.device ? BluetoothService.displayName(root.device) : ""
        color: root.theme.textPrimary
        font.pixelSize: 12
        font.family: root.font
        elide: Text.ElideRight
    }

    Text {
        visible: root.device && root.device.batteryAvailable === true
        text: root.device ? Math.round(root.device.battery * 100) + "%" : ""
        color: root.theme.textMuted
        font.pixelSize: 10
        font.family: root.font
    }

    // Transitional states — reflect exactly what BlueZ reports, no
    // optimistic UI.
    Text {
        visible: root.device && (BluetoothService.isConnecting(root.device) || BluetoothService.isDisconnecting(root.device))
        text: root.device && BluetoothService.isConnecting(root.device) ? "Connecting…" : "Disconnecting…"
        color: root.theme.textMuted
        font.pixelSize: 11
        font.family: root.font
    }

    RowLayout {
        visible: root.device && root.device.pairing === true
        spacing: 4

        Text {
            text: "Pairing…"
            color: root.theme.textMuted
            font.pixelSize: 11
            font.family: root.font
        }

        Text {
            text: "Cancel"
            color: root.theme.accentRed
            font.pixelSize: 10
            font.family: root.font
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.cancelPair(root.device)
            }
        }
    }

    RowLayout {
        visible: root.device && !root.device.pairing && !BluetoothService.isConnecting(root.device) && !BluetoothService.isDisconnecting(root.device)
        spacing: 6

        Button {
            visible: root.device && root.device.connected === true
            text: "Disconnect"
            font.family: root.font
            font.pixelSize: 10
            onClicked: BluetoothService.disconnectDevice(root.device)
        }

        Button {
            visible: root.device && root.device.paired === true && root.device.connected !== true
            text: "Connect"
            font.family: root.font
            font.pixelSize: 10
            onClicked: BluetoothService.connectDevice(root.device)
        }

        Button {
            visible: root.device && root.device.paired !== true
            text: "Pair"
            font.family: root.font
            font.pixelSize: 10
            onClicked: BluetoothService.pairDevice(root.device)
        }

        // Forget — available for anything already paired, connected or not.
        Text {
            visible: root.device && root.device.paired === true
            text: "\uf1f8" // trash
            color: root.theme.textMuted
            font.pixelSize: 12
            font.family: root.font

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: BluetoothService.removeDevice(root.device)
            }
        }
    }
}
