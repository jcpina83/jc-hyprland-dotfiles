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


## Wallpaper gallery interaction polish

Phase 2B.3.2 refines the draft-only gallery without changing the wallpaper
runtime contract.

Interaction semantics:

- MAIN and SECONDARY preview cards expose the active selection target.
- The gallery marks the effective wallpaper for the active target as
  `CURRENT`.
- A draft choice is marked `DRAFT` and takes visual precedence over
  `CURRENT`.
- The `GridView` owns keyboard focus and arrow-key navigation.
- Enter or Space selects the keyboard-current wallpaper into the active
  QML-only draft.
- Home and End jump to the first and last visible catalog entries.
- Mouse activation moves the keyboard-current index to the clicked tile.
- The current scroll position is preserved when switching MAIN/SECONDARY
  because changing target does not rebuild the catalog model.
- Changing All / Theme / Library normalizes the current index only when the
  previous index is no longer valid.

Phase 2B.3.2 remains draft-only. It does not invoke wallpaper runtime commands,
write preference files, or introduce Apply behavior.


## Transactional wallpaper mutation API

Phase 2B.4.1 introduces the first stable mutation boundary:

```text
Wallpaper UI / future WallpaperApplyService
                |
                v
        jc-wallpaperctl apply
                |
                v
wallpaper-manager.sh transactional-set
                |
        +-------+-------+
        |               |
 preferences write   runtime apply
        |               |
        +-------+-------+
                |
         runtime verify
```

Public syntax:

```bash
jc-wallpaperctl apply --main /path/to/main.jpg
jc-wallpaperctl apply --secondary /path/to/secondary.jpg
jc-wallpaperctl apply \
  --main /path/to/main.jpg \
  --secondary /path/to/secondary.jpg \
  --json
```

A MAIN+SECONDARY request is one logical transaction. The manager validates
both requested paths before writing, writes the per-theme preferences once,
applies both outputs once, and treats runtime verification as part of the
apply operation.

`apply-wallpaper.sh` verifies both output/path pairs after `awww img` or
`hyprctl hyprpaper wallpaper`. If apply or verification fails,
`transactional-set` restores the exact previous preference snapshot and
re-applies the previous runtime state. If the rollback runtime itself fails,
the preferences remain restored and the command returns a distinct failure.

All mutating manager commands acquire the same per-theme `flock`, so timer
rotation and a future Control Center Apply cannot write/apply concurrently.

The stable wrapper never edits `local/wallpapers/<theme>.env` directly.
Existing legacy manager commands remain available for compatibility; the
Control Center mutation path must use `jc-wallpaperctl apply`.

Phase 2B.4.1 does not add an Apply button to QML. QML integration begins only
after this CLI transaction is validated.


## Wallpaper Apply service

Phase 2B.4.2 adds `WallpaperApplyService.qml` as the only Quickshell owner of
the stable wallpaper mutation API.

```text
WallpaperDraftStore
        |
        v
WallpaperApplyService.qml
        |
        v
jc-wallpaperctl apply ... --json
        |
        v
transactional backend
```

`WallpaperApplyService.qml` sends only dirty targets. MAIN-only drafts use
`--main`, SECONDARY-only drafts use `--secondary`, and a two-output draft is
sent as one `--main ... --secondary ...` invocation.

The service exposes `busy`, `canApply`, `errorMessage`, `statusMessage`, and
`lastResult`. A successful backend response must report `status=applied`,
`committed=true`, `rolledBack=false`, and `runtimeVerified=true`.

After a successful transaction, `WallpaperDraftStore.prepareForRefreshAfterApply()`
marks the next observed-state refresh as authoritative. That single refresh
may replace the old draft baseline with the newly observed effective state.
Ordinary refreshes while a draft is dirty keep the existing conflict
detection behavior.

A backend `rolled-back` response preserves the QML draft, exposes the failure,
and refreshes observed state without accepting it as a successful Apply.

`WallpaperApplyService.qml` may invoke only the stable `jc-wallpaperctl`
boundary. It does not know about `awww`, `hyprpaper`, preference files,
`wallpaper-manager.sh`, or rotation internals.

Phase 2B.4.2 wires the service into `Main.qml` but intentionally adds no Apply
button to `WallpaperView.qml`. UI activation belongs to Phase 2B.4.3.


## Wallpaper Apply UI integration

Phase 2B.4.3 connects the draft-only gallery to the Apply service without
moving process ownership into the view.

