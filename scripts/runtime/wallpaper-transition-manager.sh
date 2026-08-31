#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Wallpaper transition configuration backend
#
# Owns machine-local transition persistence in wallpaper.env.
# Public callers must use jc-wallpaperctl instead of invoking this directly.
#
# wallpaper.env is also written by wallpaper-rotation-manager.sh. Both mutation
# owners therefore acquire the same global wallpaper.env lock.
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
local_dir="$base/local"
wallpaper_env="$local_dir/wallpaper.env"
theme_env="$base/theme/theme.env"
preferences_dir="$local_dir/wallpapers"

apply_script="$base/bin/apply-wallpaper.sh"

wallpaper_env_lock="$local_dir/.wallpaper-env.mutation.lock"


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


usage() {
    cat <<'EOF'
Usage:
  wallpaper-transition-manager.sh current
  wallpaper-transition-manager.sh current --json
  wallpaper-transition-manager.sh transactional-set <preset|__KEEP__> <type|__KEEP__|__INHERIT__> <duration|__KEEP__|__INHERIT__> <fps|__KEEP__|__INHERIT__>

Internal transition presets:
  theme
  default
  fade
  cyber-noir
  odyssey-glass

Internal override sentinel:
  __INHERIT__   Remove the explicit value and inherit it from the preset.
EOF
}


require_jq() {
    command -v jq >/dev/null 2>&1 \
        || die "jq is required"
}


validate_preset() {
    case "$1" in
        theme|default|fade|cyber-noir|odyssey-glass)
            printf '%s\n' "$1"
            ;;
        *)
            return 1
            ;;
    esac
}


validate_type() {
    case "$1" in
        none|simple|fade|left|right|top|bottom|wipe|wave|grow|center|any|outer|random)
            printf '%s\n' "$1"
            ;;
        *)
            return 1
            ;;
    esac
}


validate_duration() {
    local value="$1"

    [[ "$value" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]] \
        || return 1

    awk -v value="$value" \
        'BEGIN { exit !((value + 0) > 0) }' \
        || return 1

    printf '%s\n' "$value"
}


validate_fps() {
    local value="$1"

    [[ "$value" =~ ^[1-9][0-9]*$ ]] \
        || return 1

    printf '%s\n' "$value"
}


shell_quote() {
    local value="$1"
    printf "'%s'" "${value//\'/\'\\\'\'}"
}


shell_assignment_value() {
    local value="$1"

    if [[ "$value" =~ ^[A-Za-z0-9_./:+-]+$ ]]; then
        printf '%s\n' "$value"
    else
        shell_quote "$value"
        printf '\n'
    fi
}


load_configuration() {
    [[ -r "$theme_env" ]] \
        || die "active theme configuration not found: $theme_env"

    [[ -r "$wallpaper_env" ]] \
        || die "wallpaper configuration not found: $wallpaper_env"

    unset THEME_ID
    unset THEME_WALLPAPER_TRANSITION_PRESET
    unset WALLPAPER_TRANSITION_PRESET
    unset WALLPAPER_TRANSITION_TYPE
    unset WALLPAPER_TRANSITION_DURATION
    unset WALLPAPER_TRANSITION_FPS

    # shellcheck disable=SC1090
    source "$theme_env"

    : "${THEME_ID:?THEME_ID is required}"

    WALLPAPER_TRANSITION_PRESET=theme
    WALLPAPER_TRANSITION_TYPE=""
    WALLPAPER_TRANSITION_DURATION=""
    WALLPAPER_TRANSITION_FPS=""

    # shellcheck disable=SC1090
    source "$wallpaper_env"

    WALLPAPER_TRANSITION_PRESET="$(
        validate_preset "$WALLPAPER_TRANSITION_PRESET"
    )" || die \
        "invalid WALLPAPER_TRANSITION_PRESET: $WALLPAPER_TRANSITION_PRESET"

    if [[ -n "$WALLPAPER_TRANSITION_TYPE" ]]; then
        WALLPAPER_TRANSITION_TYPE="$(
            validate_type "$WALLPAPER_TRANSITION_TYPE"
        )" || die \
            "invalid WALLPAPER_TRANSITION_TYPE: $WALLPAPER_TRANSITION_TYPE"
    fi

    if [[ -n "$WALLPAPER_TRANSITION_DURATION" ]]; then
        WALLPAPER_TRANSITION_DURATION="$(
            validate_duration "$WALLPAPER_TRANSITION_DURATION"
        )" || die \
            "invalid WALLPAPER_TRANSITION_DURATION: $WALLPAPER_TRANSITION_DURATION"
    fi

    if [[ -n "$WALLPAPER_TRANSITION_FPS" ]]; then
        WALLPAPER_TRANSITION_FPS="$(
            validate_fps "$WALLPAPER_TRANSITION_FPS"
        )" || die \
            "invalid WALLPAPER_TRANSITION_FPS: $WALLPAPER_TRANSITION_FPS"
    fi
}


