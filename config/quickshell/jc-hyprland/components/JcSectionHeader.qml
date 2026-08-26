import QtQuick

Item {
    id: root

    required property var theme

    property string title: ""
    property string subtitle: ""

    readonly property bool hasSubtitle: root.subtitle.length > 0

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Column {
        id: content

        width: root.width
        spacing: root.theme.space2Xs

        Text {
            width: parent.width

            text: root.title
            color: root.theme.textPrimary

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeSection
            font.weight: root.theme.fontWeightSemibold

            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: root.hasSubtitle

            text: root.subtitle
            color: root.theme.textSecondary

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeBody
            font.weight: root.theme.fontWeightRegular

            wrapMode: Text.WordWrap
        }
    }
}
