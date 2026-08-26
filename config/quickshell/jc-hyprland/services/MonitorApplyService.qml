import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var monitorService
    property var draftStore

    property int confirmationTimeoutSeconds: 15

    property bool applying: false
    property bool keeping: false
    property bool rollingBack: false

    readonly property bool busy:
        root.applying || root.keeping || root.rollingBack

    property bool pendingConfirmation: false
    property string pendingToken: ""
    property string pendingOutput: ""
    property double pendingDeadlineEpoch: 0
    property int remainingSeconds: 0

    property string applyingOutput: ""
    property string errorMessage: ""
    property string statusMessage: ""
    property string lastAppliedOutput: ""

    signal temporaryApplied(string output)
    signal kept(string output)
    signal rolledBack(string output)
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

        const targetEnabled = Boolean(draft.enabled);

        if (!targetEnabled) {
            if (root.draftStore.activeDraftCount < 1)
                return "At least one display must remain active.";

            if (root.monitorService.focusedOutputName === draft.output) {
                return "Focus another display before disabling "
                    + draft.output + ".";
            }

            return "";
        }

        if (!draft.modeRaw || draft.modeRaw.length === 0)
            return "Enabled draft has no valid monitor mode.";

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

        const scale = Number(draft.scale);
        const transform = Number(draft.transform);

        if (!Number.isFinite(scale) || scale <= 0)
            return "Display scale must be a positive number.";

        const logicalWidth = Number(draft.width) / scale;
        const logicalHeight = Number(draft.height) / scale;

        if (!root.sameNumber(logicalWidth, Math.round(logicalWidth))
                || !root.sameNumber(logicalHeight, Math.round(logicalHeight))) {
            return "Selected scale does not produce whole logical pixels.";
        }

        if (!Number.isInteger(transform)
                || transform < 0
                || transform > 7) {
            return "Display transform must be an integer from 0 to 7.";
        }

        if (!Number.isInteger(Number(draft.x))
                || !Number.isInteger(Number(draft.y))) {
            return "Display position must use integer logical coordinates.";
        }

        if (!root.draftStore.topologyValid)
            return root.draftStore.topologyError;

        return "";
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

    function updateCountdown() {
        if (!root.pendingConfirmation) {
            root.remainingSeconds = 0;
            return;
        }

        const nowSeconds = Math.floor(Date.now() / 1000);
        const remaining =
            Math.ceil(root.pendingDeadlineEpoch - nowSeconds);

        root.remainingSeconds = Math.max(0, remaining);

        if (root.remainingSeconds <= 0 && !root.rollingBack)
            root.rollbackPending("timeout");
    }

    function setPending(response) {
        root.pendingConfirmation = true;
        root.pendingToken = String(response.token || "");
        root.pendingOutput = String(response.output || "");
        root.pendingDeadlineEpoch = Number(response.deadline || 0);

        root.updateCountdown();
    }

    function clearPending() {
        root.pendingConfirmation = false;
        root.pendingToken = "";
        root.pendingOutput = "";
        root.pendingDeadlineEpoch = 0;
        root.remainingSeconds = 0;
    }

    function recoverPending() {
        if (root.applying || root.keeping || root.rollingBack)
            return;

        statusProcess.exec([
            root.displayctlPath(),
            "status"
        ]);
    }

    function applyDirty(): void {
        root.errorMessage = "";
        root.statusMessage = "";

        if (root.busy || root.pendingConfirmation)
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

        if (dirty.length !== 1) {
            root.fail(
                "Safe Apply changes one monitor at a time. "
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
            "safe-apply",
            "--output",
            draft.output,
            "--mode",
            runtimeMode,
            "--enabled",
            draft.enabled ? "true" : "false",
            "--scale",
            String(draft.scale),
            "--transform",
            String(draft.transform),
            "--position",
            String(draft.x) + "x" + String(draft.y),
            "--timeout",
            String(root.confirmationTimeoutSeconds)
        ]);
    }

    function keepPending(): void {
        if (!root.pendingConfirmation || root.busy)
            return;

        root.errorMessage = "";
        root.keeping = true;

        keepProcess.exec([
            root.displayctlPath(),
            "keep",
            "--token",
            root.pendingToken
        ]);
    }

    function rollbackPending(reason): void {
        if (!root.pendingConfirmation || root.busy)
            return;

        root.errorMessage = "";
        root.rollingBack = true;

        if (reason === "timeout") {
            root.statusMessage =
                "Confirmation timed out. Restoring previous display state…";
        } else {
            root.statusMessage =
                "Restoring previous display state…";
        }

        rollbackProcess.exec([
            root.displayctlPath(),
            "rollback",
            "--token",
            root.pendingToken
        ]);
    }

    function fail(message) {
        root.applying = false;
        root.keeping = false;
        root.rollingBack = false;
        root.applyingOutput = "";
        root.errorMessage = message;
        root.failed(message);
    }

    Timer {
        interval: 250
        repeat: true
        running: root.pendingConfirmation

        onTriggered: root.updateCountdown()
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
                    "Safe Apply failed"
                    + (details.length > 0 ? ": " + details : "");

                root.failed(root.errorMessage);
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!response || response.status !== "pending") {
                root.errorMessage =
                    "Unexpected displayctl Safe Apply response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");

                root.failed(root.errorMessage);
                return;
            }

            root.setPending(response);
            root.errorMessage = "";
            root.lastAppliedOutput = output;
            root.statusMessage =
                "Temporary runtime display state applied to " + output
                + ". Confirm it before automatic rollback.";

            // The target mode is now the observed runtime state. The backend,
            // not the draft, owns the rollback snapshot during confirmation.
            root.draftStore.prepareForRefreshAfterApply();
            root.monitorService.refresh();

            root.temporaryApplied(output);
        }
    }

    Process {
        id: keepProcess

        stdout: StdioCollector {
            id: keepStdout
        }

        stderr: StdioCollector {
            id: keepStderr
        }

        onExited: (exitCode, exitStatus) => {
            const output = root.pendingOutput;
            const stdoutText = keepStdout.text.trim();
            const stderrText = keepStderr.text.trim();

            root.keeping = false;

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.errorMessage =
                    "Unable to keep display mode"
                    + (details.length > 0 ? ": " + details : "");

                root.failed(root.errorMessage);
                root.recoverPending();
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!response) {
                root.fail(
                    "Unexpected displayctl Keep response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );
                return;
            }

            if (response.status === "busy") {
                root.statusMessage =
                    "Safe Apply transaction is being finalized.";
                root.recoverPending();
                return;
            }

            if (response.status === "idle") {
                root.clearPending();
                root.statusMessage =
                    "Safe Apply transaction already completed. "
                    + "Refreshing observed state.";
                root.monitorService.refresh();
                return;
            }

            if (response.status !== "kept") {
                root.fail(
                    "Unexpected displayctl Keep status: "
                    + String(response.status)
                );
                return;
            }

            root.clearPending();
            root.errorMessage = "";
            root.statusMessage =
                "Runtime display state kept for " + output
                + ". Persistent monitors.conf is still unchanged.";

            root.monitorService.refresh();
            root.kept(output);
        }
    }

    Process {
        id: rollbackProcess

        stdout: StdioCollector {
            id: rollbackStdout
        }

        stderr: StdioCollector {
            id: rollbackStderr
        }

        onExited: (exitCode, exitStatus) => {
            const output = root.pendingOutput;
            const stdoutText = rollbackStdout.text.trim();
            const stderrText = rollbackStderr.text.trim();

            root.rollingBack = false;

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.errorMessage =
                    "Display rollback failed"
                    + (details.length > 0 ? ": " + details : "");

                root.failed(root.errorMessage);
                root.recoverPending();
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!response) {
                root.fail(
                    "Unexpected displayctl Rollback response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>")
                );
                return;
            }

            if (response.status === "busy") {
                root.statusMessage =
                    "Rollback is already being processed.";
                root.recoverPending();
                return;
            }

            if (response.status !== "rolled-back"
                    && response.status !== "idle") {
                root.fail(
                    "Unexpected displayctl Rollback status: "
                    + String(response.status)
                );
                return;
            }

            root.clearPending();
            root.errorMessage = "";
            root.statusMessage =
                "Previous runtime display state restored for " + output + ".";

            root.monitorService.refresh();
            root.rolledBack(output);
        }
    }

    Process {
        id: statusProcess

        stdout: StdioCollector {
            id: statusStdout
        }

        stderr: StdioCollector {
            id: statusStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = statusStdout.text.trim();

            if (exitCode !== 0)
                return;

            const response = root.parseResponse(stdoutText);

            if (!response)
                return;

            if (response.status === "pending") {
                root.setPending(response);
                root.statusMessage =
                    "Recovered pending Safe Apply for "
                    + root.pendingOutput + ".";
                return;
            }

            if (response.status === "idle" && root.pendingConfirmation) {
                root.clearPending();
                root.monitorService.refresh();
            }
        }
    }

    Component.onCompleted: root.recoverPending()
}
