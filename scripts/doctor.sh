#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

distro=$("$(dirname "$0")/detect-distro.sh")
printf 'Distro adapter: %s\n' "$distro"

for cmd in hyprctl waybar wofi foot; do
    if command -v "$cmd" >/dev/null 2>&1; then printf 'OK   %s -> %s\n' "$cmd" "$(command -v "$cmd")"; else printf 'MISS %s\n' "$cmd"; fi
done

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl version | head -n 1 || true
    errors=$(hyprctl configerrors 2>/dev/null || true)
    [[ -z "$errors" ]] && echo 'OK   Hyprland configerrors: clean' || printf 'WARN Hyprland configerrors:\n%s\n' "$errors"
fi
