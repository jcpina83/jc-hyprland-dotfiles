import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // -------------------------------------------------------------------------
    // Phase 2D.1c — immediate Quick Settings mutation boundary.
    //
    // This service may invoke only the stable public Quick Settings API:
    //
    //   jc-quick-settings dnd on --json
    //   jc-quick-settings dnd off --json
    //
    // It never invokes SwayNC or any desktop backend directly. Successful and
    // failed mutations are reconciled through QuickSettingsService.
    // -------------------------------------------------------------------------

    property var quickSettingsService

    property bool applyingDnd: false
    property bool awaitingRefresh: false
    property bool pendingDndEnabled: false
    property bool pendingMutationSucceeded: false
    property bool pendingChanged: false

    property string errorMessage: ""
    property string statusMessage: ""
    property var lastResult: null

    readonly property bool busy:
        root.applyingDnd || root.awaitingRefresh

    readonly property bool canSetDnd:
        !root.busy
        && root.quickSettingsService
        && root.quickSettingsService.ready
        && !root.quickSettingsService.loading
        && root.quickSettingsService.dndAvailable
        && root.quickSettingsService.dndBackendInstalled
        && root.quickSettingsService.dndRunning

    signal dndApplied(bool desiredEnabled, bool stateChanged)
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

    Connections {
        target: root.quickSettingsService

        function onRefreshed() {
            if (!root.awaitingRefresh)
                return;

            Qt.callLater(root.finishObservedReconciliation);
        }

        function onRefreshFailed(message) {
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
    }
}
