import QtQuick
import Quickshell
import Quickshell.Io

import qs.services as Services
import qs.theme as Theme
import qs.modules.displays as Displays

Scope {
    id: root

    property bool displaysVisible: false

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

    function showDisplays() {
        root.displaysVisible = true;
        monitorApplyService.recoverPending();
        monitorService.refresh();
        displayPersistenceService.refreshPreview();
    }

    function hideDisplays() {
        // Do not hide the confirmation UI while a Safe Apply is pending.
        if (monitorApplyService.pendingConfirmation
                || displayPersistenceService.saving)
            return;

        root.displaysVisible = false;
        displayDraftStore.reset();
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
        targetScreen: root.resolveScreen(monitorService.focusedOutputName)

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
            return root.displaysVisible;
        }
    }
}
