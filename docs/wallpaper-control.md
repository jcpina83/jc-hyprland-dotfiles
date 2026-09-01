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

## Phase 2B.6 closure — fit and automatic rotation

Phase 2B.6 is complete. The Wallpapers module now owns transactional wallpaper
fit plus automatic-rotation editing without moving backend responsibility into
feature presentation QML.

```text
2B.6.1 Transactional wallpaper fit API                  ✓
2B.6.2 Wallpaper fit draft UI                           ✓
2B.6.3 Transactional automatic-rotation API             ✓
2B.6.4 Rotation observed state, draft and Apply service ✓
2B.6.5 Visible rotation controls + unified Apply/Reset  ✓
2B.6.6 End-to-end validation + documentation            ✓ COMPLETE
```

The final mutation flow is:

```text
WallpaperView
    |
    v
WallpaperDraftStore
    |
    v
WallpaperMutationCoordinator
    |                         |
    v                         v
WallpaperApplyService     WallpaperRotationApplyService
    |                         |
    v                         v
jc-wallpaperctl apply     jc-wallpaperctl rotation apply
```

There is one user-level Apply/Reset workflow for Wallpapers, but two explicit
mutation domains. Wallpaper/path-fit changes and automatic-rotation changes
remain independently dirty and independently reconciled.

For a combined draft, the coordinator commits wallpaper/path-fit first. Only
after its authoritative observed-state refresh has reconciled that domain does
the rotation transaction start. A failure or rollback in the first domain stops
the second transaction. Recovery Reset delegates to the mutation owner that
requires recovery and, when both domains require recovery, visits both owners
before accepting the final observed draft baseline.

`WallpaperRotationControl.qml` is presentation-only. It exposes Enabled, Mode,
Target and Interval intent and does not own `Process`, `jc-wallpaperctl`,
`systemctl`, `wallpaper.env`, the configurator, or an internal manager.
`WallpaperMutationCoordinator.qml` is orchestration-only and owns none of those
backend details either.

The Phase 2B.6 end-to-end closure test exercised the real path from the QML
coordinator through `WallpaperRotationApplyService`, the stable public CLI,
transactional manager and systemd runtime:

```text
random -> next -> random
```

Both mutations committed and reconciled back to a clean observed/draft state at
`true / random / both / 15m`, with the timer loaded, enabled, active, waiting and
runtime synchronization true.

Successful rotation mutations may canonicalize the textual representation of
the four managed `WALLPAPER_ROTATION_*` assignments. All unrelated
`wallpaper.env` bytes remain preserved. Exact byte restoration remains a
transactional rollback guarantee because rollback restores the captured file
snapshot. Once the managed assignments are canonical, the successful
change-and-restore round trip is byte-stable.

This closes Phase 2B.6 only. Phase 2B Wallpapers remains active; the next
Wallpapers work continues in Phase 2B.7.

## Automatic rotation visual refinement

The post-2B.6 presentation refinement keeps the established rotation
draft/Apply contract unchanged while making the automatic-rotation panel more
compact and legible.

Mode and Target options now carry semantic JC Holo icons through
`JcChoiceGroup`. Mode uses the existing refresh/all vocabulary for sequential
and random behavior. MAIN and SECONDARY use the display semantic; BOTH uses the
all-target semantic.

Interval editing uses the shared `JcSlider` instead of a row of preset buttons.
The slider covers 5–60 minutes in five-minute steps and exposes reference marks
for `5m`, `15m`, `30m`, and `1h`. The exact existing draft value remains visible
above the slider. A non-preset value such as `45m` remains intact until the user
actually moves the slider; values outside the visual 5–60 minute range are also
shown as custom instead of being silently rewritten.

The Control Center shell owns the content viewport boundary and clips hosted
module rendering before the footer. The wallpaper gallery therefore does not
use a child-level footer margin. Its minimum height and grid-cell height adapt
to the remaining content space so the visible first row stays above the shell
footer instead of forcing the feature view through it.

