import QtQuick
import "../theme-switcher"

// The list of input methods shown in the selector panel. Presentational only:
// it reports clicks and hovers, InputMethodMenu decides what to do with them.
Rectangle {
    id: card

    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property string currentMode: "en"
    property int selectedIndex: 0

    signal chosen(string key)
    signal hovered(int index)

    width: 232
    height: column.implicitHeight + 16
    radius: 12
    color: card.theme.bgBase
    border.color: card.theme.bgBorder
    border.width: 1

    // Swallow clicks on the card so they don't reach the click-catcher.
    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2

        Repeater {
            model: InputMethodService.modes

            Rectangle {
                id: row
                required property var modelData
                required property int index

                readonly property bool current: card.currentMode === modelData.key
                readonly property bool selected: card.selectedIndex === index

                width: column.width
                height: 46
                radius: 8
                color: row.selected ? card.theme.bgSelected : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Accessible.role: Accessible.Button
                Accessible.name: modelData.name + (row.current ? ", active" : "")

                // Short code of the input method
                Rectangle {
                    id: chip
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 8
                    color: row.current ? card.theme.accentPrimary : card.theme.bgSurface

                    Text {
                        anchors.centerIn: parent
                        text: row.modelData.glyph
                        color: row.current ? card.theme.textOnAccent : card.theme.textPrimary
                        font.pixelSize: 15
                        font.bold: true
                        font.family: card.font
                    }
                }

                Column {
                    anchors.left: chip.right
                    anchors.leftMargin: 10
                    anchors.right: tick.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        width: parent.width
                        text: row.modelData.name
                        color: card.theme.textPrimary
                        font.pixelSize: 13
                        font.bold: row.current
                        font.family: card.font
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: row.modelData.detail
                        color: card.theme.textMuted
                        font.pixelSize: 10
                        font.family: card.font
                        elide: Text.ElideRight
                    }
                }

                // Check mark on the active one
                Text {
                    id: tick
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf00c"
                    visible: row.current
                    color: card.theme.accentPrimary
                    font.pixelSize: 13
                    font.family: card.font
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: card.hovered(row.index)
                    onClicked: card.chosen(row.modelData.key)
                }
            }
        }
    }
}
