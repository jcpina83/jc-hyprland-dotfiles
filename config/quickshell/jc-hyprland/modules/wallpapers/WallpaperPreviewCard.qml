import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property string targetId: "main"
    property string outputName: ""
    property string wallpaperPath: ""
    property string effectivePath: ""
    property string fitMode: ""
    property bool targetSelected: false
    property bool draftDirty: false
    property bool controlEnabled: true

    signal clicked()

    readonly property string displayName:
        root.wallpaperPath.length > 0
            ? root.wallpaperPath.split("/").pop()
            : "No wallpaper"

    readonly property string sourceUrl:
        root.wallpaperPath.length > 0
            ? "file://" + root.wallpaperPath
            : ""

    implicitHeight: root.theme.controlHeightLarge * 3
    activeFocusOnTab: root.controlEnabled
    opacity: root.controlEnabled ? 1 : root.theme.opacityDisabled

    Keys.onPressed: event => {
        if (!root.controlEnabled)
            return;

        if (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    Components.JcSurface {
        id: previewSurface

        anchors.fill: parent

        theme: root.theme
        surfaceRole: "glass"
        bordered: false
        fillEnabled: false
        cornerRadius: 0
        selected: root.targetSelected
        focused: root.activeFocus

        Components.JcHudFrame {
            anchors.fill: parent
            anchors.margins: root.theme.space2Xs

            theme: root.theme
            surfaceRole: "glass"
            selected: root.targetSelected
            focused: root.activeFocus

            fillEnabled: true
            fillColor: root.targetSelected
                ? root.theme.hudSelectedSurface
                : root.theme.hudSurface
            contentPadding: 0
            cutSize: root.theme.spaceSm
            accentLength: root.theme.controlHeightLarge
            glowEnabled: root.targetSelected
            showInnerFrame: true
            showCornerAccents: true
            showSecondaryAccent: root.targetSelected
        }

        Components.JcRoundedImage {
            id: previewImage

            anchors.fill: parent
            anchors.margins:
                root.theme.spaceSm + root.theme.space2Xs

            source: root.sourceUrl
            radius: root.theme.radiusSm

            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(480, 240)
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins:
                root.theme.spaceSm + root.theme.space2Xs

            height: previewInfo.implicitHeight + (root.theme.spaceSm * 2)

            color: root.theme.surfaceOverlay
            radius: root.theme.radiusSm

            RowLayout {
                id: previewInfo

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: root.theme.spaceSm

                spacing: root.theme.spaceSm

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.space2Xs

                    Text {
                        Layout.fillWidth: true

                        text:
                            String(root.targetId).toUpperCase()
                            + " · "
                            + (root.outputName.length > 0
                                ? root.outputName
                                : "unknown output")

                        color: root.targetSelected
                            ? root.theme.accent
                            : root.theme.textPrimary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeBody
                        font.weight: root.theme.fontWeightSemibold

                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true

                        text: root.displayName
                        color: root.theme.textSecondary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeCaption
                        font.weight: root.theme.fontWeightRegular

                        elide: Text.ElideMiddle
                    }
                }

                Components.JcChip {
                    visible: root.targetSelected

                    theme: root.theme
                    text: "Target"
                    compact: true
                    checked: true
                    controlEnabled: false
                }

                Components.JcChip {
                    visible: root.draftDirty

                    theme: root.theme
                    text: "Draft"
                    compact: true
                    checked: true
                    controlEnabled: false
                }

                Text {
                    text: root.fitMode.length > 0
                        ? root.fitMode
                        : "cover"

                    color: root.theme.textMuted

                    font.family: root.theme.fontFamilyMono
                    font.pixelSize: root.theme.textSizeCaption
                }
            }
        }

        Text {
            anchors.centerIn: parent

            visible: root.wallpaperPath.length === 0

            text: "Preview unavailable"
            color: root.theme.textSecondary

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeBody
        }
    }

    MouseArea {
        anchors.fill: parent

        enabled: root.controlEnabled
        hoverEnabled: root.controlEnabled
        cursorShape: root.controlEnabled
            ? Qt.PointingHandCursor
            : Qt.ArrowCursor

        onPressed: root.forceActiveFocus()
        onClicked: root.clicked()
    }
}
