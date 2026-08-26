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
    "components/JcIconButton.qml"
    "components/JcChip.qml"
    "components/JcToggle.qml"
    "components/JcSlider.qml"
    "components/JcComboBox.qml"
    "components/JcNavItem.qml"
    "components/JcTooltip.qml"
    "components/JcPopup.qml"
    "components/JcMetricRing.qml"
    "modules/dev/ComponentGallery.qml"
    "modules/controlcenter/ControlCenterShell.qml"
    "modules/controlcenter/ControlCenterNavigation.qml"
    "components/JcCard.qml"
    "components/JcChoiceGroup.qml"
    "components/JcSurface.qml"
    "components/JcDivider.qml"
    "components/JcSectionHeader.qml"
    "services/MonitorService.qml"
    "services/MonitorModeParser.qml"
    "services/DisplayDraftStore.qml"
    "services/MonitorApplyService.qml"
    "services/DisplayPersistenceService.qml"
    "modules/displays/DisplayView.qml"
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


printf '\n==> Phase 2A.3.5b stable wrapper generic routing\n'

control_center_wrapper="$repo_root/scripts/runtime/jc-control-center.sh"

for wrapper_generic_contract in \
    'ipc call controlCenter showControlCenter' \
    "ipc call controlCenter showControlCenterOn \"\$output\"" \
    'ipc call controlCenter hideControlCenter' \
    'ipc call controlCenter toggleControlCenter' \
    "ipc call controlCenter toggleControlCenterOn \"\$output\"" \
    'ipc call controlCenter controlCenterIsVisible'
do
    if grep -Fq -- "$wrapper_generic_contract" "$control_center_wrapper" 2>/dev/null; then
        ok "stable wrapper generic route: $wrapper_generic_contract"
    else
        fail "stable wrapper generic route missing: $wrapper_generic_contract"
    fi
done

wrapper_legacy_routes="$(
    grep -nE \
        'showDisplays(On)?|hideDisplays|toggleDisplays(On)?|refreshDisplays|displaysAreVisible' \
        "$control_center_wrapper" \
        2>/dev/null ||
        true
)"

if [[ -z "$wrapper_legacy_routes" ]]; then
    ok "stable wrapper no longer depends on display-specific visibility IPC"
else
    fail "stable wrapper still contains display-specific visibility IPC:"
    printf '%s\n' "$wrapper_legacy_routes" >&2
fi

if grep -Fq 'ipc call controlCenter refreshControlCenter' \
    "$control_center_wrapper" 2>/dev/null
then
    ok "wrapper refresh uses generic Control Center IPC"
else
    fail "wrapper refreshControlCenter action missing"
fi


printf '\n==> Phase 2A.3.5 generic IPC contract\n'

main_qml="${main_qml:-$config_dir/Main.qml}"

for generic_ipc_contract in \
    'function showControlCenter(): void' \
    'function showControlCenterOn(outputName: string): void' \
    'function toggleControlCenter(): void' \
    'function toggleControlCenterOn(outputName: string): void' \
    'function hideControlCenter(): void' \
    'function refreshControlCenter(): void' \
    'function controlCenterIsVisible(): bool' \
    'function showModule(moduleId: string): void' \
    'readonly property string activeModule:'
do
    if grep -Fq -- "$generic_ipc_contract" "$main_qml" 2>/dev/null; then
        ok "generic Control Center IPC: $generic_ipc_contract"
    else
        fail "generic Control Center IPC missing: $generic_ipc_contract"
    fi
done



display_ipc_residue="$(
    grep -nE \
        'function (showDisplays|showDisplaysOn|hideDisplays|toggleDisplays|toggleDisplaysOn|refreshDisplays|displaysAreVisible)\(' \
        "$main_qml" \
        2>/dev/null ||
        true
)"

if [[ -z "$display_ipc_residue" ]]; then
    ok "Main.qml exposes no display-specific Control Center IPC adapters"
else
    fail "Main.qml still exposes display-specific Control Center IPC adapters:"
    printf '%s\n' "$display_ipc_residue" >&2
fi


preview_residue="$(
    grep -nE \
        'shellPreview|ShellPreview|controlCenterShellPreview|displaysVisible|requestedOutputName' \
        "$main_qml" \
        2>/dev/null ||
        true
)"

if [[ -z "$preview_residue" ]]; then
    ok "Main.qml contains no shell-preview or legacy visibility state"
else
    fail "Main.qml still contains preview/legacy state:"
    printf '%s\n' "$preview_residue" >&2
fi

printf '\n==> Phase 2A.3.4 modular Displays content contract\n'

display_module_windows="$(
    grep -RIl \
        --include='*.qml' \
        'PanelWindow {' \
        "$config_dir/modules/displays" \
        2>/dev/null ||
        true
)"

if [[ -z "$display_module_windows" ]]; then
    ok "Displays module owns no PanelWindow"
else
    fail "Displays module must be hosted by ControlCenterShell, not own a PanelWindow:"
    printf '%s\n' "$display_module_windows" >&2
fi


display_view="$config_dir/modules/displays/DisplayView.qml"
control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
main_qml="${main_qml:-$config_dir/Main.qml}"

for view_contract in \
    'Item {' \
    'property var monitorService' \
    'property var draftStore' \
    'property var applyService' \
    'property var persistenceService' \
    'required property var theme' \
    'signal refreshRequested()' \
    'signal resetRequested()' \
    'signal applyRequested()' \
    'signal keepRequested()' \
    'signal rollbackRequested()' \
    'signal saveRequested()' \
    'DisplayLayoutEditor {' \
    'delegate: DisplayCard {' \
    'Save Configuration'
