import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    id: root

    // Phase 2G.2b — native mutation foundation.
    //
    // Pair/forget remain intentionally outside this phase.
    // BluetoothService remains authoritative for observed state.
    property var bluetoothService: null

    property bool applyingAdapterEnabled: false
    property bool applyingDeviceConnection: false
    property bool awaitingObservedState: false

    property bool pendingDesiredAdapterEnabled: false
    property bool pendingDesiredConnected: false
    property bool pendingDesiredTrusted: false
    property bool pendingDesiredBlocked: false
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


    function canSetPairedDeviceTrusted(device, desiredTrusted): bool {
        if (root.busy || device === null || device === undefined)
            return false;

        if (root.bluetoothService === null
                || root.bluetoothService === undefined
                || root.bluetoothService.enabled !== true) {
            return false;
        }

        if (device.paired !== true || device.pairing === true)
            return false;

        const desired = Boolean(desiredTrusted);
        return Boolean(device.trusted) !== desired;
    }


    function canSetPairedDeviceBlocked(device, desiredBlocked): bool {
        if (root.busy || device === null || device === undefined)
            return false;

        if (root.bluetoothService === null
                || root.bluetoothService === undefined
                || root.bluetoothService.enabled !== true) {
            return false;
        }

        if (device.paired !== true || device.pairing === true)
            return false;

        const desired = Boolean(desiredBlocked);

        if (Boolean(device.blocked) === desired)
            return false;

        if (desired && device.connected === true)
            return false;

        return true;
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
        root.pendingDesiredTrusted = false;
        root.pendingDesiredBlocked = false;
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


    function setPairedDeviceTrusted(device, desiredTrusted): void {
        root.clearTransientFeedback();

        const desired = Boolean(desiredTrusted);

        if (!root.canSetPairedDeviceTrusted(device, desired)) {
            root.reject(
                "paired-device-trust",
                "Paired-device trust mutation is unavailable."
            );
            return;
        }

        root.awaitingObservedState = true;
        root.pendingDevice = device;
        root.pendingDesiredTrusted = desired;
        root.pendingAction = desired
            ? "paired-device-trust"
            : "paired-device-untrust";
        root.statusMessage = desired
            ? "Trusting paired Bluetooth device…"
            : "Removing trust from paired Bluetooth device…";

        mutationTimeout.restart();
        device.trusted = desired;
    }


    function setPairedDeviceBlocked(device, desiredBlocked): void {
        root.clearTransientFeedback();

        const desired = Boolean(desiredBlocked);

        if (!root.canSetPairedDeviceBlocked(device, desired)) {
            root.reject(
                "paired-device-block",
                desired && device && device.connected === true
                    ? "Disconnect the paired Bluetooth device before blocking it."
                    : "Paired-device block mutation is unavailable."
            );
            return;
        }

        root.awaitingObservedState = true;
        root.pendingDevice = device;
        root.pendingDesiredBlocked = desired;
        root.pendingAction = desired
            ? "paired-device-block"
            : "paired-device-unblock";
        root.statusMessage = desired
            ? "Blocking paired Bluetooth device…"
            : "Unblocking paired Bluetooth device…";

        mutationTimeout.restart();
        device.blocked = desired;
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


    function reconcilePairedDeviceTrusted(): void {
        if (!root.busy
                || root.pendingDevice === null
                || (root.pendingAction !== "paired-device-trust"
                    && root.pendingAction !== "paired-device-untrust")) {
            return;
        }

        if (Boolean(root.pendingDevice.trusted)
                !== root.pendingDesiredTrusted) {
            return;
        }

        const action = root.pendingAction;
        root.resetPending();
        root.statusMessage = action === "paired-device-trust"
            ? "Paired Bluetooth device trusted."
            : "Paired Bluetooth device trust removed.";
    }


    function reconcilePairedDeviceBlocked(): void {
        if (!root.busy
                || root.pendingDevice === null
                || (root.pendingAction !== "paired-device-block"
                    && root.pendingAction !== "paired-device-unblock")) {
            return;
        }

        if (Boolean(root.pendingDevice.blocked)
                !== root.pendingDesiredBlocked) {
            return;
        }

        const action = root.pendingAction;
        root.resetPending();
        root.statusMessage = action === "paired-device-block"
            ? "Paired Bluetooth device blocked."
            : "Paired Bluetooth device unblocked.";
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

        function onTrustedChanged() {
            root.reconcilePairedDeviceTrusted();
        }

        function onBlockedChanged() {
            root.reconcilePairedDeviceBlocked();
        }
    }
}
