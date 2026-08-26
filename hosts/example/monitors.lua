-- =============================================================================
-- jc-hyprland-dotfiles
-- Machine-local monitor configuration template
--
-- Copy to:
--   ~/.config/jc-hyprland-dotfiles/local/monitors.lua
--
-- Do not commit hardware serial numbers from the local copy.
-- =============================================================================

-- Replace the example selectors/modes with values reported by:
--   hyprctl -j monitors all

hl.monitor({
    output = "desc:Example Primary Monitor",
    mode = "preferred",
    position = "0x0",
    scale = 1,
})

hl.monitor({
    output = "desc:Example Secondary Monitor",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-- Example:
--
-- hl.workspace_rule({
--     workspace = "1",
--     monitor = "desc:Example Primary Monitor",
--     default = true,
--     persistent = true,
-- })