```text
WallpaperView.qml
    |
    | applyRequested()
    v
Main.qml
    |
    v
WallpaperApplyService.applyDirty()
    |
    v
jc-wallpaperctl apply
```

The Apply button appears whenever a wallpaper draft is pending and is enabled
only when `WallpaperApplyService.canApply` is true. During Apply and the
authoritative observed-state refresh, target switching, wallpaper activation,
filters, Reset, Refresh, navigation, and Control Center close are locked.

A successful flow is:

`Apply → backend → observed refresh → clean draft`.

The DraftStore post-Apply reconciliation makes the confirmed effective
wallpapers the new baseline, so MAIN-only, SECONDARY-only, and combined drafts
all return to `dirtyCount = 0` after the refresh completes.

If the transactional backend returns `rolled-back`, runtime and persisted
preferences have already been restored by the backend. The UI exposes the
failure and rollback keeps the draft pending so it may be reviewed, reset, or
retried.

`WallpaperView.qml` still owns no `Process`, shell command, wallpaper runtime,
or preference-file mutation. It only emits `applyRequested()`.

Phase 2B.4.3 completes the first end-to-end wallpaper Apply workflow. Manual
runtime validation covers MAIN-only, SECONDARY-only, and combined drafts.


## Wallpaper failure semantics

Phase 2B.4.4 makes the machine-readable Apply failure contract explicit.

`jc-wallpaperctl apply ... --json` now preserves JSON output for argument and
path validation failures as well as transactional failures.

The stable statuses are:

```text
applied
  committed=true
  rolledBack=false
  preferencesRestored=false
  runtimeRollbackVerified=false
  runtimeVerified=true

invalid-request
  committed=false
  rolledBack=false
  preferencesRestored=false
  runtimeRollbackVerified=false
  runtimeVerified=false

rolled-back
  committed=false
  rolledBack=true
  preferencesRestored=true
  runtimeRollbackVerified=true
  runtimeVerified=false

rollback-failed
  committed=false
  rolledBack=false
  preferencesRestored=true
  runtimeRollbackVerified=false
  runtimeVerified=false
```

`rollback-failed` is reserved for the manager's distinct recovery failure:
the previous preference snapshot was restored, but re-applying/verifying the
previous runtime state failed. It must never be reported as a successful
rollback.

`WallpaperApplyService.qml` exposes this state through
`rollbackRecoveryRequired`. While it is true, another Apply is blocked and
the Control Center reports that wallpaper recovery is required. The pending
draft is preserved and observed state is refreshed for inspection.

An `invalid-request` is a pre-mutation rejection and therefore does not mark
runtime recovery as required.

Phase 2B.4.4 closes the failure-semantics portion of the transactional
wallpaper Apply workflow.


## Reset / Apply lifecycle refinement

Phase 2B.5 refines QML state lifecycle without expanding the wallpaper
mutation backend.

Normal Reset is coordinated by `WallpaperApplyService.resetDraft()` and then
delegates to `WallpaperDraftStore.reset()`. Reset accepts the latest observed
effective wallpapers as the new draft baseline, including when
`observedChangedWhileDirty` is true.

Transient Apply feedback is cleared by `clearTransientFeedback()` when the
user starts a new wallpaper selection or completes a normal Reset. A previous
success, `invalid-request`, or fully rolled-back Apply therefore does not
dominate a new editing session.

A recovery-required Reset is intentionally different:

```text
rollbackRecoveryRequired
        |
        v
Refresh & Reset
        |
        v
WallpaperService.refresh()
        |
        +-- runtimeMatchesConfigured=true
        |       |
        |       v
        |   clear recovery flag
        |   reset draft to observed baseline
        |
        +-- runtimeMatchesConfigured=false
                |
                v
            keep recovery flag
            keep draft pending
            Reset is not performed
```

The button is labeled `Refresh & Reset` while recovery is required. It never
claims that a failed runtime rollback was repaired merely because the draft
was discarded.

If the recovery refresh itself fails, `rollbackRecoveryRequired` stays true
and the draft remains pending for inspection.

`WallpaperView.qml` emits `resetRequested()`; `Main.qml` routes it to
`WallpaperApplyService.resetDraft()`. The view does not own recovery logic.

Phase 2B.5 completes Reset / Apply lifecycle refinement.


## Transactional wallpaper fit API

Phase 2B.6.1 extends `jc-wallpaperctl apply` with per-output fit
configuration while preserving the existing transaction/rollback boundary.

