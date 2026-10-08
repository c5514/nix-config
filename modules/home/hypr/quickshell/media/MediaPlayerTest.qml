import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../theme-switcher"

// Throwaway verification harness for MediaPlayer.qml — not the Quick
// Settings panel, just enough to see the widget render and respond to
// real MPD/MPRIS activity before it gets embedded anywhere.
Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    IpcHandler {
        target: "media-player"
        function toggle(): void {
            testPanel.visible = !testPanel.visible;
        }
    }

    PanelWindow {
        id: testPanel
        visible: false
        focusable: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-media-player-test"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: testPanel.visible = false

            // Rectangle {
            //     anchors.fill: parent
            //     color: root.theme.bgOverlay
            // }
        }

        Rectangle {
            anchors.centerIn: parent
            width: mediaPlayer.implicitWidth + 32
            height: mediaPlayer.implicitHeight + 32
            radius: 16
            color: root.theme.bgBase
            border.color: root.theme.bgBorder
            border.width: 1
            focus: true

            Keys.onEscapePressed: testPanel.visible = false

            MouseArea {
                anchors.fill: parent
                onClicked: event => event.accepted = true
            }

            MediaPlayer {
                id: mediaPlayer
                anchors.centerIn: parent
                theme: root.theme
                font: root.font
            }
        }
    }
}