This refinement is presentation-only. It does not change
`WallpaperDraftStore`, `WallpaperMutationCoordinator`, either Apply service,
`jc-wallpaperctl`, persistence, rotation systemd state, or the single
Wallpapers Apply/Reset workflow.

## Automatic rotation tile layout

The approved JC Holo rotation composition uses a compact three-zone panel:

```text
Mode            | Target                    | Interval
Next / Random   | MAIN / SECONDARY / BOTH  | 5m ... 1h slider
```

Mode and Target use the shared `JcSettingTile` presentation primitive with a
semantic icon above the label. The rotation component still emits only the
existing `modeSelected(...)`, `targetSelected(...)`, `enabledSelected(...)`,
and `intervalSelected(...)` intent signals; no backend ownership moved into
presentation.

The panel height is intentionally compact so Library keeps enough of the shell
content viewport for a complete first wallpaper row. Target previews use a
slightly shorter fixed presentation row, the fit row is reduced to its actual
control content height, and the Library gallery regains a 2.95-control-height
minimum with 2.55–3.05 adaptive cells.

The shell clipping invariant remains the final safety boundary, but normal
Wallpapers layout is expected to fit above the footer without depending on
clipping to hide content.

## Rotation inner-clearance and Fit proximity refinement

The final tile-panel geometry keeps the approved icon-over-label composition
while reserving explicit clearance between the Mode/Target controls and the
lower JC Holo frame edge.

Compact `JcSettingTile` instances use a 0.98-control-height body and the
rotation content row reserves an additional `spaceXs` bottom margin inside the
HUD. The panel external height is unchanged, so Library keeps the vertical
space recovered by the previous layout pass.

The Wallpapers main content spacing uses `spaceSm`. The Fit row uses one
control-height and both `WallpaperFitControl` instances keep their natural
height aligned to the top of that row. This moves Fit / Fill / Stretch / Center
closer to the monitor previews without changing their interaction contract.

Library remains at the accepted 2.95-control-height minimum with adaptive
2.55–3.05 cells, and `ControlCenterShell.contentHost` remains the footer
clipping safety boundary.

## Rotation HUD final breathing room

The compact Fit/layout pass recovered enough vertical budget to expand the automatic-rotation HUD instead of shrinking its controls further.

`WallpaperRotationControl` now uses a 3.70-control-height presentation footprint and reserves `spaceSm` below the Mode / Target / Interval body row. Compact `JcSettingTile` instances remain at 0.98-control-height, so the added space is frame clearance rather than larger controls.

Library, previews, Fit controls, footer clipping, draft, Apply, persistence, and runtime contracts are unchanged by this refinement.

## Transactional transition backend

Phase 2B.7.1b introduces `wallpaper-transition-manager.sh` as the internal
machine-local owner of wallpaper transition persistence.

The backend owns only the active `WALLPAPER_TRANSITION_PRESET`,
`WALLPAPER_TRANSITION_TYPE`, `WALLPAPER_TRANSITION_DURATION` and
`WALLPAPER_TRANSITION_FPS` assignments in
`~/.config/jc-hyprland-dotfiles/local/wallpaper.env`.

`TYPE`, `DURATION` and `FPS` are optional overrides. Internally,
`__INHERIT__` removes an explicit override so the selected preset supplies the
effective value.

Rotation and transition are separate mutation domains but write the same
machine-local file. `wallpaper-rotation-manager.sh` and
`wallpaper-transition-manager.sh` therefore share the global
`.wallpaper-env.mutation.lock`.

A transition transaction also acquires the active theme wallpaper mutation
lock before re-applying the current wallpaper runtime. This serializes a
transition change against gallery Apply and automatic wallpaper rotation while
the transition configuration is being verified.

The transaction takes a byte-for-byte snapshot of `wallpaper.env`, rewrites
only active transition assignments, preserves unrelated bytes, then invokes
the existing `apply-wallpaper.sh` runtime. Failure restores the exact snapshot
and re-applies the previous runtime configuration.

