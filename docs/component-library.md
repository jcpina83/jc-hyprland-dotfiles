# Reusable QML Component Library

Phase 2A.2 establishes the reusable visual component layer for the
`jc-hyprland` Quickshell Control Center.

```text
themes/<active>/quickshell.json
              |
              v
          Theme.qml
              |
              v
     reusable components
              |
              v
       feature modules
              |
              v
           Main.qml
```

The component layer owns presentation and interaction behavior. It does not own
Hyprland mutation, persistence, hardware policy, or feature-specific state.

---

## Status

Phase 2A.2 is complete.

```text
2A.2.1 Component audit + API contract        complete
2A.2.2 Foundations                           complete
2A.2.3 Actions                               complete
2A.2.4 Selection                             complete
2A.2.5 Inputs                                complete
2A.2.6 Navigation                            complete
2A.2.7 Feedback / overlays                   complete
2A.2.8 Data visualization                    complete
2A.2.9 Component Gallery                     complete
2A.2.10 Validation + documentation           complete
```

---

## Component contract

Canonical Phase 2 components receive the shared Theme API through:

```qml
required property var theme
```

They consume semantic tokens for colors, surfaces, borders, interaction states,
spacing, radii, control sizes, typography, opacity, focus, motion and easing.

Components must not branch on concrete theme IDs such as `odyssey-glass` or
`cyber-noir`.

Components must not execute shell commands or mutate Hyprland directly.

---

## Component catalog

| Component | Responsibility | Primary API |
|---|---|---|
| `JcSurface` | Semantic container / depth | `surfaceRole`, `selected`, `focused`, `bordered` |
| `JcDivider` | Separator | `orientation`, `dividerColor`, `thickness` |
| `JcSectionHeader` | Section title/subtitle | `title`, `subtitle` |
| `JcButton` | Text action | `text`, `iconName`, `icon` fallback, `controlEnabled`, `checked`, `compact`, `clicked()` |
| `JcIconButton` | Compact icon action | `iconName`, `icon` fallback, `accessibleName`, `controlEnabled`, `checked`, `compact`, `clicked()` |
| `JcChip` | Discrete selection | `text`, `iconName`, `icon` fallback, `checked`, `controlEnabled`, `clicked()` |
| `JcToggle` | Boolean selection | `text`, `checked`, `controlEnabled`, `toggled(value)` |
| `JcChoiceGroup` | Visible discrete option set | `options`, `selectedValue`, `emptyText`, `controlEnabled`, `valueSelected(value)` |
| `JcSlider` | Numeric range input | Slider `from`, `to`, `value`, `stepSize`, `moved()` plus `controlEnabled` |
| `JcComboBox` | Compact list selection | `options`, `selectedValue`, `placeholder`, `controlEnabled`, `valueSelected(value)` |
| `JcNavItem` | Control Center navigation | `iconName`, `icon` fallback, `text`, `selected`, `controlEnabled`, `clicked()` |
| `JcTooltip` | Contextual help | ToolTip `text`, `visible` plus `controlEnabled` |
| `JcPopup` | Contained overlay | Popup API plus `showScrim`, `dismissOnOutside` |
| `JcMetricRing` | Semantic metric visualization | `value`, `minimum`, `maximum`, `label`, `unit`, `status`, `decimals` |

---

## State ownership

The visual component is not a state authority.

```text
Observed State
      |
      v
   Draft State
      |
      v
Applied Runtime State
      |
      v
Persistent State
```

Selection components display external state and emit requests back to the owner:

```text
JcChoiceGroup / JcChip
    selectedValue / checked -> visual state
    valueSelected / clicked -> request

JcToggle
    checked                 -> visual state
    toggled                 -> requested value

JcComboBox
    selectedValue           -> visual state
    valueSelected           -> request
```

---

## Action vs selection

```text
JcButton       action
JcIconButton   compact icon action

JcChip         discrete selection
JcToggle       boolean selection
JcChoiceGroup  small visible option set

JcSlider       numeric range
JcComboBox     compact / larger option set

JcNavItem      module navigation
```

---

## Metric visualization

`JcMetricRing` visualizes data but does not decide hardware thresholds.

The provider owns `value`, range and semantic `status`.

Supported statuses:

```text
normal
success
warning
danger
critical
info
```

`critical` maps to the Design System `danger` color.

---

## Feedback and overlays

`JcTooltip` provides brief contextual help.

`JcPopup` is a contained overlay owned by an existing Quickshell window and
supports focus, Escape, optional outside-click dismissal, optional scrim,
modal/modeless behavior and Design System motion.

`JcPopup` does not replace feature-level `PanelWindow` ownership.

---

## Compatibility retirement

`JcCard` was retired in Phase 2A.4.7 after its final Component Gallery consumer
migrated to `JcSurface`.

The Phase 1 Theme API compatibility aliases were retired at the same boundary.
Production Phase 2 QML therefore uses the canonical semantic Theme API directly;
new components must use `JcSurface` plus the reusable control library.

Migration of the current Displays card surfaces belongs to Phase 2A.4.

---

## Component Gallery

The visual harness lives at:

```text
config/quickshell/jc-hyprland/modules/dev/ComponentGallery.qml
```

IPC:

```bash
qs -c jc-hyprland ipc call controlCenter showGallery
qs -c jc-hyprland ipc call controlCenter hideGallery
qs -c jc-hyprland ipc call controlCenter toggleGallery
qs -c jc-hyprland ipc call controlCenter galleryIsVisible
```

The gallery and Displays panel are mutually exclusive.

The gallery is a development surface. Production desktop consumers continue to
use the stable `jc-control-center` wrapper.

---

## Quality gates

```bash
make quickshell-validate
make lint
make check

qs -c jc-hyprland ipc show
qs -c jc-hyprland log
hyprctl configerrors

git diff --check
git diff --cached --check
```

Phase 2A.2 closure validation checks:

- complete canonical component inventory,
- required Theme API injection,
- no hardcoded colors in canonical components,
- no legacy Theme aliases in canonical components,
- complete Component Gallery coverage,
- documentation coverage,
- retired Phase 1 visual compatibility boundary,
- completed roadmap state.

---

## Next phases

```text
2A.3 Control Center shell + navigation  ✓ complete
2A.4 Displays visual redesign           ← next
```

Phase 2A.3 composed the reusable vocabulary into the production Control Center shell.

Phase 2A.4 is next and migrates Displays visually while preserving the observed /
draft / runtime / persistent architecture.
