import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme-switcher"
import "../components"

// Throwaway verification UI for the audio services (input/output devices +
// app playback streams). Not the Quick Settings panel — just enough to
// confirm each service actually works before it gets wired into anything
// bigger.
Scope {
    id: root
    property var theme: Theme
    property string font: "JetBrainsMono NF"
    property bool open: false

    IpcHandler {
        target: "audio-input"
        function toggle(): void {
            root.open = !root.open;
        }
    }

    // Created on open, destroyed on close: a closed panel keeps no window,
    // scene graph or item tree alive.
    LazyLoader {
        active: root.open

        PanelWindow {

            // Blur only the visible panel (niri ext-background-effect), not the whole layer.

            BackgroundEffect.blurRegion: Region { item: box; radius: 16 }
            id: testPanel
            focusable: true
            color: "transparent"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "quickshell-audio-input-test"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            property string currentTab: "playback"
            property bool showDebug: false

            MouseArea {
                anchors.fill: parent
                onClicked: root.open = false

                // Rectangle {
                //     anchors.fill: parent
                //     color: root.theme.bgOverlay
                // }
            }

            Rectangle {
                id: box
                anchors.centerIn: parent
                width: 420
                height: Math.min(mainColumn.implicitHeight + 32, 680)
                radius: 16
                color: root.theme.bgBase
                border.color: root.theme.bgBorder
                border.width: 1
                focus: true

                Keys.onEscapePressed: root.open = false

                MouseArea {
                    anchors.fill: parent
                    onClicked: event => event.accepted = true
                }

                ColumnLayout {
                    id: mainColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Text {
                        text: "Audio"
                        color: root.theme.textPrimary
                        font {
                            pixelSize: 15
                            bold: true
                            family: root.font
                        }
                    }

                    // ---- Tab switcher --------------------------------------

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: [
                                {
                                    key: "input",
                                    label: "Input"
                                },
                                {
                                    key: "output",
                                    label: "Output"
                                },
                                {
                                    key: "playback",
                                    label: "Playback"
                                }
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 30
                                radius: 8
                                color: testPanel.currentTab === modelData.key ? root.theme.accentPrimary : root.theme.bgSurface

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: testPanel.currentTab === modelData.key ? root.theme.textOnAccent : root.theme.textPrimary
                                    font.pixelSize: 12
                                    font.bold: testPanel.currentTab === modelData.key
                                    font.family: root.font
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: testPanel.currentTab = modelData.key
                                }
                            }
                        }
                    }

                    // ---- Input tab ------------------------------------------

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: testPanel.currentTab === "input"

                        Rectangle {
                            Layout.fillWidth: true
                            height: inDefaultColumn.implicitHeight + 20
                            radius: 10
                            color: root.theme.bgSurface
                            border.color: root.theme.bgBorder
                            border.width: 1

                            ColumnLayout {
                                id: inDefaultColumn
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: AudioInputService.hasDefaultInput ? "\uf130" : "\uf131"
                                        color: AudioInputService.defaultMuted ? root.theme.accentRed : root.theme.accentPrimary
                                        font.pixelSize: 16
                                        font.family: root.font
                                    }

                                    Text {
                                        text: AudioInputService.defaultName
                                        color: root.theme.textPrimary
                                        font.pixelSize: 13
                                        font.family: root.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: AudioInputService.hasDefaultInput
                                        text: Math.round(AudioInputService.defaultVolume * 100) + "%"
                                        color: root.theme.textMuted
                                        font.pixelSize: 12
                                        font.family: root.font
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    enabled: AudioInputService.hasDefaultInput

                                    Slider {
                                        id: inVolSlider
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 1
                                        enabled: AudioInputService.hasDefaultInput

                                        trackColor: root.theme.bgHover
                                        fillColor: root.theme.accentPrimary
                                        handleColor: root.theme.textPrimary

                                        // No continuous `value:` binding — dragging would
                                        // sever it. Seed once, resync only while not pressed.
                                        Component.onCompleted: value = AudioInputService.defaultVolume
                                        Connections {
                                            target: AudioInputService
                                            function onDefaultVolumeChanged() {
                                                if (!inVolSlider.pressed)
                                                    inVolSlider.value = AudioInputService.defaultVolume;
                                            }
                                        }

                                        onMoved: AudioInputService.setDefaultVolume(value)
                                    }

                                    Button {
                                        text: AudioInputService.defaultMuted ? "Unmute" : "Mute"
                                        font.family: root.font
                                        enabled: AudioInputService.hasDefaultInput
                                        onClicked: AudioInputService.toggleDefaultMuted()
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Available inputs (" + AudioInputService.inputs.length + ")"
                            color: root.theme.textMuted
                            font.pixelSize: 11
                            font.family: root.font
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 220)
                            clip: true
                            spacing: 4
                            model: AudioInputService.inputs

                            delegate: Rectangle {
                                id: inputRow
                                required property var modelData
                                width: ListView.view.width
                                height: 40
                                radius: 8
                                color: AudioInputService.isDefault(modelData) ? root.theme.bgSelected : (inputRowArea.containsMouse ? root.theme.bgHover : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: inputRow.modelData.audio.muted ? "\uf131" : "\uf130"
                                        color: inputRow.modelData.audio.muted ? root.theme.accentRed : root.theme.textSecondary
                                        font.pixelSize: 13
                                        font.family: root.font
                                    }

                                    Text {
                                        text: AudioInputService.displayName(inputRow.modelData)
                                        color: root.theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: root.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: Math.round(inputRow.modelData.audio.volume * 100) + "%"
                                        color: root.theme.textMuted
                                        font.pixelSize: 11
                                        font.family: root.font
                                    }

                                    Text {
                                        visible: AudioInputService.isDefault(inputRow.modelData)
                                        text: "\u2713"
                                        color: root.theme.accentPrimary
                                        font.pixelSize: 12
                                        font.family: root.font
                                    }
                                }

                                MouseArea {
                                    id: inputRowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AudioInputService.setDefaultInput(inputRow.modelData)
                                }
                            }
                        }

                        Text {
                            visible: AudioInputService.inputs.length === 0
                            text: "No input devices found."
                            color: root.theme.textMuted
                            font.pixelSize: 12
                            font.family: root.font
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // ---- Output tab -----------------------------------------

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        visible: testPanel.currentTab === "output"

                        Rectangle {
                            Layout.fillWidth: true
                            height: outDefaultColumn.implicitHeight + 20
                            radius: 10
                            color: root.theme.bgSurface
                            border.color: root.theme.bgBorder
                            border.width: 1

                            ColumnLayout {
                                id: outDefaultColumn
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: AudioOutputService.hasDefaultOutput ? "\uf028" : "\uf026"
                                        color: AudioOutputService.defaultMuted ? root.theme.accentRed : root.theme.accentPrimary
                                        font.pixelSize: 16
                                        font.family: root.font
                                    }

                                    Text {
                                        text: AudioOutputService.defaultName
                                        color: root.theme.textPrimary
                                        font.pixelSize: 13
                                        font.family: root.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: AudioOutputService.hasDefaultOutput
                                        text: Math.round(AudioOutputService.defaultVolume * 100) + "%"
                                        color: root.theme.textMuted
                                        font.pixelSize: 12
                                        font.family: root.font
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8
                                    enabled: AudioOutputService.hasDefaultOutput

                                    Slider {
                                        id: outVolSlider
                                        Layout.fillWidth: true
                                        from: 0
                                        to: 1
                                        enabled: AudioOutputService.hasDefaultOutput

                                        trackColor: root.theme.bgHover
                                        fillColor: root.theme.accentPrimary
                                        handleColor: root.theme.textPrimary

                                        Component.onCompleted: value = AudioOutputService.defaultVolume
                                        Connections {
                                            target: AudioOutputService
                                            function onDefaultVolumeChanged() {
                                                if (!outVolSlider.pressed)
                                                    outVolSlider.value = AudioOutputService.defaultVolume;
                                            }
                                        }

                                        onMoved: AudioOutputService.setDefaultVolume(value)
                                    }

                                    Button {
                                        text: AudioOutputService.defaultMuted ? "Unmute" : "Mute"
                                        font.family: root.font
                                        enabled: AudioOutputService.hasDefaultOutput
                                        onClicked: AudioOutputService.toggleDefaultMuted()
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Available outputs (" + AudioOutputService.outputs.length + ")"
                            color: root.theme.textMuted
                            font.pixelSize: 11
                            font.family: root.font
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 220)
                            clip: true
                            spacing: 4
                            model: AudioOutputService.outputs

                            delegate: Rectangle {
                                id: outputRow
                                required property var modelData
                                width: ListView.view.width
                                height: 40
                                radius: 8
                                color: AudioOutputService.isDefault(modelData) ? root.theme.bgSelected : (outputRowArea.containsMouse ? root.theme.bgHover : "transparent")

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: outputRow.modelData.audio.muted ? "\uf026" : "\uf028"
                                        color: outputRow.modelData.audio.muted ? root.theme.accentRed : root.theme.textSecondary
                                        font.pixelSize: 13
                                        font.family: root.font
                                    }

                                    Text {
                                        text: AudioOutputService.displayName(outputRow.modelData)
                                        color: root.theme.textPrimary
                                        font.pixelSize: 12
                                        font.family: root.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: Math.round(outputRow.modelData.audio.volume * 100) + "%"
                                        color: root.theme.textMuted
                                        font.pixelSize: 11
                                        font.family: root.font
                                    }

                                    Text {
                                        visible: AudioOutputService.isDefault(outputRow.modelData)
                                        text: "\u2713"
                                        color: root.theme.accentPrimary
                                        font.pixelSize: 12
                                        font.family: root.font
                                    }
                                }

                                MouseArea {
                                    id: outputRowArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: AudioOutputService.setDefaultOutput(outputRow.modelData)
                                }
                            }
                        }

                        Text {
                            visible: AudioOutputService.outputs.length === 0
                            text: "No output devices found."
                            color: root.theme.textMuted
                            font.pixelSize: 12
                            font.family: root.font
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // ---- Playback tab ---------------------------------------

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: testPanel.currentTab === "playback"

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "Applications (" + AudioStreamService.streams.length + ")"
                                color: root.theme.textMuted
                                font.pixelSize: 11
                                font.family: root.font
                                Layout.fillWidth: true
                            }
                            Text {
                                text: testPanel.showDebug ? "Hide raw nodes" : "Debug: show raw nodes"
                                color: root.theme.accentCyan
                                font.pixelSize: 10
                                font.family: root.font
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: testPanel.showDebug = !testPanel.showDebug
                                }
                            }
                        }

                        ListView {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 260)
                            clip: true
                            spacing: 6
                            model: AudioStreamService.streams

                            delegate: Rectangle {
                                id: streamRow
                                required property var modelData
                                width: ListView.view.width
                                height: streamContent.implicitHeight + 16
                                radius: 8
                                color: root.theme.bgSurface
                                border.color: root.theme.bgBorder
                                border.width: 1

                                ColumnLayout {
                                    id: streamContent
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: AudioStreamService.appName(streamRow.modelData)
                                            color: root.theme.textPrimary
                                            font.pixelSize: 12
                                            font.family: root.font
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }

                                        Text {
                                            text: Math.round(streamRow.modelData.audio.volume * 100) + "%"
                                            color: root.theme.textMuted
                                            font.pixelSize: 11
                                            font.family: root.font
                                        }
                                    }

                                    Text {
                                        readonly property string media: AudioStreamService.mediaName(streamRow.modelData)
                                        visible: media.length > 0
                                        text: media
                                        color: root.theme.textMuted
                                        font.pixelSize: 10
                                        font.family: root.font
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Slider {
                                            id: streamSlider
                                            Layout.fillWidth: true
                                            from: 0
                                            to: 1
                                            trackHeight: 5
                                            handleSize: 12

                                            trackColor: root.theme.bgHover
                                            fillColor: root.theme.accentPrimary
                                            handleColor: root.theme.textPrimary

                                            Component.onCompleted: value = streamRow.modelData.audio.volume
                                            Connections {
                                                target: streamRow.modelData.audio
                                                function onVolumeChanged() {
                                                    if (!streamSlider.pressed)
                                                        streamSlider.value = streamRow.modelData.audio.volume;
                                                }
                                            }

                                            onMoved: AudioStreamService.setVolume(streamRow.modelData.id, value)
                                        }

                                        Button {
                                            text: streamRow.modelData.audio.muted ? "Unmute" : "Mute"
                                            font.family: root.font
                                            onClicked: AudioStreamService.toggleMuted(streamRow.modelData.id)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: AudioStreamService.streams.length === 0
                            text: "No apps currently playing audio."
                            color: root.theme.textMuted
                            font.pixelSize: 12
                            font.family: root.font
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // ---- Raw diagnostic: every PipeWire node, unfiltered ----
                        // Shows exactly what Quickshell reports for isStream/isSink/
                        // hasAudio on every node, so a detection gap can be diagnosed
                        // from real data instead of guesswork.
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: testPanel.showDebug
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true
                                height: 1
                                color: root.theme.bgBorder
                            }

                            Text {
                                text: "Raw PipeWire nodes (" + (Pipewire.ready ? Pipewire.nodes.values.length : 0) + ")"
                                color: root.theme.textMuted
                                font.pixelSize: 10
                                font.family: root.font
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(contentHeight, 200)
                                clip: true
                                spacing: 2
                                model: Pipewire.ready ? Pipewire.nodes.values : []

                                delegate: Text {
                                    required property var modelData
                                    width: ListView.view.width
                                    text: (modelData.name || "?") + "  |  stream=" + modelData.isStream + " sink=" + modelData.isSink + " audio=" + (modelData.audio !== null && modelData.audio !== undefined)
                                    color: modelData.isStream ? root.theme.accentCyan : root.theme.textMuted
                                    font.pixelSize: 9
                                    font.family: root.font
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
