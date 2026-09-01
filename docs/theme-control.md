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

## Phase 2C.2b hardening — mutation lock FD inheritance

The first controlled real Apply exposed an important process-inheritance edge
case.

The transaction manager correctly held the theme and wallpaper `flock`
descriptors, but the Waybar and SwayNC launchers inherited those open file
descriptors. Their resident child processes therefore continued owning the
locks after the transaction manager exited.

The manager now uses one child execution boundary:

```text
run_without_mutation_locks
        |
        +--> close FD 9  theme mutation lock
        +--> close FD 8  wallpaper.env mutation lock
        +--> close FD 7  first per-theme wallpaper lock
        +--> close FD 6  second per-theme wallpaper lock
        |
        +--> exec consumer command
```

The transaction parent retains the locks for the whole transaction. Only the
consumer child closes its inherited copies.

This boundary is used for Hyprland commands, wallpaper Apply, Waybar, SwayNC
and auxiliary SDDM helpers. It prevents resident desktop processes from
extending mutation-lock lifetime beyond the transaction.

A post-Apply lock-leak sentinel is required after every successful Apply.
It must verify that no resident process retains any theme/wallpaper mutation
lock before the next transaction starts.

## Phase 2C — explicit Theme runtime recovery API

The QML recovery audit identified one backend gap before `ThemeApplyService`
can safely model `rollback-failed`.

A `rollback-failed` Apply may have restored the persistent active-theme
identity while one or more critical runtime consumers remain unverified.
`ThemeService.refresh()` cannot repair that condition because it observes
theme identity and catalog state, not the runtime state of Hyprland, wallpaper,
Waybar or SwayNC.

The stable public recovery boundary is therefore:

```text
jc-theme recover [--json]
```

Recovery is deliberately separate from same-theme Apply.

```text
jc-theme apply CURRENT_THEME --json
        -> existing no-op contract remains unchanged

jc-theme recover --json
        -> re-apply and verify current active theme runtime
```

This distinction prevents an ordinary no-change Apply from unexpectedly
restarting desktop consumers and gives QML an explicit recovery operation.

### Recovery preconditions and ownership

Recovery requires the current active file and active symlink to be synchronized
and the current theme to satisfy the normal theme validity contract.

It acquires the same theme and wallpaper coordination locks as Apply, but does
not rewrite either active identity representation.

The current active theme becomes both the previous and target runtime identity,
and the existing critical runtime boundary is executed:

```text
Hyprland reload + configerrors
        |
        v
wallpaper runtime Apply + verification
        |
        v
Waybar restart + verification
        |
        v
SwayNC restart when it was running
        |
        v
active identity verification
```

SDDM remains auxiliary and is synchronized only after critical desktop
recovery succeeds.

### Recovery result contract

Successful recovery:

```text
rc=0
status=recovered
committed=true
changed=false
rolledBack=false
identityRestored=false
runtimeVerified=true
runtimeRollbackVerified=false
```

Failed critical recovery:

```text
rc=7
status=recovery-failed
committed=false
changed=false
rolledBack=false
identityRestored=false
runtimeVerified=false
runtimeRollbackVerified=false
```

`invalid-request` with `rc=2` remains the pre-operation rejection for malformed
options or an unhealthy active identity.

A failed recovery does not attempt a second rollback transaction: the recovery
target is already the current persistent identity. The caller must keep
recovery mode active and allow another explicit recovery attempt after the
underlying runtime problem is corrected.

### Future ThemeApplyService recovery rule

After an Apply returns `rollback-failed`, QML must:

```text
rollbackRecoveryRequired = true
        |
        +--> block normal Apply
        +--> preserve draft
        +--> ThemeService.refresh() for inspection
        |
        +--> explicit Recovery action
                 |
                 v
           jc-theme recover --json
                 |
                 +--> recovered
                 |      -> ThemeService.refresh()
                 |      -> verify observed healthy current identity
                 |      -> clear recovery mode
                 |
                 +--> recovery-failed
                        -> keep recovery mode
```

A successful Recovery does not discard the user's pending draft. Reset remains
a separate user decision.

## Phase 2C — ThemeApplyService mutation foundation

`ThemeApplyService.qml` is the only QML owner of Theme mutation and runtime
recovery.

Its stable runtime boundary is limited to:

```text
jc-theme apply THEME --json
jc-theme recover --json
```

The service has no knowledge of active-theme files, symlinks, transaction
locks, Hyprland, wallpaper engines, Waybar, SwayNC, SDDM or the internal
transaction manager.

It receives two dependencies from `Main.qml`:

```text
ThemeService     observed authoritative feature state
ThemeDraftStore  pending user theme selection
```

### Apply eligibility

Normal Apply is allowed only when:

```text
ThemeService.ready
ThemeService.observedHealthy
!ThemeService.loading
ThemeDraftStore.initialized
ThemeDraftStore.dirty
ThemeDraftStore.draftValid
!ThemeDraftStore.observedChangedWhileDirty
!ThemeApplyService.busy
!ThemeApplyService.rollbackRecoveryRequired
```

An external observed-state change while the user has a draft therefore blocks
Apply until the draft is reset.

### Successful Apply reconciliation

A backend `rc=0 / status=applied` is not by itself QML success.

The lifecycle is:

```text
Apply
  |
  v
jc-theme apply DRAFT --json
  |
  v
backend applied + runtimeVerified
  |
  v
ThemeDraftStore.prepareForRefreshAfterApply(DRAFT)
  |
  v
ThemeService.refresh()
  |
  v
coherent observed active theme == requested theme
  |
  v
ThemeDraftStore adopts observed theme as baseline + draft
  |
  v
dirty=false
  |
  v
ThemeApplyService.applied()
```