do
    if grep -Fq -- "$view_contract" "$display_view" 2>/dev/null; then
        ok "DisplayView contract: $view_contract"
    else
        fail "DisplayView contract missing: $view_contract"
    fi
done

for forbidden_view_contract in \
    'showCloseAction' \
    'closeRequested()' \
    'PanelWindow {' \
    'property var targetScreen' \
    'screen:' \
    'hyprctl' \
    'Process {'
do
    if grep -Fq -- "$forbidden_view_contract" "$display_view" 2>/dev/null; then
        fail "DisplayView must not contain: $forbidden_view_contract"
    else
        ok "DisplayView excludes: $forbidden_view_contract"
    fi
done


for shell_content_contract in \
    'property Component contentComponent: null' \
    'readonly property var activeContentItem:' \
    'contentLoader.item' \
    'Loader {' \
    'id: contentLoader' \
    'sourceComponent: root.contentComponent'
do
    if grep -Fq -- "$shell_content_contract" "$control_center_shell" 2>/dev/null; then
        ok "ControlCenterShell content-host contract: $shell_content_contract"
    else
        fail "ControlCenterShell content-host contract missing: $shell_content_contract"
    fi
done

for main_content_contract in \
    'id: shellDisplaysComponent' \
    'Displays.DisplayView {' \
    'theme: controlCenterShell.theme' \
    'monitorService: root.monitorServiceHandle' \
    'contentComponent:' \
    '? shellDisplaysComponent' \
    'onApplyRequested: monitorApplyService.applyDirty()' \
    'monitorApplyService.rollbackPending("user")' \
    'displayPersistenceService.saveConfiguration()'
do
    if grep -Fq -- "$main_content_contract" "$main_qml" 2>/dev/null; then
        ok "Main modular Displays contract: $main_content_contract"
    else
        fail "Main modular Displays contract missing: $main_content_contract"
    fi
done

for shell_safety_contract in \
    'function hideControlCenter() {' \
    'monitorApplyService.busy' \
    'monitorApplyService.pendingConfirmation' \
    'displayPersistenceService.saving' \
    'displayDraftStore.reset();'
do
    if grep -Fq -- "$shell_safety_contract" "$main_qml" 2>/dev/null; then
        ok "Control Center Displays safety contract: $shell_safety_contract"
    else
        fail "Control Center Displays safety contract missing: $shell_safety_contract"
    fi
done

printf '\n==> Phase 2A.3.3 Control Center navigation contract\n'

control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
main_qml="${main_qml:-$config_dir/Main.qml}"

for nav_contract in \
    'required property var theme' \
    'property string activeModuleId: "displays"' \
    'signal moduleRequested(string moduleId)' \
    'readonly property var navigationItems:' \
    'Components.JcSurface {' \
    'Components.JcSectionHeader {' \
    'Components.JcDivider {' \
    'delegate: Components.JcNavItem {' \
    'selected:' \
    'controlEnabled:' \
    'root.moduleRequested('
do
    if grep -Fq -- "$nav_contract" "$control_center_navigation" 2>/dev/null; then
        ok "ControlCenterNavigation contract: $nav_contract"
    else
        fail "ControlCenterNavigation contract missing: $nav_contract"
    fi
done

for module_id in \
    displays \
    wallpapers \
    themes \
    quick-settings \
    performance \
    media \
    network \
    notifications
do
    if grep -Fq -- "id: \"$module_id\"" \
        "$control_center_navigation" 2>/dev/null
    then
        ok "ControlCenterNavigation module id: $module_id"
    else
        fail "ControlCenterNavigation module id missing: $module_id"
    fi
done

if grep -A4 -F 'id: "displays"' "$control_center_navigation" \
    | grep -Fq 'enabled: true'
then
    ok "Displays navigation entry is enabled"
else
    fail "Displays navigation entry must be enabled"
fi

for future_module in \
    wallpapers \
    themes \
    quick-settings \
    performance \
    media \
    network \
    notifications
do
    if grep -A4 -F "id: \"$future_module\"" "$control_center_navigation" \
        | grep -Fq 'enabled: false'
    then
        ok "future navigation entry disabled: $future_module"
    else
        fail "future navigation entry must remain disabled: $future_module"
    fi
done

navigation_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "$control_center_navigation" \
        2>/dev/null ||
        true
)"

if [[ -z "$navigation_hardcoded_colors" ]]; then
    ok "ControlCenterNavigation contains no hardcoded colors"
else
    fail "ControlCenterNavigation contains hardcoded colors:"
    printf '%s\n' "$navigation_hardcoded_colors" >&2
fi

navigation_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "$control_center_navigation" \
        2>/dev/null ||
        true
)"

if [[ -z "$navigation_legacy_aliases" ]]; then
    ok "ControlCenterNavigation uses canonical Theme API tokens"
else
    fail "ControlCenterNavigation uses legacy Theme API aliases:"
    printf '%s\n' "$navigation_legacy_aliases" >&2
fi

for shell_nav_contract in \
    'property string activeModuleId: "displays"' \
    'signal moduleRequested(string moduleId)' \
    'ControlCenterNavigation {' \
    'activeModuleId: root.activeModuleId' \
    'root.moduleRequested(moduleId)'
