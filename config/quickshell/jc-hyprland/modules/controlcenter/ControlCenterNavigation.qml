import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property string activeModuleId: "displays"
    property bool navigationLocked: false

    signal moduleRequested(string moduleId)

    function focusActiveItem() {
        let fallbackItem = null;

        for (let i = 0; i < root.navigationItems.length; ++i) {
            const entry = root.navigationItems[i];

            if (!entry || !Boolean(entry.enabled))
                continue;

            const item = navigationRepeater.itemAt(i);

            if (!item)
                continue;

            if (!fallbackItem)
                fallbackItem = item;

            if (String(entry.id) === root.activeModuleId) {
                item.forceActiveFocus();
                return true;
            }
        }

        if (fallbackItem) {
            fallbackItem.forceActiveFocus();
            return true;
        }

        return false;
    }

    function focusRelative(startIndex, step) {
        const count = root.navigationItems.length;

        if (count <= 0 || step === 0)
            return false;

        for (let offset = 1; offset <= count; ++offset) {
            const candidateIndex =
                (startIndex + (step * offset) + count * 2) % count;

            const candidateItem =
                navigationRepeater.itemAt(candidateIndex);

            if (!candidateItem || !candidateItem.controlEnabled)
                continue;

            candidateItem.forceActiveFocus();
            return true;
        }

        return false;
    }

    function focusBoundary(last) {
        const count = root.navigationItems.length;

        if (count <= 0)
            return false;

        const start = last ? count - 1 : 0;
        const end = last ? -1 : count;
        const step = last ? -1 : 1;

        for (let i = start; i !== end; i += step) {
            const candidateItem = navigationRepeater.itemAt(i);

            if (!candidateItem || !candidateItem.controlEnabled)
                continue;

            candidateItem.forceActiveFocus();
            return true;
        }

        return false;
    }

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
                    id: navigationRepeater

                    model: root.navigationItems

                    delegate: Components.JcNavItem {
                        required property int index
                        required property var modelData

                        Layout.fillWidth: true

                        theme: root.theme

                        icon: String(modelData.icon)
                        text: String(modelData.label)

                        selected:
                            root.activeModuleId === String(modelData.id)

                        controlEnabled:
                            Boolean(modelData.enabled)
                            && (!root.navigationLocked
                                || root.activeModuleId
                                    === String(modelData.id))

                        onClicked:
                            root.moduleRequested(
                                String(modelData.id)
                            )

                        onPreviousFocusRequested:
                            root.focusRelative(index, -1)

                        onNextFocusRequested:
                            root.focusRelative(index, 1)

                        onFirstFocusRequested:
                            root.focusBoundary(false)

                        onLastFocusRequested:
                            root.focusBoundary(true)
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
