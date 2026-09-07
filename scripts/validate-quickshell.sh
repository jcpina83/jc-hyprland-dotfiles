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
    "services/ThemeService.qml"
    "services/ThemeDraftStore.qml"
    "services/ThemeApplyService.qml"
    "services/WallpaperDraftStore.qml"
    "services/WallpaperApplyService.qml"
    "services/WallpaperRotationApplyService.qml"
    "services/WallpaperMutationCoordinator.qml"
    "modules/wallpapers/WallpaperView.qml"
    "modules/wallpapers/WallpaperRotationControl.qml"
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

reset_control_context="$(
    grep -B 24 -F \
        'onClicked: root.resetRequested()' \
        "$wallpaper_view" \
        || true
)"

if grep -Fq \
    '&& !root.draftStore.observedChangedWhileDirty' \
    <<< "$reset_control_context"
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
    'onResetRequested: wallpaperMutationCoordinator.resetDraft()' \
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
    'applyService: root.wallpaperMutationCoordinatorHandle' \
    'onApplyRequested: wallpaperMutationCoordinator.applyDirty()'
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

if grep -A4 -F 'id: "quick-settings"' "$control_center_navigation" \
    | grep -Fq 'enabled: true'
then
    ok "Quick Settings navigation entry is enabled"
else
    fail "Quick Settings navigation entry must be enabled"
fi

for future_module in \
    themes \
    quick-settings \
    performance \
    media \
    network \
    notifications
do
    if [[ "$future_module" == "themes"
            || "$future_module" == "quick-settings" ]]; then
        continue
    fi
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
    'property bool compact: false' \
    'signal valueSelected(string value)' \
    'textRole: "label"' \
    'valueRole: "value"' \
    'function indexForSelectedValue(): int' \
    'function syncCurrentIndex(): void' \
    'onActivated: index =>' \
    'JcInteractiveFrame {' \
    'hovered: root.hovered' \
    'pressed: root.down' \
    'selected: root.popup.visible' \
    'focused: root.activeFocus' \
    'name: "chevron-down"' \
    'delegate: Controls.ItemDelegate {' \
    'popup: Controls.Popup {' \
    'root.theme.controlSurfaceDefault' \
    'root.theme.controlSurfaceHover' \
    'root.theme.controlSurfacePressed' \
    'root.theme.controlSurfaceSelected' \
    'root.theme.controlTextDisabled' \
    'root.theme.controlTextSelected' \
    'root.theme.surfaceOverlay' \
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
    '- [x] **Phase 2B — Wallpapers**' \
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
    'Wallpapers  ✓ COMPLETE'
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
    'Components.JcIconButton {' \
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
    'columnSpacing: root.theme.spaceSm' \
    'rowSpacing: root.theme.space2Xs' \
    'id: topologyDPad' \
    'anchors.right: parent.right'
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
    '- [x] **Phase 2B — Wallpapers**' \
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
    'Wallpapers  ✓ COMPLETE' \
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
    'String(root.wallpaperService.mainFit || "cover")' \
    '!== root.baselineMainFit'
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
    'iconName: "left"' \
    'iconName: "right"' \
    'iconName: "above"' \
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


printf '\n==> Phase H1.4.3b compact icon differentiation\n'

holo_compact_icon="$config_dir/components/JcIcon.qml"
holo_compact_chip="$config_dir/components/JcChip.qml"
holo_compact_theme="$config_dir/theme/Theme.qml"

if grep -Fq -- \
    'readonly property int iconSizeCompactControl: 16' \
    "$holo_compact_theme"
then
    ok 'compact interactive icon size token is 16 px'
else
    fail 'compact interactive icon size token missing'
fi

if grep -Fq -- \
    '? root.theme.iconSizeCompactControl' \
    "$holo_compact_chip"
then
    ok 'JcChip uses compact interactive icon size'
else
    fail 'JcChip compact icon size contract missing'
fi

for contract in \
    'ctx.rect(6.7, 8.3, 10.6, 7.4);' \
    'ctx.rect(5.0, 5.0, 14.0, 14.0);' \
    'root.drawArrow(ctx, 10.8, 10.8, 6.4, 6.4, 1.7);' \
    'root.drawArrow(ctx, 13.2, 13.2, 17.6, 17.6, 1.7);'
do
    if grep -Fq -- "$contract" "$holo_compact_icon"; then
        ok "Fit/Fill differentiation contract: $contract"
    else
        fail "Fit/Fill differentiation contract missing: $contract"
    fi
done


printf '\n==> Phase H1.4.3b wallpaper section hierarchy\n'

holo_wallpaper_view="$config_dir/modules/wallpapers/WallpaperView.qml"
holo_library_icon="$config_dir/components/JcIcon.qml"

for contract in \
    'title: "Wallpaper targets"' \
    'root.wallpaperService.mainOutput.length > 0' \
    'root.wallpaperService.secondaryOutput.length > 0' \
    'iconName: "all"' \
    'iconName: "theme"' \
    'iconName: "library"'
do
    if grep -Fq -- "$contract" "$holo_wallpaper_view"; then
        ok "Wallpaper section hierarchy: $contract"
    else
        fail "Wallpaper section hierarchy missing: $contract"
    fi
done

for semantic_name in all library
do
    if grep -Fq -- "\"$semantic_name\"" "$holo_library_icon"; then
        ok "Wallpaper filter semantic icon: $semantic_name"
    else
        fail "Wallpaper filter semantic icon missing: $semantic_name"
    fi
done

for contract in \
    'case "all":' \
    'case "library":' \
    'ctx.rect(4.2, 4.2, 6.1, 6.1);' \
    'ctx.lineTo(20.5, 18.8);'
do
    if grep -Fq -- "$contract" "$holo_library_icon"; then
        ok "Wallpaper filter vector contract: $contract"
    else
        fail "Wallpaper filter vector contract missing: $contract"
    fi
done


printf '\n==> Phase H1.4.4a Displays visual hierarchy\n'

holo_display_view="$config_dir/modules/displays/DisplayView.qml"
holo_display_layout="$config_dir/modules/displays/DisplayLayoutEditor.qml"

for contract in \
    'title: "Monitors"' \
    '+ " active · "' \
    'title: "Monitor settings"' \
    '" detected · resolution · refresh rate · scale · orientation"' \
    'delegate: DisplayCard {' \
    'title: "Persistent configuration"'
do
    if grep -Fq -- "$contract" "$holo_display_view"; then
        ok "Displays hierarchy contract: $contract"
    else
        fail "Displays hierarchy contract missing: $contract"
    fi
done

for contract in \
    'title: "Layout & position"' \
    'root.draftStore.topologyValid' \
    'Components.JcComboBox {' \
    'Components.JcIconButton {'
do
    if grep -Fq -- "$contract" "$holo_display_layout"; then
        ok "Displays layout hierarchy contract: $contract"
    else
        fail "Displays layout hierarchy contract missing: $contract"
    fi
done

if grep -Fq -- 'title: "Visual layout"' "$holo_display_layout"; then
    fail 'Displays retains superseded "Visual layout" title'
else
    ok 'Displays retired superseded "Visual layout" title'
fi

for contract in \
    'id: layoutHudFrame' \
    'id: persistenceHudFrame'
do
    if grep -R -Fq -- "$contract" \
        "$holo_display_view" \
        "$holo_display_layout"
    then
        ok "Displays functional perimeter preserved: $contract"
    else
        fail "Displays functional perimeter missing: $contract"
    fi
done


printf '\n==> Phase H1.4.4b Display control strip\n'

holo_display_card="$config_dir/modules/displays/DisplayCard.qml"
holo_combo_box="$config_dir/components/JcComboBox.qml"
holo_icon="$config_dir/components/JcIcon.qml"

for contract in \
    'readonly property real controlStripMinColumnWidth:' \
    'readonly property int controlStripColumns:' \
    'id: displayControlStrip' \
    'columns: root.controlStripColumns' \
    'columnSpacing: root.theme.spaceMd' \
    'text: "Resolution"' \
    'text: "Refresh rate"' \
    'text: "Orientation"' \
    'text: "Scale"'
do
    if grep -Fq -- "$contract" "$holo_display_card"; then
        ok "Display control strip contract: $contract"
    else
        fail "Display control strip contract missing: $contract"
    fi
done

display_card_combo_count="$(
    grep -Fc 'Components.JcComboBox {' "$holo_display_card" 2>/dev/null || true
)"
display_card_slider_count="$(
    grep -Fc 'Components.JcSlider {' "$holo_display_card" 2>/dev/null || true
)"
compact_combo_count="$(
    awk '
        /Components.JcComboBox \{/ { in_combo=1; next }
        in_combo && /compact: true/ { count++; in_combo=0 }
        in_combo && /^        }/ { in_combo=0 }
        END { print count+0 }
    ' "$holo_display_card"
)"

if [[ "$display_card_combo_count" == "3" \
    && "$display_card_slider_count" == "1" ]]
then
    ok "DisplayCard remains 3 ComboBoxes + 1 Slider"
else
    fail "DisplayCard control counts changed: combo=$display_card_combo_count slider=$display_card_slider_count"
fi

if [[ "$compact_combo_count" == "3" ]]; then
    ok "DisplayCard uses compact mode on all three enum ComboBoxes"
else
    fail "DisplayCard expected 3 compact enum ComboBoxes, found $compact_combo_count"
fi

for contract in \
    'property bool compact: false' \
    'implicitHeight: root.compact' \
    'JcInteractiveFrame {' \
    'selected: root.popup.visible' \
    'focused: root.activeFocus' \
    'name: "chevron-down"' \
    '? root.theme.iconSizeCompactControl'
do
    if grep -Fq -- "$contract" "$holo_combo_box"; then
        ok "JC Holo ComboBox contract: $contract"
    else
        fail "JC Holo ComboBox contract missing: $contract"
    fi
done

if grep -Fq -- 'text: "⌄"' "$holo_combo_box"; then
    fail "JcComboBox still owns the raw chevron glyph"
else
    ok "JcComboBox uses semantic chevron rendering"
fi

for contract in \
    '"chevron-down"' \
    'case "chevron-down":' \
    '[[6.2, 8.8], [12, 14.5], [17.8, 8.8]]'
do
    if grep -Fq -- "$contract" "$holo_icon"; then
        ok "Semantic chevron contract: $contract"
    else
        fail "Semantic chevron contract missing: $contract"
    fi
done


printf '\n==> Phase H1.4.4d in-canvas HUD D-Pad\n'

holo_display_layout="$config_dir/modules/displays/DisplayLayoutEditor.qml"
holo_architecture="$repo_root/docs/architecture.md"

for contract in \
    'id: topologySelectorGrid' \
    'columns: root.compactLayout ? 1 : 2' \
    'id: topologyDPad' \
    'anchors.right: parent.right' \
    'root.dpadReservedWidth' \
    'Components.JcHudFrame {' \
    'surfaceRole: "glass-raised"' \
    'columns: 3' \
    'rows: 3'
do
    if grep -Fq -- "$contract" "$holo_display_layout"; then
        ok "HUD D-Pad composition: $contract"
    else
        fail "HUD D-Pad composition missing: $contract"
    fi
done

layout_combo_count="$(
    grep -Fc 'Components.JcComboBox {' "$holo_display_layout" 2>/dev/null || true
)"
layout_icon_button_count="$(
    grep -Fc 'Components.JcIconButton {' "$holo_display_layout" 2>/dev/null || true
)"
layout_bottom_button_count="$(
    grep -Fc 'Components.JcButton {' "$holo_display_layout" 2>/dev/null || true
)"

if [[ "$layout_combo_count" == "2" \
    && "$layout_icon_button_count" == "5" \
    && "$layout_bottom_button_count" == "0" ]]
then
    ok "Layout editor uses 2 selectors + 5 in-canvas HUD icon actions"
else
    fail "Unexpected layout control count: combo=$layout_combo_count icon=$layout_icon_button_count bottom=$layout_bottom_button_count"
fi

for semantic_icon in above left center right below
do
    if grep -Fq -- "iconName: \"$semantic_icon\"" "$holo_display_layout"; then
        ok "HUD D-Pad semantic icon: $semantic_icon"
    else
        fail "HUD D-Pad semantic icon missing: $semantic_icon"
    fi
done

for direction in above left right below
do
    if grep -Fq -- "root.snapSelected(\"$direction\")" "$holo_display_layout"; then
        ok "HUD D-Pad draft direction: $direction"
    else
        fail "HUD D-Pad draft direction missing: $direction"
    fi
done

for center_contract in \
    'id: recenterTopologyButton' \
    'accessibleName: "Recenter topology"' \
    'onClicked: root.recalculateBounds()'
do
    if grep -Fq -- "$center_contract" "$holo_display_layout"; then
        ok "HUD D-Pad center action: $center_contract"
    else
        fail "HUD D-Pad center action missing: $center_contract"
    fi
done

if grep -Fq -- 'id: positionSegmentedActions' "$holo_display_layout"; then
    fail "Retired bottom position strip remains"
else
    ok "Retired bottom position strip removed"
fi

for runtime_contract in \
    'root.draftStore.snapPosition(' \
    'root.draftStore.setPosition(' \
    'root.draftStore.snapRelative(' \
    'root.draftStore.topologyValid'
do
    if grep -Fq -- "$runtime_contract" "$holo_display_layout"; then
        ok "HUD D-Pad preserves topology boundary: $runtime_contract"
    else
        fail "HUD D-Pad topology boundary missing: $runtime_contract"
    fi
done

for doc_contract in \
    '## H1.4.4d In-canvas HUD D-Pad' \
    'right side of the' \
    'topology canvas, matching the visual editing surface' \
    'center action recenters the topology viewport' \
    'does not reset or mutate the display draft'
do
    if grep -Fq -- "$doc_contract" "$holo_architecture"; then
        ok "H1.4.4d architecture contract: $doc_contract"
    else
        fail "H1.4.4d architecture contract missing: $doc_contract"
    fi
done


printf '\n==> Phase 2B.6.3 rotation mutation API\n'

rotation_manager="$repo_root/scripts/runtime/wallpaper-rotation-manager.sh"
wallpaperctl="$repo_root/scripts/runtime/jc-wallpaperctl.sh"
wallpaper_docs="$repo_root/docs/wallpaper-control.md"
architecture_docs="$repo_root/docs/architecture.md"

for contract in \
    'wallpaper-rotation-manager.sh current --json' \
    'wallpaper-rotation-manager.sh transactional-set' \
    'acquire_mutation_lock() {' \
    '.wallpaper-env.mutation.lock' \
    'write_rotation_configuration() {' \
    'shell_assignment_value() {' \
    'configure-wallpaper-rotation.sh' \
    'verify_expected_state() {' \
    'return 6' \
    'return 7'
do
    if grep -Fq -- "$contract" "$rotation_manager"; then
        ok "Rotation manager contract: $contract"
    else
        fail "Rotation manager contract missing: $contract"
    fi
done

for contract in \
    'jc-wallpaperctl rotation status [--json]' \
    'jc-wallpaperctl rotation apply' \
    "rotation_manager=\"\$base/bin/wallpaper-rotation-manager.sh\"" \
    'rotation_apply() {' \
    'rotation_command() {' \
    'rotation)' \
    "| .rotation = \$rotation"
do
    if grep -Fq -- "$contract" "$wallpaperctl"; then
        ok "Stable rotation API contract: $contract"
    else
        fail "Stable rotation API contract missing: $contract"
    fi
done

for forbidden in \
    'systemctl' \
    'configure-wallpaper-rotation' \
    'wallpaper.env'
do
    if grep -R -Fq -- "$forbidden" \
        "$config_dir/modules/wallpapers" \
        "$config_dir/services/WallpaperService.qml" \
        "$config_dir/services/WallpaperApplyService.qml"
    then
        fail "Wallpaper QML contains forbidden rotation backend detail: $forbidden"
    else
        ok "Wallpaper QML excludes rotation backend detail: $forbidden"
    fi
done

for contract in \
    '## Rotation mutation API' \
    'jc-wallpaperctl rotation apply' \
    'wallpaper-rotation-manager.sh' \
    'Byte-for-byte restoration is required for transactional' \
    "\`6\` means rollback was verified. Exit code \`7\` means" \
    "Exit code \`7\`"
do
    if grep -Fq -- "$contract" "$wallpaper_docs"; then
        ok "Rotation mutation documentation: $contract"
    else
        fail "Rotation mutation documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.6.3 Rotation mutation boundary' \
    'Rotation state is not duplicated into the theme' \
    'No QML component owns systemd lifecycle'
do
    if grep -Fq -- "$contract" "$architecture_docs"; then
        ok "Rotation architecture contract: $contract"
    else
        fail "Rotation architecture contract missing: $contract"
    fi
done


printf '\n==> Phase 2B.6.4a rotation observed + draft foundation\n'

rotation_service="$config_dir/services/WallpaperService.qml"
rotation_draft="$config_dir/services/WallpaperDraftStore.qml"
wallpaper_apply="$config_dir/services/WallpaperApplyService.qml"
rotation_docs="$repo_root/docs/wallpaper-control.md"
rotation_arch="$repo_root/docs/architecture.md"

for contract in \
    'property bool rotationRuntimeSynchronized: false' \
    'property bool rotationIntervalSynchronized: false' \
    'property bool rotationLifecycleSynchronized: false' \
    'status.rotation.runtime.timer' \
    'status.rotation.runtime.synchronized'
do
    if grep -Fq -- "$contract" "$rotation_service"; then
        ok "Rotation observed-state contract: $contract"
    else
        fail "Rotation observed-state contract missing: $contract"
    fi
done

for contract in \
    'property bool draftRotationEnabled: false' \
    'property string draftRotationMode: "next"' \
    'property string draftRotationTarget: "both"' \
    'property string draftRotationInterval: "30m"' \
    'readonly property bool rotationDirty:' \
    'readonly property bool hasWallpaperDirty:' \
    'function setRotationEnabled(enabled): void {' \
    'function setRotationMode(mode): void {' \
    'function setRotationTarget(target): void {' \
    'function setRotationInterval(interval): void {' \
    'function prepareForRefreshAfterRotationApply(): void {' \
    'function resetRotation(): void {' \
    'property string syncAfterApplyDomain: ""'
do
    if grep -Fq -- "$contract" "$rotation_draft"; then
        ok "Rotation draft contract: $contract"
    else
        fail "Rotation draft contract missing: $contract"
    fi
done

for contract in \
    'root.draftStore.hasWallpaperDirty' \
    'There are no wallpaper or fit changes to apply.'
do
    if grep -Fq -- "$contract" "$wallpaper_apply"; then
        ok "Wallpaper Apply domain isolation: $contract"
    else
        fail "Wallpaper Apply domain isolation missing: $contract"
    fi
done

for contract in \
    '## Rotation observed and draft foundation' \
    'hasWallpaperDirty' \
    'rotationDirty' \
    'prepareForRefreshAfterRotationApply()'
do
    if grep -Fq -- "$contract" "$rotation_docs"; then
        ok "Rotation draft documentation: $contract"
    else
        fail "Rotation draft documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.6.4a Rotation observed and draft foundation' \
    'Domain-aware reconciliation' \
    'jc-wallpaperctl rotation apply'
do
    if grep -Fq -- "$contract" "$rotation_arch"; then
        ok "Rotation draft architecture: $contract"
    else
        fail "Rotation draft architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.6.4b rotation Apply service\n'

rotation_apply="$config_dir/services/WallpaperRotationApplyService.qml"
rotation_main="$config_dir/Main.qml"
rotation_docs="$repo_root/docs/wallpaper-control.md"
rotation_arch="$repo_root/docs/architecture.md"

for contract in \
    'Scope {' \
    'property var wallpaperService' \
    'property var draftStore' \
    'property bool applying: false' \
    'property bool awaitingRefresh: false' \
    'property bool recoveryResetPending: false' \
    'property bool rollbackRecoveryRequired: false' \
    'readonly property bool busy:' \
    'readonly property bool canApply:' \
    'root.draftStore.rotationDirty' \
    'signal applied()' \
    'signal rolledBack(string message)' \
    'signal rollbackFailed(string message)' \
    'function wallpaperctlPath() {' \
    'function validAppliedResponse(payload) {' \
    'payload.status === "reconciled"' \
    'Boolean(payload.configurationRestored)' \
    'Boolean(payload.runtimeRollbackVerified)' \
    'function buildApplyArguments() {' \
    '"rotation",' \
    '"apply"' \
    'args.push("--enabled")' \
    'args.push("--mode")' \
    'args.push("--target")' \
    'args.push("--interval")' \
    'function applyDirty(): void {' \
    'function resetDraft(): void {' \
    'root.draftStore.prepareForRefreshAfterRotationApply();' \
    'root.wallpaperService.rotationRuntimeSynchronized' \
    'Process {' \
    'StdioCollector {' \
    'Connections {'
do
    if grep -Fq -- "$contract" "$rotation_apply"; then
        ok "Rotation Apply service contract: $contract"
    else
        fail "Rotation Apply service contract missing: $contract"
    fi
done

for forbidden in \
    'systemctl' \
    'wallpaper.env' \
    'configure-wallpaper-rotation' \
    'wallpaper-rotation-manager'
do
    if grep -Fq -- "$forbidden" "$rotation_apply"; then
        fail "Rotation Apply service bypasses stable CLI boundary: $forbidden"
    else
        ok "Rotation Apply service excludes backend detail: $forbidden"
    fi
done

for contract in \
    '|| wallpaperRotationApplyService.busy' \
    'wallpaperRotationApplyService.applying' \
    'wallpaperRotationApplyService.awaitingRefresh' \
    'wallpaperRotationApplyService.rollbackRecoveryRequired' \
    'wallpaperRotationApplyServiceHandle:' \
    'Services.WallpaperRotationApplyService {' \
    'id: wallpaperRotationApplyService' \
    'wallpaperService: wallpaperService' \
    'draftStore: wallpaperDraftStore'
do
    if grep -Fq -- "$contract" "$rotation_main"; then
        ok "Main rotation Apply wiring: $contract"
    else
        fail "Main rotation Apply wiring missing: $contract"
    fi
done

