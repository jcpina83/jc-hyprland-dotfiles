# Wallpaper Control Architecture

## Phase 2B contract

```text
Quickshell Wallpaper UI
        |
        v
jc-wallpaperctl
        |
        +--> wallpaper-manager.sh
        |       |
        |       +--> theme defaults
        |       +--> per-theme machine-local preferences
        |       `--> apply-wallpaper.sh
        |
        +--> wallpaper.env
        `--> runtime observation (awww / hyprpaper)
```

### State boundaries

Wallpaper state is intentionally simpler than display Safe Apply:

```text
Observed runtime state
        |
        v
WallpaperService
        |
        v
UI draft selection
        |
        v
Apply
        |
        +--> persistent per-theme preference
        `--> wallpaper runtime
```

The UI draft is QML-only. Selecting a thumbnail must not execute `awww`,
write `wallpaper.env`, or modify per-theme preference files.

`wallpaper-manager.sh` owns wallpaper preference persistence and delegates the
actual runtime change to `apply-wallpaper.sh`. The latter remains the only
low-level backend that selects and drives `awww` or `hyprpaper`.

### Persistent configuration

`~/.config/jc-hyprland-dotfiles/local/wallpaper.env` owns global machine-local
settings:

- wallpaper engine
- wallpaper library root
- transition settings
- automatic rotation settings

`~/.config/jc-hyprland-dotfiles/local/wallpapers/<theme>.env` stores
machine-local wallpaper selections and fit overrides for each theme.

### Catalog

The canonical catalog is produced by `wallpaper-manager.sh` from:

1. `<active-theme>/wallpapers`
2. `WALLPAPER_LIBRARY_DIR`

Canonical paths are deduplicated before they are exposed to the UI.

### Stable read API

Phase 2B.2.1 introduces:

```bash
jc-wallpaperctl status
jc-wallpaperctl status --json
jc-wallpaperctl catalog
jc-wallpaperctl catalog --json
```

This phase is read-only. Mutation commands are introduced only after the
observed-state and catalog contracts are validated.

### QML safety contract

Wallpaper QML modules must not directly:

- invoke `awww`
- invoke `hyprpaper`
- invoke `systemctl`
- write `wallpaper.env`
- write `local/wallpapers/*.env`
- own rotation timer lifecycle


## WallpaperService observed-state boundary

`services/WallpaperService.qml` is the Quickshell read boundary for Phase
2B.2.2. It consumes only the stable machine-readable API:

```bash
jc-wallpaperctl status --json
jc-wallpaperctl catalog --json
```

The service is read-only. It does not invoke `awww`, `hyprpaper`, `systemctl`,
or write wallpaper configuration/preferences.

A refresh is committed atomically: status is held as a pending snapshot until
the catalog request also succeeds. UI consumers therefore do not observe a
new status paired with an old catalog.

The service exposes:

- active theme and wallpaper library identity
- configured and observed runtime engines
- rotation configuration
- MAIN/SECONDARY defaults, overrides, effective and runtime wallpapers
- `runtimeMatchesConfigured`
- the canonical deduplicated wallpaper catalog
- loading/ready/error/last-refresh lifecycle state

The catalog is loaded on service initialization and explicit `refresh()`.
There is intentionally no periodic catalog polling. A future `WallpaperView`
may request refresh when the Wallpapers module becomes active.


## Wallpaper UI foundation

Phase 2B.3.1 introduces the first hosted Wallpapers module:

```text
ControlCenterShell
        |
        v
WallpaperView.qml
        |
        +--> WallpaperService.qml      observed state + catalog
        `--> WallpaperDraftStore.qml   QML-only draft selection
```

`WallpaperDraftStore.qml` is draft-only. Selecting a wallpaper changes only
the in-memory MAIN or SECONDARY draft and never changes the desktop runtime or
persistent preference files.

The initial visual module contains:

- MAIN and SECONDARY preview cards
- explicit target selection
- All / Theme / Library catalog filters
- a virtualized `GridView`
- lightweight asynchronous thumbnails
- current/effective wallpaper markers
- draft selection markers
- refresh and reset-draft actions
- observed-state-change protection while a draft exists

The catalog `GridView` uses delegate virtualization and a bounded
`cacheBuffer`; the 459-item catalog is not instantiated as 459 simultaneous
thumbnail components.

Phase 2B.3.1 intentionally does not provide Apply. Runtime mutation remains
outside QML and will be introduced through the stable wallpaper controller in
the next mutation phase.
