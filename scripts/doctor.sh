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

quickshell_config="$config_home/quickshell/jc-hyprland"
quickshell_config_expected="$repo_root/config/quickshell/jc-hyprland"

host_env="$local_dir/host.env"
monitors_lua="$local_dir/monitors.lua"
wallpaper_env="$local_dir/wallpaper.env"

hypr_dir="$config_home/hypr"
hypr_lua_module="$hypr_dir/jc-dotfiles"
hypr_lua_expected="$repo_root/config/hypr/lua"
hyprland_lua="$hypr_dir/hyprland.lua"

systemd_user_dir="$config_home/systemd/user"

wallpaper_rotation_service="$systemd_user_dir/jc-wallpaper-rotation.service"
wallpaper_rotation_timer="$systemd_user_dir/jc-wallpaper-rotation.timer"
wallpaper_rotation_dropin="$systemd_user_dir/jc-wallpaper-rotation.timer.d/interval.conf"

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
    hypridle
    awww
    awww-daemon
    swaync
    swaync-client
    qs
    systemctl
    systemd-run
    jq
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
# Hyprland Lua integration
# ==============================================================================

section "Hyprland Lua integration"

if [[ -r "$monitors_lua" ]]; then
    ok "$monitors_lua"
else
    fail "machine-local Lua monitor configuration missing: $monitors_lua"
fi

if [[ -L "$hypr_lua_module" ]]; then
    hypr_lua_actual="$(readlink -f "$hypr_lua_module" 2>/dev/null || true)"
    hypr_lua_expected_real="$(readlink -f "$hypr_lua_expected" 2>/dev/null || true)"

    if [[ "$hypr_lua_actual" == "$hypr_lua_expected_real" ]]; then
        ok "Hyprland jc-dotfiles Lua module"
    else
        fail "Hyprland Lua module points to unexpected target: $hypr_lua_actual"
    fi
elif [[ -e "$hypr_lua_module" ]]; then
    fail "Hyprland Lua module exists but is not a symlink: $hypr_lua_module"
else
    fail "Hyprland Lua module missing: $hypr_lua_module"
fi

if [[ -r "$hyprland_lua" ]]     && grep -Fqx 'require("jc-dotfiles/init")' "$hyprland_lua"
then
    ok "hyprland.lua loads jc-dotfiles/init"
else
    fail "hyprland.lua does not load jc-dotfiles/init"
fi

# ==============================================================================
# Quickshell
# ==============================================================================

section "Quickshell"

if command -v qs >/dev/null 2>&1; then

    quickshell_version="$(qs --version 2>/dev/null | head -1 || true)"

    if [[ -n "$quickshell_version" ]]; then
        ok "$quickshell_version"
    else
        warn "unable to read Quickshell version"
    fi

else
    fail "qs unavailable"
fi


if [[ -L "$quickshell_config" ]]; then

    quickshell_actual="$(readlink -f "$quickshell_config" 2>/dev/null || true)"
    quickshell_expected="$(readlink -f "$quickshell_config_expected" 2>/dev/null || true)"

    if [[ "$quickshell_actual" == "$quickshell_expected" ]]; then
        ok "jc-hyprland config symlink"
    else
        fail "Quickshell config points to unexpected target: $quickshell_actual"
    fi

elif [[ -e "$quickshell_config" ]]; then

    fail "Quickshell config exists but is not a symlink: $quickshell_config"

else

    fail "Quickshell config missing: $quickshell_config"

fi


quickshell_required_files=(
    "shell.qml"
    "Main.qml"
    "services/MonitorService.qml"
    "modules/displays/DisplayPopup.qml"
)

for relative in "${quickshell_required_files[@]}"; do

    if [[ -r "$quickshell_config/$relative" ]]; then
        ok "quickshell/$relative"
    else
        fail "missing Quickshell runtime file: $relative"
    fi

done


if command -v qs >/dev/null 2>&1; then

    if qs -c jc-hyprland ipc show >/dev/null 2>&1; then
        ok "Quickshell IPC responsive"
    else
        warn "Quickshell shell is not running or IPC is unavailable"
    fi

