#!/usr/bin/env bash
set -uo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

config_dir="$repo_root/config/quickshell/jc-hyprland"
control_center_wrapper="$repo_root/scripts/runtime/jc-control-center.sh"
quickshell_launcher="$repo_root/scripts/runtime/start-quickshell.sh"
hypr_autostart="$repo_root/config/hypr/lua/autostart.lua"
hypr_keybindings="$repo_root/config/hypr/lua/keybindings.lua"
waybar_main="$repo_root/config/waybar/templates/config-main.jsonc"
waybar_secondary="$repo_root/config/waybar/templates/config-secondary.jsonc"
errors=0


ok() {
    printf '  OK    %s\n' "$*"
}


fail() {
    printf '  FAIL  %s\n' "$*" >&2
    ((errors += 1))
}


printf '==> Quickshell structure\n'

required_files=(
    "shell.qml"
    "Main.qml"
    "theme/Theme.qml"
    "components/JcButton.qml"
    "components/JcCard.qml"
    "components/JcChoiceGroup.qml"
    "services/MonitorService.qml"
    "services/MonitorModeParser.qml"
    "services/DisplayDraftStore.qml"
    "services/MonitorApplyService.qml"
    "services/DisplayPersistenceService.qml"
    "modules/displays/DisplayPopup.qml"
    "modules/displays/DisplayLayout.qml"
    "modules/displays/DisplayLayoutEditor.qml"
    "modules/displays/DisplayCard.qml"
)

if [[ ! -d "$config_dir" ]]; then
    fail "configuration directory missing: $config_dir"
else
    ok "configuration directory"
fi

for relative in "${required_files[@]}"; do
    if [[ -r "$config_dir/$relative" ]]; then
        ok "$relative"
    else
        fail "missing or unreadable: $relative"
    fi
done


printf '\n==> QML JavaScript compatibility\n'

spread_matches="$(
    grep -RInF \
        --include='*.qml' \
        '...' \
        "$config_dir" \
        2>/dev/null ||
        true
)"

if [[ -z "$spread_matches" ]]; then
    ok "no spread/rest syntax in QML JavaScript"
else
    fail "spread/rest syntax is not allowed in project QML:"
    printf '%s\n' "$spread_matches" >&2
fi


printf '\n==> Display runtime backend\n'

display_controller="$repo_root/scripts/runtime/jc-displayctl.sh"

if [[ -x "$display_controller" ]]; then
    ok "jc-displayctl.sh executable"
else
    fail "missing or non-executable display controller"
fi

for backend_contract in \
    'hyprctl -r eval' \
    'hyprctl -j monitors all' \
    'safe-apply)' \
    'rollback)' \
    '--enabled' \
    'disabled = true' \
    'disabled = false' \
    'validate_disable_guard' \
    'refusing to disable the last active monitor' \
    'refusing to disable focused output' \
    'rollback-enabled' \
    'target-enabled' \
    'systemd-run' \
    'HYPRLAND_INSTANCE_SIGNATURE' \
    'write_watchdog_environment' \
    'restore_watchdog_environment' \
    '--setenv=HYPRLAND_INSTANCE_SIGNATURE=' \
    '--setenv=XDG_RUNTIME_DIR='
do
    if grep -Fq -- "$backend_contract" "$display_controller" 2>/dev/null; then
        ok "backend contract: $backend_contract"
    else
        fail "display backend contract missing: $backend_contract"
    fi
done

if grep -Fq "description_selector=\"desc:\$description\"" \
    "$display_controller" 2>/dev/null
then
    ok "desc:<description> persistent selector support"
else
    fail "display controller does not support desc:<description> rules"
fi


printf '\n==> Display persistence backend\n'

display_configurator="$repo_root/scripts/runtime/jc-displaycfg.sh"

if [[ -x "$display_configurator" ]]; then
    ok "jc-displaycfg.sh executable"
else
    fail "missing or non-executable display persistence backend"
fi

for persistence_contract in \
    'preview)' \
    'save)' \
    'backups)' \
    'restore-last)' \
    'JC_MONITORS_LUA' \
    'hyprctl -j monitors all' \
    'hyprctl reload' \
    'hyprctl configerrors' \
    'candidate.XXXXXX' \
    "mv -f -- \"\$candidate_for_replace\" \"\$monitors_lua\"" \
    'backup_current_file' \
    'rewrite_monitor_block' \
    'mask_monitor_blocks' \
    'validate_candidate_structure' \
    'verify_runtime_matches_snapshot' \
    'verify_runtime_snapshot_once' \
    'runtime_snapshot_diagnostics' \
    'max_attempts=40' \
    'delay_seconds=0.10' \
    'disabled = true' \
    'workspace rules or other'
