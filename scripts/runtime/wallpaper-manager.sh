#!/usr/bin/env bash
set -euo pipefail

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"

theme_link="$base/theme"
local_dir="$base/local"
preferences_dir="$local_dir/wallpapers"
wallpaper_env="$local_dir/wallpaper.env"

apply_script="$base/bin/apply-wallpaper.sh"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  wallpaper-manager.sh current
  wallpaper-manager.sh current --json
  wallpaper-manager.sh catalog
  wallpaper-manager.sh catalog --json
  wallpaper-manager.sh set main <file>
  wallpaper-manager.sh set secondary <file>
  wallpaper-manager.sh set both <file>
  wallpaper-manager.sh transactional-set <main|__KEEP__> <secondary|__KEEP__>
  wallpaper-manager.sh random main
  wallpaper-manager.sh random secondary
  wallpaper-manager.sh random both
  wallpaper-manager.sh next main
  wallpaper-manager.sh next secondary
  wallpaper-manager.sh next both
  wallpaper-manager.sh reset main
  wallpaper-manager.sh reset secondary
  wallpaper-manager.sh reset all
EOF
}

shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}

[[ -L "$theme_link" ]] || die "active theme link not found: $theme_link"

theme_root="$(readlink -f "$theme_link")"
theme_env="$theme_root/theme.env"

[[ -r "$theme_env" ]] || die "active theme configuration not found: $theme_env"

# shellcheck disable=SC1090
source "$theme_env"

: "${THEME_ID:?THEME_ID is required}"
: "${MAIN_WALLPAPER:?MAIN_WALLPAPER is required}"
: "${SECONDARY_WALLPAPER:?SECONDARY_WALLPAPER is required}"

WALLPAPER_LIBRARY_DIR="$HOME/Pictures/Wallpapers"

if [[ -r "$wallpaper_env" ]]; then
    # shellcheck disable=SC1090
    source "$wallpaper_env"
fi

WALLPAPER_LIBRARY_DIR="${WALLPAPER_LIBRARY_DIR:-$HOME/Pictures/Wallpapers}"
WALLPAPER_LIBRARY_DIR="${WALLPAPER_LIBRARY_DIR/#\~/$HOME}"

preferences_file="$preferences_dir/${THEME_ID}.env"

mkdir -p "$preferences_dir"

MAIN_WALLPAPER_OVERRIDE=""
SECONDARY_WALLPAPER_OVERRIDE=""
MAIN_WALLPAPER_FIT_OVERRIDE=""
SECONDARY_WALLPAPER_FIT_OVERRIDE=""

if [[ -r "$preferences_file" ]]; then
    # shellcheck disable=SC1090
    source "$preferences_file"
fi

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
    mv "$tmp_file" "$preferences_file"
    trap - RETURN
}

apply_preferences() {
    [[ -x "$apply_script" ]] || die "wallpaper runtime not found: $apply_script"
    "$apply_script"
}


acquire_mutation_lock() {
    local lock_file="$preferences_dir/.${THEME_ID}.mutation.lock"

    command -v flock >/dev/null 2>&1 \
        || die "flock is required for wallpaper mutation safety"

    exec 9>"$lock_file"
    flock -x 9
}


restore_preferences_snapshot() {
    local snapshot="$1"
    local existed="$2"
    local restore_tmp

    if [[ "$existed" == true ]]; then
        restore_tmp="$(
            mktemp "$preferences_dir/.${THEME_ID}.restore.XXXXXX"
        )"

        cat -- "$snapshot" > "$restore_tmp"
        chmod 0600 "$restore_tmp"
        mv -f -- "$restore_tmp" "$preferences_file"
    else
        rm -f -- "$preferences_file"
    fi
}


