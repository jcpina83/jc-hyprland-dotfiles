-- =============================================================================
-- jc-hyprland-dotfiles
-- Hyprland appearance
-- Hyprland 0.55+
-- =============================================================================

local theme = require("jc-dotfiles/theme")


-- =============================================================================
-- General appearance
-- =============================================================================

hl.config({
    general = {
        border_size = 2,

        gaps_in = 6,
        gaps_out = 12,
        gaps_workspaces = 6,

        resize_on_border = true,

        col = {
            active_border = {
                colors = {
                    theme.primary,
                    theme.secondary,
                },
                angle = 45,
            },

            inactive_border = theme.inactive_border,
        },
    },


    -- =========================================================================
    -- Decoration
    -- =========================================================================

    decoration = {
        rounding = 14,
        rounding_power = 2.4,

        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,

        dim_inactive = false,


        -- ---------------------------------------------------------------------
        -- Shadow
        -- ---------------------------------------------------------------------

        shadow = {
            enabled = true,

            range = 16,
            render_power = 3,
            sharp = false,

            color = theme.shadow,

            offset = { 0, 4 },
        },


        -- ---------------------------------------------------------------------
        -- Blur
        -- ---------------------------------------------------------------------

        blur = {
            enabled = true,

            size = 5,
            passes = 2,

            ignore_opacity = true,
            new_optimizations = true,

            xray = false,

            noise = 0.0117,
            contrast = 0.90,
            brightness = 0.96,

            vibrancy = 0.16,
            vibrancy_darkness = 0.05,

            popups = true,
            popups_ignorealpha = 0.20,
        },
    },
})


-- =============================================================================
-- Layer-shell blur
-- ==============================================================================


-- -----------------------------------------------------------------------------
-- Waybar
-- -----------------------------------------------------------------------------

hl.layer_rule({
    name = "jc-waybar-blur",

    match = {
        namespace = "^jc-(main|secondary)$",
    },

    blur = true,
    ignore_alpha = 0.15,
})


-- -----------------------------------------------------------------------------
-- Wofi
-- -----------------------------------------------------------------------------

hl.layer_rule({
    name = "jc-wofi-blur",

    match = {
        namespace = "^wofi$",
    },

    blur = true,
    ignore_alpha = 0.15,
})


-- -----------------------------------------------------------------------------
-- SwayNC
-- -----------------------------------------------------------------------------

hl.layer_rule({
    name = "jc-swaync-blur",

    match = {
        namespace = "^swaync.*$",
    },

    blur = true,
    ignore_alpha = 0.12,
})