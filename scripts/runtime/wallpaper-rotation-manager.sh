#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Wallpaper rotation configuration backend
#
# Owns machine-local rotation persistence and systemd reconciliation.
# Public callers must use jc-wallpaperctl instead of invoking this directly.
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
local_dir="$base/local"
wallpaper_env="$local_dir/wallpaper.env"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
systemd_user_dir="$config_home/systemd/user"
dropin_file="$systemd_user_dir/jc-wallpaper-rotation.timer.d/interval.conf"

timer_unit="jc-wallpaper-rotation.timer"
service_unit="jc-wallpaper-rotation.service"

script_real="$(readlink -f -- "$0")"
runtime_dir="$(dirname "$script_real")"
configurator="$runtime_dir/../configure-wallpaper-rotation.sh"

lock_file="$local_dir/.wallpaper-env.mutation.lock"


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


usage() {
    cat <<'EOF'
Usage:
  wallpaper-rotation-manager.sh current
  wallpaper-rotation-manager.sh current --json
  wallpaper-rotation-manager.sh transactional-set <enabled|__KEEP__> <mode|__KEEP__> <target|__KEEP__> <interval|__KEEP__>
EOF
}


require_jq() {
    command -v jq >/dev/null 2>&1 \
        || die "jq is required"
}


validate_enabled() {
    case "$1" in
        true|false)
            printf '%s\n' "$1"
            ;;
        *)
            return 1
            ;;
    esac
}


validate_mode() {
    case "$1" in
        next|random)
            printf '%s\n' "$1"
            ;;
        *)
            return 1
            ;;
    esac
}


validate_target() {
    case "$1" in
        main|secondary|both)
            printf '%s\n' "$1"
            ;;
        *)
            return 1
            ;;
    esac
}


validate_interval() {
    local value="$1"

    command -v systemd-analyze >/dev/null 2>&1 \
        || return 1

    systemd-analyze timespan "$value" >/dev/null 2>&1 \
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
    [[ -r "$wallpaper_env" ]] \
        || die "wallpaper configuration not found: $wallpaper_env"

    WALLPAPER_ROTATION_ENABLED=false
    WALLPAPER_ROTATION_MODE=next
    WALLPAPER_ROTATION_TARGET=both
    WALLPAPER_ROTATION_INTERVAL=30m

    # shellcheck disable=SC1090
    source "$wallpaper_env"

    WALLPAPER_ROTATION_ENABLED="$(
        validate_enabled "$WALLPAPER_ROTATION_ENABLED"
    )" || die \
        "invalid WALLPAPER_ROTATION_ENABLED: $WALLPAPER_ROTATION_ENABLED"

    WALLPAPER_ROTATION_MODE="$(
        validate_mode "$WALLPAPER_ROTATION_MODE"
    )" || die \
        "invalid WALLPAPER_ROTATION_MODE: $WALLPAPER_ROTATION_MODE"

    WALLPAPER_ROTATION_TARGET="$(
        validate_target "$WALLPAPER_ROTATION_TARGET"
    )" || die \
        "invalid WALLPAPER_ROTATION_TARGET: $WALLPAPER_ROTATION_TARGET"

    WALLPAPER_ROTATION_INTERVAL="$(
        validate_interval "$WALLPAPER_ROTATION_INTERVAL"
    )" || die \
        "invalid WALLPAPER_ROTATION_INTERVAL: $WALLPAPER_ROTATION_INTERVAL"
}


systemctl_value() {
    local unit="$1"
    local property="$2"

    systemctl --user show \
        "$unit" \
        --property="$property" \
        --value \
        2>/dev/null || true
}


