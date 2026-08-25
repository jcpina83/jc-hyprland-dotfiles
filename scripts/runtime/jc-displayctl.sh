#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Safe runtime display controller
#
# Phase 1B.2:
# - accepts a live connector name such as DP-1 / DP-3
# - resolves the connector to its current Hyprland description
# - matches either output-name or desc:<description> rules in monitors.conf
# - preserves the original persistent selector when applying the runtime rule
# - modifies only the live Hyprland monitor rule
# - preserves position, scale and supported extra fields from local/monitors.conf
# - never writes local/monitors.conf
# ==============================================================================

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
base="$config_home/jc-hyprland-dotfiles"
monitors_conf="${JC_MONITORS_CONF:-$base/local/monitors.conf}"

command_name="${1:-}"
shift || true

output=""
mode=""
description=""
description_selector=""


usage() {
    cat <<'EOF'
Usage:
  jc-displayctl preflight --output <output> --mode <WIDTHxHEIGHT@HZ>
  jc-displayctl apply     --output <output> --mode <WIDTHxHEIGHT@HZ>

The --output argument is the live connector reported by Hyprland, for example:
  DP-1
  DP-3

jc-displayctl resolves that connector through:
  hyprctl -j monitors all

and accepts persistent rules selected either by:
  monitor = DP-1, ...
or:
  monitor = desc:<monitor description>, ...

The persistent file is read only. Runtime changes are issued through:
  hyprctl -r eval 'hl.monitor({...})'
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


lua_quote() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"

    printf '"%s"' "$value"
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


parse_args() {
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
    lua+=", mode = $(lua_quote "$mode")"
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


run_preflight() {
    local payload
    local lua_rule

    resolve_monitor_identity
    payload="$(find_monitor_payload)"
    lua_rule="$(build_lua_rule "$payload")"

    printf '%s\n' "$lua_rule"
}


run_apply() {
    local payload
    local lua_rule
    local result

    resolve_monitor_identity
    payload="$(find_monitor_payload)"
    lua_rule="$(build_lua_rule "$payload")"

    result="$(hyprctl -r eval "$lua_rule" 2>&1)" \
        || die "$result"

    result="$(trim "$result")"

    [[ "$result" == "ok" ]] \
        || die "hyprctl returned: ${result:-<empty>}"

    printf 'ok\n'
}


case "$command_name" in
    preflight)
        parse_args "$@"
        run_preflight
        ;;

    apply)
        parse_args "$@"
        run_apply
        ;;

    --help|-h|"")
        usage
        ;;

    *)
        die "unknown command: $command_name"
        ;;
esac
