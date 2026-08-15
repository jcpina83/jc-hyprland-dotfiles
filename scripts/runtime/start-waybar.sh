#!/usr/bin/env bash
set -euo pipefail
base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
localdir="$base/local"
runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-$UID"
mkdir -p "$runtime"

[[ -r "$localdir/host.env" ]] || { echo "Missing $localdir/host.env" >&2; exit 1; }
# Machine-local configuration; generated during setup and intentionally
# excluded from the repository.
# shellcheck disable=SC1091
source "$localdir/host.env"
: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"
: "${SECONDARY_OUTPUT:?SECONDARY_OUTPUT is required}"

sed "s/@MAIN_OUTPUT@/${MAIN_OUTPUT//\//\\/}/g" "$repo/config/waybar/templates/config-main.jsonc" > "$runtime/waybar-main.jsonc"
sed "s/@SECONDARY_OUTPUT@/${SECONDARY_OUTPUT//\//\\/}/g" "$repo/config/waybar/templates/config-secondary.jsonc" > "$runtime/waybar-secondary.jsonc"

pkill -x waybar 2>/dev/null || true
waybar -c "$runtime/waybar-main.jsonc" -s "$repo/config/waybar/style.css" &
waybar -c "$runtime/waybar-secondary.jsonc" -s "$repo/config/waybar/style.css" &
