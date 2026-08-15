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

theme="$base/theme"
theme_env="$theme/theme.env"
theme_colors="$theme/hyprlock.env"

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

[[ -r "$theme_env" ]] || {
    echo "Missing active theme metadata: $theme_env" >&2
    exit 1
}

[[ -r "$theme_colors" ]] || {
    echo "Missing Hyprlock theme palette: $theme_colors" >&2
    exit 1
}

# Machine-local configuration.
# shellcheck disable=SC1091
source "$local_dir/host.env"

# Active theme metadata.
# shellcheck disable=SC1090
source "$theme_env"

# Active theme palette.
# shellcheck disable=SC1090,SC1091
source "$theme_colors"

: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"
: "${SECONDARY_OUTPUT:?SECONDARY_OUTPUT is required}"
: "${LOCK_FG:?LOCK_FG is required}"
: "${LOCK_FG_ALT:?LOCK_FG_ALT is required}"
: "${LOCK_MUTED:?LOCK_MUTED is required}"
: "${LOCK_PRIMARY:?LOCK_PRIMARY is required}"
: "${LOCK_GREEN:?LOCK_GREEN is required}"
: "${LOCK_YELLOW:?LOCK_YELLOW is required}"
: "${LOCK_RED:?LOCK_RED is required}"
: "${LOCK_INNER:?LOCK_INNER is required}"
: "${LOCK_SHADOW:?LOCK_SHADOW is required}"
: "${LOCK_BORDER_GRADIENT:?LOCK_BORDER_GRADIENT is required}"
: "${THEME_NAME:?THEME_NAME is required}"


# ------------------------------------------------------------------------------
# Generate runtime config
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Generate runtime config
# ------------------------------------------------------------------------------

mkdir -p "$runtime"


sed \
    -e "s|@MAIN_OUTPUT@|$MAIN_OUTPUT|g" \
    -e "s|@SECONDARY_OUTPUT@|$SECONDARY_OUTPUT|g" \
    -e "s|@LOCK_FG@|$LOCK_FG|g" \
    -e "s|@LOCK_FG_ALT@|$LOCK_FG_ALT|g" \
    -e "s|@LOCK_MUTED@|$LOCK_MUTED|g" \
    -e "s|@LOCK_PRIMARY@|$LOCK_PRIMARY|g" \
    -e "s|@LOCK_GREEN@|$LOCK_GREEN|g" \
    -e "s|@LOCK_YELLOW@|$LOCK_YELLOW|g" \
    -e "s|@LOCK_RED@|$LOCK_RED|g" \
    -e "s|@LOCK_INNER@|$LOCK_INNER|g" \
    -e "s|@LOCK_SHADOW@|$LOCK_SHADOW|g" \
    -e "s|@LOCK_BORDER_GRADIENT@|$LOCK_BORDER_GRADIENT|g" \
    -e "s|@THEME_NAME@|$THEME_NAME|g" \
    "$template" \
    > "$generated"


# ------------------------------------------------------------------------------
# Safety check
# ------------------------------------------------------------------------------

if grep -qE '@[A-Z0-9_]+@' "$generated"; then
    echo "Unresolved Hyprlock template placeholders:" >&2
    grep -oE '@[A-Z0-9_]+@' "$generated" | sort -u >&2
    exit 1
fi


# ------------------------------------------------------------------------------
# Lock
# ------------------------------------------------------------------------------

exec hyprlock --config "$generated"