resolve_transition_preset() {
    local preset="$1"

    case "$preset" in
        theme)
            preset="${THEME_WALLPAPER_TRANSITION_PRESET:-default}"
            ;;
    esac

    case "$preset" in
        cyber-noir)
            TRANSITION_PRESET_TYPE=wipe
            TRANSITION_PRESET_DURATION=1.6
            TRANSITION_PRESET_FPS=60
            ;;
        odyssey-glass)
            TRANSITION_PRESET_TYPE=fade
            TRANSITION_PRESET_DURATION=1.8
            TRANSITION_PRESET_FPS=60
            ;;
        default|fade)
            TRANSITION_PRESET_TYPE=fade
            TRANSITION_PRESET_DURATION=1.2
            TRANSITION_PRESET_FPS=60
            ;;
        *)
            die "unsupported resolved wallpaper transition preset: $preset"
            ;;
    esac

    TRANSITION_PRESET_NAME="$preset"
}


print_current_json() {
    local effective_type
    local effective_duration
    local effective_fps

    require_jq
    load_configuration
    resolve_transition_preset "$WALLPAPER_TRANSITION_PRESET"

    effective_type="${WALLPAPER_TRANSITION_TYPE:-$TRANSITION_PRESET_TYPE}"
    effective_duration="${WALLPAPER_TRANSITION_DURATION:-$TRANSITION_PRESET_DURATION}"
    effective_fps="${WALLPAPER_TRANSITION_FPS:-$TRANSITION_PRESET_FPS}"

    jq -n \
        --arg preset "$WALLPAPER_TRANSITION_PRESET" \
        --arg resolvedPreset "$TRANSITION_PRESET_NAME" \
        --arg typeOverride "$WALLPAPER_TRANSITION_TYPE" \
        --arg durationOverride "$WALLPAPER_TRANSITION_DURATION" \
        --arg fpsOverride "$WALLPAPER_TRANSITION_FPS" \
        --arg effectiveType "$effective_type" \
        --arg effectiveDuration "$effective_duration" \
        --arg effectiveFps "$effective_fps" \
        --arg configFile "$wallpaper_env" \
        '{
            preset: $preset,
            resolvedPreset: $resolvedPreset,
            overrides: {
                type:
                    (if $typeOverride == ""
                     then null
                     else $typeOverride
                     end),
                duration:
                    (if $durationOverride == ""
                     then null
                     else ($durationOverride | tonumber)
                     end),
                fps:
                    (if $fpsOverride == ""
                     then null
                     else ($fpsOverride | tonumber)
                     end)
            },
            effective: {
                type: $effectiveType,
                duration: ($effectiveDuration | tonumber),
                fps: ($effectiveFps | tonumber)
            },
            configFile: $configFile
        }'
}


print_current() {
    local status

    status="$(print_current_json)"

    printf 'Wallpaper transition:\n'
    printf '  preset:          %s\n' "$(jq -r '.preset' <<< "$status")"
    printf '  resolved preset: %s\n' "$(jq -r '.resolvedPreset' <<< "$status")"
    printf '  type override:   %s\n' \
        "$(jq -r '.overrides.type // "(preset)"' <<< "$status")"
    printf '  duration:        %s\n' \
        "$(jq -r 'if .overrides.duration == null then "(preset)" else (.overrides.duration | tostring) end' <<< "$status")"
    printf '  fps override:    %s\n' \
        "$(jq -r 'if .overrides.fps == null then "(preset)" else (.overrides.fps | tostring) end' <<< "$status")"
    printf '  effective:       %s / %ss / %s FPS\n' \
        "$(jq -r '.effective.type' <<< "$status")" \
        "$(jq -r '.effective.duration' <<< "$status")" \
        "$(jq -r '.effective.fps' <<< "$status")"
}


