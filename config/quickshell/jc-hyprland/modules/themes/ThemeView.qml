import QtQuick

Item {
    id: root

    required property var theme
    property var themeService
    property var draftStore

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
                text: "Installed theme previews · selection and Apply controls arrive next."
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
                }
            }
        }
    }
}
