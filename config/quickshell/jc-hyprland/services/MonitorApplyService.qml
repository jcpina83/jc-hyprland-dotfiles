import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var monitorService
    property var draftStore

    property bool applying: false
    property string applyingOutput: ""
    property string errorMessage: ""
    property string statusMessage: ""
    property string lastAppliedOutput: ""

    signal applied(string output)
    signal failed(string message)

    function configHome() {
        const configured = Quickshell.env("XDG_CONFIG_HOME");

        if (configured !== null && String(configured).length > 0)
            return String(configured);

        const home = Quickshell.env("HOME");

        return String(home) + "/.config";
    }

    function displayctlPath() {
        return root.configHome()
            + "/jc-hyprland-dotfiles/bin/jc-displayctl";
    }

    function monitorFor(output) {
        if (!root.monitorService
                || !Array.isArray(root.monitorService.monitors)) {
            return null;
        }

        for (let i = 0; i < root.monitorService.monitors.length; ++i) {
            if (root.monitorService.monitors[i].output === output)
                return root.monitorService.monitors[i];
        }

        return null;
    }

    function sameNumber(left, right) {
        return Math.abs(Number(left) - Number(right)) < 0.0001;
    }

    function validateDraft(draft) {
        if (!draft)
            return "No display draft was selected.";

        const monitor = root.monitorFor(draft.output);

        if (!monitor)
            return "Output is no longer available: " + draft.output;

        if (monitor.disabled)
            return "Cannot apply a mode to a disabled output.";

        if (!draft.modeRaw || draft.modeRaw.length === 0)
            return "Draft has no valid monitor mode.";

        let modeExists = false;

        for (let i = 0; i < monitor.availableModes.length; ++i) {
            if (String(monitor.availableModes[i]) === draft.modeRaw) {
                modeExists = true;
                break;
            }
        }

        if (!modeExists) {
            return "Selected mode is no longer reported by "
                + draft.output + ": " + draft.modeRaw;
        }

        // Phase 1B.2 is intentionally limited to resolution + refresh.
        if (!root.sameNumber(draft.scale, draft.observed.scale)
                || Number(draft.transform) !== Number(draft.observed.transform)
                || Number(draft.x) !== Number(draft.observed.x)
                || Number(draft.y) !== Number(draft.observed.y)) {
            return "Phase 1B.2 only supports resolution and refresh changes.";
        }

        return "";
    }

    function applyDirty(): void {
        root.errorMessage = "";
        root.statusMessage = "";

        if (root.applying)
            return;

        if (!root.draftStore) {
            root.fail("Display draft store is unavailable.");
            return;
        }

        if (root.draftStore.observedChangedWhileDirty) {
            root.fail(
                "Hyprland state changed while editing. Reset the draft first."
            );
            return;
        }

        const dirty = root.draftStore.dirtyDrafts();

        if (dirty.length === 0) {
            root.fail("There are no display changes to apply.");
            return;
        }

        // First mutation milestone: one output per transaction.
        if (dirty.length !== 1) {
            root.fail(
                "Phase 1B.2 applies one monitor at a time. "
                + "Reset one draft before applying."
            );
            return;
        }

        const draft = dirty[0];
        const validationError = root.validateDraft(draft);

        if (validationError.length > 0) {
            root.fail(validationError);
            return;
        }

        const runtimeMode = String(draft.modeRaw).replace(/Hz$/, "");

        root.applying = true;
        root.applyingOutput = draft.output;

        applyProcess.exec([
            root.displayctlPath(),
            "apply",
            "--output",
            draft.output,
            "--mode",
            runtimeMode
        ]);
    }

    function fail(message) {
        root.applying = false;
        root.applyingOutput = "";
        root.errorMessage = message;
        root.failed(message);
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
            const output = root.applyingOutput;
            const stdoutText = applyStdout.text.trim();
            const stderrText = applyStderr.text.trim();

            root.applying = false;
            root.applyingOutput = "";

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.errorMessage =
                    "Display apply failed"
                    + (details.length > 0 ? ": " + details : "");

                root.failed(root.errorMessage);
                return;
            }

            if (stdoutText !== "ok") {
                root.errorMessage =
                    "Unexpected displayctl response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");

                root.failed(root.errorMessage);
                return;
            }

            root.errorMessage = "";
            root.lastAppliedOutput = output;
            root.statusMessage =
                "Runtime mode applied to " + output
                + ". Persistent monitors.conf was not modified.";

            // Allow the refreshed observed snapshot to replace the accepted draft.
            root.draftStore.prepareForRefreshAfterApply();
            root.monitorService.refresh();

            root.applied(output);
        }
    }
}
