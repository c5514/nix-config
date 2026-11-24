import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme-switcher"
import "../notifications"

Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property int barHeight: 30
    property bool open: false
    IpcHandler {
        target: "calendar"
        function toggle(): void {
            root.open = !root.open;
        }
    }
    property date currentDate: new Date()
    property date selectedDate: new Date()
    function daysInMonth(date) {
        return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
    }
    function firstDayOfMonth(date) {
        return new Date(date.getFullYear(), date.getMonth(), 1).getDay();
    }
    function previousMonth() {
        currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1);
    }
    function nextMonth() {
        currentDate = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1);
    }
    function isToday(date) {
        const today = new Date();

        return date.getFullYear() === today.getFullYear() && date.getMonth() === today.getMonth() && date.getDate() === today.getDate();
    }
    function isSelected(date) {
        return date.getFullYear() === selectedDate.getFullYear() && date.getMonth() === selectedDate.getMonth() && date.getDate() === selectedDate.getDate();
    }
    LazyLoader {
        active: root.open
        PanelWindow {
            id: calendarPanel
            BackgroundEffect.blurRegion: Region {
                item: calendarBox
                radius: 16
            }
            Component.onCompleted: {
                root.currentDate = new Date();
                root.selectedDate = new Date();
                calendarBox.forceActiveFocus();
                NotificationService.markAllRead();
            }
            focusable: true
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-calendar"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false
                // Rectangle {
                //     anchors.fill: parent
                //     color: root.theme.bgOverlay
                // }
            }
            Rectangle {
                id: calendarBox
                anchors {
                    top: parent.top
                    topMargin: root.barHeight + 8
                    horizontalCenter: parent.horizontalCenter
                }
                width: 596
                height: 330
                radius: 16
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                RowLayout {
                    id: outerRow
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 16
                    // Calendar
                    Rectangle {
                        id: calendarCard
                        Layout.preferredWidth: 288
                        Layout.minimumWidth: 0
                        Layout.maximumWidth: 288
                        Layout.fillHeight: true
                        radius: 12
                        color: "transparent"
                        border.color: "transparent"
                        border.width: 0
                        ColumnLayout {
                            id: calendarLayout
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: {
                                        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
                                        return months[currentDate.getMonth()] + " " + currentDate.getFullYear();
                                    }
                                    color: root.theme.textPrimary
                                    font.pixelSize: 16
                                    font.family: root.font
                                    font.bold: true
                                    Layout.fillWidth: true
                                }
                                Row {
                                    spacing: 3
                                    Button {
                                        width: 24
                                        height: 24
                                        background: Rectangle {
                                            radius: 6
                                            color: parent.hovered ? root.theme.bgHover : "transparent"
                                        }
                                        contentItem: Text {
                                            text: ""
                                            color: root.theme.textPrimary
                                            font.pixelSize: 14
                                            font.family: root.font
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: previousMonth()
                                    }
                                    Button {
                                        width: 24
                                        height: 24
                                        background: Rectangle {
                                            radius: 6
                                            color: parent.hovered ? root.theme.bgHover : "transparent"
                                        }
                                        contentItem: Text {
                                            text: ""
                                            color: root.theme.textPrimary
                                            font.pixelSize: 14
                                            font.family: root.font
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: nextMonth()
                                    }
                                }
                            }
                            // Day-of-week headers
                            GridLayout {
                                id: weekdayGrid
                                Layout.fillWidth: true
                                columns: 7
                                columnSpacing: 3
                                rowSpacing: 3
                                Repeater {
                                    model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                                    Text {
                                        text: modelData
                                        color: root.theme.textMuted
                                        font.pixelSize: 11
                                        font.family: root.font
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                            // Calendar days
                            Grid {
                                id: dayGrid
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 7
                                columnSpacing: 3
                                rowSpacing: 3
                                readonly property real cellWidth: (width - columnSpacing * 6) / 7
                                Repeater {
                                    id: dayRepeater
                                    model: {
                                        const first = firstDayOfMonth(currentDate);
                                        const total = daysInMonth(currentDate);
                                        const offset = first === 0 ? 6 : first - 1;
                                        return offset + total;
                                    }
                                    delegate: Rectangle {
                                        required property int index
                                        width: dayGrid.cellWidth
                                        height: dayGrid.cellWidth
                                        radius: 8
                                        property int calendarOffset: firstDayOfMonth(currentDate) === 0 ? 6 : firstDayOfMonth(currentDate) - 1
                                        property int dayNumber: index - calendarOffset + 1
                                        property bool validDay: dayNumber >= 1 && dayNumber <= daysInMonth(currentDate)
                                        property date cellDate: new Date(currentDate.getFullYear(), currentDate.getMonth(), dayNumber)
                                        color: {
                                            if (!validDay)
                                                return "transparent";
                                            if (isSelected(cellDate))
                                                return root.theme.accentPrimary;
                                            if (isToday(cellDate))
                                                return root.theme.bgSelected;
                                            return "transparent";
                                        }
                                        border.color: validDay && isToday(cellDate) ? root.theme.accentPrimary : "transparent"
                                        border.width: 2
                                        Text {
                                            anchors.centerIn: parent
                                            text: validDay ? dayNumber : ""
                                            color: {
                                                if (!validDay)
                                                    return root.theme.textMuted;
                                                if (isSelected(cellDate))
                                                    return root.theme.textOnAccent;
                                                return root.theme.textPrimary;
                                            }
                                            font.pixelSize: 13
                                            font.family: root.font
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (validDay) {
                                                    selectedDate = new Date(currentDate.getFullYear(), currentDate.getMonth(), dayNumber);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // Notifications
                    Rectangle {
                        id: notificationCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: root.theme.bgSurface
                        border.color: root.theme.bgBorder
                        border.width: 1
                        NotificationHistoryPanel {
                            anchors.fill: parent
                            anchors.margins: 12
                            theme: root.theme
                            font: root.font
                        }
                    }
                }
                Keys.onEscapePressed: root.open = false
                focus: true
            }
        }
    }
}
