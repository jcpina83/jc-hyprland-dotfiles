import QtQuick
import Quickshell

Item {
    id: root

    property var theme
    property var options: []
    property string selectedValue: ""
    property string emptyText: "No options"
    property bool controlEnabled: true

    signal valueSelected(string value)

    implicitHeight: options.length > 0
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
        spacing: root.theme ? root.theme.spacingXs : 6

        Repeater {
            model: optionModel

            delegate: JcButton {
                required property var modelData

                theme: root.theme
                compact: true

                text: String(modelData.label)
                checked: String(modelData.value) === root.selectedValue
                controlEnabled: root.controlEnabled

                onClicked: root.valueSelected(String(modelData.value))
            }
        }
    }

    Text {
        id: emptyLabel

        visible: root.options.length === 0

        width: root.width
        text: root.emptyText

        color: root.theme ? root.theme.textSecondary : "#b8b8c0"
        font.pixelSize: 12
    }
}
