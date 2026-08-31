import QtQuick

Item {
    id: root

    required property var theme

    property string text: ""
    property string iconName: ""
    property string icon: ""

    property bool selected: false
    property bool controlEnabled: true
    property bool compact: false

    signal clicked()

    readonly property bool hovered:
        root.controlEnabled && pointerArea.containsMouse

    readonly property bool pressed:
        root.controlEnabled && pointerArea.pressed

    readonly property int tileHeight:
        root.compact
            ? Math.round(root.theme.controlHeightLarge * 0.98)
            : Math.round(root.theme.controlHeightLarge * 1.34)

    readonly property color resolvedIconColor: {
        if (!root.controlEnabled)
            return root.theme.controlIconDisabled;

        if (root.selected || root.activeFocus)
            return root.theme.controlIconActive;

        if (root.hovered)
            return root.theme.textPrimary;

        return root.theme.controlIconDefault;
    }

    readonly property color resolvedTextColor: {
        if (!root.controlEnabled)
            return root.theme.controlTextDisabled;

        if (root.selected)
            return root.theme.controlTextSelected;

        if (root.activeFocus || root.hovered)
            return root.theme.textPrimary;

        return root.theme.controlTextDefault;
    }

    implicitWidth:
        root.compact
            ? root.theme.controlHeightLarge * 1.12
            : root.theme.controlHeightLarge * 1.40

    implicitHeight: root.tileHeight

    activeFocusOnTab: root.controlEnabled
    opacity:
        root.controlEnabled
            ? root.theme.opacityEnabled
            : root.theme.opacityDisabled

    scale: root.pressed ? 0.98 : 1.0

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
        selected: root.selected
        focused: root.activeFocus

        compact: root.compact
    }

    Column {
        anchors.centerIn: parent

        spacing: root.theme.space2Xs

        JcIcon {
            anchors.horizontalCenter: parent.horizontalCenter

            theme: root.theme
            name: root.iconName
            glyph: root.icon

            iconColor: root.resolvedIconColor
            iconSize:
                root.compact
                    ? root.theme.iconSizeMd
                    : root.theme.iconSizeLg

            emphasized: root.selected || root.activeFocus
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text: root.text
            color: root.resolvedTextColor

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeCaption
            font.weight:
                root.selected
                    ? root.theme.fontWeightSemibold
                    : root.theme.fontWeightMedium
        }
    }

    MouseArea {
        id: pointerArea

        anchors.fill: parent

        enabled: root.controlEnabled
        hoverEnabled: true

        cursorShape:
            root.controlEnabled
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor

        onPressed: root.forceActiveFocus()
        onClicked: root.clicked()
    }
}
