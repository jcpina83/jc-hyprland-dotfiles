#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Repository portability check
#
# Detects machine-local values dynamically instead of embedding personal
# information in this repository.
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
local_dir="$config_home/jc-hyprland-dotfiles/local"

host_env="$local_dir/host.env"
monitors_lua="$local_dir/monitors.lua"
wallpaper_env="$local_dir/wallpaper.env"

cd "$repo_root" || exit 1

errors=0


ok() {
    printf '  OK    %s\n' "$*"
}


fail() {
    printf '  FAIL  %s\n' "$*" >&2
    ((errors += 1))
}


scan_literal() {
    local label="$1"
    local value="$2"

    [[ -n "$value" ]] || return 0

    local matches

    matches="$(
        git grep \
            -nF \
            -- "$value" \
            2>/dev/null \
            || true
    )"

    if [[ -n "$matches" ]]; then
        printf '\n' >&2
        fail "$label detected in tracked files:"
        printf '%s\n' "$matches" >&2
    else
        ok "$label"
    fi
}


# ==============================================================================
# Generic absolute HOME paths
# ==============================================================================

printf '==> Absolute HOME paths\n'

matches="$(
    git grep \
        -nE \
        '/home/[A-Za-z0-9._-]+/' \
        2>/dev/null \
        || true
)"

if [[ -n "$matches" ]]; then

    fail "absolute /home/<user>/ path detected"

    printf '%s\n' "$matches" >&2

else
    ok "no absolute user HOME paths"
fi


# ==============================================================================
# Current machine identity
# ==============================================================================

printf '\n==> Current machine identity\n'

scan_literal \
    "current HOME path not tracked" \
    "$HOME"

current_hostname="$(hostname 2>/dev/null || true)"

scan_literal \
    "current hostname not tracked" \
    "$current_hostname"


# ==============================================================================
# Host-specific hardware
# ==============================================================================

printf '\n==> Host-specific hardware\n'

if [[ -r "$host_env" ]]; then

    # Machine-local configuration.
    # shellcheck disable=SC1090
    source "$host_env"

    if [[ -n "${GPU_PCI:-}" ]]; then
        scan_literal \
            "local GPU PCI address not tracked" \
            "$GPU_PCI"
    else
        ok "no GPU_PCI configured locally"
    fi

else
    ok "no local host.env available for comparison"
fi


# ==============================================================================
# Monitor serial numbers
# ==============================================================================

if [[ -r "$monitors_lua" ]]; then

    found_serial=false

    while IFS= read -r serial; do

        [[ -n "$serial" ]] || continue

        found_serial=true

        scan_literal \
            "monitor serial $serial not tracked" \
            "$serial"

    done < <(
        grep -oE 'HNT[A-Z][0-9]{6,}' \
            "$monitors_lua" \
            2>/dev/null |
            sort -u
    )


    if [[ "$found_serial" != true ]]; then
        ok "no recognizable monitor serials found locally"
    fi

else
    ok "no local monitors.lua available for comparison"
fi


# ==============================================================================
# Local wallpaper overrides
# ==============================================================================

printf '\n==> Local wallpaper overrides\n'

if [[ -r "$wallpaper_env" ]]; then

    # Machine-local configuration.
    # shellcheck disable=SC1090
    source "$wallpaper_env"

    scan_literal \
        "MAIN wallpaper override not tracked" \
        "${MAIN_WALLPAPER_OVERRIDE:-}"

    scan_literal \
        "SECONDARY wallpaper override not tracked" \
        "${SECONDARY_WALLPAPER_OVERRIDE:-}"

else
    ok "no local wallpaper.env available for comparison"
fi


# ==============================================================================
# Summary
# ==============================================================================

printf '\nPortability summary: %d error(s)\n' "$errors"


if ((errors > 0)); then
    exit 1
fi


printf 'Repository portability checks passed.\n'