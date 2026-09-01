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
  theme.sh status [--json]
  theme.sh catalog [--json]
  theme.sh apply THEME
EOF
}


list_themes() {
    local dir
    local found=false
    local active

    active="$(current_theme)"


    if [[ ! -d "$themes_dir" ]]; then
        echo "Themes directory not found: $themes_dir" >&2
        return 1
    fi


    for dir in "$themes_dir"/*; do

        [[ -d "$dir" ]] || continue
        [[ -r "$dir/theme.env" ]] || continue

        local name
        local display_name

        name="$(basename "$dir")"

        display_name="$(
            bash -c '
                # shellcheck disable=SC1090
                source "$1"

                printf "%s" "${THEME_NAME:-}"
            ' _ "$dir/theme.env"
        )"


        if [[ "$name" == "$active" ]]; then
            printf '* %-20s %s\n' \
                "$name" \
                "$display_name"
        else
            printf '  %-20s %s\n' \
                "$name" \
                "$display_name"
        fi

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


active_link_theme() {
    local resolved

    if [[ ! -L "$active_link" ]]; then
        return 0
    fi

    resolved="$(readlink -f -- "$active_link" 2>/dev/null || true)"

    if [[ -z "$resolved" ]]; then
        return 0
    fi

    basename "$resolved"
}


active_file_theme() {
    if [[ ! -r "$active_file" ]]; then
        return 0
    fi

    tr -d '\r\n' < "$active_file"
}


theme_is_complete() {
    local theme_dir="$1"
    local required

    for required in \
        theme.env \
        colors.conf \
        colors.css \
        quickshell.json \
        foot-colors.ini \
        hyprlock.env \
        sddm.env
    do
        [[ -r "$theme_dir/$required" ]] || return 1
    done

    return 0
}


theme_metadata_valid() {
    local theme_dir="$1"
    local theme_id="$2"
    local metadata="$theme_dir/quickshell.json"

    theme_is_complete "$theme_dir" || return 1

    jq -e \
        --arg id "$theme_id" \
        '
        .schemaVersion == 1
        and .id == $id
        and ((.name | type) == "string")
        and ((.name | length) > 0)
        and ((.colors | type) == "object")
        and ((.opacity | type) == "object")
        ' \
        "$metadata" >/dev/null 2>&1
}


status_json() {
    local link_theme
    local file_theme
    local active
    local synchronized=false
    local valid=false
    local theme_path=""
    local metadata_file=""

    link_theme="$(active_link_theme)"
    file_theme="$(active_file_theme)"
    active="$(current_theme)"

    if [[ -n "$link_theme" \
        && -n "$file_theme" \
        && "$link_theme" == "$file_theme" ]]
    then
        synchronized=true
    fi

    if [[ -n "$active" && "$active" != "none" ]]; then
        local candidate="$themes_dir/$active"

        if [[ -d "$candidate" ]] \
            && theme_metadata_valid "$candidate" "$active"
        then
            valid=true
            theme_path="$(readlink -f -- "$candidate")"
            metadata_file="$theme_path/quickshell.json"
        fi
    fi

    jq -n \
        --arg activeTheme "$active" \
        --arg activeFileTheme "$file_theme" \
        --arg activeLinkTheme "$link_theme" \
        --arg themePath "$theme_path" \
        --arg metadataFile "$metadata_file" \
        --argjson synchronized "$synchronized" \
        --argjson valid "$valid" \
        '{
            activeTheme: $activeTheme,
            activeFileTheme: (
                if $activeFileTheme == "" then null else $activeFileTheme end
            ),
            activeLinkTheme: (
                if $activeLinkTheme == "" then null else $activeLinkTheme end
            ),
            synchronized: $synchronized,
            valid: $valid,
            themePath: (
                if $themePath == "" then null else $themePath end
            ),
            metadataFile: (
                if $metadataFile == "" then null else $metadataFile end
            )
        }'
}


status_human() {
    local payload

    payload="$(status_json)"

    printf 'Active theme: %s\n' \
        "$(jq -r '.activeTheme' <<< "$payload")"
    printf 'Active file:  %s\n' \
        "$(jq -r '.activeFileTheme // "missing"' <<< "$payload")"
    printf 'Active link:  %s\n' \
        "$(jq -r '.activeLinkTheme // "missing"' <<< "$payload")"
    printf 'Synchronized: %s\n' \
        "$(jq -r 'if .synchronized then "yes" else "no" end' <<< "$payload")"
    printf 'Valid:        %s\n' \
        "$(jq -r 'if .valid then "yes" else "no" end' <<< "$payload")"
}


catalog_json() {
    local active
    local dir
    local theme_id
    local metadata
    local main_wallpaper
    local secondary_wallpaper
    local item
    local items=()

    active="$(current_theme)"

    if [[ ! -d "$themes_dir" ]]; then
        jq -n \
            --arg activeTheme "$active" \
            '{
                activeTheme: $activeTheme,
                count: 0,
                items: []
            }'
        return 0
    fi

    for dir in "$themes_dir"/*; do
        [[ -d "$dir" ]] || continue

        theme_id="$(basename "$dir")"
        theme_metadata_valid "$dir" "$theme_id" || continue

        metadata="$dir/quickshell.json"

        main_wallpaper=""
        secondary_wallpaper=""

        if [[ -r "$dir/wallpapers/main.webp" ]]; then
            main_wallpaper="$(readlink -f -- "$dir/wallpapers/main.webp")"
        fi

        if [[ -r "$dir/wallpapers/secondary.webp" ]]; then
            secondary_wallpaper="$(
                readlink -f -- "$dir/wallpapers/secondary.webp"
            )"
        fi

        item="$(
            jq -c \
                --arg id "$theme_id" \
                --arg activeTheme "$active" \
                --arg mainWallpaper "$main_wallpaper" \
                --arg secondaryWallpaper "$secondary_wallpaper" \
                '{
                    id: $id,
                    name: .name,
                    schemaVersion: .schemaVersion,
                    active: ($id == $activeTheme),
                    colors: .colors,
                    opacity: .opacity,
                    preview: {
                        mainWallpaper: (
                            if $mainWallpaper == ""
                            then null
                            else $mainWallpaper
                            end
                        ),
                        secondaryWallpaper: (
                            if $secondaryWallpaper == ""
                            then null
                            else $secondaryWallpaper
                            end
                        )
                    }
                }' \
                "$metadata"
        )"

        items+=("$item")
    done

    if (( ${#items[@]} == 0 )); then
        jq -n \
            --arg activeTheme "$active" \
            '{
                activeTheme: $activeTheme,
                count: 0,
                items: []
            }'
        return 0
    fi

    printf '%s\n' "${items[@]}" \
        | jq -s \
            --arg activeTheme "$active" \
            '{
                activeTheme: $activeTheme,
                count: length,
                items: .
            }'
}


catalog_human() {
    list_themes
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

    required_theme_files=(
        "theme.env"
        "colors.conf"
        "colors.css"
        "quickshell.json"
        "foot-colors.ini"
        "hyprlock.env"
    )


    for required in "${required_theme_files[@]}"; do

        if [[ ! -r "$theme_dir/$required" ]]; then
            echo "Incomplete theme '$theme_name': missing $required" >&2
            exit 1
        fi

    done

    mkdir -p "$base" "$local_dir"


    # Atomic-ish replacement of the active theme symlink.
    ln -sfn \
        "$theme_dir" \
        "$active_link"


    printf '%s\n' "$theme_name" \
        > "$active_file"


    echo "Active theme: $theme_name"

    # ------------------------------------------------------------------------------
    # Prepare and synchronize SDDM theme
    #
    # The generated artifact remains unprivileged and is useful for development
    # and validation.
    #
    # If the system integration has been installed, the active SDDM profile is
    # switched through a root-owned helper. The sudoers rule only permits the
    # explicitly supported jc themes, so no user-controlled QML is copied as root
    # during a normal theme switch.
    # ------------------------------------------------------------------------------

    sddm_prepare="$repo_root/scripts/runtime/prepare-sddm-theme.sh"
    sddm_switch="/usr/local/libexec/jc-hyprland-sddm-switch"


    if [[ -x "$sddm_prepare" ]]; then

        echo
        echo "Preparing SDDM theme..."

        if ! "$sddm_prepare"; then
            echo
            echo "Theme activated, but SDDM theme preparation failed." >&2
        fi

    fi


    if [[ -x "$sddm_switch" ]]; then

        echo
        echo "Synchronizing SDDM profile..."

        if ! sudo -n "$sddm_switch" "$theme_name"; then
            echo
            echo "Theme activated, but SDDM profile synchronization failed." >&2
        fi

    fi

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

    # ------------------------------------------------------------------------------
    # Refresh resident UI components
    # ------------------------------------------------------------------------------

    waybar_runtime="$repo_root/scripts/runtime/start-waybar.sh"
    swaync_runtime="$repo_root/scripts/runtime/start-swaync.sh"


    if [[ -x "$waybar_runtime" ]]; then
        echo
        echo "Refreshing Waybar..."

        "$waybar_runtime"
    fi


    if pgrep -x swaync >/dev/null 2>&1 \
        && [[ -x "$swaync_runtime" ]]
    then
        echo
        echo "Refreshing SwayNC..."

        "$swaync_runtime" --restart
    fi

}


case "${1:-}" in

    list)
        list_themes
        ;;

    current)
        current_theme
        ;;

    status)
        case "${2:-}" in
            --json)
                status_json
                ;;
            "")
                status_human
                ;;
            *)
                echo "Unknown status option: ${2}" >&2
                usage >&2
                exit 2
                ;;
        esac
        ;;

    catalog)
        case "${2:-}" in
            --json)
                catalog_json
                ;;
            "")
                catalog_human
                ;;
            *)
                echo "Unknown catalog option: ${2}" >&2
                usage >&2
                exit 2
                ;;
        esac
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
