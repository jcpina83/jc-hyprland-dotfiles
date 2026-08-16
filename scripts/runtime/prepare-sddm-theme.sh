#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Prepare SDDM theme for the currently active desktop theme.
#
# This script performs no privileged system changes.
# It produces a self-contained SDDM theme ready for testing/deployment.
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

base="$config_home/jc-hyprland-dotfiles"
active_theme_link="$base/theme"

generated_root="$base/generated/sddm"
target_dir="$generated_root/jc-hyprland"


log() {
    printf '[jc-hyprland-dotfiles] %s\n' "$*"
}


# ------------------------------------------------------------------------------
# Active theme
# ------------------------------------------------------------------------------

if [[ ! -L "$active_theme_link" ]]; then
    printf 'ERROR: active theme symlink not found: %s\n' \
        "$active_theme_link" >&2
    exit 1
fi

theme_root="$(readlink -f "$active_theme_link")"

if [[ ! -d "$theme_root" ]]; then
    printf 'ERROR: active theme symlink is invalid: %s\n' \
        "$active_theme_link" >&2
    exit 1
fi

theme_name="$(basename "$theme_root")"
sddm_env="$theme_root/sddm.env"

if [[ ! -r "$sddm_env" ]]; then
    printf 'ERROR: theme has no SDDM configuration: %s\n' \
        "$sddm_env" >&2
    exit 1
fi


# ------------------------------------------------------------------------------
# Theme configuration
# ------------------------------------------------------------------------------

# shellcheck disable=SC1090
source "$sddm_env"

required_variables=(
    SDDM_VARIANT
    SDDM_BACKGROUND
    SDDM_BACKGROUND_COLOR
    SDDM_PANEL_COLOR
    SDDM_PANEL_BORDER
    SDDM_PRIMARY
    SDDM_SECONDARY
    SDDM_TEXT
    SDDM_TEXT_MUTED
)

for variable in "${required_variables[@]}"; do
    if [[ -z "${!variable:-}" ]]; then
        printf 'ERROR: missing SDDM variable: %s\n' "$variable" >&2
        exit 1
    fi
done


background_source="$theme_root/$SDDM_BACKGROUND"

if [[ ! -r "$background_source" ]]; then
    printf 'ERROR: SDDM background not found: %s\n' \
        "$background_source" >&2
    exit 1
fi


# ------------------------------------------------------------------------------
# Shared SDDM engine
# ------------------------------------------------------------------------------

engine_dir="$repo_root/config/sddm/jc-hyprland"

if [[ ! -r "$engine_dir/Main.qml" ]]; then
    printf 'ERROR: SDDM engine not found: %s\n' "$engine_dir" >&2
    exit 1
fi


# ------------------------------------------------------------------------------
# Atomic staging
# ------------------------------------------------------------------------------

mkdir -p "$generated_root"

tmp_dir="$(mktemp -d "$generated_root/.jc-hyprland.XXXXXX")"

cleanup() {
    if [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]]; then
        rm -rf -- "$tmp_dir"
    fi
}

trap cleanup EXIT


# Copy the shared QML engine.
cp -a \
    "$engine_dir/." \
    "$tmp_dir/"


# Bundle the active theme wallpaper.
mkdir -p "$tmp_dir/assets"

cp \
    "$background_source" \
    "$tmp_dir/assets/background.webp"


# Generate the configuration consumed by Main.qml.
cat > "$tmp_dir/theme.conf" <<EOF
[General]
Variant=$SDDM_VARIANT

Background=assets/background.webp

BackgroundColor=$SDDM_BACKGROUND_COLOR
PanelColor=$SDDM_PANEL_COLOR
PanelBorder=$SDDM_PANEL_BORDER

PrimaryColor=$SDDM_PRIMARY
SecondaryColor=$SDDM_SECONDARY

TextColor=$SDDM_TEXT
MutedColor=$SDDM_TEXT_MUTED

PanelPosition=${SDDM_PANEL_POSITION:-auto}
EOF


# ------------------------------------------------------------------------------
# Publish
# ------------------------------------------------------------------------------

rm -rf -- "$target_dir"
mv -- "$tmp_dir" "$target_dir"

tmp_dir=""

log "SDDM theme prepared: $theme_name"
log "Output: $target_dir"