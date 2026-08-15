-- =============================================================================
-- jc-hyprland-dotfiles
-- Active theme loader
--
-- Loads:
--
--   ~/.config/jc-hyprland-dotfiles/theme/colors.lua
--
-- "theme" is a symlink managed by jc-theme.
-- =============================================================================

local home = os.getenv("HOME")

if not home or home == "" then
    error("jc-hyprland-dotfiles: HOME is not defined")
end

local config_home =
    os.getenv("XDG_CONFIG_HOME")
    or (home .. "/.config")

local theme_file =
    config_home
    .. "/jc-hyprland-dotfiles/theme/colors.lua"


-- -----------------------------------------------------------------------------
-- Load active theme
-- -----------------------------------------------------------------------------

local chunk, load_error = loadfile(theme_file)

if not chunk then
    error(
        "jc-hyprland-dotfiles: unable to load active theme: "
        .. tostring(load_error)
    )
end

local ok, theme = pcall(chunk)

if not ok then
    error(
        "jc-hyprland-dotfiles: active theme failed to load: "
        .. tostring(theme)
    )
end

if type(theme) ~= "table" then
    error(
        "jc-hyprland-dotfiles: colors.lua must return a table"
    )
end


-- -----------------------------------------------------------------------------
-- Contract validation
-- -----------------------------------------------------------------------------

local required = {
    "id",
    "name",
    "bg",
    "bg_alt",
    "surface",
    "surface_alt",
    "foreground",
    "muted",
    "primary",
    "secondary",
    "accent",
    "green",
    "yellow",
    "red",
    "inactive_border",
    "shadow",
}

for _, key in ipairs(required) do
    if theme[key] == nil or theme[key] == "" then
        error(
            "jc-hyprland-dotfiles: theme is missing required key: "
            .. key
        )
    end
end


return theme