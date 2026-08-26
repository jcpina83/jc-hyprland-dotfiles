#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Clean installation simulation
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

test_home="$(mktemp -d)"
install_output="$(mktemp)"

errors=0


cleanup() {
    rm -rf "$test_home"
    rm -f "$install_output"
}


ok() {
    printf 'OK    %s\n' "$*"
}


fail() {
    printf 'FAIL  %s\n' "$*" >&2
    ((errors += 1))
}


trap cleanup EXIT


# ==============================================================================
# Repository sources
# ==============================================================================

printf '==> Clean-install source validation\n'

quickshell_config="$repo_root/config/quickshell/jc-hyprland"
persistence_ui_service="$quickshell_config/services/DisplayPersistenceService.qml"
quickshell_launcher="$repo_root/scripts/runtime/start-quickshell.sh"
control_center_wrapper="$repo_root/scripts/runtime/jc-control-center.sh"
display_controller="$repo_root/scripts/runtime/jc-displayctl.sh"
display_configurator="$repo_root/scripts/runtime/jc-displaycfg.sh"
hypr_lua_source="$repo_root/config/hypr/lua"
monitor_template="$repo_root/hosts/example/monitors.lua"

if [[ -r "$quickshell_config/shell.qml" ]]; then
    ok "Quickshell config source"
else
    fail "missing Quickshell config source: $quickshell_config/shell.qml"
fi

if [[ -r "$persistence_ui_service" ]]; then
    ok "Display persistence UI service source"
else
    fail "missing display persistence UI service: $persistence_ui_service"
fi

if [[ -x "$quickshell_launcher" ]]; then
    ok "Quickshell launcher source"
else
    fail "missing or non-executable launcher: $quickshell_launcher"
fi

if [[ -x "$control_center_wrapper" ]]; then
    ok "Control Center wrapper source"
else
    fail "missing or non-executable wrapper: $control_center_wrapper"
fi

if [[ -x "$display_controller" ]]; then
    ok "Display controller source"
else
    fail "missing or non-executable controller: $display_controller"
fi

if [[ -x "$display_configurator" ]]; then
    ok "Display persistence source"
else
    fail "missing or non-executable persistence backend: $display_configurator"
fi

if [[ -r "$hypr_lua_source/init.lua" ]]; then
    ok "Hyprland Lua module source"
else
    fail "missing Hyprland Lua module: $hypr_lua_source/init.lua"
fi

if [[ -r "$monitor_template" ]]; then
    ok "Lua monitor template"
else
    fail "missing Lua monitor template: $monitor_template"
fi


# ==============================================================================
# Installer dry run in an isolated HOME
# ==============================================================================

printf '\n==> Clean HOME installation simulation\n'
printf 'Temporary HOME: %s\n' "$test_home"

if HOME="$test_home" \
    XDG_CONFIG_HOME="$test_home/.config" \
    "$repo_root/scripts/install.sh" --dry-run |
    tee "$install_output"
then
    ok "installer dry run"
else
    fail "installer dry run failed"
fi


# ==============================================================================
# Expected Quickshell installation plan
# ==============================================================================

printf '\n==> Quickshell installation plan\n'

expected_targets=(
    "$test_home/.config/quickshell/jc-hyprland"
    "$test_home/.config/jc-hyprland-dotfiles/bin/start-quickshell.sh"
    "$test_home/.config/jc-hyprland-dotfiles/bin/jc-control-center"
    "$test_home/.config/jc-hyprland-dotfiles/bin/jc-displayctl"
    "$test_home/.config/jc-hyprland-dotfiles/bin/jc-displaycfg"
    "$test_home/.config/jc-hyprland-dotfiles/local/monitors.lua"
    "$test_home/.config/hypr/jc-dotfiles"
)

for target in "${expected_targets[@]}"; do

    if grep -Fq -- "$target" "$install_output"; then
        ok "planned: $target"
    else
        fail "installer dry run does not include: $target"
    fi

done


# ==============================================================================
# Dry-run safety
# ==============================================================================

printf '\n==> Dry-run safety\n'

unexpected_links=(
    "$test_home/.config/quickshell/jc-hyprland"
    "$test_home/.config/jc-hyprland-dotfiles/bin/start-quickshell.sh"
    "$test_home/.config/jc-hyprland-dotfiles/bin/jc-control-center"
    "$test_home/.config/jc-hyprland-dotfiles/bin/jc-displayctl"
    "$test_home/.config/jc-hyprland-dotfiles/bin/jc-displaycfg"
    "$test_home/.config/jc-hyprland-dotfiles/local/monitors.lua"
    "$test_home/.config/hypr/jc-dotfiles"
)

for target in "${unexpected_links[@]}"; do

    if [[ -L "$target" ]]; then
        fail "dry run unexpectedly created symlink: $target"
    else
        ok "not created during dry run: $target"
    fi

done


# ==============================================================================
# Summary
# ==============================================================================

printf '\nClean-install summary: %d error(s)\n' "$errors"

if ((errors > 0)); then
    exit 1
fi

printf 'Clean-install simulation passed.\n'
