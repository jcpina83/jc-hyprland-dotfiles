import QtQuick

Text {
    id: root

    required property var theme

    property string name: ""
    property string glyph: ""
    property color iconColor: root.theme.controlIconDefault
    property int iconSize: root.theme.iconSizeMd
    property bool emphasized: false

    readonly property string resolvedGlyph: {
        if (root.glyph.length > 0)
            return root.glyph;

        switch (root.name) {
        case "close": return "×";
        case "refresh": return "↻";
        case "apply": return "✓";
        case "reset": return "↶";
        case "save": return "◇";
        case "keep": return "✓";
        case "revert": return "↶";
        case "fit": return "⌑";
        case "fill": return "▣";
        case "stretch": return "↔";
        case "center": return "⊙";
        case "left": return "←";
        case "right": return "→";
        case "above": return "↑";
        case "below": return "↓";
        case "display": return "▣";
        case "wallpaper": return "▧";
        case "theme": return "◐";
        case "settings": return "⚙";
        case "performance": return "◇";
        case "media": return "♪";
        case "network": return "⌁";
        case "notifications": return "●";
        case "favorite": return "★";
        default: return "";
        }
    }

    text: root.resolvedGlyph
    color: root.iconColor
    font.family: root.theme.fontFamilySans
    font.pixelSize: root.iconSize
    font.weight: root.emphasized
        ? root.theme.fontWeightSemibold
        : root.theme.fontWeightMedium
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color {
        ColorAnimation {
            duration: root.theme.motionControl
            easing.type: root.theme.easingStandard
        }
    }
}
