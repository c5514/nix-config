import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../theme-switcher"
import "../brightness"

Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"

    property bool showVolume: false
    property bool showBrightness: false
    property real volumeValue: 0
    property bool volumeMuted: false
    property real brightnessValue: 0

    // PipeWire tracking
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.defaultAudioSink?.audio ?? null

        function onVolumeChanged() {
            root.volumeValue = Pipewire.defaultAudioSink.audio.volume;
            root.showVolume = true;
            volumeHideTimer.restart();
        }

        function onMutedChanged() {
            root.volumeMuted = Pipewire.defaultAudioSink.audio.muted;
            root.showVolume = true;
            volumeHideTimer.restart();
        }
    }

    Timer {
        id: volumeHideTimer
        interval: 750
        onTriggered: root.showVolume = false
    }

    // Brightness monitoring — discovery/file-watch/read now live in the
    // shared BrightnessService (also used by Quick Settings' brightness
    // slider); OSD just listens and decides when to show itself.
    Connections {
        target: BrightnessService

        function onValueChanged() {
            root.brightnessValue = BrightnessService.value;
            if (BrightnessService.ready) {
                root.showBrightness = true;
                brightnessHideTimer.restart();
            }
        }
    }

    Timer {
        id: brightnessHideTimer
        interval: 750
        onTriggered: root.showBrightness = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            visible: root.showVolume || root.showBrightness
            focusable: false
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-osd"

            exclusionMode: ExclusionMode.Ignore
            mask: Region {}

            anchors.bottom: true

            implicitWidth: 250
            implicitHeight: 70
            margins.bottom: screen.height / 10

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.theme.bgBase
                border.color: root.theme.bgSurface
                RowLayout {
                    opacity: root.showBrightness ? 1 : 0
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 15
                    spacing: 10
                    Text {
                        text: {
                            let bright = root.brightnessValue ?? 0;
                            if (bright < 0.33)
                                return "󰃞";
                            if (bright < 0.66)
                                return "󰃟";
                            return "󰃠";
                        }
                        color: root.theme.accentPrimary
                        font.pixelSize: 35
                        font.family: root.font
                        Layout.alignment: Qt.AlignHCenter
                        style: Text.Raised// or Text.Sunken / Text.Raised depending on taste
                        styleColor: "#80000000"
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 10
                        radius: 30
                        color: root.theme.bgSurface
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(0, parent.width * Math.max(0, Math.min(1, root.brightnessValue)))
                            radius: parent.radius
                            color: root.theme.accentPrimary
                            Behavior on width {
                                NumberAnimation {
                                    duration: 50
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    opacity: root.showVolume ? 1 : 0
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 15
                    spacing: 10
                    // IconImage {
                    //     implicitSize: 30
                    //     source: {
                    //         let audio = root.volumeValue;
                    //         if (!audio)
                    //             return "";
                    //         if (root.volumeMuted)
                    //             return Quickshell.iconPath("audio-volume-muted");
                    //         let vol = root.volumeValue ?? 0;
                    //         if (vol < 0.5)
                    //             return Quickshell.iconPath("audio-volume-low");
                    //         return Quickshell.iconPath("audio-volume-high");
                    //     }
                    // }
                    Text {
                        text: {
                            if (root.volumeMuted || root.volumeValue <= 0)
                                return "󰖁";
                            if (root.volumeValue < 0.33)
                                return "󰕿";
                            if (root.volumeValue < 0.66)
                                return "󰖀";
                            return "󰕾";
                        }
                        color: root.volumeMuted ? root.theme.textMuted : root.theme.accentPrimary
                        font.pixelSize: 37
                        font.family: root.font
                        Layout.alignment: Qt.AlignHCenter
                        style: Text.Raised
                        styleColor: "#80000000"
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 10
                        radius: 20
                        color: root.theme.bgSurface
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: {
                                let audio = root.volumeValue;
                                if (!audio)
                                    return 0;
                                let vol = root.volumeMuted ? 0 : (root.volumeValue ?? 0);
                                return parent.width * vol;
                            }
                            radius: parent.radius
                            color: root.theme.accentPrimary
                            Behavior on width {
                                NumberAnimation {
                                    duration: 50
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
