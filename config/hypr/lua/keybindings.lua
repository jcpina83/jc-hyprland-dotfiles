-- =============================================================================
-- jc-hyprland-dotfiles
-- Common keybindings
-- =============================================================================

local home = os.getenv("HOME")

local terminal =
    home .. "/.config/jc-hyprland-dotfiles/bin/launch-foot.sh"

local theme_selector =
    home .. "/.config/jc-hyprland-dotfiles/bin/select-theme.sh"


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


-- -----------------------------------------------------------------------------
-- Theme selector
--
-- SUPER + T
--     Open theme selector.
-- -----------------------------------------------------------------------------

hl.unbind("SUPER + T")

hl.bind(
    "SUPER + T",
    hl.dsp.exec_cmd(theme_selector)
)


-- =============================================================================
-- Workspaces
--
-- SUPER + [1-0]
--     Switch workspace.
--
-- SUPER + SHIFT + [1-0]
--     Move active window to workspace.
--
-- Workspace 10 is mapped to key 0.
-- =============================================================================

for i = 1, 10 do
    local key = i % 10

    hl.bind(
        "SUPER + " .. key,
        hl.dsp.focus({
            workspace = i,
        })
    )

    hl.bind(
        "SUPER + SHIFT + " .. key,
        hl.dsp.window.move({
            workspace = i,
        })
    )
end