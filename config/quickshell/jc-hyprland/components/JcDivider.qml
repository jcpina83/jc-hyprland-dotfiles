import QtQuick

Rectangle {
    id: root

    required property var theme

    property int orientation: Qt.Horizontal
    property color dividerColor: theme.borderSubtle
    property int thickness: theme.borderWidthThin

    color: root.dividerColor

    implicitWidth: root.orientation === Qt.Vertical
        ? root.thickness
        : 1

    implicitHeight: root.orientation === Qt.Horizontal
        ? root.thickness
        : 1
}
