#!/usr/bin/env bash

set -uo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
status=0

printf '==> Bash syntax\n'

while IFS= read -r -d '' file; do
    printf '  bash -n %s\n' "${file#"$repo_root"/}"

    if ! bash -n "$file"; then
        status=1
    fi
done < <(
    find "$repo_root" \
        -type f \
        -name '*.sh' \
        -not -path '*/.git/*' \
        -print0
)

if command -v shellcheck >/dev/null 2>&1; then
    printf '\n==> ShellCheck\n'

    mapfile -d '' shell_files < <(
        find "$repo_root" \
            -type f \
            -name '*.sh' \
            -not -path '*/.git/*' \
            -print0
    )

    if ((${#shell_files[@]} > 0)); then
        if ! shellcheck -x "${shell_files[@]}"; then
            status=1
        fi
    fi
else
    printf '\nWARN shellcheck is not installed; static shell lint skipped.\n'
fi

if command -v fish >/dev/null 2>&1; then
    printf '\n==> Fish syntax\n'

    while IFS= read -r -d '' file; do
        printf '  fish -n %s\n' "${file#"$repo_root"/}"

        if ! fish -n "$file"; then
            status=1
        fi
    done < <(
        find "$repo_root" \
            -type f \
            -name '*.fish' \
            -not -path '*/.git/*' \
            -print0
    )
fi

exit "$status"