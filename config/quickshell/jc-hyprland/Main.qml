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

    property bool displaysVisible: false
    property bool galleryVisible: false
    property bool shellPreviewVisible: false

    property string requestedOutputName: ""
    property string shellPreviewOutputName: ""
    property string shellPreviewModuleId: "displays"

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

    function showDisplays() {
        root.galleryVisible = false;

        if (root.shellPreviewVisible) {
            root.hideShellPreview();

            if (root.shellPreviewVisible)
                return;
        }

        root.requestedOutputName = "";
        root.displaysVisible = true;
        root.prepareDisplays();
    }

    function showDisplaysOn(outputName) {
        const target = root.resolveScreen(outputName);

        root.galleryVisible = false;

        if (root.shellPreviewVisible) {
            root.hideShellPreview();

            if (root.shellPreviewVisible)
                return;
        }

        root.requestedOutputName =
            target && target.name === outputName ? outputName : "";

        root.displaysVisible = true;
        root.prepareDisplays();
    }

    function hideDisplays() {
        // Do not hide the confirmation UI while a Safe Apply is pending.
        if (monitorApplyService.pendingConfirmation
                || displayPersistenceService.saving)
            return;

        root.displaysVisible = false;
        root.requestedOutputName = "";
        displayDraftStore.reset();
    }

    function canOpenShellPreview() {
        return !displayDraftStore.hasDirty
            && !monitorApplyService.pendingConfirmation
            && !monitorApplyService.busy
            && !displayPersistenceService.saving;
    }

    function requestShellPreviewModule(moduleId) {
        // During Phase 2A.3 only Displays is operational.
        if (moduleId !== "displays")
            return;

        root.shellPreviewModuleId = moduleId;
    }

    function showShellPreview() {
        if (!root.canOpenShellPreview())
            return;

        root.galleryVisible = false;

        if (root.displaysVisible)
            root.hideDisplays();

        root.shellPreviewOutputName = "";
        root.shellPreviewModuleId = "displays";
        root.shellPreviewVisible = true;
    }

    function showShellPreviewOn(outputName) {
        if (!root.canOpenShellPreview())
            return;

        const target = root.resolveScreen(outputName);

        root.galleryVisible = false;

        if (root.displaysVisible)
            root.hideDisplays();

        root.shellPreviewOutputName =
            target && target.name === outputName ? outputName : "";

        root.shellPreviewModuleId = "displays";
        root.shellPreviewVisible = true;
    }

    function hideShellPreview() {
        // Once Displays is hosted here, preserve the same safety boundary as
        // the production display popup.
        if (monitorApplyService.busy
                || monitorApplyService.pendingConfirmation
                || displayPersistenceService.saving)
            return;

        root.shellPreviewVisible = false;
        root.shellPreviewOutputName = "";
        root.shellPreviewModuleId = "displays";
        displayDraftStore.reset();
    }

    function toggleShellPreview() {
        if (root.shellPreviewVisible)
            root.hideShellPreview();
        else
            root.showShellPreview();
    }

    function showGallery() {
        if (monitorApplyService.pendingConfirmation
                || displayPersistenceService.saving)
            return;

        if (root.displaysVisible)
            root.hideDisplays();

        if (root.shellPreviewVisible) {
            root.hideShellPreview();

            if (root.shellPreviewVisible)
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

    Displays.DisplayPopup {
        id: displayPopup

        visible: root.displaysVisible
        targetScreen: root.resolveScreen(
            root.requestedOutputName || monitorService.focusedOutputName
        )

        monitorService: monitorService
        draftStore: displayDraftStore
        applyService: monitorApplyService
        persistenceService: displayPersistenceService
        theme: theme

        onCloseRequested: root.hideDisplays()
        onRefreshRequested: {
            monitorService.refresh();
            displayPersistenceService.refreshPreview();
        }
        onResetRequested: displayDraftStore.reset()
        onApplyRequested: monitorApplyService.applyDirty()
        onKeepRequested: monitorApplyService.keepPending()
        onRollbackRequested: monitorApplyService.rollbackPending("user")
        onSaveRequested: displayPersistenceService.saveConfiguration()
    }

    Component {
        id: shellDisplaysComponent

        Displays.DisplayView {
            monitorService: monitorService
            draftStore: displayDraftStore
            applyService: monitorApplyService
            persistenceService: displayPersistenceService
            theme: theme

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
        id: controlCenterShellPreview

        visible: root.shellPreviewVisible

        targetScreen:
            root.resolveScreen(
                root.shellPreviewOutputName
                    || monitorService.focusedOutputName
            )

        theme: theme
        activeModuleId: root.shellPreviewModuleId

        contentComponent:
            root.shellPreviewModuleId === "displays"
                ? shellDisplaysComponent
                : null

        onCloseRequested: root.hideShellPreview()

        onModuleRequested: moduleId =>
            root.requestShellPreviewModule(moduleId)
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

        function toggleDisplays(): void {
            if (root.displaysVisible)
                root.hideDisplays();
            else
                root.showDisplays();
        }

        function showDisplays(): void {
            root.showDisplays();
        }

        function showDisplaysOn(outputName: string): void {
            root.showDisplaysOn(outputName);
        }

        function toggleDisplaysOn(outputName: string): void {
            const target = root.resolveScreen(outputName);

            if (root.displaysVisible
                    && target
                    && displayPopup.targetScreen
                    && displayPopup.targetScreen.name === target.name) {
                root.hideDisplays();
                return;
            }

            root.showDisplaysOn(outputName);
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

        function showShellPreview(): void {
            root.showShellPreview();
        }

        function showShellPreviewOn(outputName: string): void {
            root.showShellPreviewOn(outputName);
        }

        function hideShellPreview(): void {
            root.hideShellPreview();
        }

        function toggleShellPreview(): void {
            root.toggleShellPreview();
        }

        function shellPreviewIsVisible(): bool {
            return root.shellPreviewVisible;
        }

        readonly property string shellPreviewModule:
            root.shellPreviewModuleId

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

        function displaysAreVisible(): bool {
            return root.displaysVisible;
        }
    }
}
