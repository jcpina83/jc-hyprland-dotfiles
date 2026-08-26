#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Control Center IPC wrapper
# ==============================================================================

config_name="${JC_QUICKSHELL_CONFIG:-jc-hyprland}"

if ! command -v qs >/dev/null 2>&1; then
    printf 'ERROR: quickshell (qs) is not installed or not in PATH.\n' >&2
    exit 1
fi

usage() {
    cat <<'EOF'
Usage:
  jc-control-center show
  jc-control-center show-on <output>
  jc-control-center hide
  jc-control-center toggle
  jc-control-center toggle-on <output>
  jc-control-center refresh
  jc-control-center status
  jc-control-center ipc-show
EOF
}

action="${1:-}"

case "$action" in
    show)
        exec qs -c "$config_name" \
            ipc call controlCenter showDisplays
        ;;

    show-on)
        output="${2:-}"

        if [[ -z "$output" ]]; then
            printf 'ERROR: show-on requires an output name.\n' >&2
            exit 2
        fi

        exec qs -c "$config_name" \
            ipc call controlCenter showDisplaysOn "$output"
        ;;

    hide)
        exec qs -c "$config_name" \
            ipc call controlCenter hideDisplays
        ;;

    toggle)
        exec qs -c "$config_name" \
            ipc call controlCenter toggleDisplays
        ;;

    toggle-on)
        output="${2:-}"

        if [[ -z "$output" ]]; then
            printf 'ERROR: toggle-on requires an output name.\n' >&2
            exit 2
        fi

        exec qs -c "$config_name" \
            ipc call controlCenter toggleDisplaysOn "$output"
        ;;

    refresh)
        exec qs -c "$config_name" \
            ipc call controlCenter refreshDisplays
        ;;

    status)
        exec qs -c "$config_name" \
            ipc call controlCenter displaysAreVisible
        ;;

    ipc-show)
        exec qs -c "$config_name" ipc show
        ;;

    *)
        usage
        exit 2
        ;;
esac
