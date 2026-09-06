#!/usr/bin/env bash
set -euo pipefail

schema_version=1
json_output=false

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"

night_light_service="hyprsunset.service"
night_light_temperature=4500

usage() {
    cat <<'USAGE'
Usage:
  jc-quick-settings status [--json]
  jc-quick-settings dnd status [--json]
  jc-quick-settings dnd on [--json]
  jc-quick-settings dnd off [--json]
  jc-quick-settings night-light status [--json]
  jc-quick-settings night-light on [--json]
  jc-quick-settings night-light off [--json]
  jc-quick-settings lock [--json]
  jc-quick-settings --help

Stable Quick Settings contract:
  status              Observed Quick Settings capability state.
  dnd status          Read SwayNC Do Not Disturb state.
  dnd on              Enable Do Not Disturb and verify observed state.
  dnd off             Disable Do Not Disturb and verify observed state.
  night-light status  Read managed hyprsunset state.
  night-light on      Start hyprsunset on demand, apply 4500 K and verify.
  night-light off     Restore the neutral identity matrix and verify.
  lock                Lock the session through the managed Hyprlock wrapper.

Night Light lifecycle:
  hyprsunset.service is started on demand and is never enabled by this CLI.
  A stopped service is observed as Night Light off.
  A running service is read through: hyprctl hyprsunset identity get.
  identity=false means Night Light on; identity=true means Night Light off.

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

night_light_runtime_available() {
    command_available hyprsunset \
        && command_available hyprctl \
        && command_available systemctl \
        && systemctl --user cat "$night_light_service" \
            --no-pager >/dev/null 2>&1
}

night_light_running() {
    systemctl --user is-active --quiet \
        "$night_light_service" 2>/dev/null
}

read_night_light_identity() {
    night_light_runtime_available || return 3
    night_light_running || return 4

    local value
    value="$(
        hyprctl hyprsunset identity get 2>/dev/null \
            | tr -d '\r' \
            | tail -n 1
    )"

    case "$value" in
        true|false)
            printf '%s\n' "$value"
            ;;
        *)
            return 4
            ;;
    esac
}

read_night_light_state() {
    night_light_runtime_available || return 3

    if ! night_light_running; then
        printf 'false\n'
        return 0
    fi

    local identity
    identity="$(read_night_light_identity)" || return 4

    if [[ "$identity" == "true" ]]; then
        printf 'false\n'
    else
        printf 'true\n'
    fi
}

wait_for_night_light_ipc() {
    local identity=""

    for _ in 1 2 3 4 5 6 7 8 9 10 \
             11 12 13 14 15 16 17 18 19 20 \
             21 22 23 24 25 26 27 28 29 30
    do
        identity="$(read_night_light_identity 2>/dev/null || true)"

        if [[ "$identity" == "true" || "$identity" == "false" ]]; then
            return 0
        fi

        sleep 0.10
    done

    return 1
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
    local night_light_running_state=false
    local night_light_managed=false
    local night_light_enabled=""

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

    if night_light_runtime_available; then
        night_light_available=true
        night_light_managed=true

        if night_light_running; then
            night_light_running_state=true
        fi

        night_light_enabled="$(
            read_night_light_state 2>/dev/null || true
        )"
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
        --argjson nightLightRunning "$night_light_running_state" \
        --argjson nightLightManaged "$night_light_managed" \
        --argjson nightLightEnabled "$(bool_json "$night_light_enabled")" \
        --argjson nightLightTemperature "$night_light_temperature" \
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
                    managed: $nightLightManaged,
                    enabled: $nightLightEnabled,
                    targetTemperature: $nightLightTemperature,
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
            if !.capabilities.nightLight.available
            then "unavailable"
            elif !.capabilities.nightLight.managed
            then "unmanaged"
            elif .capabilities.nightLight.enabled
            then "on"
            else "off"
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

night_light_status_json() {
    local state=""
    local running=false

    if ! night_light_runtime_available; then
        jq -n \
            --argjson schemaVersion "$schema_version" \
            --argjson targetTemperature "$night_light_temperature" \
            '{
                schemaVersion: $schemaVersion,
                status: "unavailable",
                capability: "night-light",
                available: false,
                running: false,
                managed: false,
                enabled: null,
                targetTemperature: $targetTemperature,
                backend: "hyprsunset"
            }'
        exit 3
    fi

    if night_light_running; then
        running=true
    fi

    if ! state="$(read_night_light_state)"; then
        jq -n \
            --argjson schemaVersion "$schema_version" \
            --argjson running "$running" \
            --argjson targetTemperature "$night_light_temperature" \
            '{
                schemaVersion: $schemaVersion,
                status: "failed",
                capability: "night-light",
                available: true,
                running: $running,
                managed: true,
                enabled: null,
                targetTemperature: $targetTemperature,
                backend: "hyprsunset"
            }'
        exit 4
    fi

    jq -n \
        --argjson schemaVersion "$schema_version" \
        --argjson running "$running" \
        --argjson enabled "$state" \
        --argjson targetTemperature "$night_light_temperature" \
        '{
            schemaVersion: $schemaVersion,
            status: "ok",
            capability: "night-light",
            available: true,
            running: $running,
            managed: true,
            enabled: $enabled,
            targetTemperature: $targetTemperature,
            backend: "hyprsunset"
        }'
}

