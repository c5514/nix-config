import Quickshell
import Quickshell.Wayland
import QtQuick

// A permanent, non-interactive desktop clock pinned to the upper-left
// corner of every screen.
//
// This component is intentionally isolated from the rest of the shell:
// it does not import the theme-switcher module and does not read from
// Theme/Matugen. Its colours and spacing are all scoped to this file.
Scope {
    id: root

    // --- Locally scoped style knobs (independent of Theme/Matugen) ---
    readonly property color textColor: "#ffffff"
    readonly property color subTextColor: "#d9ffffff"
    readonly property color shadowColor: "#802b2b2b"
    readonly property color panelColor: "#662b2b2b"
    readonly property int marginLeft: 64
    readonly property int marginTop: 64
    readonly property int panelPadding: 22

    SystemClock {
        id: clock
        // Minute precision only: no seconds are shown, so there is no
        // reason to wake this component up more often than that.
        precision: SystemClock.Minutes
    }

    readonly property string timeString: Qt.formatDateTime(clock.date, "hh:mm")
    readonly property string dateString: Qt.formatDateTime(clock.date, "dddd \u00b7 d MMMM")

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: clockWindow
            required property var modelData
            screen: modelData

            visible: true
            focusable: false
            color: "transparent"

            // Background layer: stays behind normal application windows
            // on this output and is not part of any single workspace, so
            // it keeps showing through when a workspace is empty.
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-desktop-clock"

            // Purely decorative: never reserve screen space for it.
            exclusionMode: ExclusionMode.Ignore

            // Empty mask == nothing in this window is clickable, so every
            // click/hover passes straight through to whatever is beneath.
            mask: Region {}

            anchors {
                top: true
                left: true
            }

            // The window surface must enclose the panel's own top/left
            // margin, or the panel would be clipped by the surface edge.
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
