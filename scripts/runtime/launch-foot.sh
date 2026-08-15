#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Odyssey Glass - Foot launcher
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"

config="$repo/config/foot/foot.ini"


if [[ ! -r "$config" ]]; then
    echo "Missing Foot configuration: $config" >&2
    exit 1
fi


if ! command -v foot >/dev/null 2>&1; then
    echo "Foot is not installed or not available in PATH." >&2
    exit 1
fi


exec foot \
    --config="$config" \
    "$@"