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
    "components/JcIcon.qml"
    "components/JcInteractiveFrame.qml"
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
    "components/JcChoiceGroup.qml"
    "components/JcSurface.qml"
    "components/JcDivider.qml"
    "components/JcSectionHeader.qml"
    "services/MonitorService.qml"
    "services/MonitorModeParser.qml"
    "services/DisplayDraftStore.qml"
    "services/MonitorApplyService.qml"
    "services/DisplayPersistenceService.qml"
    "services/WallpaperService.qml"
    "services/WallpaperDraftStore.qml"
    "services/WallpaperApplyService.qml"
    "modules/wallpapers/WallpaperView.qml"
    "modules/wallpapers/WallpaperPreviewCard.qml"
    "modules/wallpapers/WallpaperTile.qml"
    "modules/displays/DisplayView.qml"
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


printf '\n==> Phase 2B.5 Reset / Apply lifecycle refinement\n'

wallpaper_apply_service="$config_dir/services/WallpaperApplyService.qml"
wallpaper_view="$config_dir/modules/wallpapers/WallpaperView.qml"
wallpaper_main="$config_dir/Main.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for contract in \
    'property bool recoveryResetPending: false' \
    '|| root.recoveryResetPending' \
    'function clearTransientFeedback(): void {' \
    'if (root.busy || root.rollbackRecoveryRequired)' \
    'function resetDraft(): void {' \
    'root.draftStore.reset();' \
    'root.recoveryResetPending = true;' \
    'Refreshing observed wallpaper state before Reset…' \
    'if (root.wallpaperService.runtimeMatchesConfigured) {' \
    'Reset was not performed.' \
    'Wallpaper recovery refresh failed:' \
    'function onChanged() {' \
    'function onResetCompleted() {'
do
    if grep -Fq "$contract" "$wallpaper_apply_service"; then
        ok "Wallpaper Apply lifecycle: $contract"
    else
        fail "Wallpaper Apply lifecycle missing: $contract"
    fi
done

for contract in \
    'signal resetRequested()' \
    '? "Refresh & Reset"' \
    ': "Reset"' \
    '&& root.applyService.rollbackRecoveryRequired' \
    'onClicked: root.resetRequested()'
do
    if grep -Fq "$contract" "$wallpaper_view"; then
        ok "Wallpaper Reset UI lifecycle: $contract"
    else
        fail "Wallpaper Reset UI lifecycle missing: $contract"
    fi
done

if grep -Fq \
    '&& !root.draftStore.observedChangedWhileDirty' \
    "$wallpaper_view"
then
    fail "Reset remains disabled during observed-state conflict"
else
    ok "Reset accepts observed-state conflict as new baseline"
fi

if grep -Fq \
    'onClicked: root.draftStore.reset()' \
    "$wallpaper_view"
then
    fail "WallpaperView still resets DraftStore directly"
else
    ok "WallpaperView delegates Reset lifecycle"
fi

if grep -Fq \
    'onResetRequested: wallpaperApplyService.resetDraft()' \
    "$wallpaper_main"
then
    ok "Main owns Wallpaper Reset orchestration"
else
    fail "Main Wallpaper Reset orchestration missing"
fi

for contract in \
    '## Reset / Apply lifecycle refinement' \
    'Refresh & Reset' \
    'runtimeMatchesConfigured' \
    'observedChangedWhileDirty' \
    'clearTransientFeedback()' \
    'Phase 2B.5'
do
    if grep -Fq "$contract" "$wallpaper_doc"; then
        ok "Wallpaper Reset lifecycle documentation: $contract"
    else
        fail "Wallpaper Reset lifecycle documentation missing: $contract"
    fi
done


printf '\n==> Phase 2B.4.4 wallpaper failure semantics\n'

wallpaperctl="$repo_root/scripts/runtime/jc-wallpaperctl.sh"
wallpaper_apply_service="$config_dir/services/WallpaperApplyService.qml"
wallpaper_main="$config_dir/Main.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for contract in \
    'apply_error() {' \
    'status: "invalid-request"' \
    'preferencesRestored: false' \
    'runtimeRollbackVerified: false' \
    'failure_status="rollback-failed"' \
    'rolled_back=false' \
    'runtime_rollback_verified=false' \
    "preferencesRestored: \$preferencesRestored" \
    "runtimeRollbackVerified: \$runtimeRollbackVerified" \
    'runtimeVerified: false'
do
    if grep -Fq "$contract" "$wallpaperctl"; then
        ok "wallpaperctl failure semantics: $contract"
    else
        fail "wallpaperctl failure semantics missing: $contract"
    fi
done

for contract in \
    'property bool rollbackRecoveryRequired: false' \
    '&& !root.rollbackRecoveryRequired' \
    'signal rollbackFailed(string message)' \
    'function validRollbackFailedResponse(payload) {' \
    'payload.status === "rollback-failed"' \
    'function validInvalidRequestResponse(payload) {' \
    'payload.status === "invalid-request"' \
    'root.rollbackRecoveryRequired = true;' \
    'root.rollbackFailed(root.errorMessage);'
do
    if grep -Fq "$contract" "$wallpaper_apply_service"; then
        ok "WallpaperApplyService failure semantics: $contract"
    else
        fail "WallpaperApplyService failure semantics missing: $contract"
    fi
done

for contract in \
    'return "Wallpaper recovery required";' \
    'if (wallpaperApplyService.rollbackRecoveryRequired) {' \
    'Preferences were restored, but runtime rollback ' \
    'could not be verified. Review observed state.'
do
    if grep -Fq "$contract" "$wallpaper_main"; then
        ok "Main recovery-required contract: $contract"
    else
        fail "Main recovery-required contract missing: $contract"
    fi
done

for contract in \
    '## Wallpaper failure semantics' \
    'invalid-request' \
    'rollback-failed' \
    'preferencesRestored' \
    'runtimeRollbackVerified' \
    'Phase 2B.4.4'
do
    if grep -Fq "$contract" "$wallpaper_doc"; then
        ok "wallpaper failure semantics documentation: $contract"
    else
        fail "wallpaper failure semantics documentation missing: $contract"
    fi
done


printf '\n==> Phase 2B.4.3 Wallpaper Apply UI integration\n'

wallpaper_view="$config_dir/modules/wallpapers/WallpaperView.qml"
wallpaper_preview="$config_dir/modules/wallpapers/WallpaperPreviewCard.qml"
wallpaper_tile="$config_dir/modules/wallpapers/WallpaperTile.qml"
wallpaper_main="$config_dir/Main.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for contract in \
    'property var applyService' \
    'readonly property bool interactionLocked:' \
    'readonly property string operationError:' \
    'signal applyRequested()' \
    '? "Applying…"' \
    '? "Reconciling…"' \
    ': "Apply"' \
    'root.applyService.canApply' \
    'onClicked: root.applyRequested()' \
    'visible: root.operationError.length > 0' \
    'text: root.operationError' \
    'controlEnabled: !root.interactionLocked'
do
    if grep -Fq "$contract" "$wallpaper_view"; then
        ok "Wallpaper Apply UI contract: $contract"
    else
        fail "Wallpaper Apply UI contract missing: $contract"
    fi
done

for contract in \
    'property bool controlEnabled: true' \
    'activeFocusOnTab: root.controlEnabled' \
    'opacity: root.controlEnabled ? 1 : root.theme.opacityDisabled' \
    'enabled: root.controlEnabled' \
    'hoverEnabled: root.controlEnabled'
do
    if grep -Fq "$contract" "$wallpaper_preview"; then
        ok "Wallpaper preview Apply lock: $contract"
    else
        fail "Wallpaper preview Apply lock missing: $contract"
    fi
done

for contract in \
    'property bool controlEnabled: true' \
    'opacity: root.controlEnabled ? 1 : root.theme.opacityDisabled' \
    'enabled: root.controlEnabled' \
    'hoverEnabled: root.controlEnabled'
do
    if grep -Fq "$contract" "$wallpaper_tile"; then
        ok "Wallpaper tile Apply lock: $contract"
    else
        fail "Wallpaper tile Apply lock missing: $contract"
    fi
done

for contract in \
    '|| wallpaperApplyService.busy' \
    'return "Applying wallpaper changes…";' \
    'return "Reconciling wallpaper state…";' \
    'return "Wallpaper Apply error";' \
    'return wallpaperApplyService.statusMessage;' \
    'return wallpaperApplyService.errorMessage;' \
    'return "Review the draft, then choose Apply or Reset.";' \
    'applyService: root.wallpaperApplyServiceHandle' \
    'onApplyRequested: wallpaperApplyService.applyDirty()'
do
    if grep -Fq "$contract" "$wallpaper_main"; then
        ok "Main wallpaper Apply UI wiring: $contract"
    else
        fail "Main wallpaper Apply UI wiring missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-wallpaperctl' \
    '"awww"' \
    '"hyprpaper"' \
    '"systemctl"' \
    'wallpaper.env' \
    'wallpaper-manager'
do
    if grep -Fq "$forbidden" "$wallpaper_view"; then
        fail "WallpaperView bypasses Apply service boundary: $forbidden"
    else
        ok "WallpaperView preserves Apply service boundary: $forbidden"
    fi
done

for contract in \
    '## Wallpaper Apply UI integration' \
    'applyRequested()' \
    'Apply → backend → observed refresh → clean draft' \
    'rollback keeps the draft pending' \
    'Phase 2B.4.3'
do
    if grep -Fq "$contract" "$wallpaper_doc"; then
        ok "Wallpaper Apply UI documentation: $contract"
    else
        fail "Wallpaper Apply UI documentation missing: $contract"
    fi
done


printf '\n==> Phase 2B.4.2 Wallpaper Apply service\n'

wallpaper_apply_service="$config_dir/services/WallpaperApplyService.qml"
wallpaper_draft_store="$config_dir/services/WallpaperDraftStore.qml"
wallpaper_main="$config_dir/Main.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for wallpaper_apply_service_contract in \
    'Scope {' \
    'property var wallpaperService' \
    'property var draftStore' \
    'property bool applying: false' \
    'property bool awaitingRefresh: false' \
    'readonly property bool busy:' \
    'readonly property bool canApply:' \
    'property var lastResult: null' \
    'signal applied(bool mainChanged, bool secondaryChanged)' \
    'signal rolledBack(string message)' \
    'signal failed(string message)' \
    'function wallpaperctlPath() {' \
    'function buildApplyArguments() {' \
    'function applyDirty(): void {' \
    '"apply"' \
    '"--main"' \
    '"--secondary"' \
    '"--json"' \
    'root.draftStore.mainDirty' \
    'root.draftStore.secondaryDirty' \
    'payload.status === "applied"' \
    'payload.status === "rolled-back"' \
    'root.draftStore.prepareForRefreshAfterApply();' \
    'root.wallpaperService.refresh();' \
    'Process {' \
    'StdioCollector {' \
    'Connections {'
do
    if grep -Fq "$wallpaper_apply_service_contract" \
        "$wallpaper_apply_service"
    then
        ok "WallpaperApplyService contract: $wallpaper_apply_service_contract"
    else
        fail "WallpaperApplyService contract missing: $wallpaper_apply_service_contract"
    fi
done

for wallpaper_apply_forbidden_contract in \
    '"awww"' \
    '"hyprpaper"' \
    '"systemctl"' \
    'wallpaper.env' \
    'local/wallpapers/' \
    'wallpaper-manager'
do
    if grep -Fq "$wallpaper_apply_forbidden_contract" \
        "$wallpaper_apply_service"
    then
        fail "WallpaperApplyService bypasses stable mutation boundary: $wallpaper_apply_forbidden_contract"
    else
        ok "WallpaperApplyService excludes backend detail: $wallpaper_apply_forbidden_contract"
    fi
done

for wallpaper_draft_reconcile_contract in \
    'property bool syncAfterApplyPending: false' \
    'function prepareForRefreshAfterApply(): void {' \
    'root.syncAfterApplyPending = true;' \
    'if (root.syncAfterApplyPending) {' \
    'root.syncAfterApplyPending = false;' \
    'root.syncFromObserved(true);'
do
    if grep -Fq "$wallpaper_draft_reconcile_contract" \
        "$wallpaper_draft_store"
    then
        ok "WallpaperDraftStore Apply reconciliation: $wallpaper_draft_reconcile_contract"
    else
        fail "WallpaperDraftStore Apply reconciliation missing: $wallpaper_draft_reconcile_contract"
    fi
done

for wallpaper_apply_main_contract in \
    'readonly property var wallpaperApplyServiceHandle: wallpaperApplyService' \
    'Services.WallpaperApplyService {' \
    'id: wallpaperApplyService' \
    'wallpaperService: wallpaperService' \
    'draftStore: wallpaperDraftStore'
do
    if grep -Fq "$wallpaper_apply_main_contract" "$wallpaper_main"; then
        ok "Main WallpaperApplyService wiring: $wallpaper_apply_main_contract"
    else
        fail "Main WallpaperApplyService wiring missing: $wallpaper_apply_main_contract"
    fi
done

for wallpaper_apply_doc_contract in \
    '## Wallpaper Apply service' \
    'WallpaperApplyService.qml' \
    'prepareForRefreshAfterApply()' \
    'only dirty targets' \
    'Phase 2B.4.2'
do
    if grep -Fq "$wallpaper_apply_doc_contract" "$wallpaper_doc"; then
        ok "Wallpaper Apply service documentation: $wallpaper_apply_doc_contract"
    else
        fail "Wallpaper Apply service documentation missing: $wallpaper_apply_doc_contract"
    fi
done


printf '\n==> Phase 2B.4.1 transactional wallpaper mutation API\n'

wallpaperctl="$repo_root/scripts/runtime/jc-wallpaperctl.sh"
wallpaper_manager="$repo_root/scripts/runtime/wallpaper-manager.sh"
apply_wallpaper="$repo_root/scripts/runtime/apply-wallpaper.sh"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for wallpaperctl_apply_contract in \
    'jc-wallpaperctl apply --main <file>' \
    'apply_transaction() {' \
    'canonical_wallpaper_file() {' \
    "\"\$manager\" transactional-set" \
    'status: "applied"' \
    'runtimeVerified:' \
    'rolledBack:'
