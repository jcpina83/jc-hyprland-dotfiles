# JC Hyprland Quickshell

Custom Quickshell control-center implementation for `jc-hyprland-dotfiles`.

## Current milestone

### Phase 1B.5 — Visual Monitor Layout Editor

The display control center now supports draft editing for:

- resolution,
- refresh rate,
- scale,
- transform / orientation,
- logical x/y position through a visual layout editor.

Persistent monitor configuration is still intentionally unchanged.

## Hyprland layout model

Hyprland positions displays in one virtual logical coordinate space.

Position is calculated from the monitor's top-left corner and uses the
**scaled and transformed** resolution.

Negative x/y coordinates are valid.

Two active monitors must not overlap.

```text
physical mode
    │
    ├── scale
    └── transform
         │
         ▼
logical rectangle
         │
         ├── x
         └── y
         │
         ▼
virtual monitor layout
```

## Visual editor

`DisplayLayoutEditor.qml` renders the draft topology, not only the observed
Hyprland state.

```text
┌──────────────────────────────────────────┐
│              Visual layout               │
│                                          │
│           ┌──────────────┐               │
│           │     DP-1     │               │
│           │ 3440 × 1440  │               │
│           └──────────────┘               │
│                                          │
│     ┌────────────────────────────┐       │
│     │            DP-3            │       │
│     │        5120 × 2160         │       │
│     └────────────────────────────┘       │
└──────────────────────────────────────────┘
```

A monitor can be dragged. The gesture itself does not mutate Hyprland.

```text
DragHandler
    │
    ▼
visual translation
    │
 release
    ▼
snapPosition()
    │
    ▼
DisplayDraftStore.setPosition()
```

The editor uses `DragHandler { target: null }`; the input handler therefore
does not own monitor state.

## Snapping

On drag release, nearby logical coordinates snap against another monitor's:

- left/right edges,
- top/bottom edges,
- horizontal center,
- vertical center.

The editor also provides deterministic relative placement:

```text
← Left
Right →
↑ Above
↓ Below
```

Relative placement centers the moved monitor on the orthogonal axis.

For example, placing a 2752-wide logical monitor centered above a 5120-wide
monitor calculates:

```text
x = anchor.x + (5120 - 2752) / 2
```

## Scale / orientation interaction

Phase 1B.4 disabled scale or orientation choices that immediately caused an
overlap.

Phase 1B.5 now allows those choices as **draft state** and labels them
`move required`.

Example:

```text
Normal
90° · move required
180°
270° · move required
```

After selecting a rotation, move the display in the visual editor until the
topology becomes valid.

Safe Apply remains disabled while any two projected monitors overlap.

## Topology validation

`DisplayDraftStore` is the UI/domain source of truth for projected topology.

It validates:

- integer logical x/y,
- positive logical dimensions,
- pairwise overlap.

The backend independently validates the same target against live Hyprland
monitor geometry before mutation.

```text
Draft topology invalid
        │
        ├── visual red conflict
        ├── error explanation
        └── Safe Apply disabled

Draft topology valid
        │
        ▼
Safe Apply enabled
```

## Transaction boundary

Safe Apply continues to change one monitor at a time.

The transaction snapshot includes:

```text
mode
position
scale
transform
```

The external `systemd --user` watchdog is scheduled before mutation.

```text
Visual draft
    │
    ▼
Topology validation
    │
    ▼
Snapshot current runtime state
    │
    ▼
systemd rollback watchdog
    │
    ▼
Temporary runtime mutation
    │
    ▼
15 s
 ┌──┴──────────────┐
 ▼                 ▼
Keep            Rollback
```

If Quickshell exits during confirmation, the external watchdog remains
responsible for restoring the snapshot.

## Runtime CLI

Position preflight:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00 \
    --scale 1 \
    --transform 0 \
    --position 840x0
```

Negative coordinates are supported:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displayctl \
    preflight \
    --output DP-1 \
    --mode 3440x1440@165.00 \
    --scale 1 \
    --transform 1 \
    --position -1440x800
```

The Control Center passes the complete draft display state to `safe-apply`.

## Safety boundaries still in place

Phase 1B.5 intentionally does not enable:

- monitor enable/disable,
- mirror mode,
- multi-monitor atomic mutation,
- persistent writes to `local/monitors.conf`.

Only one dirty display can be applied at a time.

## Validation

```bash
make quickshell-validate
make lint
make check
```

## Next milestone

Once visual positioning and rollback are validated on the real workstation,
Phase 1B.6 can add monitor enable/disable semantics.

Persistent `monitors.conf` writes remain Phase 1C.
