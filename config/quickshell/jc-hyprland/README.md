# JC Hyprland Quickshell

Custom Quickshell control-center implementation for `jc-hyprland-dotfiles`.

## Current milestone

### Phase 1B.6 — Enable / Disable Monitors

The display module now supports draft/runtime control for:

- resolution,
- refresh rate,
- scale,
- transform / orientation,
- visual logical position,
- enabled / disabled state.

Persistence to `local/monitors.conf` is still intentionally deferred.

## Important Hyprland semantic

Disabling a monitor is **not** DPMS.

Hyprland removes a disabled monitor from the virtual layout and moves its
windows/workspaces to remaining outputs.

The runtime rule is:

```lua
hl.monitor({
    output = "...",
    disabled = true
})
```

For this reason, disable is protected by the same Safe Apply transaction used
for geometry changes.

## Safety guards

Phase 1B.6 refuses to disable:

1. the last active monitor,
2. the currently focused monitor.

The focused-monitor rule is intentionally conservative because the Control
Center follows the focused output. Focus another monitor before disabling the
current one.

The backend repeats these checks using live `hyprctl -j monitors all` data, so
the UI is not the only safety boundary.

## Draft model

Each display draft now includes:

```text
enabled
mode
refresh
scale
transform
x
y
```

Observed, draft, temporary runtime and persistent states remain separate.

```text
Observed state
      │
      ▼
DisplayDraftStore
      │
      ├── enabled
      ├── mode
      ├── scale
      ├── transform
      └── x/y
      │
      ▼
Safe Apply
      │
      ▼
Temporary runtime
```

## Disabled monitor discovery

The project continues to use:

```bash
hyprctl -j monitors all
```

rather than `hyprctl -j monitors`, because `monitors all` retains inactive /
disabled outputs.

A disabled output can therefore remain visible as a card in the Control Center
and be enabled again.

If Hyprland does not expose a reusable mode for a disabled output, enabling
fails closed rather than guessing a resolution.

## Transaction snapshot

The rollback snapshot now stores:

```text
enabled
mode
position
scale
transform
```

If the monitor was originally active:

```text
Disable
  │
  └── rollback → restore full active state
```

If the monitor was originally disabled:

```text
Enable
  │
  └── rollback → disabled = true
```

This makes Enable and Disable symmetric operations.

## UI behavior

An active display card offers:

```text
Disable
```

A disabled display card remains listed and offers:

```text
Enable
```

Geometry controls are disabled while the draft monitor is disabled.

A disabled draft disappears from the visual topology because it is no longer
part of Hyprland's logical layout.

## Safe Apply lifecycle

```text
Enable / Disable draft
        │
        ▼
Safety validation
        │
        ├── at least 1 active
        ├── focused output protected
        └── geometry valid when enabling
        │
        ▼
Snapshot enabled + geometry
        │
        ▼
systemd --user rollback watchdog
        │
        ▼
temporary runtime mutation
        │
        ▼
15 seconds
   ┌────┴─────┐
   ▼          ▼
 Keep      Rollback
```

The watchdog remains authoritative if Quickshell disappears.

### Hyprland IPC environment

The transient `systemd --user` service does not rely on the user manager having
the same compositor environment as Quickshell.

Before any display mutation, Safe Apply captures the current session IPC
context under the ephemeral transaction directory:

```text
HYPRLAND_INSTANCE_SIGNATURE
XDG_RUNTIME_DIR
WAYLAND_DISPLAY (when present)
PATH
```

The same values are passed explicitly to `systemd-run --setenv=...` and are
also restored from the pending transaction by the rollback command before
`hyprctl` is executed. This provides two independent protections against a
detached watchdog service losing access to the active Hyprland instance.

## CLI

Disable preflight:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00 \
    --enabled false
```

Enable preflight:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00 \
    --enabled true \
    --scale 1 \
    --transform 0 \
    --position 840x0
```

## Still intentionally blocked

Phase 1B.6 does not add:

- mirror mode,
- multi-monitor atomic mutations,
- persistent monitor writes.

Only one dirty display can be Safe Applied at a time.

## Validation

```bash
make quickshell-validate
make lint
make check
```

## Next milestone

With monitor runtime controls complete, Phase 1C can introduce safe persistence
to the generated machine-local `monitors.conf`.

## Phase 1B.6 Fix 2 — explicit re-enable

When a monitor already has:

```lua
disabled = true
```

supplying only mode, position, scale and transform can be accepted by Hyprland
without clearing the disabled state.

Every active rule therefore emits the state explicitly:

```lua
hl.monitor({
    output = "...",
    disabled = false,
    mode = "...",
    position = "...",
    scale = ...,
    transform = ...,
})
```

This applies to normal Enable operations and to rollback when the transaction
snapshot says the monitor was originally active.

The synthetic backend test intentionally models this strictly: geometry changes
never imply re-enable unless `disabled = false` is present.