do
    if grep -Fq "$persistence_contract" "$display_configurator" 2>/dev/null; then
        ok "persistence contract: $persistence_contract"
    else
        fail "display persistence contract missing: $persistence_contract"
    fi
done

printf '\n==> Display enable/disable draft contract\n'

draft_store="$config_dir/services/DisplayDraftStore.qml"

for draft_contract in \
    'readonly property int activeDraftCount:' \
    'enabled: !monitor.disabled' \
    'function canDisable' \
    'function enableDisableReason' \
    'function setEnabled' \
    'At least one display must remain active.' \
    'Focus another display before disabling this one.'
do
    if grep -Fq "$draft_contract" "$draft_store" 2>/dev/null; then
        ok "$draft_contract"
    else
        fail "DisplayDraftStore enable/disable contract missing: $draft_contract"
    fi
done


printf '\n==> Display card enable/disable contract\n'

display_card="$config_dir/modules/displays/DisplayCard.qml"

for card_contract in \
    'Disable' \
    'Enable' \
    'Disable pending' \
    'Enable pending' \
    'root.draftStore.canDisable' \
    'root.draftStore.setEnabled'
do
    if grep -Fq "$card_contract" "$display_card" 2>/dev/null; then
        ok "$card_contract"
    else
        fail "DisplayCard enable/disable contract missing: $card_contract"
    fi
done


printf '\n==> Safe Apply enable/disable contract\n'

apply_service="$config_dir/services/MonitorApplyService.qml"

for apply_contract in \
    'const targetEnabled = Boolean(draft.enabled);' \
    'root.draftStore.activeDraftCount < 1' \
    'root.monitorService.focusedOutputName === draft.output' \
    '"--enabled"' \
    'draft.enabled ? "true" : "false"'
do
    if grep -Fq "$apply_contract" "$apply_service" 2>/dev/null; then
        ok "$apply_contract"
    else
        fail "MonitorApplyService enable/disable contract missing: $apply_contract"
    fi
done


printf '\n==> Phase 1C.3 persistence UI contract\n'

persistence_service="$config_dir/services/DisplayPersistenceService.qml"
display_popup="$config_dir/modules/displays/DisplayPopup.qml"
main_qml="$config_dir/Main.qml"

for persistence_ui_contract in \
    'property bool checking: false' \
    'property bool saving: false' \
    'property bool previewKnown: false' \
    'property bool hasPersistentChanges: false' \
    'readonly property bool canSave:' \
    'function refreshPreview()' \
    'function saveConfiguration(): void' \
    '"preview"' \
    '"save"' \
    'root.applyService.pendingConfirmation' \
    'root.draftStore.hasDirty' \
    'preflightProcess' \
    'root.displayctlPath()' \
    'response.status !== "idle"'
do
    if grep -Fq "$persistence_ui_contract" "$persistence_service" 2>/dev/null; then
        ok "$persistence_ui_contract"
    else
        fail "DisplayPersistenceService contract missing: $persistence_ui_contract"
    fi
done

for persistence_popup_contract in \
    'property var persistenceService' \
    'signal saveRequested()' \
    'Save Configuration' \
    'root.persistenceService.canSave'
do
    if grep -Fq "$persistence_popup_contract" "$display_popup" 2>/dev/null; then
        ok "$persistence_popup_contract"
    else
        fail "DisplayPopup persistence contract missing: $persistence_popup_contract"
    fi
done

for persistence_main_contract in \
    'Services.DisplayPersistenceService {' \
    'persistenceService: displayPersistenceService' \
    'onSaveRequested: displayPersistenceService.saveConfiguration()' \
    'onKept: displayPersistenceService.refreshPreview()' \
    'onRolledBack: displayPersistenceService.refreshPreview()'
do
    if grep -Fq "$persistence_main_contract" "$main_qml" 2>/dev/null; then
        ok "$persistence_main_contract"
    else
        fail "Main persistence orchestration contract missing: $persistence_main_contract"
    fi
done

printf '\n==> Phase 1B.6 safety\n'

monitor_service="$config_dir/services/MonitorService.qml"

if grep -Fq '"hyprctl", "-j", "monitors", "all"' \
    "$monitor_service" 2>/dev/null
then
    ok "disabled outputs remain discoverable through monitors all"
else
    fail "MonitorService must query monitors all"
fi

mutation_matches="$(
    grep -RInE \
        --include='*.qml' \
        'hyprctl[^\n]*(eval|keyword[[:space:]]+monitor)|hl\.monitor[[:space:]]*\(' \
        "$config_dir" \
        2>/dev/null ||
        true
)"

