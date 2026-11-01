# Media

## Phase 2F.1a — Stable runtime API

Phase 2F starts with a stable, read-only runtime boundary:

```bash
jc-media status
jc-media status --json
```

`jc-media` observes media and audio state without changing playback, volume,
mute state, PipeWire routing or device configuration.

### Player selection

Players are discovered dynamically through `playerctl` / MPRIS.

Selection is deterministic:

1. Exclude `playerctld` as a concrete player.
2. Prefer a player whose observed status is `Playing`.
3. Otherwise prefer `Paused`.
4. Otherwise use the first remaining real player.

The selected MPRIS instance is observed runtime state. Instance suffixes are
never persisted in repository configuration.

The status contract exposes metadata, position, duration and the MPRIS
capability flags `CanControl`, `CanPlay`, `CanPause`, `CanGoNext`,
`CanGoPrevious` and `CanSeek`. Future UI controls must honor these capability
flags instead of assuming every MPRIS implementation supports every action.

### Default audio

Audio is observed through PipeWire / WirePlumber using stable selectors:

```text
@DEFAULT_AUDIO_SINK@
@DEFAULT_AUDIO_SOURCE@
```

The API may report the currently observed node name or device description, but
those values are never used as persistent selectors.

Tracked implementation must not contain machine-local PipeWire node IDs, ALSA
card numbers, Bluetooth MAC addresses or concrete MPRIS instance suffixes.

### Schema

The JSON contract starts at `schemaVersion: 1` and is read-only.

Top-level fields are:

- `schemaVersion`
- `status`
- `readOnly`
- `dependencies`
- `player`
- `audio`

No active player is a valid state and is represented with
`player.available=false`. Optional unavailable enrichment is represented by
`null` rather than inventing values.

### Phase boundary

Phase 2F.1a implements observation only. Playback, seek, volume and mute
mutations are intentionally deferred to a later phase behind the same
`jc-media` stable CLI.

## Phase 2F.1b — Observed-state service

`MediaService.qml` is the read-only QML projection of
`jc-media status --json`.

The service owns no MPRIS, PipeWire or WirePlumber backend commands. Its only
runtime boundary is the stable managed command:

```text
~/.config/jc-hyprland-dotfiles/bin/jc-media status --json
```

The projection exposes player metadata, playback state, position/duration,
capability flags, and default sink/source observed state. Nullable runtime
values remain nullable instead of being replaced with invented defaults.

`liveUpdatesEnabled` controls a one-second observation timer. The service
performs one initial refresh when created; future Media navigation/view wiring
will enable live updates only while the Media module is visible.

Failed refreshes preserve the last good snapshot and expose the failure through
`errorMessage` / `refreshFailed()`.

`Main.qml` owns the service instance and exposes `mediaServiceHandle`.
Phase 2F.1b does not enable Media navigation and does not add playback/audio
mutations.

## Phase 2F.2 — MediaView foundation and live lifecycle

`MediaView.qml` is the presentation layer for the read-only Media snapshot.

The view receives `MediaService` through dependency injection. It does not run
`jc-media`, `playerctl`, `wpctl`, `pactl`, `busctl`, MPRIS commands or
PipeWire commands directly.

The foundation presents:

- artwork with a valid fallback state,
- track title, artist and optional album,
- observed position and duration,
- a non-interactive progress visualization,
- capability availability for previous, play/pause, next and seek,
- observed default output/input descriptions, volume and mute state,
- refresh/error/footer status using the holographic HUD primitives.

Playback and audio controls remain observational in Phase 2F.2.
Capability state affects presentation, but there are no playback, seek, volume
or mute mutations yet.

Media navigation is enabled only now that `MediaView.qml` exists.
`MediaService.liveUpdatesEnabled` is true only while the Control Center is
visible and `activeModuleId` is `"media"`. Enabling live updates triggers an
immediate refresh, followed by the one-second observation timer. Switching
away from Media or closing the Control Center stops the timer.

### Media Refresh visual stability

The manual Phase 2F.2 visual gate identified periodic blinking in the Refresh
button while the one-second live observation loop was active.

The Refresh action now keeps stable presentation during background polling:
its label remains `Refresh` and its visual enabled state no longer follows the
transient `MediaService.loading` flag. Concurrency safety remains owned by
`MediaService.refresh()`, which ignores a refresh request while its status
process is already running.

This is presentation-only polish. It does not change the one-second lifecycle,
the observed-state contract, navigation behavior, or the read-only mutation
boundary.

## Phase 2F.3a — Mutation API boundary

`jc-media` now exposes explicit mutation subcommands behind the same stable
runtime boundary:

```bash
jc-media player play-pause [--json]
jc-media player next [--json]
jc-media player previous [--json]
jc-media player seek <seconds> [--json]
jc-media audio sink-volume <0..1> [--json]
jc-media audio sink-mute <on|off|toggle> [--json]
```

The `status` snapshot remains observational and continues to report
`readOnly=true`; that flag describes the snapshot contract rather than the
entire CLI.

Player actions re-run the dynamic Playing/Paused-first selection for every
request. `playerctld` remains excluded. The selected runtime instance is not
persisted.

Player mutations are capability-gated:

- play/pause requires `CanPause` while Playing or `CanPlay` otherwise;
- next requires `CanGoNext`;
- previous requires `CanGoPrevious`;
- seek is absolute seconds from the beginning and requires `CanSeek`.

Unsupported capability requests return a structured failure instead of blindly
sending a backend command.

Audio mutation addresses only `@DEFAULT_AUDIO_SINK@`. Volume is constrained to
the inclusive `0..1` range. Mute accepts `on`, `off`, or `toggle`. Numeric
PipeWire node IDs, ALSA card numbers, concrete Bluetooth identifiers and MPRIS
instance suffixes are never persisted as mutation selectors.

Phase 2F.3a adds the runtime action boundary only. `MediaService.qml` and
`MediaView.qml` remain observational until Phase 2F.3b wires action processes
and presentation signals.


## Phase 2F.3b — Action service and interactive controls

`MediaActionService.qml` is the QML mutation boundary for Media. The view never
executes runtime tools directly; it emits user intent and `Main.qml` delegates
that intent to the action service.

The action service invokes only the stable `jc-media` mutation API, validates
the structured response, and then reconciles the UI through a fresh
`MediaService` observed-state snapshot. A mutation remains busy until that
post-action observation completes.

The Media view now exposes capability-gated Previous, Play / Pause and Next
controls. Seek and output-volume mutations are emitted only when the user
releases the slider, preventing process-per-pixel command bursts while
dragging. Output mute is sent as an explicit `on` or `off` request based on the
last observed sink state.

Unavailable capabilities remain visibly disabled. With the currently observed
Firefox MPRIS player, Next and Previous therefore remain disabled while
Play / Pause and Seek are available.

Output audio can change the default sink volume and mute state. Input remains
observed-only in Phase 2F.3b; source volume/mute mutations are intentionally
outside this boundary.

No QML layer persists MPRIS instance suffixes, PipeWire numeric node IDs,
Bluetooth addresses, or device-specific selectors.


### Phase 2F.3b visual stability refinement

The one-second `MediaService` observer sets `loading=true` while a status
process is in flight but preserves the last committed good snapshot. Interactive
capability presentation therefore does not follow the transient `loading` flag;
controls remain enabled from the last healthy observed snapshot until an action
itself owns the busy state or a committed snapshot changes the capability.

The Now Playing card keeps a minimum height so title, artist, album, position
and transport controls cannot be compressed away when the output-audio controls
are present. The output/input row is kept compact to preserve the visual balance
of the Phase 2F.2 Media composition.

This refinement changes presentation stability only. It does not execute media
mutations, alter the one-second polling lifecycle, or move backend ownership out
of `jc-media`.


### Phase 2F.3b bounded action reconciliation

`MediaActionService.qml` keeps transport controls locked only while a mutation
is executing and during a bounded observed-state reconciliation window.
Reconciliation has a 2500 ms watchdog so a slow or stalled `jc-media status`
probe during an MPRIS track transition cannot leave Play/Pause, Next,
Previous, Seek or output-audio controls disabled for tens of seconds.

When the stable mutation command has already returned `status=applied` but
the reconciliation watchdog expires, the service releases the UI lock and
normal one-second `MediaService` live polling is allowed to converge the
observed snapshot later. No player URL, concrete MPRIS instance or playback
position is mutated by the watchdog itself.


### Phase 2F.3b semantic Previous-track behavior

`jc-media player previous` represents a semantic **previous track** request,
not an unconditional promise to forward exactly one raw MPRIS `Previous`.

Some MPRIS players restart the current track on the first `Previous` when the
playback position is already several seconds in. `jc-media` therefore issues
one native `Previous`, observes the selected player's track identity, and
stops immediately when the track changes. If the identity remains the same
and the player has moved to approximately 0 seconds, `jc-media` issues one
additional native `Previous` so the user-facing control reaches the preceding
track.

The fallback is bounded to one additional command. It does not persist
player-specific identifiers, does not hardcode a particular player, and does
not send two `Previous` commands when the first one already changes the track.