Canonical values are `cover`, `contain`, `stretch`, and `center`.

For `awww`: `cover -> crop`, `contain -> fit`, `stretch -> stretch`,
and `center -> no`.

`runtimeVerified` continues to verify the observed wallpaper paths.
The current runtime read boundary does not report resize mode, therefore
`fits.runtimeReadbackAvailable=false`; fit is command-verified and
visually validated rather than falsely reported as runtime-readback verified.

Examples:

```bash
jc-wallpaperctl apply --main-fit contain --json
jc-wallpaperctl apply --main-fit contain --secondary-fit cover --json
```

Phase 2B.6.2 adds fit draft state and per-output Control Center selectors.


## Wallpaper fit draft UI

Phase 2B.6.2 integrates the transactional fit API into the wallpaper draft
model and Control Center.

`WallpaperDraftStore.qml` tracks wallpaper-path and presentation-mode changes
independently. `mainDirty` and `secondaryDirty` remain output-level aggregate
flags, while `mainWallpaperDirty`, `secondaryWallpaperDirty`, `mainFitDirty`,
and `secondaryFitDirty` identify which Apply arguments are required.

Fit selection remains draft-only. `WallpaperView.qml` and
`WallpaperFitControl.qml` never invoke `awww`, `hyprpaper`, `systemctl`, or
`jc-wallpaperctl` directly. `WallpaperApplyService.qml` includes only changed
arguments in the existing transactional Apply request.

The UI exposes four canonical presentation choices per output:

- `Fit` -> `contain`
- `Fill` -> `cover`
- `Stretch` -> `stretch`
- `Center` -> `center`

Reset restores both wallpaper and fit drafts to the accepted observed baseline.
An observed wallpaper or fit change while editing raises the existing
`observedChangedWhileDirty` conflict instead of silently replacing the draft.

Phase 2B.6.2 does not add rotation mutation controls.


## Rotation mutation API

Phase 2B.6.3 adds a stable mutation boundary for automatic wallpaper rotation.

Public API:

```text
jc-wallpaperctl rotation status
jc-wallpaperctl rotation status --json
jc-wallpaperctl rotation apply [--enabled true|false] [--mode next|random]
                               [--target main|secondary|both]
                               [--interval <systemd-timespan>] [--json]
```

`wallpaper-rotation-manager.sh` owns machine-local rotation persistence in
`local/wallpaper.env`. It edits only the four `WALLPAPER_ROTATION_*` keys and
preserves the rest of the wallpaper configuration.

Shell-safe rotation values are serialized in a canonical form. Successful mutations may normalize the textual representation of the four managed rotation assignments, while all unrelated `wallpaper.env` content is preserved. Byte-for-byte restoration is required for transactional rollback because rollback restores the captured file snapshot.

The transaction snapshots `wallpaper.env`, writes rotation state atomically,
runs `configure-wallpaper-rotation.sh`, verifies the timer drop-in and systemd
lifecycle, and commits only when runtime state is synchronized.

On failure it restores `wallpaper.env` and re-runs the configurator. Exit code
`6` means rollback was verified. Exit code `7` means the configuration file was
restored but runtime rollback could not be verified.

`jc-wallpaperctl status --json` preserves `rotation.enabled`, `rotation.mode`,
`rotation.target`, and `rotation.interval`, and adds `rotation.runtime`.

QML does not call systemctl, edit wallpaper.env, or invoke the rotation
configurator. Future rotation UI uses only the stable jc-wallpaperctl boundary.


## Rotation observed and draft foundation

Phase 2B.6.4a extends the existing wallpaper state boundary before exposing
rotation controls.

`WallpaperService.qml` remains read-only and now retains the complete
`rotation.runtime` synchronization snapshot returned by
`jc-wallpaperctl status --json`.

`WallpaperDraftStore.qml` remains the single wallpaper editing store, with two
explicit draft domains:

```text
wallpaper: MAIN/SECONDARY path + fit
rotation:  enabled + mode + target + interval
```

`hasWallpaperDirty` isolates the existing wallpaper/path-fit Apply path.
`rotationDirty` aggregates the four rotation draft fields. Aggregate `hasDirty`
continues to cover the whole Wallpapers module.

Post-Apply reconciliation is domain-aware: a wallpaper Apply refresh updates
only wallpaper/path-fit baseline state, while
`prepareForRefreshAfterRotationApply()` reserves the equivalent rotation-only
reconciliation path for the rotation mutation service.

