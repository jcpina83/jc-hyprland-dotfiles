import QtQuick

Item {
    id: root

    required property var theme
    property string icon: ""
    property string iconName: ""
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

    readonly property color resolvedIconColor: {
        if (!root.controlEnabled)
            return root.theme.controlIconDisabled;
        if (root.checked || root.activeFocus)
            return root.theme.controlIconActive;
        if (root.hovered)
            return root.theme.textPrimary;
        return root.theme.controlIconDefault;
    }

    implicitWidth: root.controlSize
    implicitHeight: root.controlSize
    activeFocusOnTab: root.controlEnabled
    scale: root.pressed ? 0.96 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: root.theme.motionPress
            easing.type: root.theme.easingStandard
        }
    }

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

    JcInteractiveFrame {
        anchors.fill: parent
        theme: root.theme
        controlEnabled: root.controlEnabled
        hovered: root.hovered
        pressed: root.pressed
        selected: root.checked
        focused: root.activeFocus
        compact: root.compact
    }

    JcIcon {
        anchors.centerIn: parent
        theme: root.theme
        name: root.iconName
        glyph: root.icon
        iconColor: root.resolvedIconColor
        iconSize: root.compact
            ? root.theme.iconSizeSm
            : root.theme.iconSizeMd
        emphasized: root.checked || root.activeFocus
    }

    MouseArea {
        id: pointerArea
        anchors.fill: parent
        enabled: root.controlEnabled
        hoverEnabled: true
        cursorShape: root.controlEnabled
            ? Qt.PointingHandCursor
            : Qt.ArrowCursor
        onPressed: root.forceActiveFocus()
        onClicked: root.clicked()
    }
}
