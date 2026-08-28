import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property string wallpaperPath: ""
    property string relativePath: ""
    property string sourceType: "library"

    property bool effectiveMain: false
    property bool effectiveSecondary: false
    property bool draftSelected: false
    property bool currentForTarget: false
    property bool keyboardCurrent: false
    property int itemIndex: -1

    readonly property string stateLabel:
        root.draftSelected
            ? "DRAFT"
            : root.currentForTarget
                ? "CURRENT"
                : ""

    readonly property color stateColor:
        root.draftSelected
            ? root.theme.accent
            : root.theme.success

    signal activated(string path, int itemIndex)

    readonly property string displayName:
        root.relativePath.length > 0
            ? root.relativePath
            : root.wallpaperPath.split("/").pop()

    readonly property string sourceUrl:
        root.wallpaperPath.length > 0
            ? "file://" + root.wallpaperPath
            : ""

    activeFocusOnTab: false

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.activated(root.wallpaperPath, root.itemIndex);
            event.accepted = true;
        }
    }

    Components.JcSurface {
        anchors.fill: parent
        anchors.margins: root.theme.space2Xs

        theme: root.theme
        surfaceRole: "interactive"
        bordered: false
        fillEnabled: false
        cornerRadius: 0
        selected: root.draftSelected
        focused: root.keyboardCurrent

        Components.JcHudFrame {
            anchors.fill: parent
            anchors.margins: root.theme.space2Xs

            theme: root.theme
            surfaceRole: "glass"
            selected: root.draftSelected
            focused: root.keyboardCurrent

            fillEnabled: true
            fillColor: root.draftSelected
                ? root.theme.hudSelectedSurface
                : root.theme.hudSurface
            contentPadding: 0

            cutSize: root.theme.spaceSm
            accentLength: root.theme.controlHeightDefault

            glowEnabled: root.draftSelected
            showInnerFrame: false
            showCornerAccents: true
            showSecondaryAccent: root.draftSelected
        }

        Components.JcRoundedImage {
            id: thumbnail

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            anchors.leftMargin:
                root.theme.spaceSm + root.theme.space2Xs
            anchors.rightMargin:
                root.theme.spaceSm + root.theme.space2Xs
            anchors.topMargin:
                root.theme.spaceSm + root.theme.space2Xs

            height: Math.max(
                root.theme.controlHeightLarge * 1.35,
                parent.height - metadata.height - (root.theme.spaceSm * 3)
            )

            source: root.sourceUrl
            radius: root.theme.radiusXs

            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(320, 180)
        }

        Rectangle {
            id: metadata

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            anchors.leftMargin: root.theme.spaceSm
            anchors.rightMargin: root.theme.spaceSm
            anchors.bottomMargin: root.theme.spaceSm

            height: metadataRow.implicitHeight + (root.theme.spaceXs * 2)

            radius: root.theme.radiusSm
            color: root.theme.surfaceOverlay

            RowLayout {
                id: metadataRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: root.theme.spaceXs

                spacing: root.theme.spaceXs

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true

                        text: root.displayName
                        color: root.draftSelected
                            ? root.theme.accent
                            : root.theme.textPrimary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeCaption
                        font.weight: root.theme.fontWeightMedium

                        elide: Text.ElideMiddle
                    }

                    Text {
                        Layout.fillWidth: true

                        text:
                            String(root.sourceType).toUpperCase()
                            + (root.effectiveMain ? " · MAIN" : "")
                            + (root.effectiveSecondary
                                ? " · SECONDARY"
                                : "")

                        color: root.theme.textMuted

                        font.family: root.theme.fontFamilyMono
                        font.pixelSize: root.theme.textSizeMicro

                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: root.stateLabel.length > 0

                    text: root.stateLabel
                    color: root.stateColor

                    font.family: root.theme.fontFamilyMono
                    font.pixelSize: root.theme.textSizeMicro
                    font.weight: root.theme.fontWeightSemibold
                }

                Rectangle {
                    visible: root.stateLabel.length > 0

                    Layout.preferredWidth: root.theme.spaceSm
                    Layout.preferredHeight: root.theme.spaceSm

                    radius: width / 2
                    color: root.stateColor
                }
            }
        }

        Text {
            anchors.centerIn: thumbnail

            visible: root.wallpaperPath.length === 0

            text: "No preview"
            color: root.theme.textSecondary

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeCaption
        }
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onPressed: root.forceActiveFocus()
        onClicked: root.activated(root.wallpaperPath, root.itemIndex)
    }
}
