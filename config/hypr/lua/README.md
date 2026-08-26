# Hyprland Lua

This directory is the active Hyprland configuration layer for
`jc-hyprland-dotfiles`.

The supported compositor baseline is Hyprland `0.55+`; the primary validated
runtime is currently Hyprland `0.56.2`.

The distro-owned main configuration remains outside this repository and loads
the project overlay last:

```lua
require("jc-dotfiles/init")
```

The project overlay is split into focused Lua modules under this directory.
Machine-specific display state remains outside Git in:

```text
~/.config/jc-hyprland-dotfiles/local/monitors.lua
```

That file is loaded by `init.lua` and is the authoritative persistent display
source used by both the runtime and persistence backends.

The pre-Lua compatibility implementation is retired and is not part of the
supported runtime.
