#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Release readiness check
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

cd "$repo_root" || exit 1

errors=0


ok() {
    printf 'OK    %s\n' "$*"
}


fail() {
    printf 'FAIL  %s\n' "$*" >&2
    ((errors += 1))
}


printf '==> Version\n'

if [[ ! -r VERSION ]]; then

    fail "VERSION file missing"

else

    version="$(tr -d '[:space:]' < VERSION)"

    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        ok "VERSION=$version"
    else
        fail "invalid semantic version: $version"
    fi

fi


printf '\n==> Git diff validation\n'

if git diff --check; then
    ok "git diff --check"
else
    fail "Git whitespace errors detected"
fi


printf '\n==> Repository quality gate\n'

if make --no-print-directory check; then
    ok "make check"
else
    fail "make check failed"
fi


printf '\n==> Git working tree\n'

if [[ -z "$(git status --porcelain)" ]]; then
    ok "working tree clean"
else
    fail "working tree contains uncommitted changes"

    git status --short
fi

printf '\n==> Portability\n'
ok "covered by make check / portability-check.sh"

printf '\n==> Large tracked files\n'

large_files="$(
    git ls-files -z |
        xargs -0 -r du -b 2>/dev/null |
        awk '$1 > 20971520 {print}'
)"

if [[ -n "$large_files" ]]; then

    fail "tracked files larger than 20 MiB detected"

    printf '%s\n' "$large_files" >&2

else
    ok "no tracked file exceeds 20 MiB"
fi


printf '\nRelease summary: %d error(s)\n' "$errors"


if ((errors > 0)); then
    exit 1
fi


printf '\nRepository is ready for release validation.\n'