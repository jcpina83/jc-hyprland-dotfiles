# Control Center Shell Architecture

Phase 2A.3 established a reusable Control Center shell around the existing
Displays feature without changing the proven display runtime, Safe Apply, or
persistence architecture.

The phase began by defining the architecture and navigation contract, then
incrementally promoted that contract into the production Quickshell shell.

---

## Design goal

External desktop integrations should open a Control Center, not know which
feature module owns the window.

```text
Waybar / SUPER+C
       |
       v
jc-control-center
       |
       v
stable Control Center IPC
       |
       v
Main.qml
       |
       v
ControlCenterShell
       |
       +-- Navigation
       +-- Header
       +-- Content host
       +-- Global status/actions
              |
              v
          feature module
```

The shell is presentation and navigation infrastructure. It is not a runtime
backend.

---

## Ownership model

`Main.qml` remains the composition and orchestration root.

It owns:

```text
Control Center visibility
active module id
requested output
feature services
Safe Apply / persistence guards
generic Control Center IPC
```

`ControlCenterShell.qml` owns:

```text
PanelWindow presentation
responsive geometry
navigation presentation
header / footer presentation
content host
close / navigation request signals
```

Feature modules own their own UI and feature-specific state composition.

Runtime services and scripts continue owning external mutation and persistence.

---

## Target structure

```text
config/quickshell/jc-hyprland/
├── Main.qml
├── components/
├── modules/
│   ├── controlcenter/
│   │   ├── ControlCenterShell.qml
│   │   └── ControlCenterNavigation.qml
│   ├── displays/
│   │   ├── DisplayView.qml
│   │   └── ...
│   └── dev/
│       └── ComponentGallery.qml
├── services/
└── theme/
```

`DisplayView.qml` contains the Displays feature content and is hosted by the
generic `ControlCenterShell` content loader. The Displays module does not own a
`PanelWindow`.

This is a structural migration, not the Phase 2A.4 visual redesign.

---

## Navigation contract

Canonical module ids:

```text
displays
wallpapers
themes
quick-settings
performance
media
network
notifications
```

At the completion of Phase 2A.3, `displays` is the only fully operational module.

Future module entries may be visible but disabled until their implementation
phase is reached.

The active module is controlled state owned by `Main.qml`.

The shell emits a request:

```qml
signal moduleRequested(string moduleId)
```

and does not silently change feature state by itself.

---

## Safe transition contract

Displays already has destructive / reversible operations with confirmation and
persistence state.

Therefore shell transitions must preserve these guards.

While either condition is true:

```text
MonitorApplyService.pendingConfirmation
DisplayPersistenceService.saving
```

the Control Center must not:

```text
hide
switch away from Displays
move to the development gallery
discard DisplayDraftStore state
```

A normal module switch may reset feature draft state only when that feature's
existing close semantics allow it.

For Displays, the existing reset behavior remains owned by the orchestration
path rather than the shell presentation component.

---

## Output targeting

Output targeting remains a Control Center concern.

The requested output is resolved in `Main.qml` and passed to the shell as a
screen object.

```text
Waybar MAIN button
    -> toggle-on MAIN_OUTPUT
    -> target MAIN screen

Waybar SECONDARY button
    -> toggle-on SECONDARY_OUTPUT
    -> target SECONDARY screen

SUPER+C
    -> current focused-output behavior
```

Opening the shell on another output should re-target the existing Control
Center instance rather than create a second production shell.

The Component Gallery remains a separate development window.

---

## IPC evolution

The canonical IPC target remains:

```text
controlCenter
```

The generic Control Center IPC surface is:

```text
showControlCenter()
showControlCenterOn(outputName)
toggleControlCenter()
toggleControlCenterOn(outputName)
hideControlCenter()
refreshControlCenter()
controlCenterIsVisible()
showModule(moduleId)
```

The public Control Center IPC contract is generic and module-independent:

