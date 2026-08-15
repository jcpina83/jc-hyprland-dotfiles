# jc-hyprland-dotfiles

A modular, theme-driven and distro-aware Hyprland desktop configuration.

The project is designed to provide a reproducible personal Hyprland environment without turning the operating system configuration into a monolithic or distribution-specific rice.

> Current development release: **v0.1.0**

---

## Overview

`jc-hyprland-dotfiles` separates desktop configuration into four major layers:

```text
Distribution
     │
     ▼
Host / hardware
     │
     ▼
Common desktop components
     │
     ▼
Active theme
```

Machine-specific information such as monitor names, PCI devices and local wallpapers is intentionally kept outside the Git repository.

---

## Screenshots

### Odyssey Glass

![Odyssey Glass desktop](docs/screenshots/odyssey-glass-desktop.webp)

![Odyssey Glass launcher](docs/screenshots/odyssey-glass-wofi.webp)

![Odyssey Glass notifications](docs/screenshots/odyssey-glass-swaync.webp)

### Cyber Noir

![Cyber Noir desktop](docs/screenshots/cyber-noir-desktop.webp)

---

## Design principles

- Distribution agnostic
- Hardware agnostic
- Multi-monitor aware
- Theme based
- Modular
- Reversible
- Git managed
- Update safe

---

## Components

The current desktop stack includes:

| Component | Purpose |
|---|---|
| Hyprland | Wayland compositor |
| Waybar | Main and secondary status bars |
| Wofi | Application launcher |
| SwayNC | Notification center |
| Hyprlock | Lock screen |
| Foot | Terminal emulator |
| hyprpaper | Wallpaper manager |
| Fish | Interactive shell |

---

## Themes

Two themes are currently included.

### Odyssey Glass

The primary desktop theme.

Characteristics:

- dark glass surfaces
- blue / violet accents
- soft transparency
- rounded capsules
- moderate blur
- restrained animations

### Cyber Noir

A validation and alternative theme.

Characteristics:

- near-black surfaces
- cyan / magenta accents
- stronger contrast
- neon-inspired palette

List themes:

```bash
make theme-list
```

Show the current theme:

```bash
make theme-current
```

Apply a theme:

```bash
make theme-apply THEME=odyssey-glass
```

or:

```bash
make theme-apply THEME=cyber-noir
```

---

## Theme architecture

Themes live under:

```text
themes/
├── odyssey-glass/
│   ├── theme.env
│   ├── colors.conf
│   ├── colors.css
│   ├── foot-colors.ini
│   ├── hyprlock.env
│   └── wallpapers/
│
└── cyber-noir/
    ├── theme.env
    ├── colors.conf
    ├── colors.css
    ├── foot-colors.ini
    ├── hyprlock.env
    └── wallpapers/
```

The active theme is exposed through:

```text
~/.config/jc-hyprland-dotfiles/theme
```

which is a symlink to the selected theme directory.

Applications do not need to know the actual theme name.

---

## Repository structure

```text
jc-hyprland-dotfiles/
├── config/
│   ├── foot/
│   ├── hypr/
│   ├── hyprlock/
│   ├── swaync/
│   ├── waybar/
│   └── wofi/
│
├── distros/
│   ├── arch/
│   ├── garuda/
│   └── opensuse/
│
├── docs/
├── hosts/
│   └── example/
│
├── profiles/
├── scripts/
│   ├── lib/
│   └── runtime/
│
├── themes/
│   ├── cyber-noir/
│   └── odyssey-glass/
│
├── Makefile
├── install.sh
├── update.sh
├── uninstall.sh
├── VERSION
└── README.md
```

---

## Machine-local configuration

Hardware-specific data is deliberately stored outside the Git checkout:

```text
~/.config/jc-hyprland-dotfiles/
├── repo -> /path/to/jc-hyprland-dotfiles
├── theme -> /path/to/repo/themes/<active-theme>
│
├── bin/
│   ├── amd-gpu.sh
│   ├── apply-wallpaper.sh
│   ├── jc-theme
│   ├── launch-foot.sh
│   ├── launch-wofi.sh
│   ├── lock-session.sh
│   ├── network-traffic.sh
│   ├── start-swaync.sh
│   └── start-waybar.sh
│
└── local/
    ├── host.env
    ├── monitors.conf
    ├── wallpaper.env
    └── active-theme
```

