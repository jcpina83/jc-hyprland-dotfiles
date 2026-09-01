import QtQuick
import qs.components as Components

Item {
    id: root

    required property var theme
    property var themeData

    property bool observedActive: false
    property bool draftSelected: false
    property bool controlEnabled: true

    signal selected(string themeId)

    readonly property string selectionStateLabel:
        root.draftSelected
        ? (root.observedActive ? "ACTIVE · DRAFT" : "DRAFT")
        : (root.observedActive ? "ACTIVE" : "")

    readonly property string themeId:
        root.themeData
        ? String(root.themeData.id || "")
        : ""

    readonly property string themeName:
        root.themeData
        ? String(root.themeData.name || root.themeId)
        : root.themeId

    readonly property var previewData:
        root.themeData
        && root.themeData.preview
        ? root.themeData.preview
        : null

    readonly property var colorData:
        root.themeData
        && root.themeData.colors
        ? root.themeData.colors
        : null

    readonly property string mainWallpaperPath:
        root.previewData
        ? String(root.previewData.mainWallpaper || "")
        : ""

    readonly property string secondaryWallpaperPath:
        root.previewData
        ? String(root.previewData.secondaryWallpaper || "")
        : ""

    readonly property color previewPrimary:
        root.colorData
        && root.colorData.primary
        ? root.colorData.primary
        : root.theme.primary

    readonly property color previewSecondary:
        root.colorData
        && root.colorData.secondary
        ? root.colorData.secondary
        : root.theme.secondary

    readonly property color previewAccent:
        root.colorData
        && root.colorData.accent
        ? root.colorData.accent
        : root.theme.accent

    readonly property color previewSurface:
        root.colorData
        && root.colorData.surfaceBase
        ? root.colorData.surfaceBase
        : root.theme.surfaceBase

    function localSource(path) {
        const value = String(path || "");

        if (value.length === 0)
            return "";

        if (value.indexOf("file:") === 0)
            return value;

        if (value.indexOf("/") === 0)
            return "file://" + value;

        return value;
    }

    function fileName(path) {
        const value = String(path || "");

        if (value.length === 0)
            return "Not configured";

        const slashIndex = value.lastIndexOf("/");
        return slashIndex >= 0
            ? value.slice(slashIndex + 1)
            : value;
    }

    implicitWidth: 360
    implicitHeight: 328

    Components.JcSurface {
        anchors.fill: parent

        theme: root.theme
        surfaceRole: "glass-raised"
        selected: root.draftSelected
        opacity:
            root.controlEnabled
                ? 1
                : root.theme.opacityDisabled

        Row {
            anchors {
                top: parent.top
                right: parent.right
                margins: root.theme.spaceMd
            }

            z: 3
            spacing: root.theme.spaceXs

            Rectangle {
                visible: root.observedActive

                width:
                    activeLabel.implicitWidth
                    + root.theme.spaceSm * 2

                height: root.theme.controlHeightCompact
                radius: root.theme.radiusPill
                color: root.theme.surfaceOverlay

                border {
                    width: root.theme.borderWidthThin
                    color: root.theme.success
                }

                Text {
                    id: activeLabel

                    anchors.centerIn: parent
                    text: "ACTIVE"
                    color: root.theme.success
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                visible: root.draftSelected

                width:
                    draftLabel.implicitWidth
                    + root.theme.spaceSm * 2

                height: root.theme.controlHeightCompact
                radius: root.theme.radiusPill
                color: root.theme.surfaceOverlay

                border {
                    width: root.theme.borderWidthThin
                    color: root.theme.accent
                }

                Text {
                    id: draftLabel

                    anchors.centerIn: parent
                    text: "DRAFT"
                    color: root.theme.accent
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: Font.DemiBold
                }
            }
        }

        Column {
            anchors {
                fill: parent
                margins: root.theme.spaceMd
            }

            spacing: root.theme.spaceSm

            Item {
                width: parent.width
                height: 178
                clip: true

                Rectangle {
                    anchors.fill: parent

                    color: root.previewSurface
                    radius: root.theme.radiusMd

                    border {
                        width: root.theme.borderWidthThin
                        color: root.theme.borderSubtle
                    }
                }

                Image {
                    id: mainPreview

                    anchors.fill: parent
                    source: root.localSource(root.mainWallpaperPath)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true

                    visible:
                        root.mainWallpaperPath.length > 0
                        && mainPreview.status !== Image.Error
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - root.theme.spaceLg * 2

                    visible:
                        root.mainWallpaperPath.length === 0
                        || mainPreview.status === Image.Error

                    text: root.mainWallpaperPath.length === 0
                        ? "Main preview unavailable"
                        : "Main preview could not be loaded"

                    color: root.theme.textMuted
                    font.pixelSize: root.theme.textSizeBody
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                ThemeTokenPreview {
                    id: tokenPreview

                    anchors {
                        fill: parent
                        margins: root.theme.spaceSm
                    }

                    z: 1

                    theme: root.theme
                    themeData: root.themeData
                }

                Rectangle {
                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: root.theme.spaceSm
                    }

                    z: 2

                    width: 104
                    height: 66
                    radius: root.theme.radiusSm

                    color: root.previewSurface

                    border {
                        width: root.theme.borderWidthThin
                        color: root.theme.borderStrong
                    }

                    clip: true
                    visible: root.secondaryWallpaperPath.length > 0

                    Image {
                        id: secondaryPreview

                        anchors.fill: parent
                        source: root.localSource(root.secondaryWallpaperPath)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true

                        visible: secondaryPreview.status !== Image.Error
                    }
                }
            }

            Row {
                spacing: root.theme.spaceXs

                Rectangle {
                    width: root.theme.controlHeightCompact
                    height: root.theme.spaceXs
                    radius: root.theme.radiusPill
                    color: root.previewPrimary
                }

                Rectangle {
                    width: root.theme.controlHeightCompact
                    height: root.theme.spaceXs
                    radius: root.theme.radiusPill
                    color: root.previewSecondary
                }

                Rectangle {
                    width: root.theme.controlHeightCompact
                    height: root.theme.spaceXs
                    radius: root.theme.radiusPill
                    color: root.previewAccent
                }
            }

            Column {
                width: parent.width
                spacing: root.theme.space2Xs

                Text {
                    width: parent.width
                    text: root.themeName
                    color: root.theme.textPrimary
                    font.pixelSize: root.theme.textSizeSection
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.themeId
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    elide: Text.ElideRight
                }
            }

            Column {
                width: parent.width
                spacing: root.theme.space2Xs

                Text {
                    width: parent.width
                    text: "Main · " + root.fileName(root.mainWallpaperPath)
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    elide: Text.ElideMiddle
                }

                Text {
                    width: parent.width
                    text: "Secondary · " + root.fileName(root.secondaryWallpaperPath)
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    elide: Text.ElideMiddle
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: 4

            acceptedButtons: Qt.LeftButton
            enabled: root.controlEnabled
            hoverEnabled: root.controlEnabled

            cursorShape:
                root.controlEnabled
                    ? Qt.PointingHandCursor
                    : Qt.ArrowCursor

            onClicked: {
                if (root.controlEnabled && root.themeId.length > 0)
                    root.selected(root.themeId);
            }
        }
    }
}