acquire_wallpaper_env_lock() {
    command -v flock >/dev/null 2>&1 \
        || die "flock is required for wallpaper.env mutation safety"

    mkdir -p "$local_dir"

    exec 9>"$wallpaper_env_lock"
    flock -x 9
}


acquire_theme_mutation_lock() {
    local theme_lock

    mkdir -p "$preferences_dir"

    theme_lock="$preferences_dir/.${THEME_ID}.mutation.lock"

    exec 8>"$theme_lock"
    flock -x 8
}


write_transition_configuration() {
    local preset="$1"
    local type_override="$2"
    local duration_override="$3"
    local fps_override="$4"

    local preset_q
    local type_q=""
    local duration_q=""
    local fps_q=""
    local has_type=0
    local has_duration=0
    local has_fps=0
    local tmp_file

    preset_q="$(shell_assignment_value "$preset")"

    if [[ -n "$type_override" ]]; then
        type_q="$(shell_assignment_value "$type_override")"
        has_type=1
    fi

    if [[ -n "$duration_override" ]]; then
        duration_q="$(shell_assignment_value "$duration_override")"
        has_duration=1
    fi

    if [[ -n "$fps_override" ]]; then
        fps_q="$(shell_assignment_value "$fps_override")"
        has_fps=1
    fi

    tmp_file="$(mktemp "$local_dir/.wallpaper.env.transition.XXXXXX")"

    awk \
        -v preset="$preset_q" \
        -v type="$type_q" \
        -v duration="$duration_q" \
        -v fps="$fps_q" \
        -v has_type="$has_type" \
        -v has_duration="$has_duration" \
        -v has_fps="$has_fps" \
        '
        function emit_transition_block() {
            if (emitted)
                return

            print "WALLPAPER_TRANSITION_PRESET=" preset

            if (has_type)
                print "WALLPAPER_TRANSITION_TYPE=" type

            if (has_duration)
                print "WALLPAPER_TRANSITION_DURATION=" duration

            if (has_fps)
                print "WALLPAPER_TRANSITION_FPS=" fps

            emitted = 1
        }

        BEGIN {
            emitted = 0
        }

        /^[[:space:]]*(export[[:space:]]+)?WALLPAPER_TRANSITION_(PRESET|TYPE|DURATION|FPS)=/ {
            emit_transition_block()
            next
        }

        {
            print
        }

        END {
            emit_transition_block()
        }
        ' \
        "$wallpaper_env" > "$tmp_file"

    chmod --reference="$wallpaper_env" "$tmp_file" 2>/dev/null \
        || chmod 0600 "$tmp_file"

    mv -f -- "$tmp_file" "$wallpaper_env"
}


verify_expected_state() {
    local preset="$1"
    local type_override="$2"
    local duration_override="$3"
    local fps_override="$4"
    local status

    status="$(print_current_json)"

    jq -e \
        --arg preset "$preset" \
        --arg typeOverride "$type_override" \
        --arg durationOverride "$duration_override" \
        --arg fpsOverride "$fps_override" \
        '
        .preset == $preset
        and .overrides.type ==
            (if $typeOverride == ""
             then null
             else $typeOverride
             end)
        and .overrides.duration ==
            (if $durationOverride == ""
             then null
             else ($durationOverride | tonumber)
             end)
        and .overrides.fps ==
            (if $fpsOverride == ""
             then null
             else ($fpsOverride | tonumber)
             end)
        ' \
        <<< "$status" >/dev/null
}


