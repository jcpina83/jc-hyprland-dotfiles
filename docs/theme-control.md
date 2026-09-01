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

## Phase 2C.1d — ThemeDraftStore selection/baseline foundation

`ThemeDraftStore.qml` introduces the draft state required by the future Themes
module without enabling mutation.

The state model is deliberately small because theme selection is one atomic
choice:

```text
ThemeService.activeThemeId
        |
        v
baselineThemeId
        |
        +-----------------------+
        |                       |
        v                       v
draftThemeId                dirty
                                |
                                v
                  future ThemeApplyService
```

The store exposes:

```text
draftThemeId
baselineThemeId
initialized
dirty
hasDirty
dirtyCount
draftTheme
baselineTheme
draftValid
observedChangedWhileDirty
```

`setTheme(id)` accepts only IDs present in the observed `ThemeService` catalog.
It changes draft state only.

`reset()` discards the draft and adopts the current observed active theme as
both baseline and draft. It does not invoke the backend.

### External observed changes

When `ThemeService` refreshes:

- a clean store follows the newly observed active theme;
- a dirty store preserves the user's draft;
- if the observed active theme changed away from the draft baseline,
  `observedChangedWhileDirty` becomes true.

This preserves user intent while making external runtime changes visible.

No Apply reconciliation is introduced yet. That lifecycle belongs to the
future mutation service after the public theme Apply contract is hardened.

### Production ownership

`Main.qml` owns one `ThemeDraftStore` and injects the production
`ThemeService`. It also exposes `themeDraftStoreHandle` for the future Themes
view.

Phase 2C.1d does not enable Themes navigation and does not create a Theme view.

## Phase 2C.2b — Transactional Theme Apply backend

The public Theme Control mutation boundary is now:

```text
jc-theme apply THEME [--json]
```

`jc-theme` remains the stable public command. It delegates mutation ownership
to the internal `theme-transaction-manager.sh`; QML must never invoke that
internal manager directly.

### Transaction-critical state

A theme transaction commits only after all required desktop state is verified:

```text
active theme symlink + local/active-theme
        |
        v
Hyprland reload + clean configerrors
        |
        v
wallpaper runtime Apply + verification
        |
        v
Waybar restart + process verification
        |
        v
SwayNC restart when it was running
        |
        v
active identity re-verification
        |
        v
COMMIT
```

`Theme.qml`, Hyprlock, Foot and launch-time consumers do not need a separate
mutation command; they consume the committed active-theme authority.

### Concurrency

Theme mutation acquires:

```text
local/.theme.mutation.lock
        |
        v
local/.wallpaper-env.mutation.lock
        |
        v
old/new per-theme wallpaper mutation locks
```

The wallpaper locks are acquired in the same global-before-per-theme order
used by transition mutation, and old/new theme locks are ordered
deterministically.

### Snapshot and rollback

Before mutation the manager requires a healthy synchronized current theme and
captures exact `local/active-theme` bytes, the exact active-theme symlink
payload and the previous active theme identity.

The manager writes the new symlink before the watched active-theme file so
`Theme.qml` is not told about a new theme before the shared active symlink is
ready.

If a critical runtime step fails, the previous symlink/file snapshot is
restored and the critical runtime is re-applied against the previous theme.

The stable exit contract follows the existing Wallpapers precedent:

```text
rc=0  applied
rc=2  invalid-request
rc=6  rolled-back
rc=7  rollback-failed
```

JSON responses expose `status`, `committed`, `changed`, `rolledBack`,
`identityRestored`, `runtimeVerified`, `runtimeRollbackVerified`,
`previousTheme`, `targetTheme`, per-consumer state, warnings and message.

### SDDM is auxiliary until its theme set is reconciled

SDDM is deliberately **not transaction-critical** in this phase.

The current privileged SDDM integration permits only `odyssey-glass` and
`cyber-noir`, while Theme Control also supports `jc-holo`. A successful desktop
theme transaction therefore cannot be rolled back merely because the
root-owned login-screen profile cannot synchronize.

After the desktop commit the manager attempts SDDM preparation and privileged
profile synchronization. Failures are reported in `warnings` and
`consumers.sddm`, while the desktop transaction remains committed.

A later SDDM reconciliation step must add full supported-theme parity before
Phase 2C claims warning-free complete desktop/login synchronization.

### QML boundary remains deferred

Phase 2C.2b adds no `ThemeApplyService`. The next layer may consume only:

```text
jc-theme apply THEME --json
```

after a controlled real theme round-trip validates Apply and rollback semantics.
