#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

stamp=$(date +%Y%m%d-%H%M%S)
dest="${XDG_STATE_HOME:-$HOME/.local/state}/jc-hyprland-dotfiles/backups/$stamp"
mkdir -p "$dest"

for item in hypr waybar wofi swaync foot; do
    src="${XDG_CONFIG_HOME:-$HOME/.config}/$item"
    [[ -e "$src" ]] && cp -a "$src" "$dest/"
done

log "Backup: $dest"
