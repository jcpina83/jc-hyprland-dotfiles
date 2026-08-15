-- =============================================================================
-- jc-hyprland-dotfiles
-- Runtime autostart
-- =============================================================================

local home = os.getenv("HOME")
local bin = home .. "/.config/jc-hyprland-dotfiles/bin/"

hl.on("hyprland.start", function()
    hl.exec_cmd(bin .. "start-waybar.sh")
    hl.exec_cmd(bin .. "start-swaync.sh")
    hl.exec_cmd(bin .. "apply-wallpaper.sh")
end)