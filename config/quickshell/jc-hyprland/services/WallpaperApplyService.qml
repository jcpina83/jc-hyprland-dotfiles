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
        && root.draftStore.hasDirty
        && !root.draftStore.observedChangedWhileDirty
        && !root.rollbackRecoveryRequired

    property bool applyingMain: false
    property bool applyingSecondary: false

    property string errorMessage: ""
    property string statusMessage: ""
    property var lastResult: null

    signal applied(bool mainChanged, bool secondaryChanged)
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
            && payload.status === "applied"
            && Boolean(payload.committed)
            && !Boolean(payload.rolledBack)
            && Boolean(payload.runtimeVerified)
            && payload.after;
    }

    function validRollbackResponse(payload) {
        return payload
            && payload.status === "rolled-back"
            && !Boolean(payload.committed)
            && Boolean(payload.rolledBack)
            && Boolean(payload.preferencesRestored)
            && Boolean(payload.runtimeRollbackVerified);
    }

    function validRollbackFailedResponse(payload) {
        return payload
            && payload.status === "rollback-failed"
            && !Boolean(payload.committed)
            && !Boolean(payload.rolledBack)
            && Boolean(payload.preferencesRestored)
            && !Boolean(payload.runtimeRollbackVerified);
    }

    function validInvalidRequestResponse(payload) {
        return payload
            && payload.status === "invalid-request"
            && !Boolean(payload.committed)
            && !Boolean(payload.rolledBack);
    }

    function validFitValue(value) {
        const fit = String(value || "");

        return fit === "cover"
            || fit === "contain"
            || fit === "stretch"
            || fit === "center";
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
                + "Reset the draft before applying.";
        }

        if (root.rollbackRecoveryRequired) {
            return "Wallpaper runtime recovery is required before "
                + "another Apply can be attempted.";
        }

        if (!root.draftStore.hasDirty)
            return "There are no wallpaper changes to apply.";

        if (root.draftStore.mainWallpaperDirty
                && String(root.draftStore.draftMainPath || "").length === 0) {
            return "MAIN wallpaper draft has no valid path.";
        }

        if (root.draftStore.secondaryWallpaperDirty
                && String(root.draftStore.draftSecondaryPath || "").length === 0) {
            return "SECONDARY wallpaper draft has no valid path.";
        }

        if (root.draftStore.mainFitDirty
                && !root.validFitValue(root.draftStore.draftMainFit)) {
            return "MAIN wallpaper fit draft is invalid.";
        }

        if (root.draftStore.secondaryFitDirty
                && !root.validFitValue(root.draftStore.draftSecondaryFit)) {
            return "SECONDARY wallpaper fit draft is invalid.";
        }

        return "";
    }

    function buildApplyArguments() {
        const args = [
            root.wallpaperctlPath(),
            "apply"
        ];

        if (root.draftStore && root.draftStore.mainWallpaperDirty) {
            args.push("--main");
            args.push(String(root.draftStore.draftMainPath || ""));
        }

        if (root.draftStore && root.draftStore.mainFitDirty) {
            args.push("--main-fit");
            args.push(String(root.draftStore.draftMainFit || ""));
        }

        if (root.draftStore && root.draftStore.secondaryWallpaperDirty) {
            args.push("--secondary");
            args.push(String(root.draftStore.draftSecondaryPath || ""));
        }

        if (root.draftStore && root.draftStore.secondaryFitDirty) {
            args.push("--secondary-fit");
            args.push(String(root.draftStore.draftSecondaryFit || ""));
        }

        args.push("--json");

        return args;
    }

    function clearApplyingTargets(): void {
        root.applyingMain = false;
        root.applyingSecondary = false;
    }

    function clearTransientFeedback(): void {
        if (root.busy || root.rollbackRecoveryRequired)
            return;

        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;
    }

    function resetDraft(): void {
        if (root.busy || !root.draftStore)
            return;

        if (!root.rollbackRecoveryRequired) {
            root.draftStore.reset();
            root.clearTransientFeedback();
            return;
        }

        if (!root.wallpaperService || root.wallpaperService.loading) {
            root.errorMessage =
                "Wallpaper recovery state cannot be refreshed right now.";
            root.statusMessage = "Recovery still required.";
            return;
        }

        root.recoveryResetPending = true;
        root.statusMessage =
            "Refreshing observed wallpaper state before Reset…";

        root.wallpaperService.refresh();
    }

    function fail(message): void {
        root.applying = false;
        root.awaitingRefresh = false;
        root.clearApplyingTargets();

        root.errorMessage =
            String(message || "Wallpaper Apply failed.");
        root.statusMessage = "";

        root.failed(root.errorMessage);
    }

    function refreshObservedPreservingDraft(): void {
        if (root.wallpaperService && !root.wallpaperService.loading)
            root.wallpaperService.refresh();
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

        root.applyingMain = Boolean(root.draftStore.mainDirty);
        root.applyingSecondary =
            Boolean(root.draftStore.secondaryDirty);

        root.applying = true;
        root.statusMessage = "Applying wallpaper draft…";

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
                        "Wallpaper Apply failed and runtime rollback "
                        + "could not be verified. Preferences were restored."
                        + (
                            backendMessage.length > 0
                                ? " " + backendMessage
                                : ""
                        );

                    root.statusMessage =
                        "Wallpaper recovery required; draft remains pending.";

                    root.clearApplyingTargets();
                    root.refreshObservedPreservingDraft();
                    root.rollbackFailed(root.errorMessage);
                    return;
                }

                if (root.validRollbackResponse(response)) {
                    const backendMessage =
                        String(response.message || "").trim();

                    root.errorMessage =
                        "Wallpaper Apply failed and the previous "
                        + "state was restored."
                        + (
                            backendMessage.length > 0
                                ? " " + backendMessage
                                : ""
                        );

                    root.rollbackRecoveryRequired = false;
                    root.statusMessage =
                        "Previous wallpaper state restored; "
                        + "draft remains pending.";

                    root.clearApplyingTargets();
                    root.refreshObservedPreservingDraft();
                    root.rolledBack(root.errorMessage);
                    return;
                }

                if (root.validInvalidRequestResponse(response)) {
                    root.rollbackRecoveryRequired = false;
                    root.fail(
                        "Wallpaper Apply request rejected: "
                        + String(response.message || "invalid request")
                    );
                    return;
                }

                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.rollbackRecoveryRequired = true;
                root.fail(
                    "Wallpaper Apply failed with unknown recovery state"
                    + (details.length > 0 ? ": " + details : "")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

            if (!root.validAppliedResponse(response)) {
                root.rollbackRecoveryRequired = true;
                root.fail(
                    "Unexpected jc-wallpaperctl Apply response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

            root.rollbackRecoveryRequired = false;
            root.errorMessage = "";
            root.statusMessage =
                "Wallpaper transaction committed. "
                + "Refreshing observed state…";

            root.draftStore.prepareForRefreshAfterApply();

            root.awaitingRefresh = true;
            root.wallpaperService.refresh();
        }
    }

    Connections {
        target: root.wallpaperService

        function onRefreshed() {
            if (root.recoveryResetPending) {
                root.recoveryResetPending = false;

                if (root.wallpaperService.runtimeMatchesConfigured) {
                    root.rollbackRecoveryRequired = false;
                    root.draftStore.reset();
                    root.clearTransientFeedback();
                    return;
                }

                root.rollbackRecoveryRequired = true;
                root.errorMessage =
                    "Wallpaper runtime still differs from configured state "
                    + "after refresh. Reset was not performed.";
                root.statusMessage =
                    "Wallpaper recovery still required.";
                root.failed(root.errorMessage);
                return;
            }

            if (!root.awaitingRefresh)
                return;

            const mainChanged = root.applyingMain;
            const secondaryChanged = root.applyingSecondary;

            root.awaitingRefresh = false;
            root.clearApplyingTargets();

            root.errorMessage = "";
            root.statusMessage =
                "Wallpaper changes applied and observed state reconciled.";

            root.applied(mainChanged, secondaryChanged);
        }

        function onFailed(message) {
            if (root.recoveryResetPending) {
                root.recoveryResetPending = false;
                root.rollbackRecoveryRequired = true;

                root.errorMessage =
                    "Wallpaper recovery refresh failed: "
                    + String(message || "unknown error");
                root.statusMessage =
                    "Wallpaper recovery still required.";

                root.failed(root.errorMessage);
                return;
            }

            if (!root.awaitingRefresh)
                return;

            root.awaitingRefresh = false;
            root.clearApplyingTargets();

            root.errorMessage =
                "Wallpaper transaction committed, but observed-state "
                + "refresh failed: " + String(message || "unknown error");

            root.statusMessage =
                "Applied state could not be reconciled yet.";

            root.failed(root.errorMessage);
        }
    }

    Connections {
        target: root.draftStore

        function onChanged() {
            root.clearTransientFeedback();
        }

        function onResetCompleted() {
            root.clearTransientFeedback();
        }
    }
}
