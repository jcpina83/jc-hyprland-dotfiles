#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Wallpaper runtime
#
# Preferred backend:
#   awww      -> animated transitions
#
# Fallback backend:
#   hyprpaper -> static Hyprland-native wallpaper handling
#
# Backend selection:
#   WALLPAPER_ENGINE=auto|awww|hyprpaper
#
# Optional transition settings:
#   WALLPAPER_TRANSITION_TYPE=fade
#   WALLPAPER_TRANSITION_DURATION=1.2
#   WALLPAPER_TRANSITION_FPS=60
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

theme="$base/theme"

local_dir="$base/local"
runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

host_env="$local_dir/host.env"
wallpaper_env="$local_dir/wallpaper.env"
theme_env="$theme/theme.env"

theme_wallpaper_dir="$local_dir/wallpapers"

awww_logfile="$runtime/awww.log"
hyprpaper_logfile="$runtime/hyprpaper.log"


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

awww_resize_mode() {
    case "$1" in
        cover|crop)
            printf 'crop\n'
            ;;
        contain|fit)
            printf 'fit\n'
            ;;
        stretch)
            printf 'stretch\n'
            ;;
        center|no)
            printf 'no\n'
            ;;
        *)
            die "Unsupported wallpaper fit mode for awww: $1"
            ;;
    esac
}

daemon_running() {
    pgrep -x "$1" >/dev/null 2>&1
}

command -v hyprctl >/dev/null 2>&1 \
    || die "hyprctl is not available"

[[ -r "$host_env" ]] \
    || die "Missing host configuration: $host_env"

[[ -r "$theme_env" ]] \
    || die "Missing active theme configuration: $theme_env"

# shellcheck disable=SC1090,SC1091
source "$host_env"

# shellcheck disable=SC1090,SC1091
source "$theme_env"

if [[ -r "$wallpaper_env" ]]; then
    # shellcheck disable=SC1090,SC1091
    source "$wallpaper_env"
    printf 'Using wallpaper overrides: %s\n' "$wallpaper_env"
else
    printf 'No wallpaper override found: %s\n' "$wallpaper_env"
fi

: "${THEME_ID:?THEME_ID is required}"

theme_wallpaper_env="$theme_wallpaper_dir/${THEME_ID}.env"

if [[ -r "$theme_wallpaper_env" ]]; then
    # Theme-specific machine-local wallpaper preferences.
    # shellcheck disable=SC1090,SC1091
    source "$theme_wallpaper_env"

    printf 'Using theme wallpaper preferences: %s\n' \
        "$theme_wallpaper_env"
else
    printf 'No theme wallpaper preferences found: %s\n' \
        "$theme_wallpaper_env"
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

wallpaper_engine="${WALLPAPER_ENGINE_OVERRIDE:-${WALLPAPER_ENGINE:-auto}}"
transition_type="${WALLPAPER_TRANSITION_TYPE_OVERRIDE:-${WALLPAPER_TRANSITION_TYPE:-fade}}"
transition_duration="${WALLPAPER_TRANSITION_DURATION_OVERRIDE:-${WALLPAPER_TRANSITION_DURATION:-1.2}}"
transition_fps="${WALLPAPER_TRANSITION_FPS_OVERRIDE:-${WALLPAPER_TRANSITION_FPS:-60}}"

case "$wallpaper_engine" in
    auto)
        if command -v awww >/dev/null 2>&1 \
            && command -v awww-daemon >/dev/null 2>&1
        then
            wallpaper_engine="awww"
        elif command -v hyprpaper >/dev/null 2>&1; then
            wallpaper_engine="hyprpaper"
        else
            die "Neither awww nor hyprpaper is installed"
        fi
        ;;
    awww)
        command -v awww >/dev/null 2>&1 \
            || die "WALLPAPER_ENGINE=awww but awww is not installed"
        command -v awww-daemon >/dev/null 2>&1 \
            || die "WALLPAPER_ENGINE=awww but awww-daemon is not installed"
        ;;
    hyprpaper)
        command -v hyprpaper >/dev/null 2>&1 \
            || die "WALLPAPER_ENGINE=hyprpaper but hyprpaper is not installed"
        ;;
    *)
        die "Unsupported WALLPAPER_ENGINE: $wallpaper_engine"
        ;;
esac

