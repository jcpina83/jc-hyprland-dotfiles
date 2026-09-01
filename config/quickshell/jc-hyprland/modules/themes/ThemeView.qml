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

        Text {
            width: parent.width
            text: "Themes"
            color: root.theme.textPrimary
            font.pixelSize: root.theme.textSizeSection
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            text: "Theme selection foundation · preview and Apply controls arrive next."
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
}
