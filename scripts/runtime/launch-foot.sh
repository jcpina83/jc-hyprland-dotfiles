#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Foot runtime launcher
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
theme="$base/theme"

runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

base_config="$repo/config/foot/foot.ini"
theme_colors="$theme/foot-colors.ini"

generated="$runtime/foot.ini"


if ! command -v foot >/dev/null 2>&1; then
    echo "Foot is not installed or not available in PATH." >&2
    exit 1
fi


[[ -r "$base_config" ]] || {
    echo "Missing Foot base configuration: $base_config" >&2
    exit 1
}


[[ -r "$theme_colors" ]] || {
    echo "Missing Foot theme palette: $theme_colors" >&2
    exit 1
}


mkdir -p "$runtime"


{
    cat "$base_config"

    printf '\n'

    cat "$theme_colors"
} > "$generated"


exec foot \
    --config="$generated" \
    "$@"