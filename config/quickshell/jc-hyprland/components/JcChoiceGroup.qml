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

    function focusRelative(startIndex, step) {
        const count = choiceRepeater.count;

        if (count <= 0)
            return;

        for (let offset = 1; offset <= count; ++offset) {
            let candidateIndex = (startIndex + (step * offset)) % count;

            if (candidateIndex < 0)
                candidateIndex += count;

            const candidate = choiceRepeater.itemAt(candidateIndex);

            if (candidate && candidate.controlEnabled) {
                candidate.forceActiveFocus();
                return;
            }
        }
    }

    function focusBoundary(last) {
        const count = choiceRepeater.count;

        if (count <= 0)
            return;

        const start = last ? count - 1 : 0;
        const step = last ? -1 : 1;

        for (let offset = 0; offset < count; ++offset) {
            const candidate = choiceRepeater.itemAt(start + (step * offset));

            if (candidate && candidate.controlEnabled) {
                candidate.forceActiveFocus();
                return;
            }
        }
    }

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
            id: choiceRepeater

            model: optionModel

            delegate: JcChip {
                required property int index
                required property var modelData

                theme: root.theme
                compact: true
                directionalNavigation: true

                text: String(modelData.label)
                checked: String(modelData.value) === root.selectedValue

                controlEnabled:
                    root.controlEnabled
                    && modelData.enabled !== false

                onClicked:
                    root.valueSelected(String(modelData.value))

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