for contract in \
    '## Rotation Apply service' \
    'WallpaperRotationApplyService.qml' \
    'jc-wallpaperctl rotation apply' \
    'rotationRuntimeSynchronized' \
    'Phase 2B.6.5'
do
    if grep -Fq -- "$contract" "$rotation_docs"; then
        ok "Rotation Apply documentation: $contract"
    else
        fail "Rotation Apply documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.6.4b Rotation Apply service boundary' \
    'dedicated mutation owner' \
    'syncAfterApplyDomain'
do
    if grep -Fq -- "$contract" "$rotation_arch"; then
        ok "Rotation Apply architecture: $contract"
    else
        fail "Rotation Apply architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.6.5a unified wallpaper mutation coordinator\n'

wallpaper_coordinator="$config_dir/services/WallpaperMutationCoordinator.qml"
wallpaper_main="$config_dir/Main.qml"
wallpaper_doc="$repo_root/docs/wallpaper-control.md"
wallpaper_arch="$repo_root/docs/architecture.md"

for contract in \
    'Scope {' \
    'property var wallpaperApplyService' \
    'property var rotationApplyService' \
    'property bool sequenceRotationPending: false' \
    'property string recoveryResetOwner: ""' \
    'readonly property bool applying:' \
    'readonly property bool awaitingRefresh:' \
    'readonly property bool busy:' \
    'readonly property bool rollbackRecoveryRequired:' \
    'readonly property bool canApply:' \
    'root.draftStore.hasWallpaperDirty' \
    'root.draftStore.rotationDirty' \
    'function applyDirty(): void {' \
    'function resetDraft(): void {' \
    'function startRotationAfterWallpaper(): void {' \
    'root.wallpaperApplyService.applyDirty();' \
    'root.rotationApplyService.applyDirty();' \
    'function continueRecoveryResetAfterWallpaper(): void {' \
    'function continueRecoveryResetAfterRotation(): void {' \
    'function onApplied() {' \
    'function onResetCompleted() {' \
    'function onRotationResetCompleted() {'
do
    if grep -Fq -- "$contract" "$wallpaper_coordinator"; then
        ok "Wallpaper coordinator contract: $contract"
    else
        fail "Wallpaper coordinator contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-wallpaperctl' \
    'systemctl' \
    'wallpaper.env' \
    'wallpaper-manager' \
    'wallpaper-rotation-manager'
do
    if grep -Fq -- "$forbidden" "$wallpaper_coordinator"; then
        fail "Wallpaper coordinator bypasses service boundary: $forbidden"
    else
        ok "Wallpaper coordinator excludes mutation detail: $forbidden"
    fi
done

for contract in \
    'wallpaperMutationCoordinatorHandle:' \
    'Services.WallpaperMutationCoordinator {' \
    'id: wallpaperMutationCoordinator' \
    'wallpaperApplyService: wallpaperApplyService' \
    'rotationApplyService: wallpaperRotationApplyService' \
    'applyService: root.wallpaperMutationCoordinatorHandle' \
    'onApplyRequested: wallpaperMutationCoordinator.applyDirty()' \
    'onResetRequested: wallpaperMutationCoordinator.resetDraft()'
do
    if grep -Fq -- "$contract" "$wallpaper_main"; then
        ok "Main unified wallpaper routing: $contract"
    else
        fail "Main unified wallpaper routing missing: $contract"
    fi
done

for contract in \
    '## Unified wallpaper mutation coordinator' \
    'wallpaper/path-fit first' \
    'second domain is not started' \
    'Visible automatic-rotation controls remain deferred to Phase 2B.6.5b.'
do
    if grep -Fq -- "$contract" "$wallpaper_doc"; then
        ok "Wallpaper coordinator documentation: $contract"
    else
        fail "Wallpaper coordinator documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.6.5a Unified wallpaper mutation orchestration' \
    'orchestration boundary, not a mutation boundary' \
    'This prepares Phase 2B.6.5b to expose automatic-rotation controls without' \
    'creating a second top-level Apply/Reset workflow.'
do
    if grep -Fq -- "$contract" "$wallpaper_arch"; then
        ok "Wallpaper coordinator architecture: $contract"
    else
        fail "Wallpaper coordinator architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.6.5b automatic rotation JC Holo controls\n'

rotation_control="$config_dir/modules/wallpapers/WallpaperRotationControl.qml"
rotation_view="$config_dir/modules/wallpapers/WallpaperView.qml"
rotation_doc="$repo_root/docs/wallpaper-control.md"
rotation_arch="$repo_root/docs/architecture.md"

for contract in \
    'Item {' \
    'required property var theme' \
    'property bool controlEnabled: true' \
    'property bool enabledValue: false' \
    'property string modeValue: "next"' \
    'property string targetValue: "both"' \
    'property string intervalValue: "30m"' \
    'property bool draftDirty: false' \
    'property bool runtimeSynchronized: false' \
    'signal enabledSelected(bool value)' \
    'signal modeSelected(string value)' \
    'signal targetSelected(string value)' \
    'signal intervalSelected(string value)' \
    'Components.JcHudFrame {' \
    'Components.JcToggle {' \
    'Components.JcSettingTile {' \
    'Components.JcChip {' \
    'text: "Automatic rotation"' \
    'text: "Mode"' \
    'text: "Target"' \
    'text: "Interval"' \
    'root.runtimeSynchronized' \
    'root.draftDirty'
do
    if grep -Fq -- "$contract" "$rotation_control"; then
        ok "Rotation presentation contract: $contract"
    else
        fail "Rotation presentation contract missing: $contract"
    fi
done

for forbidden in \
    'property var draftStore' \
    'property var wallpaperService' \
    'property var applyService' \
    'Process {' \
    'jc-wallpaperctl' \
    'systemctl' \
    'wallpaper.env' \
    'wallpaper-manager' \
    'wallpaper-rotation-manager'
do
    if grep -Fq -- "$forbidden" "$rotation_control"; then
        fail "Rotation presentation owns forbidden dependency: $forbidden"
    else
        ok "Rotation presentation excludes ownership detail: $forbidden"
    fi
done

for contract in \
    'WallpaperRotationControl {' \
    'root.draftStore.draftRotationEnabled' \
    'root.draftStore.draftRotationMode' \
    'root.draftStore.draftRotationTarget' \
    'root.draftStore.draftRotationInterval' \
    'root.draftStore.rotationDirty' \
    'root.wallpaperService.rotationRuntimeSynchronized' \
    'root.draftStore.setRotationEnabled(value);' \
    'root.draftStore.setRotationMode(value);' \
    'root.draftStore.setRotationTarget(value);' \
    'root.draftStore.setRotationInterval(value);'
do
    if grep -Fq -- "$contract" "$rotation_view"; then
        ok "WallpaperView rotation draft wiring: $contract"
    else
        fail "WallpaperView rotation draft wiring missing: $contract"
    fi
done

for forbidden in \
    'jc-wallpaperctl' \
    '"systemctl"' \
    'wallpaper.env' \
    'wallpaper-rotation-manager'
do
    if grep -Fq -- "$forbidden" "$rotation_view"; then
        fail "WallpaperView rotation UI bypasses service boundary: $forbidden"
    else
        ok "WallpaperView rotation UI preserves service boundary: $forbidden"
    fi
done

for contract in \
    '## Automatic rotation JC Holo controls' \
    'presentation-only' \
    'WallpaperMutationCoordinator' \
    'Phase 2B.6.5c'
do
    if grep -Fq -- "$contract" "$rotation_doc"; then
        ok "Rotation UI documentation: $contract"
    else
        fail "Rotation UI documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.6.5b Automatic rotation presentation boundary' \
    'does not introduce a rotation-specific commit button' \
    'presentation/draft boundary'
do
    if grep -Fq -- "$contract" "$rotation_arch"; then
        ok "Rotation UI architecture: $contract"
    else
        fail "Rotation UI architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.6.6b advanced wallpaper controls closure\n'

phase_2b6_wallpaper_doc="$repo_root/docs/wallpaper-control.md"
phase_2b6_architecture="$repo_root/docs/architecture.md"
phase_2b6_main="$config_dir/Main.qml"
phase_2b6_view="$config_dir/modules/wallpapers/WallpaperView.qml"
phase_2b6_rotation_control="$config_dir/modules/wallpapers/WallpaperRotationControl.qml"
phase_2b6_coordinator="$config_dir/services/WallpaperMutationCoordinator.qml"
phase_2b6_rotation_apply="$config_dir/services/WallpaperRotationApplyService.qml"

for contract in \
    '## Phase 2B.6 closure — fit and automatic rotation' \
    '2B.6.1 Transactional wallpaper fit API                  ✓' \
    '2B.6.2 Wallpaper fit draft UI                           ✓' \
    '2B.6.3 Transactional automatic-rotation API             ✓' \
    '2B.6.4 Rotation observed state, draft and Apply service ✓' \
    '2B.6.5 Visible rotation controls + unified Apply/Reset  ✓' \
    '2B.6.6 End-to-end validation + documentation            ✓ COMPLETE' \
    'random -> next -> random' \
    'Successful rotation mutations may canonicalize' \
    'Exact byte restoration remains a' \
    'Phase 2B Wallpapers remains active' \
    'continues in Phase 2B.7'
do
    if grep -Fq -- "$contract" "$phase_2b6_wallpaper_doc"; then
        ok "Phase 2B.6 wallpaper closure: $contract"
    else
        fail "Phase 2B.6 wallpaper closure missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.6 closure — advanced wallpaper controls' \
    '2B.6 Advanced wallpaper controls  ✓ COMPLETE' \
    '2B   Wallpapers                    ACTIVE' \
    '2B.7                               NEXT' \
    'orchestration boundary, not a mutation' \
    'wallpaper-domain reconciliation' \
    'rotation-domain reconciliation' \
    'random -> next -> random' \
    'Closing 2B.6 does not close Phase 2B as a whole.'
do
    if grep -Fq -- "$contract" "$phase_2b6_architecture"; then
        ok "Phase 2B.6 architecture closure: $contract"
    else
        fail "Phase 2B.6 architecture closure missing: $contract"
    fi
done

for contract in \
    'applyService: root.wallpaperMutationCoordinatorHandle' \
    'onApplyRequested: wallpaperMutationCoordinator.applyDirty()' \
    'onResetRequested: wallpaperMutationCoordinator.resetDraft()'
do
    if grep -Fq -- "$contract" "$phase_2b6_main"; then
        ok "Phase 2B.6 unified Main routing: $contract"
    else
        fail "Phase 2B.6 unified Main routing missing: $contract"
    fi
done

for contract in \
    'root.draftStore.setRotationEnabled(value);' \
    'root.draftStore.setRotationMode(value);' \
    'root.draftStore.setRotationTarget(value);' \
    'root.draftStore.setRotationInterval(value);'
do
    if grep -Fq -- "$contract" "$phase_2b6_view"; then
        ok "Phase 2B.6 rotation draft UI: $contract"
    else
        fail "Phase 2B.6 rotation draft UI missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-wallpaperctl' \
    'systemctl' \
    'wallpaper.env' \
    'wallpaper-manager' \
    'wallpaper-rotation-manager'
do
    if grep -Fq -- "$forbidden" "$phase_2b6_rotation_control"; then
        fail "Phase 2B.6 presentation owns backend detail: $forbidden"
    else
        ok "Phase 2B.6 presentation excludes backend detail: $forbidden"
    fi

    if grep -Fq -- "$forbidden" "$phase_2b6_coordinator"; then
        fail "Phase 2B.6 coordinator owns backend detail: $forbidden"
    else
        ok "Phase 2B.6 coordinator excludes backend detail: $forbidden"
    fi
done

for contract in \
    'root.draftStore.hasWallpaperDirty' \
    'root.draftStore.rotationDirty' \
    'function startRotationAfterWallpaper(): void {' \
    'root.wallpaperApplyService.applyDirty();' \
    'root.rotationApplyService.applyDirty();' \
    'function continueRecoveryResetAfterWallpaper(): void {' \
    'function continueRecoveryResetAfterRotation(): void {'
do
    if grep -Fq -- "$contract" "$phase_2b6_coordinator"; then
        ok "Phase 2B.6 coordinator closure: $contract"
    else
        fail "Phase 2B.6 coordinator closure missing: $contract"
    fi
done

for contract in \
    '"rotation",' \
    '"apply"' \
    'root.draftStore.prepareForRefreshAfterRotationApply();' \
    'root.wallpaperService.rotationRuntimeSynchronized'
do
    if grep -Fq -- "$contract" "$phase_2b6_rotation_apply"; then
        ok "Phase 2B.6 rotation Apply boundary: $contract"
    else
        fail "Phase 2B.6 rotation Apply boundary missing: $contract"
    fi
done


printf '\n==> Wallpapers rotation visual polish\n'

rotation_polish="$config_dir/modules/wallpapers/WallpaperRotationControl.qml"
rotation_polish_view="$config_dir/modules/wallpapers/WallpaperView.qml"
rotation_polish_doc="$repo_root/docs/wallpaper-control.md"

for contract in \
    'iconName: "refresh"' \
    'iconName: "all"' \
    'iconName: "display"' \
    'function parseIntervalMinutes(value) {' \
    'function intervalFromMinutes(minutes) {' \
    'readonly property real intervalSliderValue:' \
    'readonly property bool intervalIsPreset:' \
    'Components.JcSlider {' \
    'id: intervalSlider' \
    'from: 5' \
    'to: 60' \
    'stepSize: 5' \
    'value: root.intervalSliderValue' \
    'onMoved:' \
    'root.intervalSelected(' \
    'model: root.intervalOptions.slice(0, 4)'
do
    if grep -Fq -- "$contract" "$rotation_polish"; then
        ok "Rotation visual polish: $contract"
    else
        fail "Rotation visual polish missing: $contract"
    fi
done

rotation_polish_shell="$config_dir/modules/controlcenter/ControlCenterShell.qml"
rotation_polish_shell_doc="$repo_root/docs/control-center-shell.md"

if grep -A 14 -F \
    'id: contentHost' \
    "$rotation_polish_shell" \
    | grep -Fq 'clip: true'
then
    ok "Control Center content host clips before footer"
else
    fail "Control Center content host viewport clipping missing"
fi

if grep -Fq \
    'Layout.bottomMargin: root.theme.spaceLg' \
    "$rotation_polish_view"
then
    fail "Wallpaper gallery still carries retired footer compensation margin"
else
    ok "Wallpaper gallery no longer compensates for shell footer"
fi

for contract in \
    'root.theme.controlHeightLarge * 2.95' \
    'root.theme.controlHeightLarge * 3.05' \
    'root.theme.controlHeightLarge * 2.55' \
    'Math.min(' \
    'Math.max('
do
    if grep -Fq -- "$contract" "$rotation_polish_view"; then
        ok "Wallpaper adaptive gallery contract: $contract"
    else
        fail "Wallpaper adaptive gallery contract missing: $contract"
    fi
done

for contract in \
    '### Content viewport ownership' \
    "\`contentHost\` clips hosted rendering" \
    'must not extend their drawing underneath the footer'
do
    if grep -Fq -- "$contract" "$rotation_polish_shell_doc"; then
        ok "Control Center viewport documentation: $contract"
    else
        fail "Control Center viewport documentation missing: $contract"
    fi
done

for contract in \
    '## Automatic rotation visual refinement' \
    "Interval editing uses the shared \`JcSlider\`" \
    "A non-preset value such as \`45m\` remains intact" \
    'The Control Center shell owns the content viewport boundary and clips hosted' \
    'This refinement is presentation-only.'
do
    if grep -Fq -- "$contract" "$rotation_polish_doc"; then
        ok "Rotation visual polish documentation: $contract"
    else
        fail "Rotation visual polish documentation missing: $contract"
    fi
done

for forbidden in \
    'property var draftStore' \
    'property var wallpaperService' \
    'property var applyService' \
    'Process {' \
    'jc-wallpaperctl' \
    'systemctl' \
    'wallpaper.env' \
    'wallpaper-manager' \
    'wallpaper-rotation-manager'
do
    if grep -Fq -- "$forbidden" "$rotation_polish"; then
        fail "Rotation visual polish crossed presentation boundary: $forbidden"
    else
        ok "Rotation visual polish preserves presentation boundary: $forbidden"
    fi
done


printf '\n==> JC Holo setting tiles + rotation panel composition\n'

setting_tile="$config_dir/components/JcSettingTile.qml"
rotation_tile_panel="$config_dir/modules/wallpapers/WallpaperRotationControl.qml"
rotation_tile_view="$config_dir/modules/wallpapers/WallpaperView.qml"
rotation_tile_doc="$repo_root/docs/wallpaper-control.md"
setting_tile_doc="$repo_root/docs/component-library.md"

for contract in \
    'required property var theme' \
    'property string text: ""' \
    'property string iconName: ""' \
    'property bool selected: false' \
    'property bool controlEnabled: true' \
    'signal clicked()' \
    'activeFocusOnTab: root.controlEnabled' \
    'JcInteractiveFrame {' \
    'JcIcon {' \
    'onPressed: root.forceActiveFocus()' \
    'onClicked: root.clicked()'
do
    if grep -Fq -- "$contract" "$setting_tile"; then
        ok "JcSettingTile contract: $contract"
    else
        fail "JcSettingTile contract missing: $contract"
    fi
done

for contract in \
    'Components.JcSettingTile {' \
    'model: root.modeOptions' \
    'model: root.targetOptions' \
    'orientation: Qt.Vertical' \
    'root.theme.controlHeightLarge * 3.70' \
    'Components.JcSlider {' \
    'id: intervalSlider' \
    'from: 5' \
    'to: 60' \
    'stepSize: 5' \
    'model: root.intervalOptions.slice(0, 4)'
do
    if grep -Fq -- "$contract" "$rotation_tile_panel"; then
        ok "Rotation tile-panel contract: $contract"
    else
        fail "Rotation tile-panel contract missing: $contract"
    fi
done

for contract in \
    'root.theme.controlHeightLarge * 2.72' \
    'root.theme.controlHeightLarge * 1.00' \
    'root.theme.controlHeightLarge * 2.95' \
    'root.theme.controlHeightLarge * 2.55' \
    'root.theme.controlHeightLarge * 3.05'
do
    if grep -Fq -- "$contract" "$rotation_tile_view"; then
        ok "Wallpaper vertical-budget contract: $contract"
    else
        fail "Wallpaper vertical-budget contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-wallpaperctl' \
    'systemctl' \
    'wallpaper.env' \
    'wallpaper-manager' \
    'wallpaper-rotation-manager'
do
    if grep -Fq -- "$forbidden" "$setting_tile"; then
        fail "JcSettingTile crossed presentation boundary: $forbidden"
    else
        ok "JcSettingTile excludes backend detail: $forbidden"
    fi

    if grep -Fq -- "$forbidden" "$rotation_tile_panel"; then
        fail "Rotation tile panel crossed presentation boundary: $forbidden"
    else
        ok "Rotation tile panel excludes backend detail: $forbidden"
    fi
done

for contract in \
    '## Automatic rotation tile layout' \
    "shared \`JcSettingTile\` presentation primitive" \
    'complete first wallpaper row' \
    'Library gallery regains a 2.95-control-height'
do
    if grep -Fq -- "$contract" "$rotation_tile_doc"; then
        ok "Rotation tile-layout documentation: $contract"
    else
        fail "Rotation tile-layout documentation missing: $contract"
    fi
done

for contract in \
    '### JcSettingTile' \
    'icon-over-label selection primitive' \
    'presentation-only' \
    'Themes, Quick Settings, Performance'
do
    if grep -Fq -- "$contract" "$setting_tile_doc"; then
        ok "JcSettingTile documentation: $contract"
    else
        fail "JcSettingTile documentation missing: $contract"
    fi
done


printf '\n==> Rotation tile inner-clearance + Fit proximity\n'

rotation_clearance_tile="$config_dir/components/JcSettingTile.qml"
rotation_clearance_panel="$config_dir/modules/wallpapers/WallpaperRotationControl.qml"
rotation_clearance_view="$config_dir/modules/wallpapers/WallpaperView.qml"
rotation_clearance_doc="$repo_root/docs/wallpaper-control.md"
rotation_clearance_component_doc="$repo_root/docs/component-library.md"

for contract in \
    'root.theme.controlHeightLarge * 0.98' \
    'root.theme.controlHeightLarge * 1.12'
do
    if grep -Fq -- "$contract" "$rotation_clearance_tile"; then
        ok "Compact JcSettingTile geometry: $contract"
    else
        fail "Compact JcSettingTile geometry missing: $contract"
    fi
done

if grep -Fq \
    'Layout.bottomMargin: root.theme.spaceSm' \
    "$rotation_clearance_panel"
then
    ok "Rotation body reserves lower HUD clearance"
else
    fail "Rotation body lower HUD clearance missing"
fi

for contract in \
    'spacing: root.theme.spaceSm' \
    'root.theme.controlHeightLarge * 1.00' \
    'Layout.alignment: Qt.AlignTop' \
    'root.theme.controlHeightLarge * 2.95' \
    'root.theme.controlHeightLarge * 2.55' \
    'root.theme.controlHeightLarge * 3.05'
do
    if grep -Fq -- "$contract" "$rotation_clearance_view"; then
        ok "Wallpaper compact vertical-budget contract: $contract"
    else
        fail "Wallpaper compact vertical-budget contract missing: $contract"
    fi
done

fit_align_count="$(
    grep -Fc \
        'Layout.alignment: Qt.AlignTop' \
        "$rotation_clearance_view" \
        || true
)"

if [[ "$fit_align_count" -eq 2 ]]; then
    ok "Both WallpaperFitControl instances align toward previews"
else
    fail "Expected 2 top-aligned WallpaperFitControl instances, got $fit_align_count"
fi

for contract in \
    '## Rotation inner-clearance and Fit proximity refinement' \
    '0.98-control-height body' \
    'Fit / Fill / Stretch / Center' \
    'Library remains at the accepted 2.95-control-height minimum'
do
    if grep -Fq -- "$contract" "$rotation_clearance_doc"; then
        ok "Rotation/Fit refinement documentation: $contract"
    else
        fail "Rotation/Fit refinement documentation missing: $contract"
    fi
