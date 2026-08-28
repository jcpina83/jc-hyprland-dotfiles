import QtQuick

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
        { label: "Fit", value: "contain", iconName: "fit", enabled: true },
        { label: "Fill", value: "cover", iconName: "fill", enabled: true },
        { label: "Stretch", value: "stretch", iconName: "stretch", enabled: true },
        { label: "Center", value: "center", iconName: "center", enabled: true }
    ]

    implicitHeight: fitChoices.implicitHeight
    opacity: root.controlEnabled ? 1 : root.theme.opacityDisabled

    Components.JcChoiceGroup {
        id: fitChoices
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: root.theme
        options: root.fitOptions
        selectedValue: root.selectedFit
        controlEnabled: root.controlEnabled
        centerContent: true
        onValueSelected: value => root.fitSelected(value)
    }

    Text {
        visible: root.draftDirty
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "DRAFT"
        color: root.theme.accent
        font.family: root.theme.fontFamilySans
        font.pixelSize: root.theme.textSizeCaption
        font.weight: root.theme.fontWeightSemibold
        font.letterSpacing: 0.8
    }
}