```text
showControlCenter()
showControlCenterOn(outputName)
toggleControlCenter()
toggleControlCenterOn(outputName)
hideControlCenter()
controlCenterIsVisible()
```

Their future behavior becomes conceptually:

```text
showControlCenter()
    -> show Control Center
    -> select module "displays"
```

This allows the existing `jc-control-center` wrapper, Waybar configuration and
Hyprland keybind to remain stable while internals evolve.

---

## Stable runtime wrapper contract

The public wrapper actions remain stable while internal Control Center modules evolve:

```text
jc-control-center show
jc-control-center show-on <output>
jc-control-center hide
jc-control-center toggle
jc-control-center toggle-on <output>
jc-control-center refresh
jc-control-center status
```

No Waybar or Hyprland consumer should call raw Quickshell implementation details
when the wrapper already provides the required operation.

The wrapper may be redirected to generic IPC only after the generic IPC is
runtime-validated.

---

## Component Gallery boundary

`ComponentGallery.qml` is not a production module.

It remains available through development IPC:

```text
showGallery
hideGallery
toggleGallery
galleryIsVisible
```

It must remain mutually exclusive with the production Control Center shell.

Gallery behavior must never weaken Safe Apply or persistence guards.

---

## Content-host contract

The shell must expose a generic content boundary rather than import Displays
logic directly.

Conceptually:

```text
ControlCenterShell
    |
    +-- navigation
    +-- header
    +-- content host <--- Main.qml composes active feature content here
    +-- footer/status
```

This keeps:

```text
shell -> generic presentation
Main  -> composition
module -> feature UI
service -> state / backend orchestration
```

and prevents the shell from becoming a feature-specific monolith.

---

## Phase 2A.3 sequence

```text
2A.3.1 Shell architecture + navigation contract              ✓
2A.3.2 Shell frame + responsive geometry                     ✓
2A.3.3 Navigation sidebar / rail                             ✓
2A.3.4 Modular content host + Displays view extraction       ✓
2A.3.5 Generic IPC consolidation                             ✓
2A.3.6 Header / footer + guarded transitions                 ✓
2A.3.7 Focus, keyboard, motion and visual validation         ✓
2A.3.8 Quality gates + documentation                         ✓
```

Phase 2A.4 is the next phase and performs the actual Displays visual redesign.

---

## Non-goals for Phase 2A.3

Do not:

- change `MonitorService` semantics,
- change `DisplayDraftStore` state ownership,
- change Safe Apply behavior,
- change rollback watchdog behavior,
- change persistent `monitors.lua` handling,
- redesign monitor cards or topology controls,
- couple the shell directly to shell commands,
- replace the stable runtime wrapper contract.

Those boundaries are already validated and must remain intact.


## Phase 2A.3.6 — Header, footer and guarded transitions

The production shell exposes generic presentation state for transition safety:

- `transitionLocked`
- `statusText`
- `statusDetail`
- `activeModuleTitle`

`Main.qml` remains responsible for translating feature-specific runtime state
into those generic shell properties. `ControlCenterShell.qml` does not depend
directly on display services.

While a guarded operation is active, closing the Control Center, leaving the
current module, and opening the development gallery are blocked. The shell
reflects the lock state in the close action, navigation, and footer status.

The production header identifies the active module instead of exposing
development-phase copy. The footer communicates ready, draft, apply,
confirmation, and persistence state without owning feature mutation logic.


### Phase 2A.3.7a — Initial focus and keyboard baseline

When the production Control Center becomes visible, focus is placed on the
active enabled navigation item. The shell requests focus through the navigation
component instead of depending on a feature module implementation.

The shared `JcButton` and `JcIconButton` primitives participate in keyboard
focus traversal, render the semantic focus ring, and activate with Enter,
Return, or Space. Pointer presses also transfer active focus to the control.

This establishes the keyboard baseline before directional navigation and shell
motion are added in later Phase 2A.3.7 steps.


