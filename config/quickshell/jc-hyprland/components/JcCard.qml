import QtQuick

Rectangle {
    id: root

    property var theme

    radius: theme ? theme.radiusMedium : 12
    color: theme ? theme.surface : "#242429"
    border.width: 1
    border.color: theme ? theme.border : "#3b3b43"
}
