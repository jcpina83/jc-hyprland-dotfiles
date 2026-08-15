#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Multi-theme validator
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

themes_dir="$repo_root/themes"
foot_base="$repo_root/config/foot/foot.ini"

errors=0
warnings=0


ok() {
    printf '  OK    %s\n' "$*"
}


warn() {
    printf '  WARN  %s\n' "$*" >&2
    ((warnings += 1))
}


fail() {
    printf '  FAIL  %s\n' "$*" >&2
    ((errors += 1))
}


require_file() {
    local path="$1"

    if [[ -r "$path" ]]; then
        ok "$(basename "$path")"
        return 0
    fi

    fail "missing: $path"
    return 1
}


validate_assignment() {
    local file="$1"
    local variable="$2"

    if grep -Eq \
        "^[[:space:]]*${variable}[[:space:]]*=" \
        "$file"
    then
        return 0
    fi

    fail "$(basename "$file"): missing $variable"
}


validate_hypr_variable() {
    local file="$1"
    local variable="$2"

    if grep -Eq \
        "^[[:space:]]*\\\$${variable}[[:space:]]*=" \
        "$file"
    then
        return 0
    fi

    fail "$(basename "$file"): missing \$$variable"
}


validate_css_color() {
    local file="$1"
    local color="$2"

    if grep -Eq \
        "^[[:space:]]*@define-color[[:space:]]+${color}[[:space:]]+" \
        "$file"
    then
        return 0
    fi

    fail "$(basename "$file"): missing @define-color $color"
}


