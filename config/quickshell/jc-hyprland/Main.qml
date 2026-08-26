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
        if (monitorApplyService.busy
                || monitorApplyService.pendingConfirmation
                || displayPersistenceService.saving)
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

    // Phase 1D compatibility adapters. External integrations can continue
    // using the display-specific contract while the generic IPC settles.
    function showDisplays() {
        root.showControlCenter();
    }

    function showDisplaysOn(outputName) {
        root.showControlCenterOn(outputName);
    }

    function hideDisplays() {
        root.hideControlCenter();
    }

    function toggleDisplays() {
        root.toggleControlCenter();
    }

    function toggleDisplaysOn(outputName) {
        root.toggleControlCenterOn(outputName);
    }

    function showGallery() {
        if (monitorApplyService.busy
                || monitorApplyService.pendingConfirmation
                || displayPersistenceService.saving)
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

            showCloseAction: false

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

        visible: root.controlCenterVisible

        targetScreen:
            root.resolveScreen(
                root.controlCenterOutputName
                    || monitorService.focusedOutputName
            )

        theme: theme
        activeModuleId: root.activeModuleId

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

        function controlCenterIsVisible(): bool {
            return root.controlCenterVisible;
        }

        function showModule(moduleId: string): void {
            root.showModule(moduleId);
        }

        readonly property string activeModule:
            root.activeModuleId

        // Legacy display-specific compatibility adapters.
        function toggleDisplays(): void {
            root.toggleDisplays();
        }

        function showDisplays(): void {
            root.showDisplays();
        }

        function showDisplaysOn(outputName: string): void {
            root.showDisplaysOn(outputName);
        }

        function toggleDisplaysOn(outputName: string): void {
            root.toggleDisplaysOn(outputName);
        }

        function hideDisplays(): void {
            root.hideDisplays();
        }

        function refreshDisplays(): void {
            if (!displayDraftStore.hasDirty
                    && !monitorApplyService.pendingConfirmation
                    && !monitorApplyService.busy
                    && !displayPersistenceService.saving) {
                monitorService.refresh();
                displayPersistenceService.refreshPreview();
            }
        }

        function displaysAreVisible(): bool {
            return root.controlCenterVisible
                && root.activeModuleId === "displays";
        }

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
