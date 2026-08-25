#!/usr/bin/env bash
set -uo pipefail

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
    'local/monitors.conf' \
    'safe-apply)' \
    'keep)' \
    'rollback)' \
    'status)' \
    'systemd-run' \
    'validate_scale_for_mode' \
    'validate_projected_geometry' \
    'rollback-position' \
    '--position' \
    '--position=*'
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

if grep -Fq "lua_quote \"\$configured_selector\"" \
    "$display_controller" 2>/dev/null
then
    ok "persistent monitor selector preserved during apply"
else
    fail "runtime apply does not preserve persistent monitor selector"
fi


printf '\n==> Display draft layout contract\n'

draft_store="$config_dir/services/DisplayDraftStore.qml"

for draft_contract in \
    'readonly property string topologyError:' \
    'readonly property bool topologyValid:' \
    'function projectedMonitors()' \
    'function topologyValidationError()' \
    'function outputHasOverlap' \
    'function setPosition' \
    'function snapPosition' \
    'function snapRelative' \
    'move required'
do
    if grep -Fq "$draft_contract" "$draft_store" 2>/dev/null; then
        ok "$draft_contract"
    else
        fail "DisplayDraftStore layout contract missing: $draft_contract"
    fi
done


printf '\n==> Visual layout editor contract\n'

layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"

for editor_contract in \
    'DragHandler {' \
    'target: null' \
    'activeTranslation.x' \
    'activeTranslation.y' \
    'snapPosition(' \
    'setPosition(' \
    'snapRelative(' \
    'Negative coordinates are allowed.' \
    'Topology valid' \
    'Layout conflict'
do
    if grep -Fq "$editor_contract" "$layout_editor" 2>/dev/null; then
        ok "$editor_contract"
    else
        fail "DisplayLayoutEditor contract missing: $editor_contract"
    fi
done

if grep -Fq 'DisplayLayoutEditor {' \
    "$config_dir/modules/displays/DisplayPopup.qml" 2>/dev/null
then
    ok "DisplayPopup uses visual layout editor"
else
    fail "DisplayPopup does not use DisplayLayoutEditor"
fi


printf '\n==> Safe Apply layout contract\n'

apply_service="$config_dir/services/MonitorApplyService.qml"

for apply_contract in \
    'function applyDirty(): void' \
    'root.draftStore.topologyValid' \
    'root.draftStore.topologyError' \
    '"--position"' \
    'String(draft.x) + "x" + String(draft.y)'
do
    if grep -Fq "$apply_contract" "$apply_service" 2>/dev/null; then
        ok "$apply_contract"
    else
        fail "MonitorApplyService layout contract missing: $apply_contract"
    fi
done

popup="$config_dir/modules/displays/DisplayPopup.qml"

if grep -Fq 'root.draftStore.topologyValid' "$popup" 2>/dev/null; then
    ok "Safe Apply UI gates on valid topology"
else
    fail "DisplayPopup does not gate Safe Apply on topology validity"
fi


printf '\n==> Phase 1B.5 safety\n'

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

text_position_editor="$(
    grep -RInE \
        --include='*.qml' \
        '(TextInput|TextField).*([xX]/[yY]|position)|position.*(TextInput|TextField)' \
        "$config_dir/modules/displays" \
        2>/dev/null ||
        true
)"

if [[ -z "$text_position_editor" ]]; then
    ok "position editing remains visual; no raw x/y text fields"
else
    fail "raw x/y text editor detected:"
    printf '%s\n' "$text_position_editor" >&2
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
