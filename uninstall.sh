#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
BASE="$CFG/jc-hyprland-dotfiles"

printf 'No se borrará configuración local automáticamente.\n'
printf 'Namespace instalado: %s\n' "$BASE"
printf 'Retira manualmente de ~/.config/hypr/hyprland.lua la integración:\n'
printf '  require("jc-dotfiles/init")\n'
printf 'La configuración machine-local bajo %s/local se conserva.\n' "$BASE"
