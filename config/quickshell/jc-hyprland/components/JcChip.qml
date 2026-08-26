import QtQuick

Rectangle {
    id: root

    required property var theme

    property string text: ""
    property bool controlEnabled: true
    property bool checked: false
    property bool compact: false
    property bool directionalNavigation: false

    signal clicked()
    signal previousFocusRequested()
    signal nextFocusRequested()
    signal firstFocusRequested()
    signal lastFocusRequested()

    activeFocusOnTab: root.controlEnabled

    Keys.onPressed: event => {
        if (!root.controlEnabled)
            return;

        if (event.key === Qt.Key_Return
                || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.clicked();
            event.accepted = true;
            return;
        }

        if (!root.directionalNavigation)
            return;

        if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.previousFocusRequested();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.nextFocusRequested();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Home) {
            root.firstFocusRequested();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_End) {
            root.lastFocusRequested();
            event.accepted = true;
        }
    }

    readonly property bool hovered:
        root.controlEnabled && pointerArea.containsMouse

    readonly property bool pressed:
        root.controlEnabled && pointerArea.pressed

    readonly property int horizontalPadding: root.compact
        ? root.theme.spaceSm
        : root.theme.spaceMd

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

        if (root.activeFocus)
            return root.theme.controlBorderFocus;

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

    radius: root.theme.radiusPill

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

        onPressed: root.forceActiveFocus()
        onClicked: root.clicked()
    }
}
