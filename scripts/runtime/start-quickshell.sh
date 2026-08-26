#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Quickshell launcher
#
# The named Quickshell configuration is started at most once. IPC is used as
# the authoritative readiness/instance probe because the shell already exposes
# a stable controlCenter IPC contract.
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

# Do not launch a second named shell if the existing instance is healthy enough
# to answer IPC. This also makes repeated manual calls safe.
if qs -c "$config_name" ipc show >/dev/null 2>&1; then
    exit 0
fi

exec qs -c "$config_name"