if [[ -z "$mutation_matches" ]]; then
    ok "QML contains no direct Hyprland monitor mutation"
else
    fail "QML must delegate monitor mutation to jc-displayctl:"
    printf '%s\n' "$mutation_matches" >&2
fi

ui_shell_matches="$(
    grep -RInE \
        --include='*.qml' \
        'hyprctl|Process[[:space:]]*\{' \
        "$config_dir/modules" \
        "$config_dir/components" \
        2>/dev/null ||
        true
)"

if [[ -z "$ui_shell_matches" ]]; then
    ok "display UI contains no shell/process commands"
else
    fail "UI layer must not execute shell/process commands:"
    printf '%s\n' "$ui_shell_matches" >&2
fi

if grep -Fq 'systemd-run' "$display_controller" \
    && grep -Fq "rollback --token \"\$token\"" "$display_controller"
then
    ok "external rollback watchdog preserved"
else
    fail "Safe Apply watchdog contract missing"
fi


printf '\n==> Phase 1D session integration\n'

for integration_file in \
    "$control_center_wrapper" \
    "$quickshell_launcher" \
    "$hypr_autostart" \
    "$hypr_keybindings" \
    "$waybar_main" \
    "$waybar_secondary"
do
    if [[ -r "$integration_file" ]]; then
        ok "integration source: ${integration_file#"$repo_root"/}"
    else
        fail "missing integration source: ${integration_file#"$repo_root"/}"
    fi
done

if grep -Fq 'start-quickshell.sh' "$hypr_autostart" 2>/dev/null; then
    ok "Hyprland Lua owns Quickshell session startup"
else
    fail "Hyprland autostart must launch start-quickshell.sh"
fi

if grep -Fq 'ipc show' "$quickshell_launcher" 2>/dev/null; then
    ok "Quickshell launcher has idempotent IPC probe"
else
    fail "Quickshell launcher must probe the named IPC instance"
fi

if grep -Fq '"SUPER + C"' "$hypr_keybindings" 2>/dev/null \
    && grep -Fq 'control_center .. " toggle"' "$hypr_keybindings" 2>/dev/null
then
    ok "SUPER+C uses the stable Control Center wrapper"
else
    fail "Hyprland Control Center keybind contract missing"
fi

for ipc_contract in \
    'property string requestedOutputName:' \
    'function showDisplaysOn(outputName: string): void' \
    'function toggleDisplaysOn(outputName: string): void'
do
    if grep -Fq "$ipc_contract" "$main_qml" 2>/dev/null; then
        ok "targeted IPC: $ipc_contract"
    else
        fail "targeted Control Center IPC contract missing: $ipc_contract"
    fi
done

for wrapper_contract in \
    'show-on)' \
    'toggle-on)' \
    "showDisplaysOn \"\$output\"" \
    "toggleDisplaysOn \"\$output\""
do
    if grep -Fq "$wrapper_contract" "$control_center_wrapper" 2>/dev/null; then
        ok "wrapper targeting: $wrapper_contract"
    else
        fail "Control Center wrapper targeting missing: $wrapper_contract"
    fi
done

if grep -Fq '"custom/control-center"' "$waybar_main" \
    && grep -Fq 'jc-control-center toggle-on @MAIN_OUTPUT@' "$waybar_main"
then
    ok "main Waybar targets MAIN_OUTPUT"
else
    fail "main Waybar Control Center integration missing"
fi

if grep -Fq '"custom/control-center"' "$waybar_secondary" \
    && grep -Fq 'jc-control-center toggle-on @SECONDARY_OUTPUT@' "$waybar_secondary"
then
    ok "secondary Waybar targets SECONDARY_OUTPUT"
else
    fail "secondary Waybar Control Center integration missing"
fi


printf '\n==> PanelWindow dimensions\n'

display_popup="$config_dir/modules/displays/DisplayPopup.qml"

if grep -Eq '^[[:space:]]{4}implicitWidth:[[:space:]]*[0-9]+' \
    "$display_popup" 2>/dev/null &&
   grep -Eq '^[[:space:]]{4}implicitHeight:[[:space:]]*[0-9]+' \
    "$display_popup" 2>/dev/null
then
    ok "PanelWindow uses implicitWidth / implicitHeight"
else
    fail "DisplayPopup must use implicit dimensions"
fi


printf '\nQuickshell validation summary: %d error(s)\n' "$errors"

if ((errors > 0)); then
    exit 1
fi

printf 'Quickshell static checks passed.\n'
