import QtQuick
import QtQuick.Controls as Controls

Controls.Slider {
    id: root

    required property var theme
    property bool controlEnabled: true

    enabled: root.controlEnabled

    implicitWidth: root.theme.controlHeightLarge * 4
    implicitHeight: root.theme.controlHeightDefault

    leftPadding: root.theme.space2Xs
    rightPadding: root.theme.space2Xs
    topPadding: root.theme.space2Xs
    bottomPadding: root.theme.space2Xs

    live: true

    snapMode: root.stepSize > 0
        ? Controls.Slider.SnapAlways
        : Controls.Slider.NoSnap

    opacity: root.controlEnabled
        ? root.theme.opacityEnabled
        : root.theme.opacityDisabled

    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    Behavior on opacity {
        NumberAnimation {
            duration: root.theme.motionControl
            easing.type: root.theme.easingStandard
        }
    }

    background: Item {
        x: root.leftPadding

        y:
            root.topPadding
            + ((root.availableHeight - implicitHeight) / 2)

        width: root.availableWidth

        implicitWidth: root.theme.controlHeightLarge * 4
        implicitHeight: root.theme.borderWidthThin * 2
        height: implicitHeight

        Rectangle {
            anchors.fill: parent

            radius: root.theme.radiusPill

            color: root.theme.controlSurfaceDefault

            border.width: root.theme.borderWidthThin
            border.color: root.activeFocus
                ? root.theme.controlBorderFocus
                : root.theme.controlBorderDefault
        }

        Rectangle {
            width: parent.width * root.visualPosition
            height: parent.height

            radius: root.theme.radiusPill

            color: root.controlEnabled
                ? root.theme.controlIconActive
                : root.theme.controlIconDisabled

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.motionControl
                    easing.type: root.theme.easingStandard
                }
            }
        }
    }

    handle: Rectangle {
        x:
            root.leftPadding
            + root.visualPosition
                * (root.availableWidth - width)

        y:
            root.topPadding
            + ((root.availableHeight - height) / 2)

        implicitWidth: root.theme.iconSizeMd
        implicitHeight: root.theme.iconSizeMd

        radius: root.theme.radiusPill

        color: {
            if (!root.controlEnabled)
                return root.theme.controlIconDisabled;

            if (root.pressed)
                return root.theme.controlIconActive;

            if (root.hovered || root.activeFocus)
                return root.theme.controlTextSelected;

            return root.theme.controlIconDefault;
        }

        border.width: root.activeFocus
            ? root.theme.focusRingWidth
            : root.theme.borderWidthThin

        border.color: root.activeFocus
            ? root.theme.focusRingColor
            : root.theme.controlBorderDefault

        Behavior on color {
            ColorAnimation {
                duration: root.pressed
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
}
