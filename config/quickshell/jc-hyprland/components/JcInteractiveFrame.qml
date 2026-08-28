import QtQuick

Item {
    id: root

    required property var theme

    property bool controlEnabled: true
    property bool hovered: false
    property bool pressed: false
    property bool selected: false
    property bool focused: false
    property bool compact: false

    readonly property int cornerRadius: root.compact
        ? root.theme.controlCornerRadiusCompact
        : root.theme.controlCornerRadiusDefault

    readonly property int accentLength: root.compact
        ? root.theme.controlAccentLengthCompact
        : root.theme.controlAccentLengthDefault

    readonly property int transitionDuration: {
        if (root.pressed)
            return root.theme.motionPress;
        if (root.hovered)
            return root.theme.motionHover;
        if (root.selected || root.focused)
            return root.theme.motionSelection;
        return root.theme.motionControl;
    }

    readonly property color resolvedSurfaceColor: {
        if (root.pressed)
            return root.theme.controlSurfacePressed;
        if (root.selected)
            return root.theme.controlSurfaceSelected;
        if (root.hovered)
            return root.theme.controlSurfaceHover;
        return root.theme.controlSurfaceDefault;
    }

    readonly property color resolvedBorderColor: {
        if (root.focused)
            return root.theme.controlBorderFocus;
        if (root.pressed)
            return root.theme.controlBorderPressed;
        if (root.selected)
            return root.theme.controlBorderSelected;
        if (root.hovered)
            return root.theme.controlBorderHover;
        return root.theme.controlBorderDefault;
    }

    readonly property real energyOpacity: {
        if (!root.controlEnabled)
            return 0.16;
        if (root.focused || root.selected)
            return 1.0;
        if (root.pressed)
            return 0.88;
        if (root.hovered)
            return 0.68;
        return 0.28;
    }

    opacity: root.controlEnabled
        ? root.theme.opacityEnabled
        : root.theme.opacityDisabled

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: root.cornerRadius + 1
        color: "transparent"
        border.width: root.selected || root.focused ? 2 : 1
        border.color: root.selected || root.focused
            ? root.theme.hudGlowMedium
            : root.theme.hudGlowSoft
        opacity: root.selected || root.focused
            ? 0.78
            : root.hovered ? 0.52 : 0.22

        Behavior on opacity {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.resolvedSurfaceColor
        border.width: root.focused
            ? root.theme.focusRingWidth
            : root.theme.borderWidthThin
        border.color: root.resolvedBorderColor

        Behavior on color {
            ColorAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.leftMargin: root.theme.controlAccentInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.theme.controlAccentThickness
        height: Math.min(
            parent.height - (root.theme.spaceXs * 2),
            Math.max(root.theme.spaceSm, parent.height * 0.44)
        )
        radius: 1
        color: root.theme.accent
        opacity: root.energyOpacity

        Behavior on opacity {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.theme.spaceSm
        width: root.selected || root.focused
            ? root.accentLength * 1.35
            : root.accentLength
        height: 1
        color: root.theme.hudFrame
        opacity: root.energyOpacity * 0.82

        Behavior on width {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spaceSm
        anchors.bottom: parent.bottom
        width: root.selected
            ? root.accentLength
            : Math.max(5, root.accentLength * 0.55)
        height: 1
        color: root.theme.hudSecondaryAccent
        opacity: root.selected
            ? 0.88
            : root.hovered ? 0.46 : 0.18

        Behavior on width {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.transitionDuration
                easing.type: root.theme.easingStandard
            }
        }
    }
}
