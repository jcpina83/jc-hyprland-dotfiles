#!/usr/bin/env bash
set -euo pipefail

schema_version=1
json_output=false

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"

usage() {
    cat <<'USAGE'
Usage:
  jc-quick-settings status [--json]
  jc-quick-settings dnd status [--json]
  jc-quick-settings dnd on [--json]
  jc-quick-settings dnd off [--json]
  jc-quick-settings --help

Stable Phase 2D.1a contract:
  status       Observed Quick Settings capability state.
  dnd status   Read SwayNC Do Not Disturb state.
  dnd on       Enable Do Not Disturb and verify observed state.
  dnd off      Disable Do Not Disturb and verify observed state.

Exit codes:
  0  success
  2  invalid usage
  3  requested capability unavailable
  4  backend mutation failed
  5  post-mutation verification failed
USAGE
}

die_usage() {
    printf 'ERROR: %s\n\n' "$*" >&2
    usage >&2
    exit 2
}

bool_json() {
    case "$1" in
        true|false)
            printf '%s' "$1"
            ;;
        *)
            printf 'null'
            ;;
    esac
}

command_available() {
    command -v "$1" >/dev/null 2>&1
}

process_running() {
    pgrep -x "$1" >/dev/null 2>&1
}

resolve_runtime_wrapper() {
    local installed_name="$1"
    local source_name="$2"

    if [[ -x "$base/bin/$installed_name" ]]; then
        printf '%s\n' "$base/bin/$installed_name"
        return 0
    fi

    if [[ -n "$repo" && -x "$repo/scripts/runtime/$source_name" ]]; then
        printf '%s\n' "$repo/scripts/runtime/$source_name"
        return 0
    fi

    return 1
}

read_dnd_state() {
    if ! command_available swaync-client; then
        return 3
    fi

    if ! process_running swaync; then
        return 3
    fi

    local value
    value="$(swaync-client -D 2>/dev/null || true)"

    case "$value" in
        true|false)
            printf '%s\n' "$value"
            ;;
        *)
            return 4
            ;;
    esac
}

status_json() {
    local dnd_binary=false
    local dnd_running=false
    local dnd_available=false
    local dnd_state=""

    local lock_wrapper=""
    local lock_available=false

    local suspend_wrapper=""
    local suspend_available=false

    local night_light_available=false
    local night_light_running=false

    if command_available swaync-client; then
        dnd_binary=true
    fi

    if process_running swaync; then
        dnd_running=true
    fi

    if dnd_state="$(read_dnd_state 2>/dev/null)"; then
        dnd_available=true
    fi

    lock_wrapper="$(resolve_runtime_wrapper \
        "lock-session.sh" \
        "lock-session.sh" 2>/dev/null || true)"

    if [[ -n "$lock_wrapper" ]] && command_available hyprlock; then
        lock_available=true
    fi

    suspend_wrapper="$(resolve_runtime_wrapper \
        "suspend-session.sh" \
        "suspend-session.sh" 2>/dev/null || true)"

    if [[ -n "$suspend_wrapper" ]] && command_available systemctl; then
        suspend_available=true
    fi

    if command_available hyprsunset; then
        night_light_available=true
    fi

    if process_running hyprsunset; then
        night_light_running=true
    fi

    jq -n \
        --argjson schemaVersion "$schema_version" \
        --argjson dndBinary "$dnd_binary" \
        --argjson dndRunning "$dnd_running" \
        --argjson dndAvailable "$dnd_available" \
        --argjson dndEnabled "$(bool_json "$dnd_state")" \
        --argjson lockAvailable "$lock_available" \
        --arg lockBackend "lock-session.sh" \
        --argjson suspendAvailable "$suspend_available" \
        --arg suspendBackend "suspend-session.sh" \
        --argjson nightLightAvailable "$night_light_available" \
        --argjson nightLightRunning "$night_light_running" \
        '{
            schemaVersion: $schemaVersion,
            status: "ok",
            capabilities: {
                dnd: {
                    available: $dndAvailable,
                    backendInstalled: $dndBinary,
                    running: $dndRunning,
                    enabled: $dndEnabled,
                    backend: "swaync-client"
                },
                lock: {
                    available: $lockAvailable,
                    backend: $lockBackend
                },
                nightLight: {
                    available: $nightLightAvailable,
                    running: $nightLightRunning,
                    managed: false,
                    enabled: null,
                    backend: "hyprsunset"
                },
                suspend: {
                    available: $suspendAvailable,
                    backend: $suspendBackend
                }
            }
        }'
}

status_human() {
    local payload
    payload="$(status_json)"

    printf 'Quick Settings\n'
    printf '  DND:         %s\n' \
        "$(jq -r '
            if .capabilities.dnd.available
            then (if .capabilities.dnd.enabled then "on" else "off" end)
            else "unavailable"
            end
        ' <<< "$payload")"
    printf '  Lock:        %s\n' \
        "$(jq -r '
            if .capabilities.lock.available
            then "available"
            else "unavailable"
            end
        ' <<< "$payload")"
    printf '  Night Light: %s\n' \
        "$(jq -r '
            if .capabilities.nightLight.available
            then "detected (unmanaged in Phase 2D.1a)"
            else "unavailable"
            end
        ' <<< "$payload")"
    printf '  Suspend:     %s\n' \
        "$(jq -r '
            if .capabilities.suspend.available
            then "available"
            else "unavailable"
            end
        ' <<< "$payload")"
}

