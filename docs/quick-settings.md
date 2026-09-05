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