done

for contract in \
    '#### JcSettingTile compact geometry' \
    '0.98-control-height body' \
    '1.12-control-height preferred width'
do
    if grep -Fq -- "$contract" "$rotation_clearance_component_doc"; then
        ok "JcSettingTile compact documentation: $contract"
    else
        fail "JcSettingTile compact documentation missing: $contract"
    fi
done

printf '\n==> Rotation HUD final breathing room\n'

rotation_breathing_panel="$config_dir/modules/wallpapers/WallpaperRotationControl.qml"
rotation_breathing_view="$config_dir/modules/wallpapers/WallpaperView.qml"
rotation_breathing_doc="$repo_root/docs/wallpaper-control.md"

for contract in \
    'root.theme.controlHeightLarge * 3.70' \
    'Layout.bottomMargin: root.theme.spaceSm'
do
    if grep -Fq -- "$contract" "$rotation_breathing_panel"; then
        ok "Rotation HUD breathing-room contract: $contract"
    else
        fail "Rotation HUD breathing-room contract missing: $contract"
    fi
done

for contract in \
    'root.theme.controlHeightLarge * 1.00' \
    'root.theme.controlHeightLarge * 2.95' \
    'root.theme.controlHeightLarge * 2.55' \
    'root.theme.controlHeightLarge * 3.05'
do
    if grep -Fq -- "$contract" "$rotation_breathing_view"; then
        ok "Preserved Wallpapers vertical-budget contract: $contract"
    else
        fail "Preserved Wallpapers vertical-budget contract missing: $contract"
    fi
done

for contract in \
    '## Rotation HUD final breathing room' \
    '3.70-control-height presentation footprint' \
    'frame clearance rather than larger controls'
do
    if grep -Fq -- "$contract" "$rotation_breathing_doc"; then
        ok "Rotation HUD breathing-room documentation: $contract"
    else
        fail "Rotation HUD breathing-room documentation missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.1b transactional transition backend\n'

transition_manager="$repo_root/scripts/runtime/wallpaper-transition-manager.sh"
rotation_manager="$repo_root/scripts/runtime/wallpaper-rotation-manager.sh"
transition_apply_runtime="$repo_root/scripts/runtime/apply-wallpaper.sh"
transition_docs="$repo_root/docs/wallpaper-control.md"
transition_arch="$repo_root/docs/architecture.md"

for contract in \
    'wallpaper-transition-manager.sh current --json' \
    'wallpaper-transition-manager.sh transactional-set' \
    "wallpaper_env_lock=\"\$local_dir/.wallpaper-env.mutation.lock\"" \
    'acquire_wallpaper_env_lock() {' \
    'acquire_theme_mutation_lock() {' \
    'write_transition_configuration() {' \
    'verify_expected_state() {' \
    'WALLPAPER_TRANSITION_PRESET' \
    'WALLPAPER_TRANSITION_TYPE' \
    'WALLPAPER_TRANSITION_DURATION' \
    'WALLPAPER_TRANSITION_FPS' \
    '__INHERIT__' \
    'return 6' \
    'return 7'
do
    if grep -Fq -- "$contract" "$transition_manager"; then
        ok "Transition manager contract: $contract"
    else
        fail "Transition manager contract missing: $contract"
    fi
done

for contract in \
    "lock_file=\"\$local_dir/.wallpaper-env.mutation.lock\"" \
    'write_rotation_configuration() {' \
    'verify_expected_state() {'
do
    if grep -Fq -- "$contract" "$rotation_manager"; then
        ok "Shared wallpaper.env rotation contract: $contract"
    else
        fail "Shared wallpaper.env rotation contract missing: $contract"
    fi
done

if grep -Fq '.wallpaper-rotation.mutation.lock' "$rotation_manager"; then
    fail "Rotation manager still uses legacy private wallpaper.env lock"
else
    ok "Rotation manager uses shared wallpaper.env lock"
fi

for forbidden in \
    'WALLPAPER_ROTATION_ENABLED' \
    'WALLPAPER_ROTATION_MODE' \
    'WALLPAPER_ROTATION_TARGET' \
    'WALLPAPER_ROTATION_INTERVAL'
do
    if grep -Fq -- "$forbidden" "$transition_manager"; then
        fail "Transition manager owns rotation assignment: $forbidden"
    else
        ok "Transition manager preserves rotation ownership: $forbidden"
    fi
done

for contract in \
    'THEME_WALLPAPER_TRANSITION_PRESET' \
    'TRANSITION_PRESET_TYPE=wipe' \
    'TRANSITION_PRESET_DURATION=1.6' \
    'TRANSITION_PRESET_TYPE=fade' \
    'TRANSITION_PRESET_DURATION=1.8' \
    'TRANSITION_PRESET_DURATION=1.2' \
    'TRANSITION_PRESET_FPS=60'
do
    if grep -Fq -- "$contract" "$transition_manager" \
        && grep -Fq -- "$contract" "$transition_apply_runtime"
    then
        ok "Transition preset resolution aligned: $contract"
    else
        fail "Transition preset resolution drift: $contract"
    fi
done

for contract in \
    '## Transactional transition backend' \
    'wallpaper-transition-manager.sh' \
    '.wallpaper-env.mutation.lock' \
    'active theme wallpaper mutation' \
    "Exit code \`6\`" \
    "Exit code \`7\`" \
    'Phase 2B.7.1c'
