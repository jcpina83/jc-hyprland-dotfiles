-- =============================================================================
-- jc-hyprland-dotfiles
-- Common keybindings
-- =============================================================================

local home = os.getenv("HOME")
local terminal =
    home .. "/.config/jc-hyprland-dotfiles/bin/launch-foot.sh"


-- -----------------------------------------------------------------------------
-- Terminal
--
-- Remove distro bindings by physical keycode and keysym.
-- -----------------------------------------------------------------------------

hl.unbind("SUPER + code:36")
hl.unbind("SUPER + RETURN")

hl.bind(
    "SUPER + RETURN",
    hl.dsp.exec_cmd(terminal)
)