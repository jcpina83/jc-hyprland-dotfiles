#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Managed SwayNotificationCenter runtime
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
local_dir="$base/local"

runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

host_env="$local_dir/host.env"

template="$repo/config/swaync/config.json.template"

theme_style="$base/theme/colors.css"
component_style="$repo/config/swaync/style.css"

generated_config="$runtime/swaync-config.json"
generated_style="$runtime/swaync-style.css"

pidfile="$runtime/swaync.pid"
logfile="$runtime/swaync.log"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage:
  start-swaync.sh
  start-swaync.sh --stop
  start-swaync.sh --restart
  start-swaync.sh --help
EOF
}


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}


stop_managed() {
    [[ -f "$pidfile" ]] || return 0

    local pid
    pid="$(<"$pidfile")"

    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        printf 'Stopping managed SwayNC (PID %s)\n' "$pid"

        kill "$pid" 2>/dev/null || true

        for _ in {1..30}; do
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

    --restart)
        mode="restart"
        ;;

    --help|-h)
        usage
        exit 0
        ;;

    *)
        die "Unknown option: $1"
        ;;
esac


mkdir -p "$runtime"


# ------------------------------------------------------------------------------
# Stop mode
# ------------------------------------------------------------------------------

if [[ "$mode" == "stop" ]]; then
    stop_managed
    exit 0
fi


# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------

command -v swaync >/dev/null 2>&1 \
    || die "swaync is not installed"

command -v swaync-client >/dev/null 2>&1 \
    || die "swaync-client is not installed"


# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------

[[ -r "$host_env" ]] \
    || die "Missing machine-local configuration: $host_env"

# Machine-local configuration.
# This file is resolved dynamically at runtime.
# shellcheck disable=SC1090
source "$host_env"


: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"


[[ -r "$template" ]] \
    || die "Missing SwayNC configuration template: $template"

[[ -r "$theme_style" ]] \
    || die "Missing active theme CSS: $theme_style"

[[ -r "$component_style" ]] \
    || die "Missing SwayNC component CSS: $component_style"


# ------------------------------------------------------------------------------
# Generate runtime configuration
# ------------------------------------------------------------------------------

main_output_escaped="$(escape_sed_replacement "$MAIN_OUTPUT")"


sed \
    -e "s|@MAIN_OUTPUT@|$main_output_escaped|g" \
    "$template" \
    > "$generated_config"


if grep -q '@MAIN_OUTPUT@' "$generated_config"; then
    die "Unresolved SwayNC template placeholder: @MAIN_OUTPUT@"
fi


# ------------------------------------------------------------------------------
# Generate runtime stylesheet
#
# theme/colors.css
#       +
# config/swaync/style.css
#       ↓
# runtime/swaync-style.css
# ------------------------------------------------------------------------------

cat \
    "$theme_style" \
    "$component_style" \
    > "$generated_style"


# ------------------------------------------------------------------------------
# If our managed instance is already alive, leave it alone on normal "start".
# ------------------------------------------------------------------------------

if [[ "$mode" == "start" && -f "$pidfile" ]]; then
    pid="$(<"$pidfile")"

    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
        printf 'Managed SwayNC is already running (PID %s)\n' "$pid"
        exit 0
    fi

    rm -f "$pidfile"
fi


# ------------------------------------------------------------------------------
# Notification daemon collision protection
# ------------------------------------------------------------------------------

if pgrep -x mako >/dev/null 2>&1; then
    printf 'ERROR: Mako is currently running.\n' >&2
    printf 'Only one notification daemon should own the notification service.\n' >&2
    exit 3
fi


# On a normal start, refuse to compete with an existing SwayNC.
#
# On --restart we intentionally use SwayNC's native --replace option,
# which replaces the currently running SwayNotificationCenter instance.

if [[ "$mode" == "start" ]] \
    && pgrep -x swaync >/dev/null 2>&1
then
    printf 'ERROR: another SwayNC instance is already running.\n' >&2
    printf 'Use --restart to replace the active instance.\n' >&2
    exit 4
fi


# ------------------------------------------------------------------------------
# Start SwayNC
# ------------------------------------------------------------------------------

if [[ "$mode" == "restart" ]]; then
    printf 'Replacing SwayNC on %s\n' "$MAIN_OUTPUT"
else
    printf 'Starting SwayNC on %s\n' "$MAIN_OUTPUT"
fi


swaync_args=(
    --config "$generated_config"
    --style "$generated_style"
)


if [[ "$mode" == "restart" ]]; then
    swaync_args+=(--replace)
fi


nohup swaync \
    "${swaync_args[@]}" \
    >"$logfile" 2>&1 &


pid=$!

printf '%s\n' "$pid" > "$pidfile"


sleep 0.6


if ! kill -0 "$pid" 2>/dev/null; then
    printf 'ERROR: SwayNC failed to start.\n' >&2
    printf 'Log: %s\n' "$logfile" >&2

    tail -40 "$logfile" >&2 || true

    rm -f "$pidfile"

    exit 5
fi


# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------

printf '\nSwayNC started\n'
printf 'Output: %s\n' "$MAIN_OUTPUT"

printf '\nConfig:\n'
printf '  %s\n' "$generated_config"

printf '\nStyle:\n'
printf '  %s\n' "$generated_style"

printf '\nLog:\n'
printf '  %s\n' "$logfile"