do
    if grep -Fq "$wallpaperctl_apply_contract" "$wallpaperctl"; then
        ok "jc-wallpaperctl mutation contract: $wallpaperctl_apply_contract"
    else
        fail "jc-wallpaperctl mutation contract missing: $wallpaperctl_apply_contract"
    fi
done

for wallpaper_manager_transaction_contract in \
    'acquire_mutation_lock() {' \
    'flock -x 9' \
    'restore_preferences_snapshot() {' \
    'transactional_set_pair() {' \
    'Wallpaper transaction failed; restoring previous preferences.' \
    'Wallpaper rollback completed successfully.' \
    'set|random|next|reset|transactional-set)' \
    'transactional-set)'
do
    if grep -Fq "$wallpaper_manager_transaction_contract" "$wallpaper_manager"; then
        ok "wallpaper-manager transaction: $wallpaper_manager_transaction_contract"
    else
        fail "wallpaper-manager transaction missing: $wallpaper_manager_transaction_contract"
    fi
done

for runtime_verify_contract in \
    'runtime_line_matches() {' \
    'verify_awww_runtime() {' \
    'verify_hyprpaper_runtime() {' \
    'verify_awww_runtime' \
    'verify_hyprpaper_runtime' \
    'return 6'
do
    if grep -Fq "$runtime_verify_contract" "$apply_wallpaper"; then
        ok "wallpaper runtime verification: $runtime_verify_contract"
    else
        fail "wallpaper runtime verification missing: $runtime_verify_contract"
    fi
done

for mutation_doc_contract in \
    '## Transactional wallpaper mutation API' \
    'jc-wallpaperctl apply' \
    'transactional-set' \
    'rollback' \
    'flock' \
    'Phase 2B.4.1'
do
    if grep -Fq "$mutation_doc_contract" "$wallpaper_doc"; then
        ok "wallpaper mutation documentation: $mutation_doc_contract"
    else
        fail "wallpaper mutation documentation missing: $mutation_doc_contract"
    fi
done


printf '\n==> Phase 2B.3.2 Wallpaper gallery interaction polish\n'

wallpaper_view="$config_dir/modules/wallpapers/WallpaperView.qml"
wallpaper_tile="$config_dir/modules/wallpapers/WallpaperTile.qml"
wallpaper_preview_card="$config_dir/modules/wallpapers/WallpaperPreviewCard.qml"
wallpaper_draft_store="$config_dir/services/WallpaperDraftStore.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for gallery_interaction_contract in \
    'activeFocusOnTab: true' \
    'keyNavigationEnabled: true' \
    'keyNavigationWraps: false' \
    'highlightFollowsCurrentItem: false' \
    'function normalizeGridCurrentIndex(): void {' \
    'function activateCurrentGridItem(): void {' \
    'event.key === Qt.Key_Home' \
    'event.key === Qt.Key_End' \
    'positionViewAtIndex(currentIndex, GridView.Contain);' \
    'interactive: true' \
    '+ " · arrows + Enter"'
do
    if grep -Fq "$gallery_interaction_contract" "$wallpaper_view"; then
        ok "Wallpaper gallery interaction: $gallery_interaction_contract"
    else
        fail "Wallpaper gallery interaction missing: $gallery_interaction_contract"
    fi
done

for gallery_state_contract in \
    'property bool currentForTarget: false' \
    'property bool keyboardCurrent: false' \
    'readonly property string stateLabel:' \
    '? "DRAFT"' \
    '? "CURRENT"' \
    'readonly property color stateColor:' \
    'signal activated(string path, int itemIndex)' \
    'focused: root.keyboardCurrent'
do
    if grep -Fq "$gallery_state_contract" "$wallpaper_tile"; then
        ok "WallpaperTile interaction state: $gallery_state_contract"
    else
        fail "WallpaperTile interaction state missing: $gallery_state_contract"
    fi
done

for target_marker_contract in \
    'visible: root.targetSelected' \
    'text: "Target"' \
    'text: "Draft"'
do
    if grep -Fq "$target_marker_contract" "$wallpaper_preview_card"; then
        ok "WallpaperPreviewCard target state: $target_marker_contract"
    else
        fail "WallpaperPreviewCard target state missing: $target_marker_contract"
    fi
done

for mutation_guard in \
    'Process {' \
    '"awww"' \
    '"hyprpaper"' \
    '"systemctl"' \
    'wallpaper.env' \
    'local/wallpapers/'
do
    if grep -Fq "$mutation_guard" \
        "$wallpaper_view" \
        "$wallpaper_tile" \
        "$wallpaper_preview_card" \
        "$wallpaper_draft_store"
    then
        fail "Wallpaper interaction mutation boundary violated: $mutation_guard"
    else
        ok "Wallpaper interaction remains draft-only: $mutation_guard"
    fi
done

for interaction_doc_contract in \
    '## Wallpaper gallery interaction polish' \
    'CURRENT' \
    'DRAFT' \
    'arrow-key navigation' \
    'Phase 2B.3.2'
do
    if grep -Fq "$interaction_doc_contract" "$wallpaper_doc"; then
        ok "Wallpaper interaction documentation: $interaction_doc_contract"
    else
        fail "Wallpaper interaction documentation missing: $interaction_doc_contract"
    fi
done


printf '\n==> Phase 2B.3.1d Wallpaper preview composition\n'

wallpaper_preview_card="$config_dir/modules/wallpapers/WallpaperPreviewCard.qml"

for preview_contract in \
    'Item {' \
    'required property var theme' \
    'Components.JcSurface {' \
    'id: previewSurface' \
    'theme: root.theme' \
    'selected: root.targetSelected' \
    'focused: root.activeFocus'
do
    if grep -Fq "$preview_contract" "$wallpaper_preview_card"; then
        ok "WallpaperPreviewCard composition: $preview_contract"
    else
        fail "WallpaperPreviewCard composition missing: $preview_contract"
    fi
done

first_type="$(
    awk '
        /^[[:space:]]*(Item|Components\.JcSurface)[[:space:]]*\{/ {
            print $1
            exit
        }
    ' "$wallpaper_preview_card"
)"

if [[ "$first_type" == "Item" ]]; then
    ok "WallpaperPreviewCard root uses composition instead of JcSurface inheritance"
else
    fail "WallpaperPreviewCard root must be Item"
fi


printf '\n==> Phase 2B.3.1 Wallpaper module foundation\n'

wallpaper_view="$config_dir/modules/wallpapers/WallpaperView.qml"
wallpaper_preview_card="$config_dir/modules/wallpapers/WallpaperPreviewCard.qml"
wallpaper_tile="$config_dir/modules/wallpapers/WallpaperTile.qml"
wallpaper_draft_store="$config_dir/services/WallpaperDraftStore.qml"
control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
main_qml="$config_dir/Main.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for wallpaper_draft_contract in \
    'Scope {' \
    'property var wallpaperService' \
    'property string selectedTarget: "main"' \
    'readonly property int dirtyCount:' \
    'readonly property bool hasDirty:' \
    'property bool observedChangedWhileDirty: false' \
    'function setWallpaper(target, path): void {' \
    'function setSelectedWallpaper(path): void {' \
    'function syncFromObserved(force): void {' \
    'function reset(): void {' \
    'Connections {' \
    'function onRefreshed()'
do
    if grep -Fq "$wallpaper_draft_contract" \
        "$wallpaper_draft_store" 2>/dev/null
    then
        ok "WallpaperDraftStore contract: $wallpaper_draft_contract"
    else
        fail "WallpaperDraftStore contract missing: $wallpaper_draft_contract"
    fi
done

for wallpaper_view_contract in \
    'Item {' \
    'property var wallpaperService' \
    'property var draftStore' \
    'required property var theme' \
    'signal refreshRequested()' \
    'readonly property var filteredWallpapers:' \
    'WallpaperPreviewCard {' \
    'GridView {' \
    'model: root.filteredWallpapers' \
    'cacheBuffer: cellHeight * 2' \
    'delegate: WallpaperTile {' \
    'Components.JcHudFrame {' \
    'id: wallpaperGalleryHudFrame' \
    'root.draftStore.setSelectedWallpaper(path);'
do
    if grep -Fq "$wallpaper_view_contract" "$wallpaper_view" 2>/dev/null; then
        ok "WallpaperView contract: $wallpaper_view_contract"
    else
        fail "WallpaperView contract missing: $wallpaper_view_contract"
    fi
done

for wallpaper_ui_forbidden in \
    'Process {' \
    '"awww"' \
    '"hyprpaper"' \
    '"systemctl"' \
    'wallpaper.env' \
    'local/wallpapers/'
do
    if grep -Fq "$wallpaper_ui_forbidden" \
        "$wallpaper_view" \
        "$wallpaper_preview_card" \
        "$wallpaper_tile" \
        "$wallpaper_draft_store" 2>/dev/null
    then
        fail "Wallpaper QML mutation boundary violated: $wallpaper_ui_forbidden"
    else
        ok "Wallpaper QML excludes mutation/runtime command: $wallpaper_ui_forbidden"
    fi
done

for wallpaper_main_contract in \
    'import qs.modules.wallpapers as Wallpapers' \
    '|| moduleId === "wallpapers";' \
    'function prepareWallpapers() {' \
    'Services.WallpaperDraftStore {' \
    'id: wallpaperDraftStore' \
    'id: shellWallpapersComponent' \
    'Wallpapers.WallpaperView {' \
    'draftStore: wallpaperDraftStore' \
    'readonly property var themeHandle: theme' \
    'theme: root.themeHandle' \
    '? "Wallpapers"' \
    '? shellWallpapersComponent'
do
    if grep -Fq "$wallpaper_main_contract" "$main_qml" 2>/dev/null; then
        ok "Main Wallpapers contract: $wallpaper_main_contract"
    else
        fail "Main Wallpapers contract missing: $wallpaper_main_contract"
    fi
done

if ! python3 - "$control_center_navigation" <<'PY_VALIDATE_WALLPAPER_NAV'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(
    r'id:\s*"wallpapers".*?enabled:\s*(true|false)',
    text,
    re.S,
)

if match and match.group(1) == "true":
    print("  OK    Wallpapers navigation entry is enabled")
    raise SystemExit(0)

print("  FAIL  Wallpapers navigation entry must be enabled")
raise SystemExit(1)
PY_VALIDATE_WALLPAPER_NAV
then
    ((errors += 1))
fi

for wallpaper_doc_contract in \
    '## Wallpaper UI foundation' \
    'WallpaperDraftStore.qml' \
    'GridView' \
    'draft-only' \
    'Phase 2B.3.1'
do
    if grep -Fq "$wallpaper_doc_contract" "$wallpaper_doc" 2>/dev/null; then
        ok "Wallpaper UI documentation: $wallpaper_doc_contract"
    else
        fail "Wallpaper UI documentation missing: $wallpaper_doc_contract"
    fi
done


printf '\n==> Phase 2B.2.2 Wallpaper observed-state service\n'

wallpaper_service="$config_dir/services/WallpaperService.qml"
main_qml="$config_dir/Main.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"

for wallpaper_service_contract in \
    'Scope {' \
    'property var wallpapers: []' \
    'readonly property int wallpaperCount:' \
    'property bool loading: false' \
    'property bool ready: false' \
    'property string errorMessage: ""' \
    'readonly property bool runtimeMatchesConfigured:' \
    'function wallpaperctlPath() {' \
    'function refresh(): void {' \
    '"status",' \
    '"catalog",' \
    '"--json"' \
    'root.wallpapers = catalog.items.slice(0);' \
    'Component.onCompleted: root.refresh()'
do
    if grep -Fq "$wallpaper_service_contract" \
        "$wallpaper_service" 2>/dev/null
    then
        ok "WallpaperService contract: $wallpaper_service_contract"
    else
        fail "WallpaperService contract missing: $wallpaper_service_contract"
    fi
done

for forbidden_wallpaper_qml_contract in \
    '"awww"' \
    '"hyprpaper"' \
    '"systemctl"' \
    'wallpaper.env' \
    'local/wallpapers/'
do
    if grep -Fq "$forbidden_wallpaper_qml_contract" \
        "$wallpaper_service" 2>/dev/null
    then
        fail \
            "WallpaperService must not own runtime mutation/config: " \
            "$forbidden_wallpaper_qml_contract"
    else
        ok \
            "WallpaperService excludes runtime mutation/config: " \
            "$forbidden_wallpaper_qml_contract"
    fi
done

for wallpaper_main_contract in \
    'readonly property var wallpaperServiceHandle: wallpaperService' \
    'Services.WallpaperService {' \
    'id: wallpaperService'
do
    if grep -Fq "$wallpaper_main_contract" "$main_qml" 2>/dev/null; then
        ok "Main WallpaperService contract: $wallpaper_main_contract"
    else
        fail "Main WallpaperService contract missing: $wallpaper_main_contract"
    fi
done

for wallpaper_doc_contract in \
    'WallpaperService.qml' \
    'jc-wallpaperctl status --json' \
    'jc-wallpaperctl catalog --json' \
    'The service is read-only'
do
    if grep -Fq "$wallpaper_doc_contract" "$wallpaper_doc" 2>/dev/null; then
        ok "Wallpaper service documentation: $wallpaper_doc_contract"
    else
        fail "Wallpaper service documentation missing: $wallpaper_doc_contract"
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
    'iconName:' \
    'String(modelData.iconName || "")' \
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
    '|| moduleId === "wallpapers";' \
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
    'visible: root.mounted' \
    'screen:' \
    'root.presentationScreen' \
    'property bool requestedVisible: false' \
    'property bool mounted: false' \
    'property var presentationScreen: null' \
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
    'requestedVisible: root.controlCenterVisible' \
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
    '2A.3.4 Modular content host + Displays view extraction' \
    'Phase 2A.4 is the next phase and performs the actual Displays visual redesign.'
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

