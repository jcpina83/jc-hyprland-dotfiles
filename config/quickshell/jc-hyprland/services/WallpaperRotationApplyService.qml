import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var wallpaperService
    property var draftStore

    property bool applying: false
    property bool awaitingRefresh: false
    property bool recoveryResetPending: false
    property bool rollbackRecoveryRequired: false

    readonly property bool busy:
        root.applying
        || root.awaitingRefresh
        || root.recoveryResetPending

    readonly property bool canApply:
        !root.busy
        && root.wallpaperService
        && root.wallpaperService.ready
        && !root.wallpaperService.loading
        && root.draftStore
        && root.draftStore.initialized
        && root.draftStore.rotationDirty
        && !root.draftStore.observedChangedWhileDirty
        && !root.rollbackRecoveryRequired

    property string errorMessage: ""
    property string statusMessage: ""
    property var lastResult: null

    signal applied()
    signal rolledBack(string message)
    signal rollbackFailed(string message)
    signal failed(string message)

    function configHome() {
        const configured = Quickshell.env("XDG_CONFIG_HOME");

        if (configured !== null && String(configured).length > 0)
            return String(configured);

        const home = Quickshell.env("HOME");

        return String(home) + "/.config";
    }

    function wallpaperctlPath() {
        return root.configHome()
            + "/jc-hyprland-dotfiles/bin/jc-wallpaperctl";
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

    function validAppliedResponse(payload) {
        return payload
            && (
                payload.status === "applied"
                || payload.status === "reconciled"
            )
            && Boolean(payload.committed)
            && !Boolean(payload.rolledBack)
            && Boolean(payload.runtimeVerified)
            && payload.after
            && payload.after.runtime
            && Boolean(payload.after.runtime.synchronized);
    }

    function validRollbackResponse(payload) {
        return payload
            && payload.status === "rolled-back"
            && !Boolean(payload.committed)
            && Boolean(payload.rolledBack)
            && Boolean(payload.configurationRestored)
            && Boolean(payload.runtimeRollbackVerified);
    }

    function validRollbackFailedResponse(payload) {
        return payload
            && payload.status === "rollback-failed"
            && !Boolean(payload.committed)
            && !Boolean(payload.rolledBack)
            && Boolean(payload.configurationRestored)
            && !Boolean(payload.runtimeRollbackVerified);
    }

    function validInvalidRequestResponse(payload) {
        return payload
            && payload.status === "invalid-request"
            && !Boolean(payload.committed)
            && !Boolean(payload.rolledBack);
    }

    function validateApply() {
        if (!root.wallpaperService)
            return "Wallpaper observed-state service is unavailable.";

        if (!root.wallpaperService.ready)
            return "Wallpaper observed state is not ready.";

        if (root.wallpaperService.loading)
            return "Wallpaper observed state is still refreshing.";

        if (!root.draftStore)
            return "Wallpaper draft store is unavailable.";

        if (!root.draftStore.initialized)
            return "Wallpaper draft state is not initialized.";

        if (root.draftStore.observedChangedWhileDirty) {
            return "Wallpaper state changed while editing. "
                + "Reset the draft before applying rotation.";
        }

        if (root.rollbackRecoveryRequired) {
            return "Rotation runtime recovery is required before "
                + "another Apply can be attempted.";
        }

        if (!root.draftStore.rotationDirty)
            return "There are no rotation changes to apply.";

        if (root.draftStore.rotationModeDirty
                && !root.draftStore.validRotationMode(
                    root.draftStore.draftRotationMode
                )) {
            return "Wallpaper rotation mode draft is invalid.";
        }

        if (root.draftStore.rotationTargetDirty
                && !root.draftStore.validRotationTarget(
                    root.draftStore.draftRotationTarget
                )) {
            return "Wallpaper rotation target draft is invalid.";
        }

        if (root.draftStore.rotationIntervalDirty
                && !root.draftStore.validRotationInterval(
                    root.draftStore.draftRotationInterval
                )) {
            return "Wallpaper rotation interval draft is invalid.";
        }

        return "";
    }

    function buildApplyArguments() {
        const args = [
            root.wallpaperctlPath(),
            "rotation",
            "apply"
        ];

        if (root.draftStore && root.draftStore.rotationEnabledDirty) {
            args.push("--enabled");
            args.push(
                root.draftStore.draftRotationEnabled
                    ? "true"
                    : "false"
            );
        }

        if (root.draftStore && root.draftStore.rotationModeDirty) {
            args.push("--mode");
            args.push(String(root.draftStore.draftRotationMode || ""));
        }

        if (root.draftStore && root.draftStore.rotationTargetDirty) {
            args.push("--target");
            args.push(String(root.draftStore.draftRotationTarget || ""));
        }

        if (root.draftStore && root.draftStore.rotationIntervalDirty) {
            args.push("--interval");
            args.push(String(root.draftStore.draftRotationInterval || ""));
        }

        args.push("--json");

        return args;
    }

    function clearTransientFeedback(): void {
        if (root.busy || root.rollbackRecoveryRequired)
            return;

        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;
    }

    function refreshObservedPreservingDraft(): void {
        if (root.wallpaperService && !root.wallpaperService.loading)
            root.wallpaperService.refresh();
    }

    function resetDraft(): void {
        if (root.busy || !root.draftStore)
            return;

        if (!root.rollbackRecoveryRequired) {
            root.draftStore.resetRotation();
            root.clearTransientFeedback();
            return;
        }

        if (!root.wallpaperService || root.wallpaperService.loading) {
            root.errorMessage =
                "Rotation recovery state cannot be refreshed right now.";
            root.statusMessage = "Rotation recovery still required.";
            return;
        }

        root.recoveryResetPending = true;
        root.statusMessage =
            "Refreshing observed rotation state before Reset…";

        root.wallpaperService.refresh();
    }

    function fail(message): void {
        root.applying = false;
        root.awaitingRefresh = false;

        root.errorMessage =
            String(message || "Wallpaper rotation Apply failed.");
        root.statusMessage = "";

        root.failed(root.errorMessage);
    }

    function applyDirty(): void {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const validationError = root.validateApply();

        if (validationError.length > 0) {
            root.fail(validationError);
            return;
        }

        root.applying = true;
        root.statusMessage = "Applying wallpaper rotation draft…";

        applyProcess.exec(root.buildApplyArguments());
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
                        "Rotation Apply failed and runtime rollback "
                        + "could not be verified. Configuration was restored."
                        + (
                            backendMessage.length > 0
                                ? " " + backendMessage
                                : ""
                        );

                    root.statusMessage =
                        "Rotation recovery required; draft remains pending.";

                    root.refreshObservedPreservingDraft();
                    root.rollbackFailed(root.errorMessage);
                    return;
                }

                if (root.validRollbackResponse(response)) {
                    const backendMessage =
                        String(response.message || "").trim();

                    root.rollbackRecoveryRequired = false;
                    root.errorMessage =
                        "Rotation Apply failed and the previous "
                        + "state was restored."
                        + (
                            backendMessage.length > 0
                                ? " " + backendMessage
                                : ""
                        );

                    root.statusMessage =
                        "Previous rotation state restored; "
                        + "draft remains pending.";

                    root.refreshObservedPreservingDraft();
                    root.rolledBack(root.errorMessage);
                    return;
                }

                if (root.validInvalidRequestResponse(response)) {
                    root.rollbackRecoveryRequired = false;
                    root.fail(
                        "Rotation Apply request rejected: "
                        + String(response.message || "invalid request")
                    );
                    return;
                }

                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.rollbackRecoveryRequired = true;
                root.fail(
                    "Rotation Apply failed with unknown recovery state"
                    + (details.length > 0 ? ": " + details : "")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

            if (!root.validAppliedResponse(response)) {
                root.rollbackRecoveryRequired = true;
                root.fail(
                    "Unexpected jc-wallpaperctl rotation Apply response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

            root.rollbackRecoveryRequired = false;
            root.errorMessage = "";
            root.statusMessage =
                "Rotation transaction committed. "
                + "Refreshing observed state…";

            root.draftStore.prepareForRefreshAfterRotationApply();

            root.awaitingRefresh = true;
            root.wallpaperService.refresh();
        }
    }

    Connections {
        target: root.wallpaperService

        function onRefreshed() {
            if (root.recoveryResetPending) {
                root.recoveryResetPending = false;

                if (root.wallpaperService.rotationRuntimeSynchronized) {
                    root.rollbackRecoveryRequired = false;
                    root.draftStore.resetRotation();
                    root.clearTransientFeedback();
                    return;
                }

                root.rollbackRecoveryRequired = true;
                root.errorMessage =
                    "Rotation runtime is still not synchronized "
                    + "after refresh. Reset was not performed.";
                root.statusMessage =
                    "Rotation recovery still required.";

                root.failed(root.errorMessage);
                return;
            }

            if (!root.awaitingRefresh)
                return;

            root.awaitingRefresh = false;
            root.errorMessage = "";
            root.statusMessage =
                "Rotation changes applied and observed state reconciled.";

            root.applied();
        }

        function onFailed(message) {
            if (root.recoveryResetPending) {
                root.recoveryResetPending = false;
                root.rollbackRecoveryRequired = true;

                root.errorMessage =
                    "Rotation recovery refresh failed: "
                    + String(message || "unknown error");
                root.statusMessage =
                    "Rotation recovery still required.";

                root.failed(root.errorMessage);
                return;
            }

            if (!root.awaitingRefresh)
                return;

            root.awaitingRefresh = false;

            root.errorMessage =
                "Rotation transaction committed, but observed-state "
                + "refresh failed: " + String(message || "unknown error");

            root.statusMessage =
                "Applied rotation state could not be reconciled yet.";

            root.failed(root.errorMessage);
        }
    }

    Connections {
        target: root.draftStore

        function onRotationChanged() {
            root.clearTransientFeedback();
        }

        function onRotationResetCompleted() {
            root.clearTransientFeedback();
        }
    }
}