Phase 2B.6.4a adds no visible rotation controls and performs no rotation
mutation. The rotation Apply service is introduced in the next 2B.6.4 step.


## Rotation Apply service

Phase 2B.6.4b introduces `WallpaperRotationApplyService.qml` as the sole
Quickshell owner of the stable rotation mutation API.

```text
WallpaperDraftStore.rotationDirty
        |
        v
WallpaperRotationApplyService.qml
        |
        v
jc-wallpaperctl rotation apply ... --json
        |
        v
transactional rotation backend
```

Only dirty rotation fields are emitted as CLI arguments: `--enabled`, `--mode`,
`--target`, and/or `--interval`.

The service accepts successful `applied` and `reconciled` responses only when
the backend reports `committed=true`, `rolledBack=false`,
`runtimeVerified=true`, and synchronized rotation runtime state.

`rolled-back` keeps the rotation draft pending and refreshes observed state.
`rollback-failed` marks rotation recovery as required because configuration was
restored but runtime rollback could not be verified. Recovery Reset first
refreshes observed state and accepts it only when
`WallpaperService.rotationRuntimeSynchronized` is true.

`Main.qml` owns the service instance and includes its busy/recovery state in
Control Center transition and status orchestration.

The service invokes only the stable `jc-wallpaperctl` command. It contains no
direct timer lifecycle, persistence-file, configurator, or internal rotation
manager access.

Phase 2B.6.4b still adds no visible rotation controls. UI routing belongs to
Phase 2B.6.5.


## Unified wallpaper mutation coordinator

Phase 2B.6.5a introduces `WallpaperMutationCoordinator.qml` before the visible
rotation controls are activated.

`WallpaperView.qml` keeps one Apply/Reset interaction surface. That surface no
longer points directly at `WallpaperApplyService`; it points at the coordinator:

```text
WallpaperView
    |
    | Apply / Reset
    v
WallpaperMutationCoordinator
    |                     |
    v                     v
WallpaperApplyService     WallpaperRotationApplyService
    |                     |
    v                     v
jc-wallpaperctl apply     jc-wallpaperctl rotation apply
```

A wallpaper-only draft uses only `WallpaperApplyService`. A rotation-only draft
uses only `WallpaperRotationApplyService`. When both domains are dirty, the
coordinator applies wallpaper/path-fit first. After its authoritative observed
refresh completes, the still-pending rotation draft is applied second.

If the first domain rolls back, fails, or enters recovery-required state, the
second domain is not started and remains pending for review.

Reset is also unified. Without a recovery sentinel it accepts the current
observed state for both draft domains. If a service reports rollback recovery
required, that service performs its verified refresh/reset lifecycle first;
the coordinator then completes the module-level Reset without bypassing either
service's recovery semantics.

The coordinator owns orchestration only. It has no `Process`, does not invoke
`jc-wallpaperctl`, does not edit wallpaper configuration, and does not manage
systemd units.

Visible automatic-rotation controls remain deferred to Phase 2B.6.5b.


## Automatic rotation JC Holo controls

Phase 2B.6.5b makes the rotation draft visible inside `WallpaperView.qml`
without adding another Apply/Reset workflow.

`WallpaperRotationControl.qml` is presentation-only. It receives values and
emits intent signals; it does not own `WallpaperDraftStore`,
`WallpaperService`, an Apply service, a process, or a backend command.

The JC Holo panel exposes:

```text
Automatic rotation
  Enabled   on/off
  Mode      next | random
  Target    main | secondary | both
  Interval  5m | 15m | 30m | 1h | current custom value
```

The interval selector preserves an already-observed custom interval by adding
that value to the local choice model when it is not one of the standard
presets.

`WallpaperView.qml` maps these presentation signals only to
`WallpaperDraftStore.setRotationEnabled()`, `setRotationMode()`,
`setRotationTarget()`, and `setRotationInterval()`. No runtime change happens
until the existing top-level Apply button invokes
`WallpaperMutationCoordinator`.

The panel displays both draft intent and observed runtime health:
`Draft` appears while `rotationDirty=true`, while the runtime chip reflects
`WallpaperService.rotationRuntimeSynchronized`.

During Apply/reconciliation, or while an observed-state conflict is pending,
the rotation controls are locked consistently with wallpaper selection and fit
controls. Reset remains available through the unified module lifecycle.

Phase 2B.6.5c validates the visible panel and coordinator lifecycle in an
isolated Quickshell runtime before the phase is staged.
