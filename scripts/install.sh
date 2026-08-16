#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# jc-hyprland-dotfiles
# Internal installer
# ============================================================================

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

# common.sh is part of this repository and is linted independently.
# shellcheck disable=SC1091
source "$script_dir/lib/common.sh"


# ============================================================================
# Paths
# ============================================================================

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

base="$config_home/jc-hyprland-dotfiles"
local_dir="$base/local"
bin_dir="$base/bin"

systemd_user_dir="$config_home/systemd/user"

wallpaper_rotation_service="$repo_root/config/systemd/user/jc-wallpaper-rotation.service"
wallpaper_rotation_timer="$repo_root/config/systemd/user/jc-wallpaper-rotation.timer"
wallpaper_rotation_configurator="$repo_root/scripts/configure-wallpaper-rotation.sh"

hypr_dir="$config_home/hypr"

host_template="$repo_root/hosts/example/host.env"
monitors_template="$repo_root/hosts/example/monitors.conf"
wallpaper_template="$repo_root/hosts/example/wallpaper.env"

hypr_bridge_template="$repo_root/config/hypr/hyprlang/templates/jc-dotfiles.conf.template"
hypr_bridge="$hypr_dir/jc-dotfiles.conf"


# ============================================================================
# Options
# ============================================================================

dry_run=false
apply_hyprland=false


usage() {
    cat <<'EOF'
Usage:
  scripts/install.sh [options]

Options:
  --dry-run          Show what would be done without modifying the system
  --apply-hyprland   Install and enable the Hyprland integration bridge
  --help             Show this help
EOF
}


while (($# > 0)); do
    case "$1" in
        --dry-run)
            dry_run=true
            ;;

        --apply-hyprland)
            apply_hyprland=true
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


# ============================================================================
# Helpers
# ============================================================================

run() {
    if [[ "$dry_run" == true ]]; then
        printf '+'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}


ensure_symlink() {
    local source="$1"
    local target="$2"

    if [[ -L "$target" ]]; then
        local current

        current="$(readlink -f "$target" 2>/dev/null || true)"

        if [[ "$current" == "$(readlink -f "$source")" ]]; then
            log "Symlink OK: $target"
            return 0
        fi

        if [[ "$dry_run" == true ]]; then
            printf '+ rm -f %q\n' "$target"
        else
            rm -f "$target"
        fi

    elif [[ -e "$target" ]]; then
        die "Refusing to replace existing non-symlink: $target"
    fi

    run ln -s "$source" "$target"
}


ensure_local_file() {
    local template="$1"
    local destination="$2"

    if [[ -e "$destination" ]]; then
        log "Local config preserved: $destination"
        return 0
    fi

    run cp "$template" "$destination"
}


# ============================================================================
# Validation
# ============================================================================

[[ -d "$repo_root" ]] || die "Repository root not found: $repo_root"

[[ -f "$host_template" ]] \
    || die "Missing host template: $host_template"

[[ -f "$monitors_template" ]] \
    || die "Missing monitor template: $monitors_template"

[[ -f "$wallpaper_template" ]] \
    || die "Missing wallpaper template: $wallpaper_template"

[[ -f "$wallpaper_rotation_service" ]] \
    || die "Missing wallpaper rotation service: $wallpaper_rotation_service"

[[ -f "$wallpaper_rotation_timer" ]] \
    || die "Missing wallpaper rotation timer: $wallpaper_rotation_timer"

[[ -x "$wallpaper_rotation_configurator" ]] \
    || die "Wallpaper rotation configurator is not executable: $wallpaper_rotation_configurator"

[[ -f "$hypr_bridge_template" ]] \
    || die "Missing Hyprland bridge template: $hypr_bridge_template"


# ============================================================================
# Installation
# ============================================================================

log "Repo: $repo_root"

distro="$("$script_dir/detect-distro.sh" --id)"
log "Distro: $distro"


# ----------------------------------------------------------------------------
# Runtime directories
# ----------------------------------------------------------------------------

run mkdir -p \
    "$local_dir" \
    "$bin_dir" \
    "$hypr_dir" \
    "$systemd_user_dir"


# ----------------------------------------------------------------------------
# Repository link
#
# ~/.config/jc-hyprland-dotfiles/repo
#       ->
# actual Git checkout
# ----------------------------------------------------------------------------

ensure_symlink \
    "$repo_root" \
    "$base/repo"


# ----------------------------------------------------------------------------
# Runtime scripts
# ----------------------------------------------------------------------------

ensure_symlink \
    "$repo_root/scripts/runtime/start-waybar.sh" \
    "$bin_dir/start-waybar.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/network-traffic.sh" \
    "$bin_dir/network-traffic.sh"

# AMD / amdgpu telemetry for Waybar.
# Hardware-specific PCI address remains in local/host.env.
ensure_symlink \
    "$repo_root/scripts/runtime/amd-gpu.sh" \
    "$bin_dir/amd-gpu.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/launch-wofi.sh" \
    "$bin_dir/launch-wofi.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/select-theme.sh" \
    "$bin_dir/select-theme.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/select-wallpaper.sh" \
    "$bin_dir/select-wallpaper.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/start-swaync.sh" \
    "$bin_dir/start-swaync.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/lock-session.sh" \
    "$bin_dir/lock-session.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/suspend-session.sh" \
    "$bin_dir/suspend-session.sh"

