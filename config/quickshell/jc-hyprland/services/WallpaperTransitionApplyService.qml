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
        && root.draftStore.transitionDirty
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

    function validTransitionStatus(payload) {
        return payload
            && typeof payload.preset === "string"
            && typeof payload.resolvedPreset === "string"
            && payload.overrides
            && (
                payload.overrides.type === null
                || typeof payload.overrides.type === "string"
            )
            && (
                payload.overrides.duration === null
                || typeof payload.overrides.duration === "number"
            )
            && (
                payload.overrides.fps === null
                || typeof payload.overrides.fps === "number"
            )
            && payload.effective
            && typeof payload.effective.type === "string"
            && typeof payload.effective.duration === "number"
            && typeof payload.effective.fps === "number";
    }

    function optionalString(value) {
        if (value === null || value === undefined)
            return null;

        return String(value);
    }

    function optionalNumber(value) {
        if (value === null || value === undefined)
            return null;

        return Number(value);
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
            return "Transition runtime recovery is required before "
                + "another Apply can be attempted.";
        }

        if (!root.draftStore.transitionDirty)
            return "There are no transition changes to apply.";

        if (root.draftStore.transitionPresetDirty
                && !root.draftStore.validTransitionPreset(
                    root.draftStore.draftTransitionPreset
                )) {
            return "Wallpaper transition preset draft is invalid.";
        }

        if (root.draftStore.transitionTypeDirty
                && root.draftStore.draftTransitionTypeOverride !== null
                && !root.draftStore.validTransitionType(
                    root.draftStore.draftTransitionTypeOverride
                )) {
            return "Wallpaper transition type draft is invalid.";
        }

        if (root.draftStore.transitionDurationDirty
                && root.draftStore.draftTransitionDurationOverride !== null) {
            const duration =
                Number(root.draftStore.draftTransitionDurationOverride);

            if (!isFinite(duration) || duration <= 0)
                return "Wallpaper transition duration draft is invalid.";
        }

        if (root.draftStore.transitionFpsDirty
                && root.draftStore.draftTransitionFpsOverride !== null) {
            const fps = Number(root.draftStore.draftTransitionFpsOverride);

            if (!isFinite(fps)
                    || fps <= 0
                    || Math.floor(fps) !== fps) {
                return "Wallpaper transition FPS draft is invalid.";
            }
        }

        return "";
    }

    function buildApplyArguments() {
        const args = [
            root.wallpaperctlPath(),
            "transition",
            "apply"
        ];

        if (root.draftStore && root.draftStore.transitionPresetDirty) {
            args.push("--preset");
            args.push(String(root.draftStore.draftTransitionPreset || ""));
        }

        if (root.draftStore && root.draftStore.transitionTypeDirty) {
            args.push("--type");
            args.push(
                root.draftStore.draftTransitionTypeOverride === null
                    ? "inherit"
                    : String(root.draftStore.draftTransitionTypeOverride)
            );
        }

        if (root.draftStore && root.draftStore.transitionDurationDirty) {
            args.push("--duration");
            args.push(
                root.draftStore.draftTransitionDurationOverride === null
                    ? "inherit"
                    : String(root.draftStore.draftTransitionDurationOverride)
            );
        }

        if (root.draftStore && root.draftStore.transitionFpsDirty) {
            args.push("--fps");
            args.push(
                root.draftStore.draftTransitionFpsOverride === null
                    ? "inherit"
                    : String(root.draftStore.draftTransitionFpsOverride)
            );
        }

        args.push("--json");

        return args;
    }

    function buildRecoveryArguments() {
        return [
            root.wallpaperctlPath(),
            "transition",
            "apply",
            "--preset",
            String(root.wallpaperService.transitionPreset || "theme"),
            "--type",
            root.wallpaperService.transitionTypeOverride === null
                ? "inherit"
                : String(root.wallpaperService.transitionTypeOverride),
            "--duration",
            root.wallpaperService.transitionDurationOverride === null
                ? "inherit"
                : String(root.wallpaperService.transitionDurationOverride),
            "--fps",
            root.wallpaperService.transitionFpsOverride === null
                ? "inherit"
                : String(root.wallpaperService.transitionFpsOverride),
            "--json"
        ];
    }

    function responseMatchesDraft(response) {
        if (!root.validTransitionStatus(response) || !root.draftStore)
            return false;

        if (root.draftStore.transitionPresetDirty
                && String(response.preset || "")
                    !== String(root.draftStore.draftTransitionPreset || "")) {
            return false;
        }

        if (root.draftStore.transitionTypeDirty
                && root.optionalString(response.overrides.type)
                    !== root.optionalString(
                        root.draftStore.draftTransitionTypeOverride
                    )) {
            return false;
        }

        if (root.draftStore.transitionDurationDirty
                && root.optionalNumber(response.overrides.duration)
                    !== root.optionalNumber(
                        root.draftStore.draftTransitionDurationOverride
                    )) {
            return false;
        }

        if (root.draftStore.transitionFpsDirty
                && root.optionalNumber(response.overrides.fps)
                    !== root.optionalNumber(
                        root.draftStore.draftTransitionFpsOverride
                    )) {
            return false;
        }

        return true;
    }

    function observedMatchesStatus(response) {
        if (!root.validTransitionStatus(response)
                || !root.wallpaperService
                || !root.wallpaperService.ready) {
            return false;
        }

        return String(root.wallpaperService.transitionPreset || "")
                === String(response.preset || "")
            && String(root.wallpaperService.transitionResolvedPreset || "")
                === String(response.resolvedPreset || "")
            && root.optionalString(
                    root.wallpaperService.transitionTypeOverride
                ) === root.optionalString(response.overrides.type)
            && root.optionalNumber(
                    root.wallpaperService.transitionDurationOverride
                ) === root.optionalNumber(response.overrides.duration)
            && root.optionalNumber(
                    root.wallpaperService.transitionFpsOverride
                ) === root.optionalNumber(response.overrides.fps)
            && String(root.wallpaperService.transitionEffectiveType || "")
                === String(response.effective.type || "")
            && Number(
                    root.wallpaperService.transitionEffectiveDuration || 0
                ) === Number(response.effective.duration || 0)
            && Number(
                    root.wallpaperService.transitionEffectiveFps || 0
                ) === Number(response.effective.fps || 0);
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

    function fail(message): void {
        root.applying = false;
        root.awaitingRefresh = false;

        root.errorMessage =
            String(message || "Wallpaper transition Apply failed.");
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
        root.statusMessage = "Applying wallpaper transition draft…";

        applyProcess.exec(root.buildApplyArguments());
    }

    function resetDraft(): void {
        if (root.busy || !root.draftStore)
            return;

        if (!root.rollbackRecoveryRequired) {
            root.draftStore.resetTransition();
            root.clearTransientFeedback();
            return;
        }

        if (!root.wallpaperService
                || !root.wallpaperService.ready
                || root.wallpaperService.loading) {
            root.errorMessage =
                "Transition recovery state cannot be re-applied right now.";
            root.statusMessage = "Transition recovery still required.";
            return;
        }

        root.recoveryResetPending = true;
        root.errorMessage = "";
        root.statusMessage =
            "Re-applying observed transition state before Reset…";

        recoveryProcess.exec(root.buildRecoveryArguments());
    }

    function startRecoveryRefresh(status): void {
        if (root.validTransitionStatus(status))
            root.lastResult = status;

        root.draftStore.prepareForRefreshAfterTransitionApply();
        root.awaitingRefresh = true;
        root.wallpaperService.refresh();
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
            const details = stderrText.length > 0
                ? stderrText
                : stdoutText;

            root.applying = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                if (exitCode === 6) {
                    root.rollbackRecoveryRequired = false;
                    root.errorMessage =
                        "Transition Apply failed and the previous "
                        + "state was restored.";
                    root.statusMessage =
                        "Previous transition state restored; "
                        + "draft remains pending.";

                    root.refreshObservedPreservingDraft();
                    root.rolledBack(root.errorMessage);
                    return;
                }

                if (exitCode === 7) {
                    root.rollbackRecoveryRequired = true;
                    root.errorMessage =
                        "Transition Apply failed and runtime rollback "
                        + "could not be verified."
                        + (
                            details.length > 0
                                ? " " + details
                                : ""
                        );
                    root.statusMessage =
                        "Transition recovery required; draft remains pending.";

                    root.refreshObservedPreservingDraft();
                    root.rollbackFailed(root.errorMessage);
                    return;
                }

                root.rollbackRecoveryRequired = true;
                root.fail(
                    "Transition Apply failed with unknown recovery state"
                    + (details.length > 0 ? ": " + details : "")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

            if (!root.validTransitionStatus(response)
                    || !root.responseMatchesDraft(response)) {
                root.rollbackRecoveryRequired = true;
                root.fail(
                    "Unexpected jc-wallpaperctl transition Apply response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

            root.rollbackRecoveryRequired = false;
            root.errorMessage = "";
            root.statusMessage =
                "Transition transaction committed. "
                + "Refreshing observed state…";

            root.draftStore.prepareForRefreshAfterTransitionApply();

            root.awaitingRefresh = true;
            root.wallpaperService.refresh();
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
            const details = stderrText.length > 0
                ? stderrText
                : stdoutText;

            if (!root.recoveryResetPending)
                return;

            if (exitCode !== 0) {
                root.recoveryResetPending = false;
                root.awaitingRefresh = false;
                root.rollbackRecoveryRequired = true;

                if (exitCode === 6) {
                    root.errorMessage =
                        "Transition recovery re-apply failed. "
                        + "The recovery attempt rolled back successfully, "
                        + "but the previously unverified runtime state "
                        + "remains unresolved.";
                    root.statusMessage =
                        "Transition recovery still required.";
                    root.rolledBack(root.errorMessage);
                    return;
                }

                if (exitCode === 7) {
                    root.errorMessage =
                        "Transition recovery re-apply failed and runtime "
                        + "rollback still could not be verified."
                        + (details.length > 0 ? " " + details : "");
                    root.statusMessage =
                        "Transition recovery still required.";
                    root.rollbackFailed(root.errorMessage);
                    return;
                }

                root.errorMessage =
                    "Transition recovery re-apply failed"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage =
                    "Transition recovery still required.";
                root.failed(root.errorMessage);
                return;
            }

            if (!root.validTransitionStatus(response)) {
                root.recoveryResetPending = false;
                root.awaitingRefresh = false;
                root.rollbackRecoveryRequired = true;
                root.errorMessage =
                    "Transition recovery returned an unexpected response.";
                root.statusMessage = "Transition recovery still required.";
                root.failed(root.errorMessage);
                return;
            }

            root.statusMessage =
                "Transition recovery transaction committed. "
                + "Refreshing observed state…";

            root.startRecoveryRefresh(response);
        }
    }

    Connections {
        target: root.wallpaperService

        function onRefreshed() {
            if (root.recoveryResetPending) {
                if (!root.awaitingRefresh)
                    return;

                root.awaitingRefresh = false;
                root.recoveryResetPending = false;
                root.rollbackRecoveryRequired = false;

                root.draftStore.resetTransition();
                root.clearTransientFeedback();
                return;
            }

            if (!root.awaitingRefresh)
                return;

            root.awaitingRefresh = false;

            if (!root.observedMatchesStatus(root.lastResult)) {
                root.errorMessage =
                    "Transition transaction committed, but observed state "
                    + "does not match the committed transition snapshot.";
                root.statusMessage =
                    "Applied transition state could not be reconciled.";
                root.failed(root.errorMessage);
                return;
            }

            root.errorMessage = "";
            root.statusMessage =
                "Transition changes applied and observed state reconciled.";

            root.applied();
        }

        function onFailed(message) {
            if (root.recoveryResetPending) {
                root.recoveryResetPending = false;
                root.awaitingRefresh = false;
                root.rollbackRecoveryRequired = true;

                root.errorMessage =
                    "Transition recovery refresh failed: "
                    + String(message || "unknown error");
                root.statusMessage =
                    "Transition recovery still required.";

                root.failed(root.errorMessage);
                return;
            }

            if (!root.awaitingRefresh)
                return;

            root.awaitingRefresh = false;

            root.errorMessage =
                "Transition transaction committed, but observed-state "
                + "refresh failed: " + String(message || "unknown error");

            root.statusMessage =
                "Applied transition state could not be reconciled yet.";

            root.failed(root.errorMessage);
        }
    }

    Connections {
        target: root.draftStore

        function onTransitionChanged() {
            root.clearTransientFeedback();
        }

        function onTransitionResetCompleted() {
            root.clearTransientFeedback();
        }
    }
}
