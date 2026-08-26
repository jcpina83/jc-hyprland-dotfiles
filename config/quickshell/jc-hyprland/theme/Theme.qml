import QtQuick

QtObject {
    id: root

    // =========================================================================
    // jc-hyprland Design System
    // Phase 2A.1.1 — Semantic Color Contract
    //
    // Canonical semantic tokens live in this section. Consumers should prefer
    // these names instead of palette-specific values or raw hexadecimal colors.
    //
    // Theme-specific loading will be introduced in later Phase 2A.1 steps.
    // For now these defaults preserve the current Phase 1 visual baseline.
    // =========================================================================

    // -------------------------------------------------------------------------
    // Canvas / surfaces
    // -------------------------------------------------------------------------

    readonly property color canvas: "#1b1b1f"
    readonly property color canvasAlt: "#202025"

    readonly property color surfaceBase: "#242429"
    readonly property color surfaceRaised: "#2d2d33"

    readonly property color surfaceOverlay: Qt.rgba(
        surfaceBase.r,
        surfaceBase.g,
        surfaceBase.b,
        0.90
    )

    readonly property color surfaceHover: Qt.rgba(
        surfaceRaised.r,
        surfaceRaised.g,
        surfaceRaised.b,
        0.94
    )

    // -------------------------------------------------------------------------
    // Borders
    // -------------------------------------------------------------------------

    readonly property color borderDefault: "#3b3b43"

    readonly property color borderSubtle: Qt.rgba(
        borderDefault.r,
        borderDefault.g,
        borderDefault.b,
        0.72
    )

    readonly property color borderAccent: Qt.rgba(
        accent.r,
        accent.g,
        accent.b,
        0.32
    )

    // -------------------------------------------------------------------------
    // Typography
    // -------------------------------------------------------------------------

    readonly property color textPrimary: "#f2f2f4"
    readonly property color textSecondary: "#b8b8c0"
    readonly property color textMuted: "#7f7f89"

    // -------------------------------------------------------------------------
    // Brand / interaction accents
    // -------------------------------------------------------------------------

    readonly property color primary: "#89b4fa"
    readonly property color secondary: "#cba6f7"
    readonly property color accent: "#89b4fa"

    // -------------------------------------------------------------------------
    // Semantic states
    // -------------------------------------------------------------------------

    readonly property color success: "#a6e3a1"
    readonly property color warning: "#f9e2af"
    readonly property color danger: "#f38ba8"
    readonly property color info: "#89dceb"

    // =========================================================================
    // Compatibility aliases
    //
    // Phase 1 components still consume these names. Keep them until the QML
    // component migration is complete so Phase 2A.1 remains non-disruptive.
    // =========================================================================

    readonly property color background: canvas
    readonly property color surface: surfaceBase
    readonly property color surfaceAlt: surfaceRaised
    readonly property color border: borderDefault
    readonly property color error: danger

    // =========================================================================
    // Existing layout tokens
    //
    // These remain unchanged in 2A.1.1. Their formal design-system scales are
    // defined later in Phase 2A.1.
    // =========================================================================

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18

    readonly property int spacingXs: 6
    readonly property int spacingSm: 10
    readonly property int spacingMd: 16
    readonly property int spacingLg: 24
}
