pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Thin normalization layer over Quickshell's native Quickshell.Bluetooth
// module, which wraps the BlueZ DBus interface directly — fully reactive
// (adapter/device objects emit their own property-change signals from
// DBus), so unlike a bluetoothctl-based approach there is no polling, no
// text parsing, and no shelling out at all. This mirrors how
// AudioInputService/AudioOutputService sit on top of Quickshell's native
// Pipewire module rather than reimplementing device discovery themselves.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null && adapter !== undefined

    readonly property bool powered: available && adapter.enabled === true
    readonly property bool discovering: available && adapter.discovering === true
    readonly property string adapterName: available ? (adapter.name && adapter.name.length > 0 ? adapter.name : adapter.adapterId) : ""

    // BlueZ tracks every device it has ever seen for an adapter (paired,
    // previously connected, or turned up in a scan) in one flat list —
    // grouping by state happens here, not upstream.
    readonly property var _allDevices: available && adapter.devices ? adapter.devices.values : []

    readonly property var connectedDevices: _allDevices.filter(d => d.connected === true)
    readonly property var pairedDevices: _allDevices.filter(d => d.paired === true && d.connected !== true)
    // Seen (via a scan or otherwise) but never paired — what a "Scan"
    // reveals that's actually new.
    readonly property var availableDevices: _allDevices.filter(d => d.paired !== true)

    // ---- Helpers ----------------------------------------------------------

    // `name` is a user-settable alias that falls back to `deviceName` (the
    // name the device itself advertises) when empty — this just picks
    // whichever is actually populated, never invents a placeholder.
    function displayName(device) {
        if (!device)
            return "";
        if (device.name && device.name.length > 0)
            return device.name;
        if (device.deviceName && device.deviceName.length > 0)
            return device.deviceName;
        if (device.address && device.address.length > 0)
            return device.address;
        return "Unknown device";
    }

    function isConnecting(device) {
        return device && device.state === BluetoothDeviceState.Connecting;
    }

    function isDisconnecting(device) {
        return device && device.state === BluetoothDeviceState.Disconnecting;
    }

    // ---- Adapter actions --------------------------------------------------

    function togglePower() {
        if (!available)
            return;
        adapter.enabled = !adapter.enabled;
    }

    function startDiscovery() {
        if (!available)
            return;
        adapter.discovering = true;
    }

    function stopDiscovery() {
        if (!available)
            return;
        adapter.discovering = false;
    }

    // ---- Device actions --------------------------------------------------

    function connectDevice(device) {
        if (!device)
            return;
        device.connect();
    }

    function disconnectDevice(device) {
        if (!device)
            return;
        device.disconnect();
    }

    function pairDevice(device) {
        if (!device)
            return;
        device.pair();
    }

    function cancelPair(device) {
        if (!device)
            return;
        device.cancelPair();
    }

    // Forgetting also unpairs — BlueZ doesn't have a separate "unpair"
    // call, per Quickshell's own docs: "you must forget() the device to
    // unpair it."
    function removeDevice(device) {
        if (!device)
            return;
        device.forget();
    }
}