fi


# ==============================================================================
# Runtime links
# ==============================================================================

section "Runtime links"

runtime_links=(
    "start-waybar.sh:scripts/runtime/start-waybar.sh"
    "start-quickshell.sh:scripts/runtime/start-quickshell.sh"
    "jc-control-center:scripts/runtime/jc-control-center.sh"
    "jc-displayctl:scripts/runtime/jc-displayctl.sh"
    "jc-displaycfg:scripts/runtime/jc-displaycfg.sh"
    "network-traffic.sh:scripts/runtime/network-traffic.sh"
    "amd-gpu.sh:scripts/runtime/amd-gpu.sh"
    "launch-wofi.sh:scripts/runtime/launch-wofi.sh"
    "select-theme.sh:scripts/runtime/select-theme.sh"
    "select-wallpaper.sh:scripts/runtime/select-wallpaper.sh"
    "start-swaync.sh:scripts/runtime/start-swaync.sh"
    "lock-session.sh:scripts/runtime/lock-session.sh"
    "suspend-session.sh:scripts/runtime/suspend-session.sh"
    "launch-foot.sh:scripts/runtime/launch-foot.sh"
    "apply-wallpaper.sh:scripts/runtime/apply-wallpaper.sh"
    "wallpaper-manager.sh:scripts/runtime/wallpaper-manager.sh"
    "rotate-wallpaper.sh:scripts/runtime/rotate-wallpaper.sh"
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
# Wallpaper rotation
# ==============================================================================

section "Wallpaper rotation"

rotation_service_expected="$repo_root/config/systemd/user/jc-wallpaper-rotation.service"
rotation_timer_expected="$repo_root/config/systemd/user/jc-wallpaper-rotation.timer"


# ------------------------------------------------------------------------------
# Local configuration
# ------------------------------------------------------------------------------

if [[ -r "$wallpaper_env" ]]; then

    ok "$wallpaper_env"

    WALLPAPER_ROTATION_ENABLED=false
    WALLPAPER_ROTATION_MODE=next
    WALLPAPER_ROTATION_TARGET=both
    WALLPAPER_ROTATION_INTERVAL=30m

    # Machine-local configuration.
    # shellcheck disable=SC1090
    source "$wallpaper_env"

    case "${WALLPAPER_ROTATION_ENABLED:-}" in
        true|false)
            ok "WALLPAPER_ROTATION_ENABLED=$WALLPAPER_ROTATION_ENABLED"
            ;;
        *)
            fail \
                "invalid WALLPAPER_ROTATION_ENABLED: " \
                "${WALLPAPER_ROTATION_ENABLED:-<unset>}"
            ;;
    esac

    case "${WALLPAPER_ROTATION_MODE:-}" in
        next|random)
            ok "WALLPAPER_ROTATION_MODE=$WALLPAPER_ROTATION_MODE"
            ;;
        *)
            fail \
                "invalid WALLPAPER_ROTATION_MODE: " \
                "${WALLPAPER_ROTATION_MODE:-<unset>}"
            ;;
    esac

    case "${WALLPAPER_ROTATION_TARGET:-}" in
        main|secondary|both)
            ok "WALLPAPER_ROTATION_TARGET=$WALLPAPER_ROTATION_TARGET"
            ;;
        *)
            fail \
                "invalid WALLPAPER_ROTATION_TARGET: " \
                "${WALLPAPER_ROTATION_TARGET:-<unset>}"
            ;;
    esac

    if command -v systemd-analyze >/dev/null 2>&1 &&
        systemd-analyze timespan \
            "${WALLPAPER_ROTATION_INTERVAL:-}" \
            >/dev/null 2>&1
    then
        ok "WALLPAPER_ROTATION_INTERVAL=$WALLPAPER_ROTATION_INTERVAL"
    else
        fail \
            "invalid WALLPAPER_ROTATION_INTERVAL: " \
            "${WALLPAPER_ROTATION_INTERVAL:-<unset>}"
    fi

