import QtQuick

Item {
    id: root

    required property var theme
    property string text: ""
    property string iconName: ""
    property string icon: ""
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
    readonly property bool hasIcon:
        root.iconName.length > 0 || root.icon.length > 0
    readonly property int horizontalPadding: root.compact
        ? root.theme.spaceSm + root.theme.space2Xs
        : root.theme.spaceMd

    readonly property color resolvedContentColor: {
        if (!root.controlEnabled && !root.checked)
            return root.theme.controlTextDisabled;
        if (root.checked || root.activeFocus)
            return root.theme.controlTextSelected;
        if (root.hovered)
            return root.theme.textPrimary;
        return root.theme.controlTextDefault;
    }

    implicitWidth: content.implicitWidth + (root.horizontalPadding * 2)
    implicitHeight: root.compact
        ? root.theme.controlHeightCompact
        : root.theme.controlHeightDefault

    scale: root.pressed ? 0.98 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: root.theme.motionPress
            easing.type: root.theme.easingStandard
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

    Row {
        id: content
        anchors.centerIn: parent
        spacing: root.hasIcon ? root.theme.controlContentGap : 0

        JcIcon {
            visible: root.hasIcon
            anchors.verticalCenter: parent.verticalCenter
            theme: root.theme
            name: root.iconName
            glyph: root.icon
            iconColor: root.resolvedContentColor
            iconSize: root.compact
                ? root.theme.iconSizeCompactControl
                : root.theme.iconSizeMd
            emphasized: root.checked || root.activeFocus
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.resolvedContentColor
            font.family: root.theme.fontFamilySans
            font.pixelSize: root.compact
                ? root.theme.textSizeBody
                : root.theme.textSizeBodyLarge
            font.weight: root.checked
                ? root.theme.fontWeightSemibold
                : root.theme.fontWeightMedium
        }
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