# ------------------------------------------------------------------------------
# Hypridle integration
# ------------------------------------------------------------------------------

log "Configuring Hypridle lock integration..."

if [[ "${DRY_RUN:-false}" == true ]]; then
    "$repo_root/scripts/configure-hypridle.sh" --dry-run
else
    "$repo_root/scripts/configure-hypridle.sh"
fi

# ------------------------------------------------------------------------------
# nwgbar integration
# ------------------------------------------------------------------------------

log "Configuring nwgbar session integration..."

if [[ "${DRY_RUN:-false}" == true ]]; then
    "$repo_root/scripts/configure-nwgbar.sh" --dry-run
else
    "$repo_root/scripts/configure-nwgbar.sh"
fi

ensure_symlink \
    "$repo_root/scripts/runtime/launch-foot.sh" \
    "$bin_dir/launch-foot.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/apply-wallpaper.sh" \
    "$bin_dir/apply-wallpaper.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/wallpaper-manager.sh" \
    "$bin_dir/wallpaper-manager.sh"

ensure_symlink \
    "$repo_root/scripts/runtime/rotate-wallpaper.sh" \
    "$bin_dir/rotate-wallpaper.sh"

ensure_symlink \
    "$repo_root/scripts/theme.sh" \
    "$bin_dir/jc-theme"

# ----------------------------------------------------------------------------
# Local machine configuration
#
# IMPORTANT:
# These files are intentionally outside the Git checkout.
# Existing files are NEVER overwritten.
# ----------------------------------------------------------------------------

ensure_local_file \
    "$host_template" \
    "$local_dir/host.env"

ensure_local_file \
    "$monitors_template" \
    "$local_dir/monitors.conf"

ensure_local_file \
    "$wallpaper_template" \
    "$local_dir/wallpaper.env"

# ----------------------------------------------------------------------------
# Wallpaper rotation systemd user integration
#
# Unit files are managed by the repository.
# Machine-local interval and lifecycle are managed by wallpaper.env.
# ----------------------------------------------------------------------------

log "Configuring wallpaper rotation systemd integration..."

ensure_symlink \
    "$wallpaper_rotation_service" \
    "$systemd_user_dir/jc-wallpaper-rotation.service"

ensure_symlink \
    "$wallpaper_rotation_timer" \
    "$systemd_user_dir/jc-wallpaper-rotation.timer"

# The initial reload is required on a fresh installation so systemd can see
# the newly linked units before the configurator validates them.
run systemctl --user daemon-reload

run "$wallpaper_rotation_configurator"

# ----------------------------------------------------------------------------
# Hyprland integration bridge
#
# Install the bridge file, but do not modify hyprland.conf automatically.
# This keeps installation safe and reversible.
# ----------------------------------------------------------------------------

if [[ ! -e "$hypr_bridge" ]]; then
    run cp \
        "$hypr_bridge_template" \
        "$hypr_bridge"
else
    log "Hyprland bridge preserved: $hypr_bridge"
fi


# ----------------------------------------------------------------------------
# Optional Hyprland activation
# ----------------------------------------------------------------------------

if [[ "$apply_hyprland" == true ]]; then

    hyprland_conf="$hypr_dir/hyprland.conf"

    [[ -f "$hyprland_conf" ]] \
        || die "Hyprland configuration not found: $hyprland_conf"

    source_line='source = ~/.config/hypr/jc-dotfiles.conf'

    if grep -Fqx "$source_line" "$hyprland_conf"; then
        log "Hyprland integration already enabled."
    else
        log "Enabling Hyprland integration."

        if [[ "$dry_run" == true ]]; then
            printf '+ printf %q >> %q\n' \
                "$source_line" \
                "$hyprland_conf"
        else
            {
                printf '\n'
                printf '# jc-hyprland-dotfiles\n'
                printf '%s\n' "$source_line"
            } >> "$hyprland_conf"
        fi
    fi
fi

# ----------------------------------------------------------------------------
# Default active theme
#
# Only initialize it when no active theme already exists.
# Never overwrite the user's selected theme during reinstall/update.
# ----------------------------------------------------------------------------

theme_link="$base/theme"
default_theme="$repo_root/themes/odyssey-glass"


if [[ ! -e "$theme_link" && ! -L "$theme_link" ]]; then

    run ln -s \
        "$default_theme" \
        "$theme_link"

else
    log "Active theme preserved: $theme_link"
fi

# ============================================================================
# Summary
# ============================================================================

echo

log "Base instalada."

echo
echo "Runtime:"
echo "  $base/repo"
echo "  $bin_dir/start-waybar.sh"
echo "  $bin_dir/network-traffic.sh"
echo "  $bin_dir/amd-gpu.sh"

echo
echo "Local machine config:"
echo "  $local_dir/host.env"
echo "  $local_dir/monitors.conf"

echo
echo "Hyprland bridge:"
echo "  $hypr_bridge"

echo

if [[ "$apply_hyprland" == true ]]; then
    log "Hyprland integration enabled."
else
    log "Revisa local/host.env y local/monitors.conf antes de habilitar runtime."
fi