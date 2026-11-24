import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "../theme-switcher"

Rectangle {
    id: root
    property var theme: Theme
    property bool active: false
    implicitWidth: 32
    implicitHeight: 24
    radius: 12
    color: root.active ? root.theme.accentPrimary : (mouseArea.containsMouse ? root.theme.bgHover : root.theme.bgSurface)
    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }
    Process {
        id: toggleProc
        command: ["qs", "ipc", "call", "quickSettings", "toggle"]
    }
    IconImage {
        anchors.centerIn: parent
        implicitSize: 16
        source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/icons/nixos.svg"
    }
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleProc.running = true
    }
}
