-- =============================================================================
-- jc-hyprland-dotfiles
-- Hyprland Lua integration
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Theme
--
-- Must be initialized before appearance.
-- -----------------------------------------------------------------------------

require("jc-dotfiles/theme")


-- -----------------------------------------------------------------------------
-- Desktop appearance
-- -----------------------------------------------------------------------------

require("jc-dotfiles/appearance")


-- -----------------------------------------------------------------------------
-- Gaming / HDR rendering
-- -----------------------------------------------------------------------------

require("jc-dotfiles/gaming")


-- -----------------------------------------------------------------------------
-- Animations
-- -----------------------------------------------------------------------------

require("jc-dotfiles/animations")


-- -----------------------------------------------------------------------------
-- Runtime
-- -----------------------------------------------------------------------------

require("jc-dotfiles/autostart")


-- -----------------------------------------------------------------------------
-- Machine-local monitor configuration
--
-- Hardware-specific monitor descriptors, serials, modes and layout remain
-- outside the Git repository.
-- -----------------------------------------------------------------------------

local home = os.getenv("HOME")

if home then
    local monitors_file =
        home .. "/.config/jc-hyprland-dotfiles/local/monitors.lua"

    local monitors_chunk, monitors_error = loadfile(monitors_file)

    if monitors_chunk then
        monitors_chunk()
    elseif monitors_error
        and not monitors_error:match("No such file or directory")
    then
        error(monitors_error)
    end
end


-- -----------------------------------------------------------------------------
-- User overrides
--
-- MUST remain last so project keybindings win over distro defaults.
-- -----------------------------------------------------------------------------

require("jc-dotfiles/keybindings")