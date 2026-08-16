#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Quickshell launcher
# ==============================================================================

config_name="${JC_QUICKSHELL_CONFIG:-jc-hyprland}"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config_dir="$config_home/quickshell/$config_name"

if ! command -v qs >/dev/null 2>&1; then
    printf 'ERROR: quickshell (qs) is not installed or not in PATH.\n' >&2
    exit 1
fi

if [[ ! -r "$config_dir/shell.qml" ]]; then
    printf 'ERROR: Quickshell config is not installed: %s\n' "$config_dir" >&2
    printf 'Run the repository installer first: ./install.sh\n' >&2
    exit 1
fi

exec qs -c "$config_name"
