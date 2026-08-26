#!/usr/bin/env bash
set -euo pipefail

umask 077

# ==============================================================================
# jc-hyprland-dotfiles
# Display runtime controller
#
# Phase 1B.6:
# - Safe Applies enabled/disabled + mode + scale + transform + position
# - never disables the focused monitor
# - never allows the last active monitor to be disabled
# - snapshots whether the monitor was active before mutation
# - rollback restores active state or returns to disabled=true
# - external systemd user rollback watchdog remains authoritative
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
requested_enabled=""
requested_scale=""
requested_transform=""
requested_position=""
token=""
timeout_seconds=15

description=""
description_selector=""


usage() {
    cat <<'EOF'
Usage:
  jc-displayctl preflight  --output <output> --mode <WIDTHxHEIGHT@HZ> \
      [--enabled <true|false>] [--scale <scale>] [--transform <0-7>] \
      [--position <XxY>]

  jc-displayctl apply      --output <output> --mode <WIDTHxHEIGHT@HZ> \
      [--enabled <true|false>] [--scale <scale>] [--transform <0-7>] \
      [--position <XxY>]

  jc-displayctl safe-apply --output <output> --mode <WIDTHxHEIGHT@HZ> \
      [--enabled <true|false>] [--scale <scale>] [--transform <0-7>] \
      [--position <XxY>] [--timeout <seconds>]

  jc-displayctl keep       --token <token>
  jc-displayctl rollback   --token <token>
  jc-displayctl status

When --enabled is omitted, the current runtime enabled state is preserved.

Disable uses:
  hl.monitor({ output = "...", disabled = true })

Enable uses the complete requested runtime geometry and preserves supported
persistent rule extras such as VRR.

Phase 1B.6 never writes local/monitors.conf.
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


parse_bool() {
    case "$1" in
        true|1|yes|on)
            printf 'true'
            ;;
        false|0|no|off)
            printf 'false'
            ;;
        *)
            die "expected boolean true/false, got: $1"
            ;;
    esac
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

            --enabled)
                (($# >= 2)) || die "--enabled requires a value"
                requested_enabled="$(parse_bool "$2")"
                shift 2
                ;;

            --scale)
                (($# >= 2)) || die "--scale requires a value"
                requested_scale="$2"
                shift 2
                ;;

            --transform)
                (($# >= 2)) || die "--transform requires a value"
                requested_transform="$2"
                shift 2
                ;;

            --position)
                (($# >= 2)) || die "--position requires a value"
                requested_position="$2"
                shift 2
                ;;

            --position=*)
                requested_position="${1#--position=}"
                shift
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

    if [[ -n "$requested_scale" ]]; then
        [[ "$requested_scale" =~ ^[0-9]+([.][0-9]+)?$ ]] \
            || die "invalid scale: $requested_scale"

        awk -v scale="$requested_scale" \
            'BEGIN { exit !(scale > 0) }' \
            || die "scale must be greater than zero"
    fi

    if [[ -n "$requested_transform" ]]; then
        [[ "$requested_transform" =~ ^[0-7]$ ]] \
            || die "transform must be an integer from 0 to 7"
    fi

    if [[ -n "$requested_position" ]]; then
        [[ "$requested_position" =~ ^-?[0-9]+x-?[0-9]+$ ]] \
            || die "invalid position: $requested_position"
    fi

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


monitors_json() {
    hyprctl -j monitors all 2>/dev/null \
        || die "unable to query Hyprland monitors"
}


resolve_monitor_identity() {
    command -v hyprctl >/dev/null 2>&1 \
        || die "hyprctl is not available"

    command -v jq >/dev/null 2>&1 \
        || die "jq is required to resolve monitor descriptions"

    local state
    local matches

    state="$(monitors_json)"

    matches="$(
        jq -r \
            --arg output "$output" \
            '[.[] | select(.name == $output)] | length' \
            <<< "$state"
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
            <<< "$state"
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


current_runtime_state() {
    local state
    local current

    state="$(monitors_json)"

    current="$(
        jq -c \
            --arg output "$output" \
            '.[] | select(.name == $output)
             | {
                 enabled: ((.disabled // false) | not),
                 mode:
                     (if ((.width // 0) > 0
                          and (.height // 0) > 0
                          and (.refreshRate // 0) > 0)
                      then "\(.width)x\(.height)@\(.refreshRate)"
                      else ""
                      end),
                 position: "\(.x // 0)x\(.y // 0)",
                 scale:
                     (if ((.scale // 1) > 0)
                      then (.scale // 1)
                      else 1
                      end),
                 transform: (.transform // 0),
                 focused: (.focused // false)
               }' \
            <<< "$state"
    )" || die "unable to parse current monitor state"

    [[ -n "$current" ]] \
        || die "unable to determine current runtime state for $output"

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
        die "multiple monitor rules match $output; refusing ambiguous apply"
    fi

    printf '%s' "$found"
}


append_extra_field() {
    local key="$1"
    local value="$2"

    case "$key" in
        bitdepth|vrr|sdrbrightness|sdrsaturation|\
supports_wide_color|supports_hdr|sdr_min_luminance|sdr_max_luminance|\
min_luminance|max_luminance|max_avg_luminance)
            printf ', %s = %s' "$key" "$(lua_number "$value")"
            ;;

        cm|sdr_eotf|mirror|icc)
            printf ', %s = %s' "$key" "$(lua_quote "$value")"
            ;;

        transform)
            # Transform is emitted from runtime/draft state.
            ;;

        *)
            die \
                "unsupported monitor option '$key' in $monitors_conf; " \
                "refusing to drop or reinterpret it"
            ;;
    esac
}


validate_scale_for_mode() {
    local requested_mode="$1"
    local scale="$2"

    local size="${requested_mode%%@*}"
    local width="${size%%x*}"
    local height="${size#*x}"

    awk \
        -v width="$width" \
        -v height="$height" \
        -v scale="$scale" \
        'function abs(v) { return v < 0 ? -v : v }
         BEGIN {
             if (scale <= 0)
                 exit 1

             lw = width / scale
             lh = height / scale

             rw = int(lw + 0.5)
             rh = int(lh + 0.5)

             if (abs(lw - rw) >= 0.0001 || abs(lh - rh) >= 0.0001)
                 exit 1

             exit 0
         }'
}


active_monitor_count() {
    monitors_json | jq \
        '[.[] | select((.disabled // false) == false)] | length'
}


validate_disable_guard() {
    local state
    local active_count
    local focused

    state="$(monitors_json)"

    active_count="$(
        jq -r \
            '[.[] | select((.disabled // false) == false)] | length' \
            <<< "$state"
    )" || die "unable to count active monitors"

    focused="$(
        jq -r \
            --arg output "$output" \
            '.[] | select(.name == $output) | (.focused // false)' \
            <<< "$state"
    )" || die "unable to read focused monitor state"

    if ((active_count <= 1)); then
        die "refusing to disable the last active monitor"
    fi

    if [[ "$focused" == "true" ]]; then
        die "refusing to disable focused output $output; focus another display first"
    fi
}


validate_projected_geometry() {
    local requested_mode="$1"
    local position="$2"
    local scale="$3"
    local transform="$4"

    local size="${requested_mode%%@*}"
    local width="${size%%x*}"
    local height="${size#*x}"

    local x="${position%%x*}"
    local y="${position#*x}"

    local logical_width
    local logical_height

    logical_width="$(
        awk -v width="$width" -v scale="$scale" \
            'BEGIN { printf "%.6f", width / scale }'
    )"

    logical_height="$(
        awk -v height="$height" -v scale="$scale" \
            'BEGIN { printf "%.6f", height / scale }'
    )"

    case "$transform" in
        1|3|5|7)
            local swap="$logical_width"
            logical_width="$logical_height"
            logical_height="$swap"
            ;;
    esac

    local state
    local overlaps

    state="$(monitors_json)"

    overlaps="$(
        jq -r \
            --arg output "$output" \
            --argjson tx "$x" \
            --argjson ty "$y" \
            --argjson tw "$logical_width" \
            --argjson th "$logical_height" \
            '
            def rotated:
                . == 1 or . == 3 or . == 5 or . == 7;

            [
                .[]
                | select(.name != $output)
                | select((.disabled // false) == false)
                | select((.width // 0) > 0 and (.height // 0) > 0)
                | . as $m
                | (($m.scale // 1)
                    | if . == 0 then 1 else . end) as $scale
                | (if (($m.transform // 0) | rotated)
                   then ($m.height / $scale)
                   else ($m.width / $scale)
                   end) as $ow
                | (if (($m.transform // 0) | rotated)
                   then ($m.width / $scale)
                   else ($m.height / $scale)
                   end) as $oh
                | select(
                    $tx < (($m.x // 0) + $ow)
                    and ($tx + $tw) > ($m.x // 0)
                    and $ty < (($m.y // 0) + $oh)
                    and ($ty + $th) > ($m.y // 0)
                  )
                | .name
            ]
            | join(", ")
            ' \
            <<< "$state"
    )" || die "unable to validate projected monitor geometry"

    if [[ -n "$overlaps" ]]; then
        die \
            "projected geometry for $output overlaps: $overlaps; " \
            "move the display before applying"
    fi
}


validate_target_state() {
    local enabled="$1"
    local requested_mode="$2"
    local position="$3"
    local scale="$4"
    local transform="$5"

    if [[ "$enabled" == "false" ]]; then
        validate_disable_guard
        return 0
    fi

    [[ -n "$requested_mode" ]] \
        || die "cannot enable $output without a reusable monitor mode"

    [[ "$position" =~ ^-?[0-9]+x-?[0-9]+$ ]] \
        || die "invalid target position: $position"

    [[ "$scale" =~ ^[0-9]+([.][0-9]+)?$ ]] \
        || die "invalid target scale: $scale"

    awk -v scale="$scale" \
        'BEGIN { exit !(scale > 0) }' \
        || die "target scale must be greater than zero"

    [[ "$transform" =~ ^[0-7]$ ]] \
        || die "target transform must be an integer from 0 to 7"

    validate_scale_for_mode "$requested_mode" "$scale" \
        || die \
            "scale $scale does not create whole logical pixels " \
            "for mode $requested_mode"

    validate_projected_geometry \
        "$requested_mode" \
        "$position" \
        "$scale" \
        "$transform"
}


build_lua_rule() {
    local payload="$1"
    local enabled="$2"
    local requested_mode="$3"
    local position="$4"
    local scale="$5"
    local transform="$6"

    local -a fields
    IFS=',' read -r -a fields <<< "$payload"

    ((${#fields[@]} >= 1)) \
        || die "invalid monitor rule for $output"

    local configured_selector
    configured_selector="$(trim "${fields[0]}")"

    selector_matches_monitor "$configured_selector" \
        || die "monitor rule selector no longer matches $output"

    if [[ "$enabled" == "false" ]]; then
        printf 'hl.monitor({ output = %s, disabled = true })' \
            "$(lua_quote "$configured_selector")"
        return 0
    fi

    local lua
    lua="hl.monitor({"
    lua+=" output = $(lua_quote "$configured_selector")"
    lua+=", disabled = false"
    lua+=", mode = $(lua_quote "$requested_mode")"
    lua+=", position = $(lua_quote "$position")"
    lua+=", scale = $(lua_number "$scale")"
    lua+=", transform = $(lua_number "$transform")"

    # Persistent active rule format:
    # selector, mode, position, scale, key, value, ...
    #
    # A persistent "selector, disable" rule has no reusable extras.
    if ((${#fields[@]} >= 4)); then
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
    elif ((${#fields[@]} == 2)); then
        local configured_mode
        configured_mode="$(trim "${fields[1]}")"

        [[ "$configured_mode" == "disable" ]] \
            || die "unsupported short monitor rule for $output"
    fi

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


require_hyprland_ipc_environment() {
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] \
        || die "HYPRLAND_INSTANCE_SIGNATURE is missing; refusing unsafe watchdog setup"

    [[ -n "${XDG_RUNTIME_DIR:-}" ]] \
        || die "XDG_RUNTIME_DIR is missing; refusing unsafe watchdog setup"
}


write_watchdog_environment() {
    local directory="$1"

    require_hyprland_ipc_environment

    printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE" \
        > "$directory/hyprland-instance-signature"

    printf '%s\n' "$XDG_RUNTIME_DIR" \
        > "$directory/xdg-runtime-dir"

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        printf '%s\n' "$WAYLAND_DISPLAY" \
            > "$directory/wayland-display"
    fi

    if [[ -n "${PATH:-}" ]]; then
        printf '%s\n' "$PATH" \
            > "$directory/path"
    fi
}


restore_watchdog_environment() {
    local directory="$1"

    if [[ -r "$directory/hyprland-instance-signature" ]]; then
        export HYPRLAND_INSTANCE_SIGNATURE
        HYPRLAND_INSTANCE_SIGNATURE="$(
            cat "$directory/hyprland-instance-signature"
        )"
    fi

    if [[ -r "$directory/xdg-runtime-dir" ]]; then
        export XDG_RUNTIME_DIR
        XDG_RUNTIME_DIR="$(cat "$directory/xdg-runtime-dir")"
    fi

    if [[ -r "$directory/wayland-display" ]]; then
        export WAYLAND_DISPLAY
        WAYLAND_DISPLAY="$(cat "$directory/wayland-display")"
    fi

    if [[ -r "$directory/path" ]]; then
        export PATH
        PATH="$(cat "$directory/path")"
    fi
}


watchdog_systemd_environment_args() {
    require_hyprland_ipc_environment

    printf '%s\0' \
        "--setenv=HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE" \
        "--setenv=XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"

    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        printf '%s\0' \
            "--setenv=WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    fi

    if [[ -n "${PATH:-}" ]]; then
        printf '%s\0' \
            "--setenv=PATH=$PATH"
    fi
}


pending_token() {
    [[ -r "$pending_dir/token" ]] || return 1
    cat "$pending_dir/token"
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


effective_target_state() {
    local current="$1"

    local enabled
    local position
    local scale
    local transform

    enabled="${requested_enabled:-$(jq -r '.enabled' <<< "$current")}"
    position="${requested_position:-$(jq -r '.position' <<< "$current")}"
    scale="${requested_scale:-$(jq -r '.scale' <<< "$current")}"
    transform="${requested_transform:-$(jq -r '.transform' <<< "$current")}"

    printf '{"enabled":%s,"position":%s,"scale":%s,"transform":%s}\n' \
        "$enabled" \
        "$(json_quote "$position")" \
        "$scale" \
        "$transform"
}


run_preflight() {
    local payload
    local current
    local target
    local enabled
    local position
    local scale
    local transform
    local lua_rule

    resolve_monitor_identity

    payload="$(find_monitor_payload)"
    current="$(current_runtime_state)"
    target="$(effective_target_state "$current")"

    enabled="$(jq -r '.enabled' <<< "$target")"
    position="$(jq -r '.position' <<< "$target")"
    scale="$(jq -r '.scale' <<< "$target")"
    transform="$(jq -r '.transform' <<< "$target")"

    validate_target_state \
        "$enabled" "$mode" "$position" "$scale" "$transform"

    lua_rule="$(
        build_lua_rule \
            "$payload" \
            "$enabled" \
            "$mode" \
            "$position" \
            "$scale" \
            "$transform"
    )"

    printf '%s\n' "$lua_rule"
}


run_apply() {
    local payload
    local current
    local target
    local enabled
    local position
    local scale
    local transform
    local lua_rule

    resolve_monitor_identity

    payload="$(find_monitor_payload)"
    current="$(current_runtime_state)"
    target="$(effective_target_state "$current")"

    enabled="$(jq -r '.enabled' <<< "$target")"
    position="$(jq -r '.position' <<< "$target")"
    scale="$(jq -r '.scale' <<< "$target")"
    transform="$(jq -r '.transform' <<< "$target")"

    validate_target_state \
        "$enabled" "$mode" "$position" "$scale" "$transform"

    lua_rule="$(
        build_lua_rule \
            "$payload" \
            "$enabled" \
            "$mode" \
            "$position" \
            "$scale" \
            "$transform"
    )"

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
    local current
    local target

    local old_enabled
    local old_mode
    local old_position
    local old_scale
    local old_transform

    local target_enabled
    local target_position
    local target_scale
    local target_transform

    local target_rule
    local rollback_rule
    local now
    local deadline
    local unit_name

    payload="$(find_monitor_payload)"
    current="$(current_runtime_state)"
    target="$(effective_target_state "$current")"

    old_enabled="$(jq -r '.enabled' <<< "$current")"
    old_mode="$(jq -r '.mode' <<< "$current")"
    old_position="$(jq -r '.position' <<< "$current")"
    old_scale="$(jq -r '.scale' <<< "$current")"
    old_transform="$(jq -r '.transform' <<< "$current")"

    target_enabled="$(jq -r '.enabled' <<< "$target")"
    target_position="$(jq -r '.position' <<< "$target")"
    target_scale="$(jq -r '.scale' <<< "$target")"
    target_transform="$(jq -r '.transform' <<< "$target")"

    validate_target_state \
        "$target_enabled" \
        "$mode" \
        "$target_position" \
        "$target_scale" \
        "$target_transform"

    if [[ "$old_enabled" == "$target_enabled" \
        && "$old_mode" == "$mode" \
        && "$old_position" == "$target_position" \
        && "$old_scale" == "$target_scale" \
        && "$old_transform" == "$target_transform" ]]
    then
        die "requested display state already matches current runtime state"
    fi

    target_rule="$(
        build_lua_rule \
            "$payload" \
            "$target_enabled" \
            "$mode" \
            "$target_position" \
            "$target_scale" \
            "$target_transform"
    )"

    rollback_rule="$(
        build_lua_rule \
            "$payload" \
            "$old_enabled" \
            "$old_mode" \
            "$old_position" \
            "$old_scale" \
            "$old_transform"
    )"

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

    printf '%s\n' "$old_enabled" > "$pending_dir/rollback-enabled"
    printf '%s\n' "$old_mode" > "$pending_dir/rollback-mode"
    printf '%s\n' "$old_position" > "$pending_dir/rollback-position"
    printf '%s\n' "$old_scale" > "$pending_dir/rollback-scale"
    printf '%s\n' "$old_transform" > "$pending_dir/rollback-transform"

    printf '%s\n' "$target_enabled" > "$pending_dir/target-enabled"
    printf '%s\n' "$mode" > "$pending_dir/target-mode"
    printf '%s\n' "$target_position" > "$pending_dir/target-position"
    printf '%s\n' "$target_scale" > "$pending_dir/target-scale"
    printf '%s\n' "$target_transform" > "$pending_dir/target-transform"

    printf '%s\n' "$deadline" > "$pending_dir/deadline"
    printf '%s\n' "$unit_name" > "$pending_dir/unit"
    printf '%s\n' "$rollback_rule" > "$pending_dir/rollback.lua"

    # Persist the Hyprland IPC context inside the ephemeral transaction.  The
    # rollback must remain able to reach Hyprland even when systemd starts the
    # watchdog service from a detached environment.
    write_watchdog_environment "$pending_dir"

    local -a watchdog_env_args=()

    while IFS= read -r -d '' argument; do
        watchdog_env_args+=("$argument")
    done < <(watchdog_systemd_environment_args)

    if ! systemd-run \
        --user \
        --quiet \
        --collect \
        --unit="$unit_name" \
        --on-active="${timeout_seconds}s" \
        "${watchdog_env_args[@]}" \
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

    printf '{"status":"pending","token":%s,"output":%s,"enabled":%s,"timeout":%d,"deadline":%d}\n' \
        "$(json_quote "$token")" \
        "$(json_quote "$output")" \
        "$target_enabled" \
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

    # The transient systemd service may not inherit Hyprland-specific
    # environment variables. Restore the exact IPC environment captured by
    # safe-apply before calling hyprctl.
    restore_watchdog_environment "$claim_dir"

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
    local enabled=""

    [[ -r "$pending_dir/token" ]] \
        && existing_token="$(cat "$pending_dir/token")"

    [[ -r "$pending_dir/output" ]] \
        && existing_output="$(cat "$pending_dir/output")"

    [[ -r "$pending_dir/target-enabled" ]] \
        && enabled="$(cat "$pending_dir/target-enabled")"

    if [[ -r "$pending_dir/deadline" ]]; then
        deadline="$(cat "$pending_dir/deadline")"
    fi

    [[ "$deadline" =~ ^[0-9]+$ ]] || deadline=0

    now="$(date +%s)"

    if ((deadline > now)); then
        remaining=$((deadline - now))
    fi

    if [[ "$enabled" != "true" && "$enabled" != "false" ]]; then
        enabled="null"
    fi

    printf '{"status":"pending","token":%s,"output":%s,"enabled":%s,"deadline":%d,"remaining":%d}\n' \
        "$(json_quote "$existing_token")" \
        "$(json_quote "$existing_output")" \
        "$enabled" \
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