validate_wallpaper() {
    local theme_dir="$1"
    local label="$2"
    local value="$3"

    if [[ -z "$value" ]]; then
        fail "$label wallpaper is not declared"
        return
    fi

    local path

    if [[ "$value" = /* ]]; then
        path="$value"
        warn "$label wallpaper uses absolute path: $value"
    else
        path="$theme_dir/$value"
    fi

    if [[ -r "$path" ]]; then
        ok "$label wallpaper"
    else
        # Local wallpaper.env may intentionally override this.
        warn "$label wallpaper not shipped: $path"
    fi
}


validate_foot() {
    local theme_dir="$1"
    local theme_name="$2"

    local palette="$theme_dir/foot-colors.ini"

    if ! command -v foot >/dev/null 2>&1; then
        warn "foot not installed; skipping Foot validation for $theme_name"
        return
    fi

    local tmp
    tmp="$(mktemp)"

    {
        cat "$foot_base"
        printf '\n'
        cat "$palette"
    } > "$tmp"

    if foot \
        --config="$tmp" \
        --check-config >/dev/null
    then
        ok "Foot palette"
    else
        fail "Foot configuration invalid for theme: $theme_name"
    fi

    rm -f "$tmp"
}


validate_theme() {
    local theme_dir="$1"
    local theme_name

    theme_name="$(basename "$theme_dir")"

    printf '\n==> Theme: %s\n' "$theme_name"

    local required_files=(
        "theme.env"
        "colors.conf"
        "colors.css"
        "foot-colors.ini"
        "hyprlock.env"
    )

    local file

    for file in "${required_files[@]}"; do
        require_file "$theme_dir/$file" || true
    done


    # Cannot continue structural validation when core files are missing.
    for file in "${required_files[@]}"; do
        if [[ ! -r "$theme_dir/$file" ]]; then
            return
        fi
    done


    # --------------------------------------------------------------------------
    # Shell syntax
    # --------------------------------------------------------------------------

    if bash -n "$theme_dir/theme.env"; then
        ok "theme.env syntax"
    else
        fail "theme.env syntax"
    fi

    if bash -n "$theme_dir/hyprlock.env"; then
        ok "hyprlock.env syntax"
    else
        fail "hyprlock.env syntax"
    fi


    # --------------------------------------------------------------------------
    # Metadata
    # --------------------------------------------------------------------------

    local metadata=()

    mapfile -t metadata < <(
        bash -c '
            set -u

            # shellcheck disable=SC1090
            source "$1"

            printf "%s\n" "${THEME_ID:-}"
            printf "%s\n" "${THEME_NAME:-}"
            printf "%s\n" "${MAIN_WALLPAPER:-}"
            printf "%s\n" "${SECONDARY_WALLPAPER:-}"
        ' _ "$theme_dir/theme.env"
    )

    local theme_id="${metadata[0]:-}"
    local display_name="${metadata[1]:-}"
    local main_wallpaper="${metadata[2]:-}"
    local secondary_wallpaper="${metadata[3]:-}"

    if [[ "$theme_id" == "$theme_name" ]]; then
        ok "THEME_ID=$theme_id"
    else
        fail "THEME_ID '$theme_id' does not match directory '$theme_name'"
    fi

    if [[ -n "$display_name" ]]; then
        ok "THEME_NAME=$display_name"
    else
        fail "THEME_NAME is empty"
    fi


    # --------------------------------------------------------------------------
    # Hyprland palette
    # --------------------------------------------------------------------------

    local hypr_vars=(
        theme_bg
        theme_bg_alt
        theme_surface
        theme_surface_alt
        theme_foreground
        theme_muted
        theme_primary
        theme_secondary
        theme_accent
        theme_green
        theme_yellow
        theme_red
        theme_shadow
    )

    local variable

    for variable in "${hypr_vars[@]}"; do
        validate_hypr_variable \
            "$theme_dir/colors.conf" \
            "$variable"
    done

    ok "Hyprland palette structure"


    # --------------------------------------------------------------------------
    # Shared GTK/CSS palette
    # --------------------------------------------------------------------------

    local css_colors=(
        bg
        bg-alt
        surface
        surface-alt
        foreground
        foreground-alt
        muted
        primary
        secondary
        accent
        green
        yellow
        red
        glass
        glass-light
        glass-hover
        glass-border
    )

    local color

    for color in "${css_colors[@]}"; do
        validate_css_color \
            "$theme_dir/colors.css" \
            "$color"
    done

    ok "CSS palette structure"


    # --------------------------------------------------------------------------
    # Hyprlock palette
    # --------------------------------------------------------------------------

    local lock_vars=(
        LOCK_FG
        LOCK_FG_ALT
        LOCK_MUTED
        LOCK_PRIMARY
        LOCK_SECONDARY
        LOCK_GREEN
        LOCK_YELLOW
        LOCK_RED
        LOCK_INNER
        LOCK_SHADOW
        LOCK_BORDER_GRADIENT
    )

    for variable in "${lock_vars[@]}"; do
        validate_assignment \
            "$theme_dir/hyprlock.env" \
            "$variable"
    done

    ok "Hyprlock palette structure"


    # --------------------------------------------------------------------------
    # Foot
    # --------------------------------------------------------------------------

    validate_foot "$theme_dir" "$theme_name"


    # --------------------------------------------------------------------------
    # Wallpapers
    # --------------------------------------------------------------------------

    validate_wallpaper \
        "$theme_dir" \
        "MAIN" \
        "$main_wallpaper"

    validate_wallpaper \
        "$theme_dir" \
        "SECONDARY" \
        "$secondary_wallpaper"
}


# ==============================================================================
# Main
# ==============================================================================

if [[ ! -d "$themes_dir" ]]; then
    fail "Themes directory not found: $themes_dir"
else

    if (($# > 0)); then

        for theme_name in "$@"; do

            theme_dir="$themes_dir/$theme_name"

            if [[ ! -d "$theme_dir" ]]; then
                fail "Theme not found: $theme_name"
                continue
            fi

            validate_theme "$theme_dir"
        done

    else

        shopt -s nullglob

        theme_dirs=("$themes_dir"/*)

        shopt -u nullglob

        if ((${#theme_dirs[@]} == 0)); then
            fail "No themes found"
        else

            for theme_dir in "${theme_dirs[@]}"; do
                [[ -d "$theme_dir" ]] || continue
                validate_theme "$theme_dir"
            done

        fi

    fi

fi


printf '\nTheme validation summary: %d error(s), %d warning(s)\n' \
    "$errors" \
    "$warnings"


if ((errors > 0)); then
    exit 1
fi