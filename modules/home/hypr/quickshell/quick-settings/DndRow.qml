import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../notifications"

// Toggle tile for Do Not Disturb. State lives in NotificationService
// (the same flag the `notifications dnd_toggle` IPC call flips), so this
// tile stays in sync with it. Styled to match DisplayRow/BatteryRow.
Rectangle {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    readonly property bool active: NotificationService.doNotDisturb

    implicitHeight: 70
    radius: 12
    color: root.theme.bgSurface

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 2

        Text {
            text: root.active ? "\uf1f6" : "\uf0f3"
            color: root.active ? root.theme.accentPrimary : root.theme.textMuted
            font.pixelSize: 18
            font.family: root.font
            style: Text.Raised
            styleColor: "#80000000"
        }

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

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
    }
}
