import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.components as Components

PanelWindow {
    id: root

    required property var targetScreen
    required property var theme

    property string title: "Control Center"
    property string activeModuleId: "displays"
    property string activeModuleTitle: "Displays"
    property string statusText: "Ready"
    property string statusDetail: ""
    property bool transitionLocked: false
    property Component contentComponent: null

    readonly property var activeContentItem:
        contentLoader.item

    readonly property int preferredWidth: 1080
    readonly property int preferredHeight: 820
    readonly property int screenMargin: root.theme.spaceMd

    readonly property int availableScreenWidth:
        root.targetScreen
            ? Math.max(
                1,
                Number(root.targetScreen.width)
                    - (root.screenMargin * 2)
            )
            : root.preferredWidth

    readonly property int availableScreenHeight:
        root.targetScreen
            ? Math.max(
                1,
                Number(root.targetScreen.height)
                    - (root.screenMargin * 2)
            )
            : root.preferredHeight

    signal closeRequested()
    signal moduleRequested(string moduleId)

    function requestInitialFocus() {
        Qt.callLater(function() {
            navigation.focusActiveItem();
        });
    }

    screen: root.targetScreen

    implicitWidth:
        Math.min(
            root.preferredWidth,
            root.availableScreenWidth
        )

    implicitHeight:
        Math.min(
            root.preferredHeight,
            root.availableScreenHeight
        )

    color: "transparent"
    focusable: true
    exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.screenMargin
        right: root.screenMargin
    }

    Shortcut {
        sequence: "Escape"

        onActivated: {
            if (!root.transitionLocked)
                root.closeRequested();
        }
    }

    onVisibleChanged: {
        if (root.visible)
            root.requestInitialFocus();
    }

    Component.onCompleted: {
        if (root.visible)
            root.requestInitialFocus();
    }

    Components.JcSurface {
        anchors.fill: parent

        theme: root.theme
        surfaceRole: "glass-raised"
        cornerRadius: root.theme.radiusXl

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.theme.spaceLg

            spacing: root.theme.spaceLg

            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.spaceMd

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: root.title
                    subtitle: root.activeModuleTitle
                }

                Components.JcIconButton {
                    theme: root.theme
                    icon: "×"
                    accessibleName: "Close Control Center"
                    controlEnabled: !root.transitionLocked

                    onClicked: root.closeRequested()
                }
            }

            Components.JcDivider {
                Layout.fillWidth: true
                theme: root.theme
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                spacing: root.theme.spaceMd

                ControlCenterNavigation {
                    id: navigation

                    Layout.preferredWidth:
                        root.theme.controlHeightLarge * 5

                    Layout.fillHeight: true

                    theme: root.theme
                    activeModuleId: root.activeModuleId
                    navigationLocked: root.transitionLocked

                    onModuleRequested: moduleId =>
                        root.moduleRequested(moduleId)
                }

                Loader {
                    id: contentLoader

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    sourceComponent: root.contentComponent
                }
            }

            Components.JcDivider {
                Layout.fillWidth: true
                theme: root.theme
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.spaceMd

                Text {
                    text: root.statusText

                    color: root.transitionLocked
                        ? root.theme.warning
                        : root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeBody
                    font.weight: root.theme.fontWeightMedium
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    Layout.maximumWidth:
                        Math.max(240, root.implicitWidth * 0.46)

                    text: root.statusDetail
                    color: root.theme.textMuted

                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.WordWrap

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                }
            }
        }
    }
}
