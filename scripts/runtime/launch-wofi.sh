#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Managed Wofi launcher
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
local_dir="$base/local"

runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

host_env="$local_dir/host.env"

config="$repo/config/wofi/config"

theme_style="$base/theme/colors.css"
component_style="$repo/config/wofi/style.css"

generated_style="$runtime/wofi-style.css"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage:
  launch-wofi.sh
  launch-wofi.sh --main
  launch-wofi.sh --secondary
  launch-wofi.sh --monitor OUTPUT
  launch-wofi.sh --help

Without a monitor option, Wofi decides which output to use.
EOF
}


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


# ------------------------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------------------------

command -v wofi >/dev/null 2>&1 \
    || die "wofi is not installed"


# ------------------------------------------------------------------------------
# Optional machine-local configuration
# ------------------------------------------------------------------------------

if [[ -r "$host_env" ]]; then
    # Machine-local configuration.
    # This file is resolved dynamically at runtime.
    # shellcheck disable=SC1090
    source "$host_env"
fi


# ------------------------------------------------------------------------------
# Arguments
# ------------------------------------------------------------------------------

monitor=""

while (($# > 0)); do
    case "$1" in
        --main)
            monitor="${MAIN_OUTPUT:-}"

            [[ -n "$monitor" ]] \
                || die "MAIN_OUTPUT is not configured in $host_env"
            ;;

        --secondary)
            monitor="${SECONDARY_OUTPUT:-}"

            [[ -n "$monitor" ]] \
                || die "SECONDARY_OUTPUT is not configured in $host_env"
            ;;

        --monitor)
            shift

            (($# > 0)) \
                || die "Missing monitor after --monitor"

            monitor="$1"
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        *)
            die "Unknown option: $1"
            ;;
    esac

    shift
done


# ------------------------------------------------------------------------------
# Validate configuration
# ------------------------------------------------------------------------------

[[ -r "$config" ]] \
    || die "Missing Wofi configuration: $config"

[[ -r "$theme_style" ]] \
    || die "Missing active theme CSS: $theme_style"

[[ -r "$component_style" ]] \
    || die "Missing Wofi component CSS: $component_style"


# ------------------------------------------------------------------------------
# Generate active stylesheet
#
# theme/colors.css
#       +
# config/wofi/style.css
#       ↓
# runtime/wofi-style.css
# ------------------------------------------------------------------------------

mkdir -p "$runtime"

cat \
    "$theme_style" \
    "$component_style" \
    > "$generated_style"


# ------------------------------------------------------------------------------
# Launch
# ------------------------------------------------------------------------------

args=(
    --conf "$config"
    --style "$generated_style"
)


if [[ -n "$monitor" ]]; then
    args+=(
        --monitor "$monitor"
    )
fi


exec wofi "${args[@]}"