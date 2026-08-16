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

## Local install

From the repository root:

```bash
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"

ln -sfn \
  "$PWD/config/quickshell/jc-hyprland" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/jc-hyprland"
```

Start it:

```bash
./bin/start-quickshell.sh
```

## IPC

With the shell running:

```bash
qs ipc show
qs ipc call controlCenter showDisplays
qs ipc call controlCenter hideDisplays
qs ipc call controlCenter toggleDisplays
qs ipc call controlCenter refreshDisplays
qs ipc call controlCenter displaysAreVisible
```

## Development

Create an empty `.qmlls.ini` next to `shell.qml` if you want Quickshell
to manage QML language-server configuration. It is ignored by Git.
