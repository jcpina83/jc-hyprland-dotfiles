# Quick Settings Control

## Phase 2D.1a — Stable runtime API

Phase 2D begins with the runtime boundary rather than presentation QML.

The stable public command is:

```text
jc-quick-settings
```

The initial machine-readable surface is:

```bash
jc-quick-settings status --json
jc-quick-settings dnd status --json
jc-quick-settings dnd on --json
jc-quick-settings dnd off --json
```

`status --json` reports observed capability state for:

- Do Not Disturb through SwayNC;
- Lock through the existing `lock-session.sh` boundary;
- Night Light capability discovery through `hyprsunset`;
- Suspend through the existing `suspend-session.sh` boundary.

Phase 2D.1a mutates **only DND**. Lock, Suspend and Night Light are discovery
capabilities in this phase.

## DND semantics

DND uses deterministic SwayNC commands:

```text
swaync-client --get-dnd
swaync-client --dnd-on
swaync-client --dnd-off
```

The public API deliberately does not use toggle semantics for QML-facing
mutation. A caller requests the desired boolean state, and the runtime boundary
verifies the observed state before reporting success.

Successful mutation JSON has:

```json
{
  "schemaVersion": 1,
  "status": "applied",
  "capability": "dnd",
  "requested": true,
  "enabled": true,
  "verified": true,
  "changed": true,
  "backend": "swaync-client"
}
```

`changed=false` is a valid successful no-op when observed state already equals
the requested state.

Exit codes:

```text
0  success
2  invalid usage
3  capability unavailable
4  backend mutation failed
5  post-mutation verification failed
```

## Observed state versus actions

Quick Settings intentionally does **not** copy the Wallpapers/Themes
DraftStore + global Apply model.

Its Phase 2D ownership model is:

```text
presentation
    -> observed QuickSettingsService
    -> immediate QuickSettingsActionService
    -> jc-quick-settings
    -> dedicated desktop backends
```

There is no global Quick Settings draft and no global Apply button.

The QML service/action layers are introduced after this public API is validated.

## Night Light boundary

`hyprsunset` is the preferred Hyprland-native Night Light backend.

Phase 2D.1a only discovers whether it is present and running. It does not install,
start or mutate `hyprsunset`, and reports:

```text
managed=false
enabled=null
```

until Phase 2D.2 defines the portable lifecycle and state contract.

## Session action boundary

Phase 2D may surface Lock as a quick action because the project already owns a
stable `lock-session.sh` wrapper.

The complete power/session surface remains reserved for Phase 2H. Quick Settings
must not become a second owner for logout, reboot or shutdown UI.

Suspend is exposed only as capability discovery in Phase 2D.1a.

## Presentation boundary

Phase 2D.1a creates no `QuickSettingsView`, no `QuickSettingsService`, and no
`QuickSettingsActionService`.

`quick-settings` remains disabled in the Control Center navigation until the
observed/action services and module foundation exist.

## Phase 2D.1b — Observed-state service

`QuickSettingsService.qml` is the read-only QML projection of:

```bash
jc-quick-settings status --json
```

The service owns these observed domains:

```text
DND
  available
  backendInstalled
  running
  enabled
  backend

Lock
  available
  backend

Night Light
  available
  running
  managed
  enabled
  backend

Suspend
  available
  backend
```

It also exposes the standard service lifecycle:

```text
loading
ready
errorMessage
lastRefresh
refreshed()
refreshFailed(message)
refresh()
```

The service validates the complete schema before committing an observed
snapshot. Consumers therefore never receive a partially updated Quick Settings
state.

`Main.qml` owns one `QuickSettingsService` instance and exposes an explicit
`quickSettingsServiceHandle` for future dynamically-instantiated Quick Settings
views.

### Read-only boundary

`QuickSettingsService` may invoke only:

```text
jc-quick-settings status --json
```

It must not invoke:

```text
jc-quick-settings dnd on
jc-quick-settings dnd off
swaync-client
hyprsunset
lock-session.sh
suspend-session.sh
systemctl
```

Those operations belong outside the observed-state service.

The `quick-settings` navigation item remains disabled in Phase 2D.1b. The
module is enabled only after the action service and presentation foundation are
both available.

## Phase 2D.1c — Immediate DND action service

`QuickSettingsActionService.qml` is the QML mutation boundary for the first
Quick Settings action: Do Not Disturb.

Its public runtime calls are limited to deterministic desired-state commands:

```bash
jc-quick-settings dnd on --json
jc-quick-settings dnd off --json
```

