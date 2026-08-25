#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Display runtime controller
#
# Phase 1B.3:
# - resolves live connector names to persistent desc:<description> rules
# - preserves the machine-local rule and changes only monitor mode
# - supports Safe Apply with an external systemd user rollback watchdog
# - stores ephemeral transaction state under XDG_RUNTIME_DIR
# - never writes local/monitors.conf
# ==============================================================================

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
base="$config_home/jc-hyprland-dotfiles"
monitors_conf="${JC_MONITORS_CONF:-$base/local/monitors.conf}"

runtime_root_default="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state_root="${JC_DISPLAY_STATE_DIR:-$runtime_root_default/jc-hyprland-dotfiles/display-safe}"
pending_dir="$state_root/pending"

self_path="$(readlink -f "${BASH_SOURCE[0]}")"

command_name="${1:-}"
shift || true

output=""
mode=""
token=""
timeout_seconds=15

description=""
description_selector=""


usage() {
    cat <<'EOF'
Usage:
  jc-displayctl preflight  --output <output> --mode <WIDTHxHEIGHT@HZ>
  jc-displayctl apply      --output <output> --mode <WIDTHxHEIGHT@HZ>
  jc-displayctl safe-apply --output <output> --mode <WIDTHxHEIGHT@HZ> [--timeout <seconds>]
  jc-displayctl keep       --token <token>
  jc-displayctl rollback   --token <token>
  jc-displayctl status

`apply` is the low-level runtime primitive retained for diagnostics.
The Control Center uses `safe-apply`.

Safe Apply:
  1. snapshots the current runtime mode,
  2. schedules an external systemd user rollback watchdog,
  3. applies the requested runtime mode,
  4. waits for Keep or Rollback.

No command in Phase 1B.3 writes local/monitors.conf.
EOF
}


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}


json_quote() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"

    printf '"%s"' "$value"
}


lua_quote() {
    json_quote "$1"
}


lua_number() {
    local value="$1"

    [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]] \
        || die "expected numeric monitor value, got: $value"

    printf '%s' "$value"
}


lua_scale() {
    local value="$1"

    if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s' "$value"
    else
        lua_quote "$value"
    fi
}


ensure_state_root() {
    mkdir -p "$state_root"
    chmod 700 "$state_root"
}


