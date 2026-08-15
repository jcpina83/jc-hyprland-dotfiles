#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Repository portability check
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

cd "$repo_root" || exit 1


patterns=(
    '/home/jcpina'
    'TUF-Gamming-Desktop'
    'HNTW801671'
    'HNTY800053'
    '0000:03:00.0'
    'Garuda-TilliDie-cube-105.png'
)


errors=0


printf '==> Personal / machine-specific hardcodes\n'


for pattern in "${patterns[@]}"; do

    matches="$(
        grep \
            -RInF \
            --exclude-dir=.git \
            --exclude='*.md' \
            --exclude='portability-check.sh' \
            -- "$pattern" \
            config \
            scripts \
            themes \
            distros \
            hosts \
            install.sh \
            update.sh \
            uninstall.sh \
            Makefile \
            2>/dev/null \
            || true
    )"

    if [[ -n "$matches" ]]; then

        printf '\nFAIL hardcoded pattern: %s\n' "$pattern" >&2
        printf '%s\n' "$matches" >&2

        ((errors += 1))
    fi

done


if ((errors > 0)); then
    printf '\nPortability check failed: %d hardcoded pattern(s)\n' \
        "$errors" >&2

    exit 1
fi


printf '  OK    no known personal or machine-specific hardcodes\n'