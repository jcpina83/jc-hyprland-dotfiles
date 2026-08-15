#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"
ROOT=$(repo_root)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
BASE="$CFG/jc-hyprland-dotfiles"
DRY=0
APPLY_HYPR=0

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=1 ;;
        --apply-hyprland) APPLY_HYPR=1 ;;
        *) die "Argumento desconocido: $arg" ;;
    esac
done

run() {
    if (( DRY )); then printf '+ '; printf '%q ' "$@"; printf '\n'; else "$@"; fi
}

log "Repo: $ROOT"
log "Distro: $("$ROOT/scripts/detect-distro.sh")"
run mkdir -p "$BASE/local" "$BASE/bin"

if [[ -L "$BASE/repo" || -e "$BASE/repo" ]]; then
    (( DRY )) || rm -f "$BASE/repo"
fi
run ln -s "$ROOT" "$BASE/repo"

for s in start-waybar.sh network-traffic.sh; do
    target="$ROOT/scripts/runtime/$s"
    link="$BASE/bin/$s"
    [[ -e "$link" || -L "$link" ]] && { (( DRY )) || rm -f "$link"; }
    run ln -s "$target" "$link"
done

if [[ ! -e "$BASE/local/host.env" ]]; then
    run cp "$ROOT/hosts/example/host.env" "$BASE/local/host.env"
fi
if [[ ! -e "$BASE/local/monitors.conf" ]]; then
    run cp "$ROOT/hosts/example/monitors.conf" "$BASE/local/monitors.conf"
fi

integration="$CFG/hypr/jc-dotfiles.conf"
if [[ ! -e "$integration" ]]; then
    run cp "$ROOT/config/hypr/hyprlang/templates/jc-dotfiles.conf.template" "$integration"
fi

if (( APPLY_HYPR )); then
    conf="$CFG/hypr/hyprland.conf"
    [[ -f "$conf" ]] || die "No existe $conf"
    "$ROOT/scripts/backup.sh"
    line='source = ~/.config/hypr/jc-dotfiles.conf'
    if ! grep -Fqx "$line" "$conf"; then
        if (( DRY )); then echo "+ append: $line -> $conf"; else printf '\n# jc-hyprland-dotfiles\n%s\n' "$line" >> "$conf"; fi
    fi
fi

log 'Base instalada. Revisa local/host.env y local/monitors.conf antes de habilitar runtime.'
