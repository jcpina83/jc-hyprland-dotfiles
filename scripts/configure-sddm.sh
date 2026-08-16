#!/usr/bin/env bash

set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
runtime_root="$config_home/jc-hyprland-dotfiles"

source_theme_dir="$repo_root/config/sddm/jc-hyprland"
helper_source="$repo_root/scripts/system/jc-hyprland-sddm-switch"

system_theme_dir="/usr/share/sddm/themes/jc-hyprland"
system_helper="/usr/local/libexec/jc-hyprland-sddm-switch"

sddm_conf="/etc/sddm.conf"
backup_conf="${sddm_conf}.jc-before-dotfiles"
sudoers_file="/etc/sudoers.d/jc-hyprland-sddm-switch"

theme_name="jc-hyprland"
supported_themes=(
    "odyssey-glass"
    "cyber-noir"
)

dry_run=false

if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=true
elif [[ "$#" -gt 0 ]]; then
    printf 'ERROR: unsupported argument: %s\n' "$1" >&2
    exit 1
fi

log() {
    printf '[jc-hyprland-dotfiles] %s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

required_source_files=(
    "Main.qml"
    "metadata.desktop"
    "components/OdysseyGlass.qml"
    "components/CyberNoir.qml"
)

for relative in "${required_source_files[@]}"; do
    [[ -r "$source_theme_dir/$relative" ]] \
        || die "missing SDDM source file: $source_theme_dir/$relative"
done

[[ -r "$helper_source" ]] \
    || die "missing SDDM switch helper source: $helper_source"

[[ -r "$sddm_conf" ]] \
    || die "SDDM configuration not found: $sddm_conf"

active_theme_link="$runtime_root/theme"

[[ -L "$active_theme_link" ]] \
    || die "active theme link not found: $active_theme_link"

active_theme="$(basename "$(readlink -f "$active_theme_link")")"

case "$active_theme" in
    odyssey-glass|cyber-noir)
        ;;
    *)
        die "active theme is not supported by SDDM: $active_theme"
        ;;
esac

staging="$(mktemp -d)"
tmp_conf="$(mktemp)"
sudoers_tmp="$(mktemp)"
system_tmp=""

cleanup() {
    rm -rf -- "$staging" 2>/dev/null || true
    rm -f -- "$tmp_conf" "$sudoers_tmp" 2>/dev/null || true

    if [[ -n "${system_tmp:-}" ]]; then
        sudo rm -rf -- "$system_tmp" 2>/dev/null || true
    fi
}

trap cleanup EXIT

log "Building persistent SDDM bundle..."

cp -a \
    "$source_theme_dir/." \
    "$staging/"

rm -f -- "$staging/theme.conf"

mkdir -p \
    "$staging/assets" \
    "$staging/profiles"

build_profile() {
    local theme="$1"
    local theme_root="$repo_root/themes/$theme"
    local env_file="$theme_root/sddm.env"

    local SDDM_VARIANT=""
    local SDDM_BACKGROUND=""
    local SDDM_PANEL_POSITION=""
    local SDDM_BACKGROUND_COLOR=""
    local SDDM_PANEL_COLOR=""
    local SDDM_PANEL_BORDER=""
    local SDDM_PRIMARY=""
    local SDDM_SECONDARY=""
    local SDDM_TEXT=""
    local SDDM_TEXT_MUTED=""

    [[ -r "$env_file" ]] \
        || die "missing SDDM profile source: $env_file"

    # shellcheck disable=SC1090
    source "$env_file"

    local required_vars=(
        SDDM_VARIANT
        SDDM_BACKGROUND
        SDDM_PANEL_POSITION
        SDDM_BACKGROUND_COLOR
        SDDM_PANEL_COLOR
        SDDM_PANEL_BORDER
        SDDM_PRIMARY
        SDDM_SECONDARY
        SDDM_TEXT
        SDDM_TEXT_MUTED
    )

    local var
    for var in "${required_vars[@]}"; do
        [[ -n "${!var:-}" ]] \
            || die "$env_file does not define $var"
    done

    [[ "$SDDM_VARIANT" == "$theme" ]] \
        || die "$env_file has Variant=$SDDM_VARIANT; expected $theme"

    local source_background="$theme_root/$SDDM_BACKGROUND"

    [[ -f "$source_background" && ! -L "$source_background" ]] \
        || die "invalid SDDM background: $source_background"

    mkdir -p "$staging/assets/$theme"

    cp \
        "$source_background" \
        "$staging/assets/$theme/background.webp"

    cat > "$staging/profiles/$theme.conf" <<EOF
[General]
Variant=$SDDM_VARIANT
Background=assets/$theme/background.webp
BackgroundColor=$SDDM_BACKGROUND_COLOR
PanelColor=$SDDM_PANEL_COLOR
PanelBorder=$SDDM_PANEL_BORDER
PrimaryColor=$SDDM_PRIMARY
SecondaryColor=$SDDM_SECONDARY
TextColor=$SDDM_TEXT
MutedColor=$SDDM_TEXT_MUTED
PanelPosition=$SDDM_PANEL_POSITION
EOF
}

