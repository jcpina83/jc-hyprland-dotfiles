# Changelog

All notable changes to **jc-hyprland-dotfiles** are documented in this file.

The project follows semantic versioning where practical.

---

## [Unreleased]

### Planned

- Clean-install validation on Arch Linux.
- Clean-install validation on openSUSE.
- Theme-specific wallpapers.
- Additional desktop and laptop profiles.
- Improved automated installation and rollback.
- Additional themes.
- HDR and high-refresh display tuning.

---

## [0.1.0] - 2026-08-15

Initial public development release.

### Added

- Modular Hyprland configuration architecture.
- Active-theme engine with runtime theme switching.
- `odyssey-glass` theme.
- `cyber-noir` theme.
- Dual-monitor role model:
  - main output
  - secondary output
- Persistent workspace assignment by monitor role.
- Dual independent Waybar instances.
- Managed Waybar runtime with PID isolation.
- Wofi launcher integration.
- SwayNotificationCenter integration.
- Hyprlock dual-monitor layout.
- Foot terminal theme integration.
- Hyprpaper wallpaper management.
- AMD GPU Waybar telemetry.
- Network traffic Waybar telemetry.
- Machine-local `host.env`.
- Machine-local monitor configuration.
- Machine-local wallpaper overrides.
- Garuda integration.
- Arch distribution adapter.
- openSUSE distribution adapter.
- Hyprland appearance and animation modules.
- Theme-specific Hyprland, GTK/CSS, Foot and Hyprlock palettes.

### Quality

- Bash syntax validation.
- ShellCheck validation.
- Fish syntax validation.
- JSON/JSONC validation.
- Multi-theme structural validation.
- Foot configuration validation per theme.
- Machine-specific hardcode detection.
- Runtime doctor diagnostics.
- `make check` quality gate.

### Design principles

- Distribution agnostic.
- Hardware agnostic.
- Multi-monitor aware.
- Theme based.
- Modular.
- Reversible.
- Git managed.
- Update safe.

### Tested

The initial release has been validated primarily on:

- Garuda Linux
- Hyprland 0.54.x
- AMD GPU
- Multi-monitor desktop environment

Arch Linux and openSUSE adapters are included but still require full clean-install validation.