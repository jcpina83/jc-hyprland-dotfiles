import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // -------------------------------------------------------------------------
    // Phase 2D.1b — read-only observed Quick Settings state.
    //
    // This service owns no desktop mutation. Its only runtime boundary is:
    //
    //   jc-quick-settings status --json
    //
    // Mutation belongs to the future QuickSettingsActionService.
    // -------------------------------------------------------------------------

    property bool dndAvailable: false
    property bool dndBackendInstalled: false
    property bool dndRunning: false
    property bool dndEnabled: false
    property string dndBackend: ""

    property bool lockAvailable: false
    property string lockBackend: ""

    property bool nightLightAvailable: false
    property bool nightLightRunning: false
    property bool nightLightManaged: false
    property var nightLightEnabled: null
    property string nightLightBackend: ""

    property bool suspendAvailable: false
    property string suspendBackend: ""

    property bool loading: false
    property bool ready: false
    property string errorMessage: ""
    property string lastRefresh: ""

    signal refreshed()
    signal refreshFailed(string message)

    function configHome() {
        const configured = Quickshell.env("XDG_CONFIG_HOME");

        if (configured !== null && String(configured).length > 0)
            return String(configured);

        const home = Quickshell.env("HOME");

        return String(home || "") + "/.config";
    }

    function quickSettingsCommandPath() {
        return root.configHome()
            + "/jc-hyprland-dotfiles/bin/jc-quick-settings";
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

    function validCapability(payload, name) {
        return payload.capabilities
            && payload.capabilities[name]
            && typeof payload.capabilities[name] === "object";
    }

    function validStatus(payload) {
        if (!payload || typeof payload !== "object")
            return false;

        if (Number(payload.schemaVersion) !== 1
                || payload.status !== "ok") {
            return false;
        }

        if (!root.validCapability(payload, "dnd")
                || !root.validCapability(payload, "lock")
                || !root.validCapability(payload, "nightLight")
                || !root.validCapability(payload, "suspend")) {
            return false;
        }

        const dnd = payload.capabilities.dnd;
        const lock = payload.capabilities.lock;
        const nightLight = payload.capabilities.nightLight;
        const suspend = payload.capabilities.suspend;

        if (typeof dnd.available !== "boolean"
                || typeof dnd.backendInstalled !== "boolean"
                || typeof dnd.running !== "boolean"
                || typeof dnd.backend !== "string") {
            return false;
        }

        if (dnd.enabled !== null
                && typeof dnd.enabled !== "boolean") {
            return false;
        }

        if (typeof lock.available !== "boolean"
                || typeof lock.backend !== "string") {
            return false;
        }

        if (typeof nightLight.available !== "boolean"
                || typeof nightLight.running !== "boolean"
                || typeof nightLight.managed !== "boolean"
                || typeof nightLight.backend !== "string") {
            return false;
        }

        if (nightLight.enabled !== null
                && typeof nightLight.enabled !== "boolean") {
            return false;
        }

        return typeof suspend.available === "boolean"
            && typeof suspend.backend === "string";
    }

    function fail(message) {
        root.loading = false;
        root.errorMessage =
            String(message || "Quick Settings refresh failed.");
        root.refreshFailed(root.errorMessage);
    }

    function commitSnapshot(payload) {
        const dnd = payload.capabilities.dnd;
        const lock = payload.capabilities.lock;
        const nightLight = payload.capabilities.nightLight;
        const suspend = payload.capabilities.suspend;

        root.dndAvailable = Boolean(dnd.available);
        root.dndBackendInstalled = Boolean(dnd.backendInstalled);
        root.dndRunning = Boolean(dnd.running);
        root.dndEnabled =
            dnd.enabled === null ? false : Boolean(dnd.enabled);
        root.dndBackend = String(dnd.backend || "");

        root.lockAvailable = Boolean(lock.available);
        root.lockBackend = String(lock.backend || "");

        root.nightLightAvailable = Boolean(nightLight.available);
        root.nightLightRunning = Boolean(nightLight.running);
        root.nightLightManaged = Boolean(nightLight.managed);
        root.nightLightEnabled =
            nightLight.enabled === null
                ? null
                : Boolean(nightLight.enabled);
        root.nightLightBackend = String(nightLight.backend || "");

        root.suspendAvailable = Boolean(suspend.available);
        root.suspendBackend = String(suspend.backend || "");

        root.loading = false;
        root.ready = true;
        root.errorMessage = "";
        root.lastRefresh = new Date().toLocaleTimeString();
        root.refreshed();
    }

    function refresh(): void {
        if (root.loading)
            return;

        root.loading = true;
        root.errorMessage = "";

        statusProcess.command = [
            root.quickSettingsCommandPath(),
            "status",
            "--json"
        ];
        statusProcess.running = true;
    }

    Process {
        id: statusProcess

        stdout: StdioCollector {
            id: statusOutput
        }

        stderr: StdioCollector {
            id: statusError
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = String(statusOutput.text || "").trim();
            const stderrText = String(statusError.text || "").trim();

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.fail(
                    "Unable to inspect Quick Settings state"
                    + (details.length > 0 ? ": " + details : "")
                );
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!root.validStatus(response)) {
                root.fail(
                    "Unexpected jc-quick-settings status response."
                );
                return;
            }

            root.commitSnapshot(response);
        }
    }

    Component.onCompleted: root.refresh()
}
