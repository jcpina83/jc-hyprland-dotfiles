import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    id: root

    // Phase 2G.1a — read-only native BlueZ observation.
    //
    // The native API also exposes mutation properties and methods. This service
    // intentionally observes them without writing or invoking them. Pairing,
    // connect/disconnect, trust, forget, discovery, and controller power remain
    // outside the Phase 2G.1a contract.

    readonly property bool readOnly: true

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterAvailable: root.adapter !== null

    readonly property string adapterName:
        root.adapterAvailable ? String(root.adapter.name || "") : ""
    readonly property bool enabled:
        root.adapterAvailable && root.adapter.enabled === true
    readonly property int state:
        root.adapterAvailable
            ? root.adapter.state
            : BluetoothAdapterState.Disabled
    readonly property string stateName:
        BluetoothAdapterState.toString(root.state)

    readonly property bool discoverable:
        root.adapterAvailable && root.adapter.discoverable === true
    readonly property bool discovering:
        root.adapterAvailable && root.adapter.discovering === true
    readonly property bool pairable:
        root.adapterAvailable && root.adapter.pairable === true

    readonly property var devices: Bluetooth.devices
    readonly property var deviceValues:
        Bluetooth.devices ? Bluetooth.devices.values : []

    function pairedDevices() {
        const values = root.deviceValues || [];
        const paired = [];

        for (let i = 0; i < values.length; ++i) {
            const device = values[i];

            if (device && device.paired === true)
                paired.push(device);
        }

        return paired;
    }

    function connectedDevices() {
        const values = root.deviceValues || [];
        const connected = [];

        for (let i = 0; i < values.length; ++i) {
            const device = values[i];

            if (device && device.connected === true)
                connected.push(device);
        }

        return connected;
    }

    readonly property var pairedDeviceValues:
        root.pairedDevices()
    readonly property int pairedDeviceCount:
        root.pairedDeviceValues.length

    readonly property var connectedDeviceValues:
        root.connectedDevices()
    readonly property int connectedDeviceCount:
        root.connectedDeviceValues.length
    readonly property var primaryDevice:
        root.connectedDeviceCount > 0
            ? root.connectedDeviceValues[0]
            : null

    readonly property string primaryDeviceName:
        root.primaryDevice
            ? String(
                root.primaryDevice.name
                    || root.primaryDevice.deviceName
                    || ""
            )
            : ""
    readonly property int primaryDeviceState:
        root.primaryDevice
            ? root.primaryDevice.state
            : BluetoothDeviceState.Disconnected
    readonly property string primaryDeviceStateName:
        BluetoothDeviceState.toString(root.primaryDeviceState)
    readonly property bool primaryDeviceConnected:
        root.primaryDevice && root.primaryDevice.connected === true
    readonly property bool primaryDevicePaired:
        root.primaryDevice && root.primaryDevice.paired === true
    readonly property bool primaryDeviceTrusted:
        root.primaryDevice && root.primaryDevice.trusted === true
    readonly property bool primaryDeviceBatteryAvailable:
        root.primaryDevice
            && root.primaryDevice.batteryAvailable === true
    readonly property real primaryDeviceBattery:
        root.primaryDeviceBatteryAvailable
            ? Number(root.primaryDevice.battery)
            : -1

    readonly property bool observedHealthy:
        root.adapterAvailable
}
