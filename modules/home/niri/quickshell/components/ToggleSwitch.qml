import QtQuick
import "../theme-switcher"

Rectangle {
    id: root
    property var theme: Theme
    property bool checked: false
    signal toggled
    implicitWidth: 40
    implicitHeight: 20
    radius: 10
    color: root.checked ? root.theme.accentPrimary : root.theme.bgHover
    Rectangle {
        width: 14
        height: 14
        radius: 7
        color: root.theme.textPrimary
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