transactional_set_pair() {
    local requested_main="$1"
    local requested_secondary="$2"

    local snapshot
    local preferences_existed=false
    local apply_status=0
    local rollback_status=0

    if [[ "$requested_main" == "__KEEP__" \
        && "$requested_secondary" == "__KEEP__" ]]
    then
        die "transactional-set requires at least one wallpaper change"
    fi

    if [[ "$requested_main" != "__KEEP__" ]]; then
        MAIN_WALLPAPER_OVERRIDE="$(
            validate_wallpaper_file "$requested_main"
        )"
    fi

    if [[ "$requested_secondary" != "__KEEP__" ]]; then
        SECONDARY_WALLPAPER_OVERRIDE="$(
            validate_wallpaper_file "$requested_secondary"
        )"
    fi

    snapshot="$(mktemp "$preferences_dir/.${THEME_ID}.txn.XXXXXX")"

    cleanup_transaction_snapshot() {
        rm -f -- "$snapshot"
    }

    trap cleanup_transaction_snapshot RETURN

    if [[ -f "$preferences_file" ]]; then
        cat -- "$preferences_file" > "$snapshot"
        chmod 0600 "$snapshot"
        preferences_existed=true
    fi

    write_preferences

    if apply_preferences; then
        printf 'Wallpaper transaction committed:\n'
        printf '  theme:     %s\n' "$THEME_ID"

        if [[ "$requested_main" != "__KEEP__" ]]; then
            printf '  main:      %s\n' "$MAIN_WALLPAPER_OVERRIDE"
        else
            printf '  main:      (unchanged)\n'
        fi

        if [[ "$requested_secondary" != "__KEEP__" ]]; then
            printf '  secondary: %s\n' "$SECONDARY_WALLPAPER_OVERRIDE"
        else
            printf '  secondary: (unchanged)\n'
        fi

        trap - RETURN
        rm -f -- "$snapshot"
        return 0
    else
        apply_status=$?
    fi

    printf 'Wallpaper transaction failed; restoring previous preferences.\n' >&2
    restore_preferences_snapshot "$snapshot" "$preferences_existed"

    if apply_preferences; then
        printf 'Wallpaper rollback completed successfully.\n' >&2
    else
        rollback_status=$?

        printf 'ERROR: wallpaper preferences were restored, but runtime ' >&2
        printf 'rollback failed with exit code %s.\n' "$rollback_status" >&2

        trap - RETURN
        rm -f -- "$snapshot"
        return 7
    fi

    trap - RETURN
    rm -f -- "$snapshot"

    printf 'ERROR: wallpaper transaction rolled back after apply failure ' >&2
    printf '(exit code %s).\n' "$apply_status" >&2
    return "$apply_status"
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

    printf '\nLibrary:\n'
    printf '  %s\n' "$WALLPAPER_LIBRARY_DIR"
}

require_jq() {
    command -v jq >/dev/null 2>&1 \
        || die "jq is required for JSON output"
}


print_current_json() {
    local main_default
    local secondary_default
    local main_effective
    local secondary_effective
    local main_fit
    local secondary_fit
    local rotation_enabled

    require_jq

    main_default="$(resolve_theme_default "$MAIN_WALLPAPER")"
    secondary_default="$(resolve_theme_default "$SECONDARY_WALLPAPER")"

    main_effective="${MAIN_WALLPAPER_OVERRIDE:-$main_default}"
    secondary_effective="${SECONDARY_WALLPAPER_OVERRIDE:-$secondary_default}"

    main_fit="${MAIN_WALLPAPER_FIT_OVERRIDE:-${MAIN_WALLPAPER_FIT:-cover}}"
    secondary_fit="${SECONDARY_WALLPAPER_FIT_OVERRIDE:-${SECONDARY_WALLPAPER_FIT:-cover}}"

    case "${WALLPAPER_ROTATION_ENABLED:-false}" in
        true)
            rotation_enabled=true
            ;;
        *)
            rotation_enabled=false
            ;;
    esac

    jq -n \
        --arg themeId "$THEME_ID" \
        --arg themeRoot "$theme_root" \
        --arg preferencesFile "$preferences_file" \
        --arg libraryRoot "$WALLPAPER_LIBRARY_DIR" \
        --arg engine "${WALLPAPER_ENGINE:-auto}" \
        --arg transitionPreset "${WALLPAPER_TRANSITION_PRESET:-theme}" \
        --arg mainDefault "$main_default" \
        --arg mainOverride "$MAIN_WALLPAPER_OVERRIDE" \
        --arg mainEffective "$main_effective" \
        --arg mainFit "$main_fit" \
        --arg secondaryDefault "$secondary_default" \
        --arg secondaryOverride "$SECONDARY_WALLPAPER_OVERRIDE" \
        --arg secondaryEffective "$secondary_effective" \
        --arg secondaryFit "$secondary_fit" \
        --argjson rotationEnabled "$rotation_enabled" \
        --arg rotationMode "${WALLPAPER_ROTATION_MODE:-next}" \
        --arg rotationTarget "${WALLPAPER_ROTATION_TARGET:-both}" \
        --arg rotationInterval "${WALLPAPER_ROTATION_INTERVAL:-30m}" \
        '{
            theme: {
                id: $themeId,
                root: $themeRoot,
                preferencesFile: $preferencesFile
            },
            library: {
                root: $libraryRoot
            },
            engine: {
                configured: $engine
            },
            transition: {
                preset: $transitionPreset
            },
            rotation: {
                enabled: $rotationEnabled,
                mode: $rotationMode,
                target: $rotationTarget,
                interval: $rotationInterval
            },
            outputs: {
                main: {
                    default: $mainDefault,
                    override: $mainOverride,
                    effective: $mainEffective,
                    fit: $mainFit
                },
                secondary: {
                    default: $secondaryDefault,
                    override: $secondaryOverride,
                    effective: $secondaryEffective,
                    fit: $secondaryFit
                }
            }
        }'
}


