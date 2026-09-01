import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Phase 2C — QML mutation boundary for Themes.
    //
    // This service may invoke only the stable public Theme Control API:
    //
    //   jc-theme apply THEME --json
    //   jc-theme recover --json
    //
    // It owns no theme files, symlinks, locks or desktop-consumer commands.

    property var themeService
    property var draftStore

    property bool applying: false
    property bool recovering: false
    property bool awaitingRefresh: false
    property bool rollbackRecoveryRequired: false

    property string refreshMode: ""
    property string expectedObservedThemeId: ""
    property string pendingRequestedThemeId: ""
    property string pendingPreviousThemeId: ""

    property string errorMessage: ""
    property string statusMessage: ""
    property var lastResult: null

    readonly property bool busy:
        root.applying
        || root.recovering
        || root.awaitingRefresh

    readonly property bool canApply:
        !root.busy
        && !root.rollbackRecoveryRequired
        && root.themeService
        && root.themeService.ready
        && !root.themeService.loading
        && root.themeService.observedHealthy
        && root.draftStore
        && root.draftStore.initialized
        && root.draftStore.dirty
        && root.draftStore.draftValid
        && !root.draftStore.observedChangedWhileDirty

    readonly property bool canRecover:
        !root.busy
        && root.rollbackRecoveryRequired
        && root.themeService
        && root.themeService.ready
        && !root.themeService.loading
        && root.themeService.observedHealthy

    signal applied(string themeId)
    signal rolledBack(string message)
    signal rollbackFailed(string message)
    signal recovered()
    signal recoveryFailed(string message)
    signal failed(string message)

    function themeCommandPath() {
        if (root.themeService
                && typeof root.themeService.themeCommandPath === "function") {
            return root.themeService.themeCommandPath();
        }

        const configured = Quickshell.env("XDG_CONFIG_HOME");
        const home = Quickshell.env("HOME");
        const base = configured
            ? String(configured)
            : String(home || "") + "/.config";

        return base + "/jc-hyprland-dotfiles/bin/jc-theme";
    }

    function parseResponse(text) {
        const source = String(text || "").trim();

        if (!source)
            return null;

        try {
            return JSON.parse(source);
        } catch (error) {
            return null;
        }
    }

    function validAppliedResponse(payload) {
        return payload
            && payload.status === "applied"
            && Boolean(payload.committed)
            && Boolean(payload.changed)
            && !Boolean(payload.rolledBack)
            && Boolean(payload.runtimeVerified)
            && String(payload.targetTheme || "").length > 0;
    }

    function validRolledBackResponse(payload) {
        return payload
            && payload.status === "rolled-back"
            && !Boolean(payload.committed)
            && Boolean(payload.changed)
            && Boolean(payload.rolledBack)
            && Boolean(payload.identityRestored)
            && Boolean(payload.runtimeRollbackVerified)
            && String(payload.previousTheme || "").length > 0;
    }

    function validRollbackFailedResponse(payload) {
        return payload
            && payload.status === "rollback-failed"
            && !Boolean(payload.committed)
            && Boolean(payload.changed)
            && !Boolean(payload.rolledBack)
            && !Boolean(payload.runtimeRollbackVerified);
    }

    function validInvalidRequestResponse(payload) {
        return payload
            && payload.status === "invalid-request"
            && !Boolean(payload.committed)
            && !Boolean(payload.changed)
            && !Boolean(payload.rolledBack);
    }

    function validRecoveredResponse(payload) {
        return payload
            && payload.status === "recovered"
            && Boolean(payload.committed)
            && !Boolean(payload.changed)
            && !Boolean(payload.rolledBack)
            && Boolean(payload.runtimeVerified)
            && String(payload.targetTheme || "").length > 0;
    }

    function validRecoveryFailedResponse(payload) {
        return payload
            && payload.status === "recovery-failed"
            && !Boolean(payload.committed)
            && !Boolean(payload.changed)
            && !Boolean(payload.rolledBack)
            && !Boolean(payload.runtimeVerified);
    }

    function validateApply() {
        if (!root.themeService)
            return "Theme observed-state service is unavailable.";

        if (!root.themeService.ready)
            return "Theme observed state is not ready.";

        if (root.themeService.loading)
            return "Theme observed state is still refreshing.";

        if (!root.themeService.observedHealthy)
            return "Theme observed state is not healthy.";

        if (!root.draftStore)
            return "Theme draft store is unavailable.";

        if (!root.draftStore.initialized)
            return "Theme draft state is not initialized.";

        if (root.draftStore.observedChangedWhileDirty) {
            return "Theme state changed while editing. "
                + "Reset the draft before applying.";
        }

        if (root.rollbackRecoveryRequired) {
            return "Theme runtime recovery is required before "
                + "another Apply can be attempted.";
        }

        if (!root.draftStore.dirty)
            return "There are no theme changes to apply.";

        if (!root.draftStore.draftValid)
            return "The selected theme draft is invalid.";

        return "";
    }

    function validateRecovery() {
        if (!root.rollbackRecoveryRequired)
            return "Theme runtime recovery is not currently required.";

        if (!root.themeService)
            return "Theme observed-state service is unavailable.";

        if (!root.themeService.ready)
            return "Theme observed state is not ready.";

        if (root.themeService.loading)
            return "Theme observed state is still refreshing.";

        if (!root.themeService.observedHealthy)
            return "Theme observed state is not healthy enough for recovery.";

        return "";
    }

    function clearTransientFeedback() {
        if (root.busy || root.rollbackRecoveryRequired)
            return;

        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;
    }

    function refreshObserved(mode, expectedThemeId) {
        if (!root.themeService || root.themeService.loading) {
            if (mode === "rollback-failed"
                    || mode === "recovery"
                    || mode === "recovery-failed"
                    || mode === "rollback") {
                root.rollbackRecoveryRequired = true;
            }

            root.errorMessage =
                "Theme observed state cannot be refreshed right now.";
            root.statusMessage =
                root.rollbackRecoveryRequired
                    ? "Theme recovery required."
                    : "Observed-state reconciliation pending.";
            root.failed(root.errorMessage);
            return false;
        }

        root.refreshMode = String(mode || "");
        root.expectedObservedThemeId = String(expectedThemeId || "");
        root.awaitingRefresh = true;
        root.themeService.refresh();
        return true;
    }

    function applyDirty() {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const validationError = root.validateApply();

        if (validationError.length > 0) {
            root.errorMessage = validationError;
            root.failed(root.errorMessage);
            return;
        }

        root.pendingRequestedThemeId =
            String(root.draftStore.draftThemeId || "");
        root.pendingPreviousThemeId =
            String(root.themeService.activeThemeId || "");

        root.applying = true;
        root.statusMessage = "Applying theme draft…";

        applyProcess.command = [
            root.themeCommandPath(),
            "apply",
            root.pendingRequestedThemeId,
            "--json"
        ];
        applyProcess.running = true;
    }

    function recoverRuntime() {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const validationError = root.validateRecovery();

        if (validationError.length > 0) {
            root.errorMessage = validationError;
            root.recoveryFailed(root.errorMessage);
            return;
        }

        root.recovering = true;
        root.statusMessage = "Recovering active theme runtime…";

        recoveryProcess.command = [
            root.themeCommandPath(),
            "recover",
            "--json"
        ];
        recoveryProcess.running = true;
    }

    function finishObservedRefresh() {
        if (!root.awaitingRefresh)
            return;

        const mode = root.refreshMode;
        const expected = root.expectedObservedThemeId;
        const observed = root.themeService
            ? String(root.themeService.activeThemeId || "")
            : "";

        root.awaitingRefresh = false;
        root.refreshMode = "";
        root.expectedObservedThemeId = "";

        if (!root.themeService
                || !root.themeService.observedHealthy
                || observed !== expected) {
            root.errorMessage =
                "Theme observed-state reconciliation failed. Expected "
                + (expected.length > 0 ? expected : "<unknown>")
                + ", observed "
                + (observed.length > 0 ? observed : "<unknown>")
                + ".";

            if (mode === "rollback-failed"
                    || mode === "recovery"
                    || mode === "recovery-failed"
                    || mode === "rollback") {
                root.rollbackRecoveryRequired = true;
                root.statusMessage = "Theme recovery required.";
            } else {
                root.statusMessage =
                    "Applied state could not be reconciled yet.";
            }

            root.failed(root.errorMessage);
            return;
        }

        if (mode === "apply") {
            if (!root.draftStore
                    || root.draftStore.dirty
                    || root.draftStore.baselineThemeId !== expected
                    || root.draftStore.draftThemeId !== expected) {
                root.errorMessage =
                    "Theme transaction committed and was observed, "
                    + "but draft reconciliation did not complete.";
                root.statusMessage =
                    "Applied theme observed; draft reconciliation failed.";
                root.failed(root.errorMessage);
                return;
            }

            root.rollbackRecoveryRequired = false;
            root.errorMessage = "";
            root.statusMessage =
                "Theme applied and observed state reconciled.";
            root.applied(expected);
            return;
        }

        if (mode === "rollback") {
            root.rollbackRecoveryRequired = false;
            root.statusMessage =
                "Previous theme state restored; draft remains pending.";
            root.rolledBack(root.errorMessage);
            return;
        }

        if (mode === "rollback-failed") {
            root.rollbackRecoveryRequired = true;
            root.statusMessage =
                "Theme recovery required; draft remains pending.";
            root.rollbackFailed(root.errorMessage);
            return;
        }

        if (mode === "recovery") {
            root.rollbackRecoveryRequired = false;
            root.errorMessage = "";
            root.statusMessage =
                "Theme runtime recovered; draft remains pending.";
            root.recovered();
            return;
        }

        if (mode === "recovery-failed") {
            root.rollbackRecoveryRequired = true;
            root.statusMessage =
                "Theme recovery still required.";
            root.recoveryFailed(root.errorMessage);
        }
    }

    Process {
        id: applyProcess

        stdout: StdioCollector {
            id: applyStdout
        }

        stderr: StdioCollector {
            id: applyStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = applyStdout.text.trim();
            const stderrText = applyStderr.text.trim();
            const response = root.parseResponse(stdoutText);

            root.applying = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                if (root.validRollbackFailedResponse(response)) {
                    const backendMessage =
                        String(response.message || "").trim();

                    root.rollbackRecoveryRequired = true;
                    root.errorMessage =
                        "Theme Apply failed and runtime rollback "
                        + "could not be verified."
                        + (
                            backendMessage.length > 0
                                ? " " + backendMessage
                                : ""
                        );
                    root.statusMessage =
                        "Refreshing restored identity; recovery required.";

                    root.refreshObserved(
                        "rollback-failed",
                        String(response.previousTheme || "")
                    );
                    return;
                }

                if (root.validRolledBackResponse(response)) {
                    const backendMessage =
                        String(response.message || "").trim();

                    root.rollbackRecoveryRequired = false;
                    root.errorMessage =
                        "Theme Apply failed and the previous state was restored."
                        + (
                            backendMessage.length > 0
                                ? " " + backendMessage
                                : ""
                        );
                    root.statusMessage =
                        "Refreshing restored theme state…";

                    root.refreshObserved(
                        "rollback",
                        String(response.previousTheme || "")
                    );
                    return;
                }

                if (root.validInvalidRequestResponse(response)) {
                    root.rollbackRecoveryRequired = false;
                    root.errorMessage =
                        "Theme Apply request rejected: "
                        + String(response.message || "invalid request");
                    root.statusMessage = "";
                    root.failed(root.errorMessage);
                    return;
                }

                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.rollbackRecoveryRequired = true;
                root.errorMessage =
                    "Theme Apply failed with unknown recovery state"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage =
                    "Theme recovery required; refreshing observed state.";

                root.refreshObserved(
                    "rollback-failed",
                    String(root.pendingPreviousThemeId || "")
                );
                return;
            }

            if (!root.validAppliedResponse(response)
                    || String(response.targetTheme || "")
                        !== root.pendingRequestedThemeId) {
                root.rollbackRecoveryRequired = true;
                root.errorMessage =
                    "Unexpected jc-theme Apply response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");
                root.statusMessage =
                    "Theme state requires inspection before another Apply.";

                root.refreshObserved(
                    "rollback-failed",
                    String(root.pendingPreviousThemeId || "")
                );
                return;
            }

            root.rollbackRecoveryRequired = false;
            root.errorMessage = "";
            root.statusMessage =
                "Theme transaction committed. Refreshing observed state…";

            if (!root.draftStore.prepareForRefreshAfterApply(
                    root.pendingRequestedThemeId)) {
                root.errorMessage =
                    "Theme transaction committed, but draft reconciliation "
                    + "could not be prepared.";
                root.statusMessage =
                    "Refreshing observed state without draft acceptance.";
            }

            root.refreshObserved(
                "apply",
                String(response.targetTheme || "")
            );
        }
    }

    Process {
        id: recoveryProcess

        stdout: StdioCollector {
            id: recoveryStdout
        }

        stderr: StdioCollector {
            id: recoveryStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = recoveryStdout.text.trim();
            const stderrText = recoveryStderr.text.trim();
            const response = root.parseResponse(stdoutText);

            root.recovering = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                if (root.validRecoveryFailedResponse(response)) {
                    root.rollbackRecoveryRequired = true;
                    root.errorMessage =
                        "Theme runtime recovery could not be verified. "
                        + String(response.message || "");
                    root.statusMessage =
                        "Refreshing observed identity; recovery still required.";

                    root.refreshObserved(
                        "recovery-failed",
                        String(response.targetTheme || "")
                    );
                    return;
                }

                if (root.validInvalidRequestResponse(response)) {
                    root.rollbackRecoveryRequired = true;
                    root.errorMessage =
                        "Theme Recovery request rejected: "
                        + String(response.message || "invalid request");
                    root.statusMessage = "Theme recovery still required.";
                    root.recoveryFailed(root.errorMessage);
                    return;
                }

                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.rollbackRecoveryRequired = true;
                root.errorMessage =
                    "Theme Recovery failed with unknown state"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage =
                    "Theme recovery still required.";
                root.recoveryFailed(root.errorMessage);
                return;
            }

            if (!root.validRecoveredResponse(response)) {
                root.rollbackRecoveryRequired = true;
                root.errorMessage =
                    "Unexpected jc-theme Recovery response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");
                root.statusMessage =
                    "Theme recovery still required.";
                root.recoveryFailed(root.errorMessage);
                return;
            }

            root.errorMessage = "";
            root.statusMessage =
                "Theme runtime recovered. Refreshing observed state…";

            root.refreshObserved(
                "recovery",
                String(response.targetTheme || "")
            );
        }
    }

    Connections {
        target: root.themeService

        function onRefreshed() {
            if (!root.awaitingRefresh)
                return;

            Qt.callLater(root.finishObservedRefresh);
        }

        function onRefreshFailed(message) {
            if (!root.awaitingRefresh)
                return;

            const mode = root.refreshMode;

            root.awaitingRefresh = false;
            root.refreshMode = "";
            root.expectedObservedThemeId = "";

            root.errorMessage =
                "Theme observed-state refresh failed: "
                + String(message || "unknown error");

            if (mode === "rollback-failed"
                    || mode === "recovery"
                    || mode === "recovery-failed"
                    || mode === "rollback") {
                root.rollbackRecoveryRequired = true;
                root.statusMessage = "Theme recovery required.";
            } else {
                root.statusMessage =
                    "Applied state could not be reconciled yet.";
            }

            root.failed(root.errorMessage);
        }
    }

    Connections {
        target: root.draftStore

        function onChanged() {
            root.clearTransientFeedback();
        }
    }
}
