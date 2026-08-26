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

This avoids the information loss of the old Hyprlang `monitor = ..., disable`
form.

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

## Legacy Hyprlang cleanup

The active display path no longer requires:

```text
local/monitors.conf
config/hypr/hyprlang/
config/hypr/jc-dotfiles.conf
```

These legacy artifacts should only be removed after the Lua persistence path is
validated on the real host.
