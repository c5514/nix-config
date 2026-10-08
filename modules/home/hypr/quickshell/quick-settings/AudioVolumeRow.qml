import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../theme-switcher"
import "../audio"
import "../components"

// Deliberately minimal: default OUTPUT volume only. No inputs, no
// per-app streams, no device list — that's what the gear button is for,
// which opens the existing detailed Audio widget (audio/AudioInputTest.qml)
// via its own IPC handler rather than rebuilding any of that here.
RowLayout {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    spacing: 8

    Process {
        id: openAudioWidget
        command: ["qs", "ipc", "call", "audio-input", "toggle"]
    }

    Text {
        text: AudioOutputService.defaultMuted ? "\uf026" : "\uf028"
        color: AudioOutputService.defaultMuted ? root.theme.textMuted : root.theme.accentPrimary
        font.pixelSize: 16
        font.family: root.font
        style: Text.Raised
        styleColor: "#80000000"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            enabled: AudioOutputService.hasDefaultOutput
            onClicked: AudioOutputService.toggleDefaultMuted()
        }
    }

    Slider {
        id: volumeSlider
        Layout.fillWidth: true
        from: 0
        to: 1
        enabled: AudioOutputService.hasDefaultOutput

        trackColor: root.theme.bgHover
        fillColor: root.theme.accentPrimary
        handleColor: root.theme.textPrimary

        // Same "don't bind value: continuously" pattern used everywhere
        // else in this config — seed once, resync only while not pressed.
        Component.onCompleted: value = AudioOutputService.defaultVolume
        Connections {
            target: AudioOutputService
            function onDefaultVolumeChanged() {
                if (!volumeSlider.pressed)
                    volumeSlider.value = AudioOutputService.defaultVolume;
            }
        }
        onMoved: AudioOutputService.setDefaultVolume(value)
    }

    Text {
        text: AudioOutputService.hasDefaultOutput ? Math.round(AudioOutputService.defaultVolume * 100) + "%" : "--"
        color: root.theme.textMuted
        font.pixelSize: 11
        font.family: root.font
        Layout.preferredWidth: 32
    }

    // Settings button — opens the existing detailed Audio widget. Does
    // NOT duplicate its logic; this is only an entry point.
    Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 6
        color: gearArea.containsMouse ? root.theme.bgHover : "transparent"

        Text {
            anchors.centerIn: parent
            text: "\uf013"
            color: root.theme.textSecondary
            font.pixelSize: 13
            font.family: root.font
        }

        MouseArea {
            id: gearArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: openAudioWidget.running = true
        }
    }
}