do
    if grep -Fq -- "$shell_nav_contract" "$control_center_shell" 2>/dev/null; then
        ok "ControlCenterShell navigation contract: $shell_nav_contract"
    else
        fail "ControlCenterShell navigation contract missing: $shell_nav_contract"
    fi
done

for main_nav_contract in \
    'property string activeModuleId: "displays"' \
    'function moduleIsAvailable(moduleId) {' \
    'return moduleId === "displays";' \
    'function showModule(moduleId) {' \
    'root.activeModuleId = moduleId;' \
    'activeModuleId: root.activeModuleId' \
    'root.showModule(moduleId)' \
    'readonly property string activeModule:'
do
    if grep -Fq -- "$main_nav_contract" "$main_qml" 2>/dev/null; then
        ok "Main navigation ownership contract: $main_nav_contract"
    else
        fail "Main navigation ownership contract missing: $main_nav_contract"
    fi
done

printf '\n==> Phase 2A.3.2 Control Center shell frame contract\n'

control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
main_qml="${main_qml:-$config_dir/Main.qml}"

for shell_contract in \
    'PanelWindow {' \
    'required property var targetScreen' \
    'required property var theme' \
    'readonly property int preferredWidth: 1080' \
    'readonly property int preferredHeight: 820' \
    'root.targetScreen.width' \
    'root.targetScreen.height' \
    'implicitWidth:' \
    'implicitHeight:' \
    'screen: root.targetScreen' \
    'top: true' \
    'right: true' \
    'top: root.screenMargin' \
    'right: root.screenMargin' \
    'sequence: "Escape"' \
    'Components.JcSurface {' \
    'surfaceRole: "glass-raised"' \
    'Components.JcSectionHeader {' \
    'Components.JcIconButton {' \
    'Components.JcDivider {'
do
    if grep -Fq -- "$shell_contract" "$control_center_shell" 2>/dev/null; then
        ok "ControlCenterShell contract: $shell_contract"
    else
        fail "ControlCenterShell contract missing: $shell_contract"
    fi
done

shell_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "$control_center_shell" \
        2>/dev/null ||
        true
)"

if [[ -z "$shell_hardcoded_colors" ]]; then
    ok "ControlCenterShell contains no hardcoded colors"
else
    fail "ControlCenterShell contains hardcoded colors:"
    printf '%s\n' "$shell_hardcoded_colors" >&2
fi

shell_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "$control_center_shell" \
        2>/dev/null ||
        true
)"

if [[ -z "$shell_legacy_aliases" ]]; then
    ok "ControlCenterShell uses canonical Theme API tokens"
else
    fail "ControlCenterShell uses legacy Theme API aliases:"
    printf '%s\n' "$shell_legacy_aliases" >&2
fi

for main_shell_contract in \
    'import qs.modules.controlcenter as ControlCenter' \
    'property bool controlCenterVisible: false' \
    'property string controlCenterOutputName: ""' \
    'function showControlCenter() {' \
    'function showControlCenterOn(outputName) {' \
    'function hideControlCenter() {' \
    'function toggleControlCenter() {' \
    'function toggleControlCenterOn(outputName) {' \
    'function refreshControlCenter() {' \
    'ControlCenter.ControlCenterShell {' \
    'id: controlCenterShell' \
    'visible: root.controlCenterVisible' \
    'onCloseRequested: root.hideControlCenter()'
do
    if grep -Fq -- "$main_shell_contract" "$main_qml" 2>/dev/null; then
        ok "ControlCenterShell Main contract: $main_shell_contract"
    else
        fail "ControlCenterShell Main contract missing: $main_shell_contract"
    fi
done

printf '\n==> Phase 2A.3.1 Control Center shell architecture contract\n'

control_center_shell_doc="$repo_root/docs/control-center-shell.md"
architecture_doc="$repo_root/docs/architecture.md"

if [[ -r "$control_center_shell_doc" ]]; then
    ok "Control Center shell architecture documentation"
else
    fail "missing docs/control-center-shell.md"
fi

for shell_doc_contract in \
    'Main.qml` remains the composition and orchestration root.' \
    'ControlCenterShell.qml` owns:' \
    'signal moduleRequested(string moduleId)' \
    'MonitorApplyService.pendingConfirmation' \
    'DisplayPersistenceService.saving' \
    'showControlCenter()' \
    'showControlCenterOn(outputName)' \
    'toggleControlCenter()' \
    'toggleControlCenterOn(outputName)' \
    'hideControlCenter()' \
    'controlCenterIsVisible()' \
    'showModule(moduleId)' \
    'The Component Gallery remains a separate development window.' \
    '2A.3.4 Modular content host + Displays structural adapter' \
    'Phase 2A.4 follows with the actual Displays visual redesign.'
do
    if grep -Fq -- "$shell_doc_contract" \
        "$control_center_shell_doc" 2>/dev/null
    then
        ok "Control Center shell contract: $shell_doc_contract"
    else
        fail "Control Center shell contract missing: $shell_doc_contract"
    fi
done

for module_id in \
    displays \
    wallpapers \
    themes \
    quick-settings \
    performance \
    media \
    network \
    notifications
do
    if grep -Fxq -- "$module_id" \
        "$control_center_shell_doc" 2>/dev/null
    then
        ok "Control Center navigation id: $module_id"
    else
        fail "Control Center navigation id missing: $module_id"
    fi
done

if grep -Fq -- 'docs/control-center-shell.md' \
    "$architecture_doc" 2>/dev/null
