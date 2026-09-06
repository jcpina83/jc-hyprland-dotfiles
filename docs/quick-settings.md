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