do
    if grep -Fq -- "$contract" "$transition_docs"; then
        ok "Transition backend documentation: $contract"
    else
        fail "Transition backend documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.1b Transition mutation ownership' \
    "global \`wallpaper.env\` mutation lock" \
    'per-theme wallpaper mutation lock' \
    '2B.7.1c'
do
    if grep -Fq -- "$contract" "$transition_arch"; then
        ok "Transition backend architecture: $contract"
    else
        fail "Transition backend architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.1c stable transition CLI API\n'

transition_cli="$repo_root/scripts/runtime/jc-wallpaperctl.sh"
transition_install="$repo_root/scripts/install.sh"
transition_doctor="$repo_root/scripts/doctor.sh"
transition_docs="$repo_root/docs/wallpaper-control.md"
transition_arch="$repo_root/docs/architecture.md"

for contract in \
    'jc-wallpaperctl transition status [--json]' \
    'jc-wallpaperctl transition apply' \
    "transition_manager=\"\$base/bin/wallpaper-transition-manager.sh\"" \
    'transition_apply() {' \
    'transition_command() {' \
    'requested_preset="__KEEP__"' \
    'requested_type="__KEEP__"' \
    'requested_duration="__KEEP__"' \
    'requested_fps="__KEEP__"' \
    'requested_type="__INHERIT__"' \
    'requested_duration="__INHERIT__"' \
    'requested_fps="__INHERIT__"' \
    'transition)' \
    'transition_command "$@"'
do
    if grep -Fq -- "$contract" "$transition_cli"; then
        ok "Stable transition CLI contract: $contract"
    else
        fail "Stable transition CLI contract missing: $contract"
    fi
done

for forbidden in \
    'wallpaper.env' \
    'flock -x' \
    'WALLPAPER_TRANSITION_PRESET=' \
    'WALLPAPER_TRANSITION_TYPE='
do
    if grep -Fq -- "$forbidden" "$transition_cli"; then
        fail "Stable CLI crossed transition persistence boundary: $forbidden"
    else
        ok "Stable CLI excludes transition persistence detail: $forbidden"
    fi
done

for contract in \
    'wallpaper-transition-manager.sh' \
    "\"\$bin_dir/wallpaper-transition-manager.sh\""
do
    if grep -Fq -- "$contract" "$transition_install"; then
        ok "Installer transition runtime-link contract: $contract"
    else
        fail "Installer transition runtime-link contract missing: $contract"
    fi
done

if grep -Fq \
    '"wallpaper-transition-manager.sh:scripts/runtime/wallpaper-transition-manager.sh"' \
    "$transition_doctor"
then
    ok "Doctor validates internal transition manager runtime link"
else
    fail "Doctor transition manager runtime-link contract missing"
fi

for contract in \
    '## Stable transition CLI API' \
    'jc-wallpaperctl transition status' \
    'jc-wallpaperctl transition apply' \
    "friendly \`inherit\`" \
    "verified rollback code \`6\`" \
    'Phase 2B.7.2'
do
    if grep -Fq -- "$contract" "$transition_docs"; then
        ok "Stable transition CLI documentation: $contract"
    else
        fail "Stable transition CLI documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.1c Stable transition API boundary' \
    'jc-wallpaperctl transition status/apply' \
    'wallpaper-transition-manager.sh' \
    'not promoted to' \
    'Phase 2B.7.2'
do
    if grep -Fq -- "$contract" "$transition_arch"; then
        ok "Stable transition API architecture: $contract"
    else
        fail "Stable transition API architecture missing: $contract"
    fi
done

if grep -R -Fq \
    'wallpaper-transition-manager' \
    "$config_dir"
then
    fail "QML references internal transition manager before Phase 2B.7.2"
else
    ok "QML remains isolated from internal transition manager"
fi


printf '\n==> Phase 2B.7.2b observed transition state\n'

transition_observed_service="$config_dir/services/WallpaperService.qml"
transition_observed_draft="$config_dir/services/WallpaperDraftStore.qml"
transition_observed_docs="$repo_root/docs/wallpaper-control.md"
transition_observed_arch="$repo_root/docs/architecture.md"

for contract in \
    'property string transitionPreset: ""' \
    'property string transitionResolvedPreset: ""' \
    'property var transitionTypeOverride: null' \
    'property var transitionDurationOverride: null' \
    'property var transitionFpsOverride: null' \
    'property string transitionEffectiveType: ""' \
    'property real transitionEffectiveDuration: 0' \
    'property int transitionEffectiveFps: 0' \
    'property var pendingTransitionStatus: null' \
    'function validTransitionStatus(payload) {' \
    'function commitSnapshot(status, transition, catalog): void {' \
    'id: transitionStatusProcess' \
    '"transition",' \
    '"status",' \
    'root.pendingTransitionStatus = response;' \
    'Wallpaper transition changed during refresh; retry.'
do
    if grep -Fq -- "$contract" "$transition_observed_service"; then
        ok "Observed transition service contract: $contract"
    else
        fail "Observed transition service contract missing: $contract"
    fi
done

for forbidden in \
    'wallpaper-transition-manager' \
    'wallpaper.env' \
    'WALLPAPER_TRANSITION_PRESET' \
    'WALLPAPER_TRANSITION_TYPE' \
    'WALLPAPER_TRANSITION_DURATION' \
    'WALLPAPER_TRANSITION_FPS'
do
    if grep -Fq -- "$forbidden" "$transition_observed_service"; then
        fail "WallpaperService crossed transition backend boundary: $forbidden"
    else
        ok "WallpaperService excludes backend detail: $forbidden"
    fi
done

for forbidden in \
    'wallpaper-transition-manager' \
    'wallpaper.env' \
    'WALLPAPER_TRANSITION_PRESET'
do
    if grep -Fq -- "$forbidden" "$transition_observed_draft"; then
        fail "WallpaperDraftStore crossed backend boundary: $forbidden"
    else
        ok "WallpaperDraftStore excludes backend detail: $forbidden"
    fi
done

for contract in \
    '## Observed transition state' \
    'nullable' \
    'concurrent refresh conflict' \
    'Draft, Apply, coordinator and visual'
do
    if grep -Fq -- "$contract" "$transition_observed_docs"; then
        ok "Observed transition documentation: $contract"
    else
        fail "Observed transition documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.2b Transition observed-state ownership' \
    'three read' \
    'Transition override nullability' \
    'No transition mutation'
do
    if grep -Fq -- "$contract" "$transition_observed_arch"; then
        ok "Observed transition architecture: $contract"
    else
        fail "Observed transition architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.2c transition draft foundation\n'

transition_draft="$config_dir/services/WallpaperDraftStore.qml"
transition_service="$config_dir/services/WallpaperService.qml"
transition_draft_docs="$repo_root/docs/wallpaper-control.md"
transition_draft_arch="$repo_root/docs/architecture.md"

for contract in \
    'property string draftTransitionPreset: "theme"' \
    'property var draftTransitionTypeOverride: null' \
    'property var draftTransitionDurationOverride: null' \
    'property var draftTransitionFpsOverride: null' \
    'property string baselineTransitionPreset: "theme"' \
    'property string baselineTransitionResolvedPreset: ""' \
    'property var baselineTransitionTypeOverride: null' \
    'property var baselineTransitionDurationOverride: null' \
    'property var baselineTransitionFpsOverride: null' \
    'readonly property bool transitionPresetDirty:' \
    'readonly property bool transitionTypeDirty:' \
    'readonly property bool transitionDurationDirty:' \
    'readonly property bool transitionFpsDirty:' \
    'readonly property bool transitionDirty:' \
    'readonly property bool hasAnyDraftDirty:' \
    'signal transitionChanged()' \
    'signal transitionResetCompleted()' \
    'function validTransitionPreset(preset) {' \
    'function validTransitionType(type) {' \
    'function syncTransitionFromObserved(): void {' \
    'function setTransitionPreset(preset): void {' \
    'function setTransitionTypeOverride(value): void {' \
    'function setTransitionDurationOverride(value): void {' \
    'function setTransitionFpsOverride(value): void {' \
    'function prepareForRefreshAfterTransitionApply(): void {' \
    'function resetTransition(): void {' \
    'root.syncAfterApplyDomain = "transition";' \
    'else if (domain === "transition")'
do
    if grep -Fq -- "$contract" "$transition_draft"; then
        ok "Transition draft contract: $contract"
    else
        fail "Transition draft contract missing: $contract"
    fi
done

if grep -Fq \
    'readonly property bool transitionDirty:' \
    "$transition_draft"
then
    ok "Transition draft dirty ownership remains defined"
else
    fail "Transition draft dirty ownership missing"
fi

if grep -Fq \
    'readonly property bool hasAnyDraftDirty:' \
    "$transition_draft"
then
    ok "Transition refresh-protection dirty contract remains defined"
else
    fail "Transition refresh-protection dirty contract missing"
fi

for contract in \
    'root.hasAnyDraftDirty' \
    'root.observedDiffersFromBaseline()' \
    'root.syncTransitionFromObserved();'
do
    if grep -Fq -- "$contract" "$transition_draft"; then
        ok "Transition reconcile contract: $contract"
    else
        fail "Transition reconcile contract missing: $contract"
    fi
done

for forbidden in \
    'wallpaper-transition-manager' \
    'wallpaper.env' \
    'WALLPAPER_TRANSITION_PRESET' \
    'jc-wallpaperctl transition apply'
do
    if grep -Fq -- "$forbidden" "$transition_draft"; then
        fail "Transition DraftStore crossed backend/Apply boundary: $forbidden"
    else
        ok "Transition DraftStore excludes backend/Apply detail: $forbidden"
    fi
done

for observed_contract in \
    'property var transitionTypeOverride: null' \
    'property var transitionDurationOverride: null' \
    'property var transitionFpsOverride: null'
do
    if grep -Fq -- "$observed_contract" "$transition_service"; then
        ok "Draft source observed contract: $observed_contract"
    else
        fail "Draft source observed contract missing: $observed_contract"
    fi
done

for contract in \
    '## Transition draft and reconcile foundation' \
    'hasAnyDraftDirty' \
    "not folded into the existing \`dirtyCount\`" \
    'Phase 2B.7.3'
do
    if grep -Fq -- "$contract" "$transition_draft_docs"; then
        ok "Transition draft documentation: $contract"
    else
        fail "Transition draft documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.2c Transition draft ownership' \
    'nullable override semantics' \
    'hasAnyDraftDirty' \
    'Phase 2B.7.3'
do
    if grep -Fq -- "$contract" "$transition_draft_arch"; then
        ok "Transition draft architecture: $contract"
    else
        fail "Transition draft architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.3b transition Apply service\n'

transition_apply_service="$config_dir/services/WallpaperTransitionApplyService.qml"
transition_apply_draft="$config_dir/services/WallpaperDraftStore.qml"
transition_apply_coordinator="$config_dir/services/WallpaperMutationCoordinator.qml"
transition_apply_main="$config_dir/Main.qml"
transition_apply_view="$config_dir/modules/wallpapers/WallpaperView.qml"
transition_apply_docs="$repo_root/docs/wallpaper-control.md"
transition_apply_arch="$repo_root/docs/architecture.md"

if [[ -f "$transition_apply_service" ]]; then
    ok "WallpaperTransitionApplyService.qml"
else
    fail "WallpaperTransitionApplyService.qml missing"
fi

for contract in \
    'property var wallpaperService' \
    'property var draftStore' \
    'property bool applying: false' \
    'property bool awaitingRefresh: false' \
    'property bool recoveryResetPending: false' \
    'property bool rollbackRecoveryRequired: false' \
    'readonly property bool canApply:' \
    '&& root.draftStore.transitionDirty' \
    'signal applied()' \
    'signal rolledBack(string message)' \
    'signal rollbackFailed(string message)' \
    'signal failed(string message)' \
    'function validateApply() {' \
    'function buildApplyArguments() {' \
    'function buildRecoveryArguments() {' \
    'function responseMatchesDraft(response) {' \
    'function observedMatchesStatus(response) {' \
    'function applyDirty(): void {' \
    'function resetDraft(): void {' \
    '"transition",' \
    '"apply"' \
    '"--preset"' \
    '"--type"' \
    '"--duration"' \
    '"--fps"' \
    '? "inherit"' \
    'args.push("--json");' \
    'exitCode === 6' \
    'exitCode === 7' \
    'The recovery attempt rolled back successfully' \
    'previously unverified runtime state' \
    'root.draftStore.prepareForRefreshAfterTransitionApply();' \
    'root.draftStore.resetTransition();' \
    'function onTransitionChanged() {' \
    'function onTransitionResetCompleted() {'
do
    if grep -Fq -- "$contract" "$transition_apply_service"; then
        ok "Transition Apply service contract: $contract"
    else
        fail "Transition Apply service contract missing: $contract"
    fi
done

for forbidden in \
    'wallpaper-transition-manager' \
    'wallpaper.env' \
    'WALLPAPER_TRANSITION_PRESET' \
    '__INHERIT__' \
    '__KEEP__'
do
    if grep -Fq -- "$forbidden" "$transition_apply_service"; then
        fail "Transition Apply service crossed public boundary: $forbidden"
    else
        ok "Transition Apply service excludes backend detail: $forbidden"
    fi
done

if grep -Fq \
    'readonly property bool transitionDirty:' \
    "$transition_apply_draft"
then
    ok "Transition draft ownership remains available to Apply service"
else
    fail "Transition draft ownership missing"
fi

for forbidden in \
    'jc-wallpaperctl transition apply' \
    'wallpaper-transition-manager' \
    'wallpaper.env'
do
    if grep -Fq -- "$forbidden" "$transition_apply_coordinator"; then
        fail "Coordinator crossed transition mutation boundary: $forbidden"
    else
        ok "Coordinator excludes transition mutation detail: $forbidden"
    fi
done

if grep -Fq 'jc-wallpaperctl transition apply' "$transition_apply_main"; then
    fail "Main crossed transition mutation boundary"
else
    ok "Main contains no direct transition mutation"
fi

for forbidden in \
    'WallpaperTransitionApplyService' \
    'transitionApplyService' \
    'jc-wallpaperctl transition apply' \
    'wallpaper-transition-manager'
do
    if grep -Fq -- "$forbidden" "$transition_apply_view"; then
        fail "WallpaperView crossed transition Apply boundary: $forbidden"
    else
        ok "WallpaperView excludes transition Apply detail: $forbidden"
    fi
done

for contract in \
    '## Transition Apply service' \
    "Exit code \`6\`" \
    "Exit code \`7\`" \
    'Recovery Reset' \
    'Only a successful recovery transaction' \
    'does **not** clear recovery state' \
    'Phase 2B.7.3c'
do
    if grep -Fq -- "$contract" "$transition_apply_docs"; then
        ok "Transition Apply documentation: $contract"
    else
        fail "Transition Apply documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.3b Transition Apply ownership' \
    'stable public transition mutation' \
    'rollback exit-code' \
    "Recovery is cleared only after an \`rc=0\`" \
    "An \`rc=6\` during recovery remains recovery-required" \
    'Phase 2B.7.3c'
do
    if grep -Fq -- "$contract" "$transition_apply_arch"; then
        ok "Transition Apply architecture: $contract"
    else
        fail "Transition Apply architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.3c unified transition coordinator\n'

transition_coord_draft="$config_dir/services/WallpaperDraftStore.qml"
transition_coord_service="$config_dir/services/WallpaperTransitionApplyService.qml"
transition_coord="$config_dir/services/WallpaperMutationCoordinator.qml"
transition_coord_main="$config_dir/Main.qml"
transition_coord_view="$config_dir/modules/wallpapers/WallpaperView.qml"
transition_coord_docs="$repo_root/docs/wallpaper-control.md"
transition_coord_arch="$repo_root/docs/architecture.md"

for contract in \
    '+ (root.transitionDirty ? 1 : 0)' \
    'readonly property bool hasAnyDraftDirty: root.hasDirty'
do
    if grep -Fq -- "$contract" "$transition_coord_draft"; then
        ok "Transition dirty promotion: $contract"
    else
        fail "Transition dirty promotion missing: $contract"
    fi
done

for contract in \
    'property var transitionApplyService' \
    'property bool sequenceTransitionPending: false' \
    'root.transitionApplyService.applying' \
    'root.transitionApplyService.awaitingRefresh' \
    'root.transitionApplyService.busy' \
    'root.transitionApplyService.rollbackRecoveryRequired' \
    'root.draftStore.transitionDirty' \
    '!root.transitionApplyService.canApply' \
    'function startTransitionAfterWallpaper(): void {' \
    'function startRotationAfterTransition(): void {' \
    'root.transitionApplyService.applyDirty();' \
    'const transitionDirty = root.draftStore.transitionDirty;' \
    'root.sequenceTransitionPending = transitionDirty;' \
    'root.recoveryResetOwner = "transition";' \
    'function continueRecoveryResetAfterTransition(): void {' \
    'target: root.transitionApplyService' \
    'function onTransitionResetCompleted() {'
do
    if grep -Fq -- "$contract" "$transition_coord"; then
        ok "Unified transition coordinator contract: $contract"
    else
        fail "Unified transition coordinator contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-wallpaperctl' \
    'wallpaper-transition-manager' \
    'wallpaper.env' \
    'WALLPAPER_TRANSITION_'
do
    if grep -Fq -- "$forbidden" "$transition_coord"; then
        fail "Coordinator bypasses mutation owner: $forbidden"
    else
        ok "Coordinator excludes mutation detail: $forbidden"
    fi
done

for contract in \
    'wallpaperTransitionApplyServiceHandle:' \
    'Services.WallpaperTransitionApplyService {' \
    'id: wallpaperTransitionApplyService' \
    'transitionApplyService: wallpaperTransitionApplyService' \
    'applyService: root.wallpaperMutationCoordinatorHandle' \
    'onApplyRequested: wallpaperMutationCoordinator.applyDirty()' \
    'onResetRequested: wallpaperMutationCoordinator.resetDraft()'
do
    if grep -Fq -- "$contract" "$transition_coord_main"; then
        ok "Main transition coordinator wiring: $contract"
    else
        fail "Main transition coordinator wiring missing: $contract"
    fi
done

for contract in \
    'readonly property bool canApply:' \
    '&& root.draftStore.transitionDirty' \
    'root.draftStore.prepareForRefreshAfterTransitionApply();'
do
    if grep -Fq -- "$contract" "$transition_coord_service"; then
        ok "Transition Apply owner remains intact: $contract"
    else
        fail "Transition Apply owner contract missing: $contract"
    fi
done

for forbidden in \
    'WallpaperTransitionApplyService' \
    'transitionApplyService' \
    'jc-wallpaperctl' \
    'Process {'
do
    if grep -Fq -- "$forbidden" "$transition_coord_view"; then
        fail "WallpaperView bypasses unified coordinator: $forbidden"
    else
        ok "WallpaperView preserves unified coordinator boundary: $forbidden"
    fi
done

for contract in \
    '## Unified transition sequencing' \
    'Wallpaper -> Transition -> Rotation' \
    'first failing domain stops the sequence' \
    'transitionDirty' \
    'Phase 2B.7.4'
do
    if grep -Fq -- "$contract" "$transition_coord_docs"; then
        ok "Unified transition documentation: $contract"
    else
        fail "Unified transition documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.3c Unified transition sequencing' \
    'Wallpaper -> Transition -> Rotation' \
    'recovery order' \
    'single Apply/Reset surface' \
    'Phase 2B.7.4'
do
    if grep -Fq -- "$contract" "$transition_coord_arch"; then
        ok "Unified transition architecture: $contract"
    else
        fail "Unified transition architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.4b JC Holo transition control surface\n'

transition_ui="$config_dir/modules/wallpapers/WallpaperTransitionControl.qml"
transition_ui_view="$config_dir/modules/wallpapers/WallpaperView.qml"
transition_ui_draft="$config_dir/services/WallpaperDraftStore.qml"
transition_ui_apply="$config_dir/services/WallpaperTransitionApplyService.qml"
transition_ui_coord="$config_dir/services/WallpaperMutationCoordinator.qml"
transition_ui_docs="$repo_root/docs/wallpaper-control.md"
transition_ui_arch="$repo_root/docs/architecture.md"

if [[ -f "$transition_ui" ]]; then
    ok "WallpaperTransitionControl.qml"
else
    fail "WallpaperTransitionControl.qml missing"
fi

for contract in \
    'property bool controlEnabled: true' \
    'property bool draftDirty: false' \
    'property bool fpsDirty: false' \
    'property string presetValue: "theme"' \
    'property var typeOverrideValue: null' \
    'property var durationOverrideValue: null' \
    'property var fpsOverrideValue: null' \
    'property bool observedReady: false' \
    'property string observedPreset: ""' \
    'property string observedResolvedPreset: ""' \
    'property string observedEffectiveType: ""' \
    'property real observedEffectiveDuration: 0' \
    'property int observedEffectiveFps: 0' \
    'readonly property bool showAdvanced:' \
    'signal presetSelected(string value)' \
    'signal typeSelected(string value)' \
    'signal durationSelected(string value)' \
    'signal fpsSelected(string value)' \
    '"label": "Inherit preset"' \
    '"value": "inherit"' \
    '"value": "cyber-noir"' \
    '"value": "odyssey-glass"' \
    '"value": "wave"' \
    '"value": "wipe"' \
    'function buildDurationOptions() {' \
    'function buildFpsOptions() {' \
    'text: "Wallpaper transition"' \
    'text: root.observedSummary' \
    'text: "Advanced"' \
    'text: "Preset"' \
    'text: "Effect"' \
    'text: "Duration"' \
    'text: "Transition FPS"'
do
    if grep -Fq -- "$contract" "$transition_ui"; then
        ok "Transition UI contract: $contract"
    else
        fail "Transition UI contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-wallpaperctl' \
    'WallpaperTransitionApplyService' \
    'WallpaperMutationCoordinator' \
    'wallpaper-transition-manager' \
    'wallpaper.env' \
    'WALLPAPER_TRANSITION_' \
    'applyDirty()' \
    'resetDraft()'
do
    if grep -Fq -- "$forbidden" "$transition_ui"; then
        fail "Transition control crossed presentation boundary: $forbidden"
    else
        ok "Transition control excludes mutation detail: $forbidden"
    fi
done

for contract in \
    'WallpaperTransitionControl {' \
    'draftStore.transitionDirty' \
    'draftStore.transitionFpsDirty' \
    'draftStore.draftTransitionPreset' \
    'draftStore.draftTransitionTypeOverride' \
    'draftStore.draftTransitionDurationOverride' \
    'draftStore.draftTransitionFpsOverride' \
    'wallpaperService.transitionPreset' \
    'wallpaperService.transitionResolvedPreset' \
    'wallpaperService.transitionEffectiveType' \
    'wallpaperService.transitionEffectiveDuration' \
    'wallpaperService.transitionEffectiveFps' \
    'draftStore.setTransitionPreset(value);' \
    'draftStore.setTransitionTypeOverride(value);' \
    'draftStore.setTransitionDurationOverride(value);' \
    'draftStore.setTransitionFpsOverride(value);'
do
    if grep -Fq -- "$contract" "$transition_ui_view"; then
        ok "WallpaperView transition presentation wiring: $contract"
    else
        fail "WallpaperView transition presentation wiring missing: $contract"
    fi
done

if python3 - "$transition_ui_view" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

transition = text.find("WallpaperTransitionControl {")
rotation = text.find("WallpaperRotationControl {")

if transition < 0 or rotation < 0 or transition >= rotation:
    raise SystemExit(
        "WallpaperTransitionControl must remain directly before Rotation"
    )

if text.count('signal applyRequested()') != 1:
    raise SystemExit("WallpaperView must keep exactly one Apply signal")

if text.count('signal resetRequested()') != 1:
    raise SystemExit("WallpaperView must keep exactly one Reset signal")
PY
then
    ok "Transition block precedes Rotation and keeps one Apply/Reset surface"
else
    fail "Transition block placement or Apply/Reset surface changed"
fi

for contract in \
    'function setTransitionPreset(preset): void {' \
    'function setTransitionTypeOverride(value): void {' \
    'function setTransitionDurationOverride(value): void {' \
    'function setTransitionFpsOverride(value): void {'
do
    if grep -Fq -- "$contract" "$transition_ui_draft"; then
        ok "Transition UI uses existing DraftStore API: $contract"
    else
        fail "Transition DraftStore setter missing: $contract"
    fi
done

for file in \
    "$transition_ui_apply" \
    "$transition_ui_coord"
do
    if git diff --quiet HEAD -- "$file"; then
        ok "2B.7.4b leaves mutation composition unchanged: $file"
    else
        fail "2B.7.4b unexpectedly changed mutation composition: $file"
    fi
done

for contract in \
    '## JC Holo transition control surface' \
    'Preset, Effect and Duration' \
    'Advanced' \
    'FPS' \
    'single Apply/Reset' \
    'Phase 2B.7.4'
do
    if grep -Fq -- "$contract" "$transition_ui_docs"; then
        ok "Transition UI documentation: $contract"
    else
        fail "Transition UI documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.4b Transition presentation ownership' \
    'presentation-only' \
    'WallpaperTransitionControl' \
    'WallpaperDraftStore' \
    'single Apply/Reset' \
    'advanced FPS'
do
    if grep -Fq -- "$contract" "$transition_ui_arch"; then
        ok "Transition UI architecture: $contract"
    else
        fail "Transition UI architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.4c3 Wallpapers hosted overflow\n'

wallpaper_overflow_view="$config_dir/modules/wallpapers/WallpaperView.qml"
wallpaper_overflow_transition="$config_dir/modules/wallpapers/WallpaperTransitionControl.qml"
wallpaper_overflow_docs="$repo_root/docs/wallpaper-control.md"
wallpaper_overflow_arch="$repo_root/docs/architecture.md"

for contract in \
    'id: wallpaperSettingsFlickable' \
    'Layout.fillHeight: true' \
    'contentWidth: width' \
    'contentHeight: wallpaperSettingsColumn.implicitHeight' \
    'flickableDirection: Flickable.VerticalFlick' \
    'boundsBehavior: Flickable.StopAtBounds' \
    'id: wallpaperSettingsColumn' \
    'width: wallpaperSettingsFlickable.width' \
    'Controls.ScrollBar.vertical: Controls.ScrollBar {' \
    'Layout.preferredHeight:' \
    'root.theme.controlHeightLarge * 3.35'
do
    if grep -Fq -- "$contract" "$wallpaper_overflow_view"; then
        ok "Wallpapers hosted-overflow contract: $contract"
    else
        fail "Wallpapers hosted-overflow contract missing: $contract"
    fi
done

if python3 - "$wallpaper_overflow_view" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")

flick = text.find("id: wallpaperSettingsFlickable")
transition = text.find("WallpaperTransitionControl {")
rotation = text.find("WallpaperRotationControl {")
library = text.find('title: "Library"')
grid = text.find("id: wallpaperGrid")

if min(flick, transition, rotation, library, grid) < 0:
    raise SystemExit(1)

if not (flick < transition < rotation < library < grid):
    raise SystemExit(1)

settings_start = text.rfind("Flickable {", 0, flick)
settings_slice = text[settings_start:library]

if "GridView {" in settings_slice:
    raise SystemExit(1)
PY
then
    ok "Settings and Library keep separate vertical scroll ownership"
else
    fail "Settings/Library vertical scroll ownership regressed"
fi

for contract in \
    'transitionContent.implicitHeight' \
    '+ (root.theme.spaceMd * 2)' \
    'id: transitionContent'
do
    if grep -Fq -- "$contract" "$wallpaper_overflow_transition"; then
        ok "Transition natural geometry: $contract"
    else
        fail "Transition natural geometry missing: $contract"
    fi
done

if grep -Fq \
    'root.showAdvanced ? 4.08 : 2.34' \
    "$wallpaper_overflow_transition"
then
    fail "Transition still uses magic collapsed/Advanced heights"
else
    ok "Transition magic collapsed/Advanced heights retired"
fi

for contract in \
    '## Wallpapers hosted overflow' \
    'settings Flickable' \
    'Library GridView' \
    'content-driven' \
    'separate vertical scroll ownership'
do
    if grep -Fq -- "$contract" "$wallpaper_overflow_docs"; then
        ok "Wallpapers overflow documentation: $contract"
    else
        fail "Wallpapers overflow documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7.4c3 Wallpapers overflow ownership' \
    'settings Flickable' \
    'Library GridView' \
    'content-driven geometry' \
    'nested vertical scroll'
do
    if grep -Fq -- "$contract" "$wallpaper_overflow_arch"; then
        ok "Wallpapers overflow architecture: $contract"
    else
        fail "Wallpapers overflow architecture missing: $contract"
    fi
done


printf '\n==> Phase 2B.7.5b formal closure\n'

phase_2b7_readme="$repo_root/README.md"
phase_2b7_docs="$repo_root/docs/wallpaper-control.md"
phase_2b7_arch="$repo_root/docs/architecture.md"

for contract in \
    '## Phase 2B.7 — Wallpaper transitions (CLOSED)' \
    'cc5587c  transactional transition API' \
    'df5fd2e  observed + draft transition state' \
    '9dca4a7  unified transition Apply workflow' \
    '9aed1fd  JC Holo transition controls + hosted overflow' \
    'Phase 2B.7 is **CLOSED**'
do
    if grep -Fq -- "$contract" "$phase_2b7_readme"; then
        ok "2B.7 README closure: $contract"
    else
        fail "2B.7 README closure missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7 closure' \
    'Apply:    Wallpaper -> Transition -> Rotation' \
    'Recovery: Wallpaper -> Transition -> Rotation' \
    'content-driven Transition HUD geometry' \
    'one global Apply/Reset surface' \
    'Phase 2B.7 is formally **CLOSED**'
do
    if grep -Fq -- "$contract" "$phase_2b7_docs"; then
        ok "2B.7 wallpaper docs closure: $contract"
    else
        fail "2B.7 wallpaper docs closure missing: $contract"
    fi
done

for contract in \
    '## Phase 2B.7 final architecture (CLOSED)' \
    'WallpaperTransitionControl' \
    'WallpaperMutationCoordinator' \
    'WallpaperTransitionApplyService' \
    'jc-wallpaperctl transition' \
    'wallpaper-transition-manager.sh' \
    'Phase 2B.7 is **CLOSED**'
do
    if grep -Fq -- "$contract" "$phase_2b7_arch"; then
        ok "2B.7 architecture closure: $contract"
    else
        fail "2B.7 architecture closure missing: $contract"
    fi
done


printf '\n==> Phase 2B overall closure / Phase 2C handoff\n'

phase_2b_handoff_readme="$repo_root/README.md"
phase_2b_handoff_docs="$repo_root/docs/wallpaper-control.md"
phase_2b_handoff_arch="$repo_root/docs/architecture.md"

for contract in \
    '- [x] **Phase 2B — Wallpapers**' \
    '- [x] **Phase 2C — Themes**' \
    '- [ ] **Phase 2D — Quick Settings** ← **NEXT**'
do
    if grep -Fq -- "$contract" "$phase_2b_handoff_readme"; then
        ok "Roadmap handoff README: $contract"
    else
        fail "Roadmap handoff README missing: $contract"
    fi
done

if grep -Fq -- \
    '- [ ] **Phase 2C — Themes** ← **NEXT**' \
    "$phase_2b_handoff_readme"
then
    fail "README still marks Phase 2C as NEXT"
else
    ok "README no longer marks Phase 2C as NEXT"
fi

for contract in \
    '## Phase 2B overall closure' \
    'Phase 2B — **Wallpapers** is complete.' \
    'Phase 2B is **CLOSED**' \
    'Phase 2C — Themes'
do
    if grep -Fq -- "$contract" "$phase_2b_handoff_docs"; then
        ok "Phase 2B module closure: $contract"
    else
        fail "Phase 2B module closure missing: $contract"
    fi
done

for contract in \
    '├── Wallpapers  ✓ COMPLETE' \
    '├── Themes      ✓ COMPLETE' \
    '├── Quick Settings ← NEXT' \
    '## Phase 2B overall closure and Phase 2C handoff' \
    'installed theme discovery' \
    'live theme previews' \
    'active theme state' \
    'theme application'
do
    if grep -Fq -- "$contract" "$phase_2b_handoff_arch"; then
        ok "Architecture roadmap handoff: $contract"
    else
        fail "Architecture roadmap handoff missing: $contract"
    fi
done


printf '\n==> Phase 2C.1b stable theme read API\n'

phase_2c_theme_script="$repo_root/scripts/theme.sh"
phase_2c_theme_doc="$repo_root/docs/theme-control.md"
phase_2c_arch="$repo_root/docs/architecture.md"
phase_2c_readme="$repo_root/README.md"
phase_2c_theme_qml="$repo_root/config/quickshell/jc-hyprland/theme/Theme.qml"

for contract in \
    'theme.sh status [--json]' \
    'theme.sh catalog [--json]' \
    'status_json() {' \
    'catalog_json() {' \
    'activeFileTheme:' \
    'activeLinkTheme:' \
    'synchronized:' \
    'preview:' \
    'mainWallpaper:' \
    'secondaryWallpaper:'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_script"; then
        ok "Theme read API: $contract"
    else
        fail "Theme read API missing: $contract"
    fi
done

for contract in \
    '# Theme Control Architecture' \
    '## Phase 2C.1b — Stable theme read API' \
    'jc-theme status --json' \
    'jc-theme catalog --json' \
    'Live preview strategy' \
    'Mutation boundary remains deferred' \
    'ThemeService' \
    'ThemeApplyService'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "Theme control documentation: $contract"
    else
        fail "Theme control documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.1b stable theme read boundary' \
    'Theme.qml' \
    'jc-theme catalog' \
    'future ThemeService' \
    'Themes navigation entry remains disabled'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "Theme architecture: $contract"
    else
        fail "Theme architecture missing: $contract"
    fi
done

for contract in \
    'Three themes are currently included.' \
    '## JC Holo' \
    '### Stable Theme Control read API' \
    'jc-theme status --json' \
    'jc-theme catalog --json'
do
    if grep -Fq -- "$contract" "$phase_2c_readme"; then
        ok "README Theme Control: $contract"
    else
        fail "README Theme Control missing: $contract"
    fi
done

# Historical phase guard: navigation enablement may evolve later.
if [[ -f "$config_dir/modules/controlcenter/ControlCenterNavigation.qml" ]]; then
    ok "Themes navigation entry remains structurally present"
else
    fail "Themes navigation file is missing"
fi

if grep -Fq 'Process {' "$phase_2c_theme_qml"; then
    fail "Theme.qml must remain free of Process ownership"
else
    ok "Theme.qml remains free of Process ownership"
fi


printf '\n==> Phase 2C.1c ThemeService observed state\n'

phase_2c_theme_service="$config_dir/services/ThemeService.qml"
phase_2c_main="$config_dir/Main.qml"
phase_2c_theme_qml="$config_dir/theme/Theme.qml"
phase_2c_theme_doc="$repo_root/docs/theme-control.md"
phase_2c_arch="$repo_root/docs/architecture.md"

for contract in \
    'Scope {' \
    'property var themes: []' \
    'property string activeThemeId: ""' \
    'property string activeFileThemeId: ""' \
    'property string activeLinkThemeId: ""' \
    'property bool isSynchronized: false' \
    'property bool activeThemeValid: false' \
    'readonly property int themeCount:' \
    'readonly property var activeTheme:' \
    'readonly property bool observedHealthy:' \
    'function themeCommandPath() {' \
    'function themeById(themeId) {' \
    'function validStatusPayload(payload) {' \
    'function validCatalogPayload(payload) {' \
    'function refresh() {' \
    'function retrySnapshotIfNeeded(reason) {' \
    'function commitSnapshot(statusPayload, catalogPayload) {' \
    '"status",' \
    '"catalog",' \
    '"--json"' \
    'Process {' \
    'StdioCollector {' \
    'Component.onCompleted: root.refresh()'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_service"; then
        ok "ThemeService contract: $contract"
    else
        fail "ThemeService contract missing: $contract"
    fi
done

for forbidden in \
    '"apply"' \
    'local/active-theme"' \
    'ln -s' \
    'hyprctl' \
    'systemctl' \
    'start-waybar' \
    'start-swaync' \
    'apply-wallpaper' \
    'sddm-switch'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_service"; then
        fail "ThemeService mutation/backend leakage: $forbidden"
    else
        ok "ThemeService excludes mutation/backend detail: $forbidden"
    fi
done

for contract in \
    'readonly property var themeServiceHandle: themeService' \
    'Services.ThemeService {' \
    'id: themeService'
do
    if grep -Fq -- "$contract" "$phase_2c_main"; then
        ok "Main ThemeService wiring: $contract"
    else
        fail "Main ThemeService wiring missing: $contract"
    fi
done

if grep -Fq 'Process {' "$phase_2c_theme_qml"; then
    fail "Theme.qml gained Process ownership"
else
    ok "Theme.qml remains independent semantic FileView API"
fi

# Historical phase guard: navigation enablement may evolve later.
if [[ -f "$config_dir/modules/controlcenter/ControlCenterNavigation.qml" ]]; then
    ok "Themes navigation entry remains structurally present"
else
    fail "Themes navigation file is missing"
fi

for contract in \
    '## Phase 2C.1c — ThemeService observed-state boundary' \
    'status -> catalog' \
    'themeServiceHandle' \
    'still does not enable Themes navigation'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "ThemeService documentation: $contract"
    else
        fail "ThemeService documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.1c ThemeService observed-state architecture' \
    'Theme.qml' \
    'ThemeService' \
    'one bounded retry' \
    'No mutation owner is introduced'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "ThemeService architecture: $contract"
    else
        fail "ThemeService architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C.1d ThemeDraftStore foundation\n'

phase_2c_theme_draft="$config_dir/services/ThemeDraftStore.qml"
phase_2c_theme_service="$config_dir/services/ThemeService.qml"
phase_2c_main="$config_dir/Main.qml"
phase_2c_theme_qml="$config_dir/theme/Theme.qml"
phase_2c_theme_doc="$repo_root/docs/theme-control.md"
phase_2c_arch="$repo_root/docs/architecture.md"

for contract in \
    'Scope {' \
    'property var themeService' \
    'property string draftThemeId: ""' \
    'property string baselineThemeId: ""' \
    'property bool initialized: false' \
    'property bool observedChangedWhileDirty: false' \
    'readonly property bool dirty:' \
    'readonly property bool hasDirty: root.dirty' \
    'readonly property int dirtyCount:' \
    'readonly property var draftTheme:' \
    'readonly property var baselineTheme:' \
    'readonly property bool draftValid:' \
    'function validThemeId(themeId) {' \
    'function setTheme(themeId) {' \
    'function syncFromObserved(force) {' \
    'function reset() {' \
    'Connections {' \
    'function onRefreshed() {' \
    'Component.onCompleted: root.syncFromObserved(true)'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_draft"; then
        ok "ThemeDraftStore contract: $contract"
    else
        fail "ThemeDraftStore contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-theme' \
    '"apply"' \
    'local/active-theme' \
    'hyprctl' \
    'systemctl' \
    'start-waybar' \
    'start-swaync' \
    'apply-wallpaper' \
    'sddm'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_draft"; then
        fail "ThemeDraftStore mutation/backend leakage: $forbidden"
    else
        ok "ThemeDraftStore excludes mutation/backend detail: $forbidden"
    fi
done

for contract in \
    'readonly property var themeDraftStoreHandle: themeDraftStore' \
    'Services.ThemeDraftStore {' \
    'id: themeDraftStore' \
    'themeService: themeService'
do
    if grep -Fq -- "$contract" "$phase_2c_main"; then
        ok "Main ThemeDraftStore wiring: $contract"
    else
        fail "Main ThemeDraftStore wiring missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.1d — ThemeDraftStore selection/baseline foundation' \
    'observedChangedWhileDirty' \
    'setTheme(id)' \
    'reset()' \
    'themeDraftStoreHandle' \
    'does not enable Themes navigation'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "ThemeDraftStore documentation: $contract"
    else
        fail "ThemeDraftStore documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.1d theme draft-state architecture' \
    'ThemeService' \
    'ThemeDraftStore' \
    'observedChangedWhileDirty' \
    'No Theme Apply backend/service is introduced'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "ThemeDraftStore architecture: $contract"
    else
        fail "ThemeDraftStore architecture missing: $contract"
    fi
done

# Historical phase guard: navigation enablement may evolve later.
if [[ -f "$config_dir/modules/controlcenter/ControlCenterNavigation.qml" ]]; then
    ok "Themes navigation entry remains structurally present"
else
    fail "Themes navigation file is missing"
fi

if grep -Fq 'Process {' "$phase_2c_theme_qml"; then
    fail "Theme.qml gained Process ownership"
else
    ok "Theme.qml remains independent semantic FileView API"
fi

if grep -Fq '"apply"' "$phase_2c_theme_service"; then
    fail "ThemeService gained mutation ownership"
else
    ok "ThemeService remains read-only"
fi


printf '\n==> Phase 2C.2b transactional Theme Apply backend\n'

phase_2c_theme_public="$repo_root/scripts/theme.sh"
phase_2c_theme_manager="$repo_root/scripts/runtime/theme-transaction-manager.sh"
phase_2c_theme_doc="$repo_root/docs/theme-control.md"
phase_2c_arch="$repo_root/docs/architecture.md"

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for contract in \
    'theme.sh apply THEME [--json]' \
    'theme-transaction-manager.sh' \
    'apply_theme() {' \
    '"$transaction_manager" apply "$@"'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_public"; then
        ok "Transactional public Theme Apply: $contract"
    else
        fail "Transactional public Theme Apply missing: $contract"
    fi
done

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for forbidden in \
    'ln -sfn' \
    '> "$active_file"' \
    'sudo -n "$sddm_switch"' \
    'hyprctl reload >/dev/null 2>&1 || true'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_public"; then
        fail "Public jc-theme retains legacy mutation detail: $forbidden"
    else
        ok "Public jc-theme excludes internal mutation detail: $forbidden"
    fi
done

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for contract in \
    'theme_lock="$local_dir/.theme.mutation.lock"' \
    'wallpaper_env_lock="$local_dir/.wallpaper-env.mutation.lock"' \
    'flock -x 9' \
    'flock -x 8' \
    'apply_transaction() {' \
    'capture_snapshot() {' \
    'apply_identity() {' \
    'restore_identity() {' \
    'apply_critical_runtime() {' \
    'rollback_critical_runtime() {' \
    'synchronize_sddm_auxiliary() {' \
    '"rolled-back" 6' \
    '"rollback-failed" 7' \
    'identityRestored' \
    'runtimeRollbackVerified'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_manager"; then
        ok "Theme transaction manager: $contract"
    else
        fail "Theme transaction manager missing: $contract"
    fi
done

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for contract in \
    '## Phase 2C.2b — Transactional Theme Apply backend' \
    'rc=0  applied' \
    'rc=2  invalid-request' \
    'rc=6  rolled-back' \
    'rc=7  rollback-failed' \
    'SDDM is auxiliary' \
    'local/.theme.mutation.lock' \
    'local/.wallpaper-env.mutation.lock' \
    'adds no `ThemeApplyService`'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "Theme transaction documentation: $contract"
    else
        fail "Theme transaction documentation missing: $contract"
    fi
done

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for contract in \
    '## Phase 2C.2b transactional theme mutation architecture' \
    'theme-transaction-manager.sh' \
    'wallpaper coordination locks' \
    'auxiliary SDDM synchronization' \
    'Exit codes `0 / 2 / 6 / 7`' \
    'No QML mutation service'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "Theme transaction architecture: $contract"
    else
        fail "Theme transaction architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C.2b mutation-lock FD inheritance\n'

phase_2c_theme_manager="$repo_root/scripts/runtime/theme-transaction-manager.sh"
phase_2c_theme_doc="$repo_root/docs/theme-control.md"
phase_2c_arch="$repo_root/docs/architecture.md"

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for contract in \
    'run_without_mutation_locks() {' \
    'exec 9>&- 8>&- 7>&- 6>&-' \
    'run_without_mutation_locks "$wallpaper_apply"' \
    'run_without_mutation_locks "$waybar_runtime"' \
    '"$swaync_runtime" --restart' \
    '"$sddm_prepare"' \
    'sudo -n "$sddm_switch" "$target_theme"'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_manager"; then
        ok "Theme child lock-FD boundary: $contract"
    else
        fail "Theme child lock-FD boundary missing: $contract"
    fi
done

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for forbidden in \
    '    "$wallpaper_apply" >/dev/null' \
    '    "$waybar_runtime" >/dev/null' \
    '    "$swaync_runtime" --restart >/dev/null'
do
    if grep -Fxq -- "$forbidden" "$phase_2c_theme_manager"; then
        fail "Theme consumer bypasses child lock-FD boundary: $forbidden"
    else
        ok "Theme consumer uses child lock-FD boundary: $forbidden"
    fi
done

for contract in \
    '## Phase 2C.2b hardening — mutation lock FD inheritance' \
    'close FD 9' \
    'close FD 8' \
    'close FD 7' \
    'close FD 6' \
    'post-Apply lock-leak sentinel'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "Theme lock inheritance documentation: $contract"
    else
        fail "Theme lock inheritance documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2b mutation-lock child boundary' \
    'close 9/8/7/6' \
    'preventing long-lived processes' \
    'post-Apply lock-leak sentinel'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "Theme lock inheritance architecture: $contract"
    else
        fail "Theme lock inheritance architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C explicit Theme runtime recovery API\n'

phase_2c_theme_public="$repo_root/scripts/theme.sh"
phase_2c_theme_manager="$repo_root/scripts/runtime/theme-transaction-manager.sh"
phase_2c_theme_doc="$repo_root/docs/theme-control.md"
phase_2c_arch="$repo_root/docs/architecture.md"

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for contract in \
    'theme.sh recover [--json]' \
    'recover_theme() {' \
    '"$transaction_manager" recover "$@"'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_public"; then
        ok "Public Theme recovery API: $contract"
    else
        fail "Public Theme recovery API missing: $contract"
    fi
done

# Literal grep -F contracts intentionally contain shell syntax.
# shellcheck disable=SC2016
for contract in \
    'theme-transaction-manager.sh recover [--json]' \
    'recover_runtime() {' \
    'target_theme="$previous_theme"' \
    '"recovered" 0 true false false false true false' \
    '"recovery-failed" 7 false false false false false false' \
    'Theme runtime recovered and verified.' \
    'Theme runtime recovery could not be verified.'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_manager"; then
        ok "Theme recovery manager: $contract"
    else
        fail "Theme recovery manager missing: $contract"
    fi
done

# Same-theme Apply must stay a no-op; recovery is a separate operation.
# shellcheck disable=SC2016
for contract in \
    'if [[ "$target_theme" == "$previous_theme" ]]; then' \
    '"Theme is already active."'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_manager"; then
        ok "Same-theme Apply no-op preserved: $contract"
    else
        fail "Same-theme Apply no-op contract missing: $contract"
    fi
done

for contract in \
    '## Phase 2C — explicit Theme runtime recovery API' \
    'jc-theme recover [--json]' \
    'status=recovered' \
    'status=recovery-failed' \
    'same-theme Apply' \
    'rollbackRecoveryRequired = true' \
    'A successful Recovery does not discard'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "Theme recovery documentation: $contract"
    else
        fail "Theme recovery documentation missing: $contract"
    fi
done

# Literal grep -F architecture contracts include Markdown backticks.
# shellcheck disable=SC2016
for contract in \
    '## Phase 2C explicit Theme runtime recovery boundary' \
    'jc-theme recover --json' \
    'Same-theme `apply` remains a no-op' \
    'ThemeApplyService.rollbackRecoveryRequired'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "Theme recovery architecture: $contract"
    else
        fail "Theme recovery architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C ThemeApplyService foundation\n'

phase_2c_theme_apply="$config_dir/services/ThemeApplyService.qml"
phase_2c_theme_draft="$config_dir/services/ThemeDraftStore.qml"
phase_2c_main="$config_dir/Main.qml"
phase_2c_theme_qml="$config_dir/theme/Theme.qml"
phase_2c_theme_service="$config_dir/services/ThemeService.qml"
phase_2c_theme_doc="$repo_root/docs/theme-control.md"
phase_2c_arch="$repo_root/docs/architecture.md"

# Literal grep -F contracts intentionally contain QML syntax.
# shellcheck disable=SC2016
for contract in \
    'property var themeService' \
    'property var draftStore' \
    'property bool rollbackRecoveryRequired: false' \
    'readonly property bool canApply:' \
    'readonly property bool canRecover:' \
    'function applyDirty()' \
    'function recoverRuntime()' \
    'validAppliedResponse' \
    'validRolledBackResponse' \
    'validRollbackFailedResponse' \
    'validInvalidRequestResponse' \
    'validRecoveredResponse' \
    'validRecoveryFailedResponse' \
    'Qt.callLater(root.finishObservedRefresh)'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_apply"; then
        ok "ThemeApplyService contract: $contract"
    else
        fail "ThemeApplyService contract missing: $contract"
    fi
done

for forbidden in \
    'active-theme' \
    'theme-transaction-manager' \
    '.mutation.lock' \
    'hyprctl' \
    'apply-wallpaper' \
    'start-waybar' \
    'start-swaync' \
    'sddm'
do
    if grep -Fiq -- "$forbidden" "$phase_2c_theme_apply"; then
        fail "ThemeApplyService knows backend detail: $forbidden"
    else
        ok "ThemeApplyService excludes backend detail: $forbidden"
    fi
done

# Literal grep -F contracts intentionally contain QML syntax.
# shellcheck disable=SC2016
for contract in \
    'property bool syncAfterApplyPending: false' \
    'property string syncAfterApplyThemeId: ""' \
    'function prepareForRefreshAfterApply(themeId)' \
    'if (root.syncAfterApplyPending)' \
    'root.syncFromObserved(true)'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_draft"; then
        ok "ThemeDraftStore Apply reconciliation: $contract"
    else
        fail "ThemeDraftStore Apply reconciliation missing: $contract"
    fi
done

# Literal grep -F contracts intentionally contain QML syntax.
# shellcheck disable=SC2016
for contract in \
    '|| themeApplyService.busy' \
    'readonly property var themeApplyServiceHandle: themeApplyService' \
    'Services.ThemeApplyService {' \
    'themeService: themeService' \
    'draftStore: themeDraftStore'
do
    if grep -Fq -- "$contract" "$phase_2c_main"; then
        ok "ThemeApplyService composition: $contract"
    else
        fail "ThemeApplyService composition missing: $contract"
    fi
done

# Historical phase guard: navigation enablement may evolve later.
if [[ -f "$config_dir/modules/controlcenter/ControlCenterNavigation.qml" ]]; then
    ok "Themes navigation entry remains structurally present"
else
    fail "Themes navigation file is missing"
fi

if git diff --quiet HEAD -- "$phase_2c_theme_qml"; then
    ok "Theme.qml semantic API unchanged by ThemeApplyService foundation"
else
    fail "Theme.qml changed during ThemeApplyService foundation"
fi

# ThemeService's read-only boundary is validated semantically by the
# Phase 2C.1c contract and mutation/backend leakage checks above.
#
# Do not compare ThemeService.qml against HEAD here. Legitimate later fixes to
# the observed-state service must not invalidate the ThemeApplyService
# architecture contract.

# Literal grep -F documentation contracts include Markdown backticks.
# shellcheck disable=SC2016
for contract in \
    '## Phase 2C — ThemeApplyService mutation foundation' \
    'jc-theme apply THEME --json' \
    'jc-theme recover --json' \
    'rollbackRecoveryRequired=true' \
    'prepareForRefreshAfterApply(themeId)' \
    'does not create `ThemeView.qml`'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "ThemeApplyService documentation: $contract"
    else
        fail "ThemeApplyService documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C ThemeApplyService architecture' \
    'public mutation + recovery orchestration' \
    'rollbackRecoveryRequired' \
    'Recovery does not discard a pending draft' \
    'Theme navigation and ThemeView remain deferred'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "ThemeApplyService architecture: $contract"
    else
        fail "ThemeApplyService architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C.2.1 ThemeView foundation\n'

phase_2c_theme_view="$config_dir/modules/themes/ThemeView.qml"
phase_2c_theme_navigation="$config_dir/modules/controlcenter/ControlCenterNavigation.qml"

if [[ -f "$phase_2c_theme_view" ]]; then
    ok "ThemeView foundation file"
else
    fail "ThemeView.qml missing"
fi

for contract in \
    'Item {' \
    'required property var theme' \
    'property var themeService' \
    'property var draftStore' \
    'readonly property string activeThemeId:' \
    'readonly property int installedThemeCount:' \
    'readonly property string draftThemeId:' \
    'readonly property bool draftDirty:' \
    'Observed theme:' \
    'Draft synchronized with observed state'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_view"; then
        ok "ThemeView foundation contract: $contract"
    else
        fail "ThemeView foundation contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-theme' \
    'hyprctl' \
    'systemctl' \
    'active-theme' \
    'theme-transaction-manager'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_view"; then
        fail "ThemeView mutation/backend leakage: $forbidden"
    else
        ok "ThemeView excludes mutation/backend detail: $forbidden"
    fi
done

for contract in \
    'import qs.modules.themes as Themes' \
    'moduleId === "themes"' \
    'id: shellThemesComponent' \
    'Themes.ThemeView {' \
    'themeService: root.themeServiceHandle' \
    'draftStore: root.themeDraftStoreHandle' \
    '? shellThemesComponent'
do
    if grep -Fq -- "$contract" "$phase_2c_main"; then
        ok "Main ThemeView wiring: $contract"
    else
        fail "Main ThemeView wiring missing: $contract"
    fi
done

if grep -A 8 -F 'id: "themes"' "$phase_2c_theme_navigation" \
    | grep -Fq 'enabled: true'
then
    ok "Themes navigation entry is enabled"
else
    fail "Themes navigation entry must be enabled in Phase 2C.2.1"
fi

for contract in \
    '## Phase 2C.2.1 — ThemeView foundation' \
    'ThemeView.qml' \
    'navigation entry is enabled' \
    'does not invoke Apply'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "ThemeView documentation: $contract"
    else
        fail "ThemeView documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.1 ThemeView foundation' \
    'read-only visual consumer' \
    'ThemeService -> ThemeView' \
    'ThemeDraftStore -> ThemeView'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "ThemeView architecture: $contract"
    else
        fail "ThemeView architecture missing: $contract"
    fi
done



printf '\n==> Phase 2C.2.2 Theme preview cards\n'

phase_2c_theme_view="$config_dir/modules/themes/ThemeView.qml"
phase_2c_theme_preview_card="$config_dir/modules/themes/ThemePreviewCard.qml"

if [[ -f "$phase_2c_theme_preview_card" ]]; then
    ok "ThemePreviewCard file"
else
    fail "ThemePreviewCard.qml missing"
fi

for contract in \
    'required property var theme' \
    'property var themeData' \
    'readonly property var previewData:' \
    'readonly property var colorData:' \
    'readonly property string mainWallpaperPath:' \
    'readonly property string secondaryWallpaperPath:' \
    'readonly property color previewPrimary:' \
    'readonly property color previewSecondary:' \
    'readonly property color previewAccent:' \
    'function localSource(path)' \
    'function fileName(path)' \
    'Components.JcSurface {' \
    'id: mainPreview' \
    'root.previewData.mainWallpaper' \
    'root.previewData.secondaryWallpaper' \
    'Main · ' \
    'Secondary · '
do
    if grep -Fq -- "$contract" "$phase_2c_theme_preview_card"; then
        ok "ThemePreviewCard contract: $contract"
    else
        fail "ThemePreviewCard contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-theme' \
    '"apply"' \
    'applyDirty' \
    'setTheme(' \
    'reset()' \
    'hyprctl' \
    'systemctl' \
    'theme-transaction-manager'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_preview_card"; then
        fail "ThemePreviewCard mutation/selection leakage: $forbidden"
    else
        ok "ThemePreviewCard excludes mutation/selection detail: $forbidden"
    fi
done

for contract in \
    'readonly property var themes:' \
    '? root.themeService.themes' \
    'GridView {' \
    'id: themeGrid' \
    'model: root.themes' \
    'delegate: ThemePreviewCard {' \
    'required property int index' \
    'themeData: root.themes[index]' \
    'cacheBuffer: cellHeight * 2'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_view"; then
        ok "ThemeView preview-grid contract: $contract"
    else
        fail "ThemeView preview-grid contract missing: $contract"
    fi
done

for forbidden in \
    'applyDirty' \
    'onActivated:' \
    'signal themeSelected'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_view"; then
        fail "ThemeView preview phase interaction leakage: $forbidden"
    else
        ok "ThemeView preview phase remains read-only: $forbidden"
    fi
done

for contract in \
    '## Phase 2C.2.2 — Theme preview cards' \
    'ThemePreviewCard.qml' \
    'preview.mainWallpaper' \
    'preview.secondaryWallpaper' \
    'colors' \
    'read-only'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "Theme preview documentation: $contract"
    else
        fail "Theme preview documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.2 Theme preview-card architecture' \
    'ThemeService.themes' \
    'ThemePreviewCard' \
    'read-only catalog projection' \
    "nested \`preview\` object"
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "Theme preview architecture: $contract"
    else
        fail "Theme preview architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C.2.3 ACTIVE / DRAFT selection state\n'

phase_2c_theme_view="$config_dir/modules/themes/ThemeView.qml"
phase_2c_theme_preview_card="$config_dir/modules/themes/ThemePreviewCard.qml"

for contract in \
    'property bool observedActive: false' \
    'property bool draftSelected: false' \
    'signal selected(string themeId)' \
    'readonly property string selectionStateLabel:' \
    '? (root.observedActive ? "ACTIVE · DRAFT" : "DRAFT")' \
    ': (root.observedActive ? "ACTIVE" : "")' \
    'selected: root.draftSelected' \
    'text: "ACTIVE"' \
    'text: "DRAFT"' \
    'MouseArea {' \
    'root.selected(root.themeId);'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_preview_card"; then
        ok "Theme card ACTIVE/DRAFT contract: $contract"
    else
        fail "Theme card ACTIVE/DRAFT contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-theme' \
    '"apply"' \
    'applyDirty' \
    'reset()' \
    'hyprctl' \
    'systemctl' \
    'theme-transaction-manager'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_preview_card"; then
        fail "Theme card owns forbidden mutation/backend detail: $forbidden"
    else
        ok "Theme card excludes mutation/backend detail: $forbidden"
    fi
done

for contract in \
    'function selectTheme(themeId): void {' \
    'root.draftStore.setTheme(candidate)' \
    'Preview a theme, stage a draft, then choose Apply or Reset.' \
    'observedActive:' \
    'themeId === root.activeThemeId' \
    'draftSelected:' \
    'themeId === root.draftThemeId' \
    'onSelected: themeId =>' \
    'root.selectTheme(themeId)'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_view"; then
        ok "ThemeView draft-selection contract: $contract"
    else
        fail "ThemeView draft-selection contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'jc-theme' \
    'applyDirty' \
    'reset()' \
    'hyprctl' \
    'systemctl' \
    'theme-transaction-manager'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_view"; then
        fail "ThemeView owns forbidden Apply/backend detail: $forbidden"
    else
        ok "ThemeView remains draft-only: $forbidden"
    fi
done

for contract in \
    '## Phase 2C.2.3 — ACTIVE / DRAFT selection state' \
    'ThemeDraftStore.setTheme()' \
    'ACTIVE' \
    'DRAFT' \
    'does not apply'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "Theme selection documentation: $contract"
    else
        fail "Theme selection documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.3 ACTIVE / DRAFT architecture' \
    'ThemePreviewCard.selected(themeId)' \
    'ThemeView.selectTheme(themeId)' \
    'ThemeDraftStore.setTheme(themeId)' \
    'draft-only mutation boundary'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "Theme selection architecture: $contract"
    else
        fail "Theme selection architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C.2.4 Quickshell token visual preview\n'

phase_2c_theme_preview_card="$config_dir/modules/themes/ThemePreviewCard.qml"
phase_2c_theme_token_preview="$config_dir/modules/themes/ThemeTokenPreview.qml"

if [[ -f "$phase_2c_theme_token_preview" ]]; then
    ok "ThemeTokenPreview file"
else
    fail "ThemeTokenPreview.qml missing"
fi

for contract in \
    'required property var theme' \
    'property var themeData' \
    'readonly property var colorData:' \
    'readonly property var opacityData:' \
    'readonly property bool tokenDataReady:' \
    'function colorToken(name, fallback)' \
    'function opacityToken(name, fallback)' \
    'root.colorToken("canvas", root.theme.canvas)' \
    'root.colorToken("surfaceBase", root.theme.surfaceBase)' \
    'root.colorToken("surfaceRaised", root.theme.surfaceRaised)' \
    'readonly property color surfaceInteractive:' \
    'root.colorToken("textPrimary", root.theme.textPrimary)' \
    'root.colorToken("textSecondary", root.theme.textSecondary)' \
    'root.colorToken("textMuted", root.theme.textMuted)' \
    'root.colorToken("primary", root.theme.primary)' \
    'root.colorToken("secondary", root.theme.secondary)' \
    'root.colorToken("accent", root.theme.accent)' \
    'root.colorToken("success", root.theme.success)' \
    'root.colorToken("warning", root.theme.warning)' \
    'root.colorToken("danger", root.theme.danger)' \
    'root.colorToken("info", root.theme.info)' \
    'root.opacityToken("surfaceGlass", 0.78)' \
    'root.opacityToken("surfaceGlassRaised", 0.86)' \
    'root.opacityToken("surfaceSelected", 0.16)' \
    'root.opacityToken("borderStrong", 0.38)' \
    'root.opacityToken("borderAccent", 0.34)' \
    'text: "Semantic token preview"'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_token_preview"; then
        ok "ThemeTokenPreview contract: $contract"
    else
        fail "ThemeTokenPreview contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'FileView {' \
    'jc-theme' \
    '"apply"' \
    'applyDirty' \
    'setTheme(' \
    'reset()' \
    'hyprctl' \
    'systemctl' \
    'theme-transaction-manager'
do
    if grep -Fq -- "$forbidden" "$phase_2c_theme_token_preview"; then
        fail "ThemeTokenPreview owns forbidden runtime/backend detail: $forbidden"
    else
        ok "ThemeTokenPreview remains pure presentation: $forbidden"
    fi
done

for contract in \
    'ThemeTokenPreview {' \
    'id: tokenPreview' \
    'theme: root.theme' \
    'themeData: root.themeData' \
    'z: 1' \
    'z: 2'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_preview_card"; then
        ok "ThemePreviewCard token-preview composition: $contract"
    else
        fail "ThemePreviewCard token-preview composition missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.4 — Quickshell token visual preview' \
    'ThemeTokenPreview.qml' \
    'colors' \
    'opacity' \
    'common schema-v1 token core' \
    'does not apply'
do
    if grep -Fq -- "$contract" "$phase_2c_theme_doc"; then
        ok "Theme token preview documentation: $contract"
    else
        fail "Theme token preview documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.4 Quickshell token-preview architecture' \
    'ThemeService.themes' \
    'ThemeTokenPreview' \
    'colors + opacity' \
    'current Theme API' \
    'presentation-only'
do
    if grep -Fq -- "$contract" "$phase_2c_arch"; then
        ok "Theme token preview architecture: $contract"
    else
        fail "Theme token preview architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C.2.5 Theme Apply / Reset UI wiring\n'

phase_2c25_theme_view="$config_dir/modules/themes/ThemeView.qml"
phase_2c25_theme_card="$config_dir/modules/themes/ThemePreviewCard.qml"
phase_2c25_main="$config_dir/Main.qml"
phase_2c25_theme_apply="$config_dir/services/ThemeApplyService.qml"
phase_2c25_theme_draft="$config_dir/services/ThemeDraftStore.qml"
phase_2c25_theme_doc="$repo_root/docs/theme-control.md"
phase_2c25_arch="$repo_root/docs/architecture.md"

# Literal grep -F contracts intentionally contain QML syntax.
# shellcheck disable=SC2016
for contract in \
    'property var applyService' \
    'readonly property bool interactionLocked:' \
    'readonly property bool observedConflict:' \
    'readonly property bool recoveryRequired:' \
    'readonly property string operationError:' \
    'signal refreshRequested()' \
    'signal applyRequested()' \
    'signal resetRequested()' \
    'signal recoverRequested()' \
    'Preview a theme, stage a draft, then choose Apply or Reset.' \
    'root.applyService.canApply' \
    'root.applyService.canRecover' \
    'text: "Reset"' \
    ': "Recover Runtime"' \
    'onClicked: root.applyRequested()' \
    'onClicked: root.resetRequested()' \
    'onClicked: root.recoverRequested()' \
    'onClicked: root.refreshRequested()' \
    '!root.interactionLocked' \
    '!root.observedConflict'
do
    if grep -Fq -- "$contract" "$phase_2c25_theme_view"; then
        ok "Theme Apply/Reset UI contract: $contract"
    else
        fail "Theme Apply/Reset UI contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'FileView {' \
    'jc-theme' \
    'theme-transaction-manager' \
    'local/active-theme' \
    'hyprctl' \
    'systemctl' \
    'start-waybar' \
    'start-swaync' \
    'apply-wallpaper' \
    'sddm'
do
    if grep -Fq -- "$forbidden" "$phase_2c25_theme_view"; then
        fail "ThemeView bypasses Theme service boundary: $forbidden"
    else
        ok "ThemeView excludes backend/runtime detail: $forbidden"
    fi
done

# Literal grep -F contracts intentionally contain QML syntax.
# shellcheck disable=SC2016
for contract in \
    'property bool controlEnabled: true' \
    'root.theme.opacityDisabled' \
    'enabled: root.controlEnabled' \
    'hoverEnabled: root.controlEnabled'
do
    if grep -Fq -- "$contract" "$phase_2c25_theme_card"; then
        ok "Theme card mutation lock contract: $contract"
    else
        fail "Theme card mutation lock contract missing: $contract"
    fi
done

# Literal grep -F contracts intentionally contain QML syntax.
# shellcheck disable=SC2016
for contract in \
    'if (root.activeModuleId === "themes") {' \
    'return "Applying theme…";' \
    'return "Recovering theme runtime…";' \
    'return "Reconciling theme state…";' \
    'return "Theme recovery required";' \
    'return "Theme Apply error";' \
    'return "Theme state changed";' \
    '+ " theme draft(s) pending";' \
    'return "Refreshing themes…";' \
    'return "Theme service error";' \
    'return themeService.themeCount + " themes available";' \
    'return themeApplyService.statusMessage;' \
    'return "Review the theme draft, then choose Apply or Reset.";' \
    'function prepareThemes() {' \
    'root.prepareThemes();' \
    'themeDraftStore.reset();' \
    'themeApplyService.clearTransientFeedback();' \
    'applyService: root.themeApplyServiceHandle' \
    'onRefreshRequested: themeService.refresh()' \
    'onApplyRequested: themeApplyService.applyDirty()' \
    'onRecoverRequested: themeApplyService.recoverRuntime()'
do
    if grep -Fq -- "$contract" "$phase_2c25_main"; then
        ok "Main Theme Apply/Reset orchestration: $contract"
    else
        fail "Main Theme Apply/Reset orchestration missing: $contract"
    fi
done

for contract in \
    'readonly property bool canApply:' \
    'readonly property bool canRecover:' \
    'function applyDirty()' \
    'function recoverRuntime()' \
    'function clearTransientFeedback()' \
    'root.draftStore.prepareForRefreshAfterApply(' \
    'root.themeService.refresh();'
do
    if grep -Fq -- "$contract" "$phase_2c25_theme_apply"; then
        ok "ThemeApplyService reused lifecycle: $contract"
    else
        fail "ThemeApplyService lifecycle prerequisite missing: $contract"
    fi
done

for contract in \
    'function reset() {' \
    'root.baselineThemeId = observed;' \
    'root.draftThemeId = observed;' \
    'root.resetCompleted();'
do
    if grep -Fq -- "$contract" "$phase_2c25_theme_draft"; then
        ok "ThemeDraftStore Reset lifecycle: $contract"
    else
        fail "ThemeDraftStore Reset lifecycle missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.5 — Apply / Reset UI wiring' \
    'ThemeApplyService.applyDirty()' \
    'ThemeDraftStore.reset()' \
    'ThemeApplyService.recoverRuntime()' \
    'Reset is intentionally separate from runtime Recovery' \
    'Closing the Control Center now resets the Theme draft'
do
    if grep -Fq -- "$contract" "$phase_2c25_theme_doc"; then
        ok "Theme Apply/Reset documentation: $contract"
    else
        fail "Theme Apply/Reset documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.5 Theme Apply / Reset wiring architecture' \
    'ThemeApplyService` remains the only QML mutation boundary' \
    'Reset and Recovery are deliberately independent state transitions.' \
    'controlCenterTransitionLocked'
