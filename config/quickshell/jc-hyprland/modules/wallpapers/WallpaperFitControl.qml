import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property string targetId: "main"
    property string outputName: ""
    property string selectedFit: "cover"
    property bool targetSelected: false
    property bool draftDirty: false
    property bool controlEnabled: true

    signal fitSelected(string fitMode)

    readonly property var fitOptions: [
        { label: "Fit", value: "contain", enabled: true },
        { label: "Fill", value: "cover", enabled: true },
        { label: "Stretch", value: "stretch", enabled: true },
        { label: "Center", value: "center", enabled: true }
    ]

    implicitHeight: root.theme.controlHeightLarge * 1.45
    opacity: root.controlEnabled ? 1 : root.theme.opacityDisabled

    Components.JcSurface {
        anchors.fill: parent

        theme: root.theme
        surfaceRole: "glass"
        selected: root.targetSelected

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.theme.spaceSm
            spacing: root.theme.spaceXs

            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.spaceSm

                Text {
                    Layout.fillWidth: true

                    text:
                        "Presentation · "
                        + String(root.targetId).toUpperCase()
                        + (
                            root.outputName.length > 0
                                ? " · " + root.outputName
                                : ""
                        )

                    color: root.targetSelected
                        ? root.theme.accent
                        : root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightSemibold

                    elide: Text.ElideRight
                }

                Components.JcChip {
                    visible: root.draftDirty

                    theme: root.theme
                    text: "Fit draft"
                    compact: true
                    checked: true
                    controlEnabled: false
                }
            }

            Components.JcChoiceGroup {
                Layout.fillWidth: true

                theme: root.theme
                options: root.fitOptions
                selectedValue: root.selectedFit
                controlEnabled: root.controlEnabled

                onValueSelected: value => root.fitSelected(value)
            }
        }
    }
}