runtime_json() {
    local timer_load_state
    local timer_enable_state
    local timer_active_state
    local timer_sub_state
    local service_load_state
    local service_active_state
    local dropin_present=false
    local interval_synchronized=false
    local lifecycle_synchronized=false
    local synchronized=false

    require_jq

    timer_load_state="$(systemctl_value "$timer_unit" LoadState)"
    timer_enable_state="$(
        systemctl --user is-enabled "$timer_unit" 2>/dev/null || true
    )"
    timer_active_state="$(
        systemctl --user is-active "$timer_unit" 2>/dev/null || true
    )"
    timer_sub_state="$(systemctl_value "$timer_unit" SubState)"

    service_load_state="$(systemctl_value "$service_unit" LoadState)"
    service_active_state="$(
        systemctl --user is-active "$service_unit" 2>/dev/null || true
    )"

    if [[ -r "$dropin_file" ]]; then
        dropin_present=true

        if grep -Fqx \
            "OnActiveSec=$WALLPAPER_ROTATION_INTERVAL" \
            "$dropin_file" &&
            grep -Fqx \
                "OnUnitActiveSec=$WALLPAPER_ROTATION_INTERVAL" \
                "$dropin_file"
        then
            interval_synchronized=true
        fi
    fi

    if [[ "$WALLPAPER_ROTATION_ENABLED" == true ]]; then
        if [[ "$timer_enable_state" == enabled \
            && "$timer_active_state" == active ]]
        then
            lifecycle_synchronized=true
        fi
    else
        if [[ "$timer_enable_state" == linked \
            && "$timer_active_state" == inactive ]]
        then
            lifecycle_synchronized=true
        fi
    fi

    if [[ "$timer_load_state" == loaded \
        && "$service_load_state" == loaded \
        && "$interval_synchronized" == true \
        && "$lifecycle_synchronized" == true ]]
    then
        synchronized=true
    fi

    jq -n \
        --arg timerUnit "$timer_unit" \
        --arg timerLoadState "$timer_load_state" \
        --arg timerEnableState "$timer_enable_state" \
        --arg timerActiveState "$timer_active_state" \
        --arg timerSubState "$timer_sub_state" \
        --arg serviceUnit "$service_unit" \
        --arg serviceLoadState "$service_load_state" \
        --arg serviceActiveState "$service_active_state" \
        --arg dropIn "$dropin_file" \
        --argjson dropInPresent "$dropin_present" \
        --argjson intervalSynchronized "$interval_synchronized" \
        --argjson lifecycleSynchronized "$lifecycle_synchronized" \
        --argjson synchronized "$synchronized" \
        '{
            timer: {
                unit: $timerUnit,
                loadState: $timerLoadState,
                enableState: $timerEnableState,
                activeState: $timerActiveState,
                subState: $timerSubState
            },
            service: {
                unit: $serviceUnit,
                loadState: $serviceLoadState,
                activeState: $serviceActiveState
            },
            dropIn: {
                path: $dropIn,
                present: $dropInPresent
            },
            intervalSynchronized: $intervalSynchronized,
            lifecycleSynchronized: $lifecycleSynchronized,
            synchronized: $synchronized
        }'
}


print_current_json() {
    local runtime
    local enabled_json=false

    require_jq
    load_configuration

    [[ "$WALLPAPER_ROTATION_ENABLED" == true ]] \
        && enabled_json=true

    runtime="$(runtime_json)"

    jq -n \
        --argjson enabled "$enabled_json" \
        --arg mode "$WALLPAPER_ROTATION_MODE" \
        --arg target "$WALLPAPER_ROTATION_TARGET" \
        --arg interval "$WALLPAPER_ROTATION_INTERVAL" \
        --arg configFile "$wallpaper_env" \
        --argjson runtime "$runtime" \
        '{
            enabled: $enabled,
            mode: $mode,
            target: $target,
            interval: $interval,
            configFile: $configFile,
            runtime: $runtime
        }'
}


print_current() {
    local status

    status="$(print_current_json)"

    printf 'Wallpaper rotation:\n'
    printf '  enabled:      %s\n' "$(jq -r '.enabled' <<< "$status")"
    printf '  mode:         %s\n' "$(jq -r '.mode' <<< "$status")"
    printf '  target:       %s\n' "$(jq -r '.target' <<< "$status")"
    printf '  interval:     %s\n' "$(jq -r '.interval' <<< "$status")"
    printf '  synchronized: %s\n' "$(jq -r '.runtime.synchronized' <<< "$status")"
    printf '  timer:        %s / %s / %s\n' \
        "$(jq -r '.runtime.timer.enableState' <<< "$status")" \
        "$(jq -r '.runtime.timer.activeState' <<< "$status")" \
        "$(jq -r '.runtime.timer.subState' <<< "$status")"
}


acquire_mutation_lock() {
    command -v flock >/dev/null 2>&1 \
        || die "flock is required for rotation mutation safety"

    mkdir -p "$local_dir"

    exec 9>"$lock_file"
    flock -x 9
}


write_rotation_configuration() {
    local enabled="$1"
    local mode="$2"
    local target="$3"
    local interval="$4"

    local enabled_q
    local mode_q
    local target_q
    local interval_q
    local tmp_file

    enabled_q="$(shell_assignment_value "$enabled")"
    mode_q="$(shell_assignment_value "$mode")"
    target_q="$(shell_assignment_value "$target")"
    interval_q="$(shell_assignment_value "$interval")"

    tmp_file="$(mktemp "$local_dir/.wallpaper.env.rotation.XXXXXX")"

    awk \
        -v enabled="$enabled_q" \
        -v mode="$mode_q" \
        -v target="$target_q" \
        -v interval="$interval_q" \
        '
        BEGIN {
            seen_enabled = 0
            seen_mode = 0
            seen_target = 0
            seen_interval = 0
        }

        /^[[:space:]]*(export[[:space:]]+)?WALLPAPER_ROTATION_ENABLED=/ {
            if (!seen_enabled) {
                print "WALLPAPER_ROTATION_ENABLED=" enabled
                seen_enabled = 1
            }
            next
        }

        /^[[:space:]]*(export[[:space:]]+)?WALLPAPER_ROTATION_MODE=/ {
            if (!seen_mode) {
                print "WALLPAPER_ROTATION_MODE=" mode
                seen_mode = 1
            }
            next
        }

        /^[[:space:]]*(export[[:space:]]+)?WALLPAPER_ROTATION_TARGET=/ {
            if (!seen_target) {
                print "WALLPAPER_ROTATION_TARGET=" target
                seen_target = 1
            }
            next
        }

        /^[[:space:]]*(export[[:space:]]+)?WALLPAPER_ROTATION_INTERVAL=/ {
            if (!seen_interval) {
                print "WALLPAPER_ROTATION_INTERVAL=" interval
                seen_interval = 1
            }
            next
        }

        {
            print
        }

        END {
            if (!seen_enabled)
                print "WALLPAPER_ROTATION_ENABLED=" enabled
            if (!seen_mode)
                print "WALLPAPER_ROTATION_MODE=" mode
            if (!seen_target)
                print "WALLPAPER_ROTATION_TARGET=" target
            if (!seen_interval)
                print "WALLPAPER_ROTATION_INTERVAL=" interval
        }
        ' \
        "$wallpaper_env" > "$tmp_file"

    chmod --reference="$wallpaper_env" "$tmp_file" 2>/dev/null \
        || chmod 0600 "$tmp_file"

    mv -f -- "$tmp_file" "$wallpaper_env"
}


