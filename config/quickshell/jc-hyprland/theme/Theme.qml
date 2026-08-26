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
    //
    // sunken
    //   Background regions visually below normal content.
    //
    // base
    //   Standard card / panel surface.
    //
    // raised
    //   Cards or controls visually above a base surface.
    //
    // glass
    //   Translucent shell / overlay surface.
    //
    // interactive
    //   Default clickable/selectable surface.
    //
    // hover / pressed / selected
    //   Interaction depth layered over the semantic surface hierarchy.
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
    // component migration is complete so Phase 2A remains non-disruptive.
    // =========================================================================

    readonly property color background: canvas
    readonly property color surface: surfaceBase
    readonly property color surfaceAlt: surfaceRaised
    readonly property color border: borderDefault
    readonly property color error: danger

    // Existing glass-style compatibility names for future shared consumers.
    readonly property color glass: surfaceGlass
    readonly property color glassLight: surfaceGlassRaised
    readonly property color glassHover: surfaceHover
    readonly property color glassBorder: borderSubtle

    // =========================================================================
    // Existing layout tokens
    //
    // These remain unchanged in 2A.1.2. Their formal design-system scales are
    // defined in subsequent Phase 2A.1 steps.
    // =========================================================================

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 18

    readonly property int spacingXs: 6
    readonly property int spacingSm: 10
    readonly property int spacingMd: 16
    readonly property int spacingLg: 24
}
