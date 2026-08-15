#!/usr/bin/env bash
set -euo pipefail
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
BASE="$CFG/jc-hyprland-dotfiles"
printf 'No se borrará configuración local automáticamente.\n'
printf 'Namespace instalado: %s\n' "$BASE"
printf 'Retira manualmente de hyprland.conf: source = ~/.config/hypr/jc-dotfiles.conf\n'
