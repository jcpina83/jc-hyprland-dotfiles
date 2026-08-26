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
        onActivated: root.closeRequested()
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
                    subtitle: "Shell frame · Phase 2A.3.2"
                }

                Components.JcIconButton {
                    theme: root.theme
                    icon: "×"
                    accessibleName: "Close Control Center"

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
                    Layout.preferredWidth:
                        root.theme.controlHeightLarge * 5

                    Layout.fillHeight: true

                    theme: root.theme
                    activeModuleId: root.activeModuleId

                    onModuleRequested: moduleId =>
                        root.moduleRequested(moduleId)
                }

                Components.JcSurface {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    theme: root.theme
                    surfaceRole: "base"
                    cornerRadius: root.theme.radiusLg

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: root.theme.spaceXs

                        Text {
                            Layout.alignment: Qt.AlignHCenter

                            text: "Content Host"
                            color: root.theme.textPrimary

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeCardTitle
                            font.weight: root.theme.fontWeightSemibold
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter

                            text: "Displays adapter arrives in Phase 2A.3.4"
                            color: root.theme.textSecondary

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeBody
                        }
                    }
                }
            }
        }
    }
}