The final success signal is emitted only after the authoritative observed
snapshot is healthy and the draft is clean against the requested theme.

### Apply failure semantics

`invalid-request` preserves the draft and does not require recovery.

`rolled-back` preserves the draft, refreshes `ThemeService`, requires the
observed active theme to match `previousTheme`, and reports that the previous
state was restored. Runtime recovery is not required when that reconciliation
succeeds.

`rollback-failed` preserves the draft, sets
`rollbackRecoveryRequired=true`, blocks normal Apply and refreshes observed
state only for inspection. A synchronized observed identity does not clear
recovery mode because the backend explicitly reported unverified runtime
rollback.

Unknown or structurally invalid Apply responses are treated conservatively as
requiring recovery before another Apply.

### Explicit QML Recovery lifecycle

When `rollbackRecoveryRequired=true`, the service exposes `canRecover` and
`recoverRuntime()`.

```text
recoverRuntime()
      |
      v
jc-theme recover --json
      |
      +--> recovered
      |       |
      |       v
      |   ThemeService.refresh()
      |       |
      |       v
      |   observed current identity verified
      |       |
      |       v
      |   rollbackRecoveryRequired=false
      |
      +--> recovery-failed
              |
              v
          keep recovery mode
```

A successful Recovery deliberately preserves the user's pending theme draft.
Recovery repairs runtime; Reset remains a separate future UI action.

### ThemeDraftStore post-Apply state

`ThemeDraftStore` now exposes an internal one-refresh reconciliation marker:

```text
syncAfterApplyPending
syncAfterApplyThemeId
prepareForRefreshAfterApply(themeId)
```

Only the next `ThemeService.refreshed()` after a successful Apply may consume
that marker and force the observed requested theme to become the clean
baseline/draft pair. Ordinary refreshes while dirty continue preserving user
intent and conflict detection.

### Composition boundary

`Main.qml` owns one `ThemeApplyService`, injects `ThemeService` and
`ThemeDraftStore`, exposes `themeApplyServiceHandle`, and includes its `busy`
state in the global Control Center transition lock.

This phase intentionally does not create `ThemeView.qml` and does not enable
Themes navigation.

## Phase 2C.2.1 — ThemeView foundation

`modules/themes/ThemeView.qml` is now the first visual consumer of the Phase 2C
theme state model.

The Themes Control Center navigation entry is enabled and routes to ThemeView.
This foundation reads observed state from `ThemeService` and draft state from
`ThemeDraftStore`.

At this stage ThemeView is intentionally read-only:

- it displays the observed active theme,
- it exposes the installed-theme count,
- it reflects whether a draft is pending,
- it does not invoke Apply,
- it does not own runtime mutation or backend commands.

Theme preview cards, draft selection controls, Apply/Reset UI, and the final
visual treatment remain subsequent Phase 2C.2 work.

## Phase 2C.2.2 — Theme preview cards

The Themes module now renders the installed catalog as read-only preview cards.

`ThemePreviewCard.qml` consumes the real catalog structure already exposed
through `ThemeService.themes`:

- `id`
- `name`
- `colors`
- `preview.mainWallpaper`
- `preview.secondaryWallpaper`

The main wallpaper becomes the card's primary visual preview, while the
secondary wallpaper is shown as a smaller inset preview. Palette swatches are
derived from the theme's own `colors` object.

This phase remains intentionally read-only. Cards do not call
`ThemeDraftStore.setTheme()`, do not invoke Apply, and do not own runtime
mutation. ACTIVE/DRAFT selection semantics are introduced separately in
Phase 2C.2.3.

## Phase 2C.2.3 — ACTIVE / DRAFT selection state

Theme preview cards are now selectable, but selection remains draft-only.

A card exposes two independent visual states:

- `ACTIVE` means the theme is the currently observed desktop theme.
- `DRAFT` means the theme is the current pending selection in
  `ThemeDraftStore`.
- a theme may show both `ACTIVE` and `DRAFT` when the draft is synchronized
  with the observed state.

Selecting a card emits its theme ID to `ThemeView`, which delegates the state
change to `ThemeDraftStore.setTheme()`.

Selection does not apply the theme, does not call the `jc-theme` backend, and
does not mutate Hyprland, Waybar, SwayNC, wallpapers, or any runtime theme
state. Apply and Reset controls remain deferred to Phase 2C.2.5.

## Phase 2C.2.4 — Quickshell token visual preview

Theme cards now include a miniature semantic UI rendered from the candidate
theme's Quickshell token data.

`ThemeTokenPreview.qml` consumes the same catalog data originating from each
theme's `quickshell.json`:

- the common `colors` token object;
- the common `opacity` token object;
- `schemaVersion`, `id`, and `name`.

The preview intentionally uses only the common schema-v1 token core shared by
all installed themes. Optional JC Holo HUD opacity extensions are not required
for the generic preview.

The miniature UI demonstrates candidate canvas, surfaces, text hierarchy,
brand accents, semantic state colors, selected surfaces, and border opacity.
Geometry, typography sizing, spacing, and radii continue to use the current
Theme API because those values are not theme-specific fields in the current
`quickshell.json` schema.

This remains preview-only behavior. Rendering a candidate theme does not apply
it, does not change `local/active-theme`, and does not invoke any theme backend.
ACTIVE/DRAFT chrome around the card continues to represent observed/draft
state independently from the candidate token rendering.
