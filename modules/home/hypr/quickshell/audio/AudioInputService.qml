pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick

// Dynamic PipeWire/WirePlumber-backed audio input service.
//
// Scope:
//   - Physical microphone/input devices
//   - Virtual input devices
//   - Default input selection
//   - Per-input volume/mute
//
// Application capture streams are intentionally excluded.

Singleton {
    id: root

    // ---------------------------------------------------------------------
    // Node discovery
    // ---------------------------------------------------------------------

    readonly property var _audioNodes: Pipewire.ready ? Pipewire.nodes.values.filter(n => n && n.audio) : []

    // A real input/source is an audio node which:
    //
    //   isStream = false
    //   isSink   = false
    //
    readonly property var inputs: _audioNodes.filter(n => !n.isStream && !n.isSink)

    // Bind the nodes whose audio properties we use.
    PwObjectTracker {
        objects: root.inputs
    }

    // ---------------------------------------------------------------------
    // Default input
    // ---------------------------------------------------------------------

    readonly property var defaultInput: Pipewire.defaultAudioSource

    readonly property bool hasDefaultInput: defaultInput !== null && defaultInput !== undefined

    readonly property real defaultVolume: hasDefaultInput && defaultInput.audio ? defaultInput.audio.volume : 0

    readonly property bool defaultMuted: hasDefaultInput && defaultInput.audio ? defaultInput.audio.muted : false

    readonly property string defaultName: hasDefaultInput ? displayName(defaultInput) : "No microphone"

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

        return "Unknown input";
    }

    function isDefault(node) {
        return hasDefaultInput && node && node.id === defaultInput.id;
    }

    function describe(node) {
        if (!node)
            return null;

        return {
            id: node.id,
            name: displayName(node),
            volume: node.audio ? node.audio.volume : 0,
            muted: node.audio ? node.audio.muted : false,
            isDefault: root.isDefault(node)
        };
    }

    readonly property var inputList: inputs.map(n => describe(n))

    // ---------------------------------------------------------------------
    // Default device
    // ---------------------------------------------------------------------

    function setDefaultInput(node) {
        if (!node)
            return;

        Pipewire.preferredDefaultAudioSource = node;
    }

    function setDefaultInputById(nodeId) {
        const node = inputs.find(n => n.id === nodeId);

        if (node)
            root.setDefaultInput(node);
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
        const node = inputs.find(n => n.id === nodeId);

        if (node)
            root.setVolume(node, volume);
    }

    function setDefaultVolume(volume) {
        if (hasDefaultInput)
            root.setVolume(defaultInput, volume);
    }

    function adjustDefaultVolume(delta) {
        if (hasDefaultInput)
            root.setVolume(defaultInput, defaultVolume + delta);
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
        if (hasDefaultInput)
            root.toggleMuted(defaultInput);
    }
}
