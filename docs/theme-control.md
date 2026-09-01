# Theme Control Architecture

## Phase 2C contract

Phase 2C manages **theme discovery, preview, observed active state and theme
application** without replacing the Phase 2A semantic Theme API.

The ownership split is:

```text
themes/<theme>/
        |
        +-- quickshell.json
        |       |
        |       +--> Theme.qml
        |       |      semantic colors / opacity / motion consumers
        |       |
        |       +--> jc-theme catalog --json
        |              future Themes catalog / live preview data
        |
        +-- wallpaper assets
                |
                +--> jc-theme catalog --json
                       live preview composition input
```

`Theme.qml` remains the shared semantic styling API. Phase 2C does not duplicate
its token-resolution logic in a feature module.

## Phase 2C.1b — Stable theme read API

The existing public `jc-theme` wrapper now exposes a machine-readable,
read-only boundary:

```bash
jc-theme status
jc-theme status --json
jc-theme catalog
jc-theme catalog --json
```

Legacy interfaces remain supported:

```bash
jc-theme list
jc-theme current
jc-theme apply THEME
```

### Observed state

`status --json` exposes both machine-local active-theme representations:

```text
~/.config/jc-hyprland-dotfiles/theme
    symlink to repo/themes/<theme>

~/.config/jc-hyprland-dotfiles/local/active-theme
    plain-text active theme identity
```

The response reports:

```text
activeTheme
activeFileTheme
activeLinkTheme
synchronized
valid
themePath
metadataFile
```

This makes divergence observable before any Control Center mutation work is
enabled.

`Theme.qml` intentionally continues to watch `local/active-theme` directly
with Quickshell `FileView`. That is the established semantic Theme API and is
not replaced by `ThemeService`.

### Installed theme discovery

`catalog --json` discovers theme directories under the repository `themes/`
root. A catalog item is admitted only when its required theme files exist and
its `quickshell.json` metadata is valid for schema version 1 with an `id` that
matches the directory name.

For Control Center purposes, `quickshell.json` is the canonical catalog and
preview metadata source. `theme.env` remains part of the existing desktop
runtime/theme contract and is not repurposed into a QML metadata format.

Catalog items expose:

```text
id
name
schemaVersion
active
colors
opacity
preview.mainWallpaper
preview.secondaryWallpaper
```

The preview wallpaper paths are deterministic existing theme assets.

## Live preview strategy

Phase 2C does not introduce maintained screenshots for each theme. The tracked
themes currently provide theme wallpapers but no dedicated preview/thumbnail
assets.

The future Themes view should therefore compose a **live preview card** from:

```text
quickshell.json semantic palette
        +
theme wallpapers/main.webp
        +
theme wallpapers/secondary.webp
        +
canonical JC Holo component primitives
```

This keeps preview visuals synchronized with versioned theme data.

Preview composition is presentation-only. Selecting a preview must not change
`local/active-theme`, the active theme symlink, wallpaper runtime or any
desktop process.

## Mutation boundary remains deferred

Phase 2C.1b does **not** approve the current `jc-theme apply THEME` path for QML.

The existing manager changes the active theme identity before refreshing
secondary consumers such as SDDM, Hyprland, wallpaper runtime, Waybar and
SwayNC. Some of those refreshes currently use best-effort failure handling.

Before Themes UI can Apply, a later Phase 2C mutation step must define:

```text
structured Apply result
failure semantics
active file/link consistency
rollback/recovery semantics
auxiliary consumer synchronization
```

The discovered-theme set and the privileged SDDM integration also need to be
reconciled before the Control Center claims complete Apply synchronization.

## Planned QML ownership

The intended next read-only layer is:

```text
jc-theme status/catalog --json
        |
        v
ThemeService
        |
        v
ThemeDraftStore
        |
        v
ThemeView / live preview cards
```

A later mutation layer will add a dedicated `ThemeApplyService` only after the
public Apply contract is hardened.

The Themes navigation entry remains disabled during Phase 2C.1b.

## Phase 2C.1c — ThemeService observed-state boundary

`ThemeService.qml` is the first QML-facing service for Phase 2C.

It is intentionally **read-only**:

```text
jc-theme status --json
        |
        v
ThemeService
        |
        +--> observed active theme identity
        +--> file/link synchronization health

jc-theme catalog --json
        |
        v
ThemeService
        |
        +--> installed theme catalog
        +--> semantic preview metadata
        +--> MAIN / SECONDARY wallpaper preview inputs
```

The service performs a sequential `status -> catalog` read and accepts the
snapshot only when both payloads report the same active theme. A one-time retry
handles a theme switch that races the read boundary.

The committed observed snapshot exposes:

```text
themes
themeCount
activeThemeId
activeFileThemeId
activeLinkThemeId
synchronized
activeThemeValid
activeThemePath
activeMetadataFile
activeTheme
observedHealthy
ready
loading
errorMessage
```

`themeById(id)` provides lookup without requiring future feature views to parse
the raw catalog.

### Ownership

`ThemeService` may execute only:

```text
jc-theme status --json
jc-theme catalog --json
```

It must not:

```text
write local/active-theme
replace ~/.config/jc-hyprland-dotfiles/theme
invoke jc-theme apply
reload Hyprland
restart Waybar / SwayNC
apply wallpapers
synchronize SDDM
```

`Theme.qml` remains a separate semantic runtime API. It still observes
`local/active-theme` through `FileView` and is not coupled to `ThemeService`.

`Main.qml` owns the production `ThemeService` instance and exposes a stable
`themeServiceHandle` for the future Themes module.

Phase 2C.1c still does not enable Themes navigation and introduces no draft or
Apply behavior.