The QML service never calls `swaync-client` directly and never owns SwayNC
lifecycle. The stable runtime API remains responsible for backend mutation and
post-mutation verification.

The action lifecycle is:

```text
validate observed capability
        ↓
request explicit DND on/off
        ↓
validate mutation JSON
        ↓
QuickSettingsService.refresh()
        ↓
verify observed dndEnabled == requested state
        ↓
dndApplied(desiredEnabled, stateChanged)
```

`changed=false` is a successful no-op. It means the observed state already
matched the requested desired state.

The service exposes:

```text
quickSettingsService

applyingDnd
awaitingRefresh
busy
canSetDnd

errorMessage
statusMessage
lastResult

setDndEnabled(desiredEnabled)
clearTransientFeedback()

dndApplied(desiredEnabled, stateChanged)
failed(message)
```

Both successful and failed runtime requests are followed by observed-state
reconciliation whenever possible. This prevents the presentation layer from
assuming that a command result alone is the current desktop state.

`Main.qml` owns one `QuickSettingsActionService`, injects the existing
`QuickSettingsService`, exposes `quickSettingsActionServiceHandle`, and includes
the action service in the Control Center transition lock while it is busy.

Phase 2D.1c intentionally does not add Lock, Suspend, Night Light, a global
Quick Settings draft, or a global Apply button.

The `quick-settings` navigation item remains disabled until the module
presentation foundation is introduced.

## Phase 2D.1d — Quick Settings view foundation

`QuickSettingsView.qml` introduces the first production presentation surface
for Phase 2D and enables the `quick-settings` Control Center navigation entry.

The presentation contract remains layered:

```text
QuickSettingsView
        |
        +--> QuickSettingsService
        |      observed state
        |
        +--> QuickSettingsActionService
               immediate DND intent
                    |
                    v
              jc-quick-settings
```

The view contains no `Process` object and no backend command ownership.

### First interactive control

Do Not Disturb is the only mutable control in this foundation.

The view emits:

```text
dndRequested(enabled)
```

and `Main.qml` delegates that intent to:

```qml
quickSettingsActionService.setDndEnabled(enabled)
```

The toggle is bound to `QuickSettingsService.dndEnabled`, so presentation state
comes from the observed desktop snapshot rather than an optimistic local copy.

While the action service is applying or reconciling, the DND tile and toggle
are disabled by `QuickSettingsActionService.canSetDnd`.

### Observed-only capabilities

Lock, Night Light and Suspend are displayed only as discovered capabilities in
Phase 2D.1d. The view does not expose actions for them yet.

Night Light mutation and lifecycle belong to Phase 2D.2. Session-oriented
actions remain separately scoped.

### Control Center integration

Phase 2D.1d adds:

```text
prepareQuickSettings()
shellQuickSettingsComponent
Quick Settings active-module title
Quick Settings content routing
Quick Settings status text/detail
refreshControlCenter() routing
```

The navigation entry changes from disabled to enabled only after both the
observed-state service and DND action service have already been committed and
runtime-tested.

### 2D.1d visual-gate correction

The manual visual gate identified two presentation regressions before commit:

- the long `Do Not Disturb` label did not fit the fixed-width
  `JcSettingTile`, so the compact tile now uses `DND` while the full label
  remains in the descriptive text column;
- `ThemeView.qml` had drifted from the HUD framing used by Displays and
  Wallpapers, so its main header/action area and theme gallery are again
  framed with `JcHudFrame`.

Quick Settings also uses HUD framing for its DND and observed-capability
surfaces, and the Refresh action is explicitly vertically aligned.

These corrections are presentation-only. DND still flows through
`QuickSettingsActionService`, and Theme draft/apply/recovery behavior is
unchanged.

### 2D.1d observed capability tiles

The visual gate confirmed that capability discovery alone was insufficient:
Lock, Night Light and Suspend existed only as summary text and were not
recognizable as Quick Settings options.

`QuickSettingsView.qml` now renders three explicit, equal-width
`JcSettingTile` capability options:

- Lock
- Night Light
- Suspend

Each tile displays its observed availability below the control. The tiles
remain intentionally read-only in Phase 2D.1d; this makes the future controls
visible without bypassing the planned action-service/runtime boundaries.

## Phase 2D.2 — Night Light / hyprsunset

Phase 2D.2 promotes Night Light from observed-only discovery to an immediate,
verified Quick Settings action.

### Stable runtime API

```bash
jc-quick-settings night-light status --json
jc-quick-settings night-light on --json
jc-quick-settings night-light off --json
```

