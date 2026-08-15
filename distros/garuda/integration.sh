#!/usr/bin/env bash
set -euo pipefail
# Garuda-specific overrides will live here. Package installation inherits Arch.
exec "$(cd "$(dirname "$0")/../arch" && pwd)/install-packages.sh" "$@"
