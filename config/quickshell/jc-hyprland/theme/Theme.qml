import QtQuick

QtObject {
    id: root

    // =========================================================================
    // jc-hyprland Design System
    // Phase 2A.1 — Theme API
    //
    // Canonical semantic tokens live in this object. Consumers should prefer
    // these names instead of palette-specific values or raw hexadecimal colors.
    //
    // Theme-specific runtime loading will be introduced later in Phase 2A.1.
    // These defaults preserve the existing Control Center visual baseline.
    // =========================================================================

    // -------------------------------------------------------------------------
    // Canvas
    // -------------------------------------------------------------------------

    readonly property color canvas: "#1b1b1f"
    readonly property color canvasAlt: "#202025"

    // -------------------------------------------------------------------------
    // Surface hierarchy
    // -------------------------------------------------------------------------

    readonly property color surfaceSunken: canvasAlt
    readonly property color surfaceBase: "#242429"
    readonly property color surfaceRaised: "#2d2d33"

    readonly property color surfaceGlass: Qt.rgba(
        canvas.r,
        canvas.g,
        canvas.b,
        0.78
    )

    readonly property color surfaceGlassRaised: Qt.rgba(
        surfaceBase.r,
        surfaceBase.g,
        surfaceBase.b,
        0.86
    )

    readonly property color surfaceOverlay: Qt.rgba(
        surfaceBase.r,
        surfaceBase.g,
        surfaceBase.b,
        0.90
    )

    readonly property color surfaceInteractive: surfaceRaised

    readonly property color surfaceHover: Qt.rgba(
        surfaceRaised.r,
        surfaceRaised.g,
        surfaceRaised.b,
        0.94
    )

    readonly property color surfacePressed: "#35353c"

    readonly property color surfaceSelected: Qt.rgba(
        accent.r,
        accent.g,
        accent.b,
        0.16
    )

    readonly property color scrim: Qt.rgba(0, 0, 0, 0.42)

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

    readonly property color borderStrong: Qt.rgba(
        primary.r,
        primary.g,
        primary.b,
        0.38
    )

    readonly property color borderAccent: Qt.rgba(
        accent.r,
        accent.g,
        accent.b,
        0.34
    )

    readonly property color borderFocus: Qt.rgba(
        primary.r,
        primary.g,
        primary.b,
        0.62
    )

    // -------------------------------------------------------------------------
    // Typography colors
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
    // Geometry scale
    //
    // The scale is intentionally compact enough for a desktop control surface
    // while still supporting the generous spacing used by larger glass panels.
    // Existing Phase 1 values remain represented exactly through compatibility
    // aliases below.
    // =========================================================================

    // -------------------------------------------------------------------------
    // Spacing
    //
    // Prefer these semantic scale names in new components.
    // -------------------------------------------------------------------------

    readonly property int space2Xs: 4
    readonly property int spaceXs: 6
    readonly property int spaceSm: 10
    readonly property int spaceMd: 16
    readonly property int spaceLg: 24
    readonly property int spaceXl: 32
    readonly property int space2Xl: 40

    // -------------------------------------------------------------------------
    // Radius
    //
    // radiusPill is intentionally very large so the final radius is constrained
    // naturally by the control height.
    // -------------------------------------------------------------------------

    readonly property int radiusXs: 6
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 18
    readonly property int radiusXl: 24
    readonly property int radius2Xl: 32
    readonly property int radiusPill: 999

    // -------------------------------------------------------------------------
    // Common geometry
    //
    // These are not widget implementations. They provide shared measurements
    // for the reusable component library introduced in Phase 2A.2.
    // -------------------------------------------------------------------------

    readonly property int borderWidthThin: 1
    readonly property int borderWidthStrong: 2

    readonly property int controlHeightCompact: 30
    readonly property int controlHeightDefault: 34
    readonly property int controlHeightLarge: 42

    readonly property int iconSizeSm: 14
    readonly property int iconSizeMd: 18
    readonly property int iconSizeLg: 22
    readonly property int iconSizeXl: 28

    // =========================================================================
    // Compatibility aliases
    //
    // Phase 1 components still consume these names. Keep them until the QML
    // component migration is complete so Phase 2A remains non-disruptive.
    // =========================================================================

    // Colors
    readonly property color background: canvas
    readonly property color surface: surfaceBase
    readonly property color surfaceAlt: surfaceRaised
    readonly property color border: borderDefault
    readonly property color error: danger

    // Glass
    readonly property color glass: surfaceGlass
    readonly property color glassLight: surfaceGlassRaised
    readonly property color glassHover: surfaceHover
    readonly property color glassBorder: borderSubtle

    // Geometry
    readonly property int radiusSmall: radiusSm
    readonly property int radiusMedium: radiusMd
    readonly property int radiusLarge: radiusLg

    readonly property int spacingXs: spaceXs
    readonly property int spacingSm: spaceSm
    readonly property int spacingMd: spaceMd
    readonly property int spacingLg: spaceLg
}
