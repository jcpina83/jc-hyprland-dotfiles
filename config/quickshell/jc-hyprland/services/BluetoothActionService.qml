import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    id: root

    // Phase 2G.2b — native mutation foundation.
    //
    // Pair/forget/trust/block remain intentionally outside this phase.
    // BluetoothService remains authoritative for observed state.
    property var bluetoothService: null

    property bool applyingAdapterEnabled: false
    property bool applyingDeviceConnection: false
    property bool awaitingObservedState: false

    property bool pendingDesiredAdapterEnabled: false
    property bool pendingDesiredConnected: false
    property var pendingDevice: null
    property string pendingAction: ""

    property string errorMessage: ""
    property string statusMessage: ""

    readonly property var adapter:
        root.bluetoothService !== null
            ? root.bluetoothService.adapter
            : null

    readonly property bool busy:
        root.applyingAdapterEnabled
        || root.applyingDeviceConnection
        || root.awaitingObservedState

    readonly property bool canSetAdapterEnabled:
        !root.busy
        && root.adapter !== null

    signal actionApplied(string action)
    signal failed(string action, string message)

    function clearTransientFeedback(): void {
        if (root.busy)
            return;

        root.errorMessage = "";
        root.statusMessage = "";
    }

    function canSetPairedDeviceConnected(device, desiredConnected): bool {
        if (root.busy || device === null || device === undefined)
            return false;

        if (root.bluetoothService === null
                || root.bluetoothService.adapterAvailable !== true
                || root.bluetoothService.enabled !== true) {
            return false;
        }

        if (device.paired !== true || device.pairing === true)
            return false;

        const desired = Boolean(desiredConnected);
        return Boolean(device.connected) !== desired;
    }

    function reject(action, message): void {
        root.errorMessage = String(
            message || "Bluetooth action is unavailable."
        );
        root.statusMessage = "";
        root.failed(String(action || ""), root.errorMessage);
    }

    function resetPending(): void {
        root.applyingAdapterEnabled = false;
        root.applyingDeviceConnection = false;
        root.awaitingObservedState = false;
        root.pendingDesiredAdapterEnabled = false;
        root.pendingDesiredConnected = false;
        root.pendingDevice = null;
        root.pendingAction = "";
        mutationTimeout.stop();
    }

    function setAdapterEnabled(desiredEnabled): void {
        const desired = Boolean(desiredEnabled);

        root.errorMessage = "";
        root.statusMessage = "";

        if (!root.canSetAdapterEnabled) {
            root.reject(
                "bluetooth-adapter",
                "Bluetooth adapter mutation is unavailable."
            );
            return;
        }

        if (Boolean(root.adapter.enabled) === desired) {
            root.statusMessage = desired
                ? "Bluetooth adapter is already enabled."
                : "Bluetooth adapter is already disabled.";
            return;
        }

        root.applyingAdapterEnabled = true;
        root.awaitingObservedState = true;
        root.pendingDesiredAdapterEnabled = desired;
        root.pendingAction = "bluetooth-adapter";
        root.statusMessage = desired
            ? "Enabling Bluetooth adapter…"
            : "Disabling Bluetooth adapter…";

        mutationTimeout.restart();
        root.adapter.enabled = desired;
    }

    function setPairedDeviceConnected(device, desiredConnected): void {
        const desired = Boolean(desiredConnected);

        root.errorMessage = "";
        root.statusMessage = "";

        if (!root.canSetPairedDeviceConnected(device, desired)) {
            root.reject(
                "paired-device",
                "Paired-device connection mutation is unavailable."
            );
            return;
        }

        root.applyingDeviceConnection = true;
        root.awaitingObservedState = true;
        root.pendingDevice = device;
        root.pendingDesiredConnected = desired;
        root.pendingAction = desired
            ? "paired-device-connect"
            : "paired-device-disconnect";
        root.statusMessage = desired
            ? "Connecting paired Bluetooth device…"
            : "Disconnecting paired Bluetooth device…";

        mutationTimeout.restart();
        if (desired)
            device.connect();
        else
            device.disconnect();

    }

    function reconcileAdapterEnabled(): void {
        if (!root.applyingAdapterEnabled || !root.awaitingObservedState)
            return;

        if (root.adapter === null)
            return;

        if (Boolean(root.adapter.enabled)
                !== root.pendingDesiredAdapterEnabled) {
            return;
        }

        const action = root.pendingAction;
        root.resetPending();
        root.errorMessage = "";
        root.statusMessage = "Bluetooth adapter state verified.";
        root.actionApplied(action);
    }

    function reconcilePairedDevice(): void {
        if (!root.applyingDeviceConnection
                || !root.awaitingObservedState
                || root.pendingDevice === null) {
            return;
        }

        if (Boolean(root.pendingDevice.connected)
                !== root.pendingDesiredConnected) {
            return;
        }

        const action = root.pendingAction;
        root.resetPending();
        root.errorMessage = "";
        root.statusMessage = "Bluetooth device state verified.";
        root.actionApplied(action);
    }

    Timer {
        id: mutationTimeout
        interval: 6000
        repeat: false

        onTriggered: {
            const action = root.pendingAction;
            root.resetPending();
            root.errorMessage =
                "Bluetooth mutation timed out before observed state matched.";
            root.statusMessage = "";
            root.failed(action, root.errorMessage);
        }
    }

    Connections {
        target: root.adapter

        function onEnabledChanged() {
            root.reconcileAdapterEnabled();
        }
    }

    Connections {
        target: root.pendingDevice

        function onConnectedChanged() {
            root.reconcilePairedDevice();
        }
    }
}
