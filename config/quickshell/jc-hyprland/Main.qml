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

    Theme.Theme {
        id: theme
    }

    Services.MonitorService {
        id: monitorService
    }

    Displays.DisplayPopup {
        id: displayPopup

        visible: root.displaysVisible
        targetScreen: root.resolveScreen(monitorService.focusedOutputName)
        monitorService: monitorService
        theme: theme

        onCloseRequested: root.displaysVisible = false
        onRefreshRequested: monitorService.refresh()
    }

    IpcHandler {
        target: "controlCenter"

        function toggleDisplays(): void {
            root.displaysVisible = !root.displaysVisible;

            if (root.displaysVisible)
                monitorService.refresh();
        }

        function showDisplays(): void {
            root.displaysVisible = true;
            monitorService.refresh();
        }

        function hideDisplays(): void {
            root.displaysVisible = false;
        }

        function refreshDisplays(): void {
            monitorService.refresh();
        }

        function displaysAreVisible(): bool {
            return root.displaysVisible;
        }
    }
}
