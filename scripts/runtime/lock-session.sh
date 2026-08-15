#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Hyprlock runtime launcher
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
local_dir="$base/local"

runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

template="$repo/config/hyprlock/hyprlock.conf.template"
generated="$runtime/hyprlock.conf"


# ------------------------------------------------------------------------------
# Validate environment
# ------------------------------------------------------------------------------

[[ -r "$local_dir/host.env" ]] || {
    echo "Missing local configuration: $local_dir/host.env" >&2
    exit 1
}


[[ -r "$template" ]] || {
    echo "Missing Hyprlock template: $template" >&2
    exit 1
}


# Machine-local configuration.
# shellcheck disable=SC1091
source "$local_dir/host.env"


: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"
: "${SECONDARY_OUTPUT:?SECONDARY_OUTPUT is required}"


# ------------------------------------------------------------------------------
# Generate runtime config
# ------------------------------------------------------------------------------

mkdir -p "$runtime"


main_output="${MAIN_OUTPUT//\//\\/}"
secondary_output="${SECONDARY_OUTPUT//\//\\/}"


sed \
    -e "s/@MAIN_OUTPUT@/$main_output/g" \
    -e "s/@SECONDARY_OUTPUT@/$secondary_output/g" \
    "$template" \
    > "$generated"


# ------------------------------------------------------------------------------
# Safety check
# ------------------------------------------------------------------------------

if grep -qE '@(MAIN_OUTPUT|SECONDARY_OUTPUT)@' "$generated"; then
    echo "Unresolved Hyprlock template placeholders." >&2
    exit 1
fi


# ------------------------------------------------------------------------------
# Lock
# ------------------------------------------------------------------------------

exec hyprlock --config "$generated"