then
    ok "architecture references Control Center shell contract"
else
    fail "architecture must reference docs/control-center-shell.md"
fi


printf '\n==> Phase 2A.2.10 component library closure\n'

component_library_doc="$repo_root/docs/component-library.md"
design_system_doc="$repo_root/docs/design-system.md"
architecture_doc="$repo_root/docs/architecture.md"
root_readme="$repo_root/README.md"
quickshell_readme="$config_dir/README.md"
main_qml="${main_qml:-$config_dir/Main.qml}"
component_gallery="$config_dir/modules/dev/ComponentGallery.qml"

canonical_components=(
    "JcButton"
    "JcIconButton"
    "JcChip"
    "JcChoiceGroup"
    "JcComboBox"
    "JcDivider"
    "JcMetricRing"
    "JcNavItem"
    "JcPopup"
    "JcSectionHeader"
    "JcSlider"
    "JcSurface"
    "JcToggle"
    "JcTooltip"
)

canonical_component_files=()

for component_name in "${canonical_components[@]}"; do
    component_file="$config_dir/components/${component_name}.qml"
    canonical_component_files+=("$component_file")

    if [[ -r "$component_file" ]]; then
        ok "Phase 2 component: ${component_name}.qml"
    else
        fail "missing Phase 2 component: ${component_name}.qml"
        continue
    fi

    if grep -Fq -- 'required property var theme' "$component_file"; then
        ok "$component_name requires Theme API injection"
    else
        fail "$component_name must require Theme API injection"
    fi
done

library_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "${canonical_component_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$library_hardcoded_colors" ]]; then
    ok "canonical component library contains no hardcoded colors"
else
    fail "canonical component library contains hardcoded colors:"
    printf '%s\n' "$library_hardcoded_colors" >&2
fi

library_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "${canonical_component_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$library_legacy_aliases" ]]; then
    ok "canonical component library uses canonical Theme API tokens"
else
    fail "canonical component library uses legacy Theme API aliases:"
    printf '%s\n' "$library_legacy_aliases" >&2
fi

legacy_card="$config_dir/components/JcCard.qml"

if [[ -r "$legacy_card" ]] \
    && grep -Eq 'theme\.(surface|border|radiusMedium)' \
        "$legacy_card" 2>/dev/null
then
    ok "JcCard remains explicit legacy compatibility"
else
    fail "JcCard compatibility boundary is no longer explicit"
fi

for doc_file in \
    "$component_library_doc" \
    "$design_system_doc" \
    "$architecture_doc" \
    "$quickshell_readme"
do
    if [[ -r "$doc_file" ]]; then
        ok "component-library documentation: ${doc_file#"$repo_root"/}"
    else
        fail "missing component-library documentation: ${doc_file#"$repo_root"/}"
    fi
done

for component_name in "${canonical_components[@]}" "JcCard"; do
    if grep -Fq -- "$component_name" "$component_library_doc" 2>/dev/null; then
        ok "component-library doc covers $component_name"
    else
        fail "component-library doc missing $component_name"
    fi

    if grep -Fq -- "Components.${component_name} {" \
        "$component_gallery" 2>/dev/null
    then
        ok "ComponentGallery instantiates $component_name"
    else
        fail "ComponentGallery must instantiate $component_name"
    fi
done

for doc_contract in \
    'Phase 2A.2 is complete.' \
    "\`JcCard\` is intentionally retained as a Phase 1 compatibility component." \
    'modules/dev/ComponentGallery.qml' \
    'qs -c jc-hyprland ipc call controlCenter showGallery' \
    '2A.3 Control Center shell + navigation' \
    '2A.4 Displays visual redesign'
do
    if grep -Fq -- "$doc_contract" "$component_library_doc" 2>/dev/null; then
        ok "component-library documentation contract: $doc_contract"
    else
        fail "component-library documentation contract missing: $doc_contract"
    fi
done

if grep -Fq \
    -- '- [x] **Phase 2A.2 — Reusable QML Component Library**' \
    "$root_readme" 2>/dev/null
then
    ok "README marks Phase 2A.2 complete"
else
    fail "README must mark Phase 2A.2 complete"
fi

if grep -Fq -- 'docs/component-library.md' \
    "$design_system_doc" 2>/dev/null \
    && grep -Fq -- 'docs/component-library.md' \
        "$architecture_doc" 2>/dev/null
then
    ok "Design System and architecture reference component-library docs"
else
    fail "Design System / architecture component-library references missing"
fi

for gallery_ipc_contract in \
    'function showGallery(): void' \
    'function hideGallery(): void' \
    'function toggleGallery(): void' \
    'function galleryIsVisible(): bool'
do
    if grep -Fq -- "$gallery_ipc_contract" "$main_qml" 2>/dev/null; then
        ok "gallery IPC closure: $gallery_ipc_contract"
    else
        fail "gallery IPC closure missing: $gallery_ipc_contract"
    fi
done


printf '\n==> Phase 2A.2.9 component gallery contract\n'

main_qml="${main_qml:-$config_dir/Main.qml}"
component_gallery="$config_dir/modules/dev/ComponentGallery.qml"

