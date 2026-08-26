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
- Quickshell display editing stack with:
  - draft state isolated from observed state,
  - dynamic resolution / refresh selection,
  - scale and orientation controls,
  - visual monitor topology editor,
  - logical-position snapping,
  - monitor Enable / Disable controls.
- `jc-displayctl` runtime display backend with:
  - Safe Apply,
  - Keep,
  - manual rollback,
  - external systemd user rollback watchdog,
  - focused-output and last-active-monitor safety guards.
- `jc-displaycfg` persistent display backend with:
  - mutation-free preview,
  - global runtime snapshot,
  - atomic `local/monitors.lua` replacement,
  - automatic backups,
  - post-reload verification,
  - automatic persistent rollback on validation failure,
  - backup listing and restore support.
- Machine-local `hosts/example/monitors.lua` template for Lua-native display
  configuration.
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
- Desktop-session Control Center integration with:
  - Hyprland Lua autostart,
  - idempotent named Quickshell startup,
  - `SUPER + C` toggle binding,
  - MAIN / SECONDARY output-aware Waybar buttons.
- Output-aware Control Center IPC:
  - `showDisplaysOn`,
  - `toggleDisplaysOn`.
- Output-aware runtime wrapper actions:
  - `show-on <output>`,
  - `toggle-on <output>`.
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
- Hyprland integration has migrated definitively to Lua for the Hyprland 0.55+
  configuration model; Hyprlang is no longer a supported runtime path.
- The validated compositor baseline is now Hyprland 0.56.2.
- Machine-local persistent display configuration moved from `monitors.conf` to
  `local/monitors.lua`.
- `local/monitors.lua` is now the single display source consumed by both:
  - `jc-displayctl` for runtime mutation and rollback,
  - `jc-displaycfg` for persistent state.
- The project Lua overlay remains loaded after the distro base configuration so
  project-owned settings and machine-local monitor state win without forking the
  complete distro configuration.
- Display persistence is global rather than per-monitor so a Hyprland reload
  cannot silently revert another monitor's confirmed runtime-only state.
- `jq` is treated as a required runtime dependency for the display backends.
- Removed the deprecated pre-Lua Hyprland compatibility tree, legacy bridge
  file and legacy monitor template after successful Lua persistence validation.

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
- Added Phase 1D validation contracts covering:
  - Quickshell session startup ownership,
  - idempotent IPC startup probing,
  - Hyprland Control Center keybind,
  - output-aware wrapper commands,
  - MAIN / SECONDARY Waybar targeting.
- Added display safety contracts covering:
  - no raw monitor mutation from QML UI,
  - `desc:` selector preservation,
  - explicit monitor re-enable with `disabled = false`,
  - detached Safe Apply rollback watchdog environment,
  - Lua monitor persistence,
  - atomic save and backup restoration.
- Real-host display persistence validation completed against Hyprland 0.56.2,
  including reload verification and preservation of runtime refresh, layout and
  scale state.

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
- Updated project documentation to establish Lua as the only supported Hyprland
  configuration path and `local/monitors.lua` as the authoritative persistent
  display source.
- Updated the display roadmap to reflect completed Phases 1A, 1B.1–1B.6,
  1C.1–1C.3 and 1D.1–1D.4.

### Planned

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
