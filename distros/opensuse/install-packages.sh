#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
mapfile -t pkgs < <(grep -Ev '^\s*(#|$)' "$ROOT/distros/opensuse/packages.txt")
sudo zypper install "${pkgs[@]}"
