-- =============================================================================
-- jc-hyprland-dotfiles
-- Gaming / HDR rendering
-- Hyprland 0.56+
-- =============================================================================


-- =============================================================================
-- Color management / HDR
--
-- Auto HDR is intentionally disabled.
--
-- HDR switching is handled by scripts/runtime/jc-mpv.sh because automatic
-- HDR switching is currently unreliable for our mpv/Hyprland workflow.
--
-- Normal desktop state:
--   10-bit + sRGB / SDR
--
-- HDR video state:
--   jc-mpv temporarily switches DP-3 to HDR and restores sRGB on exit.
-- =============================================================================

hl.config({
    render = {
        cm_enabled = true,

        -- Managed manually by jc-mpv.
        cm_auto_hdr = 0,

        -- Inform connected displays about the presented content type.
        send_content_type = true,

        -- Let Hyprland use FP16 where appropriate for color management.
        use_fp16 = 2,
    },
})