for component_name in "${canonical_components[@]}"; do
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
    "\`JcCard\` was retired in Phase 2A.4.7 after its final Component Gallery consumer" \
    "migrated to \`JcSurface\`." \
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
    'Components.JcDivider {'
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
    'property string iconName: ""' \
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
    'JcIcon {' \
    'name: root.iconName' \
    'glyph: root.icon' \
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
    'property string iconName: ""' \
    'property string icon: ""' \
    'property bool controlEnabled: true' \
    'property bool checked: false' \
    'property bool compact: false' \
    'signal clicked()' \
    'JcInteractiveFrame {' \
    'hovered: root.hovered' \
    'pressed: root.pressed' \
    'selected: root.checked' \
    'focused: root.activeFocus' \
    'JcIcon {' \
    'root.theme.controlTextDisabled' \
    'root.theme.controlTextSelected' \
    'root.theme.controlHeightCompact' \
    'root.theme.controlHeightDefault'
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
    'property int optionSpacing: root.theme.spaceSm' \
    'signal valueSelected(string value)' \
    'spacing: root.optionSpacing' \
    'delegate: JcChip {' \
    'iconName: String(modelData.iconName || "")' \
    'icon: String(modelData.icon || "")' \
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
    'property string iconName: ""' \
    'property string icon: ""' \
    'property bool controlEnabled: true' \
    'property bool checked: false' \
    'property bool compact: false' \
    'signal clicked()' \
    'JcInteractiveFrame {' \
    'hovered: root.hovered' \
    'pressed: root.pressed' \
    'selected: root.checked' \
    'focused: root.activeFocus' \
    'JcIcon {' \
    'root.theme.controlTextDisabled' \
    'root.theme.controlTextSelected' \
    'root.theme.controlHeightCompact' \
    'root.theme.controlHeightDefault' \
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
    'property string iconName: ""' \
    'property string accessibleName: ""' \
    'property bool controlEnabled: true' \
    'property bool checked: false' \
    'property bool compact: false' \
    'signal clicked()' \
    'JcInteractiveFrame {' \
    'hovered: root.hovered' \
    'pressed: root.pressed' \
    'selected: root.checked' \
    'focused: root.activeFocus' \
    'JcIcon {' \
    'root.theme.controlIconDefault' \
    'root.theme.controlIconActive' \
    'root.theme.controlIconDisabled' \
    'root.theme.controlHeightCompact' \
    'root.theme.controlHeightDefault' \
    'root.theme.iconSizeSm' \
    'root.theme.iconSizeMd' \
    'root.theme.motionPress'
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


printf '\n==> Phase 2A.3.6 guarded shell transitions\n'

main_qml="${main_qml:-$config_dir/Main.qml}"
control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
control_center_nav="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
control_center_shell_doc="$repo_root/docs/control-center-shell.md"

for guarded_main_contract in \
    'readonly property bool controlCenterTransitionLocked:' \
    'readonly property string controlCenterStatusText:' \
    'readonly property string controlCenterStatusDetail:' \
    '&& root.controlCenterTransitionLocked)' \
    'if (root.controlCenterTransitionLocked)' \
    'transitionLocked: root.controlCenterTransitionLocked' \
    'statusText: root.controlCenterStatusText' \
    'statusDetail: root.controlCenterStatusDetail'
do
    if grep -Fq -- "$guarded_main_contract" "$main_qml" 2>/dev/null; then
        ok "guarded Main contract: $guarded_main_contract"
    else
        fail "guarded Main contract missing: $guarded_main_contract"
    fi
done

for guarded_shell_contract in \
    'property string activeModuleTitle: "Displays"' \
    'property string statusText: "Ready"' \
    'property string statusDetail: ""' \
    'property bool transitionLocked: false' \
    'subtitle: root.activeModuleTitle' \
    'controlEnabled: !root.transitionLocked' \
    'if (!root.transitionLocked)' \
    'navigationLocked: root.transitionLocked' \
    'text: root.statusText' \
    'text: root.statusDetail'
do
    if grep -Fq -- "$guarded_shell_contract" \
        "$control_center_shell" 2>/dev/null
    then
        ok "guarded shell contract: $guarded_shell_contract"
    else
        fail "guarded shell contract missing: $guarded_shell_contract"
    fi
done

for guarded_nav_contract in \
    'property bool navigationLocked: false' \
    '&& (!root.navigationLocked'
do
    if grep -Fq -- "$guarded_nav_contract" "$control_center_nav" 2>/dev/null; then
        ok "guarded navigation contract: $guarded_nav_contract"
    else
        fail "guarded navigation contract missing: $guarded_nav_contract"
    fi
done

if grep -Fq 'Modular shell · Phase 2A.3' \
    "$control_center_shell" 2>/dev/null
then
    fail "production shell still exposes development-phase header copy"
else
    ok "production shell header uses module identity"
fi

if grep -Fq '## Phase 2A.3.6 — Header, footer and guarded transitions' \
    "$control_center_shell_doc" 2>/dev/null
then
    ok "Phase 2A.3.6 shell documentation"
else
    fail "Phase 2A.3.6 shell documentation missing"
fi


printf '\n==> Phase 2A.3.7a initial focus and keyboard baseline\n'

jc_button="$config_dir/components/JcButton.qml"
jc_icon_button="$config_dir/components/JcIconButton.qml"
control_center_nav="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
control_center_shell_doc="$repo_root/docs/control-center-shell.md"

for keyboard_button in "$jc_button" "$jc_icon_button"; do
    for keyboard_contract in \
        'activeFocusOnTab: root.controlEnabled' \
        'Keys.onPressed: event => {' \
        'event.key === Qt.Key_Return' \
        'event.key === Qt.Key_Enter' \
        'event.key === Qt.Key_Space' \
        'JcInteractiveFrame {' \
        'focused: root.activeFocus' \
        'onPressed: root.forceActiveFocus()'
    do
        if grep -Fq -- "$keyboard_contract" "$keyboard_button" 2>/dev/null; then
            ok "$(basename "$keyboard_button") keyboard contract: $keyboard_contract"
        else
            fail "$(basename "$keyboard_button") keyboard contract missing: $keyboard_contract"
        fi
    done
done

for navigation_focus_contract in \
    'function focusActiveItem() {' \
    'navigationRepeater.itemAt(i)' \
    'item.forceActiveFocus();' \
    'id: navigationRepeater'
do
    if grep -Fq -- "$navigation_focus_contract" \
        "$control_center_nav" 2>/dev/null
    then
        ok "navigation focus contract: $navigation_focus_contract"
    else
        fail "navigation focus contract missing: $navigation_focus_contract"
    fi
done

for shell_focus_contract in \
    'function requestInitialFocus() {' \
    'navigation.focusActiveItem();' \
    'onRequestedVisibleChanged: {' \
    'Component.onCompleted: {' \
    'id: navigation'
do
    if grep -Fq -- "$shell_focus_contract" \
        "$control_center_shell" 2>/dev/null
    then
        ok "shell focus contract: $shell_focus_contract"
    else
        fail "shell focus contract missing: $shell_focus_contract"
    fi
done

if grep -Fq \
    '### Phase 2A.3.7a — Initial focus and keyboard baseline' \
    "$control_center_shell_doc" 2>/dev/null
then
    ok "Phase 2A.3.7a shell documentation"
else
    fail "Phase 2A.3.7a shell documentation missing"
fi


printf '\n==> Phase 2A.3.7b directional navigation semantics\n'

jc_nav_item="$config_dir/components/JcNavItem.qml"
control_center_nav="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
control_center_shell_doc="$repo_root/docs/control-center-shell.md"

for directional_item_contract in \
    'signal previousFocusRequested()' \
    'signal nextFocusRequested()' \
    'signal firstFocusRequested()' \
    'signal lastFocusRequested()' \
    'event.key === Qt.Key_Up' \
    'event.key === Qt.Key_Down' \
    'event.key === Qt.Key_Home' \
    'event.key === Qt.Key_End'
do
    if grep -Fq -- "$directional_item_contract" \
        "$jc_nav_item" 2>/dev/null
    then
        ok "JcNavItem directional contract: $directional_item_contract"
    else
        fail "JcNavItem directional contract missing: $directional_item_contract"
    fi
done

for directional_nav_contract in \
    'function focusRelative(startIndex, step) {' \
    'function focusBoundary(last) {' \
    'candidateItem.controlEnabled' \
    'required property int index' \
    'onPreviousFocusRequested:' \
    'root.focusRelative(index, -1)' \
    'onNextFocusRequested:' \
    'root.focusRelative(index, 1)' \
    'onFirstFocusRequested:' \
    'root.focusBoundary(false)' \
    'onLastFocusRequested:' \
    'root.focusBoundary(true)'
do
    if grep -Fq -- "$directional_nav_contract" \
        "$control_center_nav" 2>/dev/null
    then
        ok "directional navigation contract: $directional_nav_contract"
    else
        fail "directional navigation contract missing: $directional_nav_contract"
    fi
done

if grep -Fq \
    '### Phase 2A.3.7b — Directional navigation semantics' \
    "$control_center_shell_doc" 2>/dev/null
then
    ok "Phase 2A.3.7b shell documentation"
else
    fail "Phase 2A.3.7b shell documentation missing"
fi


printf '\n==> Phase 2A.3.7c shell and module motion\n'

control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
control_center_shell_doc="$repo_root/docs/control-center-shell.md"

for shell_motion_contract in \
    'function beginOpenPresentation() {' \
    'function playStatusMotion() {' \
    'id: shellEnterAnimation' \
    'id: contentEnterAnimation' \
    'id: statusChangeAnimation' \
    'target: shellSurface' \
    'id: shellExitAnimation' \
    'target: contentLoader' \
    'target: contentTranslate' \
    'duration: root.theme.motionPanel' \
    'duration: root.theme.motionSelection' \
    'easing.type: root.theme.easingEnter' \
    'id: contentHost' \
    'transform: Translate {' \
    'contentEnterAnimation.restart()' \
    'id: statusRow' \
    'Behavior on color {'
do
    if grep -Fq -- "$shell_motion_contract" \
        "$control_center_shell" 2>/dev/null
    then
        ok "shell motion contract: $shell_motion_contract"
    else
        fail "shell motion contract missing: $shell_motion_contract"
    fi
done

if grep -Eq \
    'Layout\.(preferredX|preferredY)|Behavior on (x|y)|NumberAnimation \{[[:space:]]*property: "(x|y)"' \
    "$control_center_shell" 2>/dev/null
then
    fail "ControlCenterShell must not animate layout-managed geometry"
else
    ok "ControlCenterShell motion avoids layout-managed geometry"
fi

if grep -Fq \
    '### Phase 2A.3.7c — Shell and module motion' \
    "$control_center_shell_doc" 2>/dev/null
then
    ok "Phase 2A.3.7c shell documentation"
else
    fail "Phase 2A.3.7c shell documentation missing"
fi


printf '\n==> Phase 2A.3.8 final documentation and release gate\n'

readme="$repo_root/README.md"
control_center_shell_doc="$repo_root/docs/control-center-shell.md"
component_library_doc="$repo_root/docs/component-library.md"
architecture_doc="$repo_root/docs/architecture.md"

for final_readme_contract in \
    '- [x] **Phase 2A.3 — Control Center shell + navigation**' \
    '- [x] **Phase 2A.4 — Displays visual redesign**' \
    '- [ ] **Phase 2B — Wallpapers** ← **NEXT**' \
    "generic \`controlCenter\` IPC with stable \`jc-control-center\` wrapper" \
    'keyboard focus, directional navigation and semantic focus rings' \
    'lightweight shell / module / status motion'
do
    if grep -Fq -- "$final_readme_contract" "$readme" 2>/dev/null; then
        ok "Phase 2A.3 README completion contract: $final_readme_contract"
    else
        fail "Phase 2A.3 README completion contract missing: $final_readme_contract"
    fi
done

for final_shell_doc_contract in \
    '## Phase 2A.3 completion status' \
    'Phase 2A.3 is complete.' \
    '2A.3.8 Quality gates + documentation                         ✓' \
    "\`ControlCenterShell.qml\` is the only production Control Center \`PanelWindow\`." \
    'Phase 2A.4 is next.'
do
    if grep -Fq -- "$final_shell_doc_contract" \
        "$control_center_shell_doc" 2>/dev/null
    then
        ok "Phase 2A.3 shell completion contract: $final_shell_doc_contract"
    else
        fail "Phase 2A.3 shell completion contract missing: $final_shell_doc_contract"
    fi
done

for final_component_contract in \
    '2A.3 Control Center shell + navigation  ✓ complete' \
    '2A.4 Displays visual redesign           ← next'
do
    if grep -Fq -- "$final_component_contract" \
        "$component_library_doc" 2>/dev/null
    then
        ok "component-library roadmap contract: $final_component_contract"
    else
        fail "component-library roadmap contract missing: $final_component_contract"
    fi
done

for final_architecture_contract in \
    'Phase 2A  Shared visual platform                 ✓ COMPLETE' \
    '2A.3  Control Center shell + navigation  ✓' \
    '2A.4  Displays visual redesign           ✓' \
    'Wallpapers  ← NEXT'
do
    if grep -Fq -- "$final_architecture_contract" \
        "$architecture_doc" 2>/dev/null
    then
        ok "architecture roadmap contract: $final_architecture_contract"
    else
        fail "architecture roadmap contract missing: $final_architecture_contract"
    fi
done

stale_control_center_docs="$(
    grep -nE \
        'DisplayPopup|showDisplays|showDisplaysOn|hideDisplays|toggleDisplays|toggleDisplaysOn|refreshDisplays|displaysAreVisible|shellPreview|displaysVisible|requestedOutputName' \
        "$readme" \
        "$control_center_shell_doc" \
        "$architecture_doc" \
        "$component_library_doc" \
        2>/dev/null ||
        true
)"

if [[ -z "$stale_control_center_docs" ]]; then
    ok "active Control Center documentation contains no retired Displays shell API"
else
    fail "active Control Center documentation still contains retired Displays shell API:"
    printf '%s\n' "$stale_control_center_docs" >&2
fi

stale_phase_language="$(
    grep -nE \
        "Phase 2A\.3 will add|The current \`DisplayPopup\.qml\`|Existing display-specific methods remain compatibility adapters" \
        "$control_center_shell_doc" \
        2>/dev/null ||
        true
)"

if [[ -z "$stale_phase_language" ]]; then
    ok "Control Center shell documentation contains no stale Phase 2A.3 planning language"
else
    fail "Control Center shell documentation still contains stale Phase 2A.3 planning language:"
    printf '%s\n' "$stale_phase_language" >&2
fi


