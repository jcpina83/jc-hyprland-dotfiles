#!/usr/bin/env bash
set -euo pipefail

log() { printf '[jc-hyprland-dotfiles] %s\n' "$*"; }
warn() { printf '[jc-hyprland-dotfiles] WARNING: %s\n' "$*" >&2; }
die() { printf '[jc-hyprland-dotfiles] ERROR: %s\n' "$*" >&2; exit 1; }

repo_root() {
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}
