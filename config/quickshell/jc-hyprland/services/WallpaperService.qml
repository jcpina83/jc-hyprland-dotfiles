import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // Canonical observed snapshot. No mutation is owned by this service.
    property var wallpapers: []
    readonly property int wallpaperCount: root.wallpapers.length

    property string themeId: ""
    property string themeRoot: ""
    property string preferencesFile: ""
    property string libraryRoot: ""

    property string configuredEngine: ""
    property string runtimeEngine: ""

    // Canonical transition state comes from the stable public transition API.
    property string transitionPreset: ""
    property string transitionResolvedPreset: ""
    property var transitionTypeOverride: null
    property var transitionDurationOverride: null
    property var transitionFpsOverride: null
    property string transitionEffectiveType: ""
    property real transitionEffectiveDuration: 0
    property int transitionEffectiveFps: 0

    property bool rotationEnabled: false
    property string rotationMode: ""
    property string rotationTarget: ""
    property string rotationInterval: ""

    property string rotationTimerLoadState: ""
    property string rotationTimerEnableState: ""
    property string rotationTimerActiveState: ""
    property string rotationTimerSubState: ""
    property string rotationServiceLoadState: ""
    property string rotationServiceActiveState: ""
    property bool rotationDropInPresent: false
    property bool rotationIntervalSynchronized: false
    property bool rotationLifecycleSynchronized: false
    property bool rotationRuntimeSynchronized: false

    property string mainOutput: ""
    property string mainDefault: ""
    property string mainOverride: ""
    property string mainEffective: ""
    property string mainFit: ""
    property string mainRuntime: ""
    property bool mainRuntimeKnown: false

    property string secondaryOutput: ""
    property string secondaryDefault: ""
    property string secondaryOverride: ""
    property string secondaryEffective: ""
    property string secondaryFit: ""
    property string secondaryRuntime: ""
    property bool secondaryRuntimeKnown: false

    readonly property bool runtimeMatchesConfigured:
        root.mainRuntimeKnown
        && root.secondaryRuntimeKnown
        && root.mainRuntime === root.mainEffective
        && root.secondaryRuntime === root.secondaryEffective

    property bool loading: false
    property bool ready: false
    property string errorMessage: ""
    property string lastRefresh: ""

    // Hold all read domains until catalog also succeeds so consumers receive
    // one coherent observed snapshot instead of mixed refresh generations.
    property var pendingStatus: null
    property var pendingTransitionStatus: null

    signal refreshed()
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

    function fail(message) {
        root.loading = false;
        root.pendingStatus = null;
        root.pendingTransitionStatus = null;
        root.errorMessage = String(message || "Wallpaper refresh failed.");
        root.failed(root.errorMessage);
    }

    function validStatus(payload) {
        return payload
            && payload.theme
            && payload.library
            && payload.engine
            && payload.transition
            && payload.rotation
            && payload.rotation.runtime
            && payload.rotation.runtime.timer
            && payload.rotation.runtime.service
            && payload.rotation.runtime.dropIn
            && payload.outputs
            && payload.outputs.main
            && payload.outputs.secondary
            && payload.runtime
            && payload.runtime.outputs
            && payload.runtime.outputs.main
            && payload.runtime.outputs.secondary;
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

    function validCatalog(payload) {
        return payload
            && Array.isArray(payload.items)
            && Number(payload.count) === payload.items.length;
    }

    function refresh(): void {
        if (root.loading)
            return;

        root.loading = true;
        root.errorMessage = "";
        root.pendingStatus = null;
        root.pendingTransitionStatus = null;

        statusProcess.exec([
            root.wallpaperctlPath(),
            "status",
            "--json"
        ]);
    }

    function commitSnapshot(status, transition, catalog): void {
        root.themeId = String(status.theme.id || "");
        root.themeRoot = String(status.theme.root || "");
        root.preferencesFile =
            String(status.theme.preferencesFile || "");
        root.libraryRoot = String(status.library.root || "");

        root.configuredEngine =
            String(status.engine.configured || "");
        root.runtimeEngine =
            String(status.runtime.engine || "");

        root.transitionPreset =
            String(transition.preset || "");
        root.transitionResolvedPreset =
            String(transition.resolvedPreset || "");
        root.transitionTypeOverride =
            transition.overrides.type === null
                ? null
                : String(transition.overrides.type);
        root.transitionDurationOverride =
            transition.overrides.duration === null
                ? null
                : Number(transition.overrides.duration);
        root.transitionFpsOverride =
            transition.overrides.fps === null
                ? null
                : Number(transition.overrides.fps);
        root.transitionEffectiveType =
            String(transition.effective.type || "");
        root.transitionEffectiveDuration =
            Number(transition.effective.duration || 0);
        root.transitionEffectiveFps =
            Number(transition.effective.fps || 0);

        root.rotationEnabled =
            Boolean(status.rotation.enabled);
        root.rotationMode =
            String(status.rotation.mode || "");
        root.rotationTarget =
            String(status.rotation.target || "");
        root.rotationInterval =
            String(status.rotation.interval || "");

        root.rotationTimerLoadState =
            String(status.rotation.runtime.timer.loadState || "");
        root.rotationTimerEnableState =
            String(status.rotation.runtime.timer.enableState || "");
        root.rotationTimerActiveState =
            String(status.rotation.runtime.timer.activeState || "");
        root.rotationTimerSubState =
            String(status.rotation.runtime.timer.subState || "");
        root.rotationServiceLoadState =
            String(status.rotation.runtime.service.loadState || "");
        root.rotationServiceActiveState =
            String(status.rotation.runtime.service.activeState || "");
        root.rotationDropInPresent =
            Boolean(status.rotation.runtime.dropIn.present);
        root.rotationIntervalSynchronized =
            Boolean(status.rotation.runtime.intervalSynchronized);
        root.rotationLifecycleSynchronized =
            Boolean(status.rotation.runtime.lifecycleSynchronized);
        root.rotationRuntimeSynchronized =
            Boolean(status.rotation.runtime.synchronized);

        root.mainOutput =
            String(status.outputs.main.output || "");
        root.mainDefault =
            String(status.outputs.main.default || "");
        root.mainOverride =
            String(status.outputs.main.override || "");
        root.mainEffective =
            String(status.outputs.main.effective || "");
        root.mainFit =
            String(status.outputs.main.fit || "");
        root.mainRuntime =
            String(status.runtime.outputs.main.wallpaper || "");
        root.mainRuntimeKnown =
            Boolean(status.runtime.outputs.main.known);

        root.secondaryOutput =
            String(status.outputs.secondary.output || "");
        root.secondaryDefault =
            String(status.outputs.secondary.default || "");
        root.secondaryOverride =
            String(status.outputs.secondary.override || "");
        root.secondaryEffective =
            String(status.outputs.secondary.effective || "");
        root.secondaryFit =
            String(status.outputs.secondary.fit || "");
        root.secondaryRuntime =
            String(status.runtime.outputs.secondary.wallpaper || "");
        root.secondaryRuntimeKnown =
            Boolean(status.runtime.outputs.secondary.known);

        // Complete replacement keeps the catalog model coherent for GridView.
        root.wallpapers = catalog.items.slice(0);

        root.pendingStatus = null;
        root.pendingTransitionStatus = null;
        root.loading = false;
        root.ready = true;
        root.errorMessage = "";
        root.lastRefresh = new Date().toLocaleTimeString();
        root.refreshed();
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
            const stderrText = statusStderr.text.trim();

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.fail(
                    "Unable to inspect wallpaper state"
                    + (details.length > 0 ? ": " + details : "")
                );
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!root.validStatus(response)) {
                root.fail(
                    "Unexpected jc-wallpaperctl status response."
                );
                return;
            }

            root.pendingStatus = response;

            transitionStatusProcess.exec([
                root.wallpaperctlPath(),
                "transition",
                "status",
                "--json"
            ]);
        }
    }

    Process {
        id: transitionStatusProcess

        stdout: StdioCollector {
            id: transitionStatusStdout
        }

        stderr: StdioCollector {
            id: transitionStatusStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = transitionStatusStdout.text.trim();
            const stderrText = transitionStatusStderr.text.trim();

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.fail(
                    "Unable to inspect wallpaper transition state"
                    + (details.length > 0 ? ": " + details : "")
                );
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!root.validTransitionStatus(response)) {
                root.fail(
                    "Unexpected jc-wallpaperctl transition status response."
                );
                return;
            }

            if (!root.pendingStatus) {
                root.fail(
                    "Wallpaper status snapshot was lost before "
                    + "transition reconciliation."
                );
                return;
            }

            const statusPreset =
                String(root.pendingStatus.transition.preset || "");
            const transitionPreset =
                String(response.preset || "");

            if (statusPreset !== transitionPreset) {
                root.fail(
                    "Wallpaper transition changed during refresh; retry."
                );
                return;
            }

            root.pendingTransitionStatus = response;

            catalogProcess.exec([
                root.wallpaperctlPath(),
                "catalog",
                "--json"
            ]);
        }
    }

    Process {
        id: catalogProcess

        stdout: StdioCollector {
            id: catalogStdout
        }

        stderr: StdioCollector {
            id: catalogStderr
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = catalogStdout.text.trim();
            const stderrText = catalogStderr.text.trim();

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.fail(
                    "Unable to load wallpaper catalog"
                    + (details.length > 0 ? ": " + details : "")
                );
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!root.validCatalog(response)) {
                root.fail(
                    "Unexpected jc-wallpaperctl catalog response."
                );
                return;
            }

            if (!root.pendingStatus) {
                root.fail(
                    "Wallpaper status snapshot was lost before catalog commit."
                );
                return;
            }

            if (!root.pendingTransitionStatus) {
                root.fail(
                    "Wallpaper transition snapshot was lost before "
                    + "catalog commit."
                );
                return;
            }

            root.commitSnapshot(
                root.pendingStatus,
                root.pendingTransitionStatus,
                response
            );
        }
    }

    Component.onCompleted: root.refresh()
}