printf '\n==> Phase 2A.4.1 Displays visual migration contract\n'

displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"
readme="$repo_root/README.md"
architecture_doc="$repo_root/docs/architecture.md"

if [[ -r "$displays_visual_doc" ]]; then
    ok "Displays visual redesign documentation"
else
    fail "Displays visual redesign documentation missing"
fi

for displays_contract in \
    'Observed State' \
    'Draft State' \
    'Applied Runtime State' \
    'Persistent State' \
    'refreshRequested()' \
    'resetRequested()' \
    'applyRequested()' \
    'keepRequested()' \
    'rollbackRequested()' \
    'saveRequested()' \
    'setEnabled(...)' \
    'setResolution(...)' \
    'setRefreshMode(...)' \
    'setScale(...)' \
    'setTransform(...)' \
    'snapPosition(...)' \
    'setPosition(...)' \
    'snapRelative(...)' \
    'availableModes` remains the source of truth for actual modes.' \
    'Mouse-only production settings controls are not an acceptable final state.' \
    "No visual control may write \`local/monitors.lua\` directly." \
    'Animations must never delay, own, or gate the Safe Apply watchdog.' \
    'Phase 2A.4 does not:' \
    'rewrite MonitorService' \
    'rewrite DisplayDraftStore' \
    'rewrite MonitorApplyService' \
    'rewrite DisplayPersistenceService'
do
    if grep -Fq -- "$displays_contract" \
        "$displays_visual_doc" 2>/dev/null
    then
        ok "Displays migration contract: $displays_contract"
    else
        fail "Displays migration contract missing: $displays_contract"
    fi
done

for visual_mapping_contract in \
    'generic feature surfaces       -> JcSurface' \
    'section headings               -> JcSectionHeader' \
    'structural separators          -> JcDivider' \
    'actions                        -> JcButton / JcIconButton' \
    'large mode / refresh lists     -> JcComboBox' \
    'continuous numeric controls    -> JcSlider'
do
    if grep -Fq -- "$visual_mapping_contract" \
        "$displays_visual_doc" 2>/dev/null
    then
        ok "Displays visual mapping: $visual_mapping_contract"
    else
        fail "Displays visual mapping missing: $visual_mapping_contract"
    fi
done

for compatibility_contract in \
    'production Displays contains no JcCard dependency' \
    'production Displays contains no legacy Theme alias dependency' \
    'Component Gallery uses JcSurface instead of JcCard' \
    'validators reject reintroduction of the retired compatibility layer'
do
    if grep -Fq -- "$compatibility_contract" \
        "$displays_visual_doc" 2>/dev/null
    then
        ok "Displays compatibility retirement contract: $compatibility_contract"
    else
        fail "Displays compatibility retirement contract missing: $compatibility_contract"
    fi
done

if grep -Fq \
    "migration contract: \`docs/displays-visual-redesign.md\`" \
    "$readme" 2>/dev/null
then
    ok "README references Displays visual migration contract"
else
    fail "README missing Displays visual migration contract reference"
fi

if grep -Fq \
    'docs/displays-visual-redesign.md' \
    "$architecture_doc" 2>/dev/null
then
    ok "architecture references Displays visual migration contract"
else
    fail "architecture missing Displays visual migration contract reference"
fi

display_view="$config_dir/modules/displays/DisplayView.qml"
display_card="$config_dir/modules/displays/DisplayCard.qml"
display_layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"

for preserved_view_signal in \
    'signal refreshRequested()' \
    'signal resetRequested()' \
    'signal applyRequested()' \
    'signal keepRequested()' \
    'signal rollbackRequested()' \
    'signal saveRequested()'
do
    if grep -Fq -- "$preserved_view_signal" \
        "$display_view" 2>/dev/null
    then
        ok "Displays preserved action signal: $preserved_view_signal"
    else
        fail "Displays preserved action signal missing: $preserved_view_signal"
    fi
done

for draft_mutation_contract in \
    'setEnabled(' \
    'setResolution(' \
    'setRefreshMode(' \
    'setScale(' \
    'setTransform('
do
    if grep -Fq -- "$draft_mutation_contract" \
        "$display_card" 2>/dev/null
    then
        ok "DisplayCard draft mutation boundary: $draft_mutation_contract"
    else
        fail "DisplayCard draft mutation boundary missing: $draft_mutation_contract"
    fi
done

for topology_mutation_contract in \
    'snapPosition(' \
    'setPosition(' \
    'snapRelative('
do
    if grep -Fq -- "$topology_mutation_contract" \
        "$display_layout_editor" 2>/dev/null
    then
        ok "DisplayLayoutEditor draft topology boundary: $topology_mutation_contract"
    else
        fail "DisplayLayoutEditor topology boundary missing: $topology_mutation_contract"
    fi
done


printf '\n==> Phase 2A.4.2 DisplayView hosted content cleanup\n'

display_view="$config_dir/modules/displays/DisplayView.qml"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"

for hosted_view_contract in \
    'Components.JcDivider {' \
    'spacing: root.theme.spaceMd' \
    'spacing: root.theme.spaceSm' \
    'DisplayLayoutEditor {' \
    'delegate: DisplayCard {' \
    'Save Configuration'
do
    if grep -Fq -- "$hosted_view_contract" "$display_view" 2>/dev/null; then
        ok "DisplayView hosted content contract: $hosted_view_contract"
    else
        fail "DisplayView hosted content contract missing: $hosted_view_contract"
    fi
done

for retired_display_view_shell in \
    'text: "Displays"' \
    'root.theme.radiusLarge' \
    'root.theme.background' \
    'root.theme.spacingLg' \
    'root.theme.spacingMd' \
    'Phase 1C.3 · Persistent Save'
do
    if grep -Fq -- "$retired_display_view_shell" \
        "$display_view" 2>/dev/null
    then
        fail "DisplayView legacy shell residue: $retired_display_view_shell"
    else
        ok "DisplayView excludes legacy shell residue: $retired_display_view_shell"
    fi
done

for preserved_display_action in \
    'signal refreshRequested()' \
    'signal resetRequested()' \
    'signal applyRequested()' \
    'signal keepRequested()' \
    'signal rollbackRequested()' \
    'signal saveRequested()'
do
    if grep -Fq -- "$preserved_display_action" \
        "$display_view" 2>/dev/null
    then
        ok "DisplayView preserved action: $preserved_display_action"
    else
        fail "DisplayView preserved action missing: $preserved_display_action"
    fi
done

if grep -Fq \
    '## Phase 2A.4.2 — DisplayView shell/content cleanup' \
    "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.2 migration documentation"
else
    fail "Phase 2A.4.2 migration documentation missing"
fi

if grep -Fq \
    '2A.4.1 Displays UI audit + visual migration contract       ✓' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        '2A.4.2 DisplayView shell/content cleanup                   ✓' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4 roadmap records DisplayView cleanup complete"
else
    fail "Phase 2A.4 roadmap does not record DisplayView cleanup complete"
fi


printf '\n==> Phase 2A.4.3 DisplayCard canonical surface migration\n'

display_card="$config_dir/modules/displays/DisplayCard.qml"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"

for display_card_visual_contract in \
    'Components.JcSurface {' \
    'cornerRadius: root.theme.radiusMd' \
    'Components.JcDivider {' \
    'spacing: root.theme.spaceSm' \
    'columnSpacing: root.theme.spaceLg' \
    'rowSpacing: root.theme.spaceXs' \
    'root.theme.textSizeBody' \
    'root.theme.textSizeCaption'
do
    if grep -Fq -- "$display_card_visual_contract" \
        "$display_card" 2>/dev/null
    then
        ok "DisplayCard visual contract: $display_card_visual_contract"
    else
        fail "DisplayCard visual contract missing: $display_card_visual_contract"
    fi
done

for display_card_retired_visual in \
    'root.theme.spacingSm' \
    'root.theme.border' \
    'font.bold:' \
    '"#f2f2f4"' \
    '"#b8b8c0"' \
    '"#f9e2af"' \
    '"#a6e3a1"' \
    '"#89b4fa"' \
    '"#3b3b43"'
do
    if grep -Fq -- "$display_card_retired_visual" \
        "$display_card" 2>/dev/null
    then
        fail "DisplayCard visual compatibility residue: $display_card_retired_visual"
    else
        ok "DisplayCard excludes visual compatibility residue: $display_card_retired_visual"
    fi
done

for display_card_draft_contract in \
    'setEnabled(' \
    'setResolution(' \
    'setRefreshMode(' \
    'setScale(' \
    'setTransform('
do
    if grep -Fq -- "$display_card_draft_contract" \
        "$display_card" 2>/dev/null
    then
        ok "DisplayCard preserved draft mutation: $display_card_draft_contract"
    else
        fail "DisplayCard draft mutation missing: $display_card_draft_contract"
    fi
done

if grep -Fq \
    '## Phase 2A.4.3 — DisplayCard canonical surface migration' \
    "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.3 migration documentation"
else
    fail "Phase 2A.4.3 migration documentation missing"
fi

if grep -Fq \
    '2A.4.2 DisplayView shell/content cleanup                   ✓' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        '2A.4.3 DisplayCard migration to canonical components       ✓' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4 roadmap records DisplayCard migration complete"
else
    fail "Phase 2A.4 roadmap does not record DisplayCard migration complete"
fi


printf '\n==> Phase 2A.4.3 DisplayCard delegate runtime binding\n'

display_view="$config_dir/modules/displays/DisplayView.qml"
display_card="$config_dir/modules/displays/DisplayCard.qml"

for delegate_runtime_contract in \
    'delegate: DisplayCard {' \
    'required property var modelData' \
    'monitor: modelData'
do
    if grep -Fq -- "$delegate_runtime_contract" "$display_view" 2>/dev/null; then
        ok "DisplayCard delegate runtime contract: $delegate_runtime_contract"
    else
        fail "DisplayCard delegate runtime contract missing: $delegate_runtime_contract"
    fi
done

for monitor_guard_contract in \
    'root.monitor' \
    'root.draftStore.enableDisableReason(root.monitor.output)'
do
    if grep -Fq -- "$monitor_guard_contract" "$display_card" 2>/dev/null; then
        ok "DisplayCard monitor lifecycle guard: $monitor_guard_contract"
    else
        fail "DisplayCard monitor lifecycle guard missing: $monitor_guard_contract"
    fi
done


printf '\n==> Phase 2A.4.4 display selection control strategy\n'

display_card="$config_dir/modules/displays/DisplayCard.qml"
display_draft_store="$config_dir/services/DisplayDraftStore.qml"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"

display_card_combo_count="$(
    grep -Fc 'Components.JcComboBox {' "$display_card" 2>/dev/null || true
)"
display_card_slider_count="$(
    grep -Fc 'Components.JcSlider {' "$display_card" 2>/dev/null || true
)"
display_card_choice_count="$(
    grep -Fc 'Components.JcChoiceGroup {' "$display_card" 2>/dev/null || true
)"

if [[ "$display_card_combo_count" == "3" ]]; then
    ok "DisplayCard uses three combo boxes for enumerated settings"
else
    fail "DisplayCard expected 3 JcComboBox controls, found $display_card_combo_count"
fi

if [[ "$display_card_slider_count" == "1" ]]; then
    ok "DisplayCard uses one slider for scale"
else
    fail "DisplayCard expected 1 JcSlider control, found $display_card_slider_count"
fi

if [[ "$display_card_choice_count" == "0" ]]; then
    ok "DisplayCard contains no button-like choice groups"
else
    fail "DisplayCard expected 0 JcChoiceGroup controls, found $display_card_choice_count"
fi

for display_selection_contract in \
    'options: root.resolutionOptions' \
    'selectedValue: root.draft ? root.draft.resolutionKey : ""' \
    'setResolution(root.monitor.output, value)' \
    'options: root.refreshOptions' \
    'selectedValue: root.draft ? root.draft.modeRaw : ""' \
    'setRefreshMode(root.monitor.output, value)' \
    'function scaleIndexForValue(scaleValue)' \
    'Components.JcSlider {' \
    'to: Math.max(0, root.scaleOptions.length - 1)' \
    'stepSize: 1' \
    'onMoved: {' \
    'root.draftStore.setScale(' \
    'options: root.transformOptions' \
    'selectedValue: root.draft ? String(root.draft.transform) : ""' \
    'setTransform(root.monitor.output, value)'
do
    if grep -Fq -- "$display_selection_contract" \
        "$display_card" 2>/dev/null
    then
        ok "DisplayCard selection contract: $display_selection_contract"
    else
        fail "DisplayCard selection contract missing: $display_selection_contract"
    fi
done

for mode_truth_contract in \
    'root.modeParser.parseAll(monitor.availableModes)' \
    'function resolutionOptionsFor(output)' \
    'root.modeParser.uniqueResolutions(draft.modes)' \
    'function refreshOptionsFor(output)' \
    'root.modeParser.modesForResolution(' \
    'function scaleOptionsFor(output)' \
    'function transformOptionsFor(output)'
do
    if grep -Fq -- "$mode_truth_contract" \
        "$display_draft_store" 2>/dev/null
    then
        ok "Display option truth contract: $mode_truth_contract"
    else
        fail "Display option truth contract missing: $mode_truth_contract"
    fi
done

if grep -Fq \
    '## Phase 2A.4.4 — Mode, scale, and transform controls' \
    "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.4 migration documentation"
else
    fail "Phase 2A.4.4 migration documentation missing"
fi

if grep -Fq \
    'Scale          -> JcSlider' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        'Orientation    -> JcComboBox' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.4 documentation uses slider/combo strategy"
else
    fail "Phase 2A.4.4 documentation has stale choice-group strategy"
fi

if grep -Fq \
    '2A.4.3 DisplayCard migration to canonical components       ✓' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        '2A.4.4 Mode / scale / transform controls                   ✓' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4 roadmap records selection controls complete"
else
    fail "Phase 2A.4 roadmap does not record selection controls complete"
fi


printf '\n==> Phase 2A.4.5 layout editor visual integration\n'

display_layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"
retired_display_layout="$config_dir/modules/displays/DisplayLayout.qml"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"

