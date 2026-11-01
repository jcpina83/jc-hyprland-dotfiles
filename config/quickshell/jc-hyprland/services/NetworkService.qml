import QtQuick
import Quickshell
import Quickshell.Networking

Scope {
    id: root

    // Phase 2G.1a — read-only native NetworkManager observation.
    //
    // This service deliberately exposes observed state only. Even though
    // Quickshell.Networking provides mutation APIs, Phase 2G.1a must not call
    // connect/disconnect/forget, toggle Wi-Fi, trigger scans, or request secrets.
    // Presentation QML must consume this service rather than importing the native
    // backend directly.

    readonly property bool readOnly: true

    readonly property int backend: Networking.backend
    readonly property string backendName:
        NetworkBackendType.toString(Networking.backend)
    readonly property bool backendAvailable:
        Networking.backend !== NetworkBackendType.None

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    readonly property int connectivity: Networking.connectivity
    readonly property string connectivityName:
        NetworkConnectivity.toString(Networking.connectivity)

    readonly property var devices: Networking.devices
    readonly property var deviceValues:
        Networking.devices ? Networking.devices.values : []

    function firstDeviceOfType(type) {
        const values = root.deviceValues || [];

        for (let i = 0; i < values.length; ++i) {
            const device = values[i];

            if (device && device.type === type)
                return device;
        }

        return null;
    }

    function connectedNetworkFor(device) {
        if (!device || !device.networks)
            return null;

        const values = device.networks.values || [];

        for (let i = 0; i < values.length; ++i) {
            const network = values[i];

            if (network && network.connected === true)
                return network;
        }

        return null;
    }

    readonly property var wifiDevice:
        root.firstDeviceOfType(DeviceType.Wifi)
    readonly property bool wifiAvailable: root.wifiDevice !== null
    readonly property bool wifiConnected:
        root.wifiAvailable && root.wifiDevice.connected === true
    readonly property string wifiInterface:
        root.wifiAvailable ? String(root.wifiDevice.name || "") : ""
    readonly property int wifiState:
        root.wifiAvailable
            ? root.wifiDevice.state
            : ConnectionState.Unknown
    readonly property string wifiStateName:
        ConnectionState.toString(root.wifiState)

    readonly property var wifiNetwork:
        root.connectedNetworkFor(root.wifiDevice)
    readonly property string wifiNetworkName:
        root.wifiNetwork ? String(root.wifiNetwork.name || "") : ""
    readonly property real wifiSignalStrength:
        root.wifiNetwork
            && typeof root.wifiNetwork.signalStrength === "number"
            ? Number(root.wifiNetwork.signalStrength)
            : -1
    readonly property string wifiSecurityName:
        root.wifiNetwork
            && root.wifiNetwork.security !== undefined
            ? WifiSecurityType.toString(root.wifiNetwork.security)
            : "Unknown"

    readonly property var wiredDevice:
        root.firstDeviceOfType(DeviceType.Wired)
    readonly property bool wiredAvailable: root.wiredDevice !== null
    readonly property bool wiredConnected:
        root.wiredAvailable && root.wiredDevice.connected === true
    readonly property string wiredInterface:
        root.wiredAvailable ? String(root.wiredDevice.name || "") : ""
    readonly property int wiredState:
        root.wiredAvailable
            ? root.wiredDevice.state
            : ConnectionState.Unknown
    readonly property string wiredStateName:
        ConnectionState.toString(root.wiredState)
    readonly property bool wiredHasLink:
        root.wiredAvailable
            && root.wiredDevice.hasLink !== undefined
            && root.wiredDevice.hasLink === true
    readonly property int wiredLinkSpeedMbps:
        root.wiredAvailable
            && typeof root.wiredDevice.linkSpeed === "number"
            ? Number(root.wiredDevice.linkSpeed)
            : 0

    readonly property bool connected:
        root.wifiConnected || root.wiredConnected

    readonly property bool observedHealthy:
        root.backendAvailable
}