do
    if grep -Fq -- "$contract" "$phase_2c25_arch"; then
        ok "Theme Apply/Reset architecture: $contract"
    else
        fail "Theme Apply/Reset architecture missing: $contract"
    fi
done


printf '\n==> Phase 2C.2.6 Theme keyboard / focus / scroll\n'

phase_2c26_theme_view="$config_dir/modules/themes/ThemeView.qml"
phase_2c26_theme_card="$config_dir/modules/themes/ThemePreviewCard.qml"
phase_2c26_theme_doc="$repo_root/docs/theme-control.md"
phase_2c26_arch="$repo_root/docs/architecture.md"

# Literal grep -F contracts intentionally contain QML syntax.
# shellcheck disable=SC2016
for contract in \
    'import QtQuick.Controls as Controls' \
    'function normalizeGridCurrentIndex(): void {' \
    'function activateCurrentGridItem(): void {' \
    'activeFocusOnTab:' \
    'keyNavigationEnabled:' \
    'keyNavigationWraps: false' \
    'highlightFollowsCurrentItem: false' \
    'boundsBehavior: Flickable.StopAtBounds' \
    'keyboardCurrent:' \
    'themeGrid.activeFocus' \
    'themeGrid.currentIndex' \
    'themeGrid.forceActiveFocus();' \
    'onCountChanged:' \
    'Qt.callLater(root.normalizeGridCurrentIndex)' \
    'onCurrentIndexChanged: {' \
    'positionViewAtIndex(' \
    'GridView.Contain' \
    'Keys.onPressed: event => {' \
    'event.key === Qt.Key_Return' \
    'event.key === Qt.Key_Enter' \
    'event.key === Qt.Key_Space' \
    'event.key === Qt.Key_Home' \
    'event.key === Qt.Key_End' \
    'Controls.ScrollBar.vertical: Controls.ScrollBar {' \
    'policy: Controls.ScrollBar.AsNeeded' \
    'interactive: true' \
    'Component.onCompleted:'
