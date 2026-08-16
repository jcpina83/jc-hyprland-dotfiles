#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Automatic wallpaper rotation wrapper
#
# Configuration:
#
#   ~/.config/jc-hyprland-dotfiles/local/wallpaper.env
#
# Supported settings:
#
#   WALLPAPER_ROTATION_ENABLED=false
#   WALLPAPER_ROTATION_MODE=next
#   WALLPAPER_ROTATION_TARGET=both
#
# Usage:
#   rotate-wallpaper.sh
#   rotate-wallpaper.sh --force
#
# --force executes one rotation even when automatic rotation is disabled.
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

local_dir="$base/local"
wallpaper_env="$local_dir/wallpaper.env"

wallpaper_manager="$base/bin/wallpaper-manager.sh"


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


usage() {
    cat <<'EOF'
Usage:
  rotate-wallpaper.sh
  rotate-wallpaper.sh --force
  rotate-wallpaper.sh --help

Options:
  --force   Rotate once even when WALLPAPER_ROTATION_ENABLED=false.
EOF
}


force=false

while (($# > 0)); do
    case "$1" in
        --force)
            force=true
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        *)
            die "unknown option: $1"
            ;;
    esac

    shift
done


[[ -x "$wallpaper_manager" ]] \
    || die "wallpaper manager not found: $wallpaper_manager"


# ------------------------------------------------------------------------------
# Defaults
# ------------------------------------------------------------------------------

WALLPAPER_ROTATION_ENABLED=false
WALLPAPER_ROTATION_MODE=next
WALLPAPER_ROTATION_TARGET=both


# ------------------------------------------------------------------------------
# Machine-local configuration
# ------------------------------------------------------------------------------

if [[ -r "$wallpaper_env" ]]; then
    # shellcheck disable=SC1090
    source "$wallpaper_env"
fi


# ------------------------------------------------------------------------------
# Validate configuration
# ------------------------------------------------------------------------------

case "$WALLPAPER_ROTATION_ENABLED" in
    true|false)
        ;;
    *)
        die \
            "WALLPAPER_ROTATION_ENABLED must be true or false: " \
            "$WALLPAPER_ROTATION_ENABLED"
        ;;
esac


case "$WALLPAPER_ROTATION_MODE" in
    next|random)
        ;;
    *)
        die \
            "unsupported WALLPAPER_ROTATION_MODE: " \
            "$WALLPAPER_ROTATION_MODE"
        ;;
esac


case "$WALLPAPER_ROTATION_TARGET" in
    main|secondary|both)
        ;;
    *)
        die \
            "unsupported WALLPAPER_ROTATION_TARGET: " \
            "$WALLPAPER_ROTATION_TARGET"
        ;;
esac


# ------------------------------------------------------------------------------
# Disabled rotation is an intentional no-op
# ------------------------------------------------------------------------------

if [[ "$WALLPAPER_ROTATION_ENABLED" != true && "$force" != true ]]; then
    printf 'Wallpaper rotation disabled.\n'
    exit 0
fi


# ------------------------------------------------------------------------------
# Rotate
# ------------------------------------------------------------------------------

printf 'Wallpaper rotation:\n'
printf '  mode:   %s\n' "$WALLPAPER_ROTATION_MODE"
printf '  target: %s\n' "$WALLPAPER_ROTATION_TARGET"

if [[ "$force" == true && "$WALLPAPER_ROTATION_ENABLED" != true ]]; then
    printf '  forced: yes\n'
fi

echo

exec "$wallpaper_manager" \
    "$WALLPAPER_ROTATION_MODE" \
    "$WALLPAPER_ROTATION_TARGET"
