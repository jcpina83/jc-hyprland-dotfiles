import QtQuick
import Quickshell

Scope {
    id: root

    property var wallpaperService
    property var draftStore
    property var wallpaperApplyService
    property var rotationApplyService

    property bool sequenceRotationPending: false
    property string recoveryResetOwner: ""
    property string coordinatorErrorMessage: ""

    readonly property bool applying:
        (root.wallpaperApplyService
            && root.wallpaperApplyService.applying)
        || (root.rotationApplyService
            && root.rotationApplyService.applying)

    readonly property bool awaitingRefresh:
        (root.wallpaperApplyService
            && root.wallpaperApplyService.awaitingRefresh)
        || (root.rotationApplyService
            && root.rotationApplyService.awaitingRefresh)

    readonly property bool busy:
        (root.wallpaperApplyService
            && root.wallpaperApplyService.busy)
        || (root.rotationApplyService
            && root.rotationApplyService.busy)

    readonly property bool rollbackRecoveryRequired:
        (root.wallpaperApplyService
            && root.wallpaperApplyService.rollbackRecoveryRequired)
        || (root.rotationApplyService
            && root.rotationApplyService.rollbackRecoveryRequired)

    readonly property bool canApply: {
        if (root.busy
                || !root.draftStore
                || !root.draftStore.initialized
                || !root.draftStore.hasDirty
                || root.draftStore.observedChangedWhileDirty
                || root.rollbackRecoveryRequired) {
            return false;
        }

        if (root.draftStore.hasWallpaperDirty
                && (
                    !root.wallpaperApplyService
                    || !root.wallpaperApplyService.canApply
                )) {
            return false;
        }

        if (root.draftStore.rotationDirty
                && (
                    !root.rotationApplyService
                    || !root.rotationApplyService.canApply
                )) {
            return false;
        }

        return true;
    }

    readonly property string errorMessage: {
        if (root.coordinatorErrorMessage.length > 0)
            return root.coordinatorErrorMessage;

        if (root.rotationApplyService
                && root.rotationApplyService.errorMessage.length > 0) {
            return root.rotationApplyService.errorMessage;
        }

        if (root.wallpaperApplyService
                && root.wallpaperApplyService.errorMessage.length > 0) {
            return root.wallpaperApplyService.errorMessage;
        }

        return "";
    }

    readonly property string statusMessage: {
        if (root.recoveryResetOwner === "wallpaper")
            return "Recovering wallpaper state before unified Reset…";

        if (root.recoveryResetOwner === "rotation")
            return "Recovering rotation state before unified Reset…";

        if (root.sequenceRotationPending
                && root.wallpaperApplyService
                && root.wallpaperApplyService.busy) {
            return "Applying wallpaper changes before rotation…";
        }

        if (root.rotationApplyService
                && root.rotationApplyService.busy) {
            return root.rotationApplyService.statusMessage;
        }

        if (root.wallpaperApplyService
                && root.wallpaperApplyService.busy) {
            return root.wallpaperApplyService.statusMessage;
        }

        if (root.coordinatorErrorMessage.length > 0)
            return root.coordinatorErrorMessage;

        return "";
    }

    function clearTransientFeedback(): void {
        root.coordinatorErrorMessage = "";

        if (root.wallpaperApplyService
                && !root.wallpaperApplyService.rollbackRecoveryRequired) {
            root.wallpaperApplyService.clearTransientFeedback();
        }

        if (root.rotationApplyService
                && !root.rotationApplyService.rollbackRecoveryRequired) {
            root.rotationApplyService.clearTransientFeedback();
        }
    }

    function stopSequence(): void {
        root.sequenceRotationPending = false;
    }

    function startRotationAfterWallpaper(): void {
        root.sequenceRotationPending = false;

        if (!root.draftStore || !root.draftStore.rotationDirty)
            return;

        if (!root.rotationApplyService
                || !root.rotationApplyService.canApply) {
            root.coordinatorErrorMessage =
                "Wallpaper changes were applied, but the pending "
                + "rotation draft could not start. Review the draft "
                + "and Apply again.";
            return;
        }

        root.rotationApplyService.applyDirty();
    }

    function applyDirty(): void {
        if (root.busy || !root.draftStore)
            return;

        root.coordinatorErrorMessage = "";

        if (!root.canApply)
            return;

        const wallpaperDirty = root.draftStore.hasWallpaperDirty;
        const rotationDirty = root.draftStore.rotationDirty;

        if (wallpaperDirty) {
            root.sequenceRotationPending = rotationDirty;
            root.wallpaperApplyService.applyDirty();
            return;
        }

        root.sequenceRotationPending = false;

        if (rotationDirty)
            root.rotationApplyService.applyDirty();
    }

    function finishUnifiedReset(): void {
        root.recoveryResetOwner = "";
        root.sequenceRotationPending = false;
        root.coordinatorErrorMessage = "";
        root.clearTransientFeedback();
    }

    function continueRecoveryResetAfterWallpaper(): void {
        if (root.recoveryResetOwner !== "wallpaper")
            return;

        if (root.rotationApplyService
                && root.rotationApplyService.rollbackRecoveryRequired) {
            root.recoveryResetOwner = "rotation";
            Qt.callLater(function() {
                root.rotationApplyService.resetDraft();
            });
            return;
        }

        root.finishUnifiedReset();
    }

    function continueRecoveryResetAfterRotation(): void {
        if (root.recoveryResetOwner !== "rotation")
            return;

        root.recoveryResetOwner = "";

        if (root.draftStore)
            root.draftStore.reset();

        root.finishUnifiedReset();
    }

    function resetDraft(): void {
        if (root.busy || !root.draftStore)
            return;

        root.sequenceRotationPending = false;
        root.coordinatorErrorMessage = "";

        if (root.wallpaperApplyService
                && root.wallpaperApplyService.rollbackRecoveryRequired) {
            root.recoveryResetOwner = "wallpaper";
            root.wallpaperApplyService.resetDraft();
            return;
        }

        if (root.rotationApplyService
                && root.rotationApplyService.rollbackRecoveryRequired) {
            root.recoveryResetOwner = "rotation";
            root.rotationApplyService.resetDraft();
            return;
        }

        root.recoveryResetOwner = "";
        root.draftStore.reset();
        root.clearTransientFeedback();
    }

    Connections {
        target: root.wallpaperApplyService

        function onApplied() {
            if (!root.sequenceRotationPending)
                return;

            Qt.callLater(function() {
                root.startRotationAfterWallpaper();
            });
        }

        function onRolledBack() {
            root.stopSequence();
        }

        function onRollbackFailed() {
            root.stopSequence();
        }

        function onFailed() {
            root.stopSequence();
        }
    }

    Connections {
        target: root.draftStore

        function onResetCompleted() {
            root.continueRecoveryResetAfterWallpaper();
        }

        function onRotationResetCompleted() {
            root.continueRecoveryResetAfterRotation();
        }
    }
}
