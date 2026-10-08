import QtQuick
import "../theme-switcher"
import "../components"

// Compact "currently playing" card(s). Pure presentation — all discovery,
// source selection, and control logic lives in MediaService/MpdService.
// Designed to be dropped into Quick Settings later without changes.
//
// Root is a plain Item (not ColumnLayout) wrapping a Column: Column uses
// each child's actual width/height to lay out and to size itself, and a
// bare Item/Rectangle's height defaults to its implicitHeight when nothing
// else sets it — so implicitHeight: content.height here reliably tracks
// the real rendered content as cards appear/disappear/resize, which a
// parent panel can read to size itself correctly.
//
// Shows ONE card per currently-active source (every MPRIS player with a
// track loaded, plus MPD if it has a song loaded) rather than collapsing
// to a single "current" player — if Firefox and Spotify are both playing,
// both show up. (Multiple tabs *within* the same Firefox window can't be
// split apart this way — Firefox exposes exactly one MPRIS player per
// browser profile, not per tab, so that limitation lives one level below
// anything this widget can see.)
Item {
    id: root

    property var theme: Theme
    property string font: "JetBrainsMono NF"

    implicitWidth: 360
    implicitHeight: content.height

    readonly property bool anythingActive: MediaService.mprisSources.length > 0 || MpdService.hasSong

    Column {
        id: content
        width: root.width
        spacing: 8

        // ---- Empty state ------------------------------------------------------

        Column {
            width: parent.width
            visible: !root.anythingActive
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "\u266a"
                color: root.theme.textMuted
                font.pixelSize: 20
                font.family: root.font
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "No media playing"
                color: root.theme.textMuted
                font.pixelSize: 12
                font.family: root.font
            }
        }

        // ---- One card per live MPRIS source ------------------------------------

        Repeater {
            model: MediaService.mprisSources

            delegate: MediaCard {
                id: mprisCard
                required property var modelData
                width: content.width

                theme: root.theme
                font: root.font

                title: modelData.trackTitle || "Unknown title"
                artist: modelData.trackArtist || ""
                sourceLabel: modelData.identity || "Media Player"
                artUrl: modelData.trackArtUrl || ""
                isPlaying: modelData.isPlaying === true
                canPrevious: modelData.canGoPrevious === true
                canNext: modelData.canGoNext === true

                // position/length are in seconds already (Quickshell
                // normalizes this). Many web players never report these at
                // all unless the page calls setPositionState() — the card
                // just hides the scrubber when that's the case.
                canSeek: modelData.canSeek === true && modelData.positionSupported === true
                positionSeconds: modelData.position
                durationSeconds: modelData.lengthSupported ? modelData.length : 0

                // Quickshell deliberately does NOT auto-update `position`
                // every tick — this is the officially documented way to
                // opt in to a smoothly-ticking value while a slider for it
                // is actually visible. Not polling: nothing is queried
                // over DBus here, this just re-reads a property that's
                // already local and cheap.
                Timer {
                    interval: 1000
                    repeat: true
                    running: mprisCard.isPlaying
                    onTriggered: mprisCard.modelData.positionChanged()
                }

                onRequestPlayPause: modelData.togglePlaying()
                onRequestNext: modelData.next()
                onRequestPrevious: modelData.previous()
                onRequestSeek: seconds => modelData.position = seconds
            }
        }

        // ---- MPD card (singleton service, not a list) --------------------------

        MediaCard {
            width: content.width
            visible: MpdService.hasSong

            theme: root.theme
            font: root.font

            title: MpdService.title.length > 0 ? MpdService.title : "Unknown title"
            artist: MpdService.artist
            sourceLabel: "MPD"
            artUrl: MpdService.artworkGuess
            isPlaying: MpdService.isPlaying
            canPrevious: true
            canNext: true
            canSeek: MpdService.duration > 0
            positionSeconds: MpdService.position
            durationSeconds: MpdService.duration

            onRequestPlayPause: MpdService.togglePlay()
            onRequestNext: MpdService.next()
            onRequestPrevious: MpdService.previous()
            onRequestSeek: seconds => MpdService.seek(seconds)
        }
    }
}