do
    if grep -Fq -- "$contract" "$phase_2c26_theme_view"; then
        ok "Theme keyboard/focus/scroll contract: $contract"
    else
        fail "Theme keyboard/focus/scroll contract missing: $contract"
    fi
done

for contract in \
    'property bool keyboardCurrent: false' \
    'focused: root.keyboardCurrent'
do
    if grep -Fq -- "$contract" "$phase_2c26_theme_card"; then
        ok "Theme card keyboard focus contract: $contract"
    else
        fail "Theme card keyboard focus contract missing: $contract"
    fi
done

for forbidden in \
    'activeFocusOnTab: root.controlEnabled' \
    'Keys.onPressed: event =>' \
    'forceActiveFocus()'
do
    if grep -Fq -- "$forbidden" "$phase_2c26_theme_card"; then
        fail "ThemePreviewCard became an independent keyboard focus owner: $forbidden"
    else
        ok "ThemePreviewCard remains a visual focus projection: $forbidden"
    fi
done

for forbidden in \
    'Process {' \
    'FileView {' \
    'jc-theme' \
    'theme-transaction-manager' \
    'local/active-theme' \
    'hyprctl' \
    'systemctl'
do
    if grep -Fq -- "$forbidden" "$phase_2c26_theme_view"; then
        fail "Theme keyboard path bypasses service boundary: $forbidden"
    else
        ok "Theme keyboard path excludes backend detail: $forbidden"
    fi
done

for contract in \
    '## Phase 2C.2.6 — Keyboard, focus, and scroll interaction' \
    'Arrow keys use native ' \
    'Enter, Return, or Space stages the current theme as the draft.' \
    'Home moves to the first theme and End moves to the last theme.' \
    'receives a presentation-only ' \
    'Keyboard activation remains draft-only.'
do
    if grep -Fq -- "$contract" "$phase_2c26_theme_doc"; then
        ok "Theme keyboard/focus documentation: $contract"
    else
        fail "Theme keyboard/focus documentation missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.6 Theme keyboard/focus/scroll architecture' \
    'owns focus and current-index navigation.' \
    'is only a visual projection of the grid' \
    'keyboard focus remain three' \
    'No mutation architecture changes in Phase 2C.2.6.'
do
    if grep -Fq -- "$contract" "$phase_2c26_arch"; then
        ok "Theme keyboard/focus architecture: $contract"
    else
        fail "Theme keyboard/focus architecture missing: $contract"
    fi
done

printf '\n==> Phase 2C formal closure / Phase 2D handoff\n'

phase_2c_closure_readme="$repo_root/README.md"
phase_2c_closure_doc="$repo_root/docs/theme-control.md"
phase_2c_closure_arch="$repo_root/docs/architecture.md"

for contract in \
    '- [x] **Phase 2C — Themes**' \
    '- [ ] **Phase 2D — Quick Settings** ← **NEXT**' \
    '## Phase 2C — Themes (CLOSED)' \
    'Phase 2C is **CLOSED**'
do
    if grep -Fq -- "$contract" "$phase_2c_closure_readme"; then
        ok "Phase 2C README closure: $contract"
    else
        fail "Phase 2C README closure missing: $contract"
    fi
done

if grep -Fq -- \
    '- [ ] **Phase 2C — Themes** ← **NEXT**' \
    "$phase_2c_closure_readme"
then
    fail "README still marks Phase 2C as NEXT after formal closure"
else
    ok "README advances NEXT to Phase 2D"
fi

for contract in \
    '## Phase 2C.2.7 — Visual / runtime E2E' \
    'jc-holo -> cyber-noir -> jc-holo' \
    '## Phase 2C.2.8 — Formal Themes closure' \
    'Phase 2C — **Themes** is complete.' \
    'Phase 2C is **CLOSED**' \
    'Phase 2D — Quick Settings'
do
    if grep -Fq -- "$contract" "$phase_2c_closure_doc"; then
        ok "Phase 2C Theme Control closure: $contract"
    else
        fail "Phase 2C Theme Control closure missing: $contract"
    fi
done

for contract in \
    '## Phase 2C.2.7 Theme visual/runtime E2E evidence' \
    '## Phase 2C final architecture and Phase 2D handoff (CLOSED)' \
    'ThemeDraftStore' \
    'ThemeApplyService' \
    'jc-theme apply / recover --json' \
    'Phase 2C is **CLOSED**' \
    'Phase 2D — Quick Settings'
do
    if grep -Fq -- "$contract" "$phase_2c_closure_arch"; then
        ok "Phase 2C architecture closure: $contract"
    else
        fail "Phase 2C architecture closure missing: $contract"
    fi
done

for commit_id in \
    '12c7c2c' \
    '1571c84' \
    'bdf057b' \
    '86e147c' \
    'd9ad4c9' \
    '9f505fa' \
    '4bed918' \
    '9747844' \
    '8fde591' \
    'e02cefe' \
    'd41eda1' \
    'be91450' \
    '51bea91' \
    '2b230e1'
do
    if grep -Fq -- "$commit_id" "$phase_2c_closure_doc"; then
        ok "Phase 2C closure commit recorded: $commit_id"
    else
        fail "Phase 2C closure commit missing: $commit_id"
    fi
done

printf '\n==> Phase 2E.1a stable Performance runtime API\n'

performance_cli="$repo_root/scripts/runtime/jc-performance.sh"
performance_docs="$repo_root/docs/performance.md"

if [[ -x "$performance_cli" ]]; then
    ok "Performance runtime API executable"
else
    fail "Performance runtime API missing or not executable"
fi

for contract in \
    'jc-performance status [--json]' \
    'schema_version=1' \
    '/proc/stat' \
    '/proc/loadavg' \
    '/proc/meminfo' \
    '/sys/devices/system/cpu/cpufreq/policy*' \
    '/sys/bus/pci/drivers/amdgpu/' \
    'GPU_PCI' \
    'configured-pci' \
    'largest-vram' \
    'fallback-largest-vram' \
    'readOnly: true' \
    "status: \$status"
do
    if grep -Fq -- "$contract" "$performance_cli"; then
        ok "Performance runtime API: $contract"
    else
        fail "Performance runtime API missing: $contract"
    fi
done

for forbidden in \
    'amdgpu_top' \
    'radeontop' \
    'nvtop' \
    'smartctl' \
    'systemctl ' \
    'hyprctl ' \
    'tee /sys' \
    '> /sys'
do
    if grep -Fq -- "$forbidden" "$performance_cli"; then
        fail "Performance runtime API contains forbidden dependency/mutation: $forbidden"
    else
        ok "Performance runtime API excludes: $forbidden"
    fi
done

for contract in \
    "\"\$repo_root/scripts/runtime/jc-performance.sh\"" \
    "\"\$bin_dir/jc-performance\"" \
    "\"\$public_bin_dir/jc-performance\""
do
    if grep -Fq -- "$contract" "$repo_root/scripts/install.sh"; then
        ok "Performance install integration: $contract"
    else
        fail "Performance install integration missing: $contract"
    fi
done

for contract in \
    'jc-performance:scripts/runtime/jc-performance.sh' \
    '"jc-performance"'
do
    if grep -Fq -- "$contract" "$repo_root/scripts/doctor.sh"; then
        ok "Performance doctor integration: $contract"
    else
        fail "Performance doctor integration missing: $contract"
    fi
done

for contract in \
    '# Performance / Hardware' \
    '## Phase 2E.1a — Stable runtime API' \
    'jc-performance status --json' \
    'GPU_PCI' \
    'hwmonN' \
    'cardN'
do
    if grep -Fq -- "$contract" "$performance_docs"; then
        ok "Performance documentation: $contract"
    else
        fail "Performance documentation missing: $contract"
    fi
done

performance_readme_contract='### Performance / Hardware — Phase 2E.1a stable runtime API'

if grep -Fq -- "$performance_readme_contract" "$repo_root/README.md"; then
    ok "Performance README contract: $performance_readme_contract"
else
    fail "Performance README contract missing: $performance_readme_contract"
fi

performance_architecture_contract='## Phase 2E.1a stable Performance runtime API'

if grep -Fq -- "$performance_architecture_contract" \
    "$repo_root/docs/architecture.md"
then
    ok "Performance architecture contract: $performance_architecture_contract"
else
    fail "Performance architecture contract missing: $performance_architecture_contract"
fi

printf '\n==> Phase 2D.1a stable Quick Settings runtime API\n'

quick_settings_cli="$repo_root/scripts/runtime/jc-quick-settings.sh"
quick_settings_doc="$repo_root/docs/quick-settings.md"
quick_settings_installer="$repo_root/scripts/install.sh"
quick_settings_readme="$repo_root/README.md"

if [[ -x "$quick_settings_cli" ]]; then
    ok "Quick Settings public API source is executable"
else
    fail "missing executable Quick Settings API source"
fi

for contract in \
    'jc-quick-settings status [--json]' \
    'jc-quick-settings dnd status [--json]' \
    'jc-quick-settings dnd on [--json]' \
    'jc-quick-settings dnd off [--json]' \
    'schema_version=1' \
    'swaync-client -D' \
    'swaync-client -dn' \
    'swaync-client -df' \
    'backend: "swaync-client"' \
    'backend: "hyprsunset"'
do
    if grep -Fq -- "$contract" "$quick_settings_cli"; then
        ok "Quick Settings API contract: $contract"
    else
        fail "Quick Settings API contract missing: $contract"
    fi
done

# `-d` is the toggle form. Match it as a standalone argument so valid
# deterministic forms `-dn` and `-df` are not false positives.
if grep -Eq -- \
    'swaync-client[[:space:]]+-d([[:space:]]|$)' \
    "$quick_settings_cli"
then
    fail "Phase 2D.1a API contains forbidden DND toggle mutation: swaync-client -d"
else
    ok "Phase 2D.1a API excludes standalone DND toggle mutation: swaync-client -d"
fi

# Phase 2D.2 now owns deterministic hyprsunset mutation in the runtime API.

for contract in \
    "\"\$repo_root/scripts/runtime/jc-quick-settings.sh\"" \
    "\"\$bin_dir/jc-quick-settings\"" \
    "\"\$public_bin_dir/jc-quick-settings\""
do
    if grep -Fq -- "$contract" "$quick_settings_installer"; then
        ok "Quick Settings installer contract: $contract"
    else
        fail "Quick Settings installer contract missing: $contract"
    fi
done

for contract in \
    '# Quick Settings Control' \
    '## Phase 2D.1a — Stable runtime API' \
    'There is no global Quick Settings draft and no global Apply button.' \
    'managed=false' \
    'Phase 2H' \
    'quick-settings` remains disabled'
do
    if grep -Fq -- "$contract" "$quick_settings_doc"; then
        ok "Quick Settings documentation contract: $contract"
    else
        fail "Quick Settings documentation contract missing: $contract"
    fi
done

for contract in \
    'jc-quick-settings status --json' \
    'jc-quick-settings dnd status --json' \
    'jc-quick-settings dnd on --json' \
    'jc-quick-settings dnd off --json' \
    'quick-settings.md'
do
    if grep -Fq -- "$contract" "$quick_settings_readme"; then
        ok "Quick Settings README contract: $contract"
    else
        fail "Quick Settings README contract missing: $contract"
    fi
done

printf '\n==> Phase 2E.1b Performance observed-state service\n'

performance_service="$repo_root/config/quickshell/jc-hyprland/services/PerformanceService.qml"
performance_docs="$repo_root/docs/performance.md"

if [[ -f "$performance_service" ]]; then
    ok "PerformanceService.qml exists"
else
    fail "missing PerformanceService.qml"
fi