for layout_editor_visual_contract in \
    'Components.JcSurface {' \
    'cornerRadius: root.theme.radiusMd' \
    'contentColumn.implicitHeight' \
    'id: contentColumn' \
    'Components.JcSectionHeader {' \
    'color: root.theme.hudSurface' \
    'root.theme.surfaceSelected' \
    'root.theme.surfaceInteractive' \
    'root.theme.danger' \
    'root.theme.borderAccent' \
    'Components.JcComboBox {' \
    'Components.JcButton {' \
    'root.theme.textSizeBody' \
    'root.theme.textSizeCaption'
do
    if grep -Fq -- "$layout_editor_visual_contract" \
        "$display_layout_editor" 2>/dev/null
    then
        ok "DisplayLayoutEditor visual contract: $layout_editor_visual_contract"
    else
        fail "DisplayLayoutEditor visual contract missing: $layout_editor_visual_contract"
    fi
done

for layout_editor_runtime_contract in \
    'root.draftStore.projectedMonitors()' \
    'root.draftStore.outputHasOverlap(monitor.output)' \
    'root.draftStore.snapPosition(' \
    'root.draftStore.setPosition(' \
    'root.draftStore.snapRelative(' \
    'root.draftStore.topologyValid' \
    'TapHandler {' \
    'DragHandler {' \
    'onClicked: root.snapSelected("left")' \
    'onClicked: root.snapSelected("right")' \
    'onClicked: root.snapSelected("above")' \
    'onClicked: root.snapSelected("below")'
do
    if grep -Fq -- "$layout_editor_runtime_contract" \
        "$display_layout_editor" 2>/dev/null
    then
        ok "DisplayLayoutEditor topology contract: $layout_editor_runtime_contract"
    else
        fail "DisplayLayoutEditor topology contract missing: $layout_editor_runtime_contract"
    fi
done

for layout_editor_residue in \
    'Components.JcCard {' \
    'Components.JcChoiceGroup {' \
    'root.theme.spacingSm' \
    'root.theme.radiusSmall' \
    'root.theme.background' \
    'root.theme.surfaceAlt' \
    'root.theme.error' \
    'font.bold:' \
    '"#'
do
    if grep -Fq -- "$layout_editor_residue" \
        "$display_layout_editor" 2>/dev/null
    then
        fail "DisplayLayoutEditor visual residue remains: $layout_editor_residue"
    else
        ok "DisplayLayoutEditor excludes visual residue: $layout_editor_residue"
    fi
done

layout_rectangle_count="$(
    grep -Fc 'Rectangle {' "$display_layout_editor" 2>/dev/null || true
)"

if [[ "$layout_rectangle_count" == "2" ]]; then
    ok "DisplayLayoutEditor keeps only canvas and monitor geometry rectangles"
else
    fail "DisplayLayoutEditor expected 2 geometry Rectangles, found $layout_rectangle_count"
fi

if [[ -e "$retired_display_layout" ]]; then
    fail "retired DisplayLayout.qml still exists"
else
    ok "unused DisplayLayout.qml retired"
fi

runtime_layout_refs="$(
    grep -RFn \
        --include='*.qml' \
        --exclude='DisplayLayoutEditor.qml' \
        'DisplayLayout {' \
        "$config_dir" 2>/dev/null || true
)"

if [[ -n "$runtime_layout_refs" ]]; then
    fail "runtime still references retired DisplayLayout component"
    printf '%s\n' "$runtime_layout_refs" >&2
else
    ok "no runtime DisplayLayout component references remain"
fi

if grep -Fq \
    '## Phase 2A.4.5 — Layout editor visual integration' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        'DisplayLayout.qml` had no runtime' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.5 migration and retirement documentation"
else
    fail "Phase 2A.4.5 migration documentation missing"
fi

if grep -Fq \
    '2A.4.4 Mode / scale / transform controls                   ✓' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        '2A.4.5 Layout editor visual integration                    ✓' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4 roadmap records layout editor integration complete"
else
    fail "Phase 2A.4 roadmap does not record layout editor integration complete"
fi


printf '\n==> Phase 2A.4.6 Safe Apply and persistence presentation\n'

display_view="$config_dir/modules/displays/DisplayView.qml"
apply_service="$config_dir/services/MonitorApplyService.qml"
persistence_service="$config_dir/services/DisplayPersistenceService.qml"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"

for safe_apply_presentation_contract in \
    'title: "Safe Apply confirmation"' \
    'root.applyService.pendingOutput' \
    'root.applyService.remainingSeconds' \
    'root.theme.warningSurface' \
    'root.theme.warningBorder' \
    'text: root.applyService && root.applyService.keeping' \
    'onClicked: root.keepRequested()' \
    'onClicked: root.rollbackRequested()'
do
    if grep -Fq -- "$safe_apply_presentation_contract" \
        "$display_view" 2>/dev/null
    then
        ok "Safe Apply presentation contract: $safe_apply_presentation_contract"
    else
        fail "Safe Apply presentation contract missing: $safe_apply_presentation_contract"
    fi
done

for feedback_surface_contract in \
    'root.theme.successSurface' \
    'root.theme.successBorder' \
    'root.theme.warningSurface' \
    'root.theme.warningBorder' \
    'root.theme.dangerSurface' \
    'root.theme.dangerBorder' \
    'root.theme.infoSurface' \
    'root.theme.infoBorder'
do
    if grep -Fq -- "$feedback_surface_contract" "$display_view" 2>/dev/null
    then
        ok "Display feedback semantic token: $feedback_surface_contract"
    else
        fail "Display feedback semantic token missing: $feedback_surface_contract"
    fi
done

for persistence_presentation_contract in \
    'title: "Persistent configuration"' \
    'root.persistenceService.checking' \
    'root.persistenceService.saving' \
    'root.persistenceService.hasPersistentChanges' \
    'root.persistenceService.statusMessage' \
    'root.persistenceService.lastBackup' \
    'root.persistenceService.canSave' \
    'Save Configuration' \
    'onClicked: root.saveRequested()'
do
    if grep -Fq -- "$persistence_presentation_contract" \
        "$display_view" 2>/dev/null
    then
        ok "Persistence presentation contract: $persistence_presentation_contract"
    else
        fail "Persistence presentation contract missing: $persistence_presentation_contract"
    fi
done

for preserved_display_action in \
    'signal refreshRequested()' \
    'signal resetRequested()' \
    'signal applyRequested()' \
    'signal keepRequested()' \
    'signal rollbackRequested()' \
    'signal saveRequested()'
do
    if grep -Fq -- "$preserved_display_action" "$display_view" 2>/dev/null
    then
        ok "Display action boundary preserved: $preserved_display_action"
    else
        fail "Display action boundary missing: $preserved_display_action"
    fi
done

for safe_apply_service_contract in \
    'property bool pendingConfirmation: false' \
    'property int remainingSeconds: 0' \
    'function applyDirty(): void' \
    'function keepPending(): void' \
    'function rollbackPending(reason): void'
do
    if grep -Fq -- "$safe_apply_service_contract" \
        "$apply_service" 2>/dev/null
    then
        ok "Safe Apply service boundary preserved: $safe_apply_service_contract"
    else
        fail "Safe Apply service boundary missing: $safe_apply_service_contract"
    fi
done

for persistence_service_contract in \
    'property bool checking: false' \
    'property bool saving: false' \
    'property bool hasPersistentChanges: false' \
    'property string lastBackup: ""' \
    'readonly property bool canSave:' \
    'function saveConfiguration(): void'
do
    if grep -Fq -- "$persistence_service_contract" \
        "$persistence_service" 2>/dev/null
    then
        ok "Persistence service boundary preserved: $persistence_service_contract"
    else
        fail "Persistence service boundary missing: $persistence_service_contract"
    fi
done

for display_view_forbidden_runtime_contract in \
    'Process {' \
    'hyprctl' \
    'systemd-run' \
    'jc-displaycfg' \
    'jc-displayctl'
do
    if grep -Fq -- "$display_view_forbidden_runtime_contract" \
        "$display_view" 2>/dev/null
    then
        fail "DisplayView must not own runtime mutation: $display_view_forbidden_runtime_contract"
    else
        ok "DisplayView excludes runtime mutation: $display_view_forbidden_runtime_contract"
    fi
done

if grep -Fq \
    '## Phase 2A.4.6 — Safe Apply and persistence presentation' \
    "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.6 migration documentation"
else
    fail "Phase 2A.4.6 migration documentation missing"
fi

if grep -Fq \
    '2A.4.5 Layout editor visual integration                    ✓' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        '2A.4.6 Safe Apply / persistence presentation               ✓' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4 roadmap records Safe Apply presentation complete"
else
    fail "Phase 2A.4 roadmap does not record Safe Apply presentation complete"
fi


printf '\n==> Phase 2A.4.7 visual compatibility retirement\n'

theme_qml="$config_dir/theme/Theme.qml"
legacy_card="$config_dir/components/JcCard.qml"
component_gallery="$config_dir/modules/dev/ComponentGallery.qml"
display_dir="$config_dir/modules/displays"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"

if [[ ! -e "$legacy_card" ]]; then
    ok "JcCard compatibility component retired"
else
    fail "JcCard compatibility component still exists"
fi

jc_card_runtime_refs="$(
    grep -RInE \
        --include='*.qml' \
        'Components\.JcCard|JcCard[[:space:]]*\{' \
        "$config_dir" \
        2>/dev/null ||
        true
)"

if [[ -z "$jc_card_runtime_refs" ]]; then
    ok "runtime QML contains no JcCard consumers"
else
    fail "runtime QML still contains JcCard consumers:"
    printf '%s\n' "$jc_card_runtime_refs" >&2
fi

for retired_theme_alias in \
    'readonly property color background: canvas' \
    'readonly property color surface: surfaceBase' \
    'readonly property color surfaceAlt: surfaceRaised' \
    'readonly property color border: borderDefault' \
    'readonly property color error: danger' \
    'readonly property color glass: surfaceGlass' \
    'readonly property color glassLight: surfaceGlassRaised' \
    'readonly property color glassHover: surfaceHover' \
    'readonly property color glassBorder: borderSubtle' \
    'readonly property int radiusSmall: radiusSm' \
    'readonly property int radiusMedium: radiusMd' \
    'readonly property int radiusLarge: radiusLg' \
    'readonly property int spacingXs: spaceXs' \
    'readonly property int spacingSm: spaceSm' \
    'readonly property int spacingMd: spaceMd' \
    'readonly property int spacingLg: spaceLg'
do
    if grep -Fq -- "$retired_theme_alias" "$theme_qml" 2>/dev/null; then
        fail "Theme compatibility alias still exists: $retired_theme_alias"
    else
        ok "Theme compatibility alias retired: $retired_theme_alias"
    fi
done

display_legacy_aliases="$(
    grep -RInE \
        --include='*.qml' \
        'theme\.(background|surface|surfaceAlt|border|error|glass|glassLight|glassHover|glassBorder|radiusSmall|radiusMedium|radiusLarge|spacingXs|spacingSm|spacingMd|spacingLg)([^a-zA-Z0-9_]|$)' \
        "$display_dir" \
        2>/dev/null ||
        true
)"

if [[ -z "$display_legacy_aliases" ]]; then
    ok "production Displays contains no legacy Theme alias dependency"
else
    fail "production Displays still contains legacy Theme aliases:"
    printf '%s\n' "$display_legacy_aliases" >&2
fi

if grep -Fq 'Components.JcSurface {' "$component_gallery" 2>/dev/null \
    && ! grep -Fq 'Components.JcCard {' "$component_gallery" 2>/dev/null
then
    ok "Component Gallery uses JcSurface instead of JcCard"
else
    fail "Component Gallery still depends on JcCard compatibility"
fi

if grep -Fq \
    '## Phase 2A.4.7 — Retire Displays visual compatibility layer' \
    "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.7 migration documentation"
else
    fail "Phase 2A.4.7 migration documentation missing"
fi

if grep -Fq \
    '2A.4.6 Safe Apply / persistence presentation               ✓' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        '2A.4.7 Retire Displays visual compatibility layer          ✓' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4 roadmap records compatibility retirement complete"
else
    fail "Phase 2A.4 roadmap does not record compatibility retirement complete"
fi


printf '\n==> Phase 2A.4.8 responsive and keyboard Displays contract\n'

display_view="$config_dir/modules/displays/DisplayView.qml"
display_card="$config_dir/modules/displays/DisplayCard.qml"
display_layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"
jc_button="$config_dir/components/JcButton.qml"
jc_combo_box="$config_dir/components/JcComboBox.qml"
jc_slider="$config_dir/components/JcSlider.qml"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"

for retired_hosted_dimension in \
    'implicitWidth: 820' \
    'implicitHeight: 700'
do
    if grep -Fq -- "$retired_hosted_dimension" "$display_view" 2>/dev/null; then
        fail "DisplayView still owns standalone geometry: $retired_hosted_dimension"
    else
        ok "DisplayView excludes standalone geometry: $retired_hosted_dimension"
    fi
done

for hosted_overflow_contract in \
    'Flickable {' \
    'Layout.fillWidth: true' \
    'Layout.fillHeight: true' \
    'contentWidth: width' \
    'contentHeight: contentColumn.implicitHeight'
do
    if grep -Fq -- "$hosted_overflow_contract" "$display_view" 2>/dev/null; then
        ok "DisplayView hosted overflow contract: $hosted_overflow_contract"
    else
        fail "DisplayView hosted overflow contract missing: $hosted_overflow_contract"
    fi
done

for topology_keyboard_contract in \
    'readonly property var selectedOptions:' \
    'root.buildSelectedOptions()' \
    'function buildSelectedOptions() {' \
    'property string selectedOutput: ""' \
    'options: root.selectedOptions' \
    'selectedValue: root.selectedOutput' \
    'root.selectOutput(value)' \
    'options: root.anchorOptions' \
    'selectedValue: root.anchorOutput' \
    'root.snapSelected("left")' \
    'root.snapSelected("right")' \
    'root.snapSelected("above")' \
    'root.snapSelected("below")'
do
    if grep -Fq -- "$topology_keyboard_contract" \
        "$display_layout_editor" 2>/dev/null
    then
        ok "DisplayLayoutEditor keyboard topology contract: $topology_keyboard_contract"
    else
        fail "DisplayLayoutEditor keyboard topology contract missing: $topology_keyboard_contract"
    fi
