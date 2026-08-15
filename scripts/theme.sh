#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Theme manager
# ==============================================================================

# Resolve this script to its real location.
#
# jc-theme is normally invoked through:
#
#   ~/.config/jc-hyprland-dotfiles/bin/jc-theme
#
# which is a symlink into the Git repository. Using BASH_SOURCE[0] directly
# would incorrectly treat ~/.config/jc-hyprland-dotfiles/bin as the script
# directory.

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

themes_dir="$repo_root/themes"

active_link="$base/theme"
local_dir="$base/local"

active_file="$local_dir/active-theme"

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

themes_dir="$repo_root/themes"

active_link="$base/theme"
local_dir="$base/local"

active_file="$local_dir/active-theme"


usage() {
    cat <<'EOF'
Usage:

  theme.sh list
  theme.sh current
  theme.sh apply THEME
EOF
}


list_themes() {
    local dir
    local found=false

    if [[ ! -d "$themes_dir" ]]; then
        echo "Themes directory not found: $themes_dir" >&2
        return 1
    fi

    for dir in "$themes_dir"/*; do
        [[ -d "$dir" ]] || continue

        if [[ ! -f "$dir/theme.env" ]]; then
            printf 'WARN  skipping %s: missing theme.env\n' \
                "$(basename "$dir")" >&2
            continue
        fi

        printf '%s\n' "$(basename "$dir")"
        found=true
    done

    if [[ "$found" != true ]]; then
        echo "No valid themes found in: $themes_dir" >&2
        return 1
    fi
}


current_theme() {

    if [[ -L "$active_link" ]]; then
        basename "$(readlink -f "$active_link")"
        return 0
    fi

    if [[ -r "$active_file" ]]; then
        cat "$active_file"
        return 0
    fi

    echo "none"
}


apply_theme() {

    local theme_name="$1"
    local theme_dir="$themes_dir/$theme_name"

    [[ -d "$theme_dir" ]] || {
        echo "Theme not found: $theme_name" >&2
        exit 1
    }

    [[ -r "$theme_dir/theme.env" ]] || {
        echo "Theme has no theme.env: $theme_name" >&2
        exit 1
    }

    [[ -r "$theme_dir/colors.conf" ]] || {
        echo "Theme has no colors.conf: $theme_name" >&2
        exit 1
    }


    mkdir -p "$base" "$local_dir"


    # Atomic-ish replacement of the active theme symlink.
    ln -sfn \
        "$theme_dir" \
        "$active_link"


    printf '%s\n' "$theme_name" \
        > "$active_file"


    echo "Active theme: $theme_name"


    # Reload Hyprland colors / appearance.
    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi


    # Wallpaper application is best-effort.
    wallpaper_script="$repo_root/scripts/runtime/apply-wallpaper.sh"

    if [[ -x "$wallpaper_script" ]]; then

        if ! "$wallpaper_script"; then
            echo
            echo "Theme activated, but wallpaper application failed." >&2
        fi

    fi
}


case "${1:-}" in

    list)
        list_themes
        ;;

    current)
        current_theme
        ;;

    apply)

        [[ -n "${2:-}" ]] || {
            echo "Missing theme name." >&2
            usage >&2
            exit 2
        }

        apply_theme "$2"
        ;;

    --help|-h|"")
        usage
        ;;

    *)
        echo "Unknown command: $1" >&2
        usage >&2
        exit 2
        ;;

esac