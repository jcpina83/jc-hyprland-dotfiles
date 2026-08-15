#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Managed dual-monitor Waybar runtime
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
local_dir="$base/local"
runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

host_env="$local_dir/host.env"

main_template="$repo/config/waybar/templates/config-main.jsonc"
secondary_template="$repo/config/waybar/templates/config-secondary.jsonc"

theme_css="$base/theme/colors.css"
component_css="$repo/config/waybar/style.css"

main_config="$runtime/waybar-main.jsonc"
secondary_config="$runtime/waybar-secondary.jsonc"
generated_style="$runtime/waybar-style.css"

main_pidfile="$runtime/waybar-main.pid"
secondary_pidfile="$runtime/waybar-secondary.pid"

main_log="$runtime/waybar-main.log"
secondary_log="$runtime/waybar-secondary.log"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage:
  start-waybar.sh
  start-waybar.sh --stop
  start-waybar.sh --replace
  start-waybar.sh --help

Modes:
  default     Restart only Waybars managed by jc-hyprland-dotfiles.
  --stop      Stop only Waybars managed by jc-hyprland-dotfiles.
  --replace   Stop ALL Waybar processes, then start our managed Waybars.
EOF
}


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}


stop_pidfile() {
    local pidfile="$1"
    local label="$2"

    [[ -f "$pidfile" ]] || return 0

    local pid
    pid="$(<"$pidfile")"

    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        printf 'Stopping %s Waybar (PID %s)\n' "$label" "$pid"

        kill "$pid" 2>/dev/null || true

        for _ in {1..20}; do
            if ! kill -0 "$pid" 2>/dev/null; then
                break
            fi

            sleep 0.1
        done

        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi

    rm -f "$pidfile"
}


stop_managed() {
    stop_pidfile "$main_pidfile" "MAIN"
    stop_pidfile "$secondary_pidfile" "SECONDARY"
}


start_waybar() {
    local label="$1"
    local config="$2"
    local pidfile="$3"
    local logfile="$4"

    nohup waybar \
        -c "$config" \
        -s "$generated_style" \
        >"$logfile" 2>&1 &

    local pid=$!

    printf '%s\n' "$pid" > "$pidfile"

    sleep 0.4

    if ! kill -0 "$pid" 2>/dev/null; then
        printf 'ERROR: %s Waybar failed to start.\n' "$label" >&2
        printf 'Log: %s\n' "$logfile" >&2

        tail -30 "$logfile" >&2 || true

        rm -f "$pidfile"
        return 1
    fi
}


# ------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------

mode="start"

case "${1:-}" in
    "")
        ;;

    --stop)
        mode="stop"
        ;;

    --replace)
        mode="replace"
        ;;

    --help|-h)
        usage
        exit 0
        ;;

    *)
        die "Unknown option: $1"
        ;;
esac


# ------------------------------------------------------------------------------
# Stop mode
# ------------------------------------------------------------------------------

mkdir -p "$runtime"

if [[ "$mode" == "stop" ]]; then
    stop_managed
    exit 0
fi


# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------

command -v waybar >/dev/null 2>&1 \
    || die "waybar is not installed"

command -v sed >/dev/null 2>&1 \
    || die "sed is not available"


# ------------------------------------------------------------------------------
# Local machine configuration
# ------------------------------------------------------------------------------

[[ -r "$host_env" ]] \
    || die "Missing machine-local configuration: $host_env"

# Machine-local configuration.
# This file is resolved dynamically at runtime.
# shellcheck disable=SC1090
source "$host_env"


: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"
: "${SECONDARY_OUTPUT:?SECONDARY_OUTPUT is required}"

: "${MAIN_WORKSPACES:?MAIN_WORKSPACES is required}"
: "${SECONDARY_WORKSPACES:?SECONDARY_WORKSPACES is required}"


# ------------------------------------------------------------------------------
# Validate templates
# ------------------------------------------------------------------------------

[[ -r "$main_template" ]] \
    || die "Missing Waybar main template: $main_template"

[[ -r "$secondary_template" ]] \
    || die "Missing Waybar secondary template: $secondary_template"

[[ -r "$theme_css" ]] \
    || die "Missing active theme CSS: $theme_css"

[[ -r "$component_css" ]] \
    || die "Missing Waybar component CSS: $component_css"


# ------------------------------------------------------------------------------
# Generate active Waybar stylesheet
#
# theme/colors.css
#       +
# config/waybar/style.css
#       ↓
# runtime/waybar-style.css
# ------------------------------------------------------------------------------

cat \
    "$theme_css" \
    "$component_css" \
    > "$generated_style"


# ------------------------------------------------------------------------------
# Render templates
# ------------------------------------------------------------------------------

main_output_escaped="$(escape_sed_replacement "$MAIN_OUTPUT")"
secondary_output_escaped="$(escape_sed_replacement "$SECONDARY_OUTPUT")"

main_workspaces_escaped="$(escape_sed_replacement "$MAIN_WORKSPACES")"
secondary_workspaces_escaped="$(escape_sed_replacement "$SECONDARY_WORKSPACES")"


sed \
    -e "s|@MAIN_OUTPUT@|$main_output_escaped|g" \
    -e "s|@MAIN_WORKSPACES@|$main_workspaces_escaped|g" \
    "$main_template" \
    > "$main_config"


sed \
    -e "s|@SECONDARY_OUTPUT@|$secondary_output_escaped|g" \
    -e "s|@SECONDARY_WORKSPACES@|$secondary_workspaces_escaped|g" \
    "$secondary_template" \
    > "$secondary_config"


# ------------------------------------------------------------------------------
# Safety check
#
# Only our jc-hyprland placeholders are checked here.
# @DEFAULT_AUDIO_SINK@ belongs to PipeWire/wpctl and must remain intact.
# ------------------------------------------------------------------------------

if grep -qE '@(MAIN_OUTPUT|SECONDARY_OUTPUT|MAIN_WORKSPACES|SECONDARY_WORKSPACES)@' \
    "$main_config" "$secondary_config"
then
    die "Unresolved Waybar template placeholders"
fi


# ------------------------------------------------------------------------------
# Process management
# ------------------------------------------------------------------------------

stop_managed


if [[ "$mode" == "replace" ]]; then
    printf 'Replacing all existing Waybar instances.\n'

    pkill -x waybar 2>/dev/null || true

    sleep 0.3
fi


# ------------------------------------------------------------------------------
# Start bars
# ------------------------------------------------------------------------------

printf 'Starting MAIN Waybar on %s\n' "$MAIN_OUTPUT"

if ! start_waybar \
    "MAIN" \
    "$main_config" \
    "$main_pidfile" \
    "$main_log"
then
    exit 1
fi


printf 'Starting SECONDARY Waybar on %s\n' "$SECONDARY_OUTPUT"

if ! start_waybar \
    "SECONDARY" \
    "$secondary_config" \
    "$secondary_pidfile" \
    "$secondary_log"
then
    stop_pidfile "$main_pidfile" "MAIN"
    exit 1
fi


# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

printf '\nWaybars started\n'
printf 'MAIN:      %s\n' "$MAIN_OUTPUT"
printf 'SECONDARY: %s\n' "$SECONDARY_OUTPUT"

printf '\nRuntime CSS:\n'
printf '  %s\n' "$generated_style"

printf '\nLogs:\n'
printf '  %s\n' "$main_log"
printf '  %s\n' "$secondary_log"