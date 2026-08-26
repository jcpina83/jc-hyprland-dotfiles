import QtQuick

Item {
    id: root

    required property var theme

    property string icon: ""
    property string text: ""
    property bool selected: false
    property bool controlEnabled: true

    signal clicked()

    readonly property bool hovered:
        root.controlEnabled && pointerArea.containsMouse

    readonly property bool pressed:
        root.controlEnabled && pointerArea.pressed

    readonly property bool hasIcon:
        root.icon.length > 0

    readonly property int transitionDuration: {
        if (root.pressed)
            return root.theme.motionPress;

        if (root.hovered)
            return root.theme.motionHover;

        if (root.selected)
            return root.theme.motionSelection;

        return root.theme.motionControl;
    }

    readonly property color resolvedSurfaceColor: {
        if (!root.controlEnabled)
            return root.theme.controlSurfaceDefault;

        if (root.pressed)
            return root.theme.controlSurfacePressed;

        if (root.selected)
            return root.theme.controlSurfaceSelected;

        if (root.hovered)
            return root.theme.controlSurfaceHover;

        return root.theme.controlSurfaceDefault;
    }

    readonly property color resolvedBorderColor: {
        if (root.activeFocus)
            return root.theme.controlBorderFocus;

        if (!root.controlEnabled)
            return root.theme.controlBorderDefault;

        if (root.pressed)
            return root.theme.controlBorderPressed;

        if (root.selected)
            return root.theme.controlBorderSelected;

        if (root.hovered)
            return root.theme.controlBorderHover;

        return root.theme.controlBorderDefault;
    }

    readonly property color resolvedTextColor: {
        if (!root.controlEnabled)
            return root.theme.controlTextDisabled;

        if (root.selected)
            return root.theme.controlTextSelected;

        return root.theme.controlTextDefault;
    }

    readonly property color resolvedIconColor: {
        if (!root.controlEnabled)
            return root.theme.controlIconDisabled;

        if (root.selected)
            return root.theme.controlIconActive;

        return root.theme.controlIconDefault;
    }

    implicitWidth:
        content.implicitWidth
        + (root.theme.spaceMd * 2)

    implicitHeight: root.theme.controlHeightLarge

    activeFocusOnTab: root.controlEnabled

    Keys.onPressed: event => {
        if (!root.controlEnabled)
            return;

        if (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
        }
    }

    Rectangle {
        id: background

        anchors.fill: parent

        radius: root.theme.radiusMd

        color: root.resolvedSurfaceColor

        border.width: root.activeFocus
            ? root.theme.focusRingWidth
            : root.theme.borderWidthThin

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

        Behavior on border.color {
            ColorAnimation {
                duration: root.theme.motionControl
                easing.type: root.theme.easingStandard
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: root.theme.motionControl
                easing.type: root.theme.easingStandard
            }
        }
    }

    Rectangle {
        id: selectionIndicator

        visible: root.selected

        anchors.left: parent.left
        anchors.leftMargin: root.theme.space2Xs
        anchors.verticalCenter: parent.verticalCenter

        width: root.theme.borderWidthStrong
        height: root.theme.controlHeightCompact

        radius: root.theme.radiusPill
        color: root.theme.controlIconActive

        opacity: root.selected
            ? root.theme.opacityEnabled
            : root.theme.opacityInactive

        Behavior on opacity {
            NumberAnimation {
                duration: root.theme.motionSelection
                easing.type: root.theme.easingStandard
            }
        }
    }

    Row {
        id: content

        anchors.left: parent.left
        anchors.leftMargin: root.theme.spaceMd
        anchors.right: parent.right
        anchors.rightMargin: root.theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter

        spacing: root.theme.spaceSm

        Text {
            id: iconLabel

            visible: root.hasIcon

            anchors.verticalCenter: parent.verticalCenter

            text: root.icon
            color: root.resolvedIconColor

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.iconSizeMd
            font.weight: root.selected
                ? root.theme.fontWeightSemibold
                : root.theme.fontWeightMedium

            Behavior on color {
                ColorAnimation {
                    duration: root.transitionDuration
                    easing.type: root.theme.easingStandard
                }
            }
        }

        Text {
            id: textLabel

            anchors.verticalCenter: parent.verticalCenter

            text: root.text
            color: root.resolvedTextColor

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeBodyLarge
            font.weight: root.selected
                ? root.theme.fontWeightSemibold
                : root.theme.fontWeightMedium

            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation {
                    duration: root.transitionDuration
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

        onPressed: root.forceActiveFocus()
        onClicked: root.clicked()
    }
}
