-- =============================================================================
-- jc-hyprland-dotfiles
-- Desktop animations
-- Hyprland 0.55+
-- =============================================================================

hl.config({
    animations = {
        enabled = true,
    },
})


-- -----------------------------------------------------------------------------
-- Curves
-- -----------------------------------------------------------------------------

hl.curve("odysseyEase", {
    type = "bezier",
    points = {
        { 0.16, 1.00 },
        { 0.30, 1.00 },
    },
})

hl.curve("odysseyMove", {
    type = "bezier",
    points = {
        { 0.22, 1.00 },
        { 0.36, 1.00 },
    },
})

hl.curve("odysseyFade", {
    type = "bezier",
    points = {
        { 0.40, 0.00 },
        { 0.20, 1.00 },
    },
})


-- -----------------------------------------------------------------------------
-- Windows
-- -----------------------------------------------------------------------------

hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 3,
    bezier = "odysseyEase",
    style = "popin 94%",
})

hl.animation({
    leaf = "windowsMove",
    enabled = true,
    speed = 2,
    bezier = "odysseyMove",
})


-- -----------------------------------------------------------------------------
-- Fade
-- -----------------------------------------------------------------------------

hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 2,
    bezier = "odysseyFade",
})


-- -----------------------------------------------------------------------------
-- Layer surfaces
-- Waybar / Wofi / SwayNC
-- -----------------------------------------------------------------------------

hl.animation({
    leaf = "layers",
    enabled = true,
    speed = 3,
    bezier = "odysseyEase",
    style = "fade",
})


-- -----------------------------------------------------------------------------
-- Workspaces
-- -----------------------------------------------------------------------------

hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 3,
    bezier = "odysseyMove",
    style = "slidefade 12%",
})

hl.animation({
    leaf = "specialWorkspace",
    enabled = true,
    speed = 3,
    bezier = "odysseyEase",
    style = "slidefadevert 15%",
})


-- -----------------------------------------------------------------------------
-- Borders
-- -----------------------------------------------------------------------------

hl.animation({
    leaf = "border",
    enabled = true,
    speed = 3,
    bezier = "odysseyFade",
})