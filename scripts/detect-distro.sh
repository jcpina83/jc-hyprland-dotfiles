#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

[[ -r /etc/os-release ]] || die '/etc/os-release no existe'
. /etc/os-release

case "${ID:-}" in
    garuda) echo garuda ;;
    arch) echo arch ;;
    opensuse-tumbleweed|opensuse-leap|opensuse) echo opensuse ;;
    *)
        case " ${ID_LIKE:-} " in
            *' arch '*) echo arch ;;
            *' suse '*) echo opensuse ;;
            *) echo unsupported ;;
        esac
        ;;
esac
