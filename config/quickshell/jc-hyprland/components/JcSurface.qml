import QtQuick

Rectangle {
    id: root

    required property var theme

    // Canonical semantic surface role.
    // Supported values:
    // sunken, base, raised, glass, glass-raised, overlay, interactive
    property string surfaceRole: "base"

    property bool selected: false
    property bool focused: false
    property bool bordered: true

    property int cornerRadius: theme.radiusMd
    property int outlineWidth: theme.borderWidthThin

    readonly property color resolvedSurfaceColor: {
        if (root.selected)
            return root.theme.surfaceSelected;

        switch (root.surfaceRole) {
        case "sunken":
            return root.theme.surfaceSunken;
        case "raised":
            return root.theme.surfaceRaised;
        case "glass":
            return root.theme.surfaceGlass;
        case "glass-raised":
            return root.theme.surfaceGlassRaised;
        case "overlay":
            return root.theme.surfaceOverlay;
        case "interactive":
            return root.theme.surfaceInteractive;
        case "base":
        default:
            return root.theme.surfaceBase;
        }
    }

    readonly property color resolvedBorderColor: {
        if (root.focused)
            return root.theme.borderFocus;

        if (root.selected)
            return root.theme.borderAccent;

        return root.theme.borderDefault;
    }

    color: root.resolvedSurfaceColor
    radius: root.cornerRadius

    border.width: root.bordered ? root.outlineWidth : 0
    border.color: root.resolvedBorderColor

    Behavior on color {
        ColorAnimation {
            duration: root.theme.motionSelection
            easing.type: root.theme.easingStandard
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: root.theme.motionSelection
            easing.type: root.theme.easingStandard
        }
    }
}
