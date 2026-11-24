import QtQuick
import "../theme-switcher"

Row {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property string key: ""
    property string label: ""
    spacing: 4
    Rectangle {
        width: keyText.implicitWidth + 8
        height: 18
        radius: 4
        color: root.theme.bgSurface
        Text {
            id: keyText
            anchors.centerIn: parent
            text: root.key
            color: root.theme.textMuted
            font.pixelSize: 10
            font.family: root.font
        }
    }
    Text {
        text: root.label
        visible: root.label !== ""
        color: root.theme.textMuted
        font.pixelSize: 10
        font.family: root.font
        anchors.verticalCenter: parent.verticalCenter
    }
}
