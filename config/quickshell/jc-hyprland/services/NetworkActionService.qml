import QtQuick
import Quickshell
import Quickshell.Networking

Scope {
    id: root

    // Phase 2G.2b — native mutation foundation.
    //
    // No UI control invokes these actions in this phase. The service owns the
    // future mutation boundary while NetworkService remains authoritative for
    // observed state.
    property var networkService: null

    property bool applyingWifiEnabled: false
    property bool applyingNetworkConnection: false
    property bool awaitingObservedState: false

    property bool pendingDesiredWifiEnabled: false
    property bool pendingDesiredConnected: false
    property var pendingNetwork: null
    property string pendingAction: ""

    property string errorMessage: ""
    property string statusMessage: ""

    readonly property bool busy:
        root.applyingWifiEnabled
        || root.applyingNetworkConnection
        || root.awaitingObservedState

    readonly property bool canSetWifiEnabled:
        !root.busy
        && root.networkService !== null
        && root.networkService.backendAvailable === true
        && root.networkService.wifiHardwareEnabled === true

    signal actionApplied(string action)
    signal failed(string action, string message)

    function clearTransientFeedback(): void {
        if (root.busy)
            return;

        root.errorMessage = "";
        root.statusMessage = "";
    }

    function canSetKnownNetworkConnected(network, desiredConnected): bool {
        if (root.busy || network === null || network === undefined)
            return false;

        if (root.networkService === null
                || root.networkService.backendAvailable !== true
                || root.networkService.wifiHardwareEnabled !== true
                || root.networkService.wifiEnabled !== true) {
            return false;
        }

        if (network.known !== true)
            return false;

        const desired = Boolean(desiredConnected);

        if (network.stateChanging === true)
            return false;

        return Boolean(network.connected) !== desired;
    }

    function reject(action, message): void {
        root.errorMessage = String(
            message || "Network action is unavailable."
        );
        root.statusMessage = "";
        root.failed(String(action || ""), root.errorMessage);
    }

    function resetPending(): void {
        root.applyingWifiEnabled = false;
        root.applyingNetworkConnection = false;
        root.awaitingObservedState = false;
        root.pendingDesiredWifiEnabled = false;
        root.pendingDesiredConnected = false;
        root.pendingNetwork = null;
        root.pendingAction = "";
        mutationTimeout.stop();
    }

    function setWifiEnabled(desiredEnabled): void {
        const desired = Boolean(desiredEnabled);

        root.errorMessage = "";
        root.statusMessage = "";

        if (!root.canSetWifiEnabled) {
            root.reject(
                "wifi-radio",
                "Wi-Fi radio mutation is unavailable."
            );
            return;
        }

        if (root.networkService.wifiEnabled === desired) {
            root.statusMessage = desired
                ? "Wi-Fi radio is already enabled."
                : "Wi-Fi radio is already disabled.";
            return;
        }

        root.applyingWifiEnabled = true;
        root.awaitingObservedState = true;
        root.pendingDesiredWifiEnabled = desired;
        root.pendingAction = "wifi-radio";
        root.statusMessage = desired
            ? "Enabling Wi-Fi radio…"
            : "Disabling Wi-Fi radio…";

        Networking.wifiEnabled = desired;
        mutationTimeout.restart();
    }

    function setKnownNetworkConnected(network, desiredConnected): void {
        const desired = Boolean(desiredConnected);

        root.errorMessage = "";
        root.statusMessage = "";

        if (!root.canSetKnownNetworkConnected(network, desired)) {
            root.reject(
                "known-network",
                "Known-network connection mutation is unavailable."
            );
            return;
        }

        root.applyingNetworkConnection = true;
        root.awaitingObservedState = true;
        root.pendingNetwork = network;
        root.pendingDesiredConnected = desired;
        root.pendingAction = desired
            ? "known-network-connect"
            : "known-network-disconnect";
        root.statusMessage = desired
            ? "Connecting to saved network…"
            : "Disconnecting saved network…";

        if (desired)
            network.connect();
        else
            network.disconnect();

        mutationTimeout.restart();
    }

    function reconcileWifiEnabled(): void {
        if (!root.applyingWifiEnabled || !root.awaitingObservedState)
            return;

        if (root.networkService === null)
            return;

        if (root.networkService.wifiEnabled
                !== root.pendingDesiredWifiEnabled) {
            return;
        }

        const action = root.pendingAction;
        root.resetPending();
        root.errorMessage = "";
        root.statusMessage = "Wi-Fi radio state verified.";
        root.actionApplied(action);
    }

    function reconcileKnownNetwork(): void {
        if (!root.applyingNetworkConnection
                || !root.awaitingObservedState
                || root.pendingNetwork === null) {
            return;
        }

        if (root.pendingNetwork.stateChanging === true)
            return;

        if (Boolean(root.pendingNetwork.connected)
                !== root.pendingDesiredConnected) {
            return;
        }

        const action = root.pendingAction;
        root.resetPending();
        root.errorMessage = "";
        root.statusMessage = "Saved network state verified.";
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
                "Network mutation timed out before observed state matched.";
            root.statusMessage = "";
            root.failed(action, root.errorMessage);
        }
    }

    Connections {
        target: Networking

        function onWifiEnabledChanged() {
            root.reconcileWifiEnabled();
        }
    }

    Connections {
        target: root.pendingNetwork

        function onConnectedChanged() {
            root.reconcileKnownNetwork();
        }

        function onStateChangingChanged() {
            root.reconcileKnownNetwork();
        }
    }
}