done

for topology_responsive_contract in \
    'readonly property real compactLayoutThreshold:' \
    '(root.theme.controlHeightLarge * 8)' \
    'readonly property bool compactLayout:' \
    'columns: root.compactLayout ? 1 : 2' \
    'columns: root.compactLayout ? 2 : 4' \
    'columnSpacing: root.theme.spaceMd' \
    'rowSpacing: root.theme.spaceXs'
do
    if grep -Fq -- "$topology_responsive_contract" \
        "$display_layout_editor" 2>/dev/null
    then
        ok "DisplayLayoutEditor responsive contract: $topology_responsive_contract"
    else
        fail "DisplayLayoutEditor responsive contract missing: $topology_responsive_contract"
    fi
done

if grep -Fq 'if (!monitor || monitor.disabled)' \
    "$display_layout_editor" 2>/dev/null \
    && grep -Fq '&& !monitor.disabled' \
        "$display_layout_editor" 2>/dev/null
then
    ok "DisplayLayoutEditor keyboard selection excludes disabled outputs"
else
    fail "DisplayLayoutEditor disabled-output keyboard guard missing"
fi

for canonical_keyboard_contract in \
    "$jc_button|activeFocusOnTab: root.controlEnabled" \
    "$jc_button|event.key === Qt.Key_Return" \
    "$jc_button|event.key === Qt.Key_Space" \
    "$jc_combo_box|focusPolicy: Qt.StrongFocus" \
    "$jc_slider|focusPolicy: Qt.StrongFocus"
do
    keyboard_file="${canonical_keyboard_contract%%|*}"
    keyboard_pattern="${canonical_keyboard_contract#*|}"

    if grep -Fq -- "$keyboard_pattern" "$keyboard_file" 2>/dev/null; then
        ok "$(basename "$keyboard_file") keyboard baseline: $keyboard_pattern"
    else
        fail "$(basename "$keyboard_file") keyboard baseline missing: $keyboard_pattern"
    fi
done

display_keyboard_components="$(
    grep -c 'Components.JcComboBox {' "$display_card" 2>/dev/null || true
)"
layout_keyboard_components="$(
    grep -c 'Components.JcComboBox {' "$display_layout_editor" 2>/dev/null || true
)"

if [[ "$display_keyboard_components" == "3" ]]; then
    ok "DisplayCard keeps three keyboard-capable enumerated controls"
else
    fail "DisplayCard keyboard control count changed unexpectedly: $display_keyboard_components"
fi

if [[ "$layout_keyboard_components" == "2" ]]; then
    ok "DisplayLayoutEditor exposes selected and anchor keyboard selectors"
else
    fail "DisplayLayoutEditor expected 2 JcComboBox controls, found $layout_keyboard_components"
fi

if grep -Fq \
    '## Phase 2A.4.8 — Responsive, keyboard, and visual validation' \
    "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4.8 migration documentation"
else
    fail "Phase 2A.4.8 migration documentation missing"
fi

if grep -Fq \
    '2A.4.7 Retire Displays visual compatibility layer          ✓' \
    "$displays_visual_doc" 2>/dev/null \
    && grep -Fq \
        '2A.4.8 Responsive + keyboard + visual validation           ✓' \
        "$displays_visual_doc" 2>/dev/null
then
    ok "Phase 2A.4 roadmap records responsive keyboard validation complete"
else
    fail "Phase 2A.4 roadmap does not record responsive keyboard validation complete"
fi


printf '\n==> Phase 2A.4.9 Displays visual redesign closure\n'

readme="$repo_root/README.md"
architecture_doc="$repo_root/docs/architecture.md"
component_library_doc="$repo_root/docs/component-library.md"
design_system_doc="$repo_root/docs/design-system.md"
displays_visual_doc="$repo_root/docs/displays-visual-redesign.md"
display_view="$config_dir/modules/displays/DisplayView.qml"
display_card="$config_dir/modules/displays/DisplayCard.qml"
display_layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"
legacy_card="$config_dir/components/JcCard.qml"

for phase_2a4_readme_contract in \
    '- [x] **Phase 2A.4 — Displays visual redesign**' \
    '- [ ] **Phase 2B — Wallpapers** ← **NEXT**' \
    'added responsive layout and keyboard-complete topology interaction' \
    'retired the Phase 1 visual compatibility layer'
do
    if grep -Fq -- "$phase_2a4_readme_contract" "$readme" 2>/dev/null; then
        ok "Phase 2A.4 README closure: $phase_2a4_readme_contract"
    else
        fail "Phase 2A.4 README closure missing: $phase_2a4_readme_contract"
    fi
done

for phase_2a4_architecture_contract in \
    'Phase 2A  Shared visual platform                 ✓ COMPLETE' \
    '2A.4  Displays visual redesign           ✓' \
    'Wallpapers  ← NEXT' \
    "compatibilidad visual Phase 1 (\`JcCard\` y aliases legacy del Theme API) fue"
do
    if grep -Fq -- "$phase_2a4_architecture_contract" \
        "$architecture_doc" 2>/dev/null
    then
        ok "Phase 2A.4 architecture closure: $phase_2a4_architecture_contract"
    else
        fail "Phase 2A.4 architecture closure missing: $phase_2a4_architecture_contract"
    fi
done

for phase_2a4_component_doc_contract in \
    '## Compatibility retirement' \
    'The Phase 1 Theme API compatibility aliases were retired at the same boundary.' \
    'retired Phase 1 visual compatibility boundary'
do
    if grep -Fq -- "$phase_2a4_component_doc_contract" \
        "$component_library_doc" 2>/dev/null
    then
        ok "component-library closure: $phase_2a4_component_doc_contract"
    else
        fail "component-library closure missing: $phase_2a4_component_doc_contract"
    fi
done

for phase_2a4_design_doc_contract in \
    "The former \`JcCard\` compatibility exception was retired in Phase 2A.4.7" \
    'canonical semantic Theme API is now the only'
do
    if grep -Fq -- "$phase_2a4_design_doc_contract" \
        "$design_system_doc" 2>/dev/null
    then
        ok "design-system closure: $phase_2a4_design_doc_contract"
    else
        fail "design-system closure missing: $phase_2a4_design_doc_contract"
    fi
done

for phase_2a4_final_doc_contract in \
    '2A.4.8 Responsive + keyboard + visual validation           ✓' \
    '2A.4.9 Quality gates + documentation                       ✓ COMPLETE' \
    '## Phase 2A.4.9 — Quality gates and documentation' \
    '2A.4 Displays visual redesign                  ✓ COMPLETE' \
    '2B   Wallpapers                                ← NEXT'
do
    if grep -Fq -- "$phase_2a4_final_doc_contract" \
        "$displays_visual_doc" 2>/dev/null
    then
        ok "Displays closure documentation: $phase_2a4_final_doc_contract"
    else
        fail "Displays closure documentation missing: $phase_2a4_final_doc_contract"
    fi
done

for stale_phase_2a4_marker in \
    '- [ ] **Phase 2A.4 — Displays visual redesign** ← **NEXT**' \
    '2A.4  Displays visual redesign           ← NEXT' \
    '2A.4.8 Responsive + keyboard + visual validation           ← CURRENT' \
    "\`JcCard\` remains available until" \
    "\`JcCard\` permanece como compatibilidad Phase 1"
do
    stale_phase_2a4_refs="$(
        grep -RFn \
            --include='*.md' \
            -- "$stale_phase_2a4_marker" \
            "$repo_root/README.md" \
            "$repo_root/docs" \
            2>/dev/null || true
    )"

    if [[ -z "$stale_phase_2a4_refs" ]]; then
        ok "stale Phase 2A.4 marker retired: $stale_phase_2a4_marker"
    else
        fail "stale Phase 2A.4 marker remains: $stale_phase_2a4_marker"
        printf '%s\n' "$stale_phase_2a4_refs" >&2
    fi
done

if grep -Fq 'JcCard.qml' "$readme" 2>/dev/null; then
    fail "README repository tree still lists retired JcCard.qml"
else
    ok "README repository tree excludes retired JcCard.qml"
fi

if [[ -e "$legacy_card" ]]; then
    fail "retired JcCard.qml exists"
else
    ok "retired JcCard.qml remains absent"
fi

display_panel_windows="$(
    grep -RInE \
        --include='*.qml' \
        'PanelWindow[[:space:]]*\{' \
        "$config_dir/modules/displays" \
        2>/dev/null || true
)"

if [[ -z "$display_panel_windows" ]]; then
    ok "Displays remains hosted and owns no PanelWindow"
else
    fail "Displays unexpectedly owns a PanelWindow:"
    printf '%s\n' "$display_panel_windows" >&2
fi

display_card_combo_count="$(
    grep -Fc 'Components.JcComboBox {' "$display_card" 2>/dev/null || true
)"
display_card_slider_count="$(
    grep -Fc 'Components.JcSlider {' "$display_card" 2>/dev/null || true
)"
layout_editor_combo_count="$(
    grep -Fc 'Components.JcComboBox {' "$display_layout_editor" 2>/dev/null || true
)"

if [[ "$display_card_combo_count" == "3" \
    && "$display_card_slider_count" == "1" \
    && "$layout_editor_combo_count" == "2" ]]
then
    ok "final Displays control strategy: 3 combo + 1 slider + 2 topology selectors"
else
    fail "final Displays control strategy changed unexpectedly: card_combo=$display_card_combo_count card_slider=$display_card_slider_count layout_combo=$layout_editor_combo_count"
fi

for final_display_runtime_residue in \
    'Process {' \
    'hyprctl' \
    'systemd-run' \
    'jc-displaycfg' \
    'jc-displayctl'
do
    final_runtime_refs="$(
        grep -RFn \
            --include='*.qml' \
            -- "$final_display_runtime_residue" \
            "$config_dir/modules/displays" \
            2>/dev/null || true
    )"

    if [[ -z "$final_runtime_refs" ]]; then
        ok "final Displays presentation excludes runtime mutation: $final_display_runtime_residue"
    else
        fail "final Displays presentation contains runtime mutation: $final_display_runtime_residue"
        printf '%s\n' "$final_runtime_refs" >&2
    fi
done


printf '\n==> H1.3.3 JC Holo Control Center HUD integration\n'

jc_hud_frame="$config_dir/components/JcHudFrame.qml"
control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
display_card="$config_dir/modules/displays/DisplayCard.qml"
display_layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"
display_view="$config_dir/modules/displays/DisplayView.qml"

if [[ -f "$jc_hud_frame" ]]; then
    ok "JcHudFrame presentation primitive"
else
    fail "JcHudFrame presentation primitive missing"
fi

for hud_contract in \
    'property bool fillEnabled: true' \
    'property color primaryAccentColor:' \
    'property color secondaryAccentColor:' \
    'if (root.fillEnabled)' \
    'root.primaryAccentColor' \
    'root.secondaryAccentColor'
do
    if grep -Fq -- "$hud_contract" "$jc_hud_frame" 2>/dev/null; then
        ok "JcHudFrame H1.3.3 contract: $hud_contract"
    else
        fail "JcHudFrame H1.3.3 contract missing: $hud_contract"
    fi
done

for forbidden_hud_runtime in \
    'Process {' \
    'hyprctl' \
    'systemctl' \
    'systemd-run' \
    'jc-displayctl' \
    'jc-displaycfg'
do
    if grep -Fq -- "$forbidden_hud_runtime" "$jc_hud_frame" 2>/dev/null; then
        fail "JcHudFrame must remain presentation-only: $forbidden_hud_runtime"
    else
        ok "JcHudFrame excludes runtime mutation: $forbidden_hud_runtime"
    fi
done

for shell_hud_contract in \
    'id: shellSurface' \
    'surfaceRole: "glass-raised"' \
    'id: shellHudFrame' \
    'fillEnabled: false' \
    'cutSize: root.theme.spaceLg'
do
    if grep -Fq -- "$shell_hud_contract" "$control_center_shell" 2>/dev/null; then
        ok "ControlCenter shell HUD contract: $shell_hud_contract"
    else
        fail "ControlCenter shell HUD contract missing: $shell_hud_contract"
    fi
done

for navigation_hud_contract in \
    'id: navigationSurface' \
    'surfaceRole: "glass"' \
    'id: navigationHudFrame' \
    'showSecondaryAccent: false'
do
    if grep -Fq -- "$navigation_hud_contract" \
        "$control_center_navigation" 2>/dev/null
    then
        ok "ControlCenter navigation HUD contract: $navigation_hud_contract"
    else
        fail "ControlCenter navigation HUD contract missing: $navigation_hud_contract"
    fi
done

for display_card_hud_contract in \
    'Components.JcSurface {' \
    'surfaceRole: "glass"' \
    'id: displayCardHudFrame' \
    'root.monitor.focused' \
    'root.draft.dirty'
do
    if grep -Fq -- "$display_card_hud_contract" "$display_card" 2>/dev/null; then
        ok "DisplayCard HUD contract: $display_card_hud_contract"
    else
        fail "DisplayCard HUD contract missing: $display_card_hud_contract"
    fi
done

for layout_hud_contract in \
    'Components.JcSurface {' \
    'surfaceRole: "glass"' \
    'id: layoutHudFrame' \
    'showSecondaryAccent: false'
do
    if grep -Fq -- "$layout_hud_contract" \
        "$display_layout_editor" 2>/dev/null
    then
        ok "DisplayLayoutEditor HUD contract: $layout_hud_contract"
    else
        fail "DisplayLayoutEditor HUD contract missing: $layout_hud_contract"
    fi
done

for display_view_hud_contract in \
    'id: safeApplyHudFrame' \
    'primaryAccentColor: root.theme.warning' \
    'id: persistenceHudFrame' \
    'root.persistenceService.hasPersistentChanges'
do
    if grep -Fq -- "$display_view_hud_contract" "$display_view" 2>/dev/null; then
        ok "DisplayView HUD feedback contract: $display_view_hud_contract"
    else
        fail "DisplayView HUD feedback contract missing: $display_view_hud_contract"
    fi
done


printf '\n==> H1.3.3b true angular HUD material\n'

jc_surface="$config_dir/components/JcSurface.qml"
jc_hud_frame="$config_dir/components/JcHudFrame.qml"
control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
display_card="$config_dir/modules/displays/DisplayCard.qml"
display_layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"
display_view="$config_dir/modules/displays/DisplayView.qml"