### Phase 2A.3.7b — Directional navigation semantics

The vertical module rail supports keyboard-local directional navigation without
changing the global Tab order:

- Up moves focus to the previous enabled module.
- Down moves focus to the next enabled module.
- Home focuses the first enabled module.
- End focuses the last enabled module.
- Enter, Return, and Space continue to activate the focused module.
- Tab and Shift+Tab remain available for global Control Center focus traversal.

Directional focus skips disabled modules and wraps for Up/Down. If only one
module is enabled, directional keys keep focus on that module. Transition locks
are respected because navigation only targets delegates whose
`controlEnabled` state is true.


### Phase 2A.3.7c — Shell and module motion

Control Center motion uses the semantic motion tokens from `Theme.qml` and is
kept intentionally lightweight:

- opening the shell fades and scales the centered visual surface by a subtle amount;
- loading or changing the hosted module fades and translates the content;
- footer status changes use a short opacity/color transition;
- navigation selection continues to use the motion already provided by
  `JcNavItem`.

The `PanelWindow` geometry itself is not animated. The centered shell surface
uses opacity and scale only; hosted module content may continue to use a small
QML `Translate` transform without transferring geometry ownership away from
layouts.

Closing uses the matching opacity/scale exit motion. `ControlCenterShell`
keeps the `PanelWindow` mounted until that presentation animation completes,
while guarded transitions remain unchanged. Display Safe Apply, persistence,
and feature mutation services do not depend on animation completion.


---

## Phase 2A.3 completion status

Phase 2A.3 is complete.

The production Control Center now has:

```text
stable desktop wrapper
        |
        v
generic controlCenter IPC
        |
        v
Main.qml
  |-- lifecycle / output targeting
  |-- active module state
  |-- guarded transitions
  `-- feature service composition
        |
        v
ControlCenterShell
  |-- header
  |-- ControlCenterNavigation
  |-- generic content host
  `-- footer / status
        |
        v
feature module
        |
        `-- DisplayView
```

Validated behavior includes responsive geometry, stable output targeting,
generic IPC routing, guarded Safe Apply transitions, keyboard focus traversal,
directional module navigation, semantic focus rings, lightweight shell motion,
and real-host runtime validation.

`ControlCenterShell.qml` is the only production Control Center `PanelWindow`.
`ComponentGallery.qml` remains a separate development-only `PanelWindow`.

Phase 2A.4 is next. It will migrate the current Displays visual layer to the
shared component library while preserving observed, draft, runtime, and
persistent state boundaries.


---

### H1.3.5 — Centered Control Center presentation

The JC Holo presentation layer promotes the production Control Center from the
former top-right sidebar treatment to a centered HUD/modal presentation on the
resolved target output.

Presentation ownership remains split cleanly:

```text
Main.qml
    |
    | requestedVisible
    v
ControlCenterShell
    |-- presentationScreen
    |-- mounted lifecycle
    |-- fade + scale enter
    `-- fade + scale exit
```

`requestedVisible` expresses application intent, while `mounted` keeps the
`PanelWindow` alive long enough for exit motion to finish. The active target
screen is frozen in `presentationScreen` during close so the shell cannot jump
between outputs while disappearing.

The centered presentation intentionally retires the old top/right anchoring and
the shell-level `Translate` slide. Hosted module motion and all display runtime,
Safe Apply, rollback, and persistence ownership remain unchanged.

### Content viewport ownership

The production `ControlCenterShell.qml` owns the geometric boundary between
hosted module content and the footer/status area.

`contentHost` clips hosted rendering to the space allocated by the shell
layout. Feature modules may use internal scrolling or flexible children, but
they must not extend their drawing underneath the footer divider or status row.

This keeps footer separation a shell invariant instead of requiring each
feature view to add compensating bottom margins. Wallpapers uses that contract
by allowing its gallery surface and first-row tile height to shrink with the
available viewport while retaining the existing `GridView` scrolling behavior.
