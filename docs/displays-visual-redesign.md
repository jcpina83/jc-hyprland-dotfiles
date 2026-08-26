# Displays Visual Redesign

Phase 2A.4 migrates the existing Displays feature to the shared Phase 2 visual
system without redesigning the proven display runtime architecture.

Phase 2A.3 already established the generic Control Center shell. Phase 2A.4 is
therefore a presentation migration inside the hosted Displays feature, not a
new window architecture and not a display-backend rewrite.

---

## Phase status

```text
2A.4.1 Displays UI audit + visual migration contract       ✓
2A.4.2 DisplayView shell/content cleanup                   ✓
2A.4.3 DisplayCard migration to canonical components       ✓
2A.4.4 Mode / scale / transform controls                   ✓
2A.4.5 Layout editor visual integration                    ← CURRENT
2A.4.6 Safe Apply / persistence presentation
2A.4.7 Retire Displays visual compatibility layer
2A.4.8 Responsive + keyboard + visual validation
2A.4.9 Quality gates + documentation
```

---

## Architectural boundary

The state model is not redesigned in Phase 2A.4.

```text
Observed State
    |
    | MonitorService
    v
Display UI
    |
    | edit through DisplayDraftStore
    v
Draft State
    |
    | MonitorApplyService
    v
Applied Runtime State
    |
    | DisplayPersistenceService
    v
Persistent State
```

These four states remain distinct.

The UI must never collapse observed state, draft state, temporary applied state,
and persistent state into one visual or mutation path.

---

## Ownership contract

### Main.qml

`Main.qml` remains the composition and orchestration root.

It owns:

```text
service composition
feature signal wiring
Control Center guards
output targeting
Safe Apply lifecycle integration
persistence lifecycle integration
```

Displays QML must not move those responsibilities into feature presentation
components.

### DisplayView.qml

`DisplayView.qml` owns feature-level presentation and composition only.

It may:

```text
compose Displays sections
show observed / draft / apply / persistence status
host topology and monitor editors
emit feature action signals
derive presentation strings from service state
```

Its existing action contract remains:

```text
refreshRequested()
resetRequested()
applyRequested()
keepRequested()
rollbackRequested()
saveRequested()
```

It must not:

```text
own a PanelWindow
spawn Process objects
call hyprctl directly
write monitors.lua directly
implement the Safe Apply watchdog
persist monitor configuration directly
```

The outer Control Center title and window chrome belong to
`ControlCenterShell.qml`; `DisplayView.qml` must not recreate a second
application-level shell.

### DisplayCard.qml

`DisplayCard.qml` owns the presentation and draft controls for one monitor.

It may derive choices from `DisplayDraftStore` and mutate draft state only
through the existing draft-store API.

The following mutation paths remain authoritative:

```text
setEnabled(...)
setResolution(...)
setRefreshMode(...)
setScale(...)
setTransform(...)
```

`DisplayCard.qml` must not apply runtime monitor configuration or persist
configuration.

### DisplayLayoutEditor.qml

`DisplayLayoutEditor.qml` owns interactive topology editing.

Its mutation boundary remains draft-only:

```text
snapPosition(...)
setPosition(...)
snapRelative(...)
```

Dragging, snapping, selection, overlap visualization, and relative positioning
may be redesigned visually without moving runtime apply logic into the editor.

### DisplayLayout.qml

The Phase 2A.4.5 usage audit confirmed that `DisplayLayout.qml` had no runtime
consumer. `DisplayView.qml` hosts `DisplayLayoutEditor.qml` directly, while the
remaining references to the read-only component were documentation and
validator bookkeeping.

`DisplayLayout.qml` is therefore retired in Phase 2A.4.5 rather than carrying
a second topology renderer with duplicated geometry and legacy visual tokens.

---

## Current visual debt

The audit identified Phase 1 visual compatibility still present in production
Displays UI:

```text
DisplayView
    raw outer Rectangle
    duplicate Displays-level header/chrome
    legacy Theme aliases and fallback literals
    ad-hoc feedback text/surfaces

DisplayCard
    JcCard root
    raw divider / status indicator rectangles
    ad-hoc typography
    ChoiceGroup-heavy mode controls

DisplayLayoutEditor
    legacy JcCard root
    raw canvas / monitor geometry
    legacy surface / border aliases
    hard-coded typography and fallback colors
```