for theme in "${supported_themes[@]}"; do
    build_profile "$theme"
done

cp \
    "$staging/profiles/$active_theme.conf" \
    "$staging/theme.conf"

required_bundle_files=(
    "Main.qml"
    "metadata.desktop"
    "components/OdysseyGlass.qml"
    "components/CyberNoir.qml"
    "assets/odyssey-glass/background.webp"
    "assets/cyber-noir/background.webp"
    "profiles/odyssey-glass.conf"
    "profiles/cyber-noir.conf"
    "theme.conf"
)

for relative in "${required_bundle_files[@]}"; do
    [[ -r "$staging/$relative" ]] \
        || die "incomplete SDDM bundle: $staging/$relative"
done

grep -Fqx "Variant=$active_theme" "$staging/theme.conf" \
    || die "staged theme.conf does not match active theme"

awk \
    -v desired="$theme_name" \
    '
    BEGIN {
        in_theme = 0
        changed = 0
    }

    /^\[Theme\][[:space:]]*$/ {
        in_theme = 1
        print
        next
    }

    /^\[/ {
        in_theme = 0
    }

    in_theme && /^[[:space:]]*Current[[:space:]]*=/ {
        print "Current=" desired
        changed = 1
        next
    }

    {
        print
    }

    END {
        if (!changed) {
            exit 42
        }
    }
    ' \
    "$sddm_conf" > "$tmp_conf" || {
        status=$?

        if [[ "$status" -eq 42 ]]; then
            die "[Theme] Current= was not found in $sddm_conf"
        fi

        exit "$status"
    }

invoking_user="$(id -un)"

[[ "$invoking_user" =~ ^[A-Za-z0-9._-]+$ ]] \
    || die "unsupported local username for sudoers rule: $invoking_user"

cat > "$sudoers_tmp" <<EOF
# Managed by jc-hyprland-dotfiles.
# Allows only the root-owned SDDM profile switch helper with exact theme names.
$invoking_user ALL=(root) NOPASSWD: $system_helper odyssey-glass, $system_helper cyber-noir
EOF

if [[ "$dry_run" == true ]]; then
    log "Active SDDM profile: $active_theme"

    log "Would deploy persistent bundle:"
    printf '  %s\n' "$staging"
    printf '  -> %s\n' "$system_theme_dir"

    echo

    log "Would install root-owned helper:"
    printf '  %s\n' "$helper_source"
    printf '  -> %s\n' "$system_helper"

    echo

    log "Would install sudoers rule:"
    cat "$sudoers_tmp"

    echo

    if cmp -s "$sddm_conf" "$tmp_conf"; then
        log "SDDM already uses Current=$theme_name"
    else
        log "Would update $sddm_conf:"
        diff -u "$sddm_conf" "$tmp_conf" || true
    fi

    exit 0
fi

log "Requesting privileges for SDDM system deployment..."

sudo -v

sudo visudo -cf "$sudoers_tmp" >/dev/null

if [[ ! -e "$backup_conf" ]]; then
    sudo cp -a \
        "$sddm_conf" \
        "$backup_conf"

    log "Backup created: $backup_conf"
fi

system_tmp="$(
    sudo mktemp \
        -d \
        "/usr/share/sddm/themes/.jc-hyprland.XXXXXX"
)"

sudo cp -a \
    "$staging/." \
    "$system_tmp/"

sudo chown -R root:root "$system_tmp"

sudo find "$system_tmp" \
    -type d \
    -exec chmod 0755 {} +

sudo find "$system_tmp" \
    -type f \
    -exec chmod 0644 {} +

sudo rm -rf -- "$system_theme_dir"

sudo mv \
    "$system_tmp" \
    "$system_theme_dir"

system_tmp=""

sudo install \
    -d \
    -o root \
    -g root \
    -m 0755 \
    "$(dirname "$system_helper")"

sudo install \
    -o root \
    -g root \
    -m 0755 \
    "$helper_source" \
    "$system_helper"

sudo install \
    -o root \
    -g root \
    -m 0440 \
    "$sudoers_tmp" \
    "$sudoers_file"

sudo visudo -cf "$sudoers_file" >/dev/null

if ! cmp -s "$sddm_conf" "$tmp_conf"; then
    sudo install \
        -o root \
        -g root \
        -m 0644 \
        "$tmp_conf" \
        "$sddm_conf"
fi

log "SDDM bundle deployed: $system_theme_dir"
log "SDDM active profile: $active_theme"
log "SDDM switch helper: $system_helper"
log "SDDM sudoers rule: $sudoers_file"
log "SDDM Current=$theme_name"
log "Future profile switches can run passwordlessly through the root-owned helper."
