import Quickshell
import Quickshell.Wayland
import QtQuick

Scope {
    id: root
    readonly property color textColor: "#ffffff"
    readonly property color subTextColor: "#d9ffffff"
    readonly property color shadowColor: "#802b2b2b"
    readonly property color panelColor: "#662b2b2b"
    readonly property int marginLeft: 64
    readonly property int marginTop: 64
    readonly property int panelPadding: 22

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property string timeString: Qt.formatDateTime(clock.date, "hh:mm")
    readonly property string dateString: Qt.formatDateTime(clock.date, "dddd \u00b7 d MMMM yyyy")
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: clockWindow
            BackgroundEffect.blurRegion: Region {
                item: panel
                radius: panel.radius
            }
            required property var modelData
            screen: modelData
            visible: true
            focusable: false
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-desktop-clock"
            exclusionMode: ExclusionMode.Ignore
            mask: Region {}
            anchors {
                top: true
                left: true
            }
            implicitWidth: root.marginLeft + panel.implicitWidth
            implicitHeight: root.marginTop + panel.implicitHeight
            Rectangle {
                id: panel
                x: root.marginLeft
                y: root.marginTop
                implicitWidth: clockColumn.implicitWidth + root.panelPadding * 2
                implicitHeight: clockColumn.implicitHeight + root.panelPadding * 2
                radius: 20
                color: root.panelColor
                Column {
                    id: clockColumn
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        text: root.timeString
                        color: root.textColor
                        font.pixelSize: 76
                        font.weight: Font.Normal
                        font.letterSpacing: 1
                        style: Text.Raised
                        styleColor: root.shadowColor
                    }
                    Text {
                        text: root.dateString
                        color: root.subTextColor
                        font.pixelSize: 18
                        font.weight: Font.Light
                        font.letterSpacing: 0.5
                        style: Text.Raised
                        styleColor: root.shadowColor
                    }
                }
            }
        }
    }
}