The backend remains entirely behind `jc-quick-settings`.

```text
QuickSettingsView
        |
        | nightLightRequested(bool)
        v
QuickSettingsActionService
        |
        | jc-quick-settings night-light on|off --json
        v
jc-quick-settings
        |
        +--> systemctl --user start hyprsunset.service
        +--> hyprctl hyprsunset temperature 4500
        +--> hyprctl hyprsunset identity false|true
        |
        v
QuickSettingsService.refresh()
```

Presentation QML never invokes `hyprctl`, `systemctl` or `hyprsunset`
directly.

### Deterministic state

Hyprsunset 0.4 exposes identity state through:

```bash
hyprctl hyprsunset identity get
```

The stable adapter interprets:

- `identity=false` as Night Light **on**;
- `identity=true` as Night Light **off**;
- an inactive `hyprsunset.service` as Night Light **off**.

The target ON temperature for this phase is `4500 K`. OFF restores the neutral
identity matrix rather than approximating neutral output with a high color
temperature.

The service is started on demand but is not enabled automatically. This avoids
an unexpected filter during login and keeps Quick Settings responsible for
explicit session intent.

### Mutation response

A successful mutation follows the same verification shape as DND:

```json
{
  "schemaVersion": 1,
  "status": "applied",
  "capability": "night-light",
  "requested": true,
  "enabled": true,
  "verified": true,
  "changed": true,
  "available": true,
  "running": true,
  "managed": true,
  "targetTemperature": 4500,
  "backend": "hyprsunset"
}
```

`changed=false` is a valid verified no-op.

### UI behavior

The existing Night Light capability tile becomes interactive. Its selected
state always comes from `QuickSettingsService.nightLightEnabled`; the view does
not keep an optimistic local copy.

`QuickSettingsActionService` serializes DND and Night Light through its shared
`busy` boundary. After every Night Light request it refreshes observed state
before declaring success.

Lock and Suspend remain observed-only for the next session-actions subphase.

### Distribution portability

`hyprsunset` is added to `distros/arch/packages.txt`; Garuda inherits the Arch
package installer.

The openSUSE package manifest is intentionally unchanged until equivalent
package availability and lifecycle have been validated on openSUSE. Runtime
discovery remains graceful when the backend is unavailable.

## Phase 2D.3a — Lock quick action

Lock is promoted from capability discovery to a one-shot Quick Settings action.

### Stable runtime API

```bash
jc-quick-settings lock --json
```

The runtime adapter resolves the existing managed `lock-session.sh` wrapper,
launches it detached, and verifies that `hyprlock` becomes observable before
returning success.

A successful response is:

```json
{
  "schemaVersion": 1,
  "status": "applied",
  "capability": "lock",
  "available": true,
  "running": true,
  "verified": true,
  "changed": true,
  "backend": "lock-session.sh"
}
```

`changed=false` is a valid verified no-op when Hyprlock is already active.

The presentation boundary remains:

```text
QuickSettingsView
        |
        | lockRequested()
        v
Main.qml
        |
        | request Control Center close
        v
ControlCenterShell
        |
        | await mounted=false
        v
QuickSettingsActionService.lockSession()
        |
        | jc-quick-settings lock --json
        v
jc-quick-settings
        |
        v
lock-session.sh
        |
        v
hyprlock
```

Neither `QuickSettingsView.qml` nor `QuickSettingsActionService.qml` owns
Hyprlock commands or wrapper paths.

Lock is intentionally modeled as an action, not a toggle. There is no draft,
Apply workflow or optimistic locked-state model in QML.

The Lock handoff also distinguishes the logical close request from physical
presentation teardown: `Main.qml` requests the Control Center to close and
waits for `controlCenterShell.mounted === false` before invoking
`QuickSettingsActionService.lockSession()`. No fixed sleep or animation
duration is used.

Suspend is promoted to an action in Phase 2D.3b because validating Suspend
requires an explicit real sleep/resume gate.

## Phase 2D.3b — Suspend quick action

Suspend is promoted from capability discovery to a one-shot Quick Settings
action while preserving the existing managed boundary:

```text
QuickSettingsView
        |
        | suspendRequested()
        v
Main.qml
        |
        | close Control Center
        v
ControlCenterShell
        |
        | await mounted=false
        v
QuickSettingsActionService.suspendSession()
        |
        | jc-quick-settings suspend --json
        v
jc-quick-settings
        |
        | detached handoff
        v
suspend-session.sh
        |
        | existing input-settle delay
        v
systemctl suspend
```

