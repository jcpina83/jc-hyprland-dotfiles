import QtQuick

Item {
    id: root

    required property var theme

    property string text: ""
    property bool controlEnabled: true
    property bool checked: false

    signal toggled(bool value)

    readonly property bool hovered:
        root.controlEnabled && pointerArea.containsMouse

    readonly property bool pressed:
        root.controlEnabled && pointerArea.pressed

    readonly property int trackHeight: root.theme.controlHeightCompact
        - (root.theme.space2Xs * 2)

    readonly property int trackWidth:
        root.theme.controlHeightDefault + root.theme.spaceSm

    readonly property int knobSize:
        root.trackHeight - (root.theme.borderWidthStrong * 2)

    readonly property int knobInset: root.theme.borderWidthStrong

    readonly property color resolvedTrackColor: {
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

    readonly property color resolvedTrackBorderColor: {
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

    readonly property color resolvedKnobColor: {
        if (!root.controlEnabled)
            return root.theme.controlIconDisabled;

        if (root.checked)
            return root.theme.controlIconActive;

        return root.theme.controlIconDefault;
    }

    implicitWidth: content.implicitWidth
    implicitHeight: Math.max(
        root.theme.controlHeightDefault,
        content.implicitHeight
    )

    opacity: root.controlEnabled
        ? root.theme.opacityEnabled
        : root.theme.opacityDisabled

    Behavior on opacity {
        NumberAnimation {
            duration: root.theme.motionControl
            easing.type: root.theme.easingStandard
        }
    }

    Row {
        id: content

        anchors.verticalCenter: parent.verticalCenter

        spacing: root.theme.spaceSm

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter

            width: root.trackWidth
            height: root.trackHeight

            radius: root.theme.radiusPill
            color: root.resolvedTrackColor

            border.width: root.theme.borderWidthThin
            border.color: root.resolvedTrackBorderColor

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.motionControl
                    easing.type: root.theme.easingStandard
                }
            }

            Rectangle {
                id: knob

                width: root.knobSize
                height: root.knobSize

                y: root.knobInset
                x: root.checked
                    ? track.width - width - root.knobInset
                    : root.knobInset

                radius: root.theme.radiusPill
                color: root.resolvedKnobColor

                Behavior on x {
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
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.text.length > 0

            text: root.text
            color: root.controlEnabled
                ? root.theme.controlTextDefault
                : root.theme.controlTextDisabled

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeBody
            font.weight: root.theme.fontWeightMedium

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.motionControl
                    easing.type: root.theme.easingStandard
                }
            }
        }
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent

        enabled: root.controlEnabled
        hoverEnabled: true

        cursorShape: Qt.PointingHandCursor

        onClicked: root.toggled(!root.checked)
    }
}
