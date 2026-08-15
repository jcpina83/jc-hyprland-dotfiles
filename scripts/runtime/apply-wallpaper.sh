#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Wallpaper runtime
#
# Applies the active theme wallpaper using hyprpaper IPC.
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

theme="$base/theme"

local_dir="$base/local"
runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

host_env="$local_dir/host.env"
wallpaper_env="$local_dir/wallpaper.env"
theme_env="$theme/theme.env"

logfile="$runtime/hyprpaper.log"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


resolve_wallpaper() {
    local value="$1"

    if [[ "$value" = /* ]]; then
        printf '%s\n' "$value"
    else
        printf '%s/%s\n' "$theme" "$value"
    fi
}


# ------------------------------------------------------------------------------
# Validation
# ------------------------------------------------------------------------------

command -v hyprctl >/dev/null 2>&1 \
    || die "hyprctl is not available"

command -v hyprpaper >/dev/null 2>&1 \
    || die "hyprpaper is not installed"

[[ -r "$host_env" ]] \
    || die "Missing host configuration: $host_env"

[[ -r "$theme_env" ]] \
    || die "Missing active theme configuration: $theme_env"


# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

# Machine-local host configuration.
# shellcheck disable=SC1090,SC1091
source "$host_env"

# Active theme configuration.
# shellcheck disable=SC1090,SC1091
source "$theme_env"

# Optional machine-local wallpaper overrides.
if [[ -r "$wallpaper_env" ]]; then
    # Machine-local wallpaper configuration.
    # shellcheck disable=SC1090,SC1091
    source "$wallpaper_env"

    printf 'Using wallpaper overrides: %s\n' "$wallpaper_env"
else
    printf 'No wallpaper override found: %s\n' "$wallpaper_env"
fi


: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"
: "${SECONDARY_OUTPUT:?SECONDARY_OUTPUT is required}"

: "${MAIN_WALLPAPER:?MAIN_WALLPAPER is required}"
: "${SECONDARY_WALLPAPER:?SECONDARY_WALLPAPER is required}"


main_value="${MAIN_WALLPAPER_OVERRIDE:-$MAIN_WALLPAPER}"
secondary_value="${SECONDARY_WALLPAPER_OVERRIDE:-$SECONDARY_WALLPAPER}"

main_fit="${MAIN_WALLPAPER_FIT_OVERRIDE:-${MAIN_WALLPAPER_FIT:-cover}}"
secondary_fit="${SECONDARY_WALLPAPER_FIT_OVERRIDE:-${SECONDARY_WALLPAPER_FIT:-cover}}"


main_wallpaper="$(resolve_wallpaper "$main_value")"
secondary_wallpaper="$(resolve_wallpaper "$secondary_value")"


[[ -r "$main_wallpaper" ]] \
    || die "Main wallpaper not found: $main_wallpaper"

[[ -r "$secondary_wallpaper" ]] \
    || die "Secondary wallpaper not found: $secondary_wallpaper"


# ------------------------------------------------------------------------------
# Avoid competing wallpaper daemons
# ------------------------------------------------------------------------------

conflicting_daemons=(
    swww-daemon
    swaybg
    wpaperd
    mpvpaper
)


for daemon in "${conflicting_daemons[@]}"; do

    if pgrep -x "$daemon" >/dev/null 2>&1; then

        printf 'ERROR: another wallpaper daemon is running: %s\n' \
            "$daemon" >&2

        printf 'Refusing to start hyprpaper to avoid competing wallpaper managers.\n' \
            >&2

        exit 4
    fi

done


# ------------------------------------------------------------------------------
# Start hyprpaper if required
# ------------------------------------------------------------------------------

mkdir -p "$runtime"


if ! pgrep -x hyprpaper >/dev/null 2>&1; then

    printf 'Starting hyprpaper...\n'

    nohup hyprpaper \
        >"$logfile" 2>&1 &

    # Wait briefly for the IPC endpoint to become available.
    ready=false

    for _ in {1..30}; do

        if hyprctl hyprpaper listactive >/dev/null 2>&1; then
            ready=true
            break
        fi

        sleep 0.1

    done


    if [[ "$ready" != true ]]; then
        printf 'hyprpaper failed to expose its IPC endpoint.\n' >&2
        printf 'See: %s\n' "$logfile" >&2
        exit 5
    fi

fi


# ------------------------------------------------------------------------------
# Apply wallpapers
# ------------------------------------------------------------------------------

printf 'Applying wallpaper:\n'
printf '  MAIN       %s -> %s\n' "$MAIN_OUTPUT" "$main_wallpaper"
printf '  SECONDARY  %s -> %s\n' "$SECONDARY_OUTPUT" "$secondary_wallpaper"


hyprctl hyprpaper wallpaper \
    "$MAIN_OUTPUT, $main_wallpaper, $main_fit" >/dev/null


hyprctl hyprpaper wallpaper \
    "$SECONDARY_OUTPUT, $secondary_wallpaper, $secondary_fit" >/dev/null


printf '\nActive wallpapers:\n'

hyprctl hyprpaper listactive