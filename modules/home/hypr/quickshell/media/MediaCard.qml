import QtQuick
import QtQuick.Layouts
import "../components"

// Pure presentation for a single media source. Takes normalized values in,
// emits request* signals out — no service/protocol knowledge of its own,
// so it works identically whether it's backed by MPRIS or MPD.
Rectangle {
    id: root

    property var theme
    property string font: "JetBrainsMono NF"

    property string title: ""
    property string artist: ""
    property string sourceLabel: ""
    property string artUrl: ""
    property bool isPlaying: false
    property bool canPrevious: true
    property bool canNext: true
    property bool canSeek: false
    property real positionSeconds: 0
    property real durationSeconds: 0

    signal requestPlayPause
    signal requestNext
    signal requestPrevious
    signal requestSeek(real seconds)

    implicitHeight: content.implicitHeight + 20
    radius: 10
    color: theme.bgSurface
    border.color: theme.bgBorder
    border.width: 1

    function _formatTime(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        const m = Math.floor(s / 60);
        const r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    // MPRIS metadata for position/duration support can flicker false for a
    // beat right after a seek (many web pages only re-assert it around
    // their own play/pause Media Session handlers, which is also why
    // toggling play/pause "fixes" a stuck-hidden slider). Rather than
    // collapse the scrubber the instant one read comes back unsupported,
    // remember the last known-good duration and keep showing it through a
    // brief flicker. A genuinely new/different track resets this so a
    // track that legitimately has no duration still correctly shows no
    // scrubber.
    property real _lastKnownDuration: 0
    property bool _lastKnownCanSeek: false
    onTitleChanged: {
        _lastKnownDuration = 0;
        _lastKnownCanSeek = false;
    }
    onDurationSecondsChanged: {
        if (durationSeconds > 0)
            _lastKnownDuration = durationSeconds;
    }
    onCanSeekChanged: {
        if (canSeek)
            _lastKnownCanSeek = true;
    }
    readonly property real _effectiveDuration: durationSeconds > 0 ? durationSeconds : _lastKnownDuration
    readonly property bool _effectiveCanSeek: canSeek || _lastKnownCanSeek

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56
                radius: 6
                color: root.theme.bgHover
                clip: true

                Image {
                    id: artImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    source: root.artUrl
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: artImage.status !== Image.Ready
                    text: "\u266a"
                    color: root.theme.textMuted
                    font.pixelSize: 18
                    font.family: root.font
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.title
                    color: root.theme.textPrimary
                    font.pixelSize: 13
                    font.bold: true
                    font.family: root.font
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: root.artist.length > 0
                    text: root.artist
                    color: root.theme.textSecondary
                    font.pixelSize: 12
                    font.family: root.font
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.sourceLabel
                    color: root.theme.textMuted
                    font.pixelSize: 10
                    font.family: root.font
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                spacing: 6

                Text {
                    text: "\uf048" // previous
                    color: root.canPrevious ? root.theme.textPrimary : root.theme.textMuted
                    opacity: root.canPrevious ? 1 : 0.4
                    font.pixelSize: 14
                    font.family: root.font

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.canPrevious
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestPrevious()
                    }
                }

                Text {
                    text: root.isPlaying ? "\uf04c" : "\uf04b" // pause / play
                    color: root.theme.accentPrimary
                    font.pixelSize: 17
                    font.family: root.font
                    style: Text.Raised
                    styleColor: "#80000000"

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestPlayPause()
                    }
                }

                Text {
                    text: "\uf051" // next
                    color: root.canNext ? root.theme.textPrimary : root.theme.textMuted
                    opacity: root.canNext ? 1 : 0.4
                    font.pixelSize: 14
                    font.family: root.font

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        enabled: root.canNext
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestNext()
                    }
                }
            }
        }

        // Position scrubber — only shown when the source actually reports
        // a seekable duration. A lot of web players never report this at
        // all, so hiding it cleanly is the correct degrade, not a bug.
        RowLayout {
            Layout.fillWidth: true
            visible: root._effectiveCanSeek && root._effectiveDuration > 0
            spacing: 6

            Text {
                text: root._formatTime(root.positionSeconds)
                color: root.theme.textMuted
                font.pixelSize: 9
                font.family: root.font
            }

            Slider {
                id: posSlider
                Layout.fillWidth: true
                from: 0
                to: Math.max(root._effectiveDuration, 0.001)
                trackHeight: 4
                handleSize: 10

                trackColor: root.theme.bgHover
                fillColor: root.theme.accentPrimary
                handleColor: root.theme.textPrimary

                Component.onCompleted: value = root.positionSeconds
                onMoved: root.requestSeek(value)

                // Sync from the source only while not being dragged, same
                // pattern used for volume sliders — an active drag always
                // wins over an incoming external update.
                Connections {
                    target: root
                    function onPositionSecondsChanged() {
                        if (!posSlider.pressed)
                            posSlider.value = root.positionSeconds;
                    }
                }
            }

            Text {
                text: root._formatTime(root._effectiveDuration)
                color: root.theme.textMuted
                font.pixelSize: 9
                font.family: root.font
            }
        }
    }
}