The stable runtime response uses acceptance semantics:

```json
{
  "schemaVersion": 1,
  "status": "accepted",
  "capability": "suspend",
  "available": true,
  "accepted": true,
  "handoffVerified": true,
  "backend": "suspend-session.sh"
}
```

`handoffVerified=true` means the managed detached wrapper process was created
successfully. It does **not** claim that the later system sleep or resume cycle
has already been verified. The CLI returns before the machine enters sleep so
QML can consume a complete response first.

Suspend uses the same presentation-order rule established by Lock:
`Main.qml` waits for `controlCenterShell.mounted === false` before delegating the
runtime action. Presentation QML contains no direct session backend commands and
uses no fixed animation sleep.

Logout, reboot and shutdown remain outside this Quick Settings subphase.

## Phase 2D.4 — Visual, keyboard and icon polish

Phase 2D.4 is presentation-only polish over the completed immediate-action
contracts. It does not change the stable runtime API, observed-state service,
action service, Lock ordering or Suspend ordering.

The final Quick Settings icon treatment is intentionally hybrid:

- DND uses the dedicated semantic `dnd` vector icon;
- Night Light uses a dedicated `night-light` vector icon combining sun and crescent moon geometry;
- Lock uses a dedicated closed-padlock `lock` vector icon;
- Suspend keeps the established `power` icon for the same visual reason.

The generic `notifications`, `settings` and `theme` mappings are replaced for DND, Lock and Night Light respectively.

The action surface is titled **Quick actions** rather than **Observed
capabilities**, because DND, Night Light, Lock and Suspend are all interactive
at this phase.

Keyboard activation continues to use the canonical `JcSettingTile` contract:
Return, Enter and Space activate the focused tile. Phase 2D.4 adds explicit
directional focus navigation between the DND tile and the Lock / Night Light /
Suspend row while preserving normal Tab traversal.

The visual layer remains backend-neutral. `QuickSettingsView.qml` owns no
SwayNC, Hyprsunset, Hyprlock, systemd, loginctl or stable-CLI command details.

## Phase 2D.5 — Runtime E2E and formal closure

Phase 2D.5 completes the Quick Settings track with a clean cold-runtime
end-to-end validation over the final Phase 2D implementation.

The closure gate verified:

- the stable `jc-quick-settings` status contract and all four capabilities;
- managed executable wrappers for Lock and Suspend;
- a clean Quickshell cold start;
- Control Center routing to Quick Settings;
- observed-state refresh behavior;
- reversible DND mutation through the UI, with the original state restored;
- reversible Night Light mutation through the UI at the managed 4500 K target,
  with the original state restored;
- Lock and Suspend visual/availability non-regression;
- Control Center close/reopen lifecycle;
- Quickshell, SwayNC and Hyprland runtime health;
- final stable API state;
- no repository mutation during the E2E gate.

Lock and Suspend were intentionally **not executed again** during Phase 2D.5.
Their one-shot action paths were already validated in Phase 2D.3. Suspend also
has a separately diagnosed platform deep/S3 xHCI/Bluetooth resume issue, which
is outside the Quick Settings implementation and must remain a separate track.

### Final Phase 2D architecture

```text
QuickSettingsView
        |
        +--> QuickSettingsService
        |      observed state
        |
        +--> QuickSettingsActionService
               immediate intent
                    |
                    v
          jc-quick-settings
                    |
        +-----------+-----------+-------------+
        |           |           |             |
      SwayNC     Hyprlock   hyprsunset      systemd
       DND         Lock     Night Light      Suspend
```

The presentation layer remains backend-neutral. DND and Night Light are
reversible immediate controls; Lock and Suspend remain one-shot session
actions. No global DraftStore or Apply workflow is introduced for Quick
Settings.

### Phase status

**Phase 2D — Quick Settings: CLOSED**

Completed scope:

- 2D.1a — stable runtime API;
- 2D.1b — observed-state QML service;
- 2D.1c — DND action service;
- 2D.1d — Quick Settings view foundation;
- 2D.2 — Night Light;
- 2D.3 — Lock and Suspend session quick actions;
- 2D.4 — visual, keyboard and icon polish;
- 2D.5 — runtime E2E and formal closure.

Additional session actions such as Logout, Reboot or Shutdown are not part of
Phase 2D. Broader Notifications / Calendar / Power capabilities remain deferred
to their later planned phase rather than expanding this closed Quick Settings
scope.