for gallery_contract in \
    'PanelWindow {' \
    'required property var targetScreen' \
    'required property var theme' \
    'Shortcut {' \
    'sequence: "Escape"' \
    'Components.JcSurface {' \
    'Components.JcSectionHeader {' \
    'Components.JcButton {' \
    'Components.JcIconButton {' \
    'Components.JcChip {' \
    'Components.JcToggle {' \
    'Components.JcChoiceGroup {' \
    'Components.JcSlider {' \
    'Components.JcComboBox {' \
    'Components.JcNavItem {' \
    'Components.JcTooltip {' \
    'Components.JcPopup {' \
    'Components.JcMetricRing {' \
    'Components.JcDivider {' \
    'Components.JcCard {'
do
    if grep -Fq -- "$gallery_contract" "$component_gallery" 2>/dev/null; then
        ok "ComponentGallery contract: $gallery_contract"
    else
        fail "ComponentGallery contract missing: $gallery_contract"
    fi
done

for gallery_main_contract in \
    'import qs.modules.dev as Dev' \
    'property bool galleryVisible: false' \
    'function showGallery() {' \
    'function hideGallery() {' \
    'function toggleGallery() {' \
    'Dev.ComponentGallery {' \
    'visible: root.galleryVisible' \
    'onCloseRequested: root.hideGallery()' \
    'function toggleGallery(): void' \
    'function showGallery(): void' \
    'function hideGallery(): void' \
    'function galleryIsVisible(): bool'
do
    if grep -Fq -- "$gallery_main_contract" "$main_qml" 2>/dev/null; then
        ok "ComponentGallery Main contract: $gallery_main_contract"
    else
        fail "ComponentGallery Main contract missing: $gallery_main_contract"
    fi
done

gallery_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "$component_gallery" \
        2>/dev/null ||
        true
)"

if [[ -z "$gallery_hardcoded_colors" ]]; then
    ok "ComponentGallery contains no hardcoded colors"
else
    fail "ComponentGallery contains hardcoded colors:"
    printf '%s\n' "$gallery_hardcoded_colors" >&2
fi

gallery_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "$component_gallery" \
        2>/dev/null ||
        true
)"

if [[ -z "$gallery_legacy_aliases" ]]; then
    ok "ComponentGallery uses canonical Theme API tokens"
else
    fail "ComponentGallery uses legacy Theme API aliases:"
    printf '%s\n' "$gallery_legacy_aliases" >&2
fi


printf '\n==> Phase 2A.2.8 metric visualization component contract\n'

jc_metric_ring="$config_dir/components/JcMetricRing.qml"

for metric_contract in \
    'required property var theme' \
    'property real value: 0' \
    'property real minimum: 0' \
    'property real maximum: 100' \
    'property string label: ""' \
    'property string unit: "%"' \
    'property string status: "normal"' \
    'property int decimals: 0' \
    'readonly property real normalizedValue:' \
    'readonly property color metricColor:' \
    'case "success":' \
    'case "warning":' \
    'case "critical":' \
    'case "info":' \
    'return root.theme.danger;' \
    'return root.theme.accent;' \
    'property real animatedProgress:' \
    'Behavior on animatedProgress {' \
    'root.theme.motionEmphasized' \
    'root.theme.easingEmphasized' \
    'Canvas {' \
    'ringCanvas.requestPaint()' \
    'root.theme.textSizeMetric' \
    'root.theme.textSizeCaption'
do
    if grep -Fq -- "$metric_contract" "$jc_metric_ring" 2>/dev/null; then
        ok "JcMetricRing contract: $metric_contract"
    else
        fail "JcMetricRing contract missing: $metric_contract"
    fi
done

metric_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "$jc_metric_ring" \
        2>/dev/null ||
        true
)"

if [[ -z "$metric_hardcoded_colors" ]]; then
    ok "metric component contains no hardcoded colors"
else
    fail "metric component contains hardcoded colors:"
    printf '%s\n' "$metric_hardcoded_colors" >&2
fi

metric_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "$jc_metric_ring" \
        2>/dev/null ||
        true
)"

if [[ -z "$metric_legacy_aliases" ]]; then
    ok "metric component uses canonical Theme API tokens"
else
    fail "metric component uses legacy Theme API aliases:"
    printf '%s\n' "$metric_legacy_aliases" >&2
fi


printf '\n==> Phase 2A.2.7 feedback and overlay component contract\n'

jc_tooltip="$config_dir/components/JcTooltip.qml"
jc_popup="$config_dir/components/JcPopup.qml"

for tooltip_contract in \
    'import QtQuick.Controls as Controls' \
    'Controls.ToolTip {' \
    'required property var theme' \
    'property bool controlEnabled: true' \
    'delay: root.theme.motionEmphasized' \
    'padding: root.theme.spaceSm' \
    'root.theme.surfaceGlassRaised' \
    'root.theme.borderStrong' \
    'root.theme.textPrimary' \
    'root.theme.textSizeCaption' \
    'root.theme.motionHover' \
    'root.theme.easingEnter' \
    'root.theme.easingExit'
do
    if grep -Fq -- "$tooltip_contract" "$jc_tooltip" 2>/dev/null; then
        ok "JcTooltip contract: $tooltip_contract"
    else
        fail "JcTooltip contract missing: $tooltip_contract"
    fi
done

for popup_contract in \
    'import QtQuick.Controls as Controls' \
    'Controls.Popup {' \
    'required property var theme' \
    'property bool showScrim: root.modal' \
    'property bool dismissOnOutside: true' \
    'modal: false' \
    'dim: root.showScrim' \
    'focus: true' \
    'Controls.Popup.CloseOnEscape' \
    'Controls.Popup.CloseOnPressOutside' \
    'Controls.Overlay.modal: Rectangle {' \
    'Controls.Overlay.modeless: Rectangle {' \
    'root.theme.scrim' \
    'root.theme.surfaceGlassRaised' \
    'root.theme.borderFocus' \
    'root.theme.borderStrong' \
    'root.theme.motionDialog' \
    'root.theme.easingEnter' \
    'root.theme.easingExit'
