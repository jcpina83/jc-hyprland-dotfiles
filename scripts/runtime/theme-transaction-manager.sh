#!/usr/bin/env bash
set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
runtime_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$runtime_dir/../.." && pwd)"

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
local_dir="$base/local"
themes_dir="$repo_root/themes"
preferences_dir="$local_dir/wallpapers"

active_link="$base/theme"
active_file="$local_dir/active-theme"

theme_lock="$local_dir/.theme.mutation.lock"
wallpaper_env_lock="$local_dir/.wallpaper-env.mutation.lock"

wallpaper_apply="$repo_root/scripts/runtime/apply-wallpaper.sh"
waybar_runtime="$repo_root/scripts/runtime/start-waybar.sh"
swaync_runtime="$repo_root/scripts/runtime/start-swaync.sh"
sddm_prepare="$repo_root/scripts/runtime/prepare-sddm-theme.sh"
sddm_switch="/usr/local/libexec/jc-hyprland-sddm-switch"

output_json=false
target_theme=""

previous_theme=""
previous_link_raw=""
previous_file_snapshot=""
snapshot_dir=""

swaync_was_running=false

sddm_prepared=false
sddm_synchronized=false

warnings=()
failure_message=""

usage() {
    cat <<'USAGE'
Usage:
  theme-transaction-manager.sh apply THEME [--json]
USAGE
}

