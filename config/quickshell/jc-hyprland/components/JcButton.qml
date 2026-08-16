import QtQuick

Rectangle {
    id: root

    property var theme
    property string text: ""
    property bool controlEnabled: true

    signal clicked()

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 34

    radius: theme ? theme.radiusSmall : 8

    color: {
        if (!root.controlEnabled)
            return theme ? theme.surfaceAlt : "#2d2d33";

        if (mouseArea.containsMouse)
            return theme ? theme.surfaceAlt : "#2d2d33";

        return theme ? theme.surface : "#242429";
    }

    border.width: 1
    border.color: theme ? theme.border : "#3b3b43"
    opacity: root.controlEnabled ? 1.0 : 0.55

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.theme ? root.theme.textPrimary : "#f2f2f4"
        font.pixelSize: 13
        font.weight: Font.Medium
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
