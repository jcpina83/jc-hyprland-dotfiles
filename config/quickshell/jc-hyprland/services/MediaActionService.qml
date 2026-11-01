import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Phase 2F.3b mutation boundary.
    //
    // This service invokes only the stable jc-media CLI. MPRIS player
    // selection and PipeWire default-sink resolution remain owned by jc-media.

    property var mediaService

    property bool applying: false
    property bool awaitingRefresh: false
    property bool postActionRefreshIssued: false
    property bool pendingMutationSucceeded: false

    // Action execution is normally sub-second. Observed-state reconciliation
    // must never hold the transport controls indefinitely if a backend status
    // probe stalls during an MPRIS track transition.
    property int reconciliationTimeoutMs: 2500

    property string pendingAction: ""
    property string errorMessage: ""
    property string statusMessage: ""
    property var lastResult: null

    readonly property bool busy:
        root.applying || root.awaitingRefresh

    // Keep capability presentation stable while the 1 s observer refresh is
    // in flight. MediaService preserves the last committed good snapshot while
    // loading, so transient loading is not an availability boundary.
    readonly property bool observedReady:
        root.mediaService
        && root.mediaService.ready
        && root.mediaService.observedHealthy

    readonly property bool canPlayPause:
        !root.busy
        && root.observedReady
        && root.mediaService.playerAvailable
        && (
            (
                root.mediaService.playbackStatus === "Playing"
                && root.mediaService.canPause === true
            )
            || (
                root.mediaService.playbackStatus !== "Playing"
                && root.mediaService.canPlay === true
            )
        )

    readonly property bool canNext:
        !root.busy
        && root.observedReady
        && root.mediaService.playerAvailable
        && root.mediaService.canGoNext === true

    readonly property bool canPrevious:
        !root.busy
        && root.observedReady
        && root.mediaService.playerAvailable
        && root.mediaService.canGoPrevious === true

    readonly property bool canSeek:
        !root.busy
        && root.observedReady
        && root.mediaService.playerAvailable
        && root.mediaService.canSeek === true

    readonly property bool canSetSinkVolume:
        !root.busy
        && root.observedReady
        && root.mediaService.sinkAvailable

    readonly property bool canSetSinkMute:
        !root.busy
        && root.observedReady
        && root.mediaService.sinkAvailable

    signal actionApplied(string action)
    signal failed(string action, string message)

    function mediaCommandPath() {
        if (root.mediaService
                && typeof root.mediaService.mediaCommandPath === "function") {
            return root.mediaService.mediaCommandPath();
        }

        const configured = Quickshell.env("XDG_CONFIG_HOME");
        const home = Quickshell.env("HOME");
        const base = configured
            ? String(configured)
            : String(home || "") + "/.config";

        return base + "/jc-hyprland-dotfiles/bin/jc-media";
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

    function validAppliedResponse(payload, expectedAction) {
        return payload
            && Number(payload.schemaVersion) === 1
            && payload.status === "applied"
            && payload.action === expectedAction
            && payload.applied === true
            && payload.target
            && typeof payload.target === "object"
            && typeof payload.target.kind === "string"
            && typeof payload.message === "string";
    }

    function reject(action, message): void {
        root.errorMessage = String(message || "Media action is unavailable.");
        root.statusMessage = "";
        root.lastResult = null;
        root.failed(String(action || ""), root.errorMessage);
    }

    function clearTransientFeedback(): void {
        if (root.busy)
            return;

        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;
    }

    // `arguments` is the implicit JavaScript Arguments object in QML methods.
    // Keep the explicit command vector under a distinct identifier.
    function dispatchAction(action, commandArguments, statusText): void {
        root.errorMessage = "";
        root.statusMessage = "";
        root.lastResult = null;

        if (root.busy)
            return;

        const command = [root.mediaCommandPath()];

        for (let index = 0; index < commandArguments.length; ++index)
            command.push(String(commandArguments[index]));

        command.push("--json");

        root.pendingAction = String(action);
        root.pendingMutationSucceeded = false;
        root.applying = true;
        root.statusMessage = String(statusText || "Applying media action…");

        actionProcess.command = command;
        actionProcess.running = true;
    }

    function playPause(): void {
        const action = "player.play-pause";

        if (!root.canPlayPause) {
            root.reject(action, "Play / Pause is unavailable for this player.");
            return;
        }

        root.dispatchAction(
            action,
            ["player", "play-pause"],
            "Applying Play / Pause…"
        );
    }

    function next(): void {
        const action = "player.next";

        if (!root.canNext) {
            root.reject(action, "Next is unavailable for this player.");
            return;
        }

        root.dispatchAction(
            action,
            ["player", "next"],
            "Advancing to next media item…"
        );
    }

    function previous(): void {
        const action = "player.previous";

        if (!root.canPrevious) {
            root.reject(action, "Previous is unavailable for this player.");
            return;
        }

        root.dispatchAction(
            action,
            ["player", "previous"],
            "Returning to previous media item…"
        );
    }

    function seekTo(seconds): void {
        const action = "player.seek";
        const target = Number(seconds);

        if (!root.canSeek) {
            root.reject(action, "Seek is unavailable for this player.");
            return;
        }

        if (!isFinite(target) || target < 0) {
            root.reject(action, "Seek target must be a non-negative number.");
            return;
        }

        root.dispatchAction(
            action,
            ["player", "seek", String(target)],
            "Seeking media position…"
        );
    }

    function setSinkVolume(value): void {
        const action = "audio.sink-volume";
        const target = Number(value);

        if (!root.canSetSinkVolume) {
            root.reject(action, "Output volume control is unavailable.");
            return;
        }

        if (!isFinite(target) || target < 0 || target > 1) {
            root.reject(action, "Output volume must be within 0..1.");
            return;
        }

        root.dispatchAction(
            action,
            ["audio", "sink-volume", String(target)],
            "Updating output volume…"
        );
    }

    function setSinkMute(mode): void {
        const action = "audio.sink-mute";
        const requested = String(mode || "");

        if (!root.canSetSinkMute) {
            root.reject(action, "Output mute control is unavailable.");
            return;
        }

        if (requested !== "on"
                && requested !== "off"
                && requested !== "toggle") {
            root.reject(action, "Output mute mode must be on, off or toggle.");
            return;
        }

        root.dispatchAction(
            action,
            ["audio", "sink-mute", requested],
            requested === "off"
                ? "Unmuting output…"
                : requested === "on"
                    ? "Muting output…"
                    : "Toggling output mute…"
        );
    }

    function issuePostActionRefresh(): void {
        if (!root.awaitingRefresh || !root.mediaService)
            return;

        root.postActionRefreshIssued = true;
        root.statusMessage = "Refreshing observed media state…";
        root.mediaService.refresh();
    }

    function beginObservedReconciliation(): void {
        if (!root.mediaService) {
            const action = root.pendingAction;

            root.awaitingRefresh = false;
            root.errorMessage =
                "Media observed-state service is unavailable for reconciliation.";
            root.statusMessage = "";
            root.pendingAction = "";
            root.pendingMutationSucceeded = false;
            root.failed(action, root.errorMessage);
            return;
        }

        root.awaitingRefresh = true;
        root.postActionRefreshIssued = false;
        reconciliationWatchdog.restart();

        if (!root.mediaService.loading)
            root.issuePostActionRefresh();
    }

    function releaseReconciliationAfterTimeout(): void {
        if (!root.awaitingRefresh)
            return;

        const action = root.pendingAction;
        const mutationSucceeded = root.pendingMutationSucceeded;

        root.awaitingRefresh = false;
        root.postActionRefreshIssued = false;
        root.pendingMutationSucceeded = false;
        root.pendingAction = "";

        if (mutationSucceeded) {
            root.errorMessage = "";
            root.statusMessage =
                "Media action applied; observed-state refresh is delayed.";
            root.actionApplied(action);
            return;
        }

        if (root.errorMessage.length === 0) {
            root.errorMessage =
                "Media action failed; observed-state refresh timed out.";
        }

        root.statusMessage =
            "Media observed-state refresh timed out.";
        root.failed(action, root.errorMessage);
    }

    function finishObservedReconciliation(): void {
        if (!root.awaitingRefresh)
            return;

        reconciliationWatchdog.stop();

        const action = root.pendingAction;
        const mutationSucceeded = root.pendingMutationSucceeded;

        root.awaitingRefresh = false;
        root.postActionRefreshIssued = false;
        root.pendingMutationSucceeded = false;
        root.pendingAction = "";

        if (!mutationSucceeded) {
            root.statusMessage =
                "Media request failed; observed state refreshed.";
            root.failed(
                action,
                root.errorMessage.length > 0
                    ? root.errorMessage
                    : "Media action failed."
            );
            return;
        }

        if (!root.mediaService
                || !root.mediaService.ready
                || !root.mediaService.observedHealthy) {
            root.errorMessage =
                "Media action completed, but observed state is not healthy "
                + "after refresh.";
            root.statusMessage =
                "Media observed-state reconciliation failed.";
            root.failed(action, root.errorMessage);
            return;
        }

        root.errorMessage = "";
        root.statusMessage =
            "Media action applied and observed state reconciled.";
        root.actionApplied(action);
    }

    function handleObservedRefreshFailure(message): void {
        if (!root.awaitingRefresh)
            return;

        reconciliationWatchdog.stop();

        const action = root.pendingAction;
        const mutationSucceeded = root.pendingMutationSucceeded;

        root.awaitingRefresh = false;
        root.postActionRefreshIssued = false;
        root.pendingMutationSucceeded = false;
        root.pendingAction = "";

        if (mutationSucceeded) {
            root.errorMessage =
                "Media action was applied, but observed-state refresh failed: "
                + String(message || "unknown error");
        } else if (root.errorMessage.length === 0) {
            root.errorMessage =
                "Media action failed and observed-state refresh also failed: "
                + String(message || "unknown error");
        } else {
            root.errorMessage +=
                " Observed-state refresh also failed: "
                + String(message || "unknown error");
        }

        root.statusMessage =
            "Media state could not be reconciled.";
        root.failed(action, root.errorMessage);
    }

    Timer {
        id: reconciliationWatchdog

        interval: root.reconciliationTimeoutMs
        repeat: false

        onTriggered: root.releaseReconciliationAfterTimeout()
    }

    Process {
        id: actionProcess

        stdout: StdioCollector {
            id: actionStdout
        }

        stderr: StdioCollector {
            id: actionStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = String(actionStdout.text || "").trim();
            const stderrText = String(actionStderr.text || "").trim();
            const response = root.parseResponse(stdoutText);
            const action = root.pendingAction;

            root.applying = false;
            root.lastResult = response;

            if (exitCode !== 0) {
                const responseMessage =
                    response && typeof response.message === "string"
                        ? response.message
                        : "";
                const details = responseMessage.length > 0
                    ? responseMessage
                    : stderrText.length > 0
                        ? stderrText
                        : stdoutText;

                root.pendingMutationSucceeded = false;
                root.errorMessage =
                    "Media action failed"
                    + (details.length > 0 ? ": " + details : "");
                root.statusMessage =
                    "Refreshing observed media state…";
                root.beginObservedReconciliation();
                return;
            }

            if (!root.validAppliedResponse(response, action)) {
                root.pendingMutationSucceeded = false;
                root.errorMessage =
                    "Unexpected media action response: "
                    + (stdoutText.length > 0 ? stdoutText : "<empty>");
                root.statusMessage =
                    "Refreshing observed media state…";
                root.beginObservedReconciliation();
                return;
            }

            root.pendingMutationSucceeded = true;
            root.errorMessage = "";
            root.statusMessage =
                "Media action verified. Refreshing observed state…";
            root.beginObservedReconciliation();
        }
    }

    Connections {
        target: root.mediaService

        function onRefreshed() {
            if (!root.awaitingRefresh)
                return;

            if (!root.postActionRefreshIssued) {
                Qt.callLater(root.issuePostActionRefresh);
                return;
            }

            Qt.callLater(root.finishObservedReconciliation);
        }

        function onRefreshFailed(message) {
            if (!root.awaitingRefresh)
                return;

            if (!root.postActionRefreshIssued) {
                Qt.callLater(root.issuePostActionRefresh);
                return;
            }

            root.handleObservedRefreshFailure(message);
        }
    }
}
