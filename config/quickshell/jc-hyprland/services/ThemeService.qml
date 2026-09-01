import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // -------------------------------------------------------------------------
    // Phase 2C.1c — read-only observed theme state
    //
    // This service owns no theme files and performs no desktop mutation.
    // Its only runtime boundary is the stable public Theme Control read API:
    //
    //   jc-theme status --json
    //   jc-theme catalog --json
    //
    // Theme.qml remains the semantic visual API and independently watches
    // local/active-theme. This service exists for the Themes feature module.
    // -------------------------------------------------------------------------

    property var themes: []

    property string activeThemeId: ""
    property string activeFileThemeId: ""
    property string activeLinkThemeId: ""

    property bool isSynchronized: false
    property bool activeThemeValid: false

    property string activeThemePath: ""
    property string activeMetadataFile: ""

    property bool loading: false
    property bool ready: false
    property string errorMessage: ""

    property var pendingStatus: null
    property int refreshGeneration: 0
    property int pendingGeneration: 0
    property int snapshotRetryCount: 0

    readonly property int themeCount: root.themes.length

    readonly property var activeTheme: {
        for (let index = 0; index < root.themes.length; index++) {
            const item = root.themes[index];

            if (item && String(item.id || "") === root.activeThemeId)
                return item;
        }

        return null;
    }

    readonly property bool observedHealthy:
        root.ready
        && root.isSynchronized
        && root.activeThemeValid
        && root.activeTheme !== null

    signal refreshed()
    signal refreshFailed(string message)

    function themeCommandPath() {
        const home = Quickshell.env("HOME");
        const configHome = Quickshell.env("XDG_CONFIG_HOME");
        const base = configHome
            ? String(configHome)
            : String(home || "") + "/.config";

        return base + "/jc-hyprland-dotfiles/bin/jc-theme";
    }

    function themeById(themeId) {
        const wanted = String(themeId || "");

        for (let index = 0; index < root.themes.length; index++) {
            const item = root.themes[index];

            if (item && String(item.id || "") === wanted)
                return item;
        }

        return null;
    }

    function validStatusPayload(payload) {
        if (!payload || typeof payload !== "object")
            return false;

        if (typeof payload.activeTheme !== "string"
                || payload.activeTheme.length === 0)
            return false;

        if (payload.activeFileTheme !== null
                && typeof payload.activeFileTheme !== "string")
            return false;

        if (payload.activeLinkTheme !== null
                && typeof payload.activeLinkTheme !== "string")
            return false;

        if (typeof payload["synchronized"] !== "boolean"
                || typeof payload.valid !== "boolean")
            return false;

        return true;
    }

    function validCatalogItem(item) {
        if (!item || typeof item !== "object")
            return false;

        if (typeof item.id !== "string" || item.id.length === 0)
            return false;

        if (typeof item.name !== "string" || item.name.length === 0)
            return false;

        if (Number(item.schemaVersion) !== 1)
            return false;

        if (typeof item.active !== "boolean")
            return false;

        if (!item.colors || typeof item.colors !== "object")
            return false;

        if (!item.opacity || typeof item.opacity !== "object")
            return false;

        if (!item.preview || typeof item.preview !== "object")
            return false;

        return true;
    }

    function validCatalogPayload(payload) {
        if (!payload || typeof payload !== "object")
            return false;

        if (typeof payload.activeTheme !== "string")
            return false;

        if (!Array.isArray(payload.items))
            return false;

        if (Number(payload.count) !== payload.items.length)
            return false;

        const ids = ({});
        let activeCount = 0;

        for (let index = 0; index < payload.items.length; index++) {
            const item = payload.items[index];

            if (!root.validCatalogItem(item))
                return false;

            if (ids[item.id])
                return false;

            ids[item.id] = true;

            if (item.active)
                activeCount++;
        }

        return activeCount === 1;
    }

    function parseJson(text, sourceName) {
        const raw = String(text || "").trim();

        if (!raw)
            throw new Error(sourceName + " returned empty output");

        try {
            return JSON.parse(raw);
        } catch (error) {
            throw new Error(
                sourceName + " returned invalid JSON: " + String(error)
            );
        }
    }

    function failRefresh(message) {
        root.loading = false;
        root.pendingStatus = null;
        root.errorMessage = String(message || "Theme refresh failed.");
        root.refreshFailed(root.errorMessage);
    }

    function refresh() {
        if (root.loading)
            return;

        root.loading = true;
        root.errorMessage = "";
        root.pendingStatus = null;
        root.snapshotRetryCount = 0;
        root.refreshGeneration++;
        root.pendingGeneration = root.refreshGeneration;

        statusProcess.command = [
            root.themeCommandPath(),
            "status",
            "--json"
        ];
        statusProcess.running = true;
    }

    function retrySnapshotIfNeeded(reason) {
        if (root.snapshotRetryCount >= 1) {
            root.failRefresh(reason);
            return;
        }

        root.snapshotRetryCount++;
        root.pendingStatus = null;

        statusProcess.command = [
            root.themeCommandPath(),
            "status",
            "--json"
        ];
        statusProcess.running = true;
    }

    function commitSnapshot(statusPayload, catalogPayload) {
        root.activeThemeId = String(statusPayload.activeTheme || "");
        root.activeFileThemeId =
            statusPayload.activeFileTheme === null
                ? ""
                : String(statusPayload.activeFileTheme);
        root.activeLinkThemeId =
            statusPayload.activeLinkTheme === null
                ? ""
                : String(statusPayload.activeLinkTheme);

        root.isSynchronized = Boolean(statusPayload["synchronized"]);
        root.activeThemeValid = Boolean(statusPayload.valid);

        root.activeThemePath =
            statusPayload.themePath === null
                ? ""
                : String(statusPayload.themePath || "");
        root.activeMetadataFile =
            statusPayload.metadataFile === null
                ? ""
                : String(statusPayload.metadataFile || "");

        root.themes = catalogPayload.items.slice(0);

        root.pendingStatus = null;
        root.loading = false;
        root.ready = true;
        root.errorMessage = "";
        root.refreshed();
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
            if (!root.loading)
                return;

            if (exitCode !== 0) {
                root.failRefresh(
                    "Theme status failed (rc="
                    + String(exitCode)
                    + "): "
                    + String(statusError.text || "").trim()
                );
                return;
            }

            let payload = null;

            try {
                payload = root.parseJson(
                    statusOutput.text,
                    "jc-theme status --json"
                );
            } catch (error) {
                root.failRefresh(String(error));
                return;
            }

            if (!root.validStatusPayload(payload)) {
                root.failRefresh("Theme status payload failed validation.");
                return;
            }

            root.pendingStatus = payload;

            catalogProcess.command = [
                root.themeCommandPath(),
                "catalog",
                "--json"
            ];
            catalogProcess.running = true;
        }
    }

    Process {
        id: catalogProcess

        stdout: StdioCollector {
            id: catalogOutput
        }

        stderr: StdioCollector {
            id: catalogError
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.loading || !root.pendingStatus)
                return;

            if (exitCode !== 0) {
                root.failRefresh(
                    "Theme catalog failed (rc="
                    + String(exitCode)
                    + "): "
                    + String(catalogError.text || "").trim()
                );
                return;
            }

            let payload = null;

            try {
                payload = root.parseJson(
                    catalogOutput.text,
                    "jc-theme catalog --json"
                );
            } catch (error) {
                root.failRefresh(String(error));
                return;
            }

            if (!root.validCatalogPayload(payload)) {
                root.failRefresh("Theme catalog payload failed validation.");
                return;
            }

            if (String(payload.activeTheme || "")
                    !== String(root.pendingStatus.activeTheme || "")) {
                root.retrySnapshotIfNeeded(
                    "Theme changed while observed snapshot was being read."
                );
                return;
            }

            root.commitSnapshot(root.pendingStatus, payload);
        }
    }

    Component.onCompleted: root.refresh()
}
