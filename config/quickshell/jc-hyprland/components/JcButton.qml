import QtQuick

Rectangle {
    id: root

    property var theme
    property string text: ""
    property bool controlEnabled: true
    property bool checked: false
    property bool compact: false

    signal clicked()

    implicitWidth: label.implicitWidth + (compact ? 20 : 28)
    implicitHeight: compact ? 30 : 34

    radius: theme ? theme.radiusSmall : 8

    color: {
        if (root.checked) {
            if (root.theme)
                return Qt.rgba(
                    root.theme.accent.r,
                    root.theme.accent.g,
                    root.theme.accent.b,
                    0.16
                );

            return "#263449";
        }

        if (!root.controlEnabled)
            return theme ? theme.surfaceAlt : "#2d2d33";

        if (mouseArea.containsMouse)
            return theme ? theme.surfaceAlt : "#2d2d33";

        return theme ? theme.surface : "#242429";
    }

    border.width: 1
    border.color: root.checked
        ? (theme ? theme.accent : "#89b4fa")
        : (theme ? theme.border : "#3b3b43")

    opacity: root.controlEnabled ? 1.0 : 0.55

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text

        color: root.checked
            ? (root.theme ? root.theme.accent : "#89b4fa")
            : (root.theme ? root.theme.textPrimary : "#f2f2f4")

        font.pixelSize: root.compact ? 12 : 13
        font.weight: root.checked ? Font.DemiBold : Font.Medium
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        enabled: root.controlEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