do
    if grep -Fq -- "$popup_contract" "$jc_popup" 2>/dev/null; then
        ok "JcPopup contract: $popup_contract"
    else
        fail "JcPopup contract missing: $popup_contract"
    fi
done

feedback_files=(
    "$jc_tooltip"
    "$jc_popup"
)

feedback_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "${feedback_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$feedback_hardcoded_colors" ]]; then
    ok "feedback components contain no hardcoded colors"
else
    fail "feedback components contain hardcoded colors:"
    printf '%s\n' "$feedback_hardcoded_colors" >&2
fi

feedback_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "${feedback_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$feedback_legacy_aliases" ]]; then
    ok "feedback components use canonical Theme API tokens"
else
    fail "feedback components use legacy Theme API aliases:"
    printf '%s\n' "$feedback_legacy_aliases" >&2
fi


printf '\n==> Phase 2A.2.6 navigation component contract\n'

jc_nav_item="$config_dir/components/JcNavItem.qml"

for nav_contract in \
    'required property var theme' \
    'property string icon: ""' \
    'property string text: ""' \
    'property bool selected: false' \
    'property bool controlEnabled: true' \
    'signal clicked()' \
    'activeFocusOnTab: root.controlEnabled' \
    'Keys.onPressed: event =>' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlSurfaceHover' \
    'root.theme.controlSurfacePressed' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlBorderFocus' \
    'root.theme.controlBorderSelected' \
    'root.theme.controlTextDisabled' \
    'root.theme.controlTextSelected' \
    'root.theme.controlIconDefault' \
    'root.theme.controlIconActive' \
    'root.theme.controlIconDisabled' \
    'root.theme.controlHeightLarge' \
    'root.theme.radiusMd' \
    'root.theme.focusRingWidth' \
    'root.theme.motionHover' \
    'root.theme.motionPress' \
    'root.theme.motionSelection' \
    'root.theme.motionControl' \
    'onPressed: root.forceActiveFocus()' \
    'onClicked: root.clicked()'
do
    if grep -Fq -- "$nav_contract" "$jc_nav_item" 2>/dev/null; then
        ok "JcNavItem contract: $nav_contract"
    else
        fail "JcNavItem contract missing: $nav_contract"
    fi
done

nav_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "$jc_nav_item" \
        2>/dev/null ||
        true
)"

if [[ -z "$nav_hardcoded_colors" ]]; then
    ok "navigation component contains no hardcoded colors"
else
    fail "navigation component contains hardcoded colors:"
    printf '%s\n' "$nav_hardcoded_colors" >&2
fi

nav_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "$jc_nav_item" \
        2>/dev/null ||
        true
)"

if [[ -z "$nav_legacy_aliases" ]]; then
    ok "navigation component uses canonical Theme API tokens"
else
    fail "navigation component uses legacy Theme API aliases:"
    printf '%s\n' "$nav_legacy_aliases" >&2
fi


printf '\n==> Phase 2A.2.5 input component contract\n'

jc_slider="$config_dir/components/JcSlider.qml"
jc_combo_box="$config_dir/components/JcComboBox.qml"

for slider_contract in \
    'import QtQuick.Controls as Controls' \
    'Controls.Slider {' \
    'required property var theme' \
    'property bool controlEnabled: true' \
    'enabled: root.controlEnabled' \
    'snapMode: root.stepSize > 0' \
    'root.visualPosition' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlIconActive' \
    'root.theme.controlIconDisabled' \
    'root.theme.controlBorderFocus' \
    'root.theme.focusRingWidth' \
    'root.theme.focusRingColor' \
    'root.theme.motionPress' \
    'root.theme.motionHover' \
    'root.theme.motionControl'
do
    if grep -Fq -- "$slider_contract" "$jc_slider" 2>/dev/null; then
        ok "JcSlider contract: $slider_contract"
    else
        fail "JcSlider contract missing: $slider_contract"
    fi
done

for combo_contract in \
    'import QtQuick.Controls as Controls' \
    'Controls.ComboBox {' \
    'required property var theme' \
    'property var options: []' \
    'property string selectedValue: ""' \
    'property string placeholder: "Select"' \
    'property bool controlEnabled: true' \
    'signal valueSelected(string value)' \
    'textRole: "label"' \
    'valueRole: "value"' \
    'function indexForSelectedValue(): int' \
    'function syncCurrentIndex(): void' \
    'onActivated: index =>' \
    'delegate: Controls.ItemDelegate {' \
    'popup: Controls.Popup {' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlSurfaceHover' \
    'root.theme.controlSurfacePressed' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlTextDisabled' \
    'root.theme.controlTextSelected' \
    'root.theme.surfaceOverlay' \
    'root.theme.focusRingColor' \
    'root.theme.motionControl'
do
    if grep -Fq -- "$combo_contract" "$jc_combo_box" 2>/dev/null; then
        ok "JcComboBox contract: $combo_contract"
    else
        fail "JcComboBox contract missing: $combo_contract"
    fi
done

input_files=(
    "$jc_slider"
    "$jc_combo_box"
)

input_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "${input_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$input_hardcoded_colors" ]]; then
    ok "input components contain no hardcoded colors"
