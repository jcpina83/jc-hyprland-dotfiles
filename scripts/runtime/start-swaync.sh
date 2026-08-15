#!/usr/bin/env bash

set -euo pipefail


base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
local_dir="$base/local"

runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"

pidfile="$runtime/swaync.pid"
logfile="$runtime/swaync.log"
generated_config="$runtime/swaync-config.json"


mkdir -p "$runtime"


usage() {
    cat <<'EOF'
Usage:
  start-swaync.sh
  start-swaync.sh --stop
  start-swaync.sh --restart
  start-swaync.sh --help
EOF
}


stop_managed() {
    if [[ ! -f "$pidfile" ]]; then
        return 0
    fi

    pid=$(<"$pidfile")

    if [[ "$pid" =~ ^[0-9]+$ ]] \
        && kill -0 "$pid" 2>/dev/null
    then
        echo "[jc-hyprland-dotfiles] Stopping SwayNC (PID $pid)"
        kill "$pid" 2>/dev/null || true
    fi

    rm -f "$pidfile"
}


mode="start"


case "${1:-}" in
    "")
        ;;

    --stop)
        mode="stop"
        ;;

    --restart)
        mode="restart"
        ;;

    --help|-h)
        usage
        exit 0
        ;;

    *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
esac


if [[ "$mode" == "stop" ]]; then
    stop_managed
    exit 0
fi


[[ -r "$local_dir/host.env" ]] || {
    echo "Missing $local_dir/host.env" >&2
    exit 1
}


# Machine-local configuration.
# shellcheck disable=SC1091
source "$local_dir/host.env"


: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"


template="$repo/config/swaync/config.json.template"
style="$repo/config/swaync/style.css"


[[ -r "$template" ]] || {
    echo "Missing SwayNC template: $template" >&2
    exit 1
}


[[ -r "$style" ]] || {
    echo "Missing SwayNC stylesheet: $style" >&2
    exit 1
}


sed \
    "s/@MAIN_OUTPUT@/${MAIN_OUTPUT//\//\\/}/g" \
    "$template" \
    > "$generated_config"


if [[ "$mode" == "restart" ]]; then
    stop_managed
fi


# Refuse to compete with another notification daemon.
if pgrep -x mako >/dev/null 2>&1; then
    echo "Mako is currently running." >&2
    echo "Stop it before starting Odyssey Glass SwayNC:" >&2
    echo "  pkill -x mako" >&2
    exit 3
fi


if pgrep -x swaync >/dev/null 2>&1; then
    echo "Another SwayNC instance is already running." >&2
    echo "Stop it before starting the managed instance." >&2
    exit 4
fi


echo "[jc-hyprland-dotfiles] Starting SwayNC on $MAIN_OUTPUT"


nohup swaync \
    --config "$generated_config" \
    --style "$style" \
    > "$logfile" 2>&1 &


echo "$!" > "$pidfile"


echo "[jc-hyprland-dotfiles] SwayNC started"
echo "Config: $generated_config"
echo "Style:  $style"
echo "Log:    $logfile"