#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Quickshell static validation
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

config_dir="$repo_root/config/quickshell/jc-hyprland"

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
    "modules/displays/DisplayPopup.qml"
    "modules/displays/DisplayLayout.qml"
    "modules/displays/DisplayCard.qml"
)

if [[ ! -d "$config_dir" ]]; then
    fail "configuration directory missing: $config_dir"
else
    ok "configuration directory"
fi

for relative in "${required_files[@]}"; do
    file="$config_dir/$relative"

    if [[ -r "$file" ]]; then
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
    'local/monitors.conf' \
    'safe-apply)' \
    'keep)' \
    'rollback)' \
    'status)' \
    'systemd-run' \
    'XDG_RUNTIME_DIR' \
    'rollback.lua'
do
    if grep -Fq "$backend_contract" "$display_controller" 2>/dev/null; then
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

if grep -Fq "lua_quote \"\$configured_selector\"" \
    "$display_controller" 2>/dev/null
then
    ok "persistent monitor selector preserved during apply"
else
    fail "runtime apply does not preserve persistent monitor selector"
fi


printf '\n==> Quickshell identity and IPC contract\n'

if grep -Fqx '//@ pragma ShellId jc-hyprland' \
    "$config_dir/shell.qml" 2>/dev/null
then
    ok "stable ShellId: jc-hyprland"
else
    fail "shell.qml must declare: //@ pragma ShellId jc-hyprland"
fi

if grep -Fq 'target: "controlCenter"' \
    "$config_dir/Main.qml" 2>/dev/null
then
    ok "IPC target: controlCenter"
else
    fail "Main.qml does not expose IPC target controlCenter"
fi

for ipc_method in \
    showDisplays \
    hideDisplays \
    toggleDisplays \
    refreshDisplays \
    displaysAreVisible
do
    if grep -Fq "function $ipc_method" \
        "$config_dir/Main.qml" 2>/dev/null
    then
        ok "IPC method: $ipc_method"
    else
        fail "missing IPC method: $ipc_method"
    fi
done


printf '\n==> Monitor service contract\n'

monitor_service="$config_dir/services/MonitorService.qml"

if grep -Fq '"hyprctl", "-j", "monitors", "all"' \
    "$monitor_service" 2>/dev/null
then
    ok "read-only monitor discovery command"
else
    fail "MonitorService.qml discovery command changed unexpectedly"
fi

if grep -Fq 'availableModes' "$monitor_service" 2>/dev/null; then
    ok "availableModes captured"
else
    fail "MonitorService.qml does not expose availableModes"
fi


printf '\n==> Display draft contract\n'

draft_store="$config_dir/services/DisplayDraftStore.qml"

for draft_contract in \
    'property var drafts:' \
    'readonly property bool hasDirty:' \
    'function dirtyDrafts()' \
    'function prepareForRefreshAfterApply()' \
    'function setResolution' \
    'function setRefreshMode'
do
    if grep -Fq "$draft_contract" "$draft_store" 2>/dev/null; then
        ok "$draft_contract"
    else
        fail "DisplayDraftStore contract missing: $draft_contract"
    fi
done


printf '\n==> Safe Apply service contract\n'

apply_service="$config_dir/services/MonitorApplyService.qml"

for apply_contract in \
    'property int confirmationTimeoutSeconds: 15' \
    'property bool pendingConfirmation: false' \
    'function applyDirty(): void' \
    'function keepPending(): void' \
    'function rollbackPending(reason): void' \
    'function recoverPending()' \
    '"safe-apply"' \
    '"keep"' \
    '"rollback"' \
    '"status"' \
    'Timer {'
do
    if grep -Fq "$apply_contract" "$apply_service" 2>/dev/null; then
        ok "$apply_contract"
    else
        fail "MonitorApplyService contract missing: $apply_contract"
    fi
done


printf '\n==> Phase 1B.3 safety\n'

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
    ok "external rollback watchdog configured before confirmation"
else
    fail "Safe Apply watchdog contract missing"
fi

if grep -Fq 'Persistent monitors.conf' \
    "$config_dir/modules/displays/DisplayPopup.qml"
then
    ok "UI communicates runtime-only confirmation"
else
    fail "Safe Apply UI must state that persistence is unchanged"
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
    fail "DisplayPopup.qml must use implicitWidth / implicitHeight"
fi

deprecated_window_dimensions="$(
    grep -nE \
        '^[[:space:]]{4}(width|height):[[:space:]]*[0-9]+' \
        "$display_popup" \
        2>/dev/null ||
        true
)"

if [[ -z "$deprecated_window_dimensions" ]]; then
    ok "no deprecated top-level numeric width / height"
else
    fail "deprecated top-level PanelWindow dimensions detected:"
    printf '%s\n' "$deprecated_window_dimensions" >&2
fi


printf '\nQuickshell validation summary: %d error(s)\n' "$errors"

if ((errors > 0)); then
    exit 1
fi

printf 'Quickshell static checks passed.\n'