transactional_set() {
    local requested_preset="$1"
    local requested_type="$2"
    local requested_duration="$3"
    local requested_fps="$4"

    local before_preset
    local before_type
    local before_duration
    local before_fps

    local next_preset
    local next_type
    local next_duration
    local next_fps

    local snapshot
    local apply_log
    local rollback_log

    [[ "$requested_preset" != "__KEEP__" \
        || "$requested_type" != "__KEEP__" \
        || "$requested_duration" != "__KEEP__" \
        || "$requested_fps" != "__KEEP__" ]] \
        || die "transactional-set requires at least one transition change"

    [[ -x "$apply_script" ]] \
        || die "wallpaper runtime not found: $apply_script"

    acquire_wallpaper_env_lock
    load_configuration
    acquire_theme_mutation_lock

    before_preset="$WALLPAPER_TRANSITION_PRESET"
    before_type="$WALLPAPER_TRANSITION_TYPE"
    before_duration="$WALLPAPER_TRANSITION_DURATION"
    before_fps="$WALLPAPER_TRANSITION_FPS"

    next_preset="$before_preset"
    next_type="$before_type"
    next_duration="$before_duration"
    next_fps="$before_fps"

    if [[ "$requested_preset" != "__KEEP__" ]]; then
        next_preset="$(
            validate_preset "$requested_preset"
        )" || die "unsupported transition preset: $requested_preset"
    fi

    if [[ "$requested_type" == "__INHERIT__" ]]; then
        next_type=""
    elif [[ "$requested_type" != "__KEEP__" ]]; then
        next_type="$(
            validate_type "$requested_type"
        )" || die "unsupported transition type: $requested_type"
    fi

    if [[ "$requested_duration" == "__INHERIT__" ]]; then
        next_duration=""
    elif [[ "$requested_duration" != "__KEEP__" ]]; then
        next_duration="$(
            validate_duration "$requested_duration"
        )" || die "unsupported transition duration: $requested_duration"
    fi

    if [[ "$requested_fps" == "__INHERIT__" ]]; then
        next_fps=""
    elif [[ "$requested_fps" != "__KEEP__" ]]; then
        next_fps="$(
            validate_fps "$requested_fps"
        )" || die "unsupported transition FPS: $requested_fps"
    fi

    snapshot="$(mktemp "$local_dir/.wallpaper.env.transition-snapshot.XXXXXX")"
    apply_log="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/jc-transition-apply.XXXXXX")"
    rollback_log="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/jc-transition-rollback.XXXXXX")"

    cp -p -- "$wallpaper_env" "$snapshot"

    cleanup_transaction() {
        rm -f -- "$snapshot" "$apply_log" "$rollback_log"
    }

    trap cleanup_transaction RETURN

    write_transition_configuration \
        "$next_preset" \
        "$next_type" \
        "$next_duration" \
        "$next_fps"

    if "$apply_script" >"$apply_log" 2>&1 \
        && verify_expected_state \
            "$next_preset" \
            "$next_type" \
            "$next_duration" \
            "$next_fps"
    then
        cat "$apply_log"

        printf '\nTransition transaction committed:\n'
        printf '  preset:   %s\n' "$next_preset"
        printf '  type:     %s\n' "${next_type:-"(preset)"}"
        printf '  duration: %s\n' "${next_duration:-"(preset)"}"
        printf '  fps:      %s\n' "${next_fps:-"(preset)"}"

        trap - RETURN
        cleanup_transaction
        return 0
    fi

    printf 'Transition transaction failed; restoring wallpaper.env.\n' >&2

    cp -p -- "$snapshot" "$wallpaper_env"

    if "$apply_script" >"$rollback_log" 2>&1 \
        && verify_expected_state \
            "$before_preset" \
            "$before_type" \
            "$before_duration" \
            "$before_fps"
    then
        cat "$apply_log" >&2
        cat "$rollback_log" >&2
        printf 'Transition rollback completed successfully.\n' >&2

        trap - RETURN
        cleanup_transaction
        return 6
    fi

    cat "$apply_log" >&2
    cat "$rollback_log" >&2
    printf 'ERROR: transition configuration was restored, but runtime rollback could not be verified.\n' >&2

    trap - RETURN
    cleanup_transaction
    return 7
}


command_name="${1:-}"

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

    transactional-set)
        [[ "$#" -eq 5 ]] || {
            usage >&2
            exit 2
        }

        transactional_set "$2" "$3" "$4" "$5"
        ;;

    --help|-h|help)
        usage
        ;;

    *)
        usage >&2
        exit 2
        ;;
esac
