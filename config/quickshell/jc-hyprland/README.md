# JC Hyprland Quickshell — Phase 1A

Initial read-only Quickshell control-center foundation.

## Responsibilities

- `shell.qml`: shell entrypoint only.
- `Main.qml`: composition root, popup visibility, screen selection and IPC.
- `services/MonitorService.qml`: Hyprland adapter and normalized monitor model.
- `modules/displays/DisplayPopup.qml`: display popup composition only.
- `modules/displays/DisplayLayout.qml`: read-only topology visualization.
- `modules/displays/DisplayCard.qml`: one monitor's read-only details.
- `components/`: reusable visual primitives.
- `theme/Theme.qml`: design tokens.

## Phase 1A constraints

This phase is intentionally read-only.

It does **not**:

- run `hyprctl keyword monitor`,
- write `monitors.conf`,
- change resolution, scale or refresh rate,
- alter Waybar,
- alter wallpaper services.

## Installation

The repository installer owns the runtime symlinks.

From the repository root:

```bash
./install.sh
```

It installs:

```text
~/.config/quickshell/jc-hyprland
    -> <repo>/config/quickshell/jc-hyprland

~/.config/jc-hyprland-dotfiles/bin/start-quickshell.sh
    -> <repo>/scripts/runtime/start-quickshell.sh

~/.config/jc-hyprland-dotfiles/bin/jc-control-center
    -> <repo>/scripts/runtime/jc-control-center.sh
```

## Start Quickshell

```bash
~/.config/jc-hyprland-dotfiles/bin/start-quickshell.sh
```

## Control Center IPC

Preferred interface:

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-control-center ipc-show
~/.config/jc-hyprland-dotfiles/bin/jc-control-center show
~/.config/jc-hyprland-dotfiles/bin/jc-control-center hide
~/.config/jc-hyprland-dotfiles/bin/jc-control-center toggle
~/.config/jc-hyprland-dotfiles/bin/jc-control-center refresh
~/.config/jc-hyprland-dotfiles/bin/jc-control-center status
```

Direct Quickshell IPC remains available for diagnostics:

```bash
qs -c jc-hyprland ipc show
qs -c jc-hyprland ipc call controlCenter showDisplays
qs -c jc-hyprland ipc call controlCenter hideDisplays
qs -c jc-hyprland ipc call controlCenter toggleDisplays
qs -c jc-hyprland ipc call controlCenter refreshDisplays
qs -c jc-hyprland ipc call controlCenter displaysAreVisible
```

## Quality gates

Static Quickshell validation:

```bash
make quickshell-validate
```

Full repository quality gate:

```bash
make check
```

Runtime IPC smoke test, with Quickshell already running:

```bash
make quickshell-test
```

## Development

Create an empty `.qmlls.ini` next to `shell.qml` if you want Quickshell
to manage QML language-server configuration. It is ignored by Git.
