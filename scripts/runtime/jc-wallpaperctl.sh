#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Stable wallpaper read API
#
# Phase 2B.2.1 is intentionally read-only.
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
host_env="$base/local/host.env"
manager="$base/bin/wallpaper-manager.sh"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage:
  jc-wallpaperctl status
  jc-wallpaperctl status --json
  jc-wallpaperctl catalog
  jc-wallpaperctl catalog --json
EOF
}

require_jq() {
    command -v jq >/dev/null 2>&1 \
        || die "jq is required for JSON output"
}

[[ -r "$host_env" ]] \
    || die "host configuration not found: $host_env"

[[ -x "$manager" ]] \
    || die "wallpaper manager not found: $manager"

# shellcheck disable=SC1090
source "$host_env"

: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"
: "${SECONDARY_OUTPUT:?SECONDARY_OUTPUT is required}"

runtime_json() {
    local runtime_engine="unknown"
    local main_wallpaper=""
    local secondary_wallpaper=""
    local raw=""
    local line
    local rest
    local output
    local wallpaper

    require_jq

    if command -v awww >/dev/null 2>&1 \
        && pgrep -x awww-daemon >/dev/null 2>&1 \
        && raw="$(awww query 2>/dev/null)"
    then
        runtime_engine="awww"

        while IFS= read -r line; do
            [[ "$line" == *"currently displaying: image: "* ]] || continue

            rest="${line#: }"
            output="${rest%%:*}"
            wallpaper="${line#*currently displaying: image: }"

            case "$output" in
                "$MAIN_OUTPUT")
                    main_wallpaper="$wallpaper"
                    ;;
                "$SECONDARY_OUTPUT")
                    secondary_wallpaper="$wallpaper"
                    ;;
            esac
        done <<< "$raw"

    elif pgrep -x hyprpaper >/dev/null 2>&1; then
        runtime_engine="hyprpaper"
    fi

    jq -n \
        --arg engine "$runtime_engine" \
        --arg mainOutput "$MAIN_OUTPUT" \
        --arg mainWallpaper "$main_wallpaper" \
        --arg secondaryOutput "$SECONDARY_OUTPUT" \
        --arg secondaryWallpaper "$secondary_wallpaper" \
        '{
            engine: $engine,
            outputs: {
                main: {
                    name: $mainOutput,
                    wallpaper: $mainWallpaper,
                    known: ($mainWallpaper != "")
                },
                secondary: {
                    name: $secondaryOutput,
                    wallpaper: $secondaryWallpaper,
                    known: ($secondaryWallpaper != "")
                }
            }
        }'
}

print_status_json() {
    local configured
    local runtime

    require_jq

    configured="$("$manager" current --json)"
    runtime="$(runtime_json)"

    jq -n \
        --argjson configured "$configured" \
        --argjson runtime "$runtime" \
        --arg mainOutput "$MAIN_OUTPUT" \
        --arg secondaryOutput "$SECONDARY_OUTPUT" \
        '
        $configured
        | .outputs.main.output = $mainOutput
        | .outputs.secondary.output = $secondaryOutput
        | .runtime = $runtime
        '
}

print_status() {
    "$manager" current

    printf '\nOutputs:\n'
    printf '  MAIN:      %s\n' "$MAIN_OUTPUT"
    printf '  SECONDARY: %s\n' "$SECONDARY_OUTPUT"

    printf '\nRuntime:\n'

    if command -v awww >/dev/null 2>&1 \
        && pgrep -x awww-daemon >/dev/null 2>&1
    then
        awww query 2>/dev/null || printf '  awww query unavailable\n'
    elif pgrep -x hyprpaper >/dev/null 2>&1; then
        printf '  engine: hyprpaper\n'
        printf '  active wallpaper paths: unavailable through this read API\n'
    else
        printf '  engine: unknown\n'
    fi
}

command_name="${1:-}"

case "$command_name" in
    status)
        if [[ "$#" -eq 1 ]]; then
            print_status
        elif [[ "$#" -eq 2 && "$2" == "--json" ]]; then
            print_status_json
        else
            usage >&2
            exit 2
        fi
        ;;

    catalog)
        if [[ "$#" -eq 1 ]]; then
            exec "$manager" catalog
        elif [[ "$#" -eq 2 && "$2" == "--json" ]]; then
            exec "$manager" catalog --json
        else
            usage >&2
            exit 2
        fi
        ;;

    --help|-h|help)
        usage
        ;;

    *)
        usage >&2
        exit 2
        ;;
esac