Exit code `6` means rollback was verified. Exit code `7` means the exact
configuration snapshot was restored but runtime rollback could not be
verified.

This phase intentionally exposes no new QML mutation path and no public
transition command. Stable `jc-wallpaperctl transition ...` routing belongs to
Phase 2B.7.1c.

## Stable transition CLI API

Phase 2B.7.1c exposes transition state and mutation only through the stable
user-facing wallpaper CLI:

```text
jc-wallpaperctl transition status [--json]

jc-wallpaperctl transition apply
    [--preset theme|default|fade|cyber-noir|odyssey-glass]
    [--type inherit|none|simple|fade|left|right|top|bottom|wipe|wave|grow|center|any|outer|random]
    [--duration inherit|<seconds>]
    [--fps inherit|<integer>]
    [--json]
```

Omitted Apply fields use the backend `__KEEP__` contract. The public
friendly `inherit` value for type, duration and FPS is translated to the
internal `__INHERIT__` sentinel, removing that explicit override and returning
the field to preset ownership.

`transition status --json` returns preset, resolved preset, optional overrides,
effective type/duration/FPS and the machine-local configuration path.

`transition apply --json` suppresses successful runtime logs and returns the
same canonical status JSON after commit. Transaction failure preserves the
backend exit code, including verified rollback code `6` and rollback
verification failure code `7`.

`jc-wallpaperctl` never edits `wallpaper.env`; mutation remains delegated to
`wallpaper-transition-manager.sh`.

The transition manager is installed only in the internal runtime bin layer.
The existing public `jc-wallpaperctl` entry point remains the sole public
wallpaper mutation CLI.

QML integration remains deferred to Phase 2B.7.2.

## Observed transition state

Phase 2B.7.2b extends `WallpaperService` with canonical read-only transition
state sourced exclusively through the stable public API.

The refresh chain is:

```text
jc-wallpaperctl status --json
        |
        v
jc-wallpaperctl transition status --json
        |
        v
jc-wallpaperctl catalog --json
        |
        v
WallpaperService.commitSnapshot(...)
```

The service now observes the selected preset, resolved preset, nullable
type/duration/FPS overrides, and effective type/duration/FPS values.

A nullable override is intentionally preserved as `null`; QML does not
collapse inherited state into the effective value. This distinction is needed
by the next Draft phase so `inherit` remains a first-class user choice.

The general wallpaper status and dedicated transition status must report the
same transition preset during one refresh. A mismatch is treated as a
concurrent refresh conflict and the snapshot is not committed.

`WallpaperService` remains read-only and references neither `wallpaper.env`
nor the internal transition manager. Draft, Apply, coordinator and visual
transition controls remain unchanged in this subphase.

## Transition draft and reconcile foundation

Phase 2B.7.2c adds transition draft ownership to `WallpaperDraftStore` while
keeping transition mutation unavailable to the existing Apply coordinator.

The draft stores the selected preset plus nullable type, duration and FPS
overrides. `null` remains the canonical draft representation of inherited
preset ownership; setters also accept the presentation-friendly `inherit`
value and normalize it back to `null`.

The store tracks baseline transition configuration separately from derived
observed values. Resolved preset and effective type/duration/FPS are retained
in the baseline so an external theme or transition-resolution change can be
detected while any draft is dirty.

`transitionDirty` is intentionally not folded into the existing `dirtyCount`
or `hasDirty` yet. Those properties currently describe domains with an Apply
owner. `hasAnyDraftDirty` includes transition state and is used by refresh
conflict/reconciliation logic so a pending transition draft cannot be silently
overwritten by an observed refresh.

A dedicated transition refresh domain and `resetTransition()` lifecycle are
prepared for the future Apply service, but no process, CLI mutation or
coordinator sequencing is introduced here.

Phase 2B.7.3 will add the transition Apply owner and then promote
`transitionDirty` into the single global Apply/Reset workflow.

## Transition Apply service

