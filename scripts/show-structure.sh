#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
find "$ROOT" -maxdepth "${1:-4}" -not -path '*/.git/*' -not -path '*/.git' -print | sed "s#^$ROOT#.#" | sort
