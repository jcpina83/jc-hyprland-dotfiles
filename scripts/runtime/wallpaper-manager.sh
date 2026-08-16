#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Wallpaper preference manager
#
# Manages machine-local wallpaper preferences for the active theme.
#
# Preferences are stored in:
#
#   ~/.config/jc-hyprland-dotfiles/local/wallpapers/<theme-id>.env
#
# The repository is never modified.
#
# Usage:
#   wallpaper-manager.sh current
#   wallpaper-manager.sh set main <file>
#   wallpaper-manager.sh set secondary <file>
#   wallpaper-manager.sh set both <file>
#   wallpaper-manager.sh reset main
#   wallpaper-manager.sh reset secondary
#   wallpaper-manager.sh reset all
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

theme_link="$base/theme"
local_dir="$base/local"
preferences_dir="$local_dir/wallpapers"

apply_script="$base/bin/apply-wallpaper.sh"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


usage() {
    cat <<'EOF'
Usage:
  wallpaper-manager.sh current
  wallpaper-manager.sh set main <file>
  wallpaper-manager.sh set secondary <file>
  wallpaper-manager.sh set both <file>
  wallpaper-manager.sh reset main
  wallpaper-manager.sh reset secondary
  wallpaper-manager.sh reset all
EOF
}


shell_quote() {
    local value="$1"

    printf "'%s'" "${value//\'/\'\\\'\'}"
}


# ------------------------------------------------------------------------------
# Active theme
# ------------------------------------------------------------------------------

[[ -L "$theme_link" ]] \
    || die "active theme link not found: $theme_link"

theme_root="$(readlink -f "$theme_link")"
theme_env="$theme_root/theme.env"

[[ -r "$theme_env" ]] \
    || die "active theme configuration not found: $theme_env"

# shellcheck disable=SC1090
source "$theme_env"

: "${THEME_ID:?THEME_ID is required}"
: "${MAIN_WALLPAPER:?MAIN_WALLPAPER is required}"
: "${SECONDARY_WALLPAPER:?SECONDARY_WALLPAPER is required}"


preferences_file="$preferences_dir/${THEME_ID}.env"

mkdir -p "$preferences_dir"


# ------------------------------------------------------------------------------
# Load existing theme-specific preferences
# ------------------------------------------------------------------------------

MAIN_WALLPAPER_OVERRIDE=""
SECONDARY_WALLPAPER_OVERRIDE=""
MAIN_WALLPAPER_FIT_OVERRIDE=""
SECONDARY_WALLPAPER_FIT_OVERRIDE=""

if [[ -r "$preferences_file" ]]; then
    # shellcheck disable=SC1090
    source "$preferences_file"
fi


# ------------------------------------------------------------------------------
# Preference persistence
# ------------------------------------------------------------------------------

write_preferences() {
    local tmp_file

    tmp_file="$(mktemp "$preferences_dir/.${THEME_ID}.XXXXXX")"

    cleanup_tmp() {
        rm -f -- "$tmp_file"
    }

    trap cleanup_tmp RETURN

    {
        cat <<EOF
# ==============================================================================
# jc-hyprland-dotfiles
# User wallpaper preferences: $THEME_ID
#
# Machine-local. Never commit.
# Managed by wallpaper-manager.sh.
# ==============================================================================

EOF

        if [[ -n "$MAIN_WALLPAPER_OVERRIDE" ]]; then
            printf 'MAIN_WALLPAPER_OVERRIDE=%s\n' \
                "$(shell_quote "$MAIN_WALLPAPER_OVERRIDE")"
        else
            printf '# MAIN_WALLPAPER_OVERRIDE=""\n'
        fi

        if [[ -n "$SECONDARY_WALLPAPER_OVERRIDE" ]]; then
            printf 'SECONDARY_WALLPAPER_OVERRIDE=%s\n' \
                "$(shell_quote "$SECONDARY_WALLPAPER_OVERRIDE")"
        else
            printf '# SECONDARY_WALLPAPER_OVERRIDE=""\n'
        fi

        printf '\n'

        if [[ -n "$MAIN_WALLPAPER_FIT_OVERRIDE" ]]; then
            printf 'MAIN_WALLPAPER_FIT_OVERRIDE=%s\n' \
                "$(shell_quote "$MAIN_WALLPAPER_FIT_OVERRIDE")"
        else
            printf '# MAIN_WALLPAPER_FIT_OVERRIDE=cover\n'
        fi

        if [[ -n "$SECONDARY_WALLPAPER_FIT_OVERRIDE" ]]; then
            printf 'SECONDARY_WALLPAPER_FIT_OVERRIDE=%s\n' \
                "$(shell_quote "$SECONDARY_WALLPAPER_FIT_OVERRIDE")"
        else
            printf '# SECONDARY_WALLPAPER_FIT_OVERRIDE=cover\n'
        fi
    } > "$tmp_file"

    chmod 0600 "$tmp_file"

    mv \
        "$tmp_file" \
        "$preferences_file"

    trap - RETURN
}


