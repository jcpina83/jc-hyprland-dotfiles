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
    property string transitionPreset: ""

    property bool rotationEnabled: false
    property string rotationMode: ""
    property string rotationTarget: ""
    property string rotationInterval: ""

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

    // Hold status until catalog also succeeds so consumers receive an atomic
    // snapshot instead of new status paired with an old catalog.
    property var pendingStatus: null

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
            && payload.outputs
            && payload.outputs.main
            && payload.outputs.secondary
            && payload.runtime
            && payload.runtime.outputs
            && payload.runtime.outputs.main
            && payload.runtime.outputs.secondary;
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

        statusProcess.exec([
            root.wallpaperctlPath(),
            "status",
            "--json"
        ]);
    }

    function commitSnapshot(status, catalog): void {
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
            String(status.transition.preset || "");

        root.rotationEnabled =
            Boolean(status.rotation.enabled);
        root.rotationMode =
            String(status.rotation.mode || "");
        root.rotationTarget =
            String(status.rotation.target || "");
        root.rotationInterval =
            String(status.rotation.interval || "");

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

            root.commitSnapshot(root.pendingStatus, response);
        }
    }

    Component.onCompleted: root.refresh()
}
