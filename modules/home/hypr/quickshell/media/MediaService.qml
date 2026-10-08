pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Normalizes every media source (MPD + every MPRIS player — Firefox,
// Chromium, mpv, Spotify, whatever is currently registered) into one
// "current player" interface for the UI.
//
// MPRIS players come for free from Quickshell.Services.Mpris (Firefox and
// Chromium register themselves over MPRIS automatically whenever a page
// plays media with the Media Session API active, no extra setup needed).
// MPD does not speak MPRIS on its own (that would require running the
// separate mpDris2 bridge, which isn't assumed to be installed), so it's
// folded in here from MpdService as a synthetic entry alongside the real
// MPRIS ones.
Singleton {
    id: root

    // Raw, live MprisPlayer references (not snapshots) for any UI that
    // wants to show every active source rather than collapsing to one —
    // e.g. Firefox AND Spotify both playing at once. This only changes
    // identity when a player with a track appears or disappears (only
    // trackTitle/trackArtist *presence* is read below, not their values,
    // and never volatile per-tick state like position), so a Repeater
    // bound to this keeps its delegates alive across ordinary playback
    // changes instead of getting reset on every tick.
    readonly property var mprisSources: {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.filter(p => (p.trackTitle && p.trackTitle.length > 0) || (p.trackArtist && p.trackArtist.length > 0));
    }

    function _mprisEntries() {
        const players = Mpris.players ? Mpris.players.values : [];
        return players.map(p => ({
                    kind: "mpris",
                    ref: p,
                    source: p.identity || "Media Player",
                    title: p.trackTitle || "",
                    artist: p.trackArtist || "",
                    album: p.trackAlbum || "",
                    artUrl: p.trackArtUrl || "",
                    isPlaying: p.isPlaying === true,
                    hasTrack: (p.trackTitle && p.trackTitle.length > 0) || (p.trackArtist && p.trackArtist.length > 0),
                    canPlay: p.canPlay === true,
                    canPause: p.canPause === true,
                    canGoNext: p.canGoNext === true,
                    canGoPrevious: p.canGoPrevious === true
                }));
    }

    function _mpdEntry() {
        if (!MpdService.connected || !MpdService.hasSong)
            return null;
        return {
            kind: "mpd",
            ref: null,
            source: "MPD",
            title: MpdService.title,
            artist: MpdService.artist,
            album: MpdService.album,
            artUrl: MpdService.artworkGuess,
            isPlaying: MpdService.isPlaying,
            hasTrack: true,
            canPlay: true,
            canPause: true,
            canGoNext: true,
            canGoPrevious: true
        };
    }

    readonly property var _entries: {
        const list = root._mprisEntries().filter(e => e.hasTrack);
        const mpd = root._mpdEntry();
        if (mpd)
            list.push(mpd);
        return list;
    }

    // Every source that currently has something loaded — not just the
    // single "primary" one. Playing sources first, so if two things are
    // going at once the one you're more likely to care about lands on top.
    readonly property var players: {
        const list = root._entries.slice();
        list.sort((a, b) => (b.isPlaying ? 1 : 0) - (a.isPlaying ? 1 : 0));
        return list;
    }

    // MPRIS position doesn't update reactively on its own (per Quickshell's
    // own docs) — this is their documented workaround: manually re-emit
    // positionChanged() once a second for every currently-playing MPRIS
    // player so anything bound to .position re-evaluates. MPD's equivalent
    // ticker lives in MpdService itself since it needs to interpolate a
    // locally-tracked anchor rather than just re-reading a live property.
    Timer {
        interval: 1000
        repeat: true
        running: root.players.some(e => e.kind === "mpris" && e.isPlaying)
        onTriggered: {
            for (const e of root.players) {
                if (e.kind === "mpris" && e.isPlaying && e.ref)
                    e.ref.positionChanged();
            }
        }
    }

    // ---- Per-entry controls (for a UI showing multiple sources at once) --

    function playPauseFor(entry) {
        if (!entry)
            return;
        if (entry.kind === "mpd")
            MpdService.togglePlay();
        else if (entry.ref)
            entry.ref.togglePlaying();
    }

    function nextFor(entry) {
        if (!entry)
            return;
        if (entry.kind === "mpd")
            MpdService.next();
        else if (entry.ref && entry.canGoNext)
            entry.ref.next();
    }

    function previousFor(entry) {
        if (!entry)
            return;
        if (entry.kind === "mpd")
            MpdService.previous();
        else if (entry.ref && entry.canGoPrevious)
            entry.ref.previous();
    }

    function positionFor(entry) {
        if (!entry)
            return 0;
        if (entry.kind === "mpd")
            return MpdService.position;
        return entry.ref ? (entry.ref.position || 0) : 0;
    }

    function lengthFor(entry) {
        if (!entry)
            return 0;
        if (entry.kind === "mpd")
            return MpdService.duration;
        return entry.ref ? (entry.ref.length || 0) : 0;
    }

    function canSeekFor(entry) {
        if (!entry)
            return false;
        if (entry.kind === "mpd")
            return true;
        return entry.ref && entry.ref.canSeek === true;
    }

    function seekFor(entry, fraction) {
        if (!entry)
            return;
        const len = root.lengthFor(entry);
        if (len <= 0)
            return;
        const seconds = Math.max(0, Math.min(len, fraction * len));
        if (entry.kind === "mpd")
            MpdService.seek(seconds);
        else if (entry.ref && entry.ref.canSeek)
            entry.ref.position = seconds;
    }

    // ---- Singular "primary source" API (used by the bar's compact pill) -
    //
    // Sticky: keep showing whatever was current before if it's still
    // playing, so a second source merely being *paused* doesn't yank the
    // bar's display away from what you were just looking at. This is
    // deliberately kept separate from `players` above — the bar has room
    // for exactly one thing, the fuller widget has room for all of them.
    property string _stickyKind: ""
    property string _stickySource: ""

    readonly property var currentEntry: {
        const entries = root._entries;
        if (entries.length === 0)
            return null;

        // 1. Whatever was current before, if it's still actively playing.
        for (const e of entries) {
            if (e.kind === root._stickyKind && e.source === root._stickySource && e.isPlaying)
                return e;
        }
        // 2. Any other source that's actively playing.
        for (const e of entries) {
            if (e.isPlaying)
                return e;
        }
        // 3. Whatever was current before, even if now just paused.
        for (const e of entries) {
            if (e.kind === root._stickyKind && e.source === root._stickySource)
                return e;
        }
        // 4. Nothing is playing and nothing was previously selected —
        // fall back to whatever exists rather than showing nothing.
        return entries[0];
    }

    onCurrentEntryChanged: {
        if (currentEntry) {
            _stickyKind = currentEntry.kind;
            _stickySource = currentEntry.source;
        }
    }

    readonly property bool hasMedia: currentEntry !== null
    readonly property string title: hasMedia ? currentEntry.title : ""
    readonly property string artist: hasMedia ? currentEntry.artist : ""
    readonly property string album: hasMedia ? currentEntry.album : ""
    readonly property string artUrl: hasMedia ? currentEntry.artUrl : ""
    readonly property string source: hasMedia ? currentEntry.source : ""
    readonly property bool isPlaying: hasMedia ? currentEntry.isPlaying : false
    readonly property bool canPlay: hasMedia ? currentEntry.canPlay : false
    readonly property bool canPause: hasMedia ? currentEntry.canPause : false
    readonly property bool canNext: hasMedia ? currentEntry.canGoNext : false
    readonly property bool canPrevious: hasMedia ? currentEntry.canGoPrevious : false

    // How many sources currently have something loaded, for an optional
    // "+2 more" style affordance in the UI if ever wanted.
    readonly property int sourceCount: _entries.length

    function playPause() {
        if (!hasMedia)
            return;
        const e = currentEntry;
        if (e.kind === "mpd")
            MpdService.togglePlay();
        else if (e.ref)
            e.ref.togglePlaying();
    }

    function next() {
        if (!hasMedia)
            return;
        const e = currentEntry;
        if (e.kind === "mpd")
            MpdService.next();
        else if (e.ref && e.canGoNext)
            e.ref.next();
    }

    function previous() {
        if (!hasMedia)
            return;
        const e = currentEntry;
        if (e.kind === "mpd")
            MpdService.previous();
        else if (e.ref && e.canGoPrevious)
            e.ref.previous();
    }
}
