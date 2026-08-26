import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // =========================================================================
    // jc-hyprland Design System
    // Phase 2A.1 — Theme API
    //
    // Runtime theme identity is read from the existing machine-local
    // `local/active-theme` contract written by scripts/theme.sh.
    //
    // Visual values are then loaded from:
    //
    //   ~/.config/jc-hyprland-dotfiles/repo/themes/<theme>/quickshell.json
    //
    // This keeps Quickshell behind the same active-theme authority already used
    // by the rest of the desktop. No shell command is executed from QML.
    // =========================================================================

    // -------------------------------------------------------------------------
    // Runtime theme source
    // -------------------------------------------------------------------------

    readonly property string homeDir: {
        const value = Quickshell.env("HOME");
        return value ? String(value) : "";
    }

    readonly property string configHome: {
        const value = Quickshell.env("XDG_CONFIG_HOME");

        if (value)
            return String(value);

        return root.homeDir + "/.config";
    }

    readonly property string runtimeBase:
        root.configHome + "/jc-hyprland-dotfiles"

    readonly property string activeThemeId: {
        if (!activeThemeFile.loaded)
            return "";

        return activeThemeFile.text().trim();
    }

    readonly property string themeFilePath: {
        if (!root.activeThemeId)
            return "";

        return root.runtimeBase
            + "/repo/themes/"
            + root.activeThemeId
            + "/quickshell.json";
    }

    readonly property var themeData: {
        if (!themeFile.loaded)
            return ({});

        const raw = themeFile.text().trim();

        if (!raw)
            return ({});

        try {
            return JSON.parse(raw);
        } catch (error) {
            console.warn(
                "jc-hyprland: invalid Quickshell theme JSON:",
                root.themeFilePath,
                error
            );

            return ({});
        }
    }

    readonly property bool externalThemeLoaded:
        themeFile.loaded
        && root.themeData
        && root.themeData.id === root.activeThemeId

    readonly property string activeThemeName: {
        if (root.themeData && root.themeData.name)
            return String(root.themeData.name);

        return root.activeThemeId;
    }

    function colorToken(name, fallback) {
        const colors = root.themeData ? root.themeData.colors : null;

        if (colors && colors[name] !== undefined && colors[name] !== "")
            return colors[name];

        return fallback;
    }

    function opacityToken(name, fallback) {
        const values = root.themeData ? root.themeData.opacity : null;

        if (!values || values[name] === undefined)
            return fallback;

        const value = Number(values[name]);

        if (!Number.isFinite(value))
            return fallback;

        return Math.max(0.0, Math.min(1.0, value));
    }

    FileView {
        id: activeThemeFile

        path: root.runtimeBase + "/local/active-theme"
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
    }

    FileView {
        id: themeFile

        path: root.themeFilePath
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
    }

    // -------------------------------------------------------------------------
    // Canvas
    // -------------------------------------------------------------------------

    readonly property color canvas:
        root.colorToken("canvas", "#1b1b1f")

    readonly property color canvasAlt:
        root.colorToken("canvasAlt", "#202025")

    // -------------------------------------------------------------------------
    // Surface hierarchy
    // -------------------------------------------------------------------------

    readonly property color surfaceSunken:
        root.colorToken("surfaceSunken", canvasAlt)

    readonly property color surfaceBase:
        root.colorToken("surfaceBase", "#242429")

    readonly property color surfaceRaised:
        root.colorToken("surfaceRaised", "#2d2d33")

    readonly property color surfaceGlass: Qt.rgba(
        canvas.r,
        canvas.g,
        canvas.b,
        root.opacityToken("surfaceGlass", 0.78)
    )

    readonly property color surfaceGlassRaised: Qt.rgba(
        surfaceBase.r,
        surfaceBase.g,
        surfaceBase.b,
        root.opacityToken("surfaceGlassRaised", 0.86)
    )

    readonly property color surfaceOverlay: Qt.rgba(
        surfaceBase.r,
        surfaceBase.g,
        surfaceBase.b,
        root.opacityToken("surfaceOverlay", 0.90)
    )

    readonly property color surfaceInteractive:
        root.colorToken("surfaceInteractive", surfaceRaised)

    readonly property color surfaceHover: Qt.rgba(
        surfaceRaised.r,
        surfaceRaised.g,
        surfaceRaised.b,
        root.opacityToken("surfaceHover", 0.94)
    )

    readonly property color surfacePressed:
        root.colorToken("surfacePressed", "#35353c")

    readonly property color surfaceSelected: Qt.rgba(
        accent.r,
        accent.g,
        accent.b,
        root.opacityToken("surfaceSelected", 0.16)
    )

    readonly property color scrim: Qt.rgba(
        0,
        0,
        0,
        root.opacityToken("scrim", 0.42)
    )

    // -------------------------------------------------------------------------
    // Borders
    // -------------------------------------------------------------------------

    readonly property color borderDefault: Qt.rgba(
        primary.r,
        primary.g,
        primary.b,
        root.opacityToken("borderDefault", 0.24)
    )

    readonly property color borderSubtle: Qt.rgba(
        primary.r,
        primary.g,
        primary.b,
        root.opacityToken("borderSubtle", 0.20)
    )

    readonly property color borderStrong: Qt.rgba(
        primary.r,
        primary.g,
        primary.b,
        root.opacityToken("borderStrong", 0.38)
    )

    readonly property color borderAccent: Qt.rgba(
        accent.r,
        accent.g,
        accent.b,
        root.opacityToken("borderAccent", 0.34)
    )

    readonly property color borderFocus: Qt.rgba(
        primary.r,
        primary.g,
        primary.b,
        root.opacityToken("borderFocus", 0.62)
    )

    // -------------------------------------------------------------------------
    // Typography colors
    // -------------------------------------------------------------------------

    readonly property color textPrimary:
        root.colorToken("textPrimary", "#f2f2f4")

    readonly property color textSecondary:
        root.colorToken("textSecondary", "#b8b8c0")

    readonly property color textMuted:
        root.colorToken("textMuted", "#7f7f89")

    // -------------------------------------------------------------------------
    // Brand / interaction accents
    // -------------------------------------------------------------------------

    readonly property color primary:
        root.colorToken("primary", "#89b4fa")

    readonly property color secondary:
        root.colorToken("secondary", "#cba6f7")

    readonly property color accent:
        root.colorToken("accent", "#89b4fa")

    // -------------------------------------------------------------------------
    // Semantic states
    // -------------------------------------------------------------------------

    readonly property color success:
        root.colorToken("success", "#a6e3a1")

    readonly property color warning:
        root.colorToken("warning", "#f9e2af")

    readonly property color danger:
        root.colorToken("danger", "#f38ba8")

    readonly property color info:
        root.colorToken("info", "#89dceb")

    // =========================================================================
    // Interaction states
    // =========================================================================

    // Control surfaces
    readonly property color controlSurfaceDefault: surfaceInteractive
    readonly property color controlSurfaceHover: surfaceHover
    readonly property color controlSurfacePressed: surfacePressed
    readonly property color controlSurfaceSelected: surfaceSelected

    // Control borders
    readonly property color controlBorderDefault: borderDefault
    readonly property color controlBorderHover: borderStrong
    readonly property color controlBorderPressed: borderStrong
    readonly property color controlBorderSelected: borderAccent
    readonly property color controlBorderFocus: borderFocus

    // Control content
    readonly property color controlTextDefault: textPrimary
    readonly property color controlTextSecondary: textSecondary
    readonly property color controlTextDisabled: textMuted
    readonly property color controlTextSelected: accent

    readonly property color controlIconDefault: textSecondary
    readonly property color controlIconActive: accent
    readonly property color controlIconDisabled: textMuted

    // Interaction opacity
    readonly property real opacityEnabled: 1.00
    readonly property real opacityInactive: 0.72
    readonly property real opacityDisabled: 0.48
    readonly property real opacitySubtle: 0.62

    // Focus
    readonly property int focusRingWidth: 2
    readonly property color focusRingColor: borderFocus

    // Semantic feedback surfaces
    readonly property color successSurface: Qt.rgba(
        success.r,
        success.g,
        success.b,
        root.opacityToken("feedbackSurface", 0.12)
    )

    readonly property color successBorder: Qt.rgba(
        success.r,
        success.g,
        success.b,
        root.opacityToken("feedbackBorder", 0.34)
    )

    readonly property color warningSurface: Qt.rgba(
        warning.r,
        warning.g,
        warning.b,
        root.opacityToken("feedbackSurface", 0.12)
    )

    readonly property color warningBorder: Qt.rgba(
        warning.r,
        warning.g,
        warning.b,
        root.opacityToken("feedbackBorder", 0.34)
    )

    readonly property color dangerSurface: Qt.rgba(
        danger.r,
        danger.g,
        danger.b,
        root.opacityToken("feedbackSurface", 0.12)
    )

    readonly property color dangerBorder: Qt.rgba(
        danger.r,
        danger.g,
        danger.b,
        root.opacityToken("feedbackBorder", 0.34)
    )

    readonly property color infoSurface: Qt.rgba(
        info.r,
        info.g,
        info.b,
        root.opacityToken("feedbackSurface", 0.12)
    )

    readonly property color infoBorder: Qt.rgba(
        info.r,
        info.g,
        info.b,
        root.opacityToken("feedbackBorder", 0.34)
    )

    // =========================================================================
    // Geometry scale
    // =========================================================================

    // Spacing
    readonly property int space2Xs: 4
    readonly property int spaceXs: 6
    readonly property int spaceSm: 10
    readonly property int spaceMd: 16
    readonly property int spaceLg: 24
    readonly property int spaceXl: 32
    readonly property int space2Xl: 40

    // Radius
    readonly property int radiusXs: 6
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12
    readonly property int radiusLg: 18
    readonly property int radiusXl: 24
    readonly property int radius2Xl: 32
    readonly property int radiusPill: 999

    // Common geometry
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

    // Font families
    readonly property string fontFamilySans: "sans-serif"
    readonly property string fontFamilyMono: "monospace"

    // Primitive font-size scale
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

    // Semantic typography
    readonly property int textSizeMicro: fontSize2Xs
    readonly property int textSizeCaption: fontSizeXs
    readonly property int textSizeLabel: fontSizeSm
    readonly property int textSizeBody: fontSizeMd
    readonly property int textSizeBodyLarge: fontSizeLg
    readonly property int textSizeSection: fontSizeXl
    readonly property int textSizeCardTitle: fontSize2Xl
    readonly property int textSizePanelTitle: fontSize4Xl
    readonly property int textSizeMetric: fontSize5Xl

    // Font weights
    readonly property int fontWeightRegular: Font.Normal
    readonly property int fontWeightMedium: Font.Medium
    readonly property int fontWeightSemibold: Font.DemiBold
    readonly property int fontWeightBold: Font.Bold

    // Line-height multipliers
    readonly property real lineHeightCompact: 1.15
    readonly property real lineHeightBody: 1.35
    readonly property real lineHeightRelaxed: 1.50

    // =========================================================================
    // Motion / animation
    // =========================================================================

    readonly property real motionScale: 1.0

    // Primitive duration scale (milliseconds)
    readonly property int motionInstant: 0
    readonly property int motionFast: Math.round(100 * motionScale)
    readonly property int motionNormal: Math.round(160 * motionScale)
    readonly property int motionSlow: Math.round(240 * motionScale)
    readonly property int motionEmphasis: Math.round(320 * motionScale)

    // Semantic durations
    readonly property int motionHover: motionFast
    readonly property int motionPress: motionFast
    readonly property int motionSelection: motionNormal
    readonly property int motionControl: motionNormal
    readonly property int motionPanel: motionSlow
    readonly property int motionDialog: motionSlow
    readonly property int motionEmphasized: motionEmphasis

    // Easing contract
    readonly property int easingStandard: Easing.OutCubic
    readonly property int easingEnter: Easing.OutCubic
    readonly property int easingExit: Easing.InCubic
    readonly property int easingEmphasized: Easing.InOutCubic

    // =========================================================================
    // Compatibility aliases
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
