import QtQuick
import Quickshell
import Quickshell.Io

import qs.services as Services
import qs.theme as Theme
import qs.modules.displays as Displays
import qs.modules.dev as Dev
import qs.modules.controlcenter as ControlCenter

Scope {
    id: root

    property bool controlCenterVisible: false
    property bool galleryVisible: false

    property string controlCenterOutputName: ""
    property string activeModuleId: "displays"

    readonly property bool controlCenterTransitionLocked:
        monitorApplyService.busy
        || monitorApplyService.pendingConfirmation
        || displayPersistenceService.saving

    readonly property string controlCenterStatusText: {
        if (displayPersistenceService.saving)
            return "Saving display configuration…";

        if (monitorApplyService.pendingConfirmation)
            return "Safe Apply confirmation pending";

        if (monitorApplyService.busy)
            return "Applying display changes…";

        if (displayDraftStore.hasDirty)
            return displayDraftStore.dirtyCount
                + " draft change(s) pending";

        return "Ready";
    }

    readonly property string controlCenterStatusDetail: {
        if (displayPersistenceService.saving)
            return "Finish saving before closing or changing modules.";

        if (monitorApplyService.pendingConfirmation)
            return "Keep or roll back the display change before leaving.";

        if (monitorApplyService.busy)
            return "Wait for the display operation to finish.";

        if (displayDraftStore.hasDirty)
            return "Draft changes have not been applied.";

        return "No pending Control Center operation.";
    }

    // Explicit binding handle for dynamically-instantiated feature views.
    readonly property var monitorServiceHandle: monitorService

    function resolveScreen(outputName) {
        if (Quickshell.screens.length === 0)
            return null;

        if (!outputName)
            return Quickshell.screens[0];

        for (let i = 0; i < Quickshell.screens.length; ++i) {
            if (Quickshell.screens[i].name === outputName)
                return Quickshell.screens[i];
        }

        return Quickshell.screens[0];
    }

    function prepareDisplays() {
        monitorApplyService.recoverPending();
        monitorService.refresh();
        displayPersistenceService.refreshPreview();
    }

    function moduleIsAvailable(moduleId) {
        // Phase 2A.3 ships the generic shell with Displays as the only
        // operational module. Future modules are enabled in Phase 2B–2H.
        return moduleId === "displays";
    }

    function showModule(moduleId) {
        if (!root.moduleIsAvailable(moduleId))
            return;

        if (root.controlCenterVisible
                && root.activeModuleId !== moduleId
                && root.controlCenterTransitionLocked)
            return;

        const wasVisible = root.controlCenterVisible;
        const moduleChanged = root.activeModuleId !== moduleId;

        root.galleryVisible = false;
        root.activeModuleId = moduleId;
        root.controlCenterVisible = true;

        if (moduleId === "displays" && (!wasVisible || moduleChanged))
            root.prepareDisplays();
    }

    function showControlCenter() {
        root.controlCenterOutputName = "";
        root.showModule("displays");
    }

    function showControlCenterOn(outputName) {
        const target = root.resolveScreen(outputName);

        root.controlCenterOutputName =
            target && target.name === outputName ? outputName : "";

        root.showModule("displays");
    }

    function hideControlCenter() {
        // Never hide the confirmation UI while display mutation or
        // persistence is in progress.
        if (root.controlCenterTransitionLocked)
            return;

        root.controlCenterVisible = false;
        root.controlCenterOutputName = "";
        root.activeModuleId = "displays";
        displayDraftStore.reset();
    }

    function toggleControlCenter() {
        if (root.controlCenterVisible)
            root.hideControlCenter();
        else
            root.showControlCenter();
    }

    function toggleControlCenterOn(outputName) {
        const target = root.resolveScreen(outputName);

        if (root.controlCenterVisible
                && target
                && controlCenterShell.targetScreen
                && controlCenterShell.targetScreen.name === target.name) {
            root.hideControlCenter();
            return;
        }

        root.showControlCenterOn(outputName);
    }

    function refreshControlCenter() {
        if (root.activeModuleId !== "displays")
            return;

        if (!displayDraftStore.hasDirty
                && !monitorApplyService.pendingConfirmation
                && !monitorApplyService.busy
                && !displayPersistenceService.saving) {
            monitorService.refresh();
            displayPersistenceService.refreshPreview();
        }
    }







    function showGallery() {
        if (root.controlCenterTransitionLocked)
            return;

        if (root.controlCenterVisible) {
            root.hideControlCenter();

            if (root.controlCenterVisible)
                return;
        }

        root.galleryVisible = true;
    }

    function hideGallery() {
        root.galleryVisible = false;
    }

    function toggleGallery() {
        if (root.galleryVisible)
            root.hideGallery();
        else
            root.showGallery();
    }

    Theme.Theme {
        id: theme
    }

    Services.MonitorModeParser {
        id: monitorModeParser
    }

    Services.MonitorService {
        id: monitorService
    }

    Services.DisplayDraftStore {
        id: displayDraftStore

        monitorService: monitorService
        modeParser: monitorModeParser
    }

    Services.MonitorApplyService {
        id: monitorApplyService

        monitorService: monitorService
        draftStore: displayDraftStore
        confirmationTimeoutSeconds: 15

        onKept: displayPersistenceService.refreshPreview()
        onRolledBack: displayPersistenceService.refreshPreview()
    }

    Services.DisplayPersistenceService {
        id: displayPersistenceService

        draftStore: displayDraftStore
        applyService: monitorApplyService

        onSaved: monitorService.refresh()
    }

    Component {
        id: shellDisplaysComponent

        Displays.DisplayView {
            monitorService: root.monitorServiceHandle
            draftStore: displayDraftStore
            applyService: monitorApplyService
            persistenceService: displayPersistenceService
            theme: controlCenterShell.theme

            onRefreshRequested: {
                monitorService.refresh();
                displayPersistenceService.refreshPreview();
            }

            onResetRequested: displayDraftStore.reset()
            onApplyRequested: monitorApplyService.applyDirty()
            onKeepRequested: monitorApplyService.keepPending()
            onRollbackRequested:
                monitorApplyService.rollbackPending("user")
            onSaveRequested:
                displayPersistenceService.saveConfiguration()
        }
    }

    ControlCenter.ControlCenterShell {
        id: controlCenterShell

        requestedVisible: root.controlCenterVisible

        targetScreen:
            root.resolveScreen(
                root.controlCenterOutputName
                    || monitorService.focusedOutputName
            )

        theme: theme
        activeModuleId: root.activeModuleId
        activeModuleTitle:
            root.activeModuleId === "displays"
                ? "Displays"
                : root.activeModuleId
        transitionLocked: root.controlCenterTransitionLocked
        statusText: root.controlCenterStatusText
        statusDetail: root.controlCenterStatusDetail

        contentComponent:
            root.activeModuleId === "displays"
                ? shellDisplaysComponent
                : null

        onCloseRequested: root.hideControlCenter()

        onModuleRequested: moduleId =>
            root.showModule(moduleId)
    }

    Dev.ComponentGallery {
        id: componentGallery

        visible: root.galleryVisible

        targetScreen:
            root.resolveScreen(
                monitorService.focusedOutputName
            )

        theme: theme

        onCloseRequested: root.hideGallery()
    }

    IpcHandler {
        target: "controlCenter"

        // Generic Control Center API.
        function showControlCenter(): void {
            root.showControlCenter();
        }

        function showControlCenterOn(outputName: string): void {
            root.showControlCenterOn(outputName);
        }

        function toggleControlCenter(): void {
            root.toggleControlCenter();
        }

        function toggleControlCenterOn(outputName: string): void {
            root.toggleControlCenterOn(outputName);
        }

        function hideControlCenter(): void {
            root.hideControlCenter();
        }

        function refreshControlCenter(): void {
            root.refreshControlCenter();
        }

        function controlCenterIsVisible(): bool {
            return root.controlCenterVisible;
        }

        function showModule(moduleId: string): void {
            root.showModule(moduleId);
        }

        readonly property string activeModule:
            root.activeModuleId








        // Development gallery API.
        function toggleGallery(): void {
            root.toggleGallery();
        }

        function showGallery(): void {
            root.showGallery();
        }

        function hideGallery(): void {
            root.hideGallery();
        }

        function galleryIsVisible(): bool {
            return root.galleryVisible;
        }
    }
}