dnd_status_json() {
    local state

    if ! state="$(read_dnd_state)"; then
        jq -n \
            --argjson schemaVersion "$schema_version" \
            '{
                schemaVersion: $schemaVersion,
                status: "unavailable",
                capability: "dnd",
                available: false,
                enabled: null,
                backend: "swaync-client"
            }'
        exit 3
    fi

    jq -n \
        --argjson schemaVersion "$schema_version" \
        --argjson enabled "$state" \
        '{
            schemaVersion: $schemaVersion,
            status: "ok",
            capability: "dnd",
            available: true,
            enabled: $enabled,
            backend: "swaync-client"
        }'
}

dnd_status_human() {
    local state

    if ! state="$(read_dnd_state)"; then
        printf 'DND: unavailable\n'
        exit 3
    fi

    if [[ "$state" == "true" ]]; then
        printf 'DND: on\n'
    else
        printf 'DND: off\n'
    fi
}

apply_dnd() {
    local desired="$1"
    local before=""
    local after=""
    local changed=false

    if ! before="$(read_dnd_state)"; then
        if [[ "$json_output" == true ]]; then
            jq -n \
                --argjson schemaVersion "$schema_version" \
                --argjson requested "$desired" \
                '{
                    schemaVersion: $schemaVersion,
                    status: "unavailable",
                    capability: "dnd",
                    requested: $requested,
                    enabled: null,
                    verified: false,
                    changed: false,
                    backend: "swaync-client"
                }'
        else
            printf 'ERROR: DND capability is unavailable\n' >&2
        fi
        exit 3
    fi

    if [[ "$before" != "$desired" ]]; then
        if [[ "$desired" == "true" ]]; then
            swaync-client -dn >/dev/null 2>&1 || {
                if [[ "$json_output" == true ]]; then
                    jq -n \
                        --argjson schemaVersion "$schema_version" \
                        --argjson requested "$desired" \
                        '{
                            schemaVersion: $schemaVersion,
                            status: "failed",
                            capability: "dnd",
                            requested: $requested,
                            enabled: null,
                            verified: false,
                            changed: false,
                            backend: "swaync-client",
                            message: "SwayNC rejected the DND mutation."
                        }'
                else
                    printf 'ERROR: SwayNC rejected the DND mutation\n' >&2
                fi
                exit 4
            }
        else
            swaync-client -df >/dev/null 2>&1 || {
                if [[ "$json_output" == true ]]; then
                    jq -n \
                        --argjson schemaVersion "$schema_version" \
                        --argjson requested "$desired" \
                        '{
                            schemaVersion: $schemaVersion,
                            status: "failed",
                            capability: "dnd",
                            requested: $requested,
                            enabled: null,
                            verified: false,
                            changed: false,
                            backend: "swaync-client",
                            message: "SwayNC rejected the DND mutation."
                        }'
                else
                    printf 'ERROR: SwayNC rejected the DND mutation\n' >&2
                fi
                exit 4
            }
        fi

        changed=true
    fi

    for _ in 1 2 3 4 5 6 7 8 9 10; do
        after="$(read_dnd_state 2>/dev/null || true)"

        if [[ "$after" == "$desired" ]]; then
            break
        fi

        sleep 0.05
    done

    if [[ "$after" != "$desired" ]]; then
        if [[ "$json_output" == true ]]; then
            jq -n \
                --argjson schemaVersion "$schema_version" \
                --argjson requested "$desired" \
                --argjson enabled "$(bool_json "$after")" \
                --argjson changed "$changed" \
                '{
                    schemaVersion: $schemaVersion,
                    status: "verification-failed",
                    capability: "dnd",
                    requested: $requested,
                    enabled: $enabled,
                    verified: false,
                    changed: $changed,
                    backend: "swaync-client",
                    message: "DND mutation could not be verified."
                }'
        else
            printf 'ERROR: DND mutation could not be verified\n' >&2
        fi

        exit 5
    fi

    if [[ "$json_output" == true ]]; then
        jq -n \
            --argjson schemaVersion "$schema_version" \
            --argjson requested "$desired" \
            --argjson enabled "$after" \
            --argjson changed "$changed" \
            '{
                schemaVersion: $schemaVersion,
                status: "applied",
                capability: "dnd",
                requested: $requested,
                enabled: $enabled,
                verified: true,
                changed: $changed,
                backend: "swaync-client"
            }'
    else
        if [[ "$after" == "true" ]]; then
            printf 'DND: on\n'
        else
            printf 'DND: off\n'
        fi
    fi
}

args=()

for arg in "$@"; do
    if [[ "$arg" == "--json" ]]; then
        json_output=true
    else
        args+=("$arg")
    fi
done

set -- "${args[@]}"

case "${1:-}" in
    --help|-h|help)
        usage
        ;;

    status)
        [[ $# -eq 1 ]] || die_usage "status accepts no extra arguments"

        if [[ "$json_output" == true ]]; then
            status_json
        else
            status_human
        fi
        ;;

    dnd)
        [[ $# -eq 2 ]] || die_usage "dnd requires status, on or off"

        case "$2" in
            status)
                if [[ "$json_output" == true ]]; then
                    dnd_status_json
                else
                    dnd_status_human
                fi
                ;;
            on)
                apply_dnd true
                ;;
            off)
                apply_dnd false
                ;;
            *)
                die_usage "unknown dnd action: $2"
                ;;
        esac
        ;;

    "")
        die_usage "a command is required"
        ;;

    *)
        die_usage "unknown command: $1"
        ;;
esac
