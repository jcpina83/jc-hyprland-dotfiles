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

printf '\n==> JSON / JSONC templates\n'

if command -v python3 >/dev/null 2>&1; then

    mapfile -d '' json_files < <(
        find "$repo_root/config" \
            -type f \
            \( \
                -name '*.json' \
                -o -name '*.jsonc' \
                -o -name '*.json.template' \
            \) \
            -print0
    )

    if ((${#json_files[@]} > 0)); then
        if ! python3 \
            "$repo_root/scripts/validate-jsonc.py" \
            "${json_files[@]}"
        then
            status=1
        fi
    fi

else
    printf 'WARN python3 not installed; JSON/JSONC validation skipped.\n'
fi

printf '\n==> Foot configuration\n'

foot_base="$repo_root/config/foot/foot.ini"
foot_theme="$repo_root/themes/odyssey-glass/foot-colors.ini"


if command -v foot >/dev/null 2>&1; then

    foot_tmp="$(mktemp)"

    {
        cat "$foot_base"

        printf '\n'

        cat "$foot_theme"
    } > "$foot_tmp"


    if foot \
        --config="$foot_tmp" \
        --check-config
    then
        printf '  Foot OK    base + odyssey-glass\n'
    else
        printf '  Foot FAIL  base + odyssey-glass\n' >&2
        status=1
    fi


    rm -f "$foot_tmp"

else
    printf 'WARN foot not installed; Foot validation skipped.\n'
fi

exit "$status"