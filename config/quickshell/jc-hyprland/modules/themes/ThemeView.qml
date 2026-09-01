import QtQuick
import qs.components as Components

Item {
    id: root

    required property var theme
    property var themeService
    property var draftStore
    property var applyService

    readonly property bool interactionLocked:
        root.applyService
        && Boolean(root.applyService.busy)

    readonly property bool observedConflict:
        root.draftStore
        && Boolean(root.draftStore.observedChangedWhileDirty)

    readonly property bool recoveryRequired:
        root.applyService
        && Boolean(root.applyService.rollbackRecoveryRequired)

    readonly property string operationError: {
        if (root.applyService
                && root.applyService.errorMessage.length > 0) {
            return root.applyService.errorMessage;
        }

        if (root.themeService
                && root.themeService.errorMessage.length > 0) {
            return root.themeService.errorMessage;
        }

        return "";
    }

    signal refreshRequested()
    signal applyRequested()
    signal resetRequested()
    signal recoverRequested()

    readonly property bool serviceReady:
        root.themeService !== null
        && root.themeService !== undefined
        && Boolean(root.themeService.ready)

    readonly property var themes:
        root.themeService
        && root.themeService.themes
        ? root.themeService.themes
        : []

    readonly property string activeThemeId:
        root.themeService
        ? String(root.themeService.activeThemeId || "")
        : ""

    readonly property int installedThemeCount:
        root.themeService
        ? Number(root.themeService.themeCount || 0)
        : 0

    readonly property string draftThemeId:
        root.draftStore
        ? String(root.draftStore.draftThemeId || "")
        : ""

    readonly property bool draftDirty:
        root.draftStore
        ? Boolean(root.draftStore.dirty)
        : false

    function selectTheme(themeId): void {
        const candidate = String(themeId || "");

        if (root.interactionLocked
                || root.observedConflict
                || !root.draftStore
                || candidate.length === 0) {
            return;
        }

        if (root.draftStore.setTheme(candidate)
                && root.applyService
                && typeof root.applyService.clearTransientFeedback
                    === "function") {
            root.applyService.clearTransientFeedback();
        }
    }

    Column {
        anchors {
            fill: parent
            margins: root.theme.spaceXl
        }

        spacing: root.theme.spaceLg

        Column {
            id: headerColumn

            width: parent.width
            spacing: root.theme.spaceSm

            Text {
                width: parent.width
                text: "Themes"
                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeSection
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: "Preview a theme, stage a draft, then choose Apply or Reset."
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: root.serviceReady
                    ? "Observed theme: " + root.activeThemeId
                        + " · Installed: " + root.installedThemeCount
                    : "Loading observed theme state…"
                color: root.serviceReady
                    ? root.theme.textPrimary
                    : root.theme.textMuted
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width
                text: root.draftDirty
                    ? "Draft pending: " + root.draftThemeId
                    : "Draft synchronized with observed state"
                color: root.draftDirty
                    ? root.theme.warning
                    : root.theme.success
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                spacing: root.theme.spaceSm

                Components.JcButton {
                    visible: root.draftDirty

                    theme: root.theme
                    iconName: "apply"

                    text:
                        root.applyService
                        && root.applyService.applying
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
                        root.draftDirty
                        || root.observedConflict

                    theme: root.theme
                    iconName: "reset"
                    text: "Reset"

                    controlEnabled:
                        !root.interactionLocked
                        && root.draftStore

                    onClicked: root.resetRequested()
                }

                Components.JcButton {
                    visible: root.recoveryRequired

                    theme: root.theme
                    iconName: "refresh"

                    text:
                        root.applyService
                        && root.applyService.recovering
                            ? "Recovering…"
                            : "Recover Runtime"

                    controlEnabled:
                        root.applyService
                        && root.applyService.canRecover

                    onClicked: root.recoverRequested()
                }

                Components.JcButton {
                    theme: root.theme
                    iconName: "refresh"

                    text:
                        root.themeService
                        && root.themeService.loading
                            ? "Refreshing…"
                            : "Refresh"

                    controlEnabled:
                        !root.interactionLocked
                        && root.themeService
                        && !root.themeService.loading
                        && !root.draftDirty
                        && !root.observedConflict

                    onClicked: root.refreshRequested()
                }
            }

            Text {
                width: parent.width

                visible: root.operationError.length > 0
                text: root.operationError
                color: root.theme.danger
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width

                visible: root.observedConflict
                text:
                    "Observed theme state changed while a draft was pending. "
                    + "Reset the draft before continuing."
                color: root.theme.warning
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.WordWrap
            }

            Text {
                width: parent.width

                visible: root.recoveryRequired
                text:
                    "Theme runtime recovery is required before another Apply. "
                    + "Recovery preserves the pending draft."
                color: root.theme.warning
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.WordWrap
            }
        }

        Item {
            width: parent.width
            height: Math.max(
                0,
                parent.height
                    - headerColumn.height
                    - parent.spacing
            )

            Text {
                anchors.centerIn: parent
                width: parent.width - root.theme.spaceXl * 2

                visible:
                    root.serviceReady
                    && root.installedThemeCount === 0

                text: "No installed themes were reported by ThemeService."
                color: root.theme.textMuted
                font.pixelSize: root.theme.textSizeBody
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            GridView {
                id: themeGrid

                anchors.fill: parent

                model: root.themes
                visible: root.installedThemeCount > 0

                readonly property int columnCount:
                    width >= 760 ? 2 : 1

                cellWidth:
                    width / Math.max(1, themeGrid.columnCount)

                cellHeight: 344
                cacheBuffer: cellHeight * 2
                clip: true
                interactive: true

                delegate: ThemePreviewCard {
                    required property int index

                    width:
                        themeGrid.cellWidth
                        - root.theme.spaceMd

                    height:
                        themeGrid.cellHeight
                        - root.theme.spaceMd

                    theme: root.theme
                    themeData: root.themes[index]

                    observedActive:
                        themeId.length > 0
                        && themeId === root.activeThemeId

                    draftSelected:
                        themeId.length > 0
                        && themeId === root.draftThemeId

                    controlEnabled:
                        !root.interactionLocked
                        && !root.observedConflict

                    onSelected: themeId =>
                        root.selectTheme(themeId)
                }
            }
        }
    }
}
