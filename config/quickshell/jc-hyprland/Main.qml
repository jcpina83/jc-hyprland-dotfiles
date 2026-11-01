import QtQuick
import Quickshell
import Quickshell.Io

import qs.services as Services
import qs.theme as Theme
import qs.modules.displays as Displays
import qs.modules.wallpapers as Wallpapers
import qs.modules.themes as Themes
import qs.modules.quicksettings as QuickSettings
import qs.modules.performance as Performance
import qs.modules.media as Media
import qs.modules.network as Network
import qs.modules.dev as Dev
import qs.modules.controlcenter as ControlCenter

Scope {
    id: root

    property bool controlCenterVisible: false
    property bool galleryVisible: false
    property bool pendingSessionLock: false
    property bool pendingSessionSuspend: false

    property string controlCenterOutputName: ""
    property string activeModuleId: "displays"

    readonly property bool controlCenterTransitionLocked:
        monitorApplyService.busy
        || monitorApplyService.pendingConfirmation
        || displayPersistenceService.saving
        || wallpaperApplyService.busy
        || wallpaperRotationApplyService.busy
        || themeApplyService.busy
        || quickSettingsActionService.busy

    readonly property string controlCenterStatusText: {
        if (root.activeModuleId === "performance") {
            if (performanceService.loading)
                return "Refreshing Performance telemetry…";

            if (performanceService.errorMessage.length > 0)
                return "Performance telemetry error";

            if (performanceService.ready) {
                return performanceService.status === "partial"
                    ? "Performance telemetry partial"
                    : "Performance telemetry live";
            }

            return "Waiting for Performance telemetry…";
        }

        if (root.activeModuleId === "themes") {
            if (themeApplyService.applying)
                return "Applying theme…";

            if (themeApplyService.recovering)
                return "Recovering theme runtime…";

            if (themeApplyService.awaitingRefresh)
                return "Reconciling theme state…";

            if (themeApplyService.rollbackRecoveryRequired)
                return "Theme recovery required";

            if (themeApplyService.errorMessage.length > 0)
                return "Theme Apply error";

            if (themeDraftStore.observedChangedWhileDirty)
                return "Theme state changed";

            if (themeDraftStore.hasDirty)
                return themeDraftStore.dirtyCount
                    + " theme draft(s) pending";

            if (themeService.loading)
                return "Refreshing themes…";

            if (themeService.errorMessage.length > 0)
                return "Theme service error";

            if (themeService.ready)
                return themeService.themeCount + " themes available";
        }

        if (root.activeModuleId === "quick-settings") {
            if (quickSettingsActionService.applyingDnd)
                return "Updating Do Not Disturb…";

            if (quickSettingsActionService.applyingNightLight)
                return "Updating Night Light…";

            if (quickSettingsActionService.applyingLock)
                return "Locking session…";

            if (quickSettingsActionService.applyingSuspend)
                return "Suspending session…";

            if (quickSettingsActionService.awaitingRefresh
                    || quickSettingsActionService.awaitingNightLightRefresh) {
                return "Reconciling Quick Settings…";
            }

            if (quickSettingsActionService.errorMessage.length > 0)
                return "Quick Settings action error";

            if (quickSettingsService.loading)
                return "Refreshing Quick Settings…";

            if (quickSettingsService.errorMessage.length > 0)
                return "Quick Settings service error";

            if (quickSettingsService.ready) {
                if (quickSettingsService.dndEnabled)
                    return "Do Not Disturb enabled";

                if (quickSettingsService.nightLightEnabled === true)
                    return "Night Light enabled";

                return "Quick Settings ready";
            }
        }

        if (root.activeModuleId === "wallpapers") {
            if (wallpaperRotationApplyService.applying)
                return "Applying rotation changes…";

            if (wallpaperRotationApplyService.awaitingRefresh)
                return "Reconciling rotation state…";

            if (wallpaperRotationApplyService.rollbackRecoveryRequired)
                return "Rotation recovery required";

            if (wallpaperRotationApplyService.errorMessage.length > 0)
                return "Rotation Apply error";

            if (wallpaperApplyService.applying)
                return "Applying wallpaper changes…";

            if (wallpaperApplyService.awaitingRefresh)
                return "Reconciling wallpaper state…";

            if (wallpaperApplyService.rollbackRecoveryRequired)
                return "Wallpaper recovery required";

            if (wallpaperApplyService.errorMessage.length > 0)
                return "Wallpaper Apply error";

            if (wallpaperDraftStore.observedChangedWhileDirty)
                return "Wallpaper state changed";

            if (wallpaperDraftStore.hasDirty)
                return wallpaperDraftStore.dirtyCount
                    + " wallpaper draft(s) pending";

            if (wallpaperService.loading)
                return "Refreshing wallpapers…";

            if (wallpaperService.errorMessage.length > 0)
                return "Wallpaper service error";

            if (wallpaperService.ready)
                return wallpaperService.wallpaperCount
                    + " wallpapers available";
        }

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
        if (root.activeModuleId === "performance") {
            if (performanceService.errorMessage.length > 0)
                return performanceService.errorMessage;

            if (performanceService.ready) {
                return "Read-only telemetry refreshes every "
                    + (performanceService.refreshIntervalMs / 1000)
                    + " seconds while Performance is visible.";
            }

            return "Waiting for Performance observed state.";
        }

        if (root.activeModuleId === "themes") {
            if (themeApplyService.busy)
                return themeApplyService.statusMessage;

            if (themeApplyService.rollbackRecoveryRequired) {
                return "Recover the active theme runtime before another "
                    + "Apply. Recovery preserves the pending draft.";
            }

            if (themeApplyService.errorMessage.length > 0)
                return themeApplyService.errorMessage;

            if (themeDraftStore.observedChangedWhileDirty)
                return "Reset the draft before selecting or applying a theme.";

            if (themeDraftStore.hasDirty)
                return "Review the theme draft, then choose Apply or Reset.";

            if (themeService.errorMessage.length > 0)
                return themeService.errorMessage;

            if (themeService.ready)
                return "Select a theme to preview and stage a new draft.";

            return "Waiting for theme observed state.";
        }

        if (root.activeModuleId === "quick-settings") {
            if (quickSettingsActionService.busy)
                return quickSettingsActionService.statusMessage;

            if (quickSettingsActionService.errorMessage.length > 0)
                return quickSettingsActionService.errorMessage;

            if (quickSettingsService.errorMessage.length > 0)
                return quickSettingsService.errorMessage;

            if (quickSettingsService.ready) {
                return "Use Do Not Disturb, Night Light, Lock and Suspend now.";
            }

            return "Waiting for Quick Settings observed state.";
        }

        if (root.activeModuleId === "wallpapers") {
            if (wallpaperRotationApplyService.busy)
                return wallpaperRotationApplyService.statusMessage;

            if (wallpaperRotationApplyService.rollbackRecoveryRequired) {
                return "Rotation configuration was restored, but runtime "
                    + "rollback could not be verified. Review observed state.";
            }

            if (wallpaperRotationApplyService.errorMessage.length > 0)
                return wallpaperRotationApplyService.errorMessage;

            if (wallpaperApplyService.busy)
                return wallpaperApplyService.statusMessage;

            if (wallpaperApplyService.rollbackRecoveryRequired) {
                return "Preferences were restored, but runtime rollback "
                    + "could not be verified. Review observed state.";
            }

            if (wallpaperApplyService.errorMessage.length > 0)
                return wallpaperApplyService.errorMessage;

            if (wallpaperDraftStore.observedChangedWhileDirty)
                return "Reset the draft before selecting another wallpaper.";

            if (wallpaperDraftStore.hasDirty)
                return "Review the draft, then choose Apply or Reset.";

            if (wallpaperService.errorMessage.length > 0)
                return wallpaperService.errorMessage;

            if (wallpaperService.ready)
                return "Select MAIN or SECONDARY, then choose a wallpaper.";

            return "Waiting for wallpaper observed state.";
        }

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
    readonly property var wallpaperServiceHandle: wallpaperService
    readonly property var wallpaperApplyServiceHandle: wallpaperApplyService
    readonly property var wallpaperTransitionApplyServiceHandle:
        wallpaperTransitionApplyService
    readonly property var wallpaperRotationApplyServiceHandle:
        wallpaperRotationApplyService
    readonly property var wallpaperMutationCoordinatorHandle:
        wallpaperMutationCoordinator
    readonly property var themeHandle: theme
    readonly property var themeServiceHandle: themeService
    readonly property var quickSettingsServiceHandle: quickSettingsService
    readonly property var performanceServiceHandle: performanceService
    readonly property var mediaServiceHandle: mediaService
    readonly property var mediaActionServiceHandle: mediaActionService
    readonly property var networkServiceHandle: networkService
    readonly property var bluetoothServiceHandle: bluetoothService
    readonly property var networkActionServiceHandle: networkActionService
    readonly property var bluetoothActionServiceHandle: bluetoothActionService
    readonly property var quickSettingsActionServiceHandle:
        quickSettingsActionService
    readonly property var themeDraftStoreHandle: themeDraftStore
    readonly property var themeApplyServiceHandle: themeApplyService

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

    function prepareWallpapers() {
        if (!wallpaperDraftStore.hasDirty)
            wallpaperService.refresh();
    }

    function prepareThemes() {
        if (!themeDraftStore.hasDirty
                && !themeApplyService.busy) {
            themeService.refresh();
        }
    }

    function prepareQuickSettings() {
        if (!quickSettingsActionService.busy) {
            quickSettingsActionService.clearTransientFeedback();
            quickSettingsService.refresh();
        }
    }

    function moduleIsAvailable(moduleId) {
        if (moduleId === "themes"
                || moduleId === "quick-settings"
                || moduleId === "performance"
                || moduleId === "media") {
            return true;
        }

        if (moduleId === "network")
            return true;

        return moduleId === "displays"
            || moduleId === "wallpapers";
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

        if (moduleId === "wallpapers" && (!wasVisible || moduleChanged))
            root.prepareWallpapers();

        if (moduleId === "themes" && (!wasVisible || moduleChanged))
            root.prepareThemes();

        if (moduleId === "quick-settings"
                && (!wasVisible || moduleChanged)) {
            root.prepareQuickSettings();
        }
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

    function dispatchPendingSessionLock(): void {
        if (!root.pendingSessionLock)
            return;

        // requestedVisible=false is only the logical close request.
        // Do not launch Hyprlock until the PanelWindow has completed its
        // exit motion and ControlCenterShell reports mounted=false.
        if (controlCenterShell.mounted)
            return;

        root.pendingSessionLock = false;
        quickSettingsActionService.lockSession();
    }

    function requestSessionLock(): void {
        if (root.pendingSessionLock
                || root.pendingSessionSuspend
                || quickSettingsActionService.busy) {
            return;
        }

        root.pendingSessionLock = true;
        root.hideControlCenter();

        // hideControlCenter() can be refused by an unrelated guarded
        // transition. Never lock while the Control Center is still
        // logically requested visible.
        if (root.controlCenterVisible) {
            root.pendingSessionLock = false;
            return;
        }

        // Covers the already-unmounted case without depending on a fixed
        // animation duration.
        Qt.callLater(root.dispatchPendingSessionLock);
    }


    function dispatchPendingSessionSuspend(): void {
        if (!root.pendingSessionSuspend)
            return;

        if (controlCenterShell.mounted)
            return;

        root.pendingSessionSuspend = false;
        quickSettingsActionService.suspendSession();
    }

    function requestSessionSuspend(): void {
        if (root.pendingSessionLock
                || root.pendingSessionSuspend
                || quickSettingsActionService.busy) {
            return;
        }

        root.pendingSessionSuspend = true;
        root.hideControlCenter();

        if (root.controlCenterVisible) {
            root.pendingSessionSuspend = false;
            return;
        }

        Qt.callLater(root.dispatchPendingSessionSuspend);
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
        wallpaperDraftStore.reset();
        themeDraftStore.reset();
        themeApplyService.clearTransientFeedback();
        quickSettingsActionService.clearTransientFeedback();
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
        if (root.activeModuleId === "themes") {
            if (!themeDraftStore.hasDirty
                    && !themeApplyService.busy) {
                themeService.refresh();
            }

            return;
        }

        if (root.activeModuleId === "wallpapers") {
            if (!wallpaperDraftStore.hasDirty)
                wallpaperService.refresh();

            return;
        }

        if (root.activeModuleId === "quick-settings") {
            if (!quickSettingsActionService.busy)
                quickSettingsService.refresh();

            return;
        }

        if (root.activeModuleId === "performance") {
            performanceService.refresh();
            return;
        }

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


    Services.ThemeService {
        id: themeService
    }


    Services.QuickSettingsService {
        id: quickSettingsService
    }


    Services.PerformanceService {
        id: performanceService

        liveUpdatesEnabled:
            root.controlCenterVisible
            && root.activeModuleId === "performance"
    }

    Services.MediaService {
        id: mediaService

        liveUpdatesEnabled:
            root.controlCenterVisible
            && root.activeModuleId === "media"
    }

    Services.MediaActionService {
        id: mediaActionService
        mediaService: mediaService
    }

    Services.NetworkService {
        id: networkService
    }

    Services.BluetoothService {
        id: bluetoothService
    }

    Services.NetworkActionService {
        id: networkActionService
        networkService: networkService
    }

    Services.BluetoothActionService {
        id: bluetoothActionService
        bluetoothService: bluetoothService
    }

    Services.QuickSettingsActionService {
        id: quickSettingsActionService
        quickSettingsService: quickSettingsService
    }


    Services.ThemeDraftStore {
        id: themeDraftStore
        themeService: themeService
    }


    Services.ThemeApplyService {
        id: themeApplyService
        themeService: themeService
        draftStore: themeDraftStore
    }


    Services.MonitorModeParser {
        id: monitorModeParser
    }

    Services.MonitorService {
        id: monitorService
    }

    Services.WallpaperService {
        id: wallpaperService
    }

    Services.WallpaperDraftStore {
        id: wallpaperDraftStore

        wallpaperService: wallpaperService
    }

    Services.WallpaperApplyService {
        id: wallpaperApplyService

        wallpaperService: wallpaperService
        draftStore: wallpaperDraftStore
    }

    Services.WallpaperTransitionApplyService {
        id: wallpaperTransitionApplyService

        wallpaperService: wallpaperService
        draftStore: wallpaperDraftStore
    }

    Services.WallpaperRotationApplyService {
        id: wallpaperRotationApplyService

        wallpaperService: wallpaperService
        draftStore: wallpaperDraftStore
    }

    Services.WallpaperMutationCoordinator {
        id: wallpaperMutationCoordinator

        wallpaperService: wallpaperService
        draftStore: wallpaperDraftStore
        wallpaperApplyService: wallpaperApplyService
        transitionApplyService: wallpaperTransitionApplyService
        rotationApplyService: wallpaperRotationApplyService
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
        id: shellWallpapersComponent

        Wallpapers.WallpaperView {
            wallpaperService: root.wallpaperServiceHandle
            draftStore: wallpaperDraftStore
            applyService: root.wallpaperMutationCoordinatorHandle
            theme: root.themeHandle

            onRefreshRequested: wallpaperService.refresh()
            onApplyRequested: wallpaperMutationCoordinator.applyDirty()
            onResetRequested: wallpaperMutationCoordinator.resetDraft()
        }
    }

    Component {
        id: shellThemesComponent

        Themes.ThemeView {
            theme: root.themeHandle
            themeService: root.themeServiceHandle
            draftStore: root.themeDraftStoreHandle
            applyService: root.themeApplyServiceHandle

            onRefreshRequested: themeService.refresh()
            onApplyRequested: themeApplyService.applyDirty()

            onResetRequested: {
                themeDraftStore.reset();
                themeApplyService.clearTransientFeedback();
            }

            onRecoverRequested: themeApplyService.recoverRuntime()
        }
    }


    Component {
        id: shellQuickSettingsComponent

        QuickSettings.QuickSettingsView {
            theme: root.themeHandle
            quickSettingsService: root.quickSettingsServiceHandle
            actionService: root.quickSettingsActionServiceHandle

            onRefreshRequested: quickSettingsService.refresh()
            onDndRequested: enabled =>
                quickSettingsActionService.setDndEnabled(enabled)
            onNightLightRequested: enabled =>
                quickSettingsActionService.setNightLightEnabled(enabled)
            onLockRequested: root.requestSessionLock()
            onSuspendRequested: root.requestSessionSuspend()
        }
    }


    Component {
        id: shellPerformanceComponent

        Performance.PerformanceView {
            theme: controlCenterShell.theme
            performanceService: root.performanceServiceHandle

            onRefreshRequested: performanceService.refresh()
        }
    }

    Component {
        id: shellMediaComponent

        Media.MediaView {
            theme: controlCenterShell.theme
            mediaService: root.mediaServiceHandle
            actionService: root.mediaActionServiceHandle

            onRefreshRequested: {
                mediaActionService.clearTransientFeedback();
                mediaService.refresh();
            }

            onPlayPauseRequested: mediaActionService.playPause()
            onNextRequested: mediaActionService.next()
            onPreviousRequested: mediaActionService.previous()
            onSeekRequested: seconds =>
                mediaActionService.seekTo(seconds)
            onSinkVolumeRequested: value =>
                mediaActionService.setSinkVolume(value)
            onSinkMuteRequested: mode =>
                mediaActionService.setSinkMute(mode)
        }
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


    Component {
        id: shellNetworkComponent

        Network.NetworkView {
            theme: controlCenterShell.theme
            networkService: root.networkServiceHandle
            bluetoothService: root.bluetoothServiceHandle
            networkActionService: root.networkActionServiceHandle
            bluetoothActionService: root.bluetoothActionServiceHandle
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
                : root.activeModuleId === "wallpapers"
                    ? "Wallpapers"
                    : root.activeModuleId === "quick-settings"
                        ? "Quick Settings"
                        : root.activeModuleId === "performance"
                            ? "Performance"
                            : root.activeModuleId === "media"
                                ? "Media"
                                : root.activeModuleId
        transitionLocked: root.controlCenterTransitionLocked
        statusText: root.controlCenterStatusText
        statusDetail: root.controlCenterStatusDetail

        contentComponent:
            root.activeModuleId === "displays"
                ? shellDisplaysComponent
                : root.activeModuleId === "wallpapers"
                    ? shellWallpapersComponent
                    : root.activeModuleId === "themes"
                        ? shellThemesComponent
                        : root.activeModuleId === "quick-settings"
                            ? shellQuickSettingsComponent
                            : root.activeModuleId === "performance"
                                ? shellPerformanceComponent
                                : root.activeModuleId === "media"
                                    ? shellMediaComponent
                                    : root.activeModuleId === "network"
                                    ? shellNetworkComponent
                                    : null

        onCloseRequested: root.hideControlCenter()

        onModuleRequested: moduleId =>
            root.showModule(moduleId)

        onMountedChanged: {
            if (!mounted) {
                root.dispatchPendingSessionLock();
                root.dispatchPendingSessionSuspend();
            }
        }
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
