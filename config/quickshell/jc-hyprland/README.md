# JC Hyprland Quickshell

Custom Quickshell control-center implementation for `jc-hyprland-dotfiles`.

## Current milestone

### Phase 1B.4 — Scale + Orientation

The displays module now supports Safe Apply for:

- resolution,
- refresh rate,
- scale,
- transform / orientation,
- one monitor per transaction.

It still does **not** persist changes to `local/monitors.conf`.

## State boundaries

```text
Hyprland
   │
   ▼
Observed state
   │
   ▼
DisplayDraftStore
   │
   ├── mode
   ├── scale
   ├── transform
   └── x/y observed only
   │
   ▼
MonitorApplyService
   │
   ▼
jc-displayctl safe-apply
   │
   ├── validate
   ├── snapshot
   ├── watchdog
   └── runtime mutation
```

Observed state, draft state, runtime-applied state and persistent state remain
separate.

## Scale validation

Hyprland expects scale to produce whole logical pixels.

The Control Center uses a conservative common scale set:

```text
1.00
1.25
1.50
1.75
2.00
```

and only exposes candidates that divide the selected physical resolution into
whole logical pixels.

For example:

```text
3440 × 1440 / 1.25 = 2752 × 1152   valid
3440 × 1440 / 1.50 = 2293.33 × 960 invalid
```

The backend validates this again before mutation.

## Orientation / transform

Hyprland transform values are represented directly:

```text
0  Normal
1  90°
2  180°
3  270°
4  Flipped
5  Flipped + 90°
6  Flipped + 180°
7  Flipped + 270°
```

Transforms `1`, `3`, `5` and `7` exchange logical width and height.

## Topology guard

Phase 1B.4 intentionally does not edit position.

Before a scale or transform can be selected/applied, the projected logical
rectangle is compared with every other active monitor.

```text
target logical rectangle
        │
        ▼
overlaps another monitor?
   │             │
  yes            no
   │             │
disabled /       Safe Apply
rejected
```

An option that requires repositioning is shown as:

```text
90° · layout needed
```

and is disabled.

The backend performs the same overlap validation independently of the UI.

This avoids introducing invalid monitor overlap while the visual layout editor
is not yet available.

## Safe Apply snapshot

Rollback now snapshots the complete mutable runtime state used by this phase:

```text
mode
position
scale
transform
```

This is important after `Keep`: a later Safe Apply preserves the current runtime
scale and transform instead of falling back to the persistent rule.

Persistent monitor options such as VRR, color-management and bit-depth fields
continue to be preserved from the machine-local monitor rule.

## Safe Apply lifecycle

```text
Draft
  │
  ▼
Validate mode + scale + transform + topology
  │
  ▼
Snapshot current runtime display state
  │
  ▼
Schedule systemd --user rollback watchdog
  │
  ▼
Apply temporary state
  │
  ▼
15 second confirmation
  │
  ├── Keep
  │      └── retain runtime state
  │
  └── Rollback / timeout
         └── restore snapshot
```

The external watchdog remains independent from Quickshell.

## CLI examples

Existing mode-only preflight remains valid and preserves current runtime scale,
transform and position:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00
```

Scale preflight:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00 \
    --scale 1.25
```

Transform preflight:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00 \
    --transform 2
```

The Control Center supplies the full draft state during Safe Apply.

## Still intentionally blocked

Phase 1B.4 does not expose:

- manual x/y position,
- drag/drop monitor layout,
- enable/disable,
- persistent save to `monitors.conf`.

A rotation that needs repositioning is rejected until the layout phase.

## Validation

```bash
make quickshell-validate
make lint
make check
```

## Next milestone

Phase 1B.5 can build a visual position/layout editor on top of the same
transactional Safe Apply boundary.
