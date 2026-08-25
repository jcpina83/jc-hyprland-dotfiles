# JC Hyprland Quickshell

Custom Quickshell Control Center for `jc-hyprland-dotfiles`.

## Current milestone

### Phase 1B.2 — runtime display apply

The displays module now supports:

- live monitor discovery,
- real `availableModes`,
- topology visualization,
- editable per-output draft state,
- resolution selection,
- refresh-rate selection constrained by resolution,
- dirty/reset handling,
- runtime-only apply for one monitor at a time.

Persistence remains separate and is **not modified** in this phase.

## Mutation boundary

```text
Display UI
    │
    ▼
DisplayDraftStore
    │
    ▼
MonitorApplyService
    │
    ▼
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl
    │
    ▼
hyprctl eval / hl.monitor(...)
    │
    ▼
Hyprland runtime
```

The QML UI never runs `hyprctl` directly.

## Why jc-displayctl preserves the persistent rule

Hyprland 0.55+ uses Lua monitor rules:

```lua
hl.monitor({
    output = "DP-1",
    mode = "1920x1080@144",
    position = "0x0",
    scale = 1
})
```

Monitor rules also contain fields such as:

```text
transform
bitdepth
cm
vrr
sdrbrightness
sdrsaturation
...
```

Phase 1B.2 changes only `mode`.

`jc-displayctl` therefore reads the existing machine-local Hyprlang monitor rule
from:

```text
~/.config/jc-hyprland-dotfiles/local/monitors.conf
```

and reconstructs the runtime Lua rule while preserving supported extra fields.

The file is never written by Phase 1B.2.

If an unknown monitor option is present, `jc-displayctl` refuses the apply rather
than silently dropping it.

## One-monitor transaction

This first runtime mutation milestone applies exactly one dirty output at a time.

```text
dirtyCount = 0  -> nothing to apply
dirtyCount = 1  -> Apply enabled
dirtyCount > 1  -> Apply blocked
```

This keeps the first mutation boundary simple and avoids partial multi-output
transactions before rollback support exists.

## Runtime backend

Preflight without modifying Hyprland:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00
```

Apply runtime-only:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    apply \
    --output DP-1 \
    --mode 3440x1440@165.00
```

Normal use should happen through the Control Center UI.

## Validation

```bash
make quickshell-validate
make lint
make check
```

## Phase boundary

Phase 1B.2 does not provide:

- confirmation countdown,
- automatic rollback,
- scale editing,
- orientation editing,
- position editing,
- monitor enable/disable,
- persistent `monitors.conf` writes.

Those remain separate milestones.

## Next milestone

Phase 1B.3 will add Safe Apply:

```text
Observed snapshot
      │
      ▼
Temporary runtime apply
      │
      ▼
Confirmation countdown
      │
      ├── Keep
      └── Rollback
```

Only after Safe Apply is proven will higher-risk fields such as scale,
orientation and topology be exposed.
