pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Per-application PLAYBACK stream volume/mute.
//
// Examples:
//   Firefox
//   Chromium
//   mpv
//   games
//   music players
//
// These are application streams sending audio INTO a sink.
//
// They are intentionally separate from AudioOutputService, which manages
// actual output devices such as speakers, headphones and HDMI.

Singleton {
    id: root

    // ---------------------------------------------------------------------
    // Node discovery
    // ---------------------------------------------------------------------

    // Application streams are dynamic: they appear when an application
    // creates an audio stream.
    //
    // Bind all isStream nodes before inspecting their audio object so that
    // dynamically-created streams get their PwNodeAudio object tracked.
    readonly property var _streamCandidates: Pipewire.ready ? Pipewire.nodes.values.filter(n => n && n.isStream) : []

    PwObjectTracker {
        objects: root._streamCandidates
    }

    // ---------------------------------------------------------------------
    // Playback streams
    // ---------------------------------------------------------------------
    //
    // PipeWire/Quickshell semantics:
    //
    //     isStream = true
    //     isSink   = true
    //
    // represents an application stream which accepts/sends audio into the
    // sink side of the graph.
    //
    // Your debug output showed:
    //
    //     Firefox   stream=true sink=true audio=true
    //     Chromium  stream=true sink=true audio=true
    //
    // Therefore these MUST use `n.isSink`, not `!n.isSink`.
    readonly property var streams: _streamCandidates.filter(n => n.audio && n.isSink)

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function appName(node) {
        if (!node)
            return "";

        const props = node.properties || {};

        if (props["application.name"] && props["application.name"].length > 0)
            return props["application.name"];

        if (node.description && node.description.length > 0)
            return node.description;

        if (node.name && node.name.length > 0)
            return node.name;

        return "Unknown application";
    }

    function mediaName(node) {
        if (!node)
            return "";

        const props = node.properties || {};

        return props["media.name"] || "";
    }

    function _findNode(nodeId) {
        for (const node of root.streams) {
            if (node.id === nodeId)
                return node;
        }

        return null;
    }

    // ---------------------------------------------------------------------
    // Volume
    // ---------------------------------------------------------------------

    function setVolume(nodeId, volume) {
        const node = root._findNode(nodeId);

        if (!node || !node.audio)
            return;

        node.audio.volume = Math.max(0, Math.min(1, volume));
    }

    // ---------------------------------------------------------------------
    // Mute
    // ---------------------------------------------------------------------

    function setMuted(nodeId, muted) {
        const node = root._findNode(nodeId);

        if (!node || !node.audio)
            return;

        node.audio.muted = muted;
    }

    function toggleMuted(nodeId) {
        const node = root._findNode(nodeId);

        if (!node || !node.audio)
            return;

        node.audio.muted = !node.audio.muted;
    }
}
