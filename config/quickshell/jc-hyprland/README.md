# JC Hyprland Quickshell

Custom Quickshell control-center implementation for `jc-hyprland-dotfiles`.

## Display architecture

Hyprland 0.55+ uses Lua configuration. The project therefore uses one
machine-local persistent source for display state:

```text
~/.config/jc-hyprland-dotfiles/local/monitors.lua
```

The distro-owned `~/.config/hypr/hyprland.lua` loads the project overlay last:

```lua
require("jc-dotfiles/init")
```

and `jc-dotfiles/init.lua` loads `local/monitors.lua`.

This makes project-owned monitor rules authoritative without rewriting the
distribution's main Hyprland configuration.

## Runtime vs persistence

Runtime display mutations remain separate from persistence:

```text
DisplayDraftStore
      |
      v
MonitorApplyService
      |
      v
jc-displayctl
      |
      +-- Safe Apply / Keep / Rollback
      +-- runtime only
      +-- reads persistent extras from local/monitors.lua


Confirmed runtime topology
      |
      v
jc-displaycfg
      |
      +-- preview
      +-- backup
      +-- atomic save
      +-- hyprctl reload
      +-- post-reload verification
      +-- automatic file rollback
      |
      v
local/monitors.lua
```

`Keep` and `Save Configuration` intentionally remain different concepts.

## Phase 1C.1 — Lua persistence backend

`jc-displaycfg` snapshots every configured monitor returned by:

```bash
hyprctl -j monitors all
```

and updates only fields owned by the monitor block:

```lua
hl.monitor({
    output = "desc:...",
    mode = "...",
    position = "...",
    scale = ...,
    disabled = ...,
    transform = ...,
    -- existing extras remain untouched
})
```

The existing selector stays unchanged. In particular a persistent
`desc:<description>` selector is never replaced by a connector such as DP-1.

Existing options such as these are preserved:

```text
vrr
bitdepth
cm
sdr_eotf
sdrbrightness
sdrsaturation
supports_wide_color
supports_hdr
icc
mirror
...
```

Workspace rules are outside the monitor mutation boundary and are preserved
byte-for-byte.

## Disabled monitors

Lua persistence can keep both the disabled flag and the reusable geometry in
the same block:

```lua
hl.monitor({
    output = "desc:...",
    mode = "3440x1440@165",
    position = "840x0",
    scale = 1,
    disabled = true,
})
```

This keeps the reusable geometry available even while the monitor is
persistently disabled.

## Save transaction

```text
save
 |
 +-- require clean configerrors
 +-- capture monitors all
 +-- build monitors.lua candidate
 +-- preserve all non-monitor Lua
 +-- backup current monitors.lua
 +-- atomic rename
 +-- hyprctl reload
 +-- wait for runtime convergence
 +-- verify runtime against pre-save snapshot
 |
 +-- success

failure
 |
 +-- restore backup atomically
 +-- hyprctl reload
 +-- return error
```

Backups live in:

```text
~/.config/jc-hyprland-dotfiles/local/backups/displays/
```

## CLI

```bash
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg status
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg preview
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg save
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg backups
~/.config/jc-hyprland-dotfiles/bin/jc-displaycfg restore-last
```

## Lua migration status

The Lua persistence path has been validated end-to-end on the primary host,
including preview, atomic save, Hyprland reload, post-reload verification and
automatic rollback behavior.

The pre-Lua compatibility path is therefore retired. Display runtime and
persistence now share `local/monitors.lua` as their single machine-local source
of truth.


## Design System / Theme API

Phase 2A.1 adds a shared semantic Theme API at:

```text
config/quickshell/jc-hyprland/theme/Theme.qml
```

`Main.qml` owns one `Theme.Theme` instance and passes it to Control Center
modules/components. The Theme object observes:

```text
~/.config/jc-hyprland-dotfiles/local/active-theme
```

and resolves:

```text
~/.config/jc-hyprland-dotfiles/repo/themes/<theme>/quickshell.json
```

through `FileView`. Theme switching therefore does not require shell execution
from QML and does not introduce a second theme authority.

The canonical API includes semantic colors/surfaces, interaction states,
geometry, typography and motion tokens. Compatibility aliases remain for
Phase 1 components, but new Phase 2 components should consume the canonical
semantic names.

Both built-in themes implement the runtime contract:

```text
themes/odyssey-glass/quickshell.json
themes/cyber-noir/quickshell.json
```

Waybar uses equivalent semantic aliases from each theme's `colors.css`.
See `docs/design-system.md` for the complete contract and extension rules.

---

## Reusable component library

Phase 2A.2 provides the shared visual component layer under `components/`.

New feature UI should compose these components instead of embedding new palette,
geometry or interaction primitives directly in modules.

Canonical reference:

```text
../../../docs/component-library.md
```

Development visual harness:

```text
modules/dev/ComponentGallery.qml
```

Open it with:

```bash
qs -c jc-hyprland ipc call controlCenter showGallery
```

`JcCard` remains a legacy compatibility component for the current Displays UI.
New Phase 2 UI should prefer `JcSurface` and canonical reusable components.