This prevents monitor serial numbers, GPU PCI addresses and user-specific filesystem paths from entering Git.

---

## Host configuration

Example:

```ini
PROFILE=desktop
THEME=odyssey-glass

MAIN_OUTPUT=DP-3
SECONDARY_OUTPUT=DP-1

MAIN_WORKSPACES=1,2,3,4,5
SECONDARY_WORKSPACES=6,7,8,9,10

GPU_PCI=0000:00:00.0
```

Real hardware values belong only in:

```text
~/.config/jc-hyprland-dotfiles/local/host.env
```

---

## Installation

Clone the repository:

```bash
git clone <repository-url>
cd jc-hyprland-dotfiles
```

Inspect what the installer would do:

```bash
make dry-run
```

Run diagnostics:

```bash
make doctor
```

Install the runtime links and local configuration:

```bash
make install
```

Review:

```text
~/.config/jc-hyprland-dotfiles/local/host.env
~/.config/jc-hyprland-dotfiles/local/monitors.conf
```

before enabling hardware-specific configuration.

---

## Quality gates

Run the full project validation:

```bash
make check
```

This includes:

```text
Bash syntax
ShellCheck
Fish syntax
JSON / JSONC
Theme validation
Foot configuration validation
Portability checks
Runtime diagnostics
Hyprland config errors
```

Individual checks are also available:

```bash
make lint
make doctor
make theme-validate
make portability-check
```

---

## Waybar

The project runs two independent Waybar instances.

Main output:

```text
launcher
workspaces
active window
clock
GPU
CPU
RAM
audio
network
tray
notifications
power
```

Secondary output:

```text
workspaces
network traffic
audio
network
notifications
clock
```

The runtime manages only its own Waybar PIDs and does not kill unrelated Waybar instances unless explicitly requested.

---

## Notifications

SwayNotificationCenter is used as the notification daemon and control center.

Only one notification daemon should run at a time.

The project intentionally replaces Mako when SwayNC is enabled.

---

## Wallpapers

Wallpaper management is handled through hyprpaper.

Themes may ship:

```text
wallpapers/main.webp
wallpapers/secondary.webp
```

Local machine overrides can instead be configured through:

```text
~/.config/jc-hyprland-dotfiles/local/wallpaper.env
```

Local overrides are never stored in Git.

---

## Multi-monitor model

The project does not hardcode monitor connector names inside themes.

Instead, monitors receive logical roles:

```text
MAIN_OUTPUT
SECONDARY_OUTPUT
```

This allows the same configuration to be reused on different hardware.

---

## Distribution support

| Distribution | Status |
|---|---|
| Garuda Linux | Tested |
| Arch Linux | Adapter available; clean-install validation pending |
| openSUSE | Adapter available; clean-install validation pending |

The project is intentionally structured so distro-specific package installation remains separated from the desktop configuration itself.

---

## Hyprland versions

The current Hyprlang configuration targets the Hyprland `0.54.x` generation.

The repository already separates:

```text
config/hypr/hyprlang/
config/hypr/lua/
```

to allow future migration if Hyprland configuration mechanisms evolve.

---

## Useful commands

```bash
make help

make lint
make doctor
make check

make theme-list
make theme-current
make theme-apply THEME=odyssey-glass

make waybar-test
make waybar-stop

make wallpaper-apply
```

---

## Safety

The project intentionally avoids automatically overwriting:

```text
~/.config/hypr/hyprland.conf
~/.config/foot/
~/.config/waybar/
~/.config/wofi/
~/.config/swaync/
```

Runtime wrappers explicitly load the repository-managed configuration instead.

Machine-local files are stored outside Git.

---

## Development status

`v0.1.0` should be considered an early but functional development release.

The project is currently focused on:

- clean installation
- portability
- additional distro validation
- theme-specific wallpapers
- update safety
- rollback
- documentation

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).