json_array_from_lines() {
    if (( $# == 0 )); then
        printf '[]\n'
        return 0
    fi

    printf '%s\n' "$@" | jq -R . | jq -s .
}

emit_invalid_request() {
    local message="$1"

    if [[ "$output_json" == true ]]; then
        jq -n \
            --arg status "invalid-request" \
            --arg message "$message" \
            '{
                status: $status,
                committed: false,
                changed: false,
                rolledBack: false,
                identityRestored: false,
                runtimeVerified: false,
                runtimeRollbackVerified: false,
                exitCode: 2,
                message: $message,
                warnings: []
            }'
    else
        printf 'ERROR: %s\n' "$message" >&2
    fi

    exit 2
}

emit_result() {
    local status="$1"
    local exit_code="$2"
    local committed="$3"
    local changed="$4"
    local rolled_back="$5"
    local identity_restored="$6"
    local runtime_verified="$7"
    local runtime_rollback_verified="$8"
    local message="$9"
    local hyprland_verified="${10}"
    local wallpaper_verified="${11}"
    local waybar_verified="${12}"
    local swaync_required="${13}"
    local swaync_verified="${14}"
    local sddm_prepared="${15}"
    local sddm_synchronized="${16}"

    if [[ "$output_json" == true ]]; then
        local warning_json
        warning_json="$(json_array_from_lines "${warnings[@]}")"

        jq -n \
            --arg status "$status" \
            --arg previousTheme "$previous_theme" \
            --arg targetTheme "$target_theme" \
            --arg message "$message" \
            --argjson exitCode "$exit_code" \
            --argjson committed "$committed" \
            --argjson changed "$changed" \
            --argjson rolledBack "$rolled_back" \
            --argjson identityRestored "$identity_restored" \
            --argjson runtimeVerified "$runtime_verified" \
            --argjson runtimeRollbackVerified "$runtime_rollback_verified" \
            --argjson hyprlandVerified "$hyprland_verified" \
            --argjson wallpaperVerified "$wallpaper_verified" \
            --argjson waybarVerified "$waybar_verified" \
            --argjson swayncRequired "$swaync_required" \
            --argjson swayncVerified "$swaync_verified" \
            --argjson sddmPrepared "$sddm_prepared" \
            --argjson sddmSynchronized "$sddm_synchronized" \
            --argjson warnings "$warning_json" \
            '{
                status: $status,
                committed: $committed,
                changed: $changed,
                rolledBack: $rolledBack,
                identityRestored: $identityRestored,
                runtimeVerified: $runtimeVerified,
                runtimeRollbackVerified: $runtimeRollbackVerified,
                exitCode: $exitCode,
                previousTheme: (
                    if $previousTheme == "" then null else $previousTheme end
                ),
                targetTheme: (
                    if $targetTheme == "" then null else $targetTheme end
                ),
                consumers: {
                    hyprland: {
                        required: true,
                        verified: $hyprlandVerified
                    },
                    wallpaper: {
                        required: true,
                        verified: $wallpaperVerified
                    },
                    waybar: {
                        required: true,
                        verified: $waybarVerified
                    },
                    swaync: {
                        required: $swayncRequired,
                        verified: $swayncVerified
                    },
                    sddm: {
                        required: false,
                        prepared: $sddmPrepared,
                        synchronized: $sddmSynchronized
                    }
                },
                warnings: $warnings,
                message: $message
            }'
    else
        if [[ "$status" == "applied" ]]; then
            printf 'Active theme: %s\n' "$target_theme"

            if (( ${#warnings[@]} > 0 )); then
                printf '\nWarnings:\n' >&2

                local warning
                for warning in "${warnings[@]}"; do
                    printf '  - %s\n' "$warning" >&2
                done
            fi
        else
            printf 'ERROR: %s\n' "$message" >&2
        fi
    fi

    exit "$exit_code"
}

theme_complete() {
    local theme_dir="$1"
    local theme_id="$2"
    local required

    for required in \
        theme.env \
        colors.conf \
        colors.css \
        colors.lua \
        quickshell.json \
        foot-colors.ini \
        hyprlock.env \
        sddm.env \
        wallpapers/main.webp \
        wallpapers/secondary.webp
    do
        [[ -r "$theme_dir/$required" ]] || return 1
    done

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
        "$theme_dir/quickshell.json" >/dev/null 2>&1
}

active_link_theme() {
    if [[ ! -L "$active_link" ]]; then
        return 0
    fi

    local resolved
    resolved="$(readlink -f -- "$active_link" 2>/dev/null || true)"

    [[ -n "$resolved" ]] && basename "$resolved"
}

active_file_theme() {
    [[ -r "$active_file" ]] || return 0
    tr -d '\r\n' < "$active_file"
}

verify_identity() {
    local expected="$1"
    local link_theme
    local file_theme

    link_theme="$(active_link_theme)"
    file_theme="$(active_file_theme)"

    [[ "$link_theme" == "$expected" ]] \
        && [[ "$file_theme" == "$expected" ]] \
        && [[ -d "$themes_dir/$expected" ]] \
        && theme_complete "$themes_dir/$expected" "$expected"
}

atomic_set_link() {
    local target="$1"
    local temp_link="$base/.theme-link.$$.$RANDOM"

    rm -f -- "$temp_link"
    ln -s -- "$target" "$temp_link"
    mv -Tf -- "$temp_link" "$active_link"
}

atomic_set_file_value() {
    local value="$1"
    local temp_file

    temp_file="$(mktemp "$local_dir/.active-theme.XXXXXX")"
    printf '%s\n' "$value" > "$temp_file"
    chmod 0644 "$temp_file"
    mv -f -- "$temp_file" "$active_file"
}

restore_file_snapshot() {
    local temp_file

    temp_file="$(mktemp "$local_dir/.active-theme.restore.XXXXXX")"
    cp -p -- "$previous_file_snapshot" "$temp_file"
    mv -f -- "$temp_file" "$active_file"
}

capture_snapshot() {
    previous_theme="$(active_link_theme)"

    local file_theme
    file_theme="$(active_file_theme)"

    [[ -n "$previous_theme" ]] \
        || emit_invalid_request "Active theme symlink is missing or invalid."

    [[ -n "$file_theme" ]] \
        || emit_invalid_request "Active theme file is missing or empty."

    [[ "$previous_theme" == "$file_theme" ]] \
        || emit_invalid_request \
            "Active theme file/link are not synchronized; repair observed state before Apply."

    theme_complete "$themes_dir/$previous_theme" "$previous_theme" \
        || emit_invalid_request \
            "Current active theme is incomplete or invalid: $previous_theme"

    previous_link_raw="$(readlink -- "$active_link")"

    snapshot_dir="$(mktemp -d "$local_dir/.theme-transaction.XXXXXX")"
    previous_file_snapshot="$snapshot_dir/active-theme"
    cp -p -- "$active_file" "$previous_file_snapshot"
}

cleanup() {
    if [[ -n "${snapshot_dir:-}" && -d "$snapshot_dir" ]]; then
        rm -rf -- "$snapshot_dir"
    fi
}

trap cleanup EXIT

acquire_theme_lock() {
    mkdir -p "$local_dir" "$preferences_dir"

    exec 9>"$theme_lock"
    flock -x 9
}

acquire_wallpaper_locks() {
    local first="$previous_theme"
    local second="$target_theme"

    exec 8>"$wallpaper_env_lock"
    flock -x 8

    if [[ "$second" < "$first" ]]; then
        first="$target_theme"
        second="$previous_theme"
    fi

    exec 7>"$preferences_dir/.${first}.mutation.lock"
    flock -x 7

    if [[ "$second" != "$first" ]]; then
        exec 6>"$preferences_dir/.${second}.mutation.lock"
        flock -x 6
    fi
}

apply_identity() {
    atomic_set_link "$themes_dir/$target_theme"
    atomic_set_file_value "$target_theme"
    verify_identity "$target_theme"
}

restore_identity() {
    atomic_set_link "$previous_link_raw"
    restore_file_snapshot
    verify_identity "$previous_theme"
}

apply_hyprland() {
    command -v hyprctl >/dev/null 2>&1 || return 1

    hyprctl reload >/dev/null 2>&1 || return 1

    local errors
    errors="$(hyprctl configerrors 2>/dev/null || true)"
    [[ -z "${errors//[[:space:]]/}" ]]
}

apply_wallpaper() {
    [[ -x "$wallpaper_apply" ]] || return 1
    "$wallpaper_apply" >/dev/null
}

apply_waybar() {
    [[ -x "$waybar_runtime" ]] || return 1
    "$waybar_runtime" >/dev/null
}

apply_swaync_if_required() {
    if [[ "$swaync_was_running" != true ]]; then
        return 0
    fi

    [[ -x "$swaync_runtime" ]] || return 1
    "$swaync_runtime" --restart >/dev/null
}

apply_critical_runtime() {
    apply_hyprland || {
        failure_message="Hyprland reload/config verification failed."
        return 1
    }

    apply_wallpaper || {
        failure_message="Wallpaper runtime application/verification failed."
        return 1
    }

    apply_waybar || {
        failure_message="Waybar refresh verification failed."
        return 1
    }

    apply_swaync_if_required || {
        failure_message="SwayNC refresh verification failed."
        return 1
    }

    verify_identity "$target_theme" || {
        failure_message="Active theme identity verification failed after runtime refresh."
        return 1
    }

    return 0
}

rollback_critical_runtime() {
    local ok=true

    restore_identity || ok=false
    apply_hyprland || ok=false
    apply_wallpaper || ok=false
    apply_waybar || ok=false
    apply_swaync_if_required || ok=false
    verify_identity "$previous_theme" || ok=false

    [[ "$ok" == true ]]
}

synchronize_sddm_auxiliary() {
    sddm_prepared=false
    sddm_synchronized=false

    if [[ -x "$sddm_prepare" ]]; then
        if "$sddm_prepare" >/dev/null 2>&1; then
            sddm_prepared=true
        else
            warnings+=("SDDM theme preparation failed; desktop theme remains committed.")
        fi
    else
        warnings+=("SDDM preparation helper is not installed/executable.")
    fi

    if [[ -x "$sddm_switch" ]]; then
        if sudo -n "$sddm_switch" "$target_theme" >/dev/null 2>&1; then
            sddm_synchronized=true
        else
            warnings+=(
                "SDDM profile synchronization is unavailable for '$target_theme'; desktop theme remains committed."
            )
        fi
    else
        warnings+=("SDDM system switch helper is not installed.")
    fi
}

apply_transaction() {
    local theme_name="${1:-}"
    shift || true

    target_theme="$theme_name"

    while (( $# > 0 )); do
        case "$1" in
            --json)
                output_json=true
                ;;
            *)
                emit_invalid_request "Unknown Apply option: $1"
                ;;
        esac
        shift
    done

    [[ -n "$target_theme" ]] \
        || emit_invalid_request "Missing theme name."

    [[ "$target_theme" =~ ^[A-Za-z0-9._-]+$ ]] \
        || emit_invalid_request "Invalid theme identifier: $target_theme"

    local target_dir="$themes_dir/$target_theme"

    [[ -d "$target_dir" ]] \
        || emit_invalid_request "Theme not found: $target_theme"

    theme_complete "$target_dir" "$target_theme" \
        || emit_invalid_request "Theme is incomplete or metadata is invalid: $target_theme"

    acquire_theme_lock
    capture_snapshot

    if [[ "$target_theme" == "$previous_theme" ]]; then
        emit_result \
            "applied" 0 true false false false true false \
            "Theme is already active." \
            true true true false true false false
    fi

    acquire_wallpaper_locks

    if pgrep -x swaync >/dev/null 2>&1; then
        swaync_was_running=true
    fi

    if ! apply_identity; then
        failure_message="Failed to atomically update active theme identity."
    elif ! apply_critical_runtime; then
        :
    else
        synchronize_sddm_auxiliary

        emit_result \
            "applied" 0 true true false false true false \
            "Theme transaction committed." \
            true true true "$swaync_was_running" true \
            "$sddm_prepared" "$sddm_synchronized"
    fi

    local identity_restored=false

    if restore_identity; then
        identity_restored=true
    fi

    if [[ "$identity_restored" == true ]] \
        && rollback_critical_runtime
    then
        emit_result \
            "rolled-back" 6 false true true true false true \
            "$failure_message Previous theme was restored and verified." \
            false false false "$swaync_was_running" false false false
    fi

    emit_result \
        "rollback-failed" 7 false true false "$identity_restored" false false \
        "$failure_message Rollback could not be fully verified." \
        false false false "$swaync_was_running" false false false
}

command_name="${1:-}"

case "$command_name" in
    apply)
        shift
        apply_transaction "$@"
        ;;

    --help|-h|"")
        usage
        ;;

    *)
        printf 'ERROR: unknown command: %s\n' "$command_name" >&2
        usage >&2
        exit 2
        ;;
esac