else
    fail "wallpaper configuration missing: $wallpaper_env"
fi


# ------------------------------------------------------------------------------
# systemd user unit links
# ------------------------------------------------------------------------------

for specification in \
    "$wallpaper_rotation_service:$rotation_service_expected" \
    "$wallpaper_rotation_timer:$rotation_timer_expected"
do
    link="${specification%%:*}"
    expected="${specification#*:}"

    if [[ ! -L "$link" ]]; then
        fail "missing systemd user symlink: $link"
        continue
    fi

    actual="$(readlink -f "$link" 2>/dev/null || true)"
    expected="$(readlink -f "$expected" 2>/dev/null || true)"

    if [[ "$actual" == "$expected" ]]; then
        ok "$(basename "$link")"
    else
        fail "$(basename "$link") points to unexpected target: $actual"
    fi
done


# ------------------------------------------------------------------------------
# Generated interval drop-in
# ------------------------------------------------------------------------------

if [[ -r "$wallpaper_rotation_dropin" ]]; then

    ok "timer drop-in: $wallpaper_rotation_dropin"

    if grep -Fqx \
        "OnActiveSec=${WALLPAPER_ROTATION_INTERVAL:-}" \
        "$wallpaper_rotation_dropin" &&
        grep -Fqx \
            "OnUnitActiveSec=${WALLPAPER_ROTATION_INTERVAL:-}" \
            "$wallpaper_rotation_dropin"
    then
        ok "timer interval synchronized"
    else
        fail "timer drop-in does not match wallpaper.env interval"
    fi

else
    fail "wallpaper rotation timer drop-in missing: $wallpaper_rotation_dropin"
fi


# ------------------------------------------------------------------------------
# systemd lifecycle
# ------------------------------------------------------------------------------

if command -v systemctl >/dev/null 2>&1; then

    timer_enabled="$(
        systemctl --user is-enabled \
            jc-wallpaper-rotation.timer \
            2>/dev/null ||
            true
    )"

    timer_active="$(
        systemctl --user is-active \
            jc-wallpaper-rotation.timer \
            2>/dev/null ||
            true
    )"

    if [[ "${WALLPAPER_ROTATION_ENABLED:-false}" == true ]]; then

        if [[ "$timer_enabled" == enabled ]]; then
            ok "wallpaper rotation timer enabled"
        else
            fail \
                "wallpaper rotation expected enabled; " \
                "systemd state: $timer_enabled"
        fi

        if [[ "$timer_active" == active ]]; then
            ok "wallpaper rotation timer active"
        else
            fail \
                "wallpaper rotation expected active; " \
                "systemd state: $timer_active"
        fi

    else

        if [[ "$timer_enabled" == linked ]]; then
            ok "wallpaper rotation timer linked but disabled"
        else
            fail \
                "wallpaper rotation expected linked; " \
                "systemd state: $timer_enabled"
        fi

        if [[ "$timer_active" == inactive ]]; then
            ok "wallpaper rotation timer inactive"
        else
            fail \
                "wallpaper rotation expected inactive; " \
                "systemd state: $timer_active"
        fi

    fi

else
    fail "systemctl unavailable"
fi

# ==============================================================================
# Session lock
# ==============================================================================

printf '\n==> Session lock\n'

hypridle_conf="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hypridle.conf"

lock_wrapper="$HOME/.config/jc-hyprland-dotfiles/bin/lock-session.sh"


if [[ -x "$lock_wrapper" ]]; then
    ok "lock-session.sh wrapper"
else
    fail "lock-session.sh wrapper missing or not executable"
fi


if [[ -r "$hypridle_conf" ]]; then

    ok "$hypridle_conf"

    if grep -Fq \
        'jc-hyprland-dotfiles/bin/lock-session.sh' \
        "$hypridle_conf"; then

        ok "Hypridle uses jc lock-session.sh"

    else

        fail "Hypridle does not use jc lock-session.sh"

    fi

