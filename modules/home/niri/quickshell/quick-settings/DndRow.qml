import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../notifications"

Rectangle {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    readonly property bool active: NotificationService.doNotDisturb
    implicitHeight: 60
    radius: 12
    color: root.theme.bgSurface

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Text {
            text: root.active ? "\uf1f6" : "\uf0f3"
            color: root.active ? root.theme.accentPrimary : root.theme.textMuted
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
                text: "Do Not Disturb"
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.font
            }
            Text {
                Layout.fillWidth: true
                text: root.active ? "On" : "Off"
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
        onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
    }
}
