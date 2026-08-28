import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import qs.components as Components

Item {
    id: root

    property var wallpaperService
    property var draftStore
    property var applyService
    required property var theme

    property string catalogFilter: "all"

    readonly property bool interactionLocked:
        root.applyService && root.applyService.busy

    readonly property string operationError: {
        if (root.applyService
                && root.applyService.errorMessage.length > 0) {
            return root.applyService.errorMessage;
        }

        if (root.wallpaperService
                && root.wallpaperService.errorMessage.length > 0) {
            return root.wallpaperService.errorMessage;
        }

        return "";
    }

    signal refreshRequested()
    signal applyRequested()
    signal resetRequested()

    readonly property var filteredWallpapers: {
        if (!root.wallpaperService
                || !Array.isArray(root.wallpaperService.wallpapers)) {
            return [];
        }

        if (root.catalogFilter === "all")
            return root.wallpaperService.wallpapers;

        const filtered = [];
        const source = root.wallpaperService.wallpapers;

        for (let i = 0; i < source.length; ++i) {
            const item = source[i];

            if (item
                    && String(item.source || "")
                        === root.catalogFilter) {
                filtered.push(item);
            }
        }

        return filtered;
    }

    readonly property string selectedDraftPath:
        root.draftStore
            ? root.draftStore.draftForTarget(
                root.draftStore.selectedTarget
            )
            : ""

    readonly property string selectedTargetLabel:
        root.draftStore
            ? root.draftStore.selectedTarget.toUpperCase()
            : "TARGET"

    function normalizeGridCurrentIndex(): void {
        if (root.filteredWallpapers.length === 0) {
            wallpaperGrid.currentIndex = -1;
            return;
        }

        if (wallpaperGrid.currentIndex < 0
                || wallpaperGrid.currentIndex
                    >= root.filteredWallpapers.length) {
            wallpaperGrid.currentIndex = 0;
        }
    }

    function activateCurrentGridItem(): void {
        if (root.interactionLocked)
            return;

        const index = wallpaperGrid.currentIndex;

        if (index < 0 || index >= root.filteredWallpapers.length)
            return;

        const item = root.filteredWallpapers[index];

        if (!item || !root.draftStore)
            return;

        root.draftStore.setSelectedWallpaper(
            String(item.path || "")
        );
    }

    onCatalogFilterChanged:
        Qt.callLater(root.normalizeGridCurrentIndex)

    ColumnLayout {
        anchors.fill: parent
        spacing: root.theme.spaceMd

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceMd

            Text {
                Layout.fillWidth: true

                text: {
                    if (!root.wallpaperService)
                        return "Wallpaper service unavailable";

                    if (root.wallpaperService.loading)
                        return "Loading wallpaper library…";

                    if (!root.wallpaperService.ready)
                        return "Wallpaper library not ready";

                    return root.wallpaperService.wallpaperCount
                        + " available · "
                        + root.wallpaperService.runtimeEngine
                        + " runtime";
                }

                color: root.theme.textSecondary

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium

                elide: Text.ElideRight
            }

            Components.JcButton {
                visible: root.draftStore && root.draftStore.hasDirty

                theme: root.theme

                text:
                    root.applyService && root.applyService.applying
                        ? "Applying…"
                        : root.applyService
                            && root.applyService.awaitingRefresh
                                ? "Reconciling…"
                                : "Apply"

                controlEnabled:
                    root.applyService
                    && root.applyService.canApply

                onClicked: root.applyRequested()
            }

            Components.JcButton {
                visible:
                    root.draftStore
                    && (
                        root.draftStore.hasDirty
                        || (
                            root.applyService
                            && root.applyService.rollbackRecoveryRequired
                        )
                    )

                theme: root.theme

                text:
                    root.applyService
                    && root.applyService.rollbackRecoveryRequired
                        ? "Refresh & Reset"
                        : "Reset"

                controlEnabled:
                    !root.interactionLocked
                    && root.draftStore

                onClicked: root.resetRequested()
            }

            Components.JcButton {
                theme: root.theme

                text:
                    root.wallpaperService
                    && root.wallpaperService.loading
                        ? "Refreshing…"
                        : "Refresh"

                controlEnabled:
                    !root.interactionLocked
                    && root.wallpaperService
                    && !root.wallpaperService.loading
                    && !(root.draftStore && root.draftStore.hasDirty)

                onClicked: root.refreshRequested()
            }
        }

        Components.JcSurface {
            visible: root.operationError.length > 0

            Layout.fillWidth: true

            implicitHeight:
                wallpaperErrorText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.dangerSurface
            border.color: root.theme.dangerBorder

            Text {
                id: wallpaperErrorText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text: root.operationError

                color: root.theme.danger

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium

                wrapMode: Text.WordWrap
            }
        }

        Components.JcSurface {
            visible:
                root.draftStore
                && root.draftStore.observedChangedWhileDirty

            Layout.fillWidth: true

            implicitHeight:
                observedWarningText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.warningSurface
            border.color: root.theme.warningBorder

            Text {
                id: observedWarningText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text:
                    "Observed wallpaper state changed while a draft was "
                    + "selected. Reset the draft before continuing."

                color: root.theme.warning

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium

                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: false

            Layout.minimumHeight:
                root.theme.controlHeightLarge * 3
            Layout.preferredHeight:
                root.theme.controlHeightLarge * 3
            Layout.maximumHeight:
                root.theme.controlHeightLarge * 3

            spacing: root.theme.spaceMd

            WallpaperPreviewCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                theme: root.theme

                targetId: "main"
                controlEnabled: !root.interactionLocked
                outputName: root.wallpaperService
                    ? root.wallpaperService.mainOutput
                    : ""
                wallpaperPath: root.draftStore
                    ? root.draftStore.draftMainPath
                    : ""
                effectivePath: root.wallpaperService
                    ? root.wallpaperService.mainEffective
                    : ""
                fitMode: root.draftStore
                    ? root.draftStore.draftMainFit
                    : "cover"

                targetSelected:
                    root.draftStore
                    && root.draftStore.selectedTarget === "main"

                draftDirty:
                    root.draftStore
                    && root.draftStore.mainDirty

                onClicked: {
                    if (root.draftStore)
                        root.draftStore.selectTarget("main");
                }
            }

            WallpaperPreviewCard {
                Layout.fillWidth: true
                Layout.fillHeight: true

                theme: root.theme

                targetId: "secondary"
                controlEnabled: !root.interactionLocked
                outputName: root.wallpaperService
                    ? root.wallpaperService.secondaryOutput
                    : ""
                wallpaperPath: root.draftStore
                    ? root.draftStore.draftSecondaryPath
                    : ""
                effectivePath: root.wallpaperService
                    ? root.wallpaperService.secondaryEffective
                    : ""
                fitMode: root.draftStore
                    ? root.draftStore.draftSecondaryFit
                    : "cover"

                targetSelected:
                    root.draftStore
                    && root.draftStore.selectedTarget === "secondary"

                draftDirty:
                    root.draftStore
                    && root.draftStore.secondaryDirty

                onClicked: {
                    if (root.draftStore)
                        root.draftStore.selectTarget("secondary");
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumHeight:
                root.theme.controlHeightLarge * 1.30
            Layout.preferredHeight:
                root.theme.controlHeightLarge * 1.30
            Layout.maximumHeight:
                root.theme.controlHeightLarge * 1.30

            spacing: root.theme.spaceMd

            WallpaperFitControl {
                Layout.fillWidth: true
                Layout.fillHeight: true

                theme: root.theme
                targetId: "main"
                outputName: root.wallpaperService
                    ? root.wallpaperService.mainOutput
                    : ""
                selectedFit: root.draftStore
                    ? root.draftStore.draftMainFit
                    : "cover"
                targetSelected:
                    root.draftStore
                    && root.draftStore.selectedTarget === "main"
                draftDirty:
                    root.draftStore
                    && root.draftStore.mainFitDirty
                controlEnabled: !root.interactionLocked

                onFitSelected: fitMode => {
                    if (!root.draftStore)
                        return;

                    root.draftStore.selectTarget("main");
                    root.draftStore.setFit("main", fitMode);
                }
            }

            WallpaperFitControl {
                Layout.fillWidth: true
                Layout.fillHeight: true

                theme: root.theme
                targetId: "secondary"
                outputName: root.wallpaperService
                    ? root.wallpaperService.secondaryOutput
                    : ""
                selectedFit: root.draftStore
                    ? root.draftStore.draftSecondaryFit
                    : "cover"
                targetSelected:
                    root.draftStore
                    && root.draftStore.selectedTarget === "secondary"
                draftDirty:
                    root.draftStore
                    && root.draftStore.secondaryFitDirty
                controlEnabled: !root.interactionLocked

                onFitSelected: fitMode => {
                    if (!root.draftStore)
                        return;

                    root.draftStore.selectTarget("secondary");
                    root.draftStore.setFit("secondary", fitMode);
                }
            }
        }

        Components.JcDivider {
            Layout.fillWidth: true
            theme: root.theme
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceSm

            Components.JcSectionHeader {
                Layout.fillWidth: true

                theme: root.theme
                title: "Library"
                subtitle:
                    root.filteredWallpapers.length
                    + " visible · target "
                    + root.selectedTargetLabel
                    + " · arrows + Enter"
            }

            Components.JcChip {
                theme: root.theme
                text: "All"
                compact: true
                controlEnabled: !root.interactionLocked
                checked: root.catalogFilter === "all"

                onClicked: root.catalogFilter = "all"
            }

            Components.JcChip {
                theme: root.theme
                text: "Theme"
                compact: true
                controlEnabled: !root.interactionLocked
                checked: root.catalogFilter === "theme"

                onClicked: root.catalogFilter = "theme"
            }

            Components.JcChip {
                theme: root.theme
                text: "Library"
                compact: true
                controlEnabled: !root.interactionLocked
                checked: root.catalogFilter === "library"

                onClicked: root.catalogFilter = "library"
            }
        }

        Components.JcSurface {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight:
                root.theme.controlHeightLarge * 4

            theme: root.theme
            surfaceRole: "glass"
            fillEnabled: false
            bordered: false

            Components.JcHudFrame {
                id: wallpaperGalleryHudFrame

                anchors.fill: parent
                anchors.margins: root.theme.space2Xs

                theme: root.theme
                surfaceRole: "glass"

                fillEnabled: true
                fillColor: root.theme.hudSurface
                contentPadding: 0

                cutSize: root.theme.spaceMd
                accentLength: root.theme.controlHeightLarge

                glowEnabled: false
                showInnerFrame: true
                showCornerAccents: true
                showSecondaryAccent: false
            }

            GridView {
                id: wallpaperGrid

                anchors.fill: parent
                anchors.margins: root.theme.spaceMd

                clip: true

                activeFocusOnTab: true
                keyNavigationEnabled: true
                keyNavigationWraps: false
                highlightFollowsCurrentItem: false

                model: root.filteredWallpapers

                readonly property int columnCount:
                    width >= 720 ? 3 : 2

                cellWidth:
                    Math.max(
                        1,
                        Math.floor(width / columnCount)
                    )

                cellHeight:
                    root.theme.controlHeightLarge * 3.05

                cacheBuffer: cellHeight * 2

                delegate: WallpaperTile {
                    required property int index
                    required property var modelData

                    width:
                        wallpaperGrid.cellWidth
                        - root.theme.spaceSm
                    height:
                        wallpaperGrid.cellHeight
                        - root.theme.spaceSm

                    theme: root.theme
                    controlEnabled: !root.interactionLocked

                    wallpaperPath:
                        String(modelData.path || "")
                    relativePath:
                        String(modelData.relative || "")
                    sourceType:
                        String(modelData.source || "library")

                    effectiveMain:
                        Boolean(modelData.effectiveMain)
                    effectiveSecondary:
                        Boolean(modelData.effectiveSecondary)

                    draftSelected:
                        root.selectedDraftPath
                        === String(modelData.path || "")

                    currentForTarget:
                        root.draftStore
                        && (
                            root.draftStore.selectedTarget === "main"
                                ? Boolean(modelData.effectiveMain)
                                : Boolean(modelData.effectiveSecondary)
                        )

                    keyboardCurrent:
                        wallpaperGrid.activeFocus
                        && index === wallpaperGrid.currentIndex

                    itemIndex: index

                    onActivated: (path, itemIndex) => {
                        if (root.interactionLocked)
                            return;

                        wallpaperGrid.currentIndex = itemIndex;
                        wallpaperGrid.forceActiveFocus();

                        if (root.draftStore)
                            root.draftStore.setSelectedWallpaper(path);
                    }
                }

                onCountChanged:
                    Qt.callLater(root.normalizeGridCurrentIndex)

                onCurrentIndexChanged: {
                    if (currentIndex >= 0)
                        positionViewAtIndex(currentIndex, GridView.Contain);
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space) {
                        root.activateCurrentGridItem();
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_Home) {
                        if (count > 0)
                            currentIndex = 0;

                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_End) {
                        if (count > 0)
                            currentIndex = count - 1;

                        event.accepted = true;
                    }
                }

                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    policy: Controls.ScrollBar.AsNeeded
                    interactive: true
                }
            }

            Text {
                anchors.centerIn: parent

                visible:
                    root.wallpaperService
                    && root.wallpaperService.ready
                    && root.filteredWallpapers.length === 0

                text: "No wallpapers in this source"
                color: root.theme.textSecondary

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
            }
        }
    }
}