for surface_material_contract in \
    'property bool fillEnabled: true' \
    'root.theme.transparentSurface'
do
    if grep -Fq -- "$surface_material_contract" "$jc_surface" 2>/dev/null; then
        ok "JcSurface material delegation contract: $surface_material_contract"
    else
        fail "JcSurface material delegation contract missing: $surface_material_contract"
    fi
done

for hud_material_contract in \
    'property color fillColor:' \
    'ctx.fillStyle = root.fillColor'
do
    if grep -Fq -- "$hud_material_contract" "$jc_hud_frame" 2>/dev/null; then
        ok "JcHudFrame material contract: $hud_material_contract"
    else
        fail "JcHudFrame material contract missing: $hud_material_contract"
    fi
done

for shell_material_contract in \
    'id: shellSurface' \
    'fillEnabled: false' \
    'id: shellHudFrame' \
    'fillColor: root.theme.surfaceGlassRaised'
do
    if grep -Fq -- "$shell_material_contract" "$control_center_shell" 2>/dev/null; then
        ok "ControlCenter angular material contract: $shell_material_contract"
    else
        fail "ControlCenter angular material contract missing: $shell_material_contract"
    fi
done

for navigation_material_contract in \
    'id: navigationSurface' \
    'fillEnabled: false' \
    'id: navigationHudFrame' \
    'fillColor: root.theme.surfaceGlass'
do
    if grep -Fq -- "$navigation_material_contract" \
        "$control_center_navigation" 2>/dev/null
    then
        ok "Navigation angular material contract: $navigation_material_contract"
    else
        fail "Navigation angular material contract missing: $navigation_material_contract"
    fi
done

for displays_material_contract in \
    'id: displayCardHudFrame' \
    'fillColor: root.theme.hudSurface' \
    'id: layoutHudFrame'
do
    if grep -Fq -- "$displays_material_contract" "$display_card" 2>/dev/null \
        || grep -Fq -- "$displays_material_contract" \
            "$display_layout_editor" 2>/dev/null
    then
        ok "Displays angular material contract: $displays_material_contract"
    else
        fail "Displays angular material contract missing: $displays_material_contract"
    fi
done

for feedback_material_contract in \
    'id: safeApplyHudFrame' \
    'fillColor: root.theme.warningSurface' \
    'id: persistenceHudFrame' \
    'return root.theme.infoSurface;' \
    'return root.theme.warningSurface;' \
    'return root.theme.hudSurface;'
do
    if grep -Fq -- "$feedback_material_contract" "$display_view" 2>/dev/null; then
        ok "Display feedback angular material contract: $feedback_material_contract"
    else
        fail "Display feedback angular material contract missing: $feedback_material_contract"
    fi
done


printf '\n==> H1.3.4 JC Holo visual polish\n'

jc_hud_frame="$config_dir/components/JcHudFrame.qml"
control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
jc_nav_item="$config_dir/components/JcNavItem.qml"
display_view="$config_dir/modules/displays/DisplayView.qml"

for hud_polish_contract in \
    'property color frameColor:' \
    'ctx.strokeStyle = root.frameColor'
do
    if grep -Fq -- "$hud_polish_contract" "$jc_hud_frame" 2>/dev/null; then
        ok "JcHudFrame polish contract: $hud_polish_contract"
    else
        fail "JcHudFrame polish contract missing: $hud_polish_contract"
    fi
done

for shell_polish_contract in \
    'id: headerHudIndicator' \
    'id: headerHudConnector' \
    'id: headerHudCore' \
    'subtitle: root.activeModuleTitle' \
    'id: statusHudIndicator' \
    '? root.theme.warning' \
    ': root.theme.success'
do
    if grep -Fq -- "$shell_polish_contract" "$control_center_shell" 2>/dev/null; then
        ok "ControlCenter shell polish contract: $shell_polish_contract"
    else
        fail "ControlCenter shell polish contract missing: $shell_polish_contract"
    fi
done

if grep -Fq -- 'id: navItem' \
    "$control_center_navigation" 2>/dev/null
then
    ok "Navigation polish contract: id: navItem"
else
    fail "Navigation polish contract missing: id: navItem"
fi

for nav_item_selected_state_contract in \
    'property bool selected: false' \
    'readonly property color resolvedSurfaceColor:' \
    'readonly property color resolvedBorderColor:'
do
    if grep -Fq -- "$nav_item_selected_state_contract" "$jc_nav_item" 2>/dev/null; then
        ok "JcNavItem selected-state contract: $nav_item_selected_state_contract"
    else
        fail "JcNavItem selected-state contract missing: $nav_item_selected_state_contract"
    fi
done

if grep -Fq 'id: selectedHudAccent' "$jc_nav_item" 2>/dev/null; then
    fail "JcNavItem still contains selectedHudAccent overlay"
else
    ok "JcNavItem selected state has no detached HUD glint overlay"
fi

for persistence_polish_contract in \
    'id: persistenceHudFrame' \
    'bordered: true' \
    'frameColor: {' \
    'return root.theme.infoBorder;' \
    'return root.theme.warningBorder;' \
    'return root.theme.borderSubtle;'
do
    if grep -Fq -- "$persistence_polish_contract" "$display_view" 2>/dev/null; then
        ok "Persistence polish contract: $persistence_polish_contract"
    else
        fail "Persistence polish contract missing: $persistence_polish_contract"
    fi
done


printf '\n==> H1.3.4a integrated HUD glints\n'

jc_hud_frame="$config_dir/components/JcHudFrame.qml"

for glint_contract in \
    'function drawGlint(' \
    'ctx.createLinearGradient(' \
    'haloGradient.addColorStop(' \
    'coreGradient.addColorStop(' \
    'property real glintIntensity:' \
    'property real glintCoreWidth:' \
    'property real glintHaloWidth:' \
    'root.drawGlint(' \
    'ctx.strokeStyle = root.frameColor'
do
    if grep -Fq -- "$glint_contract" "$jc_hud_frame" 2>/dev/null; then
        ok "HUD glint contract: $glint_contract"
    else
        fail "HUD glint contract missing: $glint_contract"
    fi
done

for forbidden_glint_residue in \
    'ctx.moveTo(margin, root.frameWidth)' \
    'ctx.lineTo(root.width - margin, root.height - root.frameWidth)'
do
    if grep -Fq -- "$forbidden_glint_residue" "$jc_hud_frame" 2>/dev/null; then
        fail "legacy solid HUD accent remains: $forbidden_glint_residue"
    else
        ok "legacy solid HUD accent retired: $forbidden_glint_residue"
    fi
done


printf '\n==> H1.3.4b HUD cleanup and translucent inner materials\n'

control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
jc_nav_item="$config_dir/components/JcNavItem.qml"
display_layout_editor="$config_dir/modules/displays/DisplayLayoutEditor.qml"
display_view="$config_dir/modules/displays/DisplayView.qml"

if grep -Fq 'id: selectedHudAccent' "$jc_nav_item" 2>/dev/null; then
    fail "JcNavItem selectedHudAccent overlay remains"
else
    ok "JcNavItem selected HUD glint overlay retired"
fi

if grep -Fq 'id: activeHudAccent' \
    "$control_center_navigation" 2>/dev/null
then
    fail "navigation-local activeHudAccent still exists"
else
    ok "navigation-local activeHudAccent retired"
fi

for topology_glass_contract in \
    'id: canvas' \
    'color: root.theme.hudSurface' \
    'border.color: root.theme.hudInnerFrame'
do
    if grep -Fq -- "$topology_glass_contract" \
        "$display_layout_editor" 2>/dev/null
    then
        ok "Topology canvas glass contract: $topology_glass_contract"
    else
        fail "Topology canvas glass contract missing: $topology_glass_contract"
    fi
done

transparent_feedback_surface_count="$(
    grep -Fc 'color: root.theme.transparentSurface' \
        "$display_view" 2>/dev/null || true
)"

if ((transparent_feedback_surface_count >= 2)); then
    ok "Safe Apply and persistence parent materials are transparent"
else
    fail "expected at least 2 transparent HUD parent materials, found $transparent_feedback_surface_count"
fi

for persistence_glass_contract in \
    'id: persistenceHudFrame' \
    'return root.theme.hudSurface;'
do
    if grep -Fq -- "$persistence_glass_contract" \
        "$display_view" 2>/dev/null
    then
        ok "Persistence glass contract: $persistence_glass_contract"
    else
        fail "Persistence glass contract missing: $persistence_glass_contract"
    fi
done

if grep -Fq 'color: root.theme.surfaceSunken' \
    "$display_layout_editor" 2>/dev/null
then
    fail "opaque topology canvas surfaceSunken material remains"
else
    ok "opaque topology canvas surfaceSunken material retired"
fi


printf '\n==> H1.3.4c canonical JcNavItem selected-state ownership\n'

jc_nav_item="$config_dir/components/JcNavItem.qml"
control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"

for nav_item_selected_contract in \
    'property bool selected: false' \
    'readonly property color resolvedSurfaceColor:' \
    'readonly property color resolvedBorderColor:' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlBorderSelected' \
    'root.theme.controlTextSelected'
do
    if grep -Fq -- "$nav_item_selected_contract" "$jc_nav_item" 2>/dev/null; then
        ok "JcNavItem selected-state ownership: $nav_item_selected_contract"
    else
        fail "JcNavItem selected-state ownership missing: $nav_item_selected_contract"
    fi
done

for retired_nav_overlay in \
    'id: activeHudAccent' \
    'id: selectedHudAccent' \
    'showSelectedHudAccent'
do
    if grep -RFq -- "$retired_nav_overlay" \
        "$control_center_navigation" "$jc_nav_item" 2>/dev/null
    then
        fail "retired navigation overlay remains: $retired_nav_overlay"
    else
        ok "retired navigation overlay absent: $retired_nav_overlay"
    fi
done

printf '\n==> H1.3.4d canonical opacity token cleanup\n'

jc_nav_item="$config_dir/components/JcNavItem.qml"
control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"

if grep -Fq 'root.theme.opacityEnabled' "$jc_nav_item" 2>/dev/null; then
    ok "JcNavItem uses canonical opacityEnabled"
else
    fail "JcNavItem canonical opacityEnabled missing"
fi

if grep -Fq 'root.theme.opacityDisabled' "$control_center_shell" 2>/dev/null; then
    ok "ControlCenterShell HUD connector uses canonical opacityDisabled"
else
    fail "ControlCenterShell HUD connector canonical opacityDisabled missing"
fi

undefined_holo_opacity_refs="$(
    grep -RFn \
        --include='*.qml' \
        -e 'root.theme.opacityStrong' \
        -e 'root.theme.opacityMuted' \
        "$config_dir" 2>/dev/null || true
)"

if [[ -n "$undefined_holo_opacity_refs" ]]; then
    fail "undefined H1 HUD opacity aliases remain:"
    printf '%s\n' "$undefined_holo_opacity_refs" >&2
else
    ok "undefined H1 HUD opacity aliases retired"
fi


printf '\n==> H1.3.4e navigation selected-glint retirement\n'

jc_nav_item="$config_dir/components/JcNavItem.qml"
control_center_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"

for retired_selected_glint_contract in \
    'id: activeHudAccent' \
    'id: selectedHudAccent' \
    'showSelectedHudAccent'
do
    if grep -RFq -- "$retired_selected_glint_contract" \
        "$jc_nav_item" "$control_center_navigation" 2>/dev/null
    then
        fail "selected navigation glint residue remains: $retired_selected_glint_contract"
    else
        ok "selected navigation glint residue retired: $retired_selected_glint_contract"
    fi
done

printf '\n==> H1.3.5 centered Control Center presentation\n'

jc_nav_item="$config_dir/components/JcNavItem.qml"
control_center_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
main_qml="$config_dir/Main.qml"

for nav_rail_contract in \
    'id: selectionIndicator' \
    'anchors.verticalCenter: parent.verticalCenter' \
    'height: Math.max(' \
    'root.height - (root.theme.spaceMd * 2)'
do
    if grep -Fq -- "$nav_rail_contract" "$jc_nav_item" 2>/dev/null; then
        ok "JcNavItem compact selected rail: $nav_rail_contract"
    else
        fail "JcNavItem compact selected rail missing: $nav_rail_contract"
    fi
done

for centered_shell_contract in \
    'property bool requestedVisible: false' \
    'property bool mounted: false' \
    'property var presentationScreen: null' \
    'readonly property real closedPresentationScale: 0.985' \
    'visible: root.mounted' \
    'root.presentationScreen' \
    'onRequestedVisibleChanged: {' \
    'onTargetScreenChanged: {' \
    'id: shellEnterAnimation' \
    'id: shellExitAnimation' \
    'property: "scale"' \
    'transformOrigin: Item.Center' \
    'duration: root.theme.motionPanel'
do
    if grep -Fq -- "$centered_shell_contract" "$control_center_shell" 2>/dev/null; then
        ok "ControlCenter centered-presentation contract: $centered_shell_contract"
    else
        fail "ControlCenter centered-presentation contract missing: $centered_shell_contract"
    fi
done

for retired_edge_contract in \
    'top: true' \
    'right: true' \
    'id: shellTranslate'
do
    if grep -Fq -- "$retired_edge_contract" "$control_center_shell" 2>/dev/null; then
        fail "retired edge/slide presentation remains: $retired_edge_contract"
    else
        ok "retired edge/slide presentation absent: $retired_edge_contract"
    fi
done

if grep -Fq \
    'requestedVisible: root.controlCenterVisible' \
    "$main_qml" 2>/dev/null
then
    ok "Main preserves Control Center requested-visibility ownership"
else
    fail "Main requested-visibility binding missing"
fi

if grep -Fq \
    'visible: root.controlCenterVisible' \
    "$main_qml" 2>/dev/null
then
    fail "Main still directly unmounts ControlCenterShell"
else
    ok "ControlCenterShell owns exit-animation mount lifecycle"
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


printf '\n==> Phase 2B.6.1 transactional wallpaper fit API\n'

