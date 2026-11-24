import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../audio"

Rectangle {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    readonly property bool available: AudioInputService.hasDefaultInput
    readonly property bool muted: AudioInputService.defaultMuted
    implicitHeight: 60
    radius: 12
    color: root.theme.bgSurface

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        Text {
            text: root.muted ? "\uf131" : "\uf130"
            color: !root.available ? root.theme.textMuted : (root.muted ? root.theme.accentRed : root.theme.accentPrimary)
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
                text: "Microphone"
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.font
            }
            Text {
                Layout.fillWidth: true
                text: !root.available ? "No microphone" : (root.muted ? "Muted" : "On")
                color: root.theme.textMuted
                font.pixelSize: 10
                font.family: root.font
                elide: Text.ElideRight
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.available
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: AudioInputService.toggleDefaultMuted()
    }
}