for contract in \
    'Scope {' \
    'property int snapshotSchemaVersion: 0' \
    'property string status: "unknown"' \
    'property bool readOnly: true' \
    'property bool loading: false' \
    'property bool ready: false' \
    'property string errorMessage: ""' \
    'property string lastRefresh: ""' \
    'property bool liveUpdatesEnabled: false' \
    'property int refreshIntervalMs: 2000' \
    'readonly property bool observedHealthy:' \
    'signal refreshed()' \
    'signal refreshFailed(string message)' \
    'function performanceCommandPath() {' \
    'function validStatus(payload) {' \
    'function commitSnapshot(payload) {' \
    'function refresh(): void {' \
    '"status",' \
    '"--json"' \
    'Process {' \
    'StdioCollector {' \
    'Timer {' \
    'running: root.liveUpdatesEnabled' \
    'Component.onCompleted: root.refresh()'
do
    if grep -Fq -- "$contract" "$performance_service"; then
        ok "PerformanceService contract: $contract"
    else
        fail "PerformanceService contract missing: $contract"
    fi
done

for forbidden in \
    '/proc/' \
    '/sys/' \
    'GPU_PCI' \
    'hwmonN' \
    'cardN' \
    'amdgpu_top' \
    'radeontop' \
    'nvtop' \
    'smartctl' \
    'systemctl' \
    'hyprctl'
do
    if grep -Fq -- "$forbidden" "$performance_service"; then
        fail "PerformanceService violates backend-neutral boundary: $forbidden"
    else
        ok "PerformanceService excludes backend detail: $forbidden"
    fi
done

for contract in \
    'readonly property var performanceServiceHandle: performanceService' \
    'Services.PerformanceService {' \
    'id: performanceService'
do
    if grep -Fq -- "$contract" "$repo_root/config/quickshell/jc-hyprland/Main.qml"; then
        ok "Main PerformanceService wiring: $contract"
    else
        fail "Main PerformanceService wiring missing: $contract"
    fi
done

for contract in \
    '## Phase 2E.1b — Observed-state service' \
    "\`PerformanceService.qml\` is the read-only QML projection" \
    'jc-performance status --json' \
    'liveUpdatesEnabled' \
    'performanceServiceHandle' \
    "Performance navigation entry or create \`PerformanceView.qml\`."
do
    if grep -Fq -- "$contract" "$performance_docs"; then
        ok "Performance 2E.1b documentation: $contract"
    else
        fail "Performance 2E.1b documentation missing: $contract"
    fi
done

printf '\n==> Phase 2D.1b Quick Settings observed-state service\n'

quick_settings_service="$repo_root/config/quickshell/jc-hyprland/services/QuickSettingsService.qml"
quick_settings_main="$repo_root/config/quickshell/jc-hyprland/Main.qml"
quick_settings_doc="$repo_root/docs/quick-settings.md"

if [[ -f "$quick_settings_service" ]]; then
    ok "QuickSettingsService.qml exists"
else
    fail "missing QuickSettingsService.qml"
fi

for contract in \
    'Scope {' \
    'property bool dndAvailable: false' \
    'property bool dndBackendInstalled: false' \
    'property bool dndRunning: false' \
    'property bool dndEnabled: false' \
    'property bool lockAvailable: false' \
    'property bool nightLightAvailable: false' \
    'property bool nightLightRunning: false' \
    'property bool nightLightManaged: false' \
    'property var nightLightEnabled: null' \
    'property bool suspendAvailable: false' \
    'property bool loading: false' \
    'property bool ready: false' \
    'property string errorMessage: ""' \
    'property string lastRefresh: ""' \
    'signal refreshed()' \
    'signal refreshFailed(string message)' \
    'function quickSettingsCommandPath() {' \
    'function validStatus(payload) {' \
    'function commitSnapshot(payload) {' \
    'function refresh(): void {' \
    '"status",' \
    '"--json"' \
    'Process {' \
    'StdioCollector {' \
    'Component.onCompleted: root.refresh()'
do
    if grep -Fq -- "$contract" "$quick_settings_service"; then
        ok "QuickSettingsService contract: $contract"
    else
        fail "QuickSettingsService contract missing: $contract"
    fi
done

for forbidden in \
    'swaync-client' \
    'hyprsunset' \
    'lock-session.sh' \
    'suspend-session.sh' \
    'systemctl' \
    '"dnd",' \
    '"on",' \
    '"off",'
do
    if grep -Fq -- "$forbidden" "$quick_settings_service"; then
        fail "QuickSettingsService violates read-only boundary: $forbidden"
    else
        ok "QuickSettingsService excludes mutation/backend detail: $forbidden"
    fi
done

for contract in \
    'readonly property var quickSettingsServiceHandle: quickSettingsService' \
    'Services.QuickSettingsService {' \
    'id: quickSettingsService'
do
    if grep -Fq -- "$contract" "$quick_settings_main"; then
        ok "Main Quick Settings service wiring: $contract"
    else
        fail "Main Quick Settings service wiring missing: $contract"
    fi
done

# Quick Settings navigation lifecycle is validated by Phase 2D.1d.

for contract in \
    '## Phase 2D.1b — Observed-state service' \
    "\`QuickSettingsService.qml\` is the read-only QML projection" \
    'jc-quick-settings status --json' \
    'quickSettingsServiceHandle' \
    "The \`quick-settings\` navigation item remains disabled"
do
    if grep -Fq -- "$contract" "$quick_settings_doc"; then
        ok "Quick Settings 2D.1b documentation: $contract"
    else
        fail "Quick Settings 2D.1b documentation missing: $contract"
    fi
done

printf '\n==> Phase 2D.1c Quick Settings DND action service\n'

quick_settings_action_service="$repo_root/config/quickshell/jc-hyprland/services/QuickSettingsActionService.qml"

if [[ -f "$quick_settings_action_service" ]]; then
    ok "QuickSettingsActionService.qml exists"
else
    fail "missing QuickSettingsActionService.qml"
fi

for contract in \
    'Scope {' \
    'property var quickSettingsService' \
    'property bool applyingDnd: false' \
    'property bool awaitingRefresh: false' \
    'property bool pendingDndEnabled: false' \
    'property bool pendingMutationSucceeded: false' \
    'property bool pendingChanged: false' \
    'property string errorMessage: ""' \
    'property string statusMessage: ""' \
    'property var lastResult: null' \
    'readonly property bool busy:' \
    'readonly property bool canSetDnd:' \
    'signal dndApplied(bool desiredEnabled, bool stateChanged)' \
    'signal failed(string message)' \
    'function validAppliedResponse(payload, desiredEnabled) {' \
    'function validateDndMutation() {' \
    'function beginObservedReconciliation(): void {' \
    'function setDndEnabled(desiredEnabled): void {' \
    'function finishObservedReconciliation(): void {' \
    '"dnd",' \
    '? "on" : "off",' \
    '"--json"' \
    'payload.status === "applied"' \
    'payload.requested === desiredEnabled' \
    'payload.enabled === desiredEnabled' \
    'payload.verified' \
    'typeof payload.changed === "boolean"' \
    'root.quickSettingsService.refresh();' \
    'Process {' \
    'StdioCollector {' \
    'Connections {' \
    'function onRefreshed() {' \
    'function onRefreshFailed(message) {'
do
    if grep -Fq -- "$contract" "$quick_settings_action_service"; then
        ok "QuickSettingsActionService contract: $contract"
    else
        fail "QuickSettingsActionService contract missing: $contract"
    fi
done

for forbidden in \
    'swaync-client' \
    'hyprsunset' \
    'lock-session.sh' \
    'suspend-session.sh' \
    'systemctl' \
    '--toggle-dnd'
do
    if grep -Fq -- "$forbidden" "$quick_settings_action_service"; then
        fail "QuickSettingsActionService contains backend/premature action: $forbidden"
    else
        ok "QuickSettingsActionService excludes backend/premature action: $forbidden"
    fi
done

for contract in \
    '|| quickSettingsActionService.busy' \
    'readonly property var quickSettingsActionServiceHandle:' \
    'Services.QuickSettingsActionService {' \
    'id: quickSettingsActionService' \
    'quickSettingsService: quickSettingsService'
do
    if grep -Fq -- "$contract" "$quick_settings_main"; then
        ok "Main Quick Settings action wiring: $contract"
    else
        fail "Main Quick Settings action wiring missing: $contract"
    fi
done

# Quick Settings navigation lifecycle is validated by Phase 2D.1d.

for contract in \
    '## Phase 2D.1c — Immediate DND action service' \
    'QuickSettingsActionService.qml' \
    'jc-quick-settings dnd on --json' \
    'jc-quick-settings dnd off --json' \
    'changed=false' \
    'quickSettingsActionServiceHandle' \
    'navigation item remains disabled'
do
    if grep -Fq -- "$contract" "$quick_settings_doc"; then
        ok "Quick Settings 2D.1c documentation: $contract"
    else
        fail "Quick Settings 2D.1c documentation missing: $contract"
    fi
done

printf '\n==> Phase 2D.1d Quick Settings view foundation\n'

quick_settings_view="$repo_root/config/quickshell/jc-hyprland/modules/quicksettings/QuickSettingsView.qml"

if [[ -f "$quick_settings_view" ]]; then
    ok "QuickSettingsView.qml exists"
else
    fail "missing QuickSettingsView.qml"
fi

for contract in \
    'Item {' \
    'required property var theme' \
    'property var quickSettingsService' \
    'property var actionService' \
    'signal refreshRequested()' \
    'signal dndRequested(bool enabled)' \
    'readonly property bool interactionLocked:' \
    'readonly property bool dndEnabled:' \
    'readonly property bool dndControlEnabled:' \
    'Components.JcSectionHeader {' \
    'title: "Quick Settings"' \
    'Components.JcSettingTile {' \
    'text: "Do Not Disturb"' \
    'iconName: "dnd"' \
    'selected: root.dndEnabled' \
    'Components.JcToggle {' \
    'checked: root.dndEnabled' \
    'controlEnabled: root.dndControlEnabled' \
    'root.dndRequested(value)' \
    'Components.JcSurface {' \
    'title: "Quick actions"' \
    'Tab moves focus · Enter or Space activates '
do
    if grep -Fq -- "$contract" "$quick_settings_view"; then
        ok "QuickSettingsView contract: $contract"
    else
        fail "QuickSettingsView contract missing: $contract"
    fi
done

for forbidden in \
    'Process {' \
    'swaync-client' \
    'hyprsunset' \
    'lock-session.sh' \
    'suspend-session.sh' \
    'systemctl' \
    'jc-quick-settings'
do
    if grep -Fq -- "$forbidden" "$quick_settings_view"; then
        fail "QuickSettingsView owns backend/mutation detail: $forbidden"
    else
        ok "QuickSettingsView excludes backend/mutation detail: $forbidden"
    fi
done

for contract in \
    'import qs.modules.quicksettings as QuickSettings' \
    'function prepareQuickSettings() {' \
    'moduleId === "quick-settings"' \
    'root.prepareQuickSettings();' \
    'id: shellQuickSettingsComponent' \
    'QuickSettings.QuickSettingsView {' \
    'quickSettingsService: root.quickSettingsServiceHandle' \
    'actionService: root.quickSettingsActionServiceHandle' \
    'onRefreshRequested: quickSettingsService.refresh()' \
    'quickSettingsActionService.setDndEnabled(enabled)' \
    '? "Quick Settings"' \
    '? shellQuickSettingsComponent' \
    'root.activeModuleId === "quick-settings"'
do
    if grep -Fq -- "$contract" "$quick_settings_main"; then
        ok "Main Quick Settings view wiring: $contract"
    else
        fail "Main Quick Settings view wiring missing: $contract"
    fi
done

if grep -A4 -F 'id: "quick-settings"' "$control_center_navigation" \
    | grep -Fq 'enabled: true'
then
    ok "Phase 2D.1d Quick Settings navigation enabled"
else
    fail "Phase 2D.1d Quick Settings navigation not enabled"
fi

for contract in \
    '## Phase 2D.1d — Quick Settings view foundation' \
    'QuickSettingsView.qml' \
    'dndRequested(enabled)' \
    'quickSettingsActionService.setDndEnabled(enabled)' \
    'Lock, Night Light and Suspend are displayed only' \
    'navigation entry changes from disabled to enabled'
do
    if grep -Fq -- "$contract" "$quick_settings_doc"; then
        ok "Quick Settings 2D.1d documentation: $contract"
    else
        fail "Quick Settings 2D.1d documentation missing: $contract"
    fi
done

printf '\n==> Phase 2D.1d visual consistency correction\n'

quick_settings_visual="$repo_root/config/quickshell/jc-hyprland/modules/quicksettings/QuickSettingsView.qml"
theme_view_visual="$repo_root/config/quickshell/jc-hyprland/modules/themes/ThemeView.qml"

for contract in \
    'Layout.alignment: Qt.AlignVCenter' \
    'text: "DND"' \
    'compact: true' \
    'id: dndHudFrame' \
    'id: capabilityHudFrame' \
    'Components.JcHudFrame {' \
    'fillColor: root.theme.hudSurface'
do
    if grep -Fq -- "$contract" "$quick_settings_visual"; then
        ok "Quick Settings visual correction: $contract"
    else
        fail "Quick Settings visual correction missing: $contract"
    fi
done

quick_settings_hud_count="$(
    grep -Fc 'Components.JcHudFrame {' \
        "$quick_settings_visual" 2>/dev/null || true
)"

if [[ "$quick_settings_hud_count" -ge 2 ]]; then
    ok "Quick Settings uses HUD framing for both primary surfaces"
else
    fail "Quick Settings requires at least 2 JcHudFrame surfaces"
fi

for contract in \
    'id: themeHeaderSurface' \
    'id: themeHeaderHudFrame' \
    'id: themeGallerySurface' \
    'id: themeGalleryHudFrame' \
    'fillColor: root.theme.hudSurface' \
    'anchors.margins: root.theme.spaceMd'
do
    if grep -Fq -- "$contract" "$theme_view_visual"; then
        ok "Themes HUD consistency: $contract"
    else
        fail "Themes HUD consistency missing: $contract"
    fi
done

theme_view_hud_count="$(
    grep -Fc 'Components.JcHudFrame {' \
        "$theme_view_visual" 2>/dev/null || true
)"

if [[ "$theme_view_hud_count" -ge 2 ]]; then
    ok "Themes restores HUD framing on main header and gallery"
else
    fail "Themes requires at least 2 main JcHudFrame surfaces"
fi

for behavior_contract in \
    'signal applyRequested()' \
    'signal resetRequested()' \
    'signal recoverRequested()' \
    'onClicked: root.applyRequested()' \
    'onClicked: root.resetRequested()' \
    'onClicked: root.recoverRequested()' \
    'root.selectTheme(themeId);'
do
    if grep -Fq -- "$behavior_contract" "$theme_view_visual"; then
        ok "Themes behavior preserved: $behavior_contract"
    else
        fail "Themes behavior regression: $behavior_contract"
    fi
done

# Markdown backticks are intentional literal documentation contracts.
# shellcheck disable=SC2016
for doc_contract in \
    '### 2D.1d visual-gate correction' \
    '`Do Not Disturb` label did not fit' \
    '`JcSettingTile`' \
    '`ThemeView.qml` had drifted from the HUD framing' \
    'Theme draft/apply/recovery behavior is'
do
    if grep -Fq -- "$doc_contract" "$quick_settings_doc"; then
        ok "2D.1d visual correction documentation: $doc_contract"
    else
        fail "2D.1d visual correction documentation missing: $doc_contract"
    fi
done

printf '\n==> Phase 2D.1d observed capability tiles\n'

quick_settings_capability_view="$repo_root/config/quickshell/jc-hyprland/modules/quicksettings/QuickSettingsView.qml"

for contract in \
    'id: capabilityTiles' \
    'id: lockCapabilityTile' \
    'text: "Lock"' \
    'id: nightLightCapabilityTile' \
    'text: "Night Light"' \
    'id: suspendCapabilityTile' \
    'text: "Suspend"' \
    'iconName: "night-light"' \
    'iconName: "power"' \
    'root.quickSettingsService.lockAvailable' \
    'root.quickSettingsService.nightLightAvailable' \
    'root.quickSettingsService.suspendAvailable' \
    'Tab moves focus · Enter or Space activates '
do
    if grep -Fq -- "$contract" "$quick_settings_capability_view"; then
        ok "Quick Settings capability tile: $contract"
    else
        fail "Quick Settings capability tile missing: $contract"
    fi
done

capability_tile_count="$(
    grep -Ec 'id: (lock|nightLight|suspend)CapabilityTile' \
        "$quick_settings_capability_view" 2>/dev/null || true
)"

if [[ "$capability_tile_count" -eq 3 ]]; then
    ok "Quick Settings renders exactly 3 observed capability tiles"
else
    fail "Quick Settings expected 3 observed capability tiles, got $capability_tile_count"
fi

if grep -A40 -F 'id: suspendCapabilityTile' \
    "$quick_settings_capability_view" \
    | grep -Fq 'controlEnabled: root.suspendControlEnabled' \
    && grep -A40 -F 'id: suspendCapabilityTile' \
        "$quick_settings_capability_view" \
        | grep -Fq 'onClicked: root.suspendRequested()'
then
    ok "Suspend capability tile is interactive in Phase 2D.3b"
else
    fail "Suspend capability tile is not interactive in Phase 2D.3b"
fi

# Markdown backticks are intentional literal documentation contracts.
# shellcheck disable=SC2016
for doc_contract in \
    '### 2D.1d observed capability tiles' \
    'Lock, Night Light and Suspend existed only as summary text' \
    '`JcSettingTile` capability options' \
    'remain intentionally read-only in Phase 2D.1d'
do
    if grep -Fq -- "$doc_contract" "$quick_settings_doc"; then
        ok "Observed capability tile documentation: $doc_contract"
    else
        fail "Observed capability tile documentation missing: $doc_contract"
    fi
done

printf '\n==> Phase 2D.2 Night Light / hyprsunset\n'

quick_settings_cli="$repo_root/scripts/runtime/jc-quick-settings.sh"
quick_settings_action_service="$repo_root/config/quickshell/jc-hyprland/services/QuickSettingsActionService.qml"
quick_settings_view="$repo_root/config/quickshell/jc-hyprland/modules/quicksettings/QuickSettingsView.qml"
quick_settings_main="$repo_root/config/quickshell/jc-hyprland/Main.qml"
quick_settings_doc="$repo_root/docs/quick-settings.md"
quick_settings_readme="$repo_root/README.md"
arch_packages="$repo_root/distros/arch/packages.txt"
opensuse_packages="$repo_root/distros/opensuse/packages.txt"

# These are literal source-code contracts; dollar signs must not expand.
# shellcheck disable=SC2016
for contract in \
    'jc-quick-settings night-light status [--json]' \
    'jc-quick-settings night-light on [--json]' \
    'jc-quick-settings night-light off [--json]' \
    'night_light_temperature=4500' \
    'night_light_runtime_available() {' \
    'read_night_light_identity() {' \
    'read_night_light_state() {' \
    'wait_for_night_light_ipc() {' \
    'hyprctl hyprsunset identity get' \
    'hyprctl hyprsunset temperature' \
    'hyprctl hyprsunset identity false' \
    'hyprctl hyprsunset identity true' \
    'systemctl --user start "$night_light_service"' \
    'capability: "night-light"' \
    'managed: $nightLightManaged' \
    'targetTemperature: $nightLightTemperature'
do
    if grep -Fq -- "$contract" "$quick_settings_cli"; then
        ok "Night Light runtime API: $contract"
    else
        fail "Night Light runtime API missing: $contract"
    fi
done

# Literal contract; no shell expansion is intended.
# shellcheck disable=SC2016
if grep -Fq 'systemctl --user enable "$night_light_service"' \
    "$quick_settings_cli"
then
    fail "Night Light runtime API must not enable hyprsunset.service"
else
    ok "Night Light service is start-on-demand, not enabled by runtime API"
fi

for contract in \
    'property bool applyingNightLight: false' \
    'property bool awaitingNightLightRefresh: false' \
    'readonly property bool canSetNightLight:' \
    'signal nightLightApplied(bool desiredEnabled, bool stateChanged)' \
    'function validNightLightAppliedResponse(payload, desiredEnabled) {' \
    'function validateNightLightMutation() {' \
    'function setNightLightEnabled(desiredEnabled): void {' \
    'function finishNightLightObservedReconciliation(): void {' \
    '"night-light",' \
    'root.quickSettingsService.nightLightEnabled !== expected'
do
    if grep -Fq -- "$contract" "$quick_settings_action_service"; then
        ok "Night Light action service: $contract"
    else
        fail "Night Light action service missing: $contract"
    fi
done

for forbidden in \
    'hyprctl hyprsunset' \
    'systemctl --user' \
    'swaync-client'
do
    if grep -Fq -- "$forbidden" "$quick_settings_action_service"; then
        fail "Night Light action service owns backend detail: $forbidden"
    else
        ok "Night Light action service excludes backend detail: $forbidden"
    fi
done

for contract in \
    'signal nightLightRequested(bool enabled)' \
    'readonly property bool nightLightEnabled:' \
    'readonly property bool nightLightControlEnabled:' \
    'readonly property string nightLightStateLabel:' \
    'controlEnabled:' \
    'root.nightLightControlEnabled' \
    'root.nightLightRequested(' \
    'Tab moves focus · Enter or Space activates '
do
    if grep -Fq -- "$contract" "$quick_settings_view"; then
        ok "Night Light view contract: $contract"
    else
        fail "Night Light view contract missing: $contract"
    fi
done

for forbidden in \
    'hyprctl hyprsunset' \
    'systemctl --user' \
    'jc-quick-settings'
do
    if grep -Fq -- "$forbidden" "$quick_settings_view"; then
        fail "Night Light view owns backend detail: $forbidden"
    else
        ok "Night Light view excludes backend detail: $forbidden"
    fi
done

for contract in \
    'quickSettingsActionService.applyingNightLight' \
    'quickSettingsActionService.awaitingNightLightRefresh' \
    'quickSettingsService.nightLightEnabled === true' \
    'onNightLightRequested: enabled =>' \
    'quickSettingsActionService.setNightLightEnabled(enabled)' \
    'Use Do Not Disturb, Night Light, Lock and Suspend now.'