night_light_status_human() {
    local state

    if ! night_light_runtime_available; then
        printf 'Night Light: unavailable\n'
        exit 3
    fi

    if ! state="$(read_night_light_state)"; then
        printf 'ERROR: unable to read Night Light state\n' >&2
        exit 4
    fi

    if [[ "$state" == "true" ]]; then
        printf 'Night Light: on\n'
    else
        printf 'Night Light: off\n'
    fi
}

night_light_failure_json() {
    local status="$1"
    local desired="$2"
    local enabled="$3"
    local changed="$4"
    local message="$5"
    local running=false

    if night_light_running; then
        running=true
    fi

    jq -n \
        --argjson schemaVersion "$schema_version" \
        --arg status "$status" \
        --argjson requested "$desired" \
        --argjson enabled "$(bool_json "$enabled")" \
        --argjson changed "$changed" \
        --argjson running "$running" \
        --argjson targetTemperature "$night_light_temperature" \
        --arg message "$message" \
        '{
            schemaVersion: $schemaVersion,
            status: $status,
            capability: "night-light",
            requested: $requested,
            enabled: $enabled,
            verified: false,
            changed: $changed,
            available: true,
            running: $running,
            managed: true,
            targetTemperature: $targetTemperature,
            backend: "hyprsunset",
            message: $message
        }'
}

apply_night_light() {
    local desired="$1"
    local before=""
    local after=""
    local changed=false
    local started_by_us=false

    if ! night_light_runtime_available; then
        if [[ "$json_output" == true ]]; then
            jq -n \
                --argjson schemaVersion "$schema_version" \
                --argjson requested "$desired" \
                --argjson targetTemperature "$night_light_temperature" \
                '{
                    schemaVersion: $schemaVersion,
                    status: "unavailable",
                    capability: "night-light",
                    requested: $requested,
                    enabled: null,
                    verified: false,
                    changed: false,
                    available: false,
                    running: false,
                    managed: false,
                    targetTemperature: $targetTemperature,
                    backend: "hyprsunset"
                }'
        else
            printf 'ERROR: Night Light capability is unavailable\n' >&2
        fi
        exit 3
    fi

    if ! before="$(read_night_light_state)"; then
        if [[ "$json_output" == true ]]; then
            night_light_failure_json \
                "failed" \
                "$desired" \
                "" \
                false \
                "Unable to read Night Light state before mutation."
        else
            printf 'ERROR: unable to read Night Light state\n' >&2
        fi
        exit 4
    fi

    if [[ "$before" != "$desired" ]]; then
        changed=true

        if [[ "$desired" == "true" ]]; then
            if ! night_light_running; then
                systemctl --user start "$night_light_service" \
                    >/dev/null 2>&1 || {
                        if [[ "$json_output" == true ]]; then
                            night_light_failure_json \
                                "failed" \
                                "$desired" \
                                "$before" \
                                "$changed" \
                                "Unable to start hyprsunset.service."
                        else
                            printf 'ERROR: unable to start Night Light backend\n' >&2
                        fi
                        exit 4
                    }

                started_by_us=true

                if ! wait_for_night_light_ipc; then
                    systemctl --user stop "$night_light_service" \
                        >/dev/null 2>&1 || true

                    if [[ "$json_output" == true ]]; then
                        night_light_failure_json \
                            "failed" \
                            "$desired" \
                            "$before" \
                            "$changed" \
                            "hyprsunset IPC did not become ready."
                    else
                        printf 'ERROR: Night Light IPC did not become ready\n' >&2
                    fi
                    exit 4
                fi
            fi

            if ! hyprctl hyprsunset temperature \
                    "$night_light_temperature" >/dev/null 2>&1 \
                    || ! hyprctl hyprsunset identity false \
                        >/dev/null 2>&1
            then
                hyprctl hyprsunset identity true \
                    >/dev/null 2>&1 || true

                if [[ "$started_by_us" == "true" ]]; then
                    systemctl --user stop "$night_light_service" \
                        >/dev/null 2>&1 || true
                fi

                if [[ "$json_output" == true ]]; then
                    night_light_failure_json \
                        "failed" \
                        "$desired" \
                        "$before" \
                        "$changed" \
                        "hyprsunset rejected the Night Light ON mutation."
                else
                    printf 'ERROR: Night Light ON mutation failed\n' >&2
                fi
                exit 4
            fi
        else
            if night_light_running; then
                hyprctl hyprsunset identity true \
                    >/dev/null 2>&1 || {
                        if [[ "$json_output" == true ]]; then
                            night_light_failure_json \
                                "failed" \
                                "$desired" \
                                "$before" \
                                "$changed" \
                                "hyprsunset rejected the neutral identity mutation."
                        else
                            printf 'ERROR: Night Light OFF mutation failed\n' >&2
                        fi
                        exit 4
                    }
            fi
        fi
    fi

    for _ in 1 2 3 4 5 6 7 8 9 10 \
             11 12 13 14 15 16 17 18 19 20
    do
        after="$(read_night_light_state 2>/dev/null || true)"

        if [[ "$after" == "$desired" ]]; then
            break
        fi

        sleep 0.05
    done

    if [[ "$after" != "$desired" ]]; then
        if [[ "$json_output" == true ]]; then
            night_light_failure_json \
                "verification-failed" \
                "$desired" \
                "$after" \
                "$changed" \
                "Night Light mutation could not be verified."
        else
            printf 'ERROR: Night Light mutation could not be verified\n' >&2
        fi
        exit 5
    fi

    local running=false
    if night_light_running; then
        running=true
    fi

    if [[ "$json_output" == true ]]; then
        jq -n \
            --argjson schemaVersion "$schema_version" \
            --argjson requested "$desired" \
            --argjson enabled "$after" \
            --argjson changed "$changed" \
            --argjson running "$running" \
            --argjson targetTemperature "$night_light_temperature" \
            '{
                schemaVersion: $schemaVersion,
                status: "applied",
                capability: "night-light",
                requested: $requested,
                enabled: $enabled,
                verified: true,
                changed: $changed,
                available: true,
                running: $running,
                managed: true,
                targetTemperature: $targetTemperature,
                backend: "hyprsunset"
            }'
    else
        if [[ "$after" == "true" ]]; then
            printf 'Night Light: on\n'
        else
            printf 'Night Light: off\n'
        fi
    fi
}