apply_preferences() {
    [[ -x "$apply_script" ]] \
        || die "wallpaper runtime not found: $apply_script"

    "$apply_script"
}


resolve_theme_default() {
    local value="$1"

    if [[ "$value" = /* ]]; then
        printf '%s\n' "$value"
    else
        printf '%s/%s\n' "$theme_root" "$value"
    fi
}


print_current() {
    local main_default
    local secondary_default
    local main_effective
    local secondary_effective

    main_default="$(resolve_theme_default "$MAIN_WALLPAPER")"
    secondary_default="$(resolve_theme_default "$SECONDARY_WALLPAPER")"

    main_effective="${MAIN_WALLPAPER_OVERRIDE:-$main_default}"
    secondary_effective="${SECONDARY_WALLPAPER_OVERRIDE:-$secondary_default}"

    printf 'Theme: %s\n' "$THEME_ID"

    printf '\nMAIN\n'
    printf '  default:   %s\n' "$main_default"

    if [[ -n "$MAIN_WALLPAPER_OVERRIDE" ]]; then
        printf '  override:  %s\n' "$MAIN_WALLPAPER_OVERRIDE"
    else
        printf '  override:  (none)\n'
    fi

    printf '  effective: %s\n' "$main_effective"

    printf '\nSECONDARY\n'
    printf '  default:   %s\n' "$secondary_default"

    if [[ -n "$SECONDARY_WALLPAPER_OVERRIDE" ]]; then
        printf '  override:  %s\n' "$SECONDARY_WALLPAPER_OVERRIDE"
    else
        printf '  override:  (none)\n'
    fi

    printf '  effective: %s\n' "$secondary_effective"

    printf '\nPreferences:\n'
    printf '  %s\n' "$preferences_file"
}


validate_wallpaper_file() {
    local file="$1"

    [[ -f "$file" ]] \
        || die "wallpaper file not found: $file"

    [[ -r "$file" ]] \
        || die "wallpaper file is not readable: $file"

    readlink -f "$file"
}


# ------------------------------------------------------------------------------
# Commands
# ------------------------------------------------------------------------------

command_name="${1:-}"

case "$command_name" in

    current)
        [[ "$#" -eq 1 ]] || {
            usage >&2
            exit 2
        }

        print_current
        ;;


    set)
        [[ "$#" -eq 3 ]] || {
            usage >&2
            exit 2
        }

        target="$2"
        wallpaper="$(validate_wallpaper_file "$3")"

        case "$target" in
            main)
                MAIN_WALLPAPER_OVERRIDE="$wallpaper"
                ;;
            secondary)
                SECONDARY_WALLPAPER_OVERRIDE="$wallpaper"
                ;;
            both)
                MAIN_WALLPAPER_OVERRIDE="$wallpaper"
                SECONDARY_WALLPAPER_OVERRIDE="$wallpaper"
                ;;
            *)
                die "unsupported target: $target"
                ;;
        esac

        write_preferences

        printf 'Wallpaper preference updated:\n'
        printf '  theme:  %s\n' "$THEME_ID"
        printf '  target: %s\n' "$target"
        printf '  file:   %s\n' "$wallpaper"

        echo

        apply_preferences
        ;;


    reset)
        [[ "$#" -eq 2 ]] || {
            usage >&2
            exit 2
        }

        target="$2"

        case "$target" in
            main)
                MAIN_WALLPAPER_OVERRIDE=""
                MAIN_WALLPAPER_FIT_OVERRIDE=""
                ;;
            secondary)
                SECONDARY_WALLPAPER_OVERRIDE=""
                SECONDARY_WALLPAPER_FIT_OVERRIDE=""
                ;;
            all)
                MAIN_WALLPAPER_OVERRIDE=""
                SECONDARY_WALLPAPER_OVERRIDE=""
                MAIN_WALLPAPER_FIT_OVERRIDE=""
                SECONDARY_WALLPAPER_FIT_OVERRIDE=""
                ;;
            *)
                die "unsupported target: $target"
                ;;
        esac

        write_preferences

        printf 'Wallpaper preference reset:\n'
        printf '  theme:  %s\n' "$THEME_ID"
        printf '  target: %s\n' "$target"

        echo

        apply_preferences
        ;;


    --help|-h|"")
        usage
        ;;


    *)
        die "unknown command: $command_name"
        ;;

esac
