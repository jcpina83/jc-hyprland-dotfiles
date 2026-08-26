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
    // Interaction states
    //
    // Components should map their visual state to these tokens rather than
    // inventing local hover/pressed/selected/disabled colors.
    // =========================================================================

    // -------------------------------------------------------------------------
    // Control surfaces
    // -------------------------------------------------------------------------

    readonly property color controlSurfaceDefault: surfaceInteractive
    readonly property color controlSurfaceHover: surfaceHover
    readonly property color controlSurfacePressed: surfacePressed
    readonly property color controlSurfaceSelected: surfaceSelected

    // -------------------------------------------------------------------------
    // Control borders
    // -------------------------------------------------------------------------

    readonly property color controlBorderDefault: borderDefault
    readonly property color controlBorderHover: borderStrong
    readonly property color controlBorderPressed: borderStrong
    readonly property color controlBorderSelected: borderAccent
    readonly property color controlBorderFocus: borderFocus

    // -------------------------------------------------------------------------
    // Control content
    // -------------------------------------------------------------------------

    readonly property color controlTextDefault: textPrimary
    readonly property color controlTextSecondary: textSecondary
    readonly property color controlTextDisabled: textMuted
    readonly property color controlTextSelected: accent

    readonly property color controlIconDefault: textSecondary
    readonly property color controlIconActive: accent
    readonly property color controlIconDisabled: textMuted

    // -------------------------------------------------------------------------
    // Interaction opacity
    // -------------------------------------------------------------------------

    readonly property real opacityEnabled: 1.00
    readonly property real opacityInactive: 0.72
    readonly property real opacityDisabled: 0.48
    readonly property real opacitySubtle: 0.62

    // -------------------------------------------------------------------------
    // Focus
    // -------------------------------------------------------------------------

    readonly property int focusRingWidth: 2
    readonly property color focusRingColor: borderFocus

    // -------------------------------------------------------------------------
    // Semantic feedback surfaces
    //
    // Status banners, validation chips and future toast/notification components
    // can share these semantic colors without embedding theme-specific values.
    // -------------------------------------------------------------------------

    readonly property color successSurface: Qt.rgba(
        success.r,
        success.g,
        success.b,
        0.12
    )

    readonly property color successBorder: Qt.rgba(
        success.r,
        success.g,
        success.b,
        0.34
    )

    readonly property color warningSurface: Qt.rgba(
        warning.r,
        warning.g,
        warning.b,
        0.12
    )

    readonly property color warningBorder: Qt.rgba(
        warning.r,
        warning.g,
        warning.b,
        0.34
    )

    readonly property color dangerSurface: Qt.rgba(
        danger.r,
        danger.g,
        danger.b,
        0.12
    )

    readonly property color dangerBorder: Qt.rgba(
        danger.r,
        danger.g,
        danger.b,
        0.34
    )

    readonly property color infoSurface: Qt.rgba(
        info.r,
        info.g,
        info.b,
        0.12
    )

    readonly property color infoBorder: Qt.rgba(
        info.r,
        info.g,
        info.b,
        0.34
    )

    // =========================================================================
    // Geometry scale
    // =========================================================================

    // -------------------------------------------------------------------------
    // Spacing
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
    // Typography scale
    // =========================================================================

    // -------------------------------------------------------------------------
    // Font families
    // -------------------------------------------------------------------------

    readonly property string fontFamilySans: "sans-serif"
    readonly property string fontFamilyMono: "monospace"

    // -------------------------------------------------------------------------
    // Primitive font-size scale
    // -------------------------------------------------------------------------

    readonly property int fontSize2Xs: 9
    readonly property int fontSizeXs: 10
    readonly property int fontSizeSm: 11
    readonly property int fontSizeMd: 12
    readonly property int fontSizeLg: 13
    readonly property int fontSizeXl: 14
    readonly property int fontSize2Xl: 16
    readonly property int fontSize3Xl: 20
    readonly property int fontSize4Xl: 22
    readonly property int fontSize5Xl: 28

    // -------------------------------------------------------------------------
    // Semantic typography
    // -------------------------------------------------------------------------

    readonly property int textSizeMicro: fontSize2Xs
    readonly property int textSizeCaption: fontSizeXs
    readonly property int textSizeLabel: fontSizeSm
    readonly property int textSizeBody: fontSizeMd
    readonly property int textSizeBodyLarge: fontSizeLg
    readonly property int textSizeSection: fontSizeXl
    readonly property int textSizeCardTitle: fontSize2Xl
    readonly property int textSizePanelTitle: fontSize4Xl
    readonly property int textSizeMetric: fontSize5Xl

    // -------------------------------------------------------------------------
    // Font weights
    // -------------------------------------------------------------------------

    readonly property int fontWeightRegular: Font.Normal
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightSemibold: Font.DemiBold
    readonly property int fontWeightBold: Font.Bold

    // -------------------------------------------------------------------------
    // Line-height multipliers
    // -------------------------------------------------------------------------

    readonly property real lineHeightCompact: 1.15
    readonly property real lineHeightBody: 1.35
    readonly property real lineHeightRelaxed: 1.50

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
