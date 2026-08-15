#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Update
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "$script_path")" && pwd)"

"$repo_root/scripts/configure-hypridle.sh"

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
git pull --ff-only
./install.sh