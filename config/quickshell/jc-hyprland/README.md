# JC Hyprland Quickshell

Custom Quickshell control-center implementation for `jc-hyprland-dotfiles`.

## Current milestone

### Phase 1B.3 — Safe Apply

The displays module now separates:

```text
Observed state
      │
      ▼
DisplayDraftStore
      │
      ▼
Safe Apply
      │
      ├── Keep runtime state
      └── Rollback
```

Safe Apply is still limited to:

- resolution,
- refresh rate,
- one monitor per transaction.

It does **not** persist changes to `local/monitors.conf`.

## Safe Apply architecture

```text
DisplayPopup
     │
     ▼
MonitorApplyService
     │
     ▼
jc-displayctl safe-apply
     │
     ├── snapshot current runtime mode
     ├── create XDG_RUNTIME_DIR transaction
     ├── schedule systemd user watchdog
     └── apply requested runtime mode
                    │
                    ▼
               Hyprland
```

The UI countdown is not the only rollback mechanism.

An external transient `systemd --user` timer is scheduled **before** the monitor
is changed. If Quickshell crashes, reloads or is closed, the watchdog can still
invoke:

```text
jc-displayctl rollback --token <transaction>
```

## Confirmation lifecycle

```text
Observed mode
    │
    ▼
Draft
    │
    ▼
Safe Apply
    │
    ▼
Temporary runtime mode
    │
    ├── Keep
    │      └── cancel watchdog
    │
    └── 15 second timeout
           └── automatic rollback
```

`Keep` means keep the **runtime** mode. Persistence remains a later phase.

## Ephemeral transaction state

Transaction metadata lives under:

```text
$XDG_RUNTIME_DIR/jc-hyprland-dotfiles/display-safe/
```

and includes:

- transaction token,
- output,
- target mode,
- rollback mode,
- deadline,
- systemd unit name,
- generated rollback Lua rule.

This state is ephemeral and is not versioned or written to the user's persistent
dotfiles configuration.

## Runtime commands

Preflight:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@120.00
```

Safe Apply:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    safe-apply \
    --output DP-1 \
    --mode 3440x1440@120.00 \
    --timeout 15
```

Inspect pending transaction:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl status
```

Keep:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    keep \
    --token <token>
```

Rollback:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    rollback \
    --token <token>
```

Normal use should happen through the Control Center UI.

## Recovery behavior

When `MonitorApplyService` starts, it asks `jc-displayctl status`.

If a Safe Apply transaction is still pending after a Quickshell reload, the UI
recovers the token, output and deadline and resumes the confirmation view.

If the watchdog already rolled the mode back, status returns idle and observed
monitor state is refreshed.

## Safety boundary

Phase 1B.3 still does not allow editing:

- scale,
- transform/orientation,
- x/y position,
- enable/disable,
- multiple monitors in one transaction,
- persistent `monitors.conf`.

Those controls are intentionally blocked until Safe Apply is validated.

## Validation

```bash
make quickshell-validate
make lint
make check
```

## Next milestone

After Safe Apply and watchdog rollback are validated, the same transaction
boundary can safely be extended to scale and orientation before layout editing
and persistent saves are introduced.
