#!/usr/bin/env bash
set -euo pipefail

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
repo="$base/repo"
localdir="$base/local"
runtime="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-$UID"

mkdir -p "$runtime"

usage() {
    cat <<'EOF'
Usage:
  start-waybar.sh             Start/restart only jc-hyprland-dotfiles Waybars
  start-waybar.sh --stop      Stop only jc-hyprland-dotfiles Waybars
  start-waybar.sh --replace   Stop all Waybars and start jc-hyprland-dotfiles
  start-waybar.sh --help      Show this help
EOF
}

stop_managed_waybars() {
    local name pidfile pid

    for name in main secondary; do
        pidfile="$runtime/waybar-${name}.pid"

        [[ -f "$pidfile" ]] || continue

        pid=$(<"$pidfile")

        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            echo "[jc-hyprland-dotfiles] Stopping Waybar $name (PID $pid)"
            kill "$pid" 2>/dev/null || true
        fi

        rm -f "$pidfile"
    done
}

mode="start"

case "${1:-}" in
    "")
        ;;
    --stop)
        mode="stop"
        ;;
    --replace)
        mode="replace"
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
    stop_managed_waybars
    exit 0
fi

[[ -r "$localdir/host.env" ]] || {
    echo "Missing $localdir/host.env" >&2
    exit 1
}

# Machine-local runtime configuration.
# shellcheck disable=SC1091
source "$localdir/host.env"

: "${MAIN_OUTPUT:?MAIN_OUTPUT is required}"
: "${SECONDARY_OUTPUT:?SECONDARY_OUTPUT is required}"
: "${MAIN_WORKSPACES:?MAIN_WORKSPACES is required}"
: "${SECONDARY_WORKSPACES:?SECONDARY_WORKSPACES is required}"

sed \
    -e "s/@MAIN_OUTPUT@/${MAIN_OUTPUT//\//\\/}/g" \
    -e "s/@MAIN_WORKSPACES@/${MAIN_WORKSPACES// /}/g" \
    "$repo/config/waybar/templates/config-main.jsonc" \
    > "$runtime/waybar-main.jsonc"

sed \
    -e "s/@SECONDARY_OUTPUT@/${SECONDARY_OUTPUT//\//\\/}/g" \
    -e "s/@SECONDARY_WORKSPACES@/${SECONDARY_WORKSPACES// /}/g" \
    "$repo/config/waybar/templates/config-secondary.jsonc" \
    > "$runtime/waybar-secondary.jsonc"

# Always stop only instances previously started by this project.
stop_managed_waybars

if [[ "$mode" == "replace" ]]; then
    echo "[jc-hyprland-dotfiles] Replacing all existing Waybar instances"
    pkill -x waybar 2>/dev/null || true
fi

echo "[jc-hyprland-dotfiles] Starting MAIN Waybar on $MAIN_OUTPUT"

nohup waybar \
    -c "$runtime/waybar-main.jsonc" \
    -s "$repo/config/waybar/style.css" \
    > "$runtime/waybar-main.log" 2>&1 &

echo "$!" > "$runtime/waybar-main.pid"

echo "[jc-hyprland-dotfiles] Starting SECONDARY Waybar on $SECONDARY_OUTPUT"

nohup waybar \
    -c "$runtime/waybar-secondary.jsonc" \
    -s "$repo/config/waybar/style.css" \
    > "$runtime/waybar-secondary.log" 2>&1 &

echo "$!" > "$runtime/waybar-secondary.pid"

echo
echo "[jc-hyprland-dotfiles] Waybars started"
echo "  MAIN:      $MAIN_OUTPUT"
echo "  SECONDARY: $SECONDARY_OUTPUT"
echo
echo "Logs:"
echo "  $runtime/waybar-main.log"
echo "  $runtime/waybar-secondary.log"
echo
echo "Stop with:"
echo "  $base/bin/start-waybar.sh --stop"