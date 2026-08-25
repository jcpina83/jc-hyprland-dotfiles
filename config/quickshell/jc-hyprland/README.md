# JC Hyprland Quickshell

Custom Quickshell control-center implementation for `jc-hyprland-dotfiles`.

## Current milestone

### Phase 1B.1 — editable display draft

The displays module can now:

- discover monitors from Hyprland,
- normalize live monitor state,
- read real `availableModes`,
- visualize topology,
- create one independent draft per output,
- change draft resolution,
- constrain refresh-rate choices to the selected resolution,
- track dirty state,
- reset draft changes.

This milestone is still intentionally **read-only with respect to Hyprland**.

It does not execute:

```text
hyprctl keyword monitor ...
```

and it does not write:

```text
~/.config/jc-hyprland-dotfiles/local/monitors.conf
```

## Architecture

```text
Hyprland
   │
   ▼
MonitorService                  observed state
   │
   ▼
MonitorModeParser
   │
   ▼
DisplayDraftStore               editable state
   │
   ▼
DisplayPopup / DisplayCard      presentation
```

Observed state and draft state are intentionally separate.

## Files

```text
jc-hyprland/
├── shell.qml
├── Main.qml
├── components/
│   ├── JcButton.qml
│   ├── JcCard.qml
│   └── JcChoiceGroup.qml
├── services/
│   ├── MonitorService.qml
│   ├── MonitorModeParser.qml
│   └── DisplayDraftStore.qml
├── modules/
│   └── displays/
│       ├── DisplayPopup.qml
│       ├── DisplayLayout.qml
│       └── DisplayCard.qml
└── theme/
    └── Theme.qml
```

## Mode model

A Hyprland mode such as:

```text
3440x1440@165.00Hz
```

is normalized into:

```text
raw
width
height
refreshRate
resolutionKey
```

Exact duplicate mode strings are removed. Close-but-different refresh rates such
as `120.00 Hz` and `119.88 Hz` remain independent modes.

## Resolution / refresh relationship

Refresh rate is not treated as an independent global list.

```text
selected resolution
        │
        ▼
valid modes for resolution
        │
        ▼
refresh-rate choices
```

This prevents the UI from constructing a mode that the monitor did not report.

## Draft lifecycle

```text
MonitorService refresh
        │
        ▼
DisplayDraftStore
        │
        ├── edit resolution
        ├── edit refresh mode
        ├── dirty
        └── reset
```

If Hyprland monitor state changes while a draft is dirty, the draft is preserved
and marked stale instead of being overwritten silently.

## Runtime

Start:

```bash
~/.config/jc-hyprland-dotfiles/bin/start-quickshell.sh
```

Control:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-control-center show
~/.config/jc-hyprland-dotfiles/bin/jc-control-center hide
~/.config/jc-hyprland-dotfiles/bin/jc-control-center toggle
~/.config/jc-hyprland-dotfiles/bin/jc-control-center refresh
~/.config/jc-hyprland-dotfiles/bin/jc-control-center status
```

## Validation

```bash
make quickshell-validate
make quickshell-test
make check
```

## Next milestone

Phase 1B.2 will introduce a dedicated runtime apply boundary:

```text
DisplayDraftStore
        │
        ▼
ApplyService
        │
        ▼
Hyprland
```

That service will be added only after Phase 1B.1 is validated visually and at
runtime.
