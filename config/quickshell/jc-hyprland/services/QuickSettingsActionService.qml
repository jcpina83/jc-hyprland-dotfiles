import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // -------------------------------------------------------------------------
    // Phase 2D immediate Quick Settings mutation boundary.
    //
    // This service invokes only the stable public Quick Settings API:
    //
    //   jc-quick-settings dnd on|off --json
    //   jc-quick-settings night-light on|off --json
    //   jc-quick-settings lock --json
    //   jc-quick-settings suspend --json
    //
    // It never invokes desktop backends directly.
    // Successful and failed mutations reconcile through QuickSettingsService.
    // -------------------------------------------------------------------------

    property var quickSettingsService

    property bool applyingDnd: false
    property bool awaitingRefresh: false
    property bool pendingDndEnabled: false
    property bool pendingMutationSucceeded: false
    property bool pendingChanged: false

    property bool applyingNightLight: false
    property bool awaitingNightLightRefresh: false
    property bool pendingNightLightEnabled: false
    property bool pendingNightLightMutationSucceeded: false
    property bool pendingNightLightChanged: false

    property bool applyingLock: false
    property bool applyingSuspend: false

    property string errorMessage: ""
    property string statusMessage: ""
    property var lastResult: null

    readonly property bool busy:
        root.applyingDnd
        || root.awaitingRefresh
        || root.applyingNightLight
        || root.awaitingNightLightRefresh
        || root.applyingLock
        || root.applyingSuspend

    readonly property bool canSetDnd:
        !root.busy
        && root.quickSettingsService
        && root.quickSettingsService.ready
        && !root.quickSettingsService.loading
        && root.quickSettingsService.dndAvailable
        && root.quickSettingsService.dndBackendInstalled
        && root.quickSettingsService.dndRunning

    readonly property bool canSetNightLight:
        !root.busy
        && root.quickSettingsService
        && root.quickSettingsService.ready
        && !root.quickSettingsService.loading
        && root.quickSettingsService.nightLightAvailable
        && root.quickSettingsService.nightLightManaged

    readonly property bool canLock:
        !root.busy
        && root.quickSettingsService
        && root.quickSettingsService.ready
        && !root.quickSettingsService.loading
        && root.quickSettingsService.lockAvailable

    readonly property bool canSuspend:
        !root.busy
        && root.quickSettingsService
        && root.quickSettingsService.ready
        && !root.quickSettingsService.loading
        && root.quickSettingsService.suspendAvailable

    signal dndApplied(bool desiredEnabled, bool stateChanged)
    signal nightLightApplied(bool desiredEnabled, bool stateChanged)
    signal lockApplied(bool stateChanged)
    signal suspendAccepted()
    signal failed(string message)

    function quickSettingsCommandPath() {
        if (root.quickSettingsService
                && typeof root.quickSettingsService.quickSettingsCommandPath
                    === "function") {
            return root.quickSettingsService.quickSettingsCommandPath();
        }

        const configured = Quickshell.env("XDG_CONFIG_HOME");
        const home = Quickshell.env("HOME");
        const base = configured
            ? String(configured)
            : String(home || "") + "/.config";

        return base + "/jc-hyprland-dotfiles/bin/jc-quick-settings";
    }

    function parseResponse(text) {
        const source = String(text || "").trim();

        if (source.length === 0)
            return null;

        try {
            return JSON.parse(source);
        } catch (error) {
            return null;
        }
    }

    function validAppliedResponse(payload, desiredEnabled) {
        return payload
            && Number(payload.schemaVersion) === 1
            && payload.status === "applied"
            && payload.capability === "dnd"
            && typeof payload.requested === "boolean"
            && typeof payload.enabled === "boolean"
            && typeof payload.verified === "boolean"
            && typeof payload.changed === "boolean"
            && typeof payload.backend === "string"
            && payload.requested === desiredEnabled
            && payload.enabled === desiredEnabled
            && payload.verified;
    }

    function validNightLightAppliedResponse(payload, desiredEnabled) {
        return payload
            && Number(payload.schemaVersion) === 1
            && payload.status === "applied"
            && payload.capability === "night-light"
            && typeof payload.requested === "boolean"
            && typeof payload.enabled === "boolean"
            && typeof payload.verified === "boolean"
            && typeof payload.changed === "boolean"
            && typeof payload.running === "boolean"
            && typeof payload.managed === "boolean"
            && typeof payload.backend === "string"
            && payload.requested === desiredEnabled
            && payload.enabled === desiredEnabled
            && payload.verified
            && payload.managed;
    }

    function validLockAppliedResponse(payload) {
        return payload
            && Number(payload.schemaVersion) === 1
            && payload.status === "applied"
            && payload.capability === "lock"
            && typeof payload.available === "boolean"
            && typeof payload.running === "boolean"
            && typeof payload.verified === "boolean"
            && typeof payload.changed === "boolean"
            && typeof payload.backend === "string"
            && payload.available
            && payload.running
            && payload.verified;
    }


    function validSuspendAcceptedResponse(payload) {
        return payload
            && Number(payload.schemaVersion) === 1
            && payload.status === "accepted"
            && payload.capability === "suspend"
            && typeof payload.available === "boolean"
            && typeof payload.accepted === "boolean"
            && typeof payload.handoffVerified === "boolean"
            && typeof payload.backend === "string"
            && payload.available
            && payload.accepted
            && payload.handoffVerified;
    }

    function validateDndMutation() {
        if (!root.quickSettingsService)
            return "Quick Settings observed-state service is unavailable.";

        if (!root.quickSettingsService.ready)
            return "Quick Settings observed state is not ready.";

        if (root.quickSettingsService.loading)
            return "Quick Settings observed state is still refreshing.";

        if (!root.quickSettingsService.dndAvailable)
            return "Do Not Disturb is unavailable.";

        if (!root.quickSettingsService.dndBackendInstalled)
            return "Do Not Disturb backend is not installed.";

        if (!root.quickSettingsService.dndRunning)
            return "Do Not Disturb backend is not running.";

        return "";
    }

    function validateNightLightMutation() {
        if (!root.quickSettingsService)
            return "Quick Settings observed-state service is unavailable.";

        if (!root.quickSettingsService.ready)
            return "Quick Settings observed state is not ready.";

        if (root.quickSettingsService.loading)
            return "Quick Settings observed state is still refreshing.";

        if (!root.quickSettingsService.nightLightAvailable)
            return "Night Light is unavailable.";

        if (!root.quickSettingsService.nightLightManaged)
            return "Night Light backend is detected but not managed.";

        return "";
    }

    function validateLockAction() {
        if (!root.quickSettingsService)
            return "Quick Settings observed-state service is unavailable.";

        if (!root.quickSettingsService.ready)
            return "Quick Settings observed state is not ready.";

        if (root.quickSettingsService.loading)
            return "Quick Settings observed state is still refreshing.";

        if (!root.quickSettingsService.lockAvailable)
            return "Lock is unavailable.";

        return "";
    }


    function validateSuspendAction() {
        if (!root.quickSettingsService)
            return "Quick Settings observed-state service is unavailable.";

        if (!root.quickSettingsService.ready)
            return "Quick Settings observed state is not ready.";

        if (root.quickSettingsService.loading)
            return "Quick Settings observed state is still refreshing.";

        if (!root.quickSettingsService.suspendAvailable)
            return "Suspend is unavailable.";

        return "";
    }

    function clearTransientFeedback(): void {
        if (root.busy)
            return;

        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;
    }

    function beginObservedReconciliation(): void {
        if (!root.quickSettingsService) {
            root.awaitingRefresh = false;
            root.errorMessage =
                "Quick Settings observed-state service is unavailable "
                + "for reconciliation.";
            root.statusMessage = "";
            root.failed(root.errorMessage);
            return;
        }

        root.awaitingRefresh = true;

        if (!root.quickSettingsService.loading)
            root.quickSettingsService.refresh();
    }

    function beginNightLightObservedReconciliation(): void {
        if (!root.quickSettingsService) {
            root.awaitingNightLightRefresh = false;
            root.errorMessage =
                "Quick Settings observed-state service is unavailable "
                + "for Night Light reconciliation.";
            root.statusMessage = "";
            root.failed(root.errorMessage);
            return;
        }

        root.awaitingNightLightRefresh = true;

        if (!root.quickSettingsService.loading)
            root.quickSettingsService.refresh();
    }

    function setDndEnabled(desiredEnabled): void {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const validationError = root.validateDndMutation();

        if (validationError.length > 0) {
            root.errorMessage = validationError;
            root.failed(root.errorMessage);
            return;
        }

        root.pendingDndEnabled = Boolean(desiredEnabled);
        root.pendingMutationSucceeded = false;
        root.pendingChanged = false;
        root.applyingDnd = true;

        root.statusMessage =
            root.pendingDndEnabled
                ? "Enabling Do Not Disturb…"
                : "Disabling Do Not Disturb…";

        dndProcess.command = [
            root.quickSettingsCommandPath(),
            "dnd",
            root.pendingDndEnabled ? "on" : "off",
            "--json"
        ];
        dndProcess.running = true;
    }

    function setNightLightEnabled(desiredEnabled): void {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const validationError = root.validateNightLightMutation();

        if (validationError.length > 0) {
            root.errorMessage = validationError;
            root.failed(root.errorMessage);
            return;
        }

        root.pendingNightLightEnabled = Boolean(desiredEnabled);
        root.pendingNightLightMutationSucceeded = false;
        root.pendingNightLightChanged = false;
        root.applyingNightLight = true;

        root.statusMessage =
            root.pendingNightLightEnabled
                ? "Enabling Night Light…"
                : "Disabling Night Light…";

        nightLightProcess.command = [
            root.quickSettingsCommandPath(),
            "night-light",
            root.pendingNightLightEnabled ? "on" : "off",
            "--json"
        ];
        nightLightProcess.running = true;
    }

    function lockSession(): void {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const validationError = root.validateLockAction();

        if (validationError.length > 0) {
            root.errorMessage = validationError;
            root.failed(root.errorMessage);
            return;
        }

        root.applyingLock = true;
        root.statusMessage = "Locking session…";

        lockProcess.command = [
            root.quickSettingsCommandPath(),
            "lock",
            "--json"
        ];
        lockProcess.running = true;
    }


    function suspendSession(): void {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const validationError = root.validateSuspendAction();

        if (validationError.length > 0) {
            root.errorMessage = validationError;
            root.failed(root.errorMessage);
            return;
        }

        root.applyingSuspend = true;
        root.statusMessage = "Suspending session…";

        suspendProcess.command = [
            root.quickSettingsCommandPath(),
            "suspend",
            "--json"
        ];
        suspendProcess.running = true;
    }

    function finishObservedReconciliation(): void {
        if (!root.awaitingRefresh)
            return;

        const mutationSucceeded = root.pendingMutationSucceeded;
        const expected = root.pendingDndEnabled;
        const changed = root.pendingChanged;

        root.awaitingRefresh = false;
        root.pendingMutationSucceeded = false;
        root.pendingChanged = false;

        if (!root.quickSettingsService
                || !root.quickSettingsService.ready
                || root.quickSettingsService.loading) {
            root.errorMessage =
                mutationSucceeded
                    ? "Do Not Disturb mutation completed, but observed "
                        + "state is not ready after refresh."
                    : root.errorMessage;
            root.statusMessage =
                "Do Not Disturb observed-state reconciliation failed.";
            root.failed(root.errorMessage);
            return;
        }

        if (!mutationSucceeded) {
            root.statusMessage =
                "Do Not Disturb request failed; observed state refreshed.";
            root.failed(
                root.errorMessage.length > 0
                    ? root.errorMessage
                    : "Do Not Disturb mutation failed."
            );
            return;
        }

        if (!root.quickSettingsService.dndAvailable
                || root.quickSettingsService.dndEnabled !== expected) {
            const observed = root.quickSettingsService.dndAvailable
                ? String(root.quickSettingsService.dndEnabled)
                : "<unavailable>";

            root.errorMessage =
                "Do Not Disturb observed-state reconciliation failed. "
                + "Expected " + String(expected)
                + ", observed " + observed + ".";
            root.statusMessage =
                "Do Not Disturb state requires another refresh.";
            root.failed(root.errorMessage);
            return;
        }

        root.errorMessage = "";
        root.statusMessage =
            changed
                ? "Do Not Disturb updated and observed state reconciled."
                : "Do Not Disturb already matched the requested state.";

        root.dndApplied(expected, changed);
    }

    function finishNightLightObservedReconciliation(): void {
        if (!root.awaitingNightLightRefresh)
            return;

        const mutationSucceeded = root.pendingNightLightMutationSucceeded;
        const expected = root.pendingNightLightEnabled;
        const changed = root.pendingNightLightChanged;

        root.awaitingNightLightRefresh = false;
        root.pendingNightLightMutationSucceeded = false;
        root.pendingNightLightChanged = false;

        if (!root.quickSettingsService
                || !root.quickSettingsService.ready
                || root.quickSettingsService.loading) {
            root.errorMessage =
                mutationSucceeded
                    ? "Night Light mutation completed, but observed "
                        + "state is not ready after refresh."
                    : root.errorMessage;
            root.statusMessage =
                "Night Light observed-state reconciliation failed.";
            root.failed(root.errorMessage);
            return;
        }

        if (!mutationSucceeded) {
            root.statusMessage =
                "Night Light request failed; observed state refreshed.";
            root.failed(
                root.errorMessage.length > 0
                    ? root.errorMessage
                    : "Night Light mutation failed."
            );
            return;
        }

        if (!root.quickSettingsService.nightLightAvailable
                || !root.quickSettingsService.nightLightManaged
                || root.quickSettingsService.nightLightEnabled !== expected) {
            const observed =
                root.quickSettingsService.nightLightEnabled === null
                    ? "<unknown>"
                    : String(root.quickSettingsService.nightLightEnabled);

            root.errorMessage =
                "Night Light observed-state reconciliation failed. "
                + "Expected " + String(expected)
                + ", observed " + observed + ".";
            root.statusMessage =
                "Night Light state requires another refresh.";
            root.failed(root.errorMessage);
            return;
        }

        root.errorMessage = "";
        root.statusMessage =
            changed
                ? "Night Light updated and observed state reconciled."
                : "Night Light already matched the requested state.";

        root.nightLightApplied(expected, changed);
    }

    function handleDndRefreshFailure(message): void {
        if (!root.awaitingRefresh)
            return;

        const mutationSucceeded = root.pendingMutationSucceeded;

        root.awaitingRefresh = false;
        root.pendingMutationSucceeded = false;
        root.pendingChanged = false;

        if (mutationSucceeded) {
            root.errorMessage =
                "Do Not Disturb mutation was verified, but observed-state "
                + "refresh failed: "
                + String(message || "unknown error");
        } else if (root.errorMessage.length === 0) {
            root.errorMessage =
                "Do Not Disturb mutation failed and observed-state "
                + "refresh also failed: "
                + String(message || "unknown error");
        } else {
            root.errorMessage +=
                " Observed-state refresh also failed: "
                + String(message || "unknown error");
        }

        root.statusMessage =
            "Do Not Disturb state could not be reconciled.";
        root.failed(root.errorMessage);
    }

    function handleNightLightRefreshFailure(message): void {
        if (!root.awaitingNightLightRefresh)
            return;

        const mutationSucceeded = root.pendingNightLightMutationSucceeded;

        root.awaitingNightLightRefresh = false;
        root.pendingNightLightMutationSucceeded = false;
        root.pendingNightLightChanged = false;

        if (mutationSucceeded) {
            root.errorMessage =
                "Night Light mutation was verified, but observed-state "
                + "refresh failed: "
                + String(message || "unknown error");
        } else if (root.errorMessage.length === 0) {
            root.errorMessage =
                "Night Light mutation failed and observed-state "
                + "refresh also failed: "
                + String(message || "unknown error");
        } else {
            root.errorMessage +=
                " Observed-state refresh also failed: "
                + String(message || "unknown error");
        }

        root.statusMessage =
            "Night Light state could not be reconciled.";
        root.failed(root.errorMessage);
    }

    Process {
        id: dndProcess

        stdout: StdioCollector {
            id: dndStdout
        }

        stderr: StdioCollector {
            id: dndStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = String(dndStdout.text || "").trim();
            const stderrText = String(dndStderr.text || "").trim();
            const response = root.parseResponse(stdoutText);

            root.applyingDnd = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.pendingMutationSucceeded = false;
                root.pendingChanged = false;
                root.errorMessage =
                    "Do Not Disturb mutation failed"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage =
                    "Refreshing observed Do Not Disturb state…";
                root.beginObservedReconciliation();
                return;
            }

            if (!root.validAppliedResponse(
                    response,
                    root.pendingDndEnabled
                )) {
                root.pendingMutationSucceeded = false;
                root.pendingChanged = false;
                root.errorMessage =
                    "Unexpected jc-quick-settings DND response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");
                root.statusMessage =
                    "Refreshing observed Do Not Disturb state…";
                root.beginObservedReconciliation();
                return;
            }

            root.pendingMutationSucceeded = true;
            root.pendingChanged = Boolean(response.changed);
            root.errorMessage = "";
            root.statusMessage =
                "Do Not Disturb request verified. "
                + "Refreshing observed state…";

            root.beginObservedReconciliation();
        }
    }

    Process {
        id: nightLightProcess

        stdout: StdioCollector {
            id: nightLightStdout
        }

        stderr: StdioCollector {
            id: nightLightStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = String(nightLightStdout.text || "").trim();
            const stderrText = String(nightLightStderr.text || "").trim();
            const response = root.parseResponse(stdoutText);

            root.applyingNightLight = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.pendingNightLightMutationSucceeded = false;
                root.pendingNightLightChanged = false;
                root.errorMessage =
                    "Night Light mutation failed"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage =
                    "Refreshing observed Night Light state…";
                root.beginNightLightObservedReconciliation();
                return;
            }

            if (!root.validNightLightAppliedResponse(
                    response,
                    root.pendingNightLightEnabled
                )) {
                root.pendingNightLightMutationSucceeded = false;
                root.pendingNightLightChanged = false;
                root.errorMessage =
                    "Unexpected jc-quick-settings Night Light response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");
                root.statusMessage =
                    "Refreshing observed Night Light state…";
                root.beginNightLightObservedReconciliation();
                return;
            }

            root.pendingNightLightMutationSucceeded = true;
            root.pendingNightLightChanged = Boolean(response.changed);
            root.errorMessage = "";
            root.statusMessage =
                "Night Light request verified. "
                + "Refreshing observed state…";

            root.beginNightLightObservedReconciliation();
        }
    }


    Process {
        id: lockProcess

        stdout: StdioCollector {
            id: lockStdout
        }

        stderr: StdioCollector {
            id: lockStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = String(lockStdout.text || "").trim();
            const stderrText = String(lockStderr.text || "").trim();
            const response = root.parseResponse(stdoutText);

            root.applyingLock = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.errorMessage =
                    "Lock request failed"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage = "";
                root.failed(root.errorMessage);
                return;
            }

            if (!root.validLockAppliedResponse(response)) {
                root.errorMessage =
                    "Unexpected jc-quick-settings Lock response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");
                root.statusMessage = "";
                root.failed(root.errorMessage);
                return;
            }

            root.errorMessage = "";
            root.statusMessage =
                Boolean(response.changed)
                    ? "Session lock started."
                    : "Session lock was already active.";

            root.lockApplied(Boolean(response.changed));
        }
    }



    Process {
        id: suspendProcess

        stdout: StdioCollector {
            id: suspendStdout
        }

        stderr: StdioCollector {
            id: suspendStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = String(suspendStdout.text || "").trim();
            const stderrText = String(suspendStderr.text || "").trim();
            const response = root.parseResponse(stdoutText);

            root.applyingSuspend = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.errorMessage =
                    "Suspend request failed"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage = "";
                root.failed(root.errorMessage);
                return;
            }

            if (!root.validSuspendAcceptedResponse(response)) {
                root.errorMessage =
                    "Unexpected jc-quick-settings Suspend response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");
                root.statusMessage = "";
                root.failed(root.errorMessage);
                return;
            }

            root.errorMessage = "";
            root.statusMessage =
                "Suspend request accepted; waiting for system sleep.";
            root.suspendAccepted();
        }
    }


    Connections {
        target: root.quickSettingsService

        function onRefreshed() {
            if (root.awaitingRefresh)
                Qt.callLater(root.finishObservedReconciliation);

            if (root.awaitingNightLightRefresh)
                Qt.callLater(root.finishNightLightObservedReconciliation);
        }

        function onRefreshFailed(message) {
            if (root.awaitingRefresh)
                root.handleDndRefreshFailure(message);

            if (root.awaitingNightLightRefresh)
                root.handleNightLightRefreshFailure(message);
        }
    }
}
