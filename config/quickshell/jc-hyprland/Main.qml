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
        monitorService.refresh();
    }

    function hideDisplays() {
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
    }

    Displays.DisplayPopup {
        id: displayPopup

        visible: root.displaysVisible
        targetScreen: root.resolveScreen(monitorService.focusedOutputName)

        monitorService: monitorService
        draftStore: displayDraftStore
        applyService: monitorApplyService
        theme: theme

        onCloseRequested: root.hideDisplays()
        onRefreshRequested: monitorService.refresh()
        onResetRequested: displayDraftStore.reset()
        onApplyRequested: monitorApplyService.applyDirty()
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
            if (!displayDraftStore.hasDirty)
                monitorService.refresh();
        }

        function displaysAreVisible(): bool {
            return root.displaysVisible;
        }
    }
}
