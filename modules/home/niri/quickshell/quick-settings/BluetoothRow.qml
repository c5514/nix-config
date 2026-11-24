import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../bluetooth"

Rectangle {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property bool expanded: false
    implicitHeight: 60
    radius: 12
    color: root.theme.bgSurface

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Text {
            text: "\uf294"
            color: BluetoothService.available && BluetoothService.powered ? root.theme.accentPrimary : root.theme.textMuted
            font.pixelSize: 18
            font.family: root.font
            style: Text.Raised
            styleColor: "#80000000"
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                text: "Bluetooth"
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.font
            }
            Text {
                Layout.fillWidth: true
                text: {
                    if (!BluetoothService.available)
                        return "Unavailable";
                    if (!BluetoothService.powered)
                        return "Off";
                    const n = BluetoothService.connectedDevices.length;
                    return n > 0 ? n + " connected" : "On";
                }
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
                elide: Text.ElideRight
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: BluetoothService.available
        onClicked: root.expanded = !root.expanded
    }
}
