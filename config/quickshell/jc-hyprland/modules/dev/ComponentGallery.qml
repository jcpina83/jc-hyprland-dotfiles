import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell

import qs.components as Components

PanelWindow {
    id: root

    required property var targetScreen
    required property var theme

    signal closeRequested()

    property bool demoToggleValue: true
    property string demoChoiceValue: "balanced"
    property string demoComboValue: "balanced"

    screen: targetScreen

    implicitWidth: 1080
    implicitHeight: 820

    color: "transparent"
    focusable: true
    exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.theme.spaceMd
        right: root.theme.spaceMd
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

        Controls.ScrollView {
            id: galleryScroll

            anchors.fill: parent
            anchors.margins: root.theme.spaceLg

            clip: true

            Controls.ScrollBar.horizontal.policy:
                Controls.ScrollBar.AlwaysOff

            ColumnLayout {
                width: galleryScroll.availableWidth
                spacing: root.theme.spaceLg

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceMd

                    Components.JcSectionHeader {
                        Layout.fillWidth: true

                        theme: root.theme
                        title: "Component Gallery"
                        subtitle:
                            "Design-system visual harness · "
                            + root.theme.activeThemeName
                    }

                    Components.JcButton {
                        theme: root.theme
                        text: "Close"

                        onClicked: root.closeRequested()
                    }
                }

                Components.JcDivider {
                    Layout.fillWidth: true
                    theme: root.theme
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Surfaces"
                    subtitle:
                        "Semantic depth and container hierarchy"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceMd

                    Repeater {
                        model: [
                            {
                                label: "Base",
                                role: "base"
                            },
                            {
                                label: "Raised",
                                role: "raised"
                            },
                            {
                                label: "Glass",
                                role: "glass"
                            },
                            {
                                label: "Overlay",
                                role: "overlay"
                            }
                        ]

                        delegate: Components.JcSurface {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight:
                                root.theme.controlHeightLarge * 2

                            theme: root.theme
                            surfaceRole: String(modelData.role)
                            cornerRadius: root.theme.radiusLg

                            Text {
                                anchors.centerIn: parent

                                text: String(modelData.label)
                                color: root.theme.textPrimary

                                font.family:
                                    root.theme.fontFamilySans

                                font.pixelSize:
                                    root.theme.textSizeBody

                                font.weight:
                                    root.theme.fontWeightMedium
                            }
                        }
                    }
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "HUD frames"
                    subtitle:
                        "Technical glass framing · cyan energy + amber detail"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceMd

                    Components.JcHudFrame {
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            root.theme.controlHeightLarge * 2.2

                        theme: root.theme
                        surfaceRole: "glass"

                        Text {
                            anchors.centerIn: parent
                            text: "Glass HUD"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeBody
                            font.weight: root.theme.fontWeightMedium
                        }
                    }

                    Components.JcHudFrame {
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            root.theme.controlHeightLarge * 2.2

                        theme: root.theme
                        surfaceRole: "glass-raised"
                        selected: true

                        Text {
                            anchors.centerIn: parent
                            text: "Selected HUD"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeBody
                            font.weight: root.theme.fontWeightMedium
                        }
                    }

                    Components.JcHudFrame {
                        Layout.fillWidth: true
                        Layout.preferredHeight:
                            root.theme.controlHeightLarge * 2.2

                        theme: root.theme
                        surfaceRole: "glass"
                        focused: true
                        showSecondaryAccent: false

                        Text {
                            anchors.centerIn: parent
                            text: "Focused HUD"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeBody
                            font.weight: root.theme.fontWeightMedium
                        }
                    }
                }

                Components.JcDivider {
                    Layout.fillWidth: true
                    theme: root.theme
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Actions"
                    subtitle:
                        "Default, selected and disabled controls"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceSm

                    Components.JcButton {
                        theme: root.theme
                        text: "Default"
                    }

                    Components.JcButton {
                        theme: root.theme
                        text: "Selected"
                        checked: true
                    }

                    Components.JcButton {
                        theme: root.theme
                        text: "Disabled"
                        controlEnabled: false
                    }

                    Components.JcIconButton {
                        theme: root.theme
                        icon: "★"
                        accessibleName: "Favorite"
                    }

                    Components.JcIconButton {
                        theme: root.theme
                        icon: "✓"
                        accessibleName: "Selected"
                        checked: true
                    }
                }

                Components.JcDivider {
                    Layout.fillWidth: true
                    theme: root.theme
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Selection"
                    subtitle:
                        "Chips, toggle and discrete choice group"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceSm

                    Components.JcChip {
                        theme: root.theme
                        text: "Default"
                    }

                    Components.JcChip {
                        theme: root.theme
                        text: "Selected"
                        checked: true
                    }

                    Components.JcChip {
                        theme: root.theme
                        text: "Disabled"
                        controlEnabled: false
                    }

                    Components.JcToggle {
                        theme: root.theme
                        text: "Enabled"
                        checked: root.demoToggleValue

                        onToggled: value =>
                            root.demoToggleValue = value
                    }
                }

                Components.JcChoiceGroup {
                    Layout.fillWidth: true

                    theme: root.theme

                    options: [
                        {
                            label: "Quiet",
                            value: "quiet"
                        },
                        {
                            label: "Balanced",
                            value: "balanced"
                        },
                        {
                            label: "Performance",
                            value: "performance"
                        }
                    ]

                    selectedValue: root.demoChoiceValue

                    onValueSelected: value =>
                        root.demoChoiceValue = value
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Inputs"
                    subtitle:
                        "Continuous and compact-list input controls"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceLg

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.theme.spaceXs

                        Text {
                            text: "Slider · "
                                + Math.round(demoSlider.value)
                                + "%"

                            color: root.theme.textSecondary

                            font.family:
                                root.theme.fontFamilySans

                            font.pixelSize:
                                root.theme.textSizeCaption
                        }

                        Components.JcSlider {
                            id: demoSlider

                            Layout.fillWidth: true

                            theme: root.theme

                            from: 0
                            to: 100
                            value: 64
                            stepSize: 1
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.theme.spaceXs

                        Text {
                            text: "ComboBox"

                            color: root.theme.textSecondary

                            font.family:
                                root.theme.fontFamilySans

                            font.pixelSize:
                                root.theme.textSizeCaption
                        }

                        Components.JcComboBox {
                            Layout.fillWidth: true

                            theme: root.theme

                            options: [
                                {
                                    label: "Quiet",
                                    value: "quiet"
                                },
                                {
                                    label: "Balanced",
                                    value: "balanced"
                                },
                                {
                                    label: "Performance",
                                    value: "performance"
                                }
                            ]

                            selectedValue: root.demoComboValue

                            onValueSelected: value =>
                                root.demoComboValue = value
                        }
                    }
                }

                Components.JcDivider {
                    Layout.fillWidth: true
                    theme: root.theme
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Navigation"
                    subtitle:
                        "Future Control Center sidebar states"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceSm

                    Components.JcNavItem {
                        Layout.preferredWidth:
                            root.theme.controlHeightLarge * 4

                        theme: root.theme
                        icon: "◫"
                        text: "Displays"
                        selected: true
                    }

                    Components.JcNavItem {
                        Layout.preferredWidth:
                            root.theme.controlHeightLarge * 4

                        theme: root.theme
                        icon: "◈"
                        text: "Themes"
                    }

                    Components.JcNavItem {
                        Layout.preferredWidth:
                            root.theme.controlHeightLarge * 4

                        theme: root.theme
                        icon: "⚙"
                        text: "Disabled"
                        controlEnabled: false
                    }
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Feedback"
                    subtitle:
                        "Tooltip and modal overlay behavior"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceSm

                    Components.JcButton {
                        id: tooltipDemoButton

                        theme: root.theme
                        text: "Hover for tooltip"

                        Components.JcTooltip {
                            theme: root.theme

                            text:
                                "Contextual help from JcTooltip"

                            visible:
                                tooltipDemoButton.hovered
                        }
                    }

                    Components.JcButton {
                        theme: root.theme
                        text: "Open popup"

                        onClicked: demoPopup.open()
                    }
                }

                Components.JcDivider {
                    Layout.fillWidth: true
                    theme: root.theme
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Metrics"
                    subtitle:
                        "Semantic data visualization states"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceLg

                    Components.JcMetricRing {
                        theme: root.theme

                        value: 42
                        label: "CPU"
                        status: "normal"
                    }

                    Components.JcMetricRing {
                        theme: root.theme

                        value: 67
                        label: "GPU"
                        status: "info"
                    }

                    Components.JcMetricRing {
                        theme: root.theme

                        value: 78
                        label: "TEMP"
                        status: "warning"
                    }

                    Components.JcMetricRing {
                        theme: root.theme

                        value: 91
                        label: "LOAD"
                        status: "critical"
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Components.JcDivider {
                    Layout.fillWidth: true
                    theme: root.theme
                }

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Canonical surface"
                    subtitle:
                        "Phase 2 surface primitive after compatibility retirement"
                }

                Components.JcSurface {
                    Layout.fillWidth: true
                    Layout.preferredHeight:
                        root.theme.controlHeightLarge * 2

                    theme: root.theme

                    surfaceRole: "raised"

                    Text {
                        anchors.centerIn: parent

                        text:
                            "JcSurface · raised"

                        color: root.theme.textSecondary

                        font.family:
                            root.theme.fontFamilySans

                        font.pixelSize:
                            root.theme.textSizeBody
                    }
                }
            }
        }
    }

    Components.JcPopup {
        id: demoPopup

        theme: root.theme

        modal: true
        showScrim: true
        dismissOnOutside: true

        width: root.theme.controlHeightLarge * 9

        x: (root.width - width) / 2
        y: (root.height - implicitHeight) / 2

        contentItem: ColumnLayout {
            spacing: root.theme.spaceMd

            Components.JcSectionHeader {
                Layout.fillWidth: true

                theme: root.theme
                title: "JcPopup"
                subtitle:
                    "Modal overlay · click outside or press Escape"
            }

            Text {
                Layout.fillWidth: true

                text:
                    "This popup is intentionally independent "
                    + "from the Displays window."

                color: root.theme.textSecondary

                font.family:
                    root.theme.fontFamilySans

                font.pixelSize:
                    root.theme.textSizeBody

                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                Components.JcButton {
                    theme: root.theme
                    text: "Close"

                    onClicked: demoPopup.close()
                }
            }
        }
    }
}
