#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Runtime doctor
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

base="$config_home/jc-hyprland-dotfiles"
local_dir="$base/local"
bin_dir="$base/bin"

host_env="$local_dir/host.env"

errors=0
warnings=0


ok() {
    printf 'OK    %s\n' "$*"
}


warn() {
    printf 'WARN  %s\n' "$*" >&2
    ((warnings += 1))
}


fail() {
    printf 'FAIL  %s\n' "$*" >&2
    ((errors += 1))
}


section() {
    printf '\n==> %s\n' "$1"
}


# ==============================================================================
# Distro
# ==============================================================================

section "Distribution"

if distro="$("$script_dir/detect-distro.sh" --id 2>/dev/null)"; then
    ok "Distro adapter: $distro"
else
    warn "Unable to detect supported distro adapter"
fi


# ==============================================================================
# Commands
# ==============================================================================

section "Runtime dependencies"

required_commands=(
    hyprctl
    waybar
    wofi
    foot
    hyprlock
    hyprpaper
    swaync
    swaync-client
)

for command_name in "${required_commands[@]}"; do

    if command -v "$command_name" >/dev/null 2>&1; then
        ok "$command_name -> $(command -v "$command_name")"
    else
        fail "missing command: $command_name"
    fi

done


section "Development dependencies"

optional_commands=(
    shellcheck
    python3
    fish
    jq
)

for command_name in "${optional_commands[@]}"; do

    if command -v "$command_name" >/dev/null 2>&1; then
        ok "$command_name"
    else
        warn "development command not found: $command_name"
    fi

done


# ==============================================================================
# Active theme
# ==============================================================================

section "Active theme"

if [[ -L "$base/theme" ]]; then

    theme_target="$(readlink -f "$base/theme")"

    if [[ -d "$theme_target" ]]; then

        theme_name="$(basename "$theme_target")"

        ok "$theme_name -> $theme_target"

        if ! "$script_dir/validate-themes.sh" "$theme_name"; then
            fail "active theme validation failed"
        fi

    else
        fail "active theme symlink is broken"
    fi

else
    fail "active theme symlink missing: $base/theme"
fi


# ==============================================================================
# Host configuration
# ==============================================================================

section "Host configuration"

if [[ -r "$host_env" ]]; then

    ok "$host_env"

    # Machine-local configuration.
    # shellcheck disable=SC1090
    source "$host_env"

    required_host_vars=(
        PROFILE
        THEME
        MAIN_OUTPUT
        SECONDARY_OUTPUT
        MAIN_WORKSPACES
        SECONDARY_WORKSPACES
    )

    for variable in "${required_host_vars[@]}"; do

        if [[ -n "${!variable:-}" ]]; then
            ok "$variable=${!variable}"
        else
            fail "missing host variable: $variable"
        fi

    done

    if [[ -n "${GPU_PCI:-}" ]]; then

        if [[ -d "/sys/bus/pci/devices/$GPU_PCI" ]]; then
            ok "GPU_PCI=$GPU_PCI"
        else
            warn "configured GPU PCI device not found: $GPU_PCI"
        fi

    else
        warn "GPU_PCI not configured; AMD Waybar telemetry may be unavailable"
    fi

else
    fail "host configuration missing: $host_env"
fi


# ==============================================================================
# Hyprland
# ==============================================================================

section "Hyprland"