do
    if grep -Fq -- "$contract" "$quick_settings_main"; then
        ok "Main Night Light orchestration: $contract"
    else
        fail "Main Night Light orchestration missing: $contract"
    fi
done

if grep -Fxq 'hyprsunset' "$arch_packages"; then
    ok "Arch/Garuda package manifest includes hyprsunset"
else
    fail "Arch/Garuda package manifest missing hyprsunset"
fi

if grep -Fxq 'hyprsunset' "$opensuse_packages"; then
    fail "openSUSE manifest must not assume hyprsunset package parity"
else
    ok "openSUSE manifest remains unchanged for unverified hyprsunset packaging"
fi

# Markdown backticks are intentional literal documentation contracts.
# shellcheck disable=SC2016
for contract in \
    '## Phase 2D.2 — Night Light / hyprsunset' \
    'jc-quick-settings night-light status --json' \
    'jc-quick-settings night-light on --json' \
    'jc-quick-settings night-light off --json' \
    'identity=false' \
    'identity=true' \
    '`4500 K`' \
    'service is started on demand but is not enabled automatically' \
    'Lock and Suspend remain observed-only' \
    'openSUSE package manifest is intentionally unchanged'
do
    if grep -Fq -- "$contract" "$quick_settings_doc"; then
        ok "Night Light documentation: $contract"
    else
        fail "Night Light documentation missing: $contract"
    fi
done

for contract in \
    '### Quick Settings — Phase 2D.2 Night Light' \
    'jc-quick-settings night-light status --json' \
    'jc-quick-settings night-light on --json' \
    'jc-quick-settings night-light off --json'
do
    if grep -Fq -- "$contract" "$quick_settings_readme"; then
        ok "Night Light README: $contract"
    else
        fail "Night Light README missing: $contract"
    fi
done

printf '\n==> Phase 2D.3a Lock quick action\n'

quick_settings_cli="$repo_root/scripts/runtime/jc-quick-settings.sh"
quick_settings_action_service="$repo_root/config/quickshell/jc-hyprland/services/QuickSettingsActionService.qml"
quick_settings_view="$repo_root/config/quickshell/jc-hyprland/modules/quicksettings/QuickSettingsView.qml"
quick_settings_main="$repo_root/config/quickshell/jc-hyprland/Main.qml"
quick_settings_doc="$repo_root/docs/quick-settings.md"
quick_settings_readme="$repo_root/README.md"

# Literal source-code contracts; dollar signs must not expand.
# shellcheck disable=SC2016
for contract in \
    'jc-quick-settings lock [--json]' \
    'lock_runtime_wrapper() {' \
    'lock_runtime_available() {' \
    'lock_running() {' \
    'apply_lock() {' \
    'nohup "$wrapper"' \
    'process_running hyprlock' \
    'capability: "lock"' \
    'backend: "lock-session.sh"' \
    'verified: true' \
    'changed: $changed' \
    'apply_lock'
do
    if grep -Fq -- "$contract" "$quick_settings_cli"; then
        ok "Lock runtime API: $contract"
    else
        fail "Lock runtime API missing: $contract"
    fi
done

for contract in \
    'property bool applyingLock: false' \
    'readonly property bool canLock:' \
    'signal lockApplied(bool stateChanged)' \
    'function validLockAppliedResponse(payload) {' \
    'function validateLockAction() {' \
    'function lockSession(): void {' \
    'id: lockProcess' \
    '"lock",' \
    'payload.capability === "lock"' \
    'root.lockApplied(Boolean(response.changed));'
do
    if grep -Fq -- "$contract" "$quick_settings_action_service"; then
        ok "Lock action service: $contract"
    else
        fail "Lock action service missing: $contract"
    fi
done

for forbidden in \
    'hyprlock' \
    'lock-session.sh' \
    'systemctl' \
    'loginctl'
do
    if grep -Fq -- "$forbidden" "$quick_settings_action_service"; then
        fail "Lock action service owns backend detail: $forbidden"
    else
        ok "Lock action service excludes backend detail: $forbidden"
    fi
done

for contract in \
    'signal lockRequested()' \
    'readonly property bool lockControlEnabled:' \
    'readonly property string lockStateLabel:' \
    'controlEnabled: root.lockControlEnabled' \
    'onClicked: root.lockRequested()' \
    'text: root.lockStateLabel' \
    'Tab moves focus · Enter or Space activates '
do
    if grep -Fq -- "$contract" "$quick_settings_view"; then
        ok "Lock view contract: $contract"
    else
        fail "Lock view contract missing: $contract"
    fi
done

for forbidden in \
    'hyprlock' \
    'lock-session.sh' \
    'jc-quick-settings'
do
    if grep -Fq -- "$forbidden" "$quick_settings_view"; then
        fail "Lock view owns backend detail: $forbidden"
    else
        ok "Lock view excludes backend detail: $forbidden"
    fi
done

for contract in \
    'quickSettingsActionService.applyingLock' \
    'property bool pendingSessionLock: false' \
    'function requestSessionLock(): void {' \
    'function dispatchPendingSessionLock(): void {' \
    'if (controlCenterShell.mounted)' \
    'Qt.callLater(root.dispatchPendingSessionLock);' \
    'onLockRequested: root.requestSessionLock()' \
    'onMountedChanged: {' \
    'root.dispatchPendingSessionLock();' \
    'Use Do Not Disturb, Night Light, Lock and Suspend now.'
do
    if grep -Fq -- "$contract" "$quick_settings_main"; then
        ok "Main Lock orchestration: $contract"
    else
        fail "Main Lock orchestration missing: $contract"
    fi
done

# Markdown backticks are intentional literal documentation contracts.
# shellcheck disable=SC2016
for contract in \
    '## Phase 2D.3a — Lock quick action' \
    'jc-quick-settings lock --json' \
    '`lock-session.sh`' \
    '`hyprlock`' \
    '`changed=false`' \
    'Lock is intentionally modeled as an action, not a toggle.' \
    'controlCenterShell.mounted === false' \
    'No fixed sleep or animation' \
    'duration is used.' \
    'Phase 2D.3b — Suspend quick action'
do
    if grep -Fq -- "$contract" "$quick_settings_doc"; then
        ok "Lock documentation: $contract"
    else
        fail "Lock documentation missing: $contract"
    fi
done

for contract in \
    '### Quick Settings — Phase 2D.3a Lock' \
    'jc-quick-settings lock --json' \
    'controlCenterShell.mounted' \
    'Quick Settings — Phase 2D.3b Suspend'
do
    if grep -Fq -- "$contract" "$quick_settings_readme"; then
        ok "Lock README: $contract"
    else
        fail "Lock README missing: $contract"
    fi
done


printf '\n==> Phase 2D.3b Suspend quick action\n'

quick_settings_cli="$repo_root/scripts/runtime/jc-quick-settings.sh"
quick_settings_action_service="$config_dir/services/QuickSettingsActionService.qml"
quick_settings_view="$config_dir/modules/quicksettings/QuickSettingsView.qml"
quick_settings_doc="$repo_root/docs/quick-settings.md"
readme="$repo_root/README.md"

for contract in \
    'jc-quick-settings suspend [--json]' \
    'suspend_runtime_wrapper() {' \
    'apply_suspend() {' \
    'status: "accepted"' \
    'capability: "suspend"' \
    'accepted: true' \
    'handoffVerified: true' \
    'backend: "suspend-session.sh"' \
    "nohup \"\$wrapper\""
do
    if grep -Fq -- "$contract" "$quick_settings_cli"; then
        ok "Suspend runtime contract: $contract"
    else
        fail "Suspend runtime contract missing: $contract"
    fi
done

if grep -Fq 'systemctl suspend' "$quick_settings_cli"; then
    fail "Suspend stable CLI bypasses managed wrapper"
else
    ok "Suspend stable CLI preserves managed wrapper boundary"
fi

for contract in \
    'property bool applyingSuspend: false' \
    'readonly property bool canSuspend:' \
    'signal suspendAccepted()' \
    'function validSuspendAcceptedResponse(payload) {' \
    'payload.status === "accepted"' \
    'payload.capability === "suspend"' \
    'payload.handoffVerified' \
    'function validateSuspendAction() {' \
    'function suspendSession(): void {' \
    'id: suspendProcess'
do
    if grep -Fq -- "$contract" "$quick_settings_action_service"; then
        ok "Suspend ActionService contract: $contract"
    else
        fail "Suspend ActionService contract missing: $contract"
    fi
done

for forbidden in 'suspend-session.sh' 'systemctl suspend' 'loginctl suspend' 'systemd-run'; do
    if grep -Fq -- "$forbidden" "$quick_settings_action_service"; then
        fail "Suspend ActionService leaks backend: $forbidden"
    else
        ok "Suspend ActionService excludes backend: $forbidden"
    fi
done

for contract in \
    'signal suspendRequested()' \
    'readonly property bool suspendControlEnabled:' \
    'Boolean(root.actionService.canSuspend)' \
    'readonly property string suspendStateLabel:' \
    'root.actionService.applyingSuspend' \
    'controlEnabled: root.suspendControlEnabled' \
    'onClicked: root.suspendRequested()' \
    'text: root.suspendStateLabel' \
    'Tab moves focus · Enter or Space activates '
do
    if grep -Fq -- "$contract" "$quick_settings_view"; then
        ok "Suspend View contract: $contract"
    else
        fail "Suspend View contract missing: $contract"
    fi
done

for forbidden in 'suspend-session.sh' 'systemctl suspend' 'loginctl suspend' 'jc-quick-settings'; do
    if grep -Fq -- "$forbidden" "$quick_settings_view"; then
        fail "Suspend View leaks backend: $forbidden"
    else
        ok "Suspend View excludes backend: $forbidden"
    fi
done

for contract in \
    'property bool pendingSessionSuspend: false' \
    'function requestSessionSuspend(): void {' \
    'function dispatchPendingSessionSuspend(): void {' \
    'if (controlCenterShell.mounted)' \
    'quickSettingsActionService.suspendSession();' \
    'Qt.callLater(root.dispatchPendingSessionSuspend);' \
    'onSuspendRequested: root.requestSessionSuspend()' \
    'root.dispatchPendingSessionSuspend();' \
    'Use Do Not Disturb, Night Light, Lock and Suspend now.'
do
    if grep -Fq -- "$contract" "$main_qml"; then
        ok "Suspend Main contract: $contract"
    else
        fail "Suspend Main contract missing: $contract"
    fi
done

for contract in \
    '## Phase 2D.3b — Suspend quick action' \
    'jc-quick-settings suspend --json' \
    '"status": "accepted"' \
    'handoffVerified' \
    'controlCenterShell.mounted === false' \
    'does **not** claim that the later system sleep or resume cycle'
do
    if grep -Fq -- "$contract" "$quick_settings_doc"; then
        ok "Suspend documentation: $contract"
    else
        fail "Suspend documentation missing: $contract"
    fi
done

for contract in \
    '### Quick Settings — Phase 2D.3b Suspend' \
    'jc-quick-settings suspend --json' \
    'status: "accepted"' \
    'suspend-session.sh' \
    'controlCenterShell.mounted'
do
    if grep -Fq -- "$contract" "$readme"; then
        ok "Suspend README: $contract"
    else
        fail "Suspend README missing: $contract"
    fi
done

printf '\nQuickshell validation summary: %d error(s)\n' "$errors"

if ((errors > 0)); then
    exit 1
fi

printf 'Quickshell static checks passed.\n'

printf '\n==> Phase H1.4.4b2 dual-monitor card layout\n'

holo_monitor_service="$config_dir/services/MonitorService.qml"
holo_display_view="$config_dir/modules/displays/DisplayView.qml"
holo_display_card="$config_dir/modules/displays/DisplayCard.qml"
holo_quickshell_launcher="$repo_root/scripts/runtime/start-quickshell.sh"
holo_architecture="$repo_root/docs/architecture.md"

# Literal validator contracts intentionally contain shell expressions.
# shellcheck disable=SC2016
for contract in \
    'host_env="$runtime_base/local/host.env"' \
    'source "$host_env"' \
    'export JC_MAIN_OUTPUT="${MAIN_OUTPUT:-}"' \
    'export JC_SECONDARY_OUTPUT="${SECONDARY_OUTPUT:-}"'
do
    if grep -Fq -- "$contract" "$holo_quickshell_launcher"; then
        ok "Quickshell host-role bridge: $contract"
    else
        fail "Quickshell host-role bridge missing: $contract"
    fi
done

for contract in \
    'readonly property string mainOutputName:' \
    'Quickshell.env("JC_MAIN_OUTPUT")' \
    'readonly property string secondaryOutputName:' \
    'Quickshell.env("JC_SECONDARY_OUTPUT")' \
    'function roleForOutput(output)' \
    'return "Primary";' \
    'return "Secondary";'
do
    if grep -Fq -- "$contract" "$holo_monitor_service"; then
        ok "MonitorService role contract: $contract"
    else
        fail "MonitorService role contract missing: $contract"
    fi
done

for contract in \
    'readonly property real monitorCardMinWidth:' \
    'root.theme.controlHeightLarge * 8' \
    'readonly property real monitorCardTwoColumnThreshold:' \
    'id: monitorCardGrid' \
    'width >= root.monitorCardTwoColumnThreshold' \
    '? 2' \
    ': 1' \
    'readonly property real cardWidth:' \
    'width: monitorCardGrid.cardWidth' \
    'delegate: DisplayCard {' \
    'required property var modelData' \
    'monitor: modelData' \
    'outputRole: root.monitorService' \
    'root.monitorService.roleForOutput(modelData.output)'
do
    if grep -Fq -- "$contract" "$holo_display_view"; then
        ok "Displays dual-card contract: $contract"
    else
        fail "Displays dual-card contract missing: $contract"
    fi
done

for contract in \
    'property string outputRole: ""' \
    '? " · " + root.outputRole' \
    'readonly property real controlStripMinColumnWidth:' \
    'root.theme.controlHeightLarge * 2.4' \
    'id: displayControlStrip'
do
    if grep -Fq -- "$contract" "$holo_display_card"; then
        ok "DisplayCard dual-column contract: $contract"
    else
        fail "DisplayCard dual-column contract missing: $contract"
    fi
done

if grep -Eq 'DP-[0-9]+' \
    "$holo_monitor_service" \
    "$holo_display_view" \
    "$holo_display_card" \
    "$holo_quickshell_launcher"
then
    fail "Dual-monitor presentation contains a hardcoded DP-* output"
else
    ok "Dual-monitor roles contain no hardcoded DP-* output"
fi

display_card_combo_count="$(
    grep -Fc 'Components.JcComboBox {' "$holo_display_card" 2>/dev/null || true
)"
display_card_slider_count="$(
    grep -Fc 'Components.JcSlider {' "$holo_display_card" 2>/dev/null || true
)"

if [[ "$display_card_combo_count" == "3" \
    && "$display_card_slider_count" == "1" ]]
then
    ok "Dual-card layout preserves 3 ComboBoxes + 1 Slider per DisplayCard"
else
    fail "Dual-card layout changed DisplayCard control count unexpectedly: combo=$display_card_combo_count slider=$display_card_slider_count"
fi

for contract in \
    '## H1.4.4b2 dual-monitor card layout' \
    'JC_MAIN_OUTPUT / JC_SECONDARY_OUTPUT' \
    'roleForOutput(...)' \
    'Safe Apply, rollback, topology, and persistence contracts are unchanged.'
do
    if grep -Fq -- "$contract" "$holo_architecture"; then
        ok "H1.4.4b2 architecture contract: $contract"
    else
        fail "H1.4.4b2 architecture contract missing: $contract"
    fi
done

printf '\n==> Phase H1.4.4b3 Display card density polish\n'

holo_display_card="$config_dir/modules/displays/DisplayCard.qml"
holo_architecture="$repo_root/docs/architecture.md"

for contract in \
    'readonly property string disableReason:' \
    'root.draftStore.enableDisableReason(root.monitor.output)' \
    'id: disableButton' \
    'id: disableReasonHover' \
    'acceptedButtons: Qt.NoButton' \
    'root.disableReason.length > 0' \
    'Components.JcTooltip {' \
    'visible: disableReasonHover.containsMouse' \
    'text: root.disableReason'
do
    if grep -Fq -- "$contract" "$holo_display_card"; then
        ok "DisplayCard contextual Disable reason: $contract"
    else
        fail "DisplayCard contextual Disable reason missing: $contract"
    fi
done

for retired_copy in \
    'Focus another display before disabling this one.' \
    'Draft unavailable' \
    'Draft: Disabled' \
    'return "Draft: "' \
    'Options marked “move required” can be selected. Use the '
do
    if grep -Fq -- "$retired_copy" "$holo_display_card"; then
        fail "DisplayCard retains retired permanent copy: $retired_copy"
    else
        ok "DisplayCard retired permanent copy: $retired_copy"
    fi
done

display_card_combo_count="$(
    grep -Fc 'Components.JcComboBox {' "$holo_display_card" 2>/dev/null || true
)"
display_card_slider_count="$(
    grep -Fc 'Components.JcSlider {' "$holo_display_card" 2>/dev/null || true
)"

if [[ "$display_card_combo_count" == "3" \
    && "$display_card_slider_count" == "1" ]]
then
    ok "Density polish preserves 3 ComboBoxes + 1 Slider"
else
    fail "Density polish changed controls unexpectedly: combo=$display_card_combo_count slider=$display_card_slider_count"
fi

for mutation_contract in \
    'setEnabled(' \
    'setResolution(root.monitor.output, value)' \
    'setRefreshMode(root.monitor.output, value)' \
    'root.draftStore.setScale(' \
    'setTransform(root.monitor.output, value)'
do
    if grep -Fq -- "$mutation_contract" "$holo_display_card"; then
        ok "Density polish preserves mutation contract: $mutation_contract"
    else
        fail "Density polish mutation contract missing: $mutation_contract"
    fi
done

# Literal documentation contracts intentionally contain Markdown backticks.
# shellcheck disable=SC2016
for contract in \
    '## H1.4.4b3 Display card density polish' \
    '`DisplayDraftStore.enableDisableReason(output)` remains the source of truth' \
    'shows it through `JcTooltip` over the' \
    'Safe Apply, rollback, and persistent configuration semantics remain'
do
    if grep -Fq -- "$contract" "$holo_architecture"; then
        ok "H1.4.4b3 architecture contract: $contract"
    else
        fail "H1.4.4b3 architecture contract missing: $contract"
    fi
done

printf '\n==> Phase 2D.4 Quick Settings visual / keyboard / icon polish\n'

quick_settings_polish_view="$config_dir/modules/quicksettings/QuickSettingsView.qml"
quick_settings_polish_icon="$config_dir/components/JcIcon.qml"
quick_settings_polish_doc="$repo_root/docs/quick-settings.md"

for contract in \
    '"dnd"' \
    '"night-light"' \
    'case "dnd":' \
    'case "night-light":'
do
    if grep -Fq -- "$contract" "$quick_settings_polish_icon"; then
        ok "Quick Settings semantic icon contract: $contract"
    else
        fail "Quick Settings semantic icon missing: $contract"
    fi
done

for removed_icon in \
    '"lock"' \
    '"suspend"' \
    'case "lock":' \
    'case "suspend":'
do
    if grep -Fq -- "$removed_icon" "$quick_settings_polish_icon"; then
        fail "Quick Settings retains unused rejected semantic icon: $removed_icon"
    else
        ok "Quick Settings excludes unused rejected semantic icon: $removed_icon"
    fi
done

for contract in \
    'id: refreshAction' \
    'id: dndQuickTile' \
    'iconName: "dnd"' \
    'iconName: "settings"' \
    'iconName: "night-light"' \
    'iconName: "power"' \
    'title: "Quick actions"' \
    'KeyNavigation.down: dndQuickTile' \
    'KeyNavigation.down: lockCapabilityTile' \
    'nightLightCapabilityTile' \
    'KeyNavigation.left: lockCapabilityTile' \
    'KeyNavigation.right: suspendCapabilityTile' \
    'Tab moves focus · Enter or Space activates '
do
    if grep -Fq -- "$contract" "$quick_settings_polish_view"; then
        ok "Quick Settings polish view contract: $contract"
    else
        fail "Quick Settings polish view contract missing: $contract"
    fi
done

for replaced_mapping in \
    'iconName: "notifications"' \
    'iconName: "theme"'
do
    if grep -Fq -- "$replaced_mapping" "$quick_settings_polish_view"; then
        fail "Quick Settings still uses replaced icon mapping: $replaced_mapping"
    else
        ok "Quick Settings excludes replaced icon mapping: $replaced_mapping"
    fi
done

for forbidden in \
    'swaync-client' \
    'hyprsunset' \
    'lock-session.sh' \
    'suspend-session.sh' \
    'systemctl' \
    'loginctl' \
    'systemd-run' \
    'jc-quick-settings'
do
    if grep -Fq -- "$forbidden" "$quick_settings_polish_view"; then
        fail "Quick Settings polish leaks backend detail: $forbidden"
    else
        ok "Quick Settings polish excludes backend detail: $forbidden"
    fi
done

for contract in \
    '## Phase 2D.4 — Visual, keyboard and icon polish' \
    'The final Quick Settings icon treatment is intentionally hybrid:' \
    "Lock keeps the established \`settings\` icon" \
    "Suspend keeps the established \`power\` icon" \
    'presentation-only'
do
    if grep -Fq -- "$contract" "$quick_settings_polish_doc"; then
        ok "Quick Settings 2D.4 documentation: $contract"
    else
        fail "Quick Settings 2D.4 documentation missing: $contract"
    fi
done

for contract in \
    '### Quick Settings — Phase 2D.4 Visual / keyboard / icon polish' \
    'dedicated semantic vector icons for DND and Night' \
    'retaining the established Settings icon for Lock' \
    'Power icon for Suspend' \
    'directional focus movement' \
    'presentation-only'
do
    if grep -Fq -- "$contract" "$repo_root/README.md"; then
        ok "Quick Settings 2D.4 README: $contract"
    else
        fail "Quick Settings 2D.4 README missing: $contract"
    fi
done
