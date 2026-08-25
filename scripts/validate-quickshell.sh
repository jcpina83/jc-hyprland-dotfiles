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


printf '\n==> Mode parser contract\n'

mode_parser="$config_dir/services/MonitorModeParser.qml"

for parser_method in \
    parseAll \
    uniqueResolutions \
    modesForResolution \
    closestModeForResolution \
    modeByRaw
do
    if grep -Fq "function $parser_method" "$mode_parser" 2>/dev/null; then
        ok "mode parser method: $parser_method"
    else
        fail "missing mode parser method: $parser_method"
    fi
done


printf '\n==> Display draft contract\n'

draft_store="$config_dir/services/DisplayDraftStore.qml"

for draft_contract in \
    'property var drafts:' \
    'readonly property bool hasDirty:' \
    'function copyDraft' \
    'function setResolution' \
    'function setRefreshMode' \
    'function reset()'
do
    if grep -Fq "$draft_contract" "$draft_store" 2>/dev/null; then
        ok "$draft_contract"
    else
        fail "DisplayDraftStore contract missing: $draft_contract"
    fi
done


printf '\n==> Phase 1B.1 safety\n'

write_patterns='hyprctl[[:space:]].*keyword[[:space:]]+monitor|keyword[[:space:]]+monitor'

write_matches="$(
    grep -RInE \
        --include='*.qml' \
        "$write_patterns" \
        "$config_dir" \
        2>/dev/null ||
        true
)"

if [[ -z "$write_matches" ]]; then
    ok "no monitor write/apply command found"
else
    fail "Phase 1B.1 must remain runtime read-only:"
    printf '%s\n' "$write_matches" >&2
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
