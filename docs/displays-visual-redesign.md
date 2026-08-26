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
2A.4.2 DisplayView shell/content cleanup                   ← CURRENT
2A.4.3 DisplayCard migration to canonical components
2A.4.4 Mode / scale / transform controls
2A.4.5 Layout editor visual integration
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

`DisplayLayout.qml` is part of the current Displays module tree and represents
the read-only topology visualization surface.

Phase 2A.4.5 must resolve its final visual role and confirm tracked runtime
usage before it is removed, merged, or repurposed. It must not be deleted only
because the editable topology view exists.

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

DisplayLayout
    JcCard root
    raw topology rectangles
    legacy surface / border aliases

DisplayLayoutEditor
    JcCard root
    raw canvas / monitor rectangles
    legacy surface / border aliases
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