parse_mode_args() {
    while (($# > 0)); do
        case "$1" in
            --output)
                (($# >= 2)) || die "--output requires a value"
                output="$2"
                shift 2
                ;;

            --mode)
                (($# >= 2)) || die "--mode requires a value"
                mode="$2"
                shift 2
                ;;

            --timeout)
                (($# >= 2)) || die "--timeout requires a value"
                timeout_seconds="$2"
                shift 2
                ;;

            --help|-h)
                usage
                exit 0
                ;;

            *)
                die "unknown option: $1"
                ;;
        esac
    done

    [[ -n "$output" ]] || die "missing --output"
    [[ -n "$mode" ]] || die "missing --mode"

    [[ "$output" =~ ^[A-Za-z0-9._:-]+$ ]] \
        || die "invalid output name: $output"

    [[ "$mode" =~ ^[0-9]+x[0-9]+@[0-9]+([.][0-9]+)?$ ]] \
        || die "invalid mode: $mode"

    [[ "$timeout_seconds" =~ ^[0-9]+$ ]] \
        || die "timeout must be an integer number of seconds"

    if ((timeout_seconds < 5 || timeout_seconds > 120)); then
        die "timeout must be between 5 and 120 seconds"
    fi
}


parse_token_args() {
    while (($# > 0)); do
        case "$1" in
            --token)
                (($# >= 2)) || die "--token requires a value"
                token="$2"
                shift 2
                ;;

            --help|-h)
                usage
                exit 0
                ;;

            *)
                die "unknown option: $1"
                ;;
        esac
    done

    [[ -n "$token" ]] || die "missing --token"

    [[ "$token" =~ ^[A-Za-z0-9._-]+$ ]] \
        || die "invalid transaction token"
}


resolve_monitor_identity() {
    command -v hyprctl >/dev/null 2>&1 \
        || die "hyprctl is not available"

    command -v jq >/dev/null 2>&1 \
        || die "jq is required to resolve monitor descriptions"

    local monitors_json
    local matches

    monitors_json="$(hyprctl -j monitors all 2>/dev/null)" \
        || die "unable to query Hyprland monitors"

    matches="$(
        jq -r \
            --arg output "$output" \
            '[.[] | select(.name == $output)] | length' \
            <<< "$monitors_json"
    )" || die "unable to parse Hyprland monitor state"

    [[ "$matches" =~ ^[0-9]+$ ]] \
        || die "invalid monitor match count returned by jq"

    if ((matches == 0)); then
        die "output $output is not present in Hyprland monitor state"
    fi

    if ((matches > 1)); then
        die "multiple Hyprland monitors reported output $output"
    fi

    description="$(
        jq -r \
            --arg output "$output" \
            '.[] | select(.name == $output) | .description // empty' \
            <<< "$monitors_json"
    )" || die "unable to read description for $output"

    description="$(trim "$description")"

    local output_suffix=" ($output)"

    if [[ "$description" == *"$output_suffix" ]]; then
        description="${description%"$output_suffix"}"
        description="$(trim "$description")"
    fi

    if [[ -n "$description" ]]; then
        description_selector="desc:$description"
    else
        description_selector=""
    fi
}


current_runtime_mode() {
    local monitors_json
    local current

    monitors_json="$(hyprctl -j monitors all 2>/dev/null)" \
        || die "unable to query current monitor mode"

    current="$(
        jq -r \
            --arg output "$output" \
            '.[] | select(.name == $output)
             | if (.width > 0 and .height > 0 and .refreshRate > 0)
               then "\(.width)x\(.height)@\(.refreshRate)"
               else empty
               end' \
            <<< "$monitors_json"
    )" || die "unable to parse current monitor mode"

    current="$(trim "$current")"

    [[ -n "$current" ]] \
        || die "unable to determine current runtime mode for $output"

    printf '%s' "$current"
}


selector_matches_monitor() {
    local configured_selector="$1"

    if [[ "$configured_selector" == "$output" ]]; then
        return 0
    fi

    if [[ -n "$description_selector" \
        && "$configured_selector" == "$description_selector" ]]; then
        return 0
    fi

    return 1
}


find_monitor_payload() {
    [[ -r "$monitors_conf" ]] \
        || die "monitor configuration is not readable: $monitors_conf"

    local line
    local stripped
    local payload
    local -a fields
    local configured_selector
    local matches=0
    local found=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        stripped="${line%%#*}"

        if [[ "$stripped" =~ ^[[:space:]]*monitor[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            payload="${BASH_REMATCH[1]}"

            IFS=',' read -r -a fields <<< "$payload"

            ((${#fields[@]} >= 1)) || continue

            configured_selector="$(trim "${fields[0]}")"

            if selector_matches_monitor "$configured_selector"; then
                ((matches += 1))
                found="$payload"
            fi
        fi
    done < "$monitors_conf"

    if ((matches == 0)); then
        if [[ -n "$description_selector" ]]; then
            die \
                "no monitor rule found for $output; tried selectors " \
                "'$output' and '$description_selector' in $monitors_conf"
        fi

        die "no monitor rule found for $output in $monitors_conf"
    fi

    if ((matches > 1)); then
        die \
            "multiple monitor rules match $output; refusing ambiguous apply"
    fi

    printf '%s' "$found"
}


append_extra_field() {
    local key="$1"
    local value="$2"

    case "$key" in
        bitdepth|vrr|transform|sdrbrightness|sdrsaturation|\
supports_wide_color|supports_hdr|sdr_min_luminance|sdr_max_luminance|\
min_luminance|max_luminance|max_avg_luminance)
            printf ', %s = %s' "$key" "$(lua_number "$value")"
            ;;

        cm|sdr_eotf|mirror|icc)
            printf ', %s = %s' "$key" "$(lua_quote "$value")"
            ;;

        *)
            die \
                "unsupported monitor option '$key' in $monitors_conf; " \
                "refusing to drop or reinterpret it"
            ;;
    esac
}


build_lua_rule() {
    local payload="$1"
    local requested_mode="$2"
    local -a fields

    IFS=',' read -r -a fields <<< "$payload"

    ((${#fields[@]} >= 4)) \
        || die "invalid monitor rule for $output: expected at least 4 fields"

    local configured_selector
    local configured_mode
    local position
    local scale

    configured_selector="$(trim "${fields[0]}")"
    configured_mode="$(trim "${fields[1]}")"
    position="$(trim "${fields[2]}")"
    scale="$(trim "${fields[3]}")"

    selector_matches_monitor "$configured_selector" \
        || die "monitor rule selector no longer matches $output"

    [[ "$configured_mode" != "disable" ]] \
        || die "monitor $output is persistently disabled"

    [[ -n "$position" ]] || die "monitor rule has no position for $output"
    [[ -n "$scale" ]] || die "monitor rule has no scale for $output"

    local lua
    lua="hl.monitor({"
    lua+=" output = $(lua_quote "$configured_selector")"
    lua+=", mode = $(lua_quote "$requested_mode")"
    lua+=", position = $(lua_quote "$position")"
    lua+=", scale = $(lua_scale "$scale")"

    local remaining=$(( ${#fields[@]} - 4 ))

    if ((remaining % 2 != 0)); then
        die \
            "monitor rule contains unsupported non-paired extra fields for " \
            "$output"
    fi

    local index=4
    local key
    local value

    while ((index < ${#fields[@]})); do
        key="$(trim "${fields[index]}")"
        value="$(trim "${fields[index + 1]}")"

        [[ -n "$key" ]] || die "empty monitor option key for $output"
        [[ -n "$value" ]] || die "empty value for monitor option $key"

        lua+="$(append_extra_field "$key" "$value")"

        ((index += 2))
    done

    lua+=" })"

    printf '%s' "$lua"
}


run_eval_rule() {
    local lua_rule="$1"
    local result=""

    if ! result="$(hyprctl -r eval "$lua_rule" 2>&1)"; then
        printf 'ERROR: %s\n' "${result:-hyprctl eval failed}" >&2
        return 1
    fi

    result="$(trim "$result")"

    if [[ "$result" != "ok" ]]; then
        printf 'ERROR: hyprctl returned: %s\n' \
            "${result:-<empty>}" >&2
        return 1
    fi

    return 0
}


pending_token() {
    [[ -r "$pending_dir/token" ]] || return 1
    cat "$pending_dir/token"
}


pending_matches_token() {
    local expected="$1"
    local existing

    existing="$(pending_token 2>/dev/null || true)"

    [[ -n "$existing" && "$existing" == "$expected" ]]
}


unit_name_for_token() {
    printf 'jc-display-safe-%s' "$1"
}


cancel_watchdog_for_dir() {
    local directory="$1"
    local unit_name=""

    if [[ -r "$directory/unit" ]]; then
        unit_name="$(cat "$directory/unit")"
    fi

    [[ -n "$unit_name" ]] || return 0

    systemctl --user stop "${unit_name}.timer" >/dev/null 2>&1 || true
}


claim_pending_transaction() {
    local expected_token="$1"
    local claim_kind="$2"
    local existing

    [[ -d "$pending_dir" ]] || return 1

    existing="$(pending_token 2>/dev/null || true)"

    if [[ -z "$existing" || "$existing" != "$expected_token" ]]; then
        return 2
    fi

    local claim_dir="$state_root/${claim_kind}-${expected_token}-$$"

    if mv "$pending_dir" "$claim_dir" 2>/dev/null; then
        printf '%s' "$claim_dir"
        return 0
    fi

    return 3
}


restore_claim_after_failure() {
    local claim_dir="$1"

    if [[ -d "$claim_dir" && ! -e "$pending_dir" ]]; then
        mv "$claim_dir" "$pending_dir" 2>/dev/null || true
    fi
}


run_preflight() {
    local payload
    local lua_rule

    resolve_monitor_identity
    payload="$(find_monitor_payload)"
    lua_rule="$(build_lua_rule "$payload" "$mode")"

    printf '%s\n' "$lua_rule"
}


run_apply() {
    local payload
    local lua_rule

    resolve_monitor_identity
    payload="$(find_monitor_payload)"
    lua_rule="$(build_lua_rule "$payload" "$mode")"

    run_eval_rule "$lua_rule" || exit 1

    printf 'ok\n'
}


run_safe_apply() {
    command -v systemd-run >/dev/null 2>&1 \
        || die "systemd-run is required for Safe Apply"

    command -v systemctl >/dev/null 2>&1 \
        || die "systemctl is required for Safe Apply"

    ensure_state_root

    if [[ -d "$pending_dir" ]]; then
        local existing
        existing="$(pending_token 2>/dev/null || true)"

        die \
            "a display Safe Apply transaction is already pending" \
            "${existing:+ (token $existing)}"
    fi

    resolve_monitor_identity

    local payload
    local old_mode
    local target_rule
    local rollback_rule
    local now
    local deadline
    local unit_name

    payload="$(find_monitor_payload)"
    old_mode="$(current_runtime_mode)"

    if [[ "$old_mode" == "$mode" ]]; then
        die "requested mode already matches current runtime mode: $mode"
    fi

    target_rule="$(build_lua_rule "$payload" "$mode")"
    rollback_rule="$(build_lua_rule "$payload" "$old_mode")"

    token="$(date +%s)-$$-$RANDOM"
    now="$(date +%s)"
    deadline=$((now + timeout_seconds))
    unit_name="$(unit_name_for_token "$token")"

    if ! mkdir "$pending_dir" 2>/dev/null; then
        die "unable to create Safe Apply transaction"
    fi

    chmod 700 "$pending_dir"

    printf '%s\n' "$token" > "$pending_dir/token"
    printf '%s\n' "$output" > "$pending_dir/output"
    printf '%s\n' "$old_mode" > "$pending_dir/rollback-mode"
    printf '%s\n' "$mode" > "$pending_dir/target-mode"
    printf '%s\n' "$deadline" > "$pending_dir/deadline"
    printf '%s\n' "$unit_name" > "$pending_dir/unit"
    printf '%s\n' "$rollback_rule" > "$pending_dir/rollback.lua"

    # Schedule the external watchdog before changing the display. If scheduling
    # fails, no monitor mutation is allowed to happen.
    if ! systemd-run \
        --user \
        --quiet \
        --collect \
        --unit="$unit_name" \
        --on-active="${timeout_seconds}s" \
        "$self_path" rollback --token "$token"
    then
        rm -rf "$pending_dir"
        die "unable to schedule Safe Apply rollback watchdog"
    fi

    if ! run_eval_rule "$target_rule"; then
        cancel_watchdog_for_dir "$pending_dir"
        rm -rf "$pending_dir"
        exit 1
    fi

    printf '{"status":"pending","token":%s,"output":%s,"timeout":%d,"deadline":%d}\n' \
        "$(json_quote "$token")" \
        "$(json_quote "$output")" \
        "$timeout_seconds" \
        "$deadline"
}


run_keep() {
    ensure_state_root

    local claim_dir=""
    local claim_status=0

    claim_dir="$(claim_pending_transaction "$token" "keep")" \
        || claim_status=$?

    case "$claim_status" in
        0)
            ;;
        1)
            printf '{"status":"idle"}\n'
            return 0
            ;;
        2)
            die "transaction token does not match the pending Safe Apply"
            ;;
        *)
            printf '{"status":"busy"}\n'
            return 0
            ;;
    esac

    cancel_watchdog_for_dir "$claim_dir"
    rm -rf "$claim_dir"

    printf '{"status":"kept","token":%s}\n' "$(json_quote "$token")"
}


run_rollback() {
    ensure_state_root

    local claim_dir=""
    local claim_status=0

    claim_dir="$(claim_pending_transaction "$token" "rollback")" \
        || claim_status=$?

    case "$claim_status" in
        0)
            ;;
        1)
            printf '{"status":"idle"}\n'
            return 0
            ;;
        2)
            die "transaction token does not match the pending Safe Apply"
            ;;
        *)
            printf '{"status":"busy"}\n'
            return 0
            ;;
    esac

    local rollback_rule=""

    if [[ -r "$claim_dir/rollback.lua" ]]; then
        rollback_rule="$(cat "$claim_dir/rollback.lua")"
    fi

    if [[ -z "$rollback_rule" ]]; then
        restore_claim_after_failure "$claim_dir"
        die "pending transaction has no rollback rule"
    fi

    if ! run_eval_rule "$rollback_rule"; then
        restore_claim_after_failure "$claim_dir"
        exit 1
    fi

    cancel_watchdog_for_dir "$claim_dir"
    rm -rf "$claim_dir"

    printf '{"status":"rolled-back","token":%s}\n' "$(json_quote "$token")"
}


run_status() {
    ensure_state_root

    if [[ ! -d "$pending_dir" ]]; then
        printf '{"status":"idle"}\n'
        return 0
    fi

    local existing_token=""
    local existing_output=""
    local deadline=0
    local now
    local remaining=0

    [[ -r "$pending_dir/token" ]] \
        && existing_token="$(cat "$pending_dir/token")"

    [[ -r "$pending_dir/output" ]] \
        && existing_output="$(cat "$pending_dir/output")"

    if [[ -r "$pending_dir/deadline" ]]; then
        deadline="$(cat "$pending_dir/deadline")"
    fi

    [[ "$deadline" =~ ^[0-9]+$ ]] || deadline=0

    now="$(date +%s)"

    if ((deadline > now)); then
        remaining=$((deadline - now))
    fi

    printf '{"status":"pending","token":%s,"output":%s,"deadline":%d,"remaining":%d}\n' \
        "$(json_quote "$existing_token")" \
        "$(json_quote "$existing_output")" \
        "$deadline" \
        "$remaining"
}


case "$command_name" in
    preflight)
        parse_mode_args "$@"
        run_preflight
        ;;

    apply)
        parse_mode_args "$@"
        run_apply
        ;;

    safe-apply)
        parse_mode_args "$@"
        run_safe_apply
        ;;

    keep)
        parse_token_args "$@"
        run_keep
        ;;

    rollback)
        parse_token_args "$@"
        run_rollback
        ;;

    status)
        (($# == 0)) || die "status does not accept arguments"
        run_status
        ;;

    --help|-h|"")
        usage
        ;;

    *)
        die "unknown command: $command_name"
        ;;
esac
