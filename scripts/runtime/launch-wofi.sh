#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Odyssey Glass - Wofi launcher
# ==============================================================================

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
local_dir="$base/local"

config="$repo/config/wofi/config"
style="$repo/config/wofi/style.css"

monitor=""

usage() {
    cat <<'EOF'
Usage:
  launch-wofi.sh
  launch-wofi.sh --main
  launch-wofi.sh --secondary
  launch-wofi.sh --monitor OUTPUT
  launch-wofi.sh --help
EOF
}


if [[ -r "$local_dir/host.env" ]]; then
    # Machine-local runtime configuration.
    # This file intentionally lives outside the repository.
    # shellcheck disable=SC1091
    source "$local_dir/host.env"
fi


while (($# > 0)); do
    case "$1" in
        --main)
            monitor="${MAIN_OUTPUT:-}"
            ;;

        --secondary)
            monitor="${SECONDARY_OUTPUT:-}"
            ;;

        --monitor)
            shift

            (($# > 0)) || {
                echo "Missing monitor after --monitor" >&2
                exit 2
            }

            monitor="$1"
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac

    shift
done


[[ -r "$config" ]] || {
    echo "Missing Wofi config: $config" >&2
    exit 1
}

[[ -r "$style" ]] || {
    echo "Missing Wofi stylesheet: $style" >&2
    exit 1
}


args=(
    --conf "$config"
    --style "$style"
)


if [[ -n "$monitor" ]]; then
    args+=(--monitor "$monitor")
fi


exec wofi "${args[@]}"