Raw `Rectangle` remains valid for geometry-specific visuals such as monitor
topology nodes, canvas shapes, indicators, and custom drawing. It should not be
used as a replacement for canonical generic cards, dividers, buttons, or
standard semantic surfaces.

---

## Canonical component mapping

Phase 2A.4 should prefer the shared component library:

```text
generic feature surfaces       -> JcSurface
section headings               -> JcSectionHeader
structural separators          -> JcDivider
actions                        -> JcButton / JcIconButton
small semantic state           -> JcChip
boolean display state          -> JcToggle where keyboard contract is adequate
small finite option sets       -> JcChoiceGroup
large mode / refresh lists     -> JcComboBox
continuous numeric controls    -> JcSlider
```

Resolution and refresh-rate lists may contain many real monitor modes. They
should not be forced into an expanding chip grid merely to preserve the current
visual implementation.

`availableModes` remains the source of truth for actual modes.

---

## Accessibility contract

Phase 2A.4 must preserve the keyboard baseline established by Phase 2A.3.

Controls introduced into Displays must participate in predictable focus
traversal and expose visible semantic focus state.

Before using `JcToggle`, `JcChip`, or a `JcChoiceGroup` as a primary editable
control, their keyboard activation behavior must be validated and upgraded if
necessary.

Mouse-only production settings controls are not an acceptable final state.

---

## Safe Apply contract

Safe Apply behavior is invariant during the visual migration.

A draft may be presented differently, but the following behavioral rules stay
unchanged:

```text
only one monitor draft may be Safe Applied at a time
topology must be valid
observed state must not have changed underneath the draft
runtime apply is temporary until Keep
Rollback restores the previous runtime state
timeout rollback remains external to Quickshell
persistent monitors.lua is unchanged until explicit persistence
```

Animations must never delay, own, or gate the Safe Apply watchdog.

---

## Persistence contract

Persistence remains explicit and separate from Safe Apply.

The Displays UI may communicate persistence state more clearly, but saving
continues through `DisplayPersistenceService`.

The UI must preserve:

```text
canSave
saving / checking state
status feedback
error feedback
explicit Save Configuration action
```

No visual control may write `local/monitors.lua` directly.

---

## Visual target

The target information architecture is:

```text
Displays content
|
+-- Overview
|   +-- active / detected summary
|   +-- topology visualization
|   `-- current feature state
|
+-- Monitor settings
|   +-- monitor identity / role / state
|   +-- enabled state
|   +-- resolution
|   +-- refresh rate
|   +-- scale
|   `-- orientation
|
+-- Layout editor
|   +-- projected topology
|   +-- drag / snap interaction
|   `-- topology validation
|
`-- Apply and persistence feedback
    +-- draft state
    +-- Reset / Safe Apply
    +-- Keep / Rollback
    `-- Save Configuration
```

The shell already owns the application-level `Control Center / Displays`
header and generic footer. The redesigned feature content must complement that
chrome instead of duplicating it.

---

## Compatibility retirement rule

`JcCard` and the Phase 1 Theme aliases remain temporary compatibility surfaces
while the Displays migration is in progress.

They are not the target API for new Phase 2A.4 production UI.

Phase 2A.4.7 may retire them only after:

```text
no production Displays component depends on JcCard
no production Displays component depends on retired Theme aliases
the Component Gallery and component documentation are updated
validators no longer require the legacy compatibility boundary
all runtime and visual gates pass
```

Compatibility is removed deliberately, not through a blind repository-wide
replacement.

---

## Non-goals

Phase 2A.4 does not:

```text
rewrite MonitorService
rewrite DisplayDraftStore
rewrite MonitorApplyService
rewrite DisplayPersistenceService
change the external Safe Apply watchdog
change monitors.lua persistence semantics
change the generic controlCenter IPC
change jc-control-center
change ControlCenterShell ownership
restart or couple wallpaper management to display apply
hardcode monitor modes instead of using availableModes
```

---

## Exit criteria

Phase 2A.4 is complete only when:

```text
Displays uses the canonical Phase 2 component vocabulary
duplicate feature-level shell chrome is removed
monitor settings remain fully functional
topology editing remains fully functional
Safe Apply timeout / Keep / Rollback remain validated
persistence remains explicit and validated
keyboard traversal is complete
responsive layout is validated on the supported display roles
production Displays no longer depends on the visual compatibility layer
quality gates and documentation are green
```


---

## Phase 2A.4.2 — DisplayView shell/content cleanup

`DisplayView.qml` is a hosted feature view. It no longer recreates the
application-level Control Center surface or repeats the `Displays` title owned
by `ControlCenterShell.qml`.

This step deliberately preserves the feature contract:

```text
refreshRequested()
resetRequested()
applyRequested()
keepRequested()
rollbackRequested()
saveRequested()