else

    fail "Hypridle configuration missing: $hypridle_conf"

fi


if pgrep -x hypridle >/dev/null 2>&1; then
    ok "Hypridle running"
else
    warn "Hypridle not running"
fi

nwgbar_config="$HOME/.config/nwg-launchers/nwgbar/bar.json"

if [[ -r "$nwgbar_config" ]]; then

    if grep -Fq \
        'jc-hyprland-dotfiles/bin/lock-session.sh' \
        "$nwgbar_config"; then

        ok "nwgbar Lock uses jc lock-session.sh"

    else

        warn "nwgbar exists but Lock does not use jc lock-session.sh"

    fi


    if grep -Fq \
        'jc-hyprland-dotfiles/bin/suspend-session.sh' \
        "$nwgbar_config"; then

        ok "nwgbar Suspend uses jc suspend-session.sh"

    else

        warn "nwgbar exists but Suspend does not use jc suspend-session.sh"

    fi


    if grep -Fq \
        '"exec": "uwsm stop"' \
        "$nwgbar_config"; then

        ok "nwgbar Logout uses uwsm stop"

    else

        warn "nwgbar exists but Logout does not use uwsm stop"

    fi

fi

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

awww_running=false
hyprpaper_running=false
wpaperd_running=false
swww_running=false
swaybg_running=false
mpvpaper_running=false


pgrep -x awww-daemon >/dev/null 2>&1 && awww_running=true
pgrep -x hyprpaper >/dev/null 2>&1 && hyprpaper_running=true
pgrep -x wpaperd >/dev/null 2>&1 && wpaperd_running=true
pgrep -x swww-daemon >/dev/null 2>&1 && swww_running=true
pgrep -x swaybg >/dev/null 2>&1 && swaybg_running=true
pgrep -x mpvpaper >/dev/null 2>&1 && mpvpaper_running=true


running_count=0

for running in \
    "$awww_running" \
    "$hyprpaper_running" \
    "$wpaperd_running" \
    "$swww_running" \
    "$swaybg_running" \
    "$mpvpaper_running"
do
    if [[ "$running" == true ]]; then
        ((running_count += 1))
    fi
done


if (( running_count > 1 )); then

    fail "multiple wallpaper daemons are running simultaneously"

    [[ "$awww_running" == true ]] \
        && printf '      awww-daemon\n'

    [[ "$hyprpaper_running" == true ]] \
        && printf '      hyprpaper\n'

    [[ "$wpaperd_running" == true ]] \
        && printf '      wpaperd\n'

    [[ "$swww_running" == true ]] \
        && printf '      swww-daemon\n'

    [[ "$swaybg_running" == true ]] \
        && printf '      swaybg\n'

    [[ "$mpvpaper_running" == true ]] \
        && printf '      mpvpaper\n'


elif [[ "$awww_running" == true ]]; then

    ok "awww-daemon running"

    active_wallpapers="$(
        awww query 2>/dev/null ||
            true
    )"

    if [[ -n "$active_wallpapers" ]]; then
        printf '%s\n' "$active_wallpapers" |
            sed 's/^/      /'
    else
        warn "awww has no active wallpaper information"
    fi

    if command -v hyprpaper >/dev/null 2>&1; then
        ok "hyprpaper fallback available"
    else
        warn "hyprpaper fallback is not installed"
    fi


elif [[ "$hyprpaper_running" == true ]]; then

    warn "hyprpaper fallback active; awww is the preferred backend"

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

    warn "wpaperd running; jc-hyprland-dotfiles expects awww"


elif [[ "$swww_running" == true ]]; then

    warn "swww-daemon running; jc-hyprland-dotfiles expects awww"


elif [[ "$swaybg_running" == true ]]; then

    warn "swaybg running; jc-hyprland-dotfiles expects awww"


elif [[ "$mpvpaper_running" == true ]]; then

    warn "mpvpaper running; jc-hyprland-dotfiles expects awww"


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