Phase 2B.7.3b introduces `WallpaperTransitionApplyService.qml` as the QML
mutation owner for transition drafts. It invokes only the stable public
`jc-wallpaperctl transition apply` API and contains no direct access to the
internal transition manager or `wallpaper.env`.

Dirty fields map independently:

```text
transitionPresetDirty    -> --preset <preset>
transitionTypeDirty      -> --type <type|inherit>
transitionDurationDirty  -> --duration <seconds|inherit>
transitionFpsDirty       -> --fps <integer|inherit>
                              + --json
```

A `null` draft override is translated back to the public `inherit` vocabulary.
Successful transactions call
`prepareForRefreshAfterTransitionApply()`, refresh `WallpaperService`, and
emit `applied()` only after the observed transition snapshot matches the
canonical status returned by the public CLI.

The backend rollback exit contract is preserved across QML. Exit code `6`
means rollback was verified, keeps the transition draft pending, and does not
require recovery. Exit code `7` marks `rollbackRecoveryRequired` because the
configured state was restored but runtime rollback could not be verified.

Recovery Reset does not touch private backend state. The service re-applies
the currently observed transition configuration through the same stable
public API. Only a successful recovery transaction (`rc=0`) proceeds to an
observed refresh and then `resetTransition()`.

A recovery attempt returning exit code `6` does **not** clear recovery state.
That code proves only that the failed recovery attempt rolled back to the
runtime that existed before the attempt; after an earlier exit code `7`, that
previous runtime is exactly the state whose correctness was not verified.

This subphase does not yet add the service to `Main.qml`, does not promote
`transitionDirty` into global `dirtyCount`, and does not change the unified
coordinator. Those changes belong to Phase 2B.7.3c.

## Unified transition sequencing

Phase 2B.7.3c installs `WallpaperTransitionApplyService` into the existing
single Apply/Reset workflow.

The unified Apply order is:

```text
Wallpaper -> Transition -> Rotation
```

Each domain is skipped when it is clean. A transition-only draft therefore
runs only `WallpaperTransitionApplyService`, and a rotation-only draft keeps
the existing Rotation path. When multiple domains are dirty, each successful
owner completes its authoritative observed refresh before the next owner is
started.

The first failing domain stops the sequence. Any later dirty domains remain
pending and are not mutated implicitly.

`transitionDirty` is now part of `WallpaperDraftStore.dirtyCount`, so
`hasDirty` again describes every wallpaper mutation domain that has an
installed Apply owner. `hasAnyDraftDirty` remains as the refresh-protection
semantic alias and now resolves directly to `hasDirty`.

Recovery Reset uses the same ownership order:

```text
Wallpaper recovery -> Transition recovery -> Rotation recovery -> draft reset
```

The coordinator understands service state only. It never invokes
`jc-wallpaperctl`, reads `wallpaper.env`, or references an internal manager.

`Main.qml` owns all three mutation services and injects them into
`WallpaperMutationCoordinator`. `WallpaperView` still receives only that
coordinator, preserving one Apply/Reset surface.

No visible transition selector is introduced in this phase. Presentation
remains deferred to Phase 2B.7.4.

## JC Holo transition control surface

Phase 2B.7.4b adds a dedicated `WallpaperTransitionControl` immediately before
Automatic Rotation in `WallpaperView`.

The default compact surface exposes **Preset, Effect and Duration**. Effect
and Duration both include an explicit `Inherit preset` choice so the UI keeps
the DraftStore's nullable override semantics instead of replacing inherited
state with an effective value.

The header always shows the canonical observed result:

```text
Observed <preset -> resolved preset> · <effect> · <duration> · <FPS>
```

A Draft chip follows the same visual convention as Rotation. The frame also
uses the draft state as its secondary JC Holo accent.

FPS is intentionally treated as **Advanced**. The advanced row is collapsed
by default to keep the 1080x820 Control Center compact, but remains visible
when an FPS override already exists or the FPS draft is dirty. Practical FPS
values are provided while preserving an externally configured custom value.

