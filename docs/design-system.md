# Design System / Theme API

Phase 2A.1 establishes the shared visual contract used by the Quickshell Control
Center and aligns Waybar with the same semantic vocabulary.

The central rule is:

> Themes provide visual data, `Theme.qml` exposes the semantic API, and
> components consume that API.

A component must not branch on a concrete theme name such as `odyssey-glass`
or `cyber-noir`.

---

## Architecture

```text
scripts/theme.sh
      |
      +-- ~/.config/jc-hyprland-dotfiles/theme
      |       -> repo/themes/<active-theme>
      |
      +-- ~/.config/jc-hyprland-dotfiles/local/active-theme
                          |
                          v
                  Quickshell FileView
                          |
                          v
        themes/<active-theme>/quickshell.json
                          |
                          v
                       Theme.qml
                          |
                 semantic Theme API
                          |
                 +--------+--------+
                 |                 |
                 v                 v
          Control Center       future widgets
```

`Theme.qml` does not execute shell commands to discover the active theme.
It observes the existing `local/active-theme` state and resolves the
theme-specific JSON through the stable runtime `repo` namespace.

Theme switching therefore remains owned by the existing theme manager.

---

## Theme contract

Every supported theme contains the normal desktop theme files plus a
Quickshell profile:

```text
themes/<theme>/
├── theme.env
├── colors.conf
├── colors.css
├── colors.lua
├── quickshell.json
├── foot-colors.ini
├── hyprlock.env
├── sddm.env
└── wallpapers/
```

`quickshell.json` currently uses schema version `1`.

Example structure:

```json
{
  "schemaVersion": 1,
  "id": "example-theme",
  "name": "Example Theme",
  "colors": {
    "canvas": "#000000",
    "surfaceBase": "#111111",
    "surfaceRaised": "#222222",
    "textPrimary": "#ffffff",
    "primary": "#55aaff",
    "accent": "#88ccff"
  },
  "opacity": {
    "surfaceGlass": 0.8,
    "surfaceSelected": 0.16,
    "borderFocus": 0.62
  }
}
```

The validator enforces the complete required key set for tracked themes.

---

## Semantic color contract

The QML API is intentionally semantic.

### Canvas and surfaces

```text
canvas
canvasAlt

surfaceSunken
surfaceBase
surfaceRaised
surfaceGlass
surfaceGlassRaised
surfaceOverlay
surfaceInteractive
surfaceHover
surfacePressed
surfaceSelected
scrim
```

### Borders

```text
borderSubtle
borderDefault
borderStrong
borderAccent
borderFocus
```

### Text

```text
textPrimary
textSecondary
textMuted
```

### Actions / accents

```text
primary
secondary
accent
```

### State colors

```text
success
warning
danger
info
```

### Interaction contract

```text
controlSurfaceDefault / Hover / Pressed / Selected
controlBorderDefault / Hover / Pressed / Selected / Focus
controlTextDefault / Secondary / Disabled / Selected
controlIconDefault / Active / Disabled
opacityEnabled / Inactive / Disabled / Subtle
focusRingWidth / focusRingColor
```

Feedback surfaces and borders are derived from semantic state colors rather
than hardcoded per-component values.

---

## Geometry and typography

`Theme.qml` owns the primitive and semantic scales for:

- spacing,
- corner radii,
- border widths,
- control heights,
- icon sizes,
- font families,
- font sizes,
- semantic text sizes,
- font weights,
- line-height multipliers.

Components should consume these values instead of embedding new arbitrary
pixel constants when an appropriate token already exists.

---

## Motion

The shared motion contract is:

```text
motionInstant
motionFast
motionNormal
motionSlow
motionEmphasis

motionHover
motionPress
motionSelection
motionControl
motionPanel
motionDialog
motionEmphasized

easingStandard
easingEnter
easingExit
easingEmphasized
```

`motionScale` is the future boundary for global motion profiles or
accessibility behavior. Components own animation behavior; the theme API owns
the timing/easing vocabulary.

---

## Waybar alignment

GTK CSS cannot consume QML numeric properties directly, so the QML and Waybar
contracts share semantic meaning rather than a common syntax.

Waybar consumes semantic color aliases from each theme's `colors.css`:

```text
QML                         Waybar / GTK CSS
-------------------------------------------------------
canvas                      @canvas
surfaceGlass                @surface-glass
surfaceOverlay              @surface-overlay
surfaceHover                @surface-hover
surfaceSelected             @surface-selected
borderSubtle                @border-subtle
textPrimary                 @text-primary
textSecondary               @text-secondary
textMuted                   @text-muted
primary                     @action-primary
secondary                   @action-secondary
accent                      @action-accent
success                     @state-success
warning                     @state-warning
danger                      @state-danger
info                        @state-info
```

Palette primitives such as `@orange` may remain when they are genuinely
decorative and do not represent a semantic state.

---

## Compatibility aliases

Phase 1 components still use several earlier names such as:

```text
background
surface
surfaceAlt
border
error

glass
glassLight
glassHover
glassBorder

radiusSmall
radiusMedium
radiusLarge

spacingXs
spacingSm
spacingMd
spacingLg
```

These aliases remain intentionally available while Phase 2A.2 migrates and
expands the reusable component library. New components should prefer the
canonical semantic names.

---

## Rules for components

New reusable QML components should:

1. receive or resolve the shared Theme API rather than owning palette values;
2. use semantic surface/text/state tokens;
3. use the geometry, typography, interaction and motion scales;
4. avoid concrete theme-name checks;
5. avoid direct shell/process execution for visual configuration;
6. keep behavior and state ownership outside the visual token layer.

The design system is a presentation contract, not an application-state or
runtime-command service.

---

## Rules for new themes

A new theme must:

1. provide the complete standard theme file contract;
2. include a valid `quickshell.json`;
3. use a matching `id` for its directory/theme identity;
4. expose the required semantic aliases in `colors.css`;
5. pass `scripts/validate-design-system.sh`;
6. pass the normal repository lint/check gates.

---

## Validation

Run:

```bash
./scripts/validate-design-system.sh
make quickshell-validate
make lint
make check
hyprctl configerrors
```

`make lint` includes the Design System validator.

Phase 2A.1 is complete when both runtime themes switch successfully in
Quickshell, Waybar uses the semantic CSS vocabulary, and all repository quality
gates remain green.