print_catalog() {
    collect_wallpaper_candidates
    printf '%s\n' "${wallpaper_candidates[@]}"
}


print_catalog_json() {
    local theme_wallpapers
    local library_root
    local main_default
    local secondary_default
    local main_effective
    local secondary_effective

    require_jq
    collect_wallpaper_candidates

    theme_wallpapers="$(readlink -f "$theme_root/wallpapers" 2>/dev/null || true)"
    library_root="$(readlink -f "$WALLPAPER_LIBRARY_DIR" 2>/dev/null || true)"

    main_default="$(readlink -f "$(resolve_theme_default "$MAIN_WALLPAPER")")"
    secondary_default="$(readlink -f "$(resolve_theme_default "$SECONDARY_WALLPAPER")")"
    main_effective="$(effective_wallpaper_for_target main)"
    secondary_effective="$(effective_wallpaper_for_target secondary)"

    printf '%s\n' "${wallpaper_candidates[@]}" |
        jq -Rsc \
            --arg themeId "$THEME_ID" \
            --arg themeRoot "$theme_wallpapers" \
            --arg libraryRoot "$library_root" \
            --arg mainDefault "$main_default" \
            --arg secondaryDefault "$secondary_default" \
            --arg mainEffective "$main_effective" \
            --arg secondaryEffective "$secondary_effective" \
            '
            split("\n")
            | map(select(length > 0))
            | map(
                . as $path
                | {
                    path: $path,
                    name: ($path | split("/") | last),
                    source: (
                        if ($themeRoot != "" and ($path | startswith($themeRoot + "/")))
                        then "theme"
                        else "library"
                        end
                    ),
                    relative: (
                        if ($themeRoot != "" and ($path | startswith($themeRoot + "/")))
                        then ($path | ltrimstr($themeRoot + "/"))
                        elif ($libraryRoot != "" and ($path | startswith($libraryRoot + "/")))
                        then ($path | ltrimstr($libraryRoot + "/"))
                        else ($path | split("/") | last)
                        end
                    ),
                    defaultMain: ($path == $mainDefault),
                    defaultSecondary: ($path == $secondaryDefault),
                    effectiveMain: ($path == $mainEffective),
                    effectiveSecondary: ($path == $secondaryEffective)
                }
            )
            | {
                themeId: $themeId,
                themeRoot: $themeRoot,
                libraryRoot: $libraryRoot,
                count: length,
                items: .
            }
            '
}


validate_wallpaper_file() {
    local file="$1"

    [[ -f "$file" ]] || die "wallpaper file not found: $file"
    [[ -r "$file" ]] || die "wallpaper file is not readable: $file"

    readlink -f "$file"
}

