# Changelog

All notable changes to **jc-hyprland-dotfiles** are documented in this file.

The project follows semantic versioning where practical.

---

## [Unreleased]

### Added

- Quickshell `jc-hyprland` control-center foundation.
- Read-only display module with:
  - live monitor discovery,
  - monitor topology visualization,
  - display information cards,
  - dynamic `availableModes` discovery,
  - focused-output awareness.
- `MonitorService.qml` boundary for Hyprland monitor state.
- Quickshell IPC target `controlCenter` with:
  - `showDisplays`,
  - `hideDisplays`,
  - `toggleDisplays`,
  - `refreshDisplays`,
  - `displaysAreVisible`.
- Runtime Quickshell launcher:
  - `scripts/runtime/start-quickshell.sh`.
- Decoupled Control Center wrapper:
  - `scripts/runtime/jc-control-center.sh`.
- Quickshell static validation:
  - `scripts/validate-quickshell.sh`.
- Quickshell installer, doctor and Makefile integration.
- SDDM `jc-hyprland` theme foundation with:
  - `OdysseyGlass.qml`,
  - `CyberNoir.qml`,
  - theme-specific `sddm.env`.
- Hypridle configuration integration.
- Session action integration helpers for lock, suspend and logout flows.
- User-level wallpaper rotation:
  - `jc-wallpaper-rotation.service`,
  - `jc-wallpaper-rotation.timer`.
- Wallpaper rotation configuration through machine-local `wallpaper.env`.
- Awww wallpaper runtime with managed selection, application and rotation helpers.

### Changed

- Runtime launcher sources now follow the existing `scripts/runtime/*.sh` convention.
- Quickshell is installed as a named configuration:
  - `~/.config/quickshell/jc-hyprland`.
- Runtime consumers use the stable namespace:
  - `~/.config/jc-hyprland-dotfiles/bin`.
- Control Center consumers are decoupled from raw `qs ipc` commands through
  `jc-control-center`.
- Wallpaper management now prefers Awww, with Hyprpaper retained as a fallback
  when available.
- Theme contracts now include SDDM-specific values.
- Installer validation now includes Quickshell configuration and runtime
  wrappers.
- Runtime doctor now validates:
  - `qs`,
  - Quickshell configuration symlink,
  - required QML runtime files,
  - Control Center runtime links,
  - Quickshell IPC availability when the shell is running.
- Repository architecture documentation now explicitly separates:
  - distro adapters,
  - reusable configuration,
  - machine-local state,
  - runtime wrappers,
  - themes,
  - Quickshell UI/services.

### Quality

- Added Phase 1A Quickshell safety validation to prevent monitor-write commands
  from entering the read-only foundation.
- Added checks for stable `ShellId` and IPC contract.
- Added validation for `implicitWidth` / `implicitHeight` on the Quickshell
  `PanelWindow`.
- Added Quickshell validation to the repository lint pipeline.
- Added staged-diff whitespace validation with:
  - `git diff --cached --check`.
- Extended clean-install simulation to validate:
  - Quickshell source files,
  - runtime wrapper executability,
  - expected dry-run installation targets,
  - absence of real symlink creation during dry-run.
- Existing portability checks automatically cover tracked QML files.

### Documentation

- Redesigned the top-level README as a project landing page.
- Added Hyprland and target-distribution branding to the README header.
- Added architecture diagrams for:
  - repository/runtime layering,
  - Quickshell Control Center flow,
  - quality gates.
- Updated the repository tree to reflect the current project structure.
- Added Control Center development phases and roadmap.
- Added explicit screenshot placeholders without broken image links.
- Updated desktop stack documentation for:
  - Quickshell,
  - Hypridle,
  - Awww,
  - SDDM,
  - systemd wallpaper rotation.

### Planned

- Quickshell display editing draft model.
- Resolution selector sourced from actual monitor modes.
- Refresh-rate selector constrained by selected resolution.
- Scale and orientation selectors.
- Runtime monitor apply service with validation.
- Safe apply confirmation and automatic rollback.
- Persistent `monitors.conf` integration.
- Waybar and Hyprland-bind integration for the Control Center.
- Repository screenshots and visual gallery.
- Clean-install validation on Arch Linux.
- Clean-install validation on openSUSE Tumbleweed.
- Additional desktop and laptop profiles.
- Additional themes.
- VRR controls.
- HDR / 10-bit display controls where supported.
- Improved automated installation, recovery and rollback.

---

## [0.1.0] - 2026-08-15

Initial public development release.

### Added

- Modular Hyprland configuration architecture.
- Active-theme engine with runtime theme switching.
- `odyssey-glass` theme.
- `cyber-noir` theme.
- Dual-monitor role model:
  - main output,
  - secondary output.
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

- Garuda Linux.
- Hyprland 0.54.x.
- AMD GPU.
- Multi-monitor desktop environment.

Arch Linux and openSUSE adapters are included but still require full
clean-install validation.
