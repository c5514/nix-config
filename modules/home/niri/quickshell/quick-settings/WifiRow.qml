import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../bar"
import "../wifi"

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
            text: {
                if (!WifiService.radioEnabled)
                    return "\uf6ab";
                if (SystemInfo.networkType === "ethernet")
                    return "\uf796";
                return "\uf1eb";
            }
            color: WifiService.radioEnabled ? root.theme.accentPrimary : root.theme.textMuted
            font.pixelSize: 20
            font.family: root.font
            style: Text.Raised
            styleColor: "#80000000"
            Layout.alignment: Qt.AlignVCenter
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2
            Text {
                text: "Wi-Fi"
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.font
            }
            Text {
                Layout.fillWidth: true
                text: {
                    if (!WifiService.radioEnabled)
                        return "Off";
                    if (SystemInfo.networkType === "ethernet")
                        return "Ethernet";
                    if (SystemInfo.networkType === "wifi")
                        return SystemInfo.networkInfo;
                    return "Not connected";
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
        onClicked: root.expanded = !root.expanded
    }
}
