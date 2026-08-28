#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Stable wallpaper control API
#
# Reads remain side-effect free. Mutation is delegated transactionally
# through wallpaper-manager.sh; this wrapper never edits preferences.
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
  jc-wallpaperctl apply --main <file> [--secondary <file>] [--json]
  jc-wallpaperctl apply --secondary <file> [--main <file>] [--json]
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
    local configured_json="${1:-}"

    if [[ -z "$configured_json" ]]; then
        configured_json='{}'
    fi
    local runtime_engine="unknown"
    local main_wallpaper=""
    local secondary_wallpaper=""
    local expected_main=""
    local expected_secondary=""
    local raw=""
    local line
    local rest
    local output
    local wallpaper

    require_jq

    expected_main="$(
        jq -r '.outputs.main.effective // ""' <<< "$configured_json"
    )"
    expected_secondary="$(
        jq -r '.outputs.secondary.effective // ""' <<< "$configured_json"
    )"

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

    elif pgrep -x hyprpaper >/dev/null 2>&1 \
        && raw="$(hyprctl hyprpaper listactive 2>/dev/null || true)"
    then
        runtime_engine="hyprpaper"

        while IFS= read -r line; do
            if [[ -n "$expected_main" \
                && "$line" == *"$MAIN_OUTPUT"* \
                && "$line" == *"$expected_main"* ]]
            then
                main_wallpaper="$expected_main"
            fi

            if [[ -n "$expected_secondary" \
                && "$line" == *"$SECONDARY_OUTPUT"* \
                && "$line" == *"$expected_secondary"* ]]
            then
                secondary_wallpaper="$expected_secondary"
            fi
        done <<< "$raw"
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
    runtime="$(runtime_json "$configured")"

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

canonical_wallpaper_file() {
    local file="$1"

    [[ -f "$file" ]] || die "wallpaper file not found: $file"
    [[ -r "$file" ]] || die "wallpaper file is not readable: $file"

    readlink -f "$file"
}


apply_transaction() {
    local requested_main="__KEEP__"
    local requested_secondary="__KEEP__"
    local output_json=false

    local before
    local after
    local manager_log
    local apply_status
    local main_changed=false
    local secondary_changed=false
    local runtime_verified=false

    shift

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --main)
                [[ "$#" -ge 2 ]] || die "--main requires a wallpaper path"
                [[ "$requested_main" == "__KEEP__" ]] \
                    || die "--main may only be supplied once"

                requested_main="$(canonical_wallpaper_file "$2")"
                shift 2
                ;;

            --secondary)
                [[ "$#" -ge 2 ]] || die "--secondary requires a wallpaper path"
                [[ "$requested_secondary" == "__KEEP__" ]] \
                    || die "--secondary may only be supplied once"

                requested_secondary="$(canonical_wallpaper_file "$2")"
                shift 2
                ;;

            --json)
                output_json=true
                shift
                ;;

            *)
                die "unsupported apply argument: $1"
                ;;
        esac
    done

    if [[ "$requested_main" == "__KEEP__" \
        && "$requested_secondary" == "__KEEP__" ]]
    then
        die "apply requires --main and/or --secondary"
    fi

    before="$(print_status_json)"
    manager_log="$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/jc-wallpaper-apply.XXXXXX")"

    cleanup_apply_log() {
        rm -f -- "$manager_log"
    }

    trap cleanup_apply_log RETURN

    if "$manager" transactional-set \
        "$requested_main" "$requested_secondary" \
        >"$manager_log" 2>&1
    then
        apply_status=0
    else
        apply_status=$?

        if [[ "$output_json" == true ]]; then
            jq -n \
                --arg status "rolled-back" \
                --arg message "$(tail -n 12 "$manager_log")" \
                --argjson exitCode "$apply_status" \
                '{
                    status: $status,
                    committed: false,
                    rolledBack: true,
                    exitCode: $exitCode,
                    message: $message
                }'
        else
            cat "$manager_log" >&2
        fi

        trap - RETURN
        rm -f -- "$manager_log"
        return "$apply_status"
    fi

    after="$(print_status_json)"

    if [[ "$requested_main" != "__KEEP__" ]]; then
        main_changed=true
    fi

    if [[ "$requested_secondary" != "__KEEP__" ]]; then
        secondary_changed=true
    fi

    if jq -e '
        .runtime.outputs.main.known
        and .runtime.outputs.secondary.known
        and (.runtime.outputs.main.wallpaper == .outputs.main.effective)
        and (
            .runtime.outputs.secondary.wallpaper
            == .outputs.secondary.effective
        )
    ' <<< "$after" >/dev/null
    then
        runtime_verified=true
    fi

    if [[ "$output_json" == true ]]; then
        jq -n \
            --argjson before "$before" \
            --argjson after "$after" \
            --argjson mainChanged "$main_changed" \
            --argjson secondaryChanged "$secondary_changed" \
            --argjson runtimeVerified "$runtime_verified" \
            '{
                status: "applied",
                committed: true,
                rolledBack: false,
                runtimeVerified: $runtimeVerified,
                changed: {
                    main: $mainChanged,
                    secondary: $secondaryChanged
                },
                before: {
                    main: $before.outputs.main.effective,
                    secondary: $before.outputs.secondary.effective
                },
                after: {
                    main: $after.outputs.main.effective,
                    secondary: $after.outputs.secondary.effective,
                    runtimeMain: $after.runtime.outputs.main.wallpaper,
                    runtimeSecondary: $after.runtime.outputs.secondary.wallpaper,
                    engine: $after.runtime.engine
                }
            }'
    else
        cat "$manager_log"

        printf '\nTransaction summary:\n'
        printf '  runtime verified: %s\n' "$runtime_verified"
    fi

    trap - RETURN
    rm -f -- "$manager_log"
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

    apply)
        apply_transaction "$@"
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
