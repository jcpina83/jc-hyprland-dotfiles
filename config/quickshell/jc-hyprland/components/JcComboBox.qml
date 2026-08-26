import QtQuick
import QtQuick.Controls as Controls

Controls.ComboBox {
    id: root

    required property var theme

    property var options: []
    property string selectedValue: ""
    property string placeholder: "Select"
    property bool controlEnabled: true

    signal valueSelected(string value)

    enabled: root.controlEnabled

    model: root.options
    textRole: "label"
    valueRole: "value"

    implicitWidth: Math.max(
        contentLabel.implicitWidth
            + root.leftPadding
            + root.rightPadding,
        root.theme.controlHeightLarge * 4
    )

    implicitHeight: root.theme.controlHeightDefault

    leftPadding: root.theme.spaceSm
    rightPadding:
        root.theme.controlHeightDefault
        + root.theme.space2Xs

    topPadding: 0
    bottomPadding: 0

    spacing: root.theme.spaceSm

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    opacity: root.controlEnabled
        ? root.theme.opacityEnabled
        : root.theme.opacityDisabled

    displayText:
        root.currentIndex >= 0
            ? root.currentText
            : root.placeholder

    function indexForSelectedValue(): int {
        for (let i = 0; i < root.options.length; ++i) {
            const option = root.options[i];

            if (option
                    && String(option.value) === root.selectedValue) {
                return i;
            }
        }

        return -1;
    }

    function syncCurrentIndex(): void {
        const targetIndex = root.indexForSelectedValue();

        if (root.currentIndex !== targetIndex)
            root.currentIndex = targetIndex;
    }

    onSelectedValueChanged: root.syncCurrentIndex()
    onOptionsChanged: root.syncCurrentIndex()

    Component.onCompleted: root.syncCurrentIndex()

    onActivated: index => {
        if (index < 0 || index >= root.options.length)
            return;

        const option = root.options[index];

        if (!option || option.enabled === false)
            return;

        root.valueSelected(String(option.value));
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.theme.motionControl
            easing.type: root.theme.easingStandard
        }
    }

    contentItem: Text {
        id: contentLabel

        leftPadding: 0
        rightPadding: 0

        text: root.displayText

        color: {
            if (!root.controlEnabled)
                return root.theme.controlTextDisabled;

            if (root.currentIndex < 0)
                return root.theme.controlTextSecondary;

            return root.theme.controlTextDefault;
        }

        font.family: root.theme.fontFamilySans
        font.pixelSize: root.theme.textSizeBody
        font.weight: root.theme.fontWeightMedium

        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight

        Behavior on color {
            ColorAnimation {
                duration: root.theme.motionControl
                easing.type: root.theme.easingStandard
            }
        }
    }

    indicator: Text {
        x:
            root.width
            - width
            - root.theme.spaceSm

        y: (root.height - height) / 2

        text: "⌄"

        color: root.controlEnabled
            ? root.theme.controlIconDefault
            : root.theme.controlIconDisabled

        font.family: root.theme.fontFamilySans
        font.pixelSize: root.theme.iconSizeMd
        font.weight: root.theme.fontWeightSemibold

        rotation: root.popup.visible ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: root.theme.motionControl
                easing.type: root.theme.easingStandard
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: root.theme.motionControl
                easing.type: root.theme.easingStandard
            }
        }
    }

    background: Rectangle {
        radius: root.theme.radiusSm

        color: {
            if (!root.controlEnabled)
                return root.theme.controlSurfaceDefault;

            if (root.down)
                return root.theme.controlSurfacePressed;

            if (root.hovered)
                return root.theme.controlSurfaceHover;

            return root.theme.controlSurfaceDefault;
        }

        border.width: root.activeFocus
            ? root.theme.focusRingWidth
            : root.theme.borderWidthThin

        border.color: {
            if (root.activeFocus)
                return root.theme.focusRingColor;

            if (root.down)
                return root.theme.controlBorderPressed;

            if (root.hovered)
                return root.theme.controlBorderHover;

            return root.theme.controlBorderDefault;
        }

        Behavior on color {
            ColorAnimation {
                duration: root.down
                    ? root.theme.motionPress
                    : root.theme.motionHover

                easing.type: root.theme.easingStandard
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: root.theme.motionControl
                easing.type: root.theme.easingStandard
            }
        }
    }

    delegate: Controls.ItemDelegate {
        id: optionDelegate

        required property int index

        readonly property var option:
            index >= 0 && index < root.options.length
                ? root.options[index]
                : null

        readonly property bool selected:
            option
            && String(option.value) === root.selectedValue

        width: root.width

        enabled:
            root.controlEnabled
            && option
            && option.enabled !== false

        hoverEnabled: true

        highlighted: root.highlightedIndex === index

        contentItem: Text {
            text: optionDelegate.option
                ? String(optionDelegate.option.label)
                : ""

            color: {
                if (!optionDelegate.enabled)
                    return root.theme.controlTextDisabled;

                if (optionDelegate.selected)
                    return root.theme.controlTextSelected;

                return root.theme.controlTextDefault;
            }

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeBody
            font.weight: optionDelegate.selected
                ? root.theme.fontWeightSemibold
                : root.theme.fontWeightRegular

            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: root.theme.radiusSm

            color: {
                if (!optionDelegate.enabled)
                    return root.theme.controlSurfaceDefault;

                if (optionDelegate.pressed)
                    return root.theme.controlSurfacePressed;

                if (optionDelegate.selected)
                    return root.theme.controlSurfaceSelected;

                if (optionDelegate.highlighted
                        || optionDelegate.hovered) {
                    return root.theme.controlSurfaceHover;
                }

                return root.theme.surfaceOverlay;
            }
        }
    }

    popup: Controls.Popup {
        y: root.height + root.theme.space2Xs

        width: root.width

        implicitHeight: Math.min(
            contentList.implicitHeight
                + topPadding
                + bottomPadding,
            (root.theme.controlHeightDefault * 6)
                + topPadding
                + bottomPadding
        )

        topPadding: root.theme.space2Xs
        bottomPadding: root.theme.space2Xs
        leftPadding: root.theme.space2Xs
        rightPadding: root.theme.space2Xs

        contentItem: ListView {
            id: contentList

            implicitHeight: contentHeight

            clip: true

            model: root.popup.visible
                ? root.delegateModel
                : null

            currentIndex: root.highlightedIndex

            boundsBehavior: Flickable.StopAtBounds
        }

        background: Rectangle {
            radius: root.theme.radiusMd

            color: root.theme.surfaceOverlay

            border.width: root.theme.borderWidthThin
            border.color: root.theme.borderDefault
        }
    }
}
