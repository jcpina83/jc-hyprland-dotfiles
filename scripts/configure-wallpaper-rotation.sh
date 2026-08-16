#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Configure wallpaper rotation
#
# Reads:
#   ~/.config/jc-hyprland-dotfiles/local/wallpaper.env
#
# Generates:
#   ~/.config/systemd/user/jc-wallpaper-rotation.timer.d/interval.conf
#
# Manages:
#   - Timer interval
#   - systemd user daemon reload
#   - Timer enable/start when WALLPAPER_ROTATION_ENABLED=true
#   - Timer stop + activation unlink when WALLPAPER_ROTATION_ENABLED=false
#
# IMPORTANT:
# The service/timer unit files themselves are linked from the Git repository.
# Disabling rotation must therefore preserve those managed unit symlinks.
# ==============================================================================

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

base="$config_home/jc-hyprland-dotfiles"
wallpaper_env="$base/local/wallpaper.env"

systemd_user_dir="$config_home/systemd/user"
dropin_dir="$systemd_user_dir/jc-wallpaper-rotation.timer.d"
dropin_file="$dropin_dir/interval.conf"

timer_wants_dir="$systemd_user_dir/timers.target.wants"
timer_enable_link="$timer_wants_dir/jc-wallpaper-rotation.timer"

service_unit="jc-wallpaper-rotation.service"
timer_unit="jc-wallpaper-rotation.timer"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------

WALLPAPER_ROTATION_ENABLED=false
WALLPAPER_ROTATION_MODE=next
WALLPAPER_ROTATION_TARGET=both
WALLPAPER_ROTATION_INTERVAL=30m


# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

[[ -r "$wallpaper_env" ]] \
    || die "wallpaper configuration not found: $wallpaper_env"

# shellcheck disable=SC1090
source "$wallpaper_env"

: "${WALLPAPER_ROTATION_ENABLED:?WALLPAPER_ROTATION_ENABLED is required}"
: "${WALLPAPER_ROTATION_MODE:?WALLPAPER_ROTATION_MODE is required}"
: "${WALLPAPER_ROTATION_TARGET:?WALLPAPER_ROTATION_TARGET is required}"
: "${WALLPAPER_ROTATION_INTERVAL:?WALLPAPER_ROTATION_INTERVAL is required}"


# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------

command -v systemctl >/dev/null 2>&1 \
    || die "systemctl is not available"

command -v systemd-analyze >/dev/null 2>&1 \
    || die "systemd-analyze is not available"


# ------------------------------------------------------------------------------
# Validate configuration
# ------------------------------------------------------------------------------

case "$WALLPAPER_ROTATION_ENABLED" in
    true|false)
        ;;
    *)
        die \
            "WALLPAPER_ROTATION_ENABLED must be true or false: " \
            "$WALLPAPER_ROTATION_ENABLED"
        ;;
esac


case "$WALLPAPER_ROTATION_MODE" in
    next|random)
        ;;
    *)
        die \
            "unsupported WALLPAPER_ROTATION_MODE: " \
            "$WALLPAPER_ROTATION_MODE"
        ;;
esac


case "$WALLPAPER_ROTATION_TARGET" in
    main|secondary|both)
        ;;
    *)
        die \
            "unsupported WALLPAPER_ROTATION_TARGET: " \
            "$WALLPAPER_ROTATION_TARGET"
        ;;
esac


if ! systemd-analyze timespan "$WALLPAPER_ROTATION_INTERVAL" \
    >/dev/null 2>&1
then
    die \
        "invalid WALLPAPER_ROTATION_INTERVAL: " \
        "$WALLPAPER_ROTATION_INTERVAL"
fi


# ------------------------------------------------------------------------------
# Validate installed systemd user units
# ------------------------------------------------------------------------------

service_load_state="$(
    systemctl --user show \
        "$service_unit" \
        -p LoadState \
        --value \
        2>/dev/null ||
        true
)"

timer_load_state="$(
    systemctl --user show \
        "$timer_unit" \
        -p LoadState \
        --value \
        2>/dev/null ||
        true
)"

[[ "$service_load_state" == "loaded" ]] \
    || die \
        "systemd user service is not installed or loaded: " \
        "$service_unit"

[[ "$timer_load_state" == "loaded" ]] \
    || die \
        "systemd user timer is not installed or loaded: " \
        "$timer_unit"


# ------------------------------------------------------------------------------
# Generate timer drop-in
#
# Timer directives are cumulative. Reset both values inherited from the base
# unit before applying the machine-local interval.
# ------------------------------------------------------------------------------

mkdir -p "$dropin_dir"

tmp_file="$(mktemp "$dropin_dir/.interval.conf.XXXXXX")"

cleanup() {
    rm -f -- "$tmp_file"
}

trap cleanup EXIT

cat > "$tmp_file" <<EOF
# Generated by jc-hyprland-dotfiles.
# Source: $wallpaper_env
#
# Do not edit manually.

[Timer]
OnActiveSec=
OnUnitActiveSec=
OnActiveSec=$WALLPAPER_ROTATION_INTERVAL
OnUnitActiveSec=$WALLPAPER_ROTATION_INTERVAL
EOF

chmod 0644 "$tmp_file"
mv "$tmp_file" "$dropin_file"

trap - EXIT


# ------------------------------------------------------------------------------
# Reload systemd user manager
# ------------------------------------------------------------------------------

systemctl --user daemon-reload


# ------------------------------------------------------------------------------
# Apply lifecycle
# ------------------------------------------------------------------------------

if [[ "$WALLPAPER_ROTATION_ENABLED" == true ]]; then

    # The unit itself remains linked from the repository. "enable" only creates
    # the activation link under timers.target.wants.
    systemctl --user enable "$timer_unit" >/dev/null

    # Restart so interval changes are picked up immediately.
    systemctl --user restart "$timer_unit"

    lifecycle="enabled"

else

    # Do NOT use `systemctl disable` here. The timer unit itself is linked from
    # the repository and disabling a linked unit may remove that managed link.
    #
    # Stop the timer and remove only the activation link created by [Install].
    systemctl --user stop "$timer_unit" >/dev/null 2>&1 || true

    rm -f -- "$timer_enable_link"

    systemctl --user daemon-reload
    systemctl --user reset-failed "$timer_unit" >/dev/null 2>&1 || true

    lifecycle="disabled"

fi


# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

printf 'Wallpaper rotation configured:\n'
printf '  enabled:  %s\n' "$WALLPAPER_ROTATION_ENABLED"
printf '  mode:     %s\n' "$WALLPAPER_ROTATION_MODE"
printf '  target:   %s\n' "$WALLPAPER_ROTATION_TARGET"
printf '  interval: %s\n' "$WALLPAPER_ROTATION_INTERVAL"
printf '  timer:    %s\n' "$lifecycle"
printf '  drop-in:  %s\n' "$dropin_file"
