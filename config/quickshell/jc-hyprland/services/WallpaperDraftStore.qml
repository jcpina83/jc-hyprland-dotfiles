import QtQuick
import Quickshell

Scope {
    id: root

    property var wallpaperService

    property string selectedTarget: "main"

    property string draftMainPath: ""
    property string draftSecondaryPath: ""

    property string baselineMainEffective: ""
    property string baselineSecondaryEffective: ""

    property bool initialized: false
    property bool observedChangedWhileDirty: false
    property bool syncAfterApplyPending: false

    readonly property bool mainDirty:
        root.initialized
        && root.draftMainPath !== root.baselineMainEffective

    readonly property bool secondaryDirty:
        root.initialized
        && root.draftSecondaryPath !== root.baselineSecondaryEffective

    readonly property int dirtyCount:
        (root.mainDirty ? 1 : 0)
        + (root.secondaryDirty ? 1 : 0)

    readonly property bool hasDirty: root.dirtyCount > 0

    signal changed()
    signal resetCompleted()

    function validTarget(target) {
        return target === "main" || target === "secondary";
    }

    function draftForTarget(target) {
        return target === "secondary"
            ? root.draftSecondaryPath
            : root.draftMainPath;
    }

    function baselineForTarget(target) {
        return target === "secondary"
            ? root.baselineSecondaryEffective
            : root.baselineMainEffective;
    }

    function selectTarget(target): void {
        if (!root.validTarget(target))
            return;

        root.selectedTarget = target;
    }

    function setWallpaper(target, path): void {
        const normalizedTarget = String(target || "");
        const normalizedPath = String(path || "");

        if (!root.validTarget(normalizedTarget)
                || normalizedPath.length === 0) {
            return;
        }

        if (normalizedTarget === "main")
            root.draftMainPath = normalizedPath;
        else
            root.draftSecondaryPath = normalizedPath;

        root.changed();
    }

    function setSelectedWallpaper(path): void {
        root.setWallpaper(root.selectedTarget, path);
    }

    function syncFromObserved(force): void {
        if (!root.wallpaperService || !root.wallpaperService.ready)
            return;

        const observedMain =
            String(root.wallpaperService.mainEffective || "");
        const observedSecondary =
            String(root.wallpaperService.secondaryEffective || "");

        if (root.initialized && root.hasDirty && !force) {
            if (observedMain !== root.baselineMainEffective
                    || observedSecondary
                        !== root.baselineSecondaryEffective) {
                root.observedChangedWhileDirty = true;
            }

            return;
        }

        root.baselineMainEffective = observedMain;
        root.baselineSecondaryEffective = observedSecondary;

        root.draftMainPath = observedMain;
        root.draftSecondaryPath = observedSecondary;

        root.initialized = true;
        root.observedChangedWhileDirty = false;
    }

    function prepareForRefreshAfterApply(): void {
        root.syncAfterApplyPending = true;
    }

    function reset(): void {
        root.syncAfterApplyPending = false;
        root.syncFromObserved(true);
        root.selectedTarget = "main";
        root.resetCompleted();
    }

    Connections {
        target: root.wallpaperService

        function onRefreshed() {
            if (root.syncAfterApplyPending) {
                root.syncAfterApplyPending = false;
                root.syncFromObserved(true);
                return;
            }

            root.syncFromObserved(false);
        }
    }

    Component.onCompleted: root.syncFromObserved(false)
}