if command -v hyprctl >/dev/null 2>&1; then

    version="$(
        hyprctl version 2>/dev/null |
            head -1
    )"

    [[ -n "$version" ]] && ok "$version"

    config_errors="$(hyprctl configerrors 2>/dev/null || true)"

    if [[ -z "$config_errors" ]]; then
        ok "Hyprland configerrors: clean"
    else
        fail "Hyprland configuration errors:"
        printf '%s\n' "$config_errors" >&2
    fi


    if [[ -n "${MAIN_OUTPUT:-}" ]]; then

        monitor_names="$(
            hyprctl monitors 2>/dev/null |
                awk '/^Monitor / {print $2}'
        )"

        if grep -Fxq "$MAIN_OUTPUT" <<< "$monitor_names"; then
            ok "MAIN_OUTPUT active: $MAIN_OUTPUT"
        else
            fail "MAIN_OUTPUT not active: $MAIN_OUTPUT"
        fi

    fi


    if [[ -n "${SECONDARY_OUTPUT:-}" ]]; then

        if grep -Fxq "$SECONDARY_OUTPUT" <<< "${monitor_names:-}"; then
            ok "SECONDARY_OUTPUT active: $SECONDARY_OUTPUT"
        else
            fail "SECONDARY_OUTPUT not active: $SECONDARY_OUTPUT"
        fi

    fi

else
    fail "hyprctl unavailable"
fi


# ==============================================================================
# Runtime links
# ==============================================================================

section "Runtime links"

runtime_links=(
    "start-waybar.sh:scripts/runtime/start-waybar.sh"
    "network-traffic.sh:scripts/runtime/network-traffic.sh"
    "amd-gpu.sh:scripts/runtime/amd-gpu.sh"
    "launch-wofi.sh:scripts/runtime/launch-wofi.sh"
    "start-swaync.sh:scripts/runtime/start-swaync.sh"
    "lock-session.sh:scripts/runtime/lock-session.sh"
    "launch-foot.sh:scripts/runtime/launch-foot.sh"
    "apply-wallpaper.sh:scripts/runtime/apply-wallpaper.sh"
    "jc-theme:scripts/theme.sh"
)

for specification in "${runtime_links[@]}"; do

    name="${specification%%:*}"
    relative="${specification#*:}"

    link="$bin_dir/$name"
    expected="$repo_root/$relative"

    if [[ ! -L "$link" ]]; then
        fail "missing runtime symlink: $link"
        continue
    fi

    actual="$(readlink -f "$link")"
    expected="$(readlink -f "$expected")"

    if [[ "$actual" == "$expected" ]]; then
        ok "$name"
    else
        fail "$name points to unexpected target: $actual"
    fi

done


# ==============================================================================
# Notification daemon
# ==============================================================================

section "Notification daemon"

mako_running=false
swaync_running=false

pgrep -x mako >/dev/null 2>&1 && mako_running=true
pgrep -x swaync >/dev/null 2>&1 && swaync_running=true


if [[ "$mako_running" == true && "$swaync_running" == true ]]; then

    fail "Mako and SwayNC are running simultaneously"

elif [[ "$swaync_running" == true ]]; then

    ok "SwayNC running"

elif [[ "$mako_running" == true ]]; then

    warn "Mako running; Odyssey runtime expects SwayNC"

else
    warn "no notification daemon detected"
fi


# ==============================================================================
# Wallpaper daemon
# ==============================================================================

section "Wallpaper daemon"

wpaperd_running=false
hyprpaper_running=false

pgrep -x wpaperd >/dev/null 2>&1 && wpaperd_running=true
pgrep -x hyprpaper >/dev/null 2>&1 && hyprpaper_running=true


if [[ "$wpaperd_running" == true && "$hyprpaper_running" == true ]]; then

    fail "wpaperd and hyprpaper are running simultaneously"

elif [[ "$hyprpaper_running" == true ]]; then

    ok "hyprpaper running"

    active_wallpapers="$(
        hyprctl hyprpaper listactive 2>/dev/null ||
            true
    )"

    if [[ -n "$active_wallpapers" ]]; then
        printf '%s\n' "$active_wallpapers" |
            sed 's/^/      /'
    else
        warn "hyprpaper has no active wallpaper information"
    fi

elif [[ "$wpaperd_running" == true ]]; then

    warn "wpaperd running; jc-hyprland-dotfiles expects hyprpaper"

else
    warn "no wallpaper daemon detected"
fi


# ==============================================================================
# Summary
# ==============================================================================

printf '\nDoctor summary: %d error(s), %d warning(s)\n' \
    "$errors" \
    "$warnings"


if ((errors > 0)); then
    exit 1
fi