else
    fail "input components contain hardcoded colors:"
    printf '%s\n' "$input_hardcoded_colors" >&2
fi

input_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "${input_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$input_legacy_aliases" ]]; then
    ok "input components use canonical Theme API tokens"
else
    fail "input components use legacy Theme API aliases:"
    printf '%s\n' "$input_legacy_aliases" >&2
fi


printf '\n==> Phase 2A.2.4 selection component contract\n'

jc_chip="$config_dir/components/JcChip.qml"
jc_toggle="$config_dir/components/JcToggle.qml"
jc_choice_group="$config_dir/components/JcChoiceGroup.qml"

for chip_contract in \
    'required property var theme' \
    'property string text: ""' \
    'property bool controlEnabled: true' \
    'property bool checked: false' \
    'property bool compact: false' \
    'signal clicked()' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlSurfaceHover' \
    'root.theme.controlSurfacePressed' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlBorderSelected' \
    'root.theme.controlTextDisabled' \
    'root.theme.controlTextSelected' \
    'root.theme.radiusPill' \
    'root.theme.motionSelection'
do
    if grep -Fq -- "$chip_contract" "$jc_chip" 2>/dev/null; then
        ok "JcChip contract: $chip_contract"
    else
        fail "JcChip contract missing: $chip_contract"
    fi
done

for toggle_contract in \
    'required property var theme' \
    'property string text: ""' \
    'property bool controlEnabled: true' \
    'property bool checked: false' \
    'signal toggled(bool value)' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlSurfaceHover' \
    'root.theme.controlSurfacePressed' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlIconDefault' \
    'root.theme.controlIconActive' \
    'root.theme.controlIconDisabled' \
    'root.theme.radiusPill' \
    'root.theme.motionControl' \
    'onClicked: root.toggled(!root.checked)'
do
    if grep -Fq -- "$toggle_contract" "$jc_toggle" 2>/dev/null; then
        ok "JcToggle contract: $toggle_contract"
    else
        fail "JcToggle contract missing: $toggle_contract"
    fi
done

for choice_contract in \
    'required property var theme' \
    'property var options: []' \
    'property string selectedValue: ""' \
    'property string emptyText: "No options"' \
    'property bool controlEnabled: true' \
    'signal valueSelected(string value)' \
    'spacing: root.theme.spaceXs' \
    'delegate: JcChip {' \
    'root.theme.textSecondary' \
    'root.theme.textSizeBody'
do
    if grep -Fq -- "$choice_contract" "$jc_choice_group" 2>/dev/null; then
        ok "JcChoiceGroup contract: $choice_contract"
    else
        fail "JcChoiceGroup contract missing: $choice_contract"
    fi
done

if grep -Fq -- 'delegate: JcButton {' "$jc_choice_group" 2>/dev/null; then
    fail "JcChoiceGroup still uses action buttons for selection"
else
    ok "JcChoiceGroup selection is composed from JcChip"
fi

selection_files=(
    "$jc_chip"
    "$jc_toggle"
    "$jc_choice_group"
)

selection_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "${selection_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$selection_hardcoded_colors" ]]; then
    ok "selection components contain no hardcoded colors"
else
    fail "selection components contain hardcoded colors:"
    printf '%s\n' "$selection_hardcoded_colors" >&2
fi

selection_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "${selection_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$selection_legacy_aliases" ]]; then
    ok "selection components use canonical Theme API tokens"
else
    fail "selection components use legacy Theme API aliases:"
    printf '%s\n' "$selection_legacy_aliases" >&2
fi


printf '\n==> Phase 2A.2.3 action component contract\n'

jc_button="$config_dir/components/JcButton.qml"
jc_icon_button="$config_dir/components/JcIconButton.qml"

for button_contract in \
    'required property var theme' \
    'property string text: ""' \
    'property bool controlEnabled: true' \
    'property bool checked: false' \
    'property bool compact: false' \
    'signal clicked()' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlSurfaceHover' \
    'root.theme.controlSurfacePressed' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlBorderDefault' \
    'root.theme.controlBorderHover' \
    'root.theme.controlBorderPressed' \
    'root.theme.controlBorderSelected' \
    'root.theme.controlTextDisabled' \
    'root.theme.controlTextSelected' \
    'root.theme.controlHeightCompact' \
    'root.theme.controlHeightDefault' \
    'root.theme.radiusSm' \
    'root.theme.borderWidthThin' \
    'root.theme.opacityDisabled' \
    'root.theme.motionHover' \
    'root.theme.motionPress' \
    'root.theme.motionSelection' \
    'root.theme.motionControl' \
    'root.theme.easingStandard'
do
    if grep -Fq -- "$button_contract" "$jc_button" 2>/dev/null; then
        ok "JcButton contract: $button_contract"
    else
        fail "JcButton contract missing: $button_contract"
    fi
done

for icon_button_contract in \
    'required property var theme' \
    'property string icon: ""' \
    'property string accessibleName: ""' \
    'property bool controlEnabled: true' \
    'property bool checked: false' \
    'property bool compact: false' \
    'signal clicked()' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlSurfaceHover' \
    'root.theme.controlSurfacePressed' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlIconDefault' \
    'root.theme.controlIconActive' \
    'root.theme.controlIconDisabled' \
    'root.theme.controlHeightCompact' \
    'root.theme.controlHeightDefault' \
    'root.theme.iconSizeSm' \
    'root.theme.iconSizeMd' \
    'root.theme.motionHover' \
    'root.theme.motionPress' \
    'root.theme.motionSelection' \
    'root.theme.motionControl'
