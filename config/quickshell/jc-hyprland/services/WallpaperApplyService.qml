import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var wallpaperService
    property var draftStore

    property bool applying: false
    property bool awaitingRefresh: false

    readonly property bool busy:
        root.applying || root.awaitingRefresh

    readonly property bool canApply:
        !root.busy
        && root.wallpaperService
        && root.wallpaperService.ready
        && !root.wallpaperService.loading
        && root.draftStore
        && root.draftStore.initialized
        && root.draftStore.hasDirty
        && !root.draftStore.observedChangedWhileDirty

    property bool applyingMain: false
    property bool applyingSecondary: false

    property string errorMessage: ""
    property string statusMessage: ""
    property var lastResult: null

    signal applied(bool mainChanged, bool secondaryChanged)
    signal rolledBack(string message)
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
            && Boolean(payload.rolledBack);
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

        if (!root.draftStore.hasDirty)
            return "There are no wallpaper changes to apply.";

        if (root.draftStore.mainDirty
                && String(root.draftStore.draftMainPath || "").length === 0) {
            return "MAIN wallpaper draft has no valid path.";
        }

        if (root.draftStore.secondaryDirty
                && String(root.draftStore.draftSecondaryPath || "").length === 0) {
            return "SECONDARY wallpaper draft has no valid path.";
        }

        return "";
    }

    function buildApplyArguments() {
        const args = [
            root.wallpaperctlPath(),
            "apply"
        ];

        if (root.draftStore && root.draftStore.mainDirty) {
            args.push("--main");
            args.push(String(root.draftStore.draftMainPath || ""));
        }

        if (root.draftStore && root.draftStore.secondaryDirty) {
            args.push("--secondary");
            args.push(String(root.draftStore.draftSecondaryPath || ""));
        }

        args.push("--json");

        return args;
    }

    function clearApplyingTargets(): void {
        root.applyingMain = false;
        root.applyingSecondary = false;
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

                    root.statusMessage =
                        "Previous wallpaper state restored; "
                        + "draft remains pending.";

                    root.clearApplyingTargets();
                    root.refreshObservedPreservingDraft();
                    root.rolledBack(root.errorMessage);
                    return;
                }

                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.fail(
                    "Wallpaper Apply failed"
                    + (details.length > 0 ? ": " + details : "")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

            if (!root.validAppliedResponse(response)) {
                root.fail(
                    "Unexpected jc-wallpaperctl Apply response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );

                root.refreshObservedPreservingDraft();
                return;
            }

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
}
