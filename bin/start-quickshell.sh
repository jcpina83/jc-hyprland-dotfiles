#!/usr/bin/env bash
set -euo pipefail

CONFIG_NAME="${JC_QUICKSHELL_CONFIG:-jc-hyprland}"

if ! command -v qs >/dev/null 2>&1; then
  echo "ERROR: quickshell (qs) is not installed or not in PATH." >&2
  exit 1
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_DIR="${CONFIG_HOME}/quickshell/${CONFIG_NAME}"

if [[ ! -e "${CONFIG_DIR}/shell.qml" ]]; then
  echo "ERROR: Quickshell config not installed: ${CONFIG_DIR}" >&2
  echo "Create the symlink first, for example:" >&2
  echo "  mkdir -p \"${CONFIG_HOME}/quickshell\"" >&2
  echo "  ln -sfn <repo>/config/quickshell/${CONFIG_NAME} \"${CONFIG_DIR}\"" >&2
  exit 1
fi

exec qs -c "${CONFIG_NAME}"