effective_wallpaper_for_target() {
    local target="$1"
    local value
    local resolved

    case "$target" in
        main)
            value="${MAIN_WALLPAPER_OVERRIDE:-$MAIN_WALLPAPER}"
            ;;
        secondary)
            value="${SECONDARY_WALLPAPER_OVERRIDE:-$SECONDARY_WALLPAPER}"
            ;;
        *)
            die "unsupported wallpaper target: $target"
            ;;
    esac

    resolved="$(resolve_theme_default "$value")"
    readlink -f "$resolved"
}

wallpaper_candidates=()
declare -A wallpaper_candidate_seen=()

add_wallpaper_candidate() {
    local file="$1"
    local canonical

    canonical="$(readlink -f "$file")"

    [[ -n "$canonical" ]] || return 0
    [[ -f "$canonical" ]] || return 0
    [[ -r "$canonical" ]] || return 0

    if [[ -n "${wallpaper_candidate_seen[$canonical]:-}" ]]; then
        return 0
    fi

    wallpaper_candidate_seen["$canonical"]=1
    wallpaper_candidates+=("$canonical")
}

collect_wallpaper_candidates() {
    local theme_wallpapers="$theme_root/wallpapers"

    wallpaper_candidates=()
    wallpaper_candidate_seen=()

    if [[ -d "$theme_wallpapers" ]]; then
        while IFS= read -r -d '' wallpaper; do
            add_wallpaper_candidate "$wallpaper"
        done < <(
            find "$theme_wallpapers" \
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

    if [[ -d "$WALLPAPER_LIBRARY_DIR" ]]; then
        while IFS= read -r -d '' wallpaper; do
            add_wallpaper_candidate "$wallpaper"
        done < <(
            find "$WALLPAPER_LIBRARY_DIR" \
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

    ((${#wallpaper_candidates[@]} > 0)) || die "no wallpapers available"
}

choose_random_wallpaper() {
    local -a excluded=("$@")
    local -a eligible=()
    local candidate
    local excluded_path
    local skip

    for candidate in "${wallpaper_candidates[@]}"; do
        skip=false

        for excluded_path in "${excluded[@]}"; do
            if [[ "$candidate" == "$excluded_path" ]]; then
                skip=true
                break
            fi
        done

        if [[ "$skip" == false ]]; then
            eligible+=("$candidate")
        fi
    done

    if [[ ${#eligible[@]} -eq 0 && ${#excluded[@]} -gt 1 ]]; then
        for candidate in "${wallpaper_candidates[@]}"; do
            if [[ "$candidate" != "${excluded[0]}" ]]; then
                eligible+=("$candidate")
            fi
        done
    fi

    if [[ ${#eligible[@]} -eq 0 ]]; then
        eligible=("${wallpaper_candidates[@]}")
    fi

    printf '%s\n' "${eligible[RANDOM % ${#eligible[@]}]}"
}


choose_next_wallpaper() {
    local current="$1"
    local index

    ((${#wallpaper_candidates[@]} > 0)) \
        || die "no wallpapers available"

    for index in "${!wallpaper_candidates[@]}"; do
        if [[ "${wallpaper_candidates[$index]}" == "$current" ]]; then
            printf '%s\n' \
                "${wallpaper_candidates[((index + 1) % ${#wallpaper_candidates[@]} )]}"
            return 0
        fi
    done

    # If the current wallpaper is outside the active candidate collection,
    # start deterministically from the first available wallpaper.
    printf '%s\n' "${wallpaper_candidates[0]}"
}

command_name="${1:-}"

case "$command_name" in
    set|random|next|reset|transactional-set)
        acquire_mutation_lock
        ;;
esac

case "$command_name" in
    current)
        if [[ "$#" -eq 1 ]]; then
            print_current
        elif [[ "$#" -eq 2 && "$2" == "--json" ]]; then
            print_current_json
        else
            usage >&2
            exit 2
        fi
        ;;

    catalog)
        if [[ "$#" -eq 1 ]]; then
            print_catalog
        elif [[ "$#" -eq 2 && "$2" == "--json" ]]; then
            print_catalog_json
        else
            usage >&2
            exit 2
        fi
        ;;

    transactional-set)
        [[ "$#" -eq 3 ]] || {
            usage >&2
            exit 2
        }

        transactional_set_pair "$2" "$3"
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

    random)
        [[ "$#" -eq 2 ]] || {
            usage >&2
            exit 2
        }

        target="$2"

        case "$target" in
            main|secondary|both)
                ;;
            *)
                die "unsupported target: $target"
                ;;
        esac

        collect_wallpaper_candidates

        main_current="$(effective_wallpaper_for_target main)"
        secondary_current="$(effective_wallpaper_for_target secondary)"

        case "$target" in
            main)
                main_random="$(choose_random_wallpaper "$main_current")"
                MAIN_WALLPAPER_OVERRIDE="$main_random"
                ;;

            secondary)
                secondary_random="$(choose_random_wallpaper "$secondary_current")"
                SECONDARY_WALLPAPER_OVERRIDE="$secondary_random"
                ;;

            both)
                main_random="$(choose_random_wallpaper "$main_current")"
                secondary_random="$(
                    choose_random_wallpaper \
                        "$secondary_current" \
                        "$main_random"
                )"

                MAIN_WALLPAPER_OVERRIDE="$main_random"
                SECONDARY_WALLPAPER_OVERRIDE="$secondary_random"
                ;;
        esac

        write_preferences

        printf 'Random wallpaper selected:\n'
        printf '  theme:  %s\n' "$THEME_ID"
        printf '  target: %s\n' "$target"

        case "$target" in
            main)
                printf '  main:   %s\n' "$MAIN_WALLPAPER_OVERRIDE"
                ;;
            secondary)
                printf '  second: %s\n' "$SECONDARY_WALLPAPER_OVERRIDE"
                ;;
            both)
                printf '  main:   %s\n' "$MAIN_WALLPAPER_OVERRIDE"
                printf '  second: %s\n' "$SECONDARY_WALLPAPER_OVERRIDE"
                ;;
        esac

        echo
        apply_preferences
        ;;

    next)
        [[ "$#" -eq 2 ]] || {
            usage >&2
            exit 2
        }

        target="$2"

        case "$target" in
            main|secondary|both)
                ;;
            *)
                die "unsupported target: $target"
                ;;
        esac

        collect_wallpaper_candidates

        main_current="$(effective_wallpaper_for_target main)"
        secondary_current="$(effective_wallpaper_for_target secondary)"

        case "$target" in
            main)
                MAIN_WALLPAPER_OVERRIDE="$(
                    choose_next_wallpaper "$main_current"
                )"
                ;;

            secondary)
                SECONDARY_WALLPAPER_OVERRIDE="$(
                    choose_next_wallpaper "$secondary_current"
                )"
                ;;

            both)
                MAIN_WALLPAPER_OVERRIDE="$(
                    choose_next_wallpaper "$main_current"
                )"

                SECONDARY_WALLPAPER_OVERRIDE="$(
                    choose_next_wallpaper "$secondary_current"
                )"

                # If both monitors land on the same candidate and there is
                # more than one wallpaper available, advance SECONDARY once
                # more so the pair remains visually distinct.
                if [[ "$MAIN_WALLPAPER_OVERRIDE" == "$SECONDARY_WALLPAPER_OVERRIDE" \
                    && ${#wallpaper_candidates[@]} -gt 1 ]]
                then
                    SECONDARY_WALLPAPER_OVERRIDE="$(
                        choose_next_wallpaper \
                            "$SECONDARY_WALLPAPER_OVERRIDE"
                    )"
                fi
                ;;
        esac

        write_preferences

        printf 'Next wallpaper selected:\n'
        printf '  theme:  %s\n' "$THEME_ID"
        printf '  target: %s\n' "$target"

        case "$target" in
            main)
                printf '  main:   %s\n' "$MAIN_WALLPAPER_OVERRIDE"
                ;;

            secondary)
                printf '  second: %s\n' "$SECONDARY_WALLPAPER_OVERRIDE"
                ;;

            both)
                printf '  main:   %s\n' "$MAIN_WALLPAPER_OVERRIDE"
                printf '  second: %s\n' "$SECONDARY_WALLPAPER_OVERRIDE"
                ;;
        esac

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
