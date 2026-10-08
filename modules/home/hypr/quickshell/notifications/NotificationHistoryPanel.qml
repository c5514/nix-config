import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../theme-switcher"

ColumnLayout {
    id: root

    property var theme: Theme
    property string font: "JetBrainsMono NF"

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: "Notifications"
            color: root.theme.textPrimary
            font.pixelSize: 16
            font.bold: true
            font.family: root.font
            Layout.fillWidth: true
        }

        Text {
            visible: NotificationService.history.length > 0
            text: "Clear"
            color: root.theme.accentCyan
            font.pixelSize: 11
            font.family: root.font

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor

                onClicked: NotificationService.clearHistory()
            }
        }
    }

    // List / empty state area
    Item {
        id: contentArea

        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: historyList

            anchors.fill: parent

            clip: true
            spacing: 6
            model: NotificationService.history

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 5

                contentItem: Rectangle {
                    radius: 2.5
                    color: root.theme.bgHover
                }

                background: Item {}
            }

            delegate: Rectangle {
                id: entryRow

                required property var modelData

                width: historyList.width - 8
                height: entryContent.implicitHeight + 16

                radius: 8
                color: root.theme.bgSurface
                border.color: root.theme.bgBorder
                border.width: 2

                ColumnLayout {
                    id: entryContent

                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: entryRow.modelData.appName || "Notification"

                            color: root.theme.textMuted
                            font.pixelSize: 10
                            font.family: root.font

                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: Qt.formatDateTime(new Date(entryRow.modelData.timestamp), "hh:mm")

                            color: root.theme.textMuted
                            font.pixelSize: 9
                            font.family: root.font
                        }

                        Text {
                            text: "\u00d7"

                            color: root.theme.textMuted
                            font.pixelSize: 12
                            font.family: root.font

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor

                                onClicked: NotificationService.removeHistoryEntry(entryRow.modelData.id)
                            }
                        }
                    }

                    Text {
                        visible: entryRow.modelData.summary.length > 0
                        text: entryRow.modelData.summary

                        color: root.theme.textPrimary
                        font.pixelSize: 12
                        font.bold: true
                        font.family: root.font

                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: entryRow.modelData.body.length > 0
                        text: entryRow.modelData.body

                        color: root.theme.textSecondary
                        font.pixelSize: 11
                        font.family: root.font

                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true

                        textFormat: Text.PlainText
                    }
                }
            }
        }

        // Empty state is centered in the entire notification content area.
        Text {
            anchors.centerIn: parent

            visible: NotificationService.history.length === 0

            text: "No notifications yet."

            color: root.theme.textMuted
            font.pixelSize: 12
            font.family: root.font

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
