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

    property bool draftRotationEnabled: false
    property string draftRotationMode: "next"
    property string draftRotationTarget: "both"
    property string draftRotationInterval: "30m"

    property string draftTransitionPreset: "theme"
    property var draftTransitionTypeOverride: null
    property var draftTransitionDurationOverride: null
    property var draftTransitionFpsOverride: null

    property string baselineMainEffective: ""
    property string baselineSecondaryEffective: ""
    property string baselineMainFit: "cover"
    property string baselineSecondaryFit: "cover"

    property bool baselineRotationEnabled: false
    property string baselineRotationMode: "next"
    property string baselineRotationTarget: "both"
    property string baselineRotationInterval: "30m"

    property string baselineTransitionPreset: "theme"
    property string baselineTransitionResolvedPreset: ""
    property var baselineTransitionTypeOverride: null
    property var baselineTransitionDurationOverride: null
    property var baselineTransitionFpsOverride: null
    property string baselineTransitionEffectiveType: ""
    property real baselineTransitionEffectiveDuration: 0
    property int baselineTransitionEffectiveFps: 0

    property bool initialized: false
    property bool observedChangedWhileDirty: false
    property bool syncAfterApplyPending: false
    property string syncAfterApplyDomain: ""

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

    readonly property bool rotationEnabledDirty:
        root.initialized
        && root.draftRotationEnabled !== root.baselineRotationEnabled

    readonly property bool rotationModeDirty:
        root.initialized
        && root.draftRotationMode !== root.baselineRotationMode

    readonly property bool rotationTargetDirty:
        root.initialized
        && root.draftRotationTarget !== root.baselineRotationTarget

    readonly property bool rotationIntervalDirty:
        root.initialized
        && root.draftRotationInterval !== root.baselineRotationInterval

    readonly property bool rotationDirty:
        root.rotationEnabledDirty
        || root.rotationModeDirty
        || root.rotationTargetDirty
        || root.rotationIntervalDirty

    readonly property bool transitionPresetDirty:
        root.initialized
        && root.draftTransitionPreset !== root.baselineTransitionPreset

    readonly property bool transitionTypeDirty:
        root.initialized
        && root.draftTransitionTypeOverride
            !== root.baselineTransitionTypeOverride

    readonly property bool transitionDurationDirty:
        root.initialized
        && root.draftTransitionDurationOverride
            !== root.baselineTransitionDurationOverride

    readonly property bool transitionFpsDirty:
        root.initialized
        && root.draftTransitionFpsOverride
            !== root.baselineTransitionFpsOverride

    readonly property bool transitionDirty:
        root.transitionPresetDirty
        || root.transitionTypeDirty
        || root.transitionDurationDirty
        || root.transitionFpsDirty

    readonly property bool mainDirty:
        root.mainWallpaperDirty || root.mainFitDirty

    readonly property bool secondaryDirty:
        root.secondaryWallpaperDirty || root.secondaryFitDirty

    readonly property bool hasWallpaperDirty:
        root.mainDirty || root.secondaryDirty

    // `hasDirty` remains the set of domains already owned by the current
    // Apply coordinator. Transition joins it in Phase 2B.7.3 when its Apply
    // owner exists. `hasAnyDraftDirty` still protects transition drafts from
    // observed refresh reconciliation in this foundation phase.
    readonly property int dirtyCount:
        (root.mainDirty ? 1 : 0)
        + (root.secondaryDirty ? 1 : 0)
        + (root.rotationDirty ? 1 : 0)

    readonly property bool hasDirty: root.dirtyCount > 0
    readonly property bool hasAnyDraftDirty:
        root.hasDirty || root.transitionDirty

    signal changed()
    signal rotationChanged()
    signal transitionChanged()
    signal resetCompleted()
    signal rotationResetCompleted()
    signal transitionResetCompleted()

    function validTarget(target) {
        return target === "main" || target === "secondary";
    }

    function validFit(fit) {
        return fit === "cover"
            || fit === "contain"
            || fit === "stretch"
            || fit === "center";
    }

    function validRotationMode(mode) {
        return mode === "next" || mode === "random";
    }

    function validRotationTarget(target) {
        return target === "main"
            || target === "secondary"
            || target === "both";
    }

    function validRotationInterval(interval) {
        return String(interval || "").trim().length > 0;
    }

    function validTransitionPreset(preset) {
        return preset === "theme"
            || preset === "default"
            || preset === "fade"
            || preset === "cyber-noir"
            || preset === "odyssey-glass";
    }

    function validTransitionType(type) {
        return type === "none"
            || type === "simple"
            || type === "fade"
            || type === "left"
            || type === "right"
            || type === "top"
            || type === "bottom"
            || type === "wipe"
            || type === "wave"
            || type === "grow"
            || type === "center"
            || type === "any"
            || type === "outer"
            || type === "random";
    }

    function optionalString(value) {
        if (value === null || value === undefined)
            return null;

        return String(value);
    }

    function optionalNumber(value) {
        if (value === null || value === undefined)
            return null;

        return Number(value);
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

    function observedDiffersFromBaseline() {
        if (!root.wallpaperService || !root.wallpaperService.ready)
            return false;

        return String(root.wallpaperService.mainEffective || "")
                !== root.baselineMainEffective
            || String(root.wallpaperService.secondaryEffective || "")
                !== root.baselineSecondaryEffective
            || String(root.wallpaperService.mainFit || "cover")
                !== root.baselineMainFit
            || String(root.wallpaperService.secondaryFit || "cover")
                !== root.baselineSecondaryFit
            || Boolean(root.wallpaperService.rotationEnabled)
                !== root.baselineRotationEnabled
            || String(root.wallpaperService.rotationMode || "")
                !== root.baselineRotationMode
            || String(root.wallpaperService.rotationTarget || "")
                !== root.baselineRotationTarget
            || String(root.wallpaperService.rotationInterval || "")
                !== root.baselineRotationInterval
            || String(root.wallpaperService.transitionPreset || "")
                !== root.baselineTransitionPreset
            || String(root.wallpaperService.transitionResolvedPreset || "")
                !== root.baselineTransitionResolvedPreset
            || root.optionalString(
                    root.wallpaperService.transitionTypeOverride
                ) !== root.baselineTransitionTypeOverride
            || root.optionalNumber(
                    root.wallpaperService.transitionDurationOverride
                ) !== root.baselineTransitionDurationOverride
            || root.optionalNumber(
                    root.wallpaperService.transitionFpsOverride
                ) !== root.baselineTransitionFpsOverride
            || String(root.wallpaperService.transitionEffectiveType || "")
                !== root.baselineTransitionEffectiveType
            || Number(
                    root.wallpaperService.transitionEffectiveDuration || 0
                ) !== root.baselineTransitionEffectiveDuration
            || Number(
                    root.wallpaperService.transitionEffectiveFps || 0
                ) !== root.baselineTransitionEffectiveFps;
    }

    function syncWallpaperFromObserved(): void {
        if (!root.wallpaperService || !root.wallpaperService.ready)
            return;

        root.baselineMainEffective =
            String(root.wallpaperService.mainEffective || "");
        root.baselineSecondaryEffective =
            String(root.wallpaperService.secondaryEffective || "");
        root.baselineMainFit =
            String(root.wallpaperService.mainFit || "cover");
        root.baselineSecondaryFit =
            String(root.wallpaperService.secondaryFit || "cover");

        root.draftMainPath = root.baselineMainEffective;
        root.draftSecondaryPath = root.baselineSecondaryEffective;
        root.draftMainFit = root.baselineMainFit;
        root.draftSecondaryFit = root.baselineSecondaryFit;
    }

    function syncRotationFromObserved(): void {
        if (!root.wallpaperService || !root.wallpaperService.ready)
            return;

        root.baselineRotationEnabled =
            Boolean(root.wallpaperService.rotationEnabled);
        root.baselineRotationMode =
            String(root.wallpaperService.rotationMode || "next");
        root.baselineRotationTarget =
            String(root.wallpaperService.rotationTarget || "both");
        root.baselineRotationInterval =
            String(root.wallpaperService.rotationInterval || "30m");

        root.draftRotationEnabled = root.baselineRotationEnabled;
        root.draftRotationMode = root.baselineRotationMode;
        root.draftRotationTarget = root.baselineRotationTarget;
        root.draftRotationInterval = root.baselineRotationInterval;
    }

    function syncTransitionFromObserved(): void {
        if (!root.wallpaperService || !root.wallpaperService.ready)
            return;

        root.baselineTransitionPreset =
            String(root.wallpaperService.transitionPreset || "theme");
        root.baselineTransitionResolvedPreset =
            String(root.wallpaperService.transitionResolvedPreset || "");
        root.baselineTransitionTypeOverride =
            root.optionalString(
                root.wallpaperService.transitionTypeOverride
            );
        root.baselineTransitionDurationOverride =
            root.optionalNumber(
                root.wallpaperService.transitionDurationOverride
            );
        root.baselineTransitionFpsOverride =
            root.optionalNumber(
                root.wallpaperService.transitionFpsOverride
            );
        root.baselineTransitionEffectiveType =
            String(root.wallpaperService.transitionEffectiveType || "");
        root.baselineTransitionEffectiveDuration =
            Number(root.wallpaperService.transitionEffectiveDuration || 0);
        root.baselineTransitionEffectiveFps =
            Number(root.wallpaperService.transitionEffectiveFps || 0);

        root.draftTransitionPreset = root.baselineTransitionPreset;
        root.draftTransitionTypeOverride =
            root.baselineTransitionTypeOverride;
        root.draftTransitionDurationOverride =
            root.baselineTransitionDurationOverride;
        root.draftTransitionFpsOverride =
            root.baselineTransitionFpsOverride;
    }


    function refreshObservedConflict(): void {
        root.observedChangedWhileDirty =
            root.hasAnyDraftDirty
            && root.observedDiffersFromBaseline();
    }

    function syncFromObserved(force): void {
        if (!root.wallpaperService || !root.wallpaperService.ready)
            return;

        if (root.initialized && root.hasAnyDraftDirty && !force) {
            if (root.observedDiffersFromBaseline())
                root.observedChangedWhileDirty = true;

            return;
        }

        root.syncWallpaperFromObserved();
        root.syncRotationFromObserved();
        root.syncTransitionFromObserved();

        root.initialized = true;
        root.observedChangedWhileDirty = false;
    }

    function setRotationEnabled(enabled): void {
        const normalized = Boolean(enabled);
        if (root.draftRotationEnabled === normalized)
            return;

        root.draftRotationEnabled = normalized;
        root.rotationChanged();
        root.changed();
    }

    function setRotationMode(mode): void {
        const normalized = String(mode || "");
        if (!root.validRotationMode(normalized)
                || root.draftRotationMode === normalized)
            return;

        root.draftRotationMode = normalized;
        root.rotationChanged();
        root.changed();
    }

    function setRotationTarget(target): void {
        const normalized = String(target || "");
        if (!root.validRotationTarget(normalized)
                || root.draftRotationTarget === normalized)
            return;

        root.draftRotationTarget = normalized;
        root.rotationChanged();
        root.changed();
    }

    function setRotationInterval(interval): void {
        const normalized = String(interval || "").trim();
        if (!root.validRotationInterval(normalized)
                || root.draftRotationInterval === normalized)
            return;

        root.draftRotationInterval = normalized;
        root.rotationChanged();
        root.changed();
    }

    function setTransitionPreset(preset): void {
        const normalized = String(preset || "");

        if (!root.validTransitionPreset(normalized)
                || root.draftTransitionPreset === normalized) {
            return;
        }

        root.draftTransitionPreset = normalized;
        root.transitionChanged();
        root.changed();
    }

    function setTransitionTypeOverride(value): void {
        let normalized = null;

        if (value !== null
                && value !== undefined
                && String(value) !== "inherit") {
            normalized = String(value);

            if (!root.validTransitionType(normalized))
                return;
        }

        if (root.draftTransitionTypeOverride === normalized)
            return;

        root.draftTransitionTypeOverride = normalized;
        root.transitionChanged();
        root.changed();
    }

    function setTransitionDurationOverride(value): void {
        let normalized = null;

        if (value !== null
                && value !== undefined
                && String(value) !== "inherit") {
            normalized = Number(value);

            if (!isFinite(normalized) || normalized <= 0)
                return;
        }

        if (root.draftTransitionDurationOverride === normalized)
            return;

        root.draftTransitionDurationOverride = normalized;
        root.transitionChanged();
        root.changed();
    }

    function setTransitionFpsOverride(value): void {
        let normalized = null;

        if (value !== null
                && value !== undefined
                && String(value) !== "inherit") {
            normalized = Number(value);

            if (!isFinite(normalized)
                    || normalized <= 0
                    || Math.floor(normalized) !== normalized) {
                return;
            }
        }

        if (root.draftTransitionFpsOverride === normalized)
            return;

        root.draftTransitionFpsOverride = normalized;
        root.transitionChanged();
        root.changed();
    }


    function prepareForRefreshAfterApply(): void {
        root.syncAfterApplyPending = true;
        root.syncAfterApplyDomain = "wallpaper";
    }

    function prepareForRefreshAfterRotationApply(): void {
        root.syncAfterApplyPending = true;
        root.syncAfterApplyDomain = "rotation";
    }

    function prepareForRefreshAfterTransitionApply(): void {
        root.syncAfterApplyPending = true;
        root.syncAfterApplyDomain = "transition";
    }

    function resetRotation(): void {
        root.syncAfterApplyPending = false;
        root.syncAfterApplyDomain = "";
        root.syncRotationFromObserved();
        root.refreshObservedConflict();
        root.rotationResetCompleted();
    }

    function resetTransition(): void {
        root.syncAfterApplyPending = false;
        root.syncAfterApplyDomain = "";
        root.syncTransitionFromObserved();
        root.refreshObservedConflict();
        root.transitionResetCompleted();
    }

    function reset(): void {
        root.syncAfterApplyPending = false;
        root.syncAfterApplyDomain = "";
        root.syncFromObserved(true);
        root.selectedTarget = "main";
        root.resetCompleted();
    }

    Connections {
        target: root.wallpaperService

        function onRefreshed() {
            if (root.syncAfterApplyPending) {
                const domain = root.syncAfterApplyDomain;

                root.syncAfterApplyPending = false;
                root.syncAfterApplyDomain = "";

                if (domain === "rotation")
                    root.syncRotationFromObserved();
                else if (domain === "transition")
                    root.syncTransitionFromObserved();
                else
                    root.syncWallpaperFromObserved();

                root.initialized = true;
                root.refreshObservedConflict();
                return;
            }

            root.syncFromObserved(false);
        }
    }

    Component.onCompleted: root.syncFromObserved(false)
}
