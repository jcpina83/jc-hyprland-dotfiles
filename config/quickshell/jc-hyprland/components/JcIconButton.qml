import QtQuick

Rectangle {
    id: root

    required property var theme

    property string icon: ""
    property string accessibleName: ""
    property bool controlEnabled: true
    property bool checked: false
    property bool compact: false

    signal clicked()

    readonly property bool hovered:
        root.controlEnabled && pointerArea.containsMouse

    readonly property bool pressed:
        root.controlEnabled && pointerArea.pressed

    readonly property int controlSize: root.compact
        ? root.theme.controlHeightCompact
        : root.theme.controlHeightDefault

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

    readonly property color resolvedIconColor: {
        if (!root.controlEnabled)
            return root.theme.controlIconDisabled;

        if (root.checked)
            return root.theme.controlIconActive;

        return root.theme.controlIconDefault;
    }

    implicitWidth: root.controlSize
    implicitHeight: root.controlSize

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
        id: iconLabel

        anchors.centerIn: parent

        text: root.icon
        color: root.resolvedIconColor

        font.family: root.theme.fontFamilySans
        font.pixelSize: root.compact
            ? root.theme.iconSizeSm
            : root.theme.iconSizeMd

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
