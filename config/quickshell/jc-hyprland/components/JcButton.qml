import QtQuick

Rectangle {
    id: root

    // Public API preserved from the Phase 1 component.
    required property var theme
    property string text: ""
    property bool controlEnabled: true
    property bool checked: false
    property bool compact: false

    signal clicked()

    readonly property bool hovered:
        root.controlEnabled && pointerArea.containsMouse

    readonly property bool pressed:
        root.controlEnabled && pointerArea.pressed

    readonly property int horizontalPadding:
        root.compact
            ? root.theme.spaceSm
            : root.theme.spaceSm + root.theme.space2Xs

    readonly property int transitionDuration: {
        if (root.pressed)
            return root.theme.motionPress;

        if (root.hovered)
            return root.theme.motionHover;

        if (root.checked)
            return root.theme.motionSelection;

        return root.theme.motionControl;
    }

    readonly property color resolvedSurfaceColor: {
        if (!root.controlEnabled)
            return root.theme.controlSurfaceDefault;

        if (root.pressed)
            return root.theme.controlSurfacePressed;

        if (root.checked)
            return root.theme.controlSurfaceSelected;

        if (root.hovered)
            return root.theme.controlSurfaceHover;

        return root.theme.controlSurfaceDefault;
    }

    readonly property color resolvedBorderColor: {
        if (!root.controlEnabled)
            return root.theme.controlBorderDefault;

        if (root.pressed)
            return root.theme.controlBorderPressed;

        if (root.checked)
            return root.theme.controlBorderSelected;

        if (root.hovered)
            return root.theme.controlBorderHover;

        return root.theme.controlBorderDefault;
    }

    readonly property color resolvedTextColor: {
        if (!root.controlEnabled)
            return root.theme.controlTextDisabled;

        if (root.checked)
            return root.theme.controlTextSelected;

        return root.theme.controlTextDefault;
    }

    implicitWidth:
        label.implicitWidth
        + (root.horizontalPadding * 2)

    implicitHeight: root.compact
        ? root.theme.controlHeightCompact
        : root.theme.controlHeightDefault

    radius: root.theme.radiusSm

    color: root.resolvedSurfaceColor

    border.width: root.theme.borderWidthThin
    border.color: root.resolvedBorderColor

    opacity: root.controlEnabled
        ? root.theme.opacityEnabled
        : root.theme.opacityDisabled

    Behavior on color {
        ColorAnimation {
            duration: root.transitionDuration
            easing.type: root.theme.easingStandard
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: root.theme.motionControl
            easing.type: root.theme.easingStandard
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text

        color: root.resolvedTextColor

        font.family: root.theme.fontFamilySans
        font.pixelSize: root.compact
            ? root.theme.textSizeBody
            : root.theme.textSizeBodyLarge

        font.weight: root.checked
            ? root.theme.fontWeightSemibold
            : root.theme.fontWeightMedium

        Behavior on color {
            ColorAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent

        enabled: root.controlEnabled
        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        onClicked: root.clicked()
    }
}
