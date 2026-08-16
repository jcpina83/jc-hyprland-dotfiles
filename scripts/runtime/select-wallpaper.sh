#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Interactive wallpaper selector
#
# Sources:
#   - Wallpapers shipped by the active theme
#   - User wallpaper library
#
# The actual preference persistence is delegated to wallpaper-manager.sh.
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

theme_link="$base/theme"
local_dir="$base/local"
wallpaper_env="$local_dir/wallpaper.env"

wofi_launcher="$base/bin/launch-wofi.sh"
wallpaper_manager="$base/bin/wallpaper-manager.sh"


# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


notify() {
    local title="$1"
    local message="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message"
    fi
}


select_menu() {
    local prompt="$1"
    shift

    printf '%s\n' "$@" |
        "$wofi_launcher" \
            --dmenu \
            --prompt "$prompt"
}


# ------------------------------------------------------------------------------
# Runtime validation
# ------------------------------------------------------------------------------

[[ -L "$theme_link" ]] \
    || die "active theme link not found: $theme_link"

[[ -x "$wofi_launcher" ]] \
    || die "Wofi launcher not found: $wofi_launcher"

[[ -x "$wallpaper_manager" ]] \
    || die "wallpaper manager not found: $wallpaper_manager"


theme_root="$(readlink -f "$theme_link")"
theme_env="$theme_root/theme.env"

[[ -r "$theme_env" ]] \
    || die "active theme configuration not found: $theme_env"

# shellcheck disable=SC1090
source "$theme_env"

: "${THEME_ID:?THEME_ID is required}"


# ------------------------------------------------------------------------------
# Optional machine-local wallpaper configuration
# ------------------------------------------------------------------------------

WALLPAPER_LIBRARY_DIR="${WALLPAPER_LIBRARY_DIR:-$HOME/Pictures/Wallpapers}"

if [[ -r "$wallpaper_env" ]]; then
    # shellcheck disable=SC1090
    source "$wallpaper_env"
fi

WALLPAPER_LIBRARY_DIR="${WALLPAPER_LIBRARY_DIR:-$HOME/Pictures/Wallpapers}"
WALLPAPER_LIBRARY_DIR="${WALLPAPER_LIBRARY_DIR/#\~/$HOME}"


# ------------------------------------------------------------------------------
# Target/action menu
# ------------------------------------------------------------------------------

actions=(
    "MAIN monitor"
    "SECONDARY monitor"
    "BOTH monitors"
    "Restore MAIN theme wallpaper"
    "Restore SECONDARY theme wallpaper"
    "Restore ALL theme wallpapers"
)

selection="$(select_menu "Wallpaper · ${THEME_ID}" "${actions[@]}")" \
    || exit 0

[[ -n "$selection" ]] || exit 0


case "$selection" in

    "MAIN monitor")
        target="main"
        ;;

    "SECONDARY monitor")
        target="secondary"
        ;;

    "BOTH monitors")
        target="both"
        ;;

    "Restore MAIN theme wallpaper")
        "$wallpaper_manager" reset main
        notify "Wallpaper restored" "${THEME_ID} · MAIN"
        exit 0
        ;;

    "Restore SECONDARY theme wallpaper")
        "$wallpaper_manager" reset secondary
        notify "Wallpaper restored" "${THEME_ID} · SECONDARY"
        exit 0
        ;;

    "Restore ALL theme wallpapers")
        "$wallpaper_manager" reset all
        notify "Wallpapers restored" "${THEME_ID} · theme defaults"
        exit 0
        ;;

    *)
        exit 0
        ;;

esac


# ------------------------------------------------------------------------------
# Discover wallpapers
# ------------------------------------------------------------------------------

labels=()
paths=()

declare -A seen=()


add_wallpaper() {
    local source_label="$1"
    local root="$2"
    local file="$3"

    local canonical
    local relative

    canonical="$(readlink -f "$file")"

    [[ -n "$canonical" ]] || return 0
    [[ -f "$canonical" ]] || return 0

    if [[ -n "${seen[$canonical]:-}" ]]; then
        return 0
    fi

    seen["$canonical"]=1

    if [[ "$canonical" == "$root/"* ]]; then
        relative="${canonical#"$root/"}"
    else
        relative="$(basename "$canonical")"
    fi

    labels+=("${source_label} · ${relative}")
    paths+=("$canonical")
}


while IFS= read -r -d '' wallpaper; do
    add_wallpaper \
        "Theme" \
        "$theme_root" \
        "$wallpaper"
done < <(
    find "$theme_root" \
        -type f \
        \( \
            -iname '*.jpg' \
            -o -iname '*.jpeg' \
            -o -iname '*.png' \
            -o -iname '*.webp' \
        \) \
        -print0 |
    sort -z
)


if [[ -d "$WALLPAPER_LIBRARY_DIR" ]]; then
    library_root="$(readlink -f "$WALLPAPER_LIBRARY_DIR")"

    while IFS= read -r -d '' wallpaper; do
        add_wallpaper \
            "Library" \
            "$library_root" \
            "$wallpaper"
    done < <(
        find "$library_root" \
            -type f \
            \( \
                -iname '*.jpg' \
                -o -iname '*.jpeg' \
                -o -iname '*.png' \
                -o -iname '*.webp' \
            \) \
            -print0 |
        sort -z
    )
fi


if [[ ${#labels[@]} -eq 0 ]]; then
    notify \
        "JC Hyprland" \
        "No wallpapers found for ${THEME_ID}"

    exit 1
fi


# ------------------------------------------------------------------------------
# Wallpaper menu
# ------------------------------------------------------------------------------

wallpaper_selection="$(
    select_menu \
        "Wallpaper · ${target^^}" \
        "${labels[@]}"
)" || exit 0

[[ -n "$wallpaper_selection" ]] || exit 0


selected_path=""

for index in "${!labels[@]}"; do
    if [[ "${labels[$index]}" == "$wallpaper_selection" ]]; then
        selected_path="${paths[$index]}"
        break
    fi
done


[[ -n "$selected_path" ]] \
    || die "unable to resolve selected wallpaper"


# ------------------------------------------------------------------------------
# Apply through the preference manager
# ------------------------------------------------------------------------------

"$wallpaper_manager" \
    set \
    "$target" \
    "$selected_path"

notify \
    "Wallpaper applied" \
    "${THEME_ID} · ${target^^} · $(basename "$selected_path")"
