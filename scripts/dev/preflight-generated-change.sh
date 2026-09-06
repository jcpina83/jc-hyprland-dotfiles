#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
    cat <<'EOF'
Usage:
  preflight-generated-change.sh script <generated-script.sh>
  preflight-generated-change.sh changed
  preflight-generated-change.sh repo

Modes:
  script   Validate one generated Bash script before execution:
             - bash -n
             - ShellCheck
             - embedded Python heredoc syntax
             - embedded Bash/sh heredoc syntax + ShellCheck

  changed  Validate every changed/untracked *.sh file:
             - bash -n
             - ShellCheck

  repo     Run "changed", then:
             - scripts/validate-quickshell.sh
             - make lint
             - make check
             - git diff --check

Policy:
  Fix ShellCheck findings in source by default. Suppressions are reserved for
  intentional behavior and must be justified next to the suppression.
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

require_command() {
    local name="$1"

    command -v "$name" >/dev/null 2>&1 \
        || die "required command not found: $name"
}

run_bash_checks() {
    local path="$1"

    [[ -f "$path" ]] || die "file not found: $path"

    echo "  bash -n $path"
    bash -n "$path"

    echo "  shellcheck $path"
    shellcheck "$path"
}

check_embedded_heredocs() {
    local script_path="$1"

    python3 - "$script_path" <<'PY'
from __future__ import annotations

import ast
import pathlib
import re
import subprocess
import sys
import tempfile

path = pathlib.Path(sys.argv[1])
lines = path.read_text().splitlines()

python_open = re.compile(
    r"""^\s*(?:python|python3)\b[^<\n]*<<-?['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\s*$"""
)
shell_open = re.compile(
    r"""^\s*(?:bash|sh)\s+(?:-[A-Za-z]+\s+)?<<-?['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\s*$"""
)


def collect_body(start: int, tag: str) -> tuple[str, int]:
    body: list[str] = []
    index = start

    while index < len(lines):
        candidate = lines[index]

        if candidate.strip() == tag:
            return "\n".join(body) + "\n", index

        body.append(candidate)
        index += 1

    raise SystemExit(f"ERROR: unterminated heredoc {tag!r} in {path}")


python_blocks = 0
shell_blocks = 0
index = 0

while index < len(lines):
    line = lines[index]

    match = python_open.match(line)

    if match:
        tag = match.group(1)
        body, end = collect_body(index + 1, tag)
        ast.parse(body, filename=f"{path}:{index + 2}")
        python_blocks += 1
        index = end + 1
        continue

    match = shell_open.match(line)

    if match:
        tag = match.group(1)
        body, end = collect_body(index + 1, tag)

        with tempfile.NamedTemporaryFile(
            "w",
            suffix=".sh",
            delete=False,
        ) as handle:
            handle.write(body)
            temporary_path = pathlib.Path(handle.name)

        try:
            subprocess.run(
                ["bash", "-n", str(temporary_path)],
                check=True,
            )
            subprocess.run(
                ["shellcheck", str(temporary_path)],
                check=True,
            )
        finally:
            temporary_path.unlink(missing_ok=True)

        shell_blocks += 1
        index = end + 1
        continue

    index += 1

print(f"  embedded_python_blocks={python_blocks}")
print(f"  embedded_shell_blocks={shell_blocks}")
PY
}

changed_shell_files() {
    {
        git diff --name-only --diff-filter=ACMR
        git ls-files --others --exclude-standard
    } |
        awk 'NF && /\.sh$/ {print}' |
        sort -u
}

mode_script() {
    local path="${1:-}"

    [[ -n "$path" ]] || die "script mode requires a path"

    require_command bash
    require_command shellcheck
    require_command python3

    echo "==> Generated script preflight"
    run_bash_checks "$path"

    echo "==> Embedded heredoc preflight"
    check_embedded_heredocs "$path"

    echo
    echo "generated_script_preflight_rc=0"
}

mode_changed() {
    require_command bash
    require_command shellcheck
    require_command git

    git rev-parse --show-toplevel >/dev/null 2>&1 \
        || die "changed mode must run inside a Git worktree"

    mapfile -t candidates < <(changed_shell_files)

    echo "==> Changed Bash files"

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "  no changed *.sh files"
    else
        for path in "${candidates[@]}"; do
            run_bash_checks "$path"
        done
    fi

    echo
    echo "changed_shell_files=${#candidates[@]}"
    echo "changed_shell_preflight_rc=0"
}

mode_repo() {
    require_command make
    require_command git

    git rev-parse --show-toplevel >/dev/null 2>&1 \
        || die "repo mode must run inside a Git worktree"

    mode_changed

    echo
    echo "==> Repository validator"
    bash scripts/validate-quickshell.sh

    echo
    echo "==> Repository lint"
    make lint

    echo
    echo "==> Repository check"
    make check

    echo
    echo "==> Git diff check"
    git diff --check

    echo
    echo "repo_preflight_rc=0"
}

case "${1:-}" in
    script)
        shift
        mode_script "$@"
        ;;
    changed)
        shift
        [[ $# -eq 0 ]] || die "changed mode takes no arguments"
        mode_changed
        ;;
    repo)
        shift
        [[ $# -eq 0 ]] || die "repo mode takes no arguments"
        mode_repo
        ;;
    -h|--help|help|"")
        usage
        ;;
    *)
        usage >&2
        die "unknown mode: $1"
        ;;
esac