DisplayLayoutEditor
DisplayCard repeater
Safe Apply feedback and actions
persistence feedback and Save Configuration
```

The feature root now composes directly into the shell content host. Generic
separation uses `JcDivider`, and `DisplayView`-owned spacing and typography use
the canonical Phase 2 Theme tokens.

The old user-visible implementation badge `Phase 1C.3 · Persistent Save` is
removed. Persistence behavior is unchanged.

Safe Apply feedback surfaces, monitor cards, mode controls, and the layout
editor remain intentionally unchanged here. Their visual migrations belong to
later Phase 2A.4 steps.


---

## Phase 2A.4.3 — DisplayCard canonical surface migration

`DisplayCard.qml` now uses the Phase 2 semantic component vocabulary for its
card-level presentation.

The card root is `JcSurface` with the `raised` semantic role. Generic
separation uses `JcDivider`; spacing, typography, and colors use canonical
Theme tokens rather than Phase 1 aliases or literal fallbacks.

The small focused-monitor dot remains a raw `Rectangle` intentionally because
it represents monitor-specific geometry rather than a reusable generic surface.

The draft mutation boundary remains unchanged:

```text
setEnabled(...)
setResolution(...)
setRefreshMode(...)
setScale(...)
setTransform(...)
```

The four existing `JcChoiceGroup` controls are deliberately preserved in this
step. Resolution, refresh rate, scale, and orientation control strategy belongs
to Phase 2A.4.4 and must be evaluated separately from the card-surface
migration.

No runtime apply or persistence responsibility is added to `DisplayCard.qml`.


---

## Phase 2A.4.4 — Mode, scale, and transform controls

Display settings now use controls according to the shape of their data rather
than forcing every option set through the same visual primitive:

```text
Resolution     -> JcComboBox
Refresh rate   -> JcComboBox
Scale          -> JcSlider
Orientation    -> JcComboBox
```

Resolution and refresh rate can grow with the real mode list exposed by the
monitor backend. Their option builders remain backed by parsed
`availableModes`; the UI does not manufacture unsupported hardware modes.

Scale is a numeric setting, so it is presented as a `JcSlider`. The slider
does not invent arbitrary scale values: it snaps by index across the validated
options returned by `scaleOptionsFor(...)` and sends the selected option back
through `setScale(...)`.

Orientation can expose up to eight transform states, including flipped
variants, so it is presented as a `JcComboBox` rather than a row of selection
buttons. Resolution, refresh rate, and orientation therefore use compact
keyboard-accessible combo boxes, while scale uses the canonical numeric
slider.

The draft mutation boundary remains unchanged:

```text
setResolution(...)
setRefreshMode(...)
setScale(...)
setTransform(...)
```

This step changes presentation and keyboard interaction only. It does not
change Safe Apply, persistence, topology, monitor discovery, or mode parsing.


---

## Phase 2A.4.5 — Layout editor visual integration

`DisplayLayoutEditor.qml` now uses the canonical visual platform while keeping
the topology model and mutation boundary unchanged.

```text
editor shell            -> JcSurface (raised)
section heading         -> JcSectionHeader
topology status         -> success / danger semantic tokens
canvas                  -> raw Rectangle (geometry-specific)
monitor nodes           -> raw Rectangle (geometry-specific)
reference display       -> JcComboBox
relative positioning    -> JcButton
```

The canvas and monitor rectangles are intentionally retained because they
represent topology geometry rather than generic application surfaces. Their
colors, borders, spacing, radius, and typography now come from semantic Theme
tokens.

The interaction boundary is unchanged:

```text
projectedMonitors()
outputHasOverlap(...)
snapPosition(...)
setPosition(...)
snapRelative(...)
topologyValid
```

Dragging still commits only to draft position state. Relative placement still
delegates to `snapRelative(...)`; runtime apply, Safe Apply confirmation, and
persistence remain outside the layout editor.

The usage audit also confirmed that `DisplayLayout.qml` had no runtime
consumer. It is retired in this phase to avoid maintaining two independent
topology renderers.