Duration uses a compact combo rather than a slider. This keeps `inherit` a
first-class selection and avoids adding a second toggle solely to distinguish
preset ownership from a numeric override. Common transition durations are
listed and an existing custom duration is preserved as an additional option.

`WallpaperTransitionControl` is presentation-only. It emits selection signals;
`WallpaperView` maps those signals to the existing `WallpaperDraftStore`
setters. It has no Process, public CLI invocation, Apply service reference, or
backend knowledge.

The existing **single Apply/Reset** surface remains authoritative for
Wallpaper, Transition and Rotation. No second transition-specific Apply or
Reset action is introduced.

Phase 2B.7.4 visual validation and polish follow after this structural control
surface is exercised in the live Control Center.

## Wallpapers hosted overflow

Phase 2B.7.4c3 gives the Wallpapers module a hosted overflow model derived
from the proven Displays pattern without nesting two vertical scroll owners
over the wallpaper catalog.

The upper wallpaper **settings Flickable** owns vertical overflow for preview
cards, fit controls, Transition and Automatic Rotation. Its content height is
the settings `ColumnLayout.implicitHeight`, so expanding Transition Advanced
or adding future settings no longer forces Library through the Control Center
footer.

The Library header and **Library GridView** remain outside that Flickable.
The catalog therefore keeps its own virtualized GridView and vertical
scrollbar for hundreds of wallpapers. Settings scrolling and catalog
scrolling have **separate vertical scroll ownership**.

The Library gallery keeps a compact one-row-oriented viewport while its
existing GridView scrollbar exposes the full catalog.

`WallpaperTransitionControl` also retires fixed collapsed/Advanced height
multipliers. Its root height is now **content-driven** from
`transitionContent.implicitHeight` plus semantic margins, allowing ComboBox
rows and the Advanced FPS row to stay inside the HUD naturally.

No controls were shrunk and no mutation ownership changed.

## Phase 2B.7 closure

Phase 2B.7 is formally **CLOSED**.

The final transition contract is:

```text
WallpaperTransitionControl
        |
        v
WallpaperView
        |
        v
WallpaperDraftStore
        |
        v
WallpaperMutationCoordinator
        |
        v
WallpaperTransitionApplyService
        |
        v
jc-wallpaperctl transition apply
        |
        v
transactional transition manager
```

The authoritative unified mutation order is:

```text
Apply:    Wallpaper -> Transition -> Rotation
Recovery: Wallpaper -> Transition -> Rotation
```

Transition configuration supports:

- preset: `theme`, `default`, `fade`, `cyber-noir`, `odyssey-glass`
- effect override: explicit type or inherited preset value
- duration override: positive seconds or inherited preset value
- FPS override: positive integer or inherited preset value
- canonical observed effective type/duration/FPS
- transactional rollback with differentiated `rc=6` / `rc=7`
- UI draft Reset without runtime mutation
- one global Apply/Reset surface
- content-driven Transition HUD geometry
- independently scrollable Wallpapers settings and Library catalog

The closure gate confirmed the expected baseline:

```text
preset:         theme
resolvedPreset: default
effect:         fade
duration:       1.2 s
fps:            60
rotation:       enabled / random / both / 15m / synchronized
```

No additional Transition mutation owner, second Apply/Reset surface, direct
QML backend access, or nested Library scroll ownership is part of the closed
2B.7 architecture.

## Phase 2B overall closure

Phase 2B — **Wallpapers** is complete.

The module now provides the complete roadmap scope:

```text
MAIN / SECONDARY preview and selection
    + per-output fit / presentation
    + transactional Apply / Reset
    + automatic rotation
    + transition presets and overrides
    + observed / draft / applied / runtime reconciliation
    + JC Holo presentation
    + hosted settings overflow
    + independent virtualized Library scrolling
```

The final mutation composition remains:

```text
Wallpaper -> Transition -> Rotation
```

for both normal Apply sequencing and recovery sequencing, while preserving one
global Apply/Reset interaction surface.

Phase 2B is **CLOSED**. The next Control Center module in the project roadmap
is **Phase 2C — Themes**.