verify_expected_state() {
    local enabled="$1"
    local mode="$2"
    local target="$3"
    local interval="$4"
    local status
    local enabled_json=false

    [[ "$enabled" == true ]] && enabled_json=true

    status="$(print_current_json)"

    jq -e \
        --argjson enabled "$enabled_json" \
        --arg mode "$mode" \
        --arg target "$target" \
        --arg interval "$interval" \
        '
        .enabled == $enabled
        and .mode == $mode
        and .target == $target
        and .interval == $interval
        and .runtime.synchronized
        ' \
        <<< "$status" >/dev/null
}


transactional_set() {
    local requested_enabled="$1"
    local requested_mode="$2"
    local requested_target="$3"
    local requested_interval="$4"

    local before_enabled
    local before_mode
    local before_target
    local before_interval

    local next_enabled
    local next_mode
    local next_target
    local next_interval

    local snapshot
    local configure_log
    local rollback_log

    [[ -x "$configurator" ]] \
        || die "rotation configurator not found: $configurator"

    acquire_mutation_lock
    load_configuration

    before_enabled="$WALLPAPER_ROTATION_ENABLED"
    before_mode="$WALLPAPER_ROTATION_MODE"
    before_target="$WALLPAPER_ROTATION_TARGET"
    before_interval="$WALLPAPER_ROTATION_INTERVAL"

    next_enabled="$before_enabled"
    next_mode="$before_mode"
    next_target="$before_target"
    next_interval="$before_interval"

    if [[ "$requested_enabled" != "__KEEP__" ]]; then
        next_enabled="$(
            validate_enabled "$requested_enabled"
        )" || die "unsupported rotation enabled value: $requested_enabled"
    fi

    if [[ "$requested_mode" != "__KEEP__" ]]; then
        next_mode="$(
            validate_mode "$requested_mode"
        )" || die "unsupported rotation mode: $requested_mode"
    fi

    if [[ "$requested_target" != "__KEEP__" ]]; then
        next_target="$(
            validate_target "$requested_target"
        )" || die "unsupported rotation target: $requested_target"
    fi

    if [[ "$requested_interval" != "__KEEP__" ]]; then
        next_interval="$(
            validate_interval "$requested_interval"
        )" || die "unsupported rotation interval: $requested_interval"
    fi

    snapshot="$(mktemp "$local_dir/.wallpaper.env.rotation-snapshot.XXXXXX")"
    configure_log="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/jc-rotation-configure.XXXXXX")"
    rollback_log="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/jc-rotation-rollback.XXXXXX")"

    cp -p -- "$wallpaper_env" "$snapshot"

    cleanup_transaction() {
        rm -f -- "$snapshot" "$configure_log" "$rollback_log"
    }

    trap cleanup_transaction RETURN

    write_rotation_configuration \
        "$next_enabled" \
        "$next_mode" \
        "$next_target" \
        "$next_interval"

    if "$configurator" >"$configure_log" 2>&1 \
        && verify_expected_state \
            "$next_enabled" \
            "$next_mode" \
            "$next_target" \
            "$next_interval"
    then
        cat "$configure_log"

        printf '\nRotation transaction committed:\n'
        printf '  enabled:  %s\n' "$next_enabled"
        printf '  mode:     %s\n' "$next_mode"
        printf '  target:   %s\n' "$next_target"
        printf '  interval: %s\n' "$next_interval"

        trap - RETURN
        cleanup_transaction
        return 0
    fi

    printf 'Rotation transaction failed; restoring wallpaper.env.\n' >&2

    cp -p -- "$snapshot" "$wallpaper_env"

    if "$configurator" >"$rollback_log" 2>&1 \
        && verify_expected_state \
            "$before_enabled" \
            "$before_mode" \
            "$before_target" \
            "$before_interval"
    then
        cat "$configure_log" >&2
        cat "$rollback_log" >&2
        printf 'Rotation rollback completed successfully.\n' >&2

        trap - RETURN
        cleanup_transaction
        return 6
    fi

    cat "$configure_log" >&2
    cat "$rollback_log" >&2
    printf 'ERROR: rotation configuration was restored, but runtime rollback could not be verified.\n' >&2

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
