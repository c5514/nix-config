pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Dynamic PipeWire/WirePlumber-backed audio output service.
//
// Scope:
//   - Physical output devices
//   - Virtual output devices
//   - Default output selection
//   - Per-output volume/mute
//
// Application playback streams are handled separately by
// AudioStreamService.

Singleton {
    id: root

    // ---------------------------------------------------------------------
    // Node discovery
    // ---------------------------------------------------------------------

    readonly property var _audioNodes: Pipewire.ready ? Pipewire.nodes.values.filter(n => n && n.audio) : []

    // A hardware/virtual output is:
    //
    //   isStream = false
    //   isSink   = true
    //
    readonly property var outputs: _audioNodes.filter(n => !n.isStream && n.isSink)

    PwObjectTracker {
        objects: root.outputs
    }

    // ---------------------------------------------------------------------
    // Default output
    // ---------------------------------------------------------------------

    readonly property var defaultOutput: Pipewire.defaultAudioSink

    readonly property bool hasDefaultOutput: defaultOutput !== null && defaultOutput !== undefined

    readonly property real defaultVolume: hasDefaultOutput && defaultOutput.audio ? defaultOutput.audio.volume : 0

    readonly property bool defaultMuted: hasDefaultOutput && defaultOutput.audio ? defaultOutput.audio.muted : false

    readonly property string defaultName: hasDefaultOutput ? displayName(defaultOutput) : "No output device"

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function displayName(node) {
        if (!node)
            return "";

        if (node.description && node.description.length > 0)
            return node.description;

        if (node.nickname && node.nickname.length > 0)
            return node.nickname;

        if (node.name && node.name.length > 0)
            return node.name;

        return "Unknown output";
    }

    function isDefault(node) {
        return hasDefaultOutput && node && node.id === defaultOutput.id;
    }

    // ---------------------------------------------------------------------
    // Default device
    // ---------------------------------------------------------------------

    function setDefaultOutput(node) {
        if (!node)
            return;

        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultOutputById(nodeId) {
        const node = outputs.find(n => n.id === nodeId);

        if (node)
            root.setDefaultOutput(node);
    }

    // ---------------------------------------------------------------------
    // Volume
    // ---------------------------------------------------------------------

    function setVolume(node, volume) {
        if (!node || !node.audio)
            return;

        node.audio.volume = Math.max(0, Math.min(1, volume));
    }

    function setVolumeById(nodeId, volume) {
        const node = outputs.find(n => n.id === nodeId);

        if (node)
            root.setVolume(node, volume);
    }

    function setDefaultVolume(volume) {
        if (hasDefaultOutput)
            root.setVolume(defaultOutput, volume);
    }

    function adjustDefaultVolume(delta) {
        if (hasDefaultOutput)
            root.setVolume(defaultOutput, defaultVolume + delta);
    }

    // ---------------------------------------------------------------------
    // Mute
    // ---------------------------------------------------------------------

    function setMuted(node, muted) {
        if (!node || !node.audio)
            return;

        node.audio.muted = muted;
    }

    function toggleMuted(node) {
        if (!node || !node.audio)
            return;

        node.audio.muted = !node.audio.muted;
    }

    function toggleDefaultMuted() {
        if (hasDefaultOutput)
            root.toggleMuted(defaultOutput);
    }
}
