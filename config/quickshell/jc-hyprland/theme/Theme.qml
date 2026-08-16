import QtQuick

QtObject {
    // Phase 1A: intentionally simple static design tokens.
    // This is the boundary where Matugen/theme providers can be plugged in later.

    readonly property color background: "#1b1b1f"
    readonly property color surface: "#242429"
    readonly property color surfaceAlt: "#2d2d33"
    readonly property color border: "#3b3b43"

    readonly property color textPrimary: "#f2f2f4"
    readonly property color textSecondary: "#b8b8c0"
    readonly property color accent: "#89b4fa"
    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color error: "#f38ba8"

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18

    readonly property int spacingXs: 6
    readonly property int spacingSm: 10
    readonly property int spacingMd: 16
    readonly property int spacingLg: 24
}
