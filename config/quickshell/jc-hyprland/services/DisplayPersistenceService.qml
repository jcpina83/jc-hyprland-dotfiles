import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var draftStore
    property var applyService

    property bool checking: false
    property bool saving: false
    property bool previewKnown: false
    property bool hasPersistentChanges: false

    property string previewText: ""
    property string errorMessage: ""
    property string statusMessage: ""
    property string lastBackup: ""

    readonly property bool busy: root.checking || root.saving

    readonly property bool canSave:
        root.previewKnown
        && root.hasPersistentChanges
        && !root.busy
        && root.draftStore
        && !root.draftStore.hasDirty
        && root.applyService
        && !root.applyService.busy
        && !root.applyService.pendingConfirmation

    signal previewUpdated(bool hasChanges)
    signal saved(string backup)
    signal failed(string message)

    function configHome() {
        const configured = Quickshell.env("XDG_CONFIG_HOME");

        if (configured !== null && String(configured).length > 0)
            return String(configured);

        const home = Quickshell.env("HOME");

        return String(home) + "/.config";
    }

    function displaycfgPath() {
        return root.configHome()
            + "/jc-hyprland-dotfiles/bin/jc-displaycfg";
    }

    function displayctlPath() {
        return root.configHome()
            + "/jc-hyprland-dotfiles/bin/jc-displayctl";
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

    function fail(message) {
        root.checking = false;
        root.saving = false;
        root.errorMessage = message;
        root.failed(message);
    }

    function refreshPreview() {
        if (root.busy)
            return;

        root.checking = true;
        root.errorMessage = "";

        previewProcess.exec([
            root.displaycfgPath(),
            "preview"
        ]);
    }

    function saveConfiguration(): void {
        root.errorMessage = "";

        if (root.busy)
            return;

        if (!root.draftStore) {
            root.fail("Display draft store is unavailable.");
            return;
        }

        if (root.draftStore.hasDirty) {
            root.fail(
                "Apply or reset draft display changes before saving."
            );
            return;
        }

        if (!root.applyService) {
            root.fail("Display apply service is unavailable.");
            return;
        }

        if (root.applyService.busy
                || root.applyService.pendingConfirmation) {
            root.fail(
                "Finish the current Safe Apply transaction before saving."
            );
            return;
        }

        if (!root.previewKnown || !root.hasPersistentChanges) {
            root.statusMessage = "Persistent display configuration is up to date.";
            root.refreshPreview();
            return;
        }

        // Re-check the external runtime transaction immediately before save.
        // This prevents a recovered/stale Safe Apply transaction from being
        // persisted only because QML had not observed it yet.
        root.saving = true;
        root.statusMessage = "Checking display transaction state…";

        preflightProcess.exec([
            root.displayctlPath(),
            "status"
        ]);
    }

    Connections {
        target: root.applyService

        function onPendingConfirmationChanged() {
            if (root.applyService
                    && !root.applyService.pendingConfirmation
                    && !root.busy) {
                root.refreshPreview();
            }
        }
    }

    Process {
        id: previewProcess

        stdout: StdioCollector {
            id: previewStdout
        }

        stderr: StdioCollector {
            id: previewStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = previewStdout.text.trim();
            const stderrText = previewStderr.text.trim();

            root.checking = false;

            if (exitCode !== 0) {
                root.previewKnown = false;
                root.hasPersistentChanges = false;

                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.errorMessage =
                    "Unable to inspect persistent display state"
                    + (details.length > 0 ? ": " + details : "");

                root.failed(root.errorMessage);
                return;
            }

            const unchanged =
                stdoutText === "No persistent display changes.";

            root.previewKnown = true;
            root.hasPersistentChanges = !unchanged;
            root.previewText = unchanged ? "" : stdoutText;
            root.errorMessage = "";

            if (unchanged) {
                root.statusMessage =
                    "Persistent display configuration is up to date.";
            } else {
                root.statusMessage =
                    "Runtime display state has unsaved persistent changes.";
            }

            root.previewUpdated(root.hasPersistentChanges);
        }
    }

    Process {
        id: preflightProcess

        stdout: StdioCollector {
            id: preflightStdout
        }

        stderr: StdioCollector {
            id: preflightStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = preflightStdout.text.trim();
            const stderrText = preflightStderr.text.trim();

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.fail(
                    "Unable to verify Safe Apply state before save"
                    + (details.length > 0 ? ": " + details : "")
                );
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!response) {
                root.fail(
                    "Unexpected displayctl status response before save: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );
                return;
            }

            if (response.status !== "idle") {
                root.fail(
                    "A Safe Apply transaction is still active. "
                    + "Confirm or rollback it before saving."
                );

                if (root.applyService)
                    root.applyService.recoverPending();

                return;
            }

            root.statusMessage = "Saving persistent display configuration…";

            saveProcess.exec([
                root.displaycfgPath(),
                "save"
            ]);
        }
    }

    Process {
        id: saveProcess

        stdout: StdioCollector {
            id: saveStdout
        }

        stderr: StdioCollector {
            id: saveStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = saveStdout.text.trim();
            const stderrText = saveStderr.text.trim();

            root.saving = false;

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.errorMessage =
                    "Unable to save persistent display configuration"
                    + (details.length > 0 ? ": " + details : "");

                root.failed(root.errorMessage);
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!response
                    || (response.status !== "saved"
                        && response.status !== "unchanged")) {
                root.fail(
                    "Unexpected jc-displaycfg save response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );
                return;
            }

            root.previewKnown = true;
            root.hasPersistentChanges = false;
            root.previewText = "";
            root.errorMessage = "";
            root.lastBackup = String(response.backup || "");

            if (response.status === "saved") {
                root.statusMessage =
                    "Display configuration saved to monitors.lua. "
                    + "A rollback backup was created.";
            } else {
                root.statusMessage =
                    "Persistent display configuration was already up to date.";
            }

            root.saved(root.lastBackup);
        }
    }
}
