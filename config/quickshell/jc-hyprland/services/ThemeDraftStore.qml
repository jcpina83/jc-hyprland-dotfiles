import QtQuick
import Quickshell

Scope {
    id: root

    // Phase 2C.1d — Theme draft / baseline state.
    // Presentation state only: no backend invocation and no runtime mutation.

    property var themeService

    property string draftThemeId: ""
    property string baselineThemeId: ""

    property bool initialized: false
    property bool observedChangedWhileDirty: false

    readonly property bool dirty:
        root.initialized
        && root.draftThemeId.length > 0
        && root.baselineThemeId.length > 0
        && root.draftThemeId !== root.baselineThemeId

    readonly property bool hasDirty: root.dirty
    readonly property int dirtyCount: root.dirty ? 1 : 0

    readonly property var draftTheme:
        root.themeService && root.draftThemeId.length > 0
            ? root.themeService.themeById(root.draftThemeId)
            : null

    readonly property var baselineTheme:
        root.themeService && root.baselineThemeId.length > 0
            ? root.themeService.themeById(root.baselineThemeId)
            : null

    readonly property bool draftValid:
        root.draftTheme !== null

    signal changed()
    signal resetCompleted()

    function validThemeId(themeId) {
        if (!root.themeService)
            return false;

        const wanted = String(themeId || "");

        if (!wanted)
            return false;

        return root.themeService.themeById(wanted) !== null;
    }

    function setTheme(themeId) {
        const wanted = String(themeId || "");

        if (!root.validThemeId(wanted))
            return false;

        if (!root.initialized)
            root.syncFromObserved(true);

        if (root.draftThemeId === wanted)
            return true;

        root.draftThemeId = wanted;
        root.changed();
        return true;
    }

    function syncFromObserved(force) {
        if (!root.themeService || !root.themeService.ready)
            return false;

        const observed = String(root.themeService.activeThemeId || "");

        if (!observed || !root.validThemeId(observed))
            return false;

        if (!root.initialized || force) {
            root.baselineThemeId = observed;
            root.draftThemeId = observed;
            root.initialized = true;
            root.observedChangedWhileDirty = false;
            return true;
        }

        if (root.dirty) {
            if (observed !== root.baselineThemeId)
                root.observedChangedWhileDirty = true;

            return true;
        }

        root.baselineThemeId = observed;
        root.draftThemeId = observed;
        root.observedChangedWhileDirty = false;
        return true;
    }

    function reset() {
        if (!root.themeService || !root.themeService.ready)
            return false;

        const observed = String(root.themeService.activeThemeId || "");

        if (!observed || !root.validThemeId(observed))
            return false;

        root.baselineThemeId = observed;
        root.draftThemeId = observed;
        root.initialized = true;
        root.observedChangedWhileDirty = false;
        root.resetCompleted();
        return true;
    }

    Connections {
        target: root.themeService

        function onRefreshed() {
            root.syncFromObserved(false);
        }
    }

    Component.onCompleted: root.syncFromObserved(true)
}