do
    if grep -Fq -- "$icon_button_contract" "$jc_icon_button" 2>/dev/null; then
        ok "JcIconButton contract: $icon_button_contract"
    else
        fail "JcIconButton contract missing: $icon_button_contract"
    fi
done

action_files=(
    "$jc_button"
    "$jc_icon_button"
)

action_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "${action_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$action_hardcoded_colors" ]]; then
    ok "action components contain no hardcoded colors"
else
    fail "action components contain hardcoded colors:"
    printf '%s\n' "$action_hardcoded_colors" >&2
fi

action_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "${action_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$action_legacy_aliases" ]]; then
    ok "action components use canonical Theme API tokens"
else
    fail "action components use legacy Theme API aliases:"
    printf '%s\n' "$action_legacy_aliases" >&2
fi


printf '\n==> Phase 2A.2 foundation component contract\n'

jc_surface="$config_dir/components/JcSurface.qml"
jc_divider="$config_dir/components/JcDivider.qml"
jc_section_header="$config_dir/components/JcSectionHeader.qml"

for surface_contract in \
    'required property var theme' \
    'property string surfaceRole: "base"' \
    'property bool selected: false' \
    'property bool focused: false' \
    'readonly property color resolvedSurfaceColor:' \
    'readonly property color resolvedBorderColor:' \
    'root.theme.surfaceSelected' \
    'root.theme.borderFocus' \
    'root.theme.motionSelection' \
    'root.theme.easingStandard'
do
    if grep -Fq -- "$surface_contract" "$jc_surface" 2>/dev/null; then
        ok "JcSurface contract: $surface_contract"
    else
        fail "JcSurface contract missing: $surface_contract"
    fi
done

for divider_contract in \
    'required property var theme' \
    'property int orientation: Qt.Horizontal' \
    'property color dividerColor: theme.borderSubtle' \
    'property int thickness: theme.borderWidthThin'
do
    if grep -Fq -- "$divider_contract" "$jc_divider" 2>/dev/null; then
        ok "JcDivider contract: $divider_contract"
    else
        fail "JcDivider contract missing: $divider_contract"
    fi
done

for section_header_contract in \
    'required property var theme' \
    'property string title: ""' \
    'property string subtitle: ""' \
    'root.theme.space2Xs' \
    'root.theme.textPrimary' \
    'root.theme.textSecondary' \
    'root.theme.textSizeSection' \
    'root.theme.textSizeBody'
do
    if grep -Fq -- "$section_header_contract" "$jc_section_header" 2>/dev/null; then
        ok "JcSectionHeader contract: $section_header_contract"
    else
        fail "JcSectionHeader contract missing: $section_header_contract"
    fi
done

foundation_files=(
    "$jc_surface"
    "$jc_divider"
    "$jc_section_header"
)

foundation_hardcoded_colors="$(
    grep -nE \
        '#[0-9a-fA-F]{6,8}|Qt\.rgba\(' \
        "${foundation_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$foundation_hardcoded_colors" ]]; then
    ok "foundation components contain no hardcoded colors"
else
    fail "foundation components contain hardcoded colors:"
    printf '%s\n' "$foundation_hardcoded_colors" >&2
fi

foundation_legacy_aliases="$(
    grep -nE \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "${foundation_files[@]}" \
        2>/dev/null ||
        true
)"

if [[ -z "$foundation_legacy_aliases" ]]; then
    ok "foundation components use canonical Theme API tokens"
else
    fail "foundation components use legacy Theme API aliases:"
    printf '%s\n' "$foundation_legacy_aliases" >&2
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
display_view="$config_dir/modules/displays/DisplayView.qml"
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

for persistence_view_contract in \
    'property var persistenceService' \
    'signal saveRequested()' \
    'Save Configuration' \
    'root.persistenceService.canSave'
do
    if grep -Fq "$persistence_view_contract" "$display_view" 2>/dev/null; then
        ok "$persistence_view_contract"
    else
        fail "DisplayView persistence contract missing: $persistence_view_contract"
    fi
done

for persistence_main_contract in \
    'Services.DisplayPersistenceService {' \
    'persistenceService: displayPersistenceService' \
    'displayPersistenceService.saveConfiguration()' \
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
    'property string controlCenterOutputName:' \
    'function showControlCenterOn(outputName: string): void' \
    'function toggleControlCenterOn(outputName: string): void'
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
    "showControlCenterOn \"\$output\"" \
    "toggleControlCenterOn \"\$output\""
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


printf '\n==> Production PanelWindow dimensions\n'

control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"

if grep -Eq '^[[:space:]]+implicitWidth:' \
    "$control_center_shell" 2>/dev/null &&
   grep -Eq '^[[:space:]]+implicitHeight:' \
    "$control_center_shell" 2>/dev/null &&
   grep -Fq 'readonly property int preferredWidth:' \
    "$control_center_shell" 2>/dev/null &&
   grep -Fq 'readonly property int preferredHeight:' \
    "$control_center_shell" 2>/dev/null
then
    ok "ControlCenterShell owns responsive implicit dimensions"
else
    fail "ControlCenterShell responsive PanelWindow dimensions missing"
fi


printf '\nQuickshell validation summary: %d error(s)\n' "$errors"

if ((errors > 0)); then
    exit 1
fi

printf 'Quickshell static checks passed.\n'