common_conflicts=(
    swaybg
    wpaperd
    mpvpaper
    swww-daemon
)

for daemon in "${common_conflicts[@]}"; do
    if daemon_running "$daemon"; then
        die "another wallpaper daemon is running: $daemon"
    fi
done

mkdir -p "$runtime"

apply_awww() {
    local main_resize
    local secondary_resize

    main_resize="$(awww_resize_mode "$main_fit")"
    secondary_resize="$(awww_resize_mode "$secondary_fit")"

    if daemon_running hyprpaper; then
        printf 'Stopping hyprpaper before starting awww...\n'
        pkill -x hyprpaper

        for _ in {1..20}; do
            if ! daemon_running hyprpaper; then
                break
            fi
            sleep 0.05
        done
    fi

    if ! daemon_running awww-daemon; then
        printf 'Starting awww-daemon...\n'

        nohup awww-daemon --no-cache \
            >"$awww_logfile" 2>&1 &

        local ready=false

        for _ in {1..30}; do
            if awww query >/dev/null 2>&1; then
                ready=true
                break
            fi
            sleep 0.1
        done

        if [[ "$ready" != true ]]; then
            printf 'awww-daemon failed to expose its IPC endpoint.\n' >&2
            printf 'See: %s\n' "$awww_logfile" >&2
            exit 5
        fi
    fi

    printf 'Applying wallpapers with awww:\n'
    printf '  MAIN       %s -> %s\n' "$MAIN_OUTPUT" "$main_wallpaper"
    printf '  SECONDARY  %s -> %s\n' "$SECONDARY_OUTPUT" "$secondary_wallpaper"
    printf '  TRANSITION %s / %ss / %s FPS\n' \
        "$transition_type" \
        "$transition_duration" \
        "$transition_fps"

    awww img \
        --outputs "$MAIN_OUTPUT" \
        --resize "$main_resize" \
        --transition-type "$transition_type" \
        --transition-duration "$transition_duration" \
        --transition-fps "$transition_fps" \
        "$main_wallpaper"

    awww img \
        --outputs "$SECONDARY_OUTPUT" \
        --resize "$secondary_resize" \
        --transition-type "$transition_type" \
        --transition-duration "$transition_duration" \
        --transition-fps "$transition_fps" \
        "$secondary_wallpaper"

    printf '\nActive wallpapers:\n'
    awww query
}

apply_hyprpaper() {
    if daemon_running awww-daemon; then
        printf 'Stopping awww-daemon before starting hyprpaper...\n'

        if command -v awww >/dev/null 2>&1; then
            awww kill >/dev/null 2>&1 || true
        fi

        if daemon_running awww-daemon; then
            pkill -x awww-daemon || true
        fi

        for _ in {1..20}; do
            if ! daemon_running awww-daemon; then
                break
            fi
            sleep 0.05
        done
    fi

    if ! daemon_running hyprpaper; then
        printf 'Starting hyprpaper...\n'

        nohup hyprpaper \
            >"$hyprpaper_logfile" 2>&1 &

        local ready=false

        for _ in {1..30}; do
            if hyprctl hyprpaper listactive >/dev/null 2>&1; then
                ready=true
                break
            fi
            sleep 0.1
        done

        if [[ "$ready" != true ]]; then
            printf 'hyprpaper failed to expose its IPC endpoint.\n' >&2
            printf 'See: %s\n' "$hyprpaper_logfile" >&2
            exit 5
        fi
    fi

    printf 'Applying wallpapers with hyprpaper:\n'
    printf '  MAIN       %s -> %s\n' "$MAIN_OUTPUT" "$main_wallpaper"
    printf '  SECONDARY  %s -> %s\n' "$SECONDARY_OUTPUT" "$secondary_wallpaper"

    hyprctl hyprpaper wallpaper \
        "$MAIN_OUTPUT, $main_wallpaper, $main_fit" >/dev/null

    hyprctl hyprpaper wallpaper \
        "$SECONDARY_OUTPUT, $secondary_wallpaper, $secondary_fit" >/dev/null

    printf '\nActive wallpapers:\n'
    hyprctl hyprpaper listactive
}

printf 'Wallpaper engine: %s\n' "$wallpaper_engine"

case "$wallpaper_engine" in
    awww)
        apply_awww
        ;;
    hyprpaper)
        apply_hyprpaper
        ;;
esac
