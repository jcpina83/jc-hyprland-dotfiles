import QtQuick
import Quickshell

Scope {
    id: root

    property var wallpaperService

    property string selectedTarget: "main"

    property string draftMainPath: ""
    property string draftSecondaryPath: ""
    property string draftMainFit: "cover"
    property string draftSecondaryFit: "cover"

    property string baselineMainEffective: ""
    property string baselineSecondaryEffective: ""
    property string baselineMainFit: "cover"
    property string baselineSecondaryFit: "cover"

    property bool initialized: false
    property bool observedChangedWhileDirty: false
    property bool syncAfterApplyPending: false

    readonly property bool mainWallpaperDirty:
        root.initialized
        && root.draftMainPath !== root.baselineMainEffective

    readonly property bool secondaryWallpaperDirty:
        root.initialized
        && root.draftSecondaryPath !== root.baselineSecondaryEffective

    readonly property bool mainFitDirty:
        root.initialized
        && root.draftMainFit !== root.baselineMainFit

    readonly property bool secondaryFitDirty:
        root.initialized
        && root.draftSecondaryFit !== root.baselineSecondaryFit

    readonly property bool mainDirty:
        root.mainWallpaperDirty || root.mainFitDirty

    readonly property bool secondaryDirty:
        root.secondaryWallpaperDirty || root.secondaryFitDirty

    readonly property int dirtyCount:
        (root.mainDirty ? 1 : 0)
        + (root.secondaryDirty ? 1 : 0)

    readonly property bool hasDirty: root.dirtyCount > 0

    signal changed()
    signal resetCompleted()

    function validTarget(target) {
        return target === "main" || target === "secondary";
    }

    function validFit(fit) {
        return fit === "cover"
            || fit === "contain"
            || fit === "stretch"
            || fit === "center";
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

    function fitForTarget(target) {
        return target === "secondary"
            ? root.draftSecondaryFit
            : root.draftMainFit;
    }

    function baselineFitForTarget(target) {
        return target === "secondary"
            ? root.baselineSecondaryFit
            : root.baselineMainFit;
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

        if (normalizedTarget === "main") {
            if (root.draftMainPath === normalizedPath)
                return;

            root.draftMainPath = normalizedPath;
        } else {
            if (root.draftSecondaryPath === normalizedPath)
                return;

            root.draftSecondaryPath = normalizedPath;
        }

        root.changed();
    }

    function setSelectedWallpaper(path): void {
        root.setWallpaper(root.selectedTarget, path);
    }

    function setFit(target, fit): void {
        const normalizedTarget = String(target || "");
        const normalizedFit = String(fit || "");

        if (!root.validTarget(normalizedTarget)
                || !root.validFit(normalizedFit)) {
            return;
        }

        if (normalizedTarget === "main") {
            if (root.draftMainFit === normalizedFit)
                return;

            root.draftMainFit = normalizedFit;
        } else {
            if (root.draftSecondaryFit === normalizedFit)
                return;

            root.draftSecondaryFit = normalizedFit;
        }

        root.changed();
    }

    function setSelectedFit(fit): void {
        root.setFit(root.selectedTarget, fit);
    }

    function syncFromObserved(force): void {
        if (!root.wallpaperService || !root.wallpaperService.ready)
            return;

        const observedMain =
            String(root.wallpaperService.mainEffective || "");
        const observedSecondary =
            String(root.wallpaperService.secondaryEffective || "");
        const observedMainFit =
            String(root.wallpaperService.mainFit || "cover");
        const observedSecondaryFit =
            String(root.wallpaperService.secondaryFit || "cover");

        if (root.initialized && root.hasDirty && !force) {
            if (observedMain !== root.baselineMainEffective
                    || observedSecondary
                        !== root.baselineSecondaryEffective
                    || observedMainFit !== root.baselineMainFit
                    || observedSecondaryFit !== root.baselineSecondaryFit) {
                root.observedChangedWhileDirty = true;
            }

            return;
        }

        root.baselineMainEffective = observedMain;
        root.baselineSecondaryEffective = observedSecondary;
        root.baselineMainFit = observedMainFit;
        root.baselineSecondaryFit = observedSecondaryFit;

        root.draftMainPath = observedMain;
        root.draftSecondaryPath = observedSecondary;
        root.draftMainFit = observedMainFit;
        root.draftSecondaryFit = observedSecondaryFit;

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