lock_runtime_wrapper() {
    resolve_runtime_wrapper \
        "lock-session.sh" \
        "lock-session.sh"
}

lock_runtime_available() {
    local wrapper=""

    wrapper="$(lock_runtime_wrapper 2>/dev/null || true)"

    [[ -n "$wrapper" && -x "$wrapper" ]] \
        && command_available hyprlock
}

lock_running() {
    process_running hyprlock
}

apply_lock() {
    local wrapper=""
    local changed=false
    local running=false

    wrapper="$(lock_runtime_wrapper 2>/dev/null || true)"

    if [[ -z "$wrapper" || ! -x "$wrapper" ]] \
            || ! command_available hyprlock
    then
        if [[ "$json_output" == true ]]; then
            jq -n \
                --argjson schemaVersion "$schema_version" \
                '{
                    schemaVersion: $schemaVersion,
                    status: "unavailable",
                    capability: "lock",
                    available: false,
                    running: false,
                    verified: false,
                    changed: false,
                    backend: "lock-session.sh"
                }'
        else
            printf 'ERROR: Lock capability is unavailable\n' >&2
        fi

        exit 3
    fi

    if lock_running; then
        running=true
    else
        changed=true

        nohup "$wrapper" >/dev/null 2>&1 </dev/null &

        for _ in 1 2 3 4 5 6 7 8 9 10 \
                 11 12 13 14 15 16 17 18 19 20 \
                 21 22 23 24 25 26 27 28 29 30 \
                 31 32 33 34 35 36 37 38 39 40
        do
            if lock_running; then
                running=true
                break
            fi

            sleep 0.05
        done
    fi

    if [[ "$running" != "true" ]]; then
        if [[ "$json_output" == true ]]; then
            jq -n \
                --argjson schemaVersion "$schema_version" \
                --argjson changed "$changed" \
                '{
                    schemaVersion: $schemaVersion,
                    status: "verification-failed",
                    capability: "lock",
                    available: true,
                    running: false,
                    verified: false,
                    changed: $changed,
                    backend: "lock-session.sh",
                    message: "Hyprlock did not become observable."
                }'
        else
            printf 'ERROR: session lock could not be verified\n' >&2
        fi

        exit 5
    fi

    if [[ "$json_output" == true ]]; then
        jq -n \
            --argjson schemaVersion "$schema_version" \
            --argjson changed "$changed" \
            '{
                schemaVersion: $schemaVersion,
                status: "applied",
                capability: "lock",
                available: true,
                running: true,
                verified: true,
                changed: $changed,
                backend: "lock-session.sh"
            }'
    else
        if [[ "$changed" == "true" ]]; then
            printf 'Lock: started\n'
        else
            printf 'Lock: already active\n'
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

    lock)
        [[ $# -eq 1 ]]             || die_usage "lock accepts no extra arguments"

        apply_lock
        ;;

    night-light)
        [[ $# -eq 2 ]] \
            || die_usage "night-light requires status, on or off"

        case "$2" in
            status)
                if [[ "$json_output" == true ]]; then
                    night_light_status_json
                else
                    night_light_status_human
                fi
                ;;
            on)
                apply_night_light true
                ;;
            off)
                apply_night_light false
                ;;
            *)
                die_usage "unknown night-light action: $2"
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
