import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property string activeModuleId: "displays"

    signal moduleRequested(string moduleId)

    readonly property var navigationItems: [
        {
            id: "displays",
            label: "Displays",
            icon: "▣",
            enabled: true
        },
        {
            id: "wallpapers",
            label: "Wallpapers",
            icon: "▧",
            enabled: false
        },
        {
            id: "themes",
            label: "Themes",
            icon: "◐",
            enabled: false
        },
        {
            id: "quick-settings",
            label: "Quick Settings",
            icon: "⚙",
            enabled: false
        },
        {
            id: "performance",
            label: "Performance",
            icon: "◇",
            enabled: false
        },
        {
            id: "media",
            label: "Media",
            icon: "♪",
            enabled: false
        },
        {
            id: "network",
            label: "Network",
            icon: "⌁",
            enabled: false
        },
        {
            id: "notifications",
            label: "Notifications",
            icon: "●",
            enabled: false
        }
    ]

    implicitWidth: root.theme.controlHeightLarge * 5
    implicitHeight: navigationSurface.implicitHeight

    Components.JcSurface {
        id: navigationSurface

        anchors.fill: parent

        theme: root.theme
        surfaceRole: "base"
        cornerRadius: root.theme.radiusLg

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.theme.spaceMd

            spacing: root.theme.spaceSm

            Components.JcSectionHeader {
                Layout.fillWidth: true

                theme: root.theme
                title: "Modules"
                subtitle: "Control Center"
            }

            Components.JcDivider {
                Layout.fillWidth: true
                theme: root.theme
            }

            ColumnLayout {
                Layout.fillWidth: true

                spacing: root.theme.spaceXs

                Repeater {
                    model: root.navigationItems

                    delegate: Components.JcNavItem {
                        required property var modelData

                        Layout.fillWidth: true

                        theme: root.theme

                        icon: String(modelData.icon)
                        text: String(modelData.label)

                        selected:
                            root.activeModuleId === String(modelData.id)

                        controlEnabled:
                            Boolean(modelData.enabled)

                        onClicked:
                            root.moduleRequested(
                                String(modelData.id)
                            )
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            Text {
                Layout.fillWidth: true

                text: "More modules arrive in Phase 2B–2H"
                color: root.theme.textMuted

                wrapMode: Text.WordWrap

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeCaption
            }
        }
    }
}
