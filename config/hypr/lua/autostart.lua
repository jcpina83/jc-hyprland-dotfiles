-- =============================================================================
-- jc-hyprland-dotfiles
-- Runtime autostart
-- =============================================================================

local home = os.getenv("HOME")
local bin = home .. "/.config/jc-hyprland-dotfiles/bin/"

hl.on("hyprland.start", function()
    -- Quickshell is the Control Center runtime. Its launcher is idempotent and
    -- becomes the single startup boundary for the named jc-hyprland shell.
    hl.exec_cmd(bin .. "start-quickshell.sh")

    hl.exec_cmd(bin .. "start-waybar.sh")
    hl.exec_cmd(bin .. "start-swaync.sh")
    hl.exec_cmd(bin .. "apply-wallpaper.sh")
end)
