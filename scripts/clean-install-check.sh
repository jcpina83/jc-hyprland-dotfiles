#!/usr/bin/env bash
set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

test_home="$(mktemp -d)"

cleanup() {
    rm -rf "$test_home"
}

trap cleanup EXIT

echo "==> Clean HOME installation simulation"
echo "Temporary HOME: $test_home"

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
"$repo_root/scripts/install.sh" --dry-run

echo
echo "Clean-install simulation passed."