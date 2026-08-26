import QtQuick
import Quickshell

Item {
    id: root

    required property var theme
    property var options: []
    property string selectedValue: ""
    property string emptyText: "No options"
    property bool controlEnabled: true

    signal valueSelected(string value)

    implicitHeight: root.options.length > 0
        ? choiceFlow.implicitHeight
        : emptyLabel.implicitHeight

    ScriptModel {
        id: optionModel

        values: root.options
        objectProp: "value"
    }

    Flow {
        id: choiceFlow

        visible: root.options.length > 0

        width: root.width
        spacing: root.theme.spaceXs

        Repeater {
            model: optionModel

            delegate: JcChip {
                required property var modelData

                theme: root.theme
                compact: true

                text: String(modelData.label)
                checked: String(modelData.value) === root.selectedValue

                controlEnabled:
                    root.controlEnabled
                    && modelData.enabled !== false

                onClicked:
                    root.valueSelected(String(modelData.value))
            }
        }
    }

    Text {
        id: emptyLabel

        visible: root.options.length === 0

        width: root.width
        text: root.emptyText

        color: root.theme.textSecondary

        font.family: root.theme.fontFamilySans
        font.pixelSize: root.theme.textSizeBody
        font.weight: root.theme.fontWeightRegular
    }
}
