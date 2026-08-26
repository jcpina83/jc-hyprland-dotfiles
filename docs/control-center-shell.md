# Control Center Shell Architecture

Phase 2A.3 turns the current display-specific popup entry point into a reusable
Control Center shell without changing the proven display runtime, Safe Apply or
persistence architecture.

Phase 2A.3.1 defines the architecture and navigation contract before the shell
QML is implemented.

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
IPC compatibility
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

During Phase 2A.3 only `displays` is required to be fully operational.

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

Phase 2A.3 will add generic methods:

```text
showControlCenter()
showControlCenterOn(outputName)
toggleControlCenter()
toggleControlCenterOn(outputName)
hideControlCenter()
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

## Runtime wrapper compatibility

The public wrapper actions remain stable during Phase 2A.3:

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
2A.3.1 Shell architecture + navigation contract
2A.3.2 Shell frame + responsive geometry
2A.3.3 Navigation sidebar / rail
2A.3.4 Modular content host + Displays structural adapter
2A.3.5 Generic IPC consolidation
2A.3.6 Header / footer + guarded transitions
2A.3.7 Focus, keyboard, motion and visual validation
2A.3.8 Quality gates + documentation
```

Phase 2A.4 follows with the actual Displays visual redesign.

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