wallpaper_fit_manager="$repo_root/scripts/runtime/wallpaper-manager.sh"
wallpaper_fit_ctl="$repo_root/scripts/runtime/jc-wallpaperctl.sh"
wallpaper_fit_runtime="$repo_root/scripts/runtime/apply-wallpaper.sh"

for contract in \
    'validate_wallpaper_fit() {' \
    "local requested_main_fit=\"\${3:-__KEEP__}\"" \
    "local requested_secondary_fit=\"\${4:-__KEEP__}\"" \
    "transactional_set_pair \"\$2\" \"\$3\" \"\$4\" \"\$5\""
do
    if grep -Fq -- "$contract" "$wallpaper_fit_manager"; then
        ok "Wallpaper fit manager contract: $contract"
    else
        fail "Wallpaper fit manager contract missing: $contract"
    fi
done

for contract in \
    '--main-fit <cover|contain|stretch|center>' \
    '--secondary-fit <cover|contain|stretch|center>' \
    'canonical_wallpaper_fit() {' \
    '--main-fit)' \
    '--secondary-fit)' \
    'runtimeReadbackAvailable: false'
do
    if grep -Fq -- "$contract" "$wallpaper_fit_ctl"; then
        ok "jc-wallpaperctl fit contract: $contract"
    else
        fail "jc-wallpaperctl fit contract missing: $contract"
    fi
done

for contract in \
    'cover|crop)' \
    'contain|fit)' \
    'stretch)' \
    'center|no)'
do
    if grep -Fq -- "$contract" "$wallpaper_fit_runtime"; then
        ok "Wallpaper runtime fit mapping: $contract"
    else
        fail "Wallpaper runtime fit mapping missing: $contract"
    fi
done


printf '\n==> Phase 2B.6.2 wallpaper fit draft UI\n'

wallpaper_fit_draft="$config_dir/services/WallpaperDraftStore.qml"
wallpaper_fit_apply="$config_dir/services/WallpaperApplyService.qml"
wallpaper_fit_view="$config_dir/modules/wallpapers/WallpaperView.qml"
wallpaper_fit_control="$config_dir/modules/wallpapers/WallpaperFitControl.qml"

if [[ -f "$wallpaper_fit_control" ]]; then
    ok "WallpaperFitControl.qml"
else
    fail "WallpaperFitControl.qml missing"
fi

for contract in \
    'property string draftMainFit: "cover"' \
    'property string draftSecondaryFit: "cover"' \
    'readonly property bool mainWallpaperDirty:' \
    'readonly property bool secondaryWallpaperDirty:' \
    'readonly property bool mainFitDirty:' \
    'readonly property bool secondaryFitDirty:' \
    'root.mainWallpaperDirty || root.mainFitDirty' \
    'root.secondaryWallpaperDirty || root.secondaryFitDirty' \
    'function setFit(target, fit): void {' \
    'observedMainFit !== root.baselineMainFit'
do
    if grep -Fq -- "$contract" "$wallpaper_fit_draft"; then
        ok "Wallpaper fit draft contract: $contract"
    else
        fail "Wallpaper fit draft contract missing: $contract"
    fi
done

for contract in \
    'root.draftStore.mainWallpaperDirty' \
    'root.draftStore.secondaryWallpaperDirty' \
    'root.draftStore.mainFitDirty' \
    'root.draftStore.secondaryFitDirty' \
    'args.push("--main-fit")' \
    'args.push("--secondary-fit")'
do
    if grep -Fq -- "$contract" "$wallpaper_fit_apply"; then
        ok "Wallpaper fit Apply contract: $contract"
    else
        fail "Wallpaper fit Apply contract missing: $contract"
    fi
done

for contract in \
    'WallpaperFitControl {' \
    'root.draftStore.draftMainFit' \
    'root.draftStore.draftSecondaryFit' \
    'root.draftStore.setFit("main", fitMode);' \
    'root.draftStore.setFit("secondary", fitMode);'
do
    if grep -Fq -- "$contract" "$wallpaper_fit_view"; then
        ok "Wallpaper fit View contract: $contract"
    else
        fail "Wallpaper fit View contract missing: $contract"
    fi
done

for forbidden in 'Process {' '"awww"' '"hyprpaper"' '"systemctl"' 'wallpaper.env'; do
    if grep -Fq -- "$forbidden" "$wallpaper_fit_control"; then
        fail "WallpaperFitControl mutation boundary violation: $forbidden"
    else
        ok "WallpaperFitControl excludes mutation/runtime command: $forbidden"
    fi
done



printf '\n==> Phase H1.4.1 JC Holo interactive controls\n'

holo_icon="$config_dir/components/JcIcon.qml"
holo_frame="$config_dir/components/JcInteractiveFrame.qml"
holo_button="$config_dir/components/JcButton.qml"
holo_icon_button="$config_dir/components/JcIconButton.qml"
holo_chip="$config_dir/components/JcChip.qml"
holo_choice="$config_dir/components/JcChoiceGroup.qml"
holo_fit="$config_dir/modules/wallpapers/WallpaperFitControl.qml"

for contract in \
    'case "fit": return "⌑";' \
    'case "fill": return "▣";' \
    'case "stretch": return "↔";' \
    'case "center": return "⊙";'
do
    if grep -Fq -- "$contract" "$holo_icon"; then
        ok "JcIcon semantic contract: $contract"
    else
        fail "JcIcon semantic contract missing: $contract"
    fi
done

for contract in \
    'property bool hovered: false' \
    'property bool pressed: false' \
    'property bool selected: false' \
    'property bool focused: false' \
    'root.theme.hudGlowMedium' \
    'root.theme.hudSecondaryAccent' \
    'root.theme.controlAccentInset'
do
    if grep -Fq -- "$contract" "$holo_frame"; then
        ok "JcInteractiveFrame contract: $contract"
    else
        fail "JcInteractiveFrame contract missing: $contract"
    fi
done

for component in "$holo_button" "$holo_icon_button" "$holo_chip"; do
    if grep -Fq -- 'JcInteractiveFrame {' "$component"; then
        ok "$(basename "$component") uses JcInteractiveFrame"
    else
        fail "$(basename "$component") must use JcInteractiveFrame"
    fi
    if grep -Fq -- 'JcIcon {' "$component"; then
        ok "$(basename "$component") uses JcIcon"
    else
        fail "$(basename "$component") must use JcIcon"
    fi
done

for contract in \
    'property int optionSpacing: root.theme.spaceSm' \
    'property bool centerContent: false' \
    'function activeRepeater() {' \
    'id: centeredChoiceRow' \
    'iconName: String(modelData.iconName || "")' \
    'icon: String(modelData.icon || "")'
do
    if grep -Fq -- "$contract" "$holo_choice"; then
        ok "JcChoiceGroup H1.4 contract: $contract"
    else
        fail "JcChoiceGroup H1.4 contract missing: $contract"
    fi
done

for contract in \
    'iconName: "fit"' \
    'iconName: "fill"' \
    'iconName: "stretch"' \
    'iconName: "center"' \
    'id: fitChoices' \
    'centerContent: true' \
    'text: "DRAFT"'
do
    if grep -Fq -- "$contract" "$holo_fit"; then
        ok "Wallpaper Fit H1.4 consumer: $contract"
    else
        fail "Wallpaper Fit H1.4 consumer missing: $contract"
    fi
done

if grep -Fq -- 'Components.JcSurface {' "$holo_fit"; then
    fail "Wallpaper Fit group must not own a background JcSurface"
else
    ok "Wallpaper Fit group uses flat control composition"
fi


printf '\n==> Phase H1.4.2a semantic action icons\n'

semantic_icon="$config_dir/components/JcIcon.qml"
semantic_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
semantic_wallpapers="$config_dir/modules/wallpapers/WallpaperView.qml"
semantic_displays="$config_dir/modules/displays/DisplayView.qml"
semantic_display_card="$config_dir/modules/displays/DisplayCard.qml"
semantic_layout="$config_dir/modules/displays/DisplayLayoutEditor.qml"

if grep -Fq -- 'case "power": return "⏻";' "$semantic_icon"; then
    ok 'semantic icon vocabulary: power'
else
    fail 'semantic icon vocabulary missing: power'
fi

for contract in \
    'iconName: "apply"' \
    '? "refresh"' \
    ': "reset"' \
    'iconName: "refresh"'
do
    if grep -Fq -- "$contract" "$semantic_wallpapers"; then
        ok "Wallpaper semantic action: $contract"
    else
        fail "Wallpaper semantic action missing: $contract"
    fi
done

for contract in \
    'iconName: "reset"' \
    'iconName: "apply"' \
    'iconName: "refresh"' \
    'iconName: "keep"' \
    'iconName: "revert"' \
    'iconName: "save"'
do
    if grep -Fq -- "$contract" "$semantic_displays"; then
        ok "Displays semantic action: $contract"
    else
        fail "Displays semantic action missing: $contract"
    fi
done

if grep -Fq -- 'iconName: "power"' "$semantic_display_card"; then
    ok 'Display enable/disable uses semantic power icon'
else
    fail 'Display enable/disable semantic power icon missing'
fi

for contract in \
    'text: "Left"' \
    'iconName: "left"' \
    'text: "Right"' \
    'iconName: "right"' \
    'text: "Above"' \
    'iconName: "above"' \
    'text: "Below"' \
    'iconName: "below"'
do
    if grep -Fq -- "$contract" "$semantic_layout"; then
        ok "Display topology semantic action: $contract"
    else
        fail "Display topology semantic action missing: $contract"
    fi
done

for legacy_label in \
    'text: "← Left"' \
    'text: "Right →"' \
    'text: "↑ Above"' \
    'text: "↓ Below"'
do
    if grep -Fq -- "$legacy_label" "$semantic_layout"; then
        fail "Display topology retains embedded icon glyph: $legacy_label"
    else
        ok "Display topology retired embedded glyph: $legacy_label"
    fi
done

if grep -Fq -- 'iconName: "close"' "$semantic_shell"; then
    ok 'Control Center close uses semantic icon'
else
    fail 'Control Center close semantic icon missing'
fi

if grep -Fq -- 'icon: "×"' "$semantic_shell"; then
    fail 'Control Center close still uses raw glyph'
else
    ok 'Control Center close raw glyph retired'
fi


printf '\n==> Phase H1.4.2b navigation semantic icons\n'

semantic_nav_item="$config_dir/components/JcNavItem.qml"
semantic_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"
semantic_gallery="$config_dir/modules/dev/ComponentGallery.qml"

for contract in \
    'property string iconName: ""' \
    'root.iconName.length > 0' \
    'JcIcon {' \
    'name: root.iconName' \
    'glyph: root.icon'
do
    if grep -Fq -- "$contract" "$semantic_nav_item"; then
        ok "JcNavItem semantic icon contract: $contract"
    else
        fail "JcNavItem semantic icon contract missing: $contract"
    fi
done

for semantic_name in \
    display \
    wallpaper \
    theme \
    settings \
    performance \
    media \
    network \
    notifications
do
    if grep -Fq -- "iconName: \"$semantic_name\"" "$semantic_navigation"; then
        ok "Control Center navigation semantic icon: $semantic_name"
    else
        fail "Control Center navigation semantic icon missing: $semantic_name"
    fi
done

for contract in \
    'iconName:' \
    'String(modelData.iconName || "")'
do
    if grep -Fq -- "$contract" "$semantic_navigation"; then
        ok "Control Center navigation delegate: $contract"
    else
        fail "Control Center navigation delegate missing: $contract"
    fi
done

navigation_raw_glyphs="$(
    grep -nE \
        'icon:[[:space:]]*"(▣|▧|◐|⚙|◇|♪|⌁|●)"|modelData\.icon([^N]|$)' \
        "$semantic_navigation" \
        2>/dev/null ||
        true
)"

if [[ -z "$navigation_raw_glyphs" ]]; then
    ok "production navigation contains no raw icon glyph bindings"
else
    fail "production navigation still contains raw icon glyph bindings:"
    printf '%s\n' "$navigation_raw_glyphs" >&2
fi

for contract in \
    'iconName: "display"' \
    'iconName: "theme"' \
    'iconName: "settings"'
do
    if grep -Fq -- "$contract" "$semantic_gallery"; then
        ok "ComponentGallery navigation semantic icon: $contract"
    else
        fail "ComponentGallery navigation semantic icon missing: $contract"
    fi
done


printf '\n==> Phase H1.4.3a JC Holo vector icon renderer\n'

holo_vector_icon="$config_dir/components/JcIcon.qml"
holo_vector_theme="$config_dir/theme/Theme.qml"

for contract in \
    'property var vectorNames:' \
    'readonly property bool vectorKnown:' \
    'readonly property bool useVector:' \
    'Canvas {' \
    'root.drawIcon(ctx, root.name);' \
    'ctx.scale(width / 24, height / 24);' \
    'visible: root.useVector' \
    '!root.useVector' \
    'root.resolvedGlyph.length > 0'
do
    if grep -Fq -- "$contract" "$holo_vector_icon"; then
        ok "JcIcon vector renderer contract: $contract"
    else
        fail "JcIcon vector renderer contract missing: $contract"
    fi
done

for semantic_name in \
    close refresh apply reset save keep revert \
    fit fill stretch center left right above below \
    display wallpaper theme settings performance media network \
    notifications favorite power
do
    if grep -Fq -- "\"$semantic_name\"" "$holo_vector_icon"; then
        ok "JcIcon vector semantic: $semantic_name"
    else
        fail "JcIcon vector semantic missing: $semantic_name"
    fi
done

for contract in \
    'readonly property real iconStrokeRatio: 0.072' \
    'readonly property real iconEmphasisStrokeScale: 1.12'
do
    if grep -Fq -- "$contract" "$holo_vector_theme"; then
        ok "JC Holo vector icon theme token: $contract"
    else
        fail "JC Holo vector icon theme token missing: $contract"
    fi
done

if grep -Eq \
    '/usr/share/icons|Font Awesome|Nerd Font|Symbols Nerd' \
    "$holo_vector_icon"
then
    fail "JcIcon vector renderer must not depend on system icon/font paths"
else
    ok "JcIcon vector renderer is self-contained"
fi

printf '\nQuickshell validation summary: %d error(s)\n' "$errors"

if ((errors > 0)); then
    exit 1
fi

printf 'Quickshell static checks passed.\n'
