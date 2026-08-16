#!/usr/bin/env bash

set -euo pipefail

RUNTIME_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
REPO_LINK="${RUNTIME_DIR}/repo"
THEME_LINK="${RUNTIME_DIR}/theme"

if [[ ! -e "${REPO_LINK}" ]]; then
    notify-send "JC Hyprland" "No se encontró el repositorio activo"
    exit 1
fi

REPO="$(readlink -f "${REPO_LINK}")"
THEMES_DIR="${REPO}/themes"

if [[ ! -d "${THEMES_DIR}" ]]; then
    notify-send "JC Hyprland" "No se encontró el directorio de temas"
    exit 1
fi

current_theme=""

if [[ -L "${THEME_LINK}" ]]; then
    current_theme="$(basename "$(readlink -f "${THEME_LINK}")")"
fi

menu_entries=()

while IFS= read -r theme; do
    if [[ "${theme}" == "${current_theme}" ]]; then
        menu_entries+=("★ ${theme}")
    else
        menu_entries+=("${theme}")
    fi
done < <(
    find "${THEMES_DIR}" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' |
    sort
)

if [[ ${#menu_entries[@]} -eq 0 ]]; then
    notify-send "JC Hyprland" "No hay temas disponibles"
    exit 1
fi

selection="$(
    printf '%s\n' "${menu_entries[@]}" |
        wofi \
            --dmenu \
            --prompt "Seleccionar tema"
)"

[[ -z "${selection}" ]] && exit 0

selection="${selection#★ }"

if [[ "${selection}" == "${current_theme}" ]]; then
    exit 0
fi

if make -C "${REPO}" theme-apply THEME="${selection}"; then
    notify-send \
        "Tema aplicado" \
        "${selection}"
else
    notify-send \
        -u critical \
        "Error al aplicar tema" \
        "${selection}"

    exit 1
fi