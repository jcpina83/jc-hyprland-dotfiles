#!/usr/bin/env bash
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
errors=0

ok() {
    printf '  OK    %s\n' "$*"
}

fail() {
    printf '  FAIL  %s\n' "$*" >&2
    ((errors += 1))
}

require_file() {
    local label="$1"
    local file="$2"

    if [[ -r "$file" ]]; then
        ok "$label"
    else
        fail "$label: missing $file"
    fi
}

require_text() {
    local label="$1"
    local file="$2"
    local text="$3"

    if grep -Fq -- "$text" "$file"; then
        ok "$label"
    else
        fail "$label"
    fi
}

theme_qml="$repo_root/config/quickshell/jc-hyprland/theme/Theme.qml"
waybar_css="$repo_root/config/waybar/style.css"
design_doc="$repo_root/docs/design-system.md"
readme="$repo_root/README.md"

printf '==> Design System / Theme API\n'

require_file "Theme.qml" "$theme_qml"
require_file "Waybar semantic stylesheet" "$waybar_css"
require_file "Design System documentation" "$design_doc"

printf '\n==> Quickshell Theme API contract\n'

qml_contract=(
    "Scope {"
    "FileView {"
    "readonly property string activeThemeId:"
    "readonly property string themeFilePath:"
    "readonly property bool externalThemeLoaded:"
    "function colorToken(name, fallback)"
    "function opacityToken(name, fallback)"
    "readonly property color canvas:"
    "readonly property color surfaceBase:"
    "readonly property color surfaceSelected:"
    "readonly property color borderFocus:"
    "readonly property color textPrimary:"
    "readonly property color primary:"
    "readonly property color success:"
    "readonly property color controlSurfaceDefault:"
    "readonly property real opacityDisabled:"
    "readonly property int spaceMd:"
    "readonly property int radiusMd:"
    "readonly property int textSizeBody:"
    "readonly property int motionNormal:"
    "readonly property int easingStandard:"
)

for token in "${qml_contract[@]}"; do
    require_text "Theme API: $token" "$theme_qml" "$token"
done

printf '\n==> Runtime theme JSON contract\n'

if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 is required for quickshell.json validation"
else
    for theme in cyber-noir odyssey-glass; do
        theme_json="$repo_root/themes/$theme/quickshell.json"

        require_file "$theme quickshell.json" "$theme_json"

        if [[ -r "$theme_json" ]]; then
            if python3 - "$theme_json" "$theme" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
expected_id = sys.argv[2]

required_colors = {
    "canvas",
    "canvasAlt",
    "surfaceSunken",
    "surfaceBase",
    "surfaceRaised",
    "surfaceInteractive",
    "surfacePressed",
    "textPrimary",
    "textSecondary",
    "textMuted",
    "primary",
    "secondary",
    "accent",
    "success",
    "warning",
    "danger",
    "info",
}

required_opacity = {
    "surfaceGlass",
    "surfaceGlassRaised",
    "surfaceOverlay",
    "surfaceHover",
    "surfaceSelected",
    "scrim",
    "borderSubtle",
    "borderDefault",
    "borderStrong",
    "borderAccent",
    "borderFocus",
    "feedbackSurface",
    "feedbackBorder",
}

try:
    data = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:
    print(f"{path}: invalid JSON: {exc}", file=sys.stderr)
    raise SystemExit(1)

if data.get("schemaVersion") != 1:
    print(f"{path}: schemaVersion must be 1", file=sys.stderr)
    raise SystemExit(1)

if data.get("id") != expected_id:
    print(
        f"{path}: id {data.get('id')!r} does not match {expected_id!r}",
        file=sys.stderr,
    )
    raise SystemExit(1)

if not isinstance(data.get("name"), str) or not data["name"].strip():
    print(f"{path}: non-empty name is required", file=sys.stderr)
    raise SystemExit(1)

colors = data.get("colors")
opacity = data.get("opacity")

if not isinstance(colors, dict):
    print(f"{path}: colors object is required", file=sys.stderr)
    raise SystemExit(1)

if not isinstance(opacity, dict):
    print(f"{path}: opacity object is required", file=sys.stderr)
    raise SystemExit(1)

missing_colors = sorted(required_colors - colors.keys())
missing_opacity = sorted(required_opacity - opacity.keys())

if missing_colors:
    print(
        f"{path}: missing color tokens: {', '.join(missing_colors)}",
        file=sys.stderr,
    )
    raise SystemExit(1)

if missing_opacity:
    print(
        f"{path}: missing opacity tokens: {', '.join(missing_opacity)}",
        file=sys.stderr,
    )
    raise SystemExit(1)

for key in required_colors:
    value = colors[key]
    if not isinstance(value, str) or not value:
        print(f"{path}: invalid color token {key}", file=sys.stderr)
        raise SystemExit(1)

for key in required_opacity:
    value = opacity[key]
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        print(f"{path}: invalid opacity token {key}", file=sys.stderr)
        raise SystemExit(1)

    if not 0.0 <= float(value) <= 1.0:
        print(f"{path}: opacity token {key} must be within 0..1", file=sys.stderr)
        raise SystemExit(1)
PY
            then
                ok "$theme quickshell.json schema"
            else
                fail "$theme quickshell.json schema"
            fi
        fi
    done
fi

printf '\n==> CSS semantic contract\n'

css_tokens=(
    "canvas"
    "surface-sunken"
    "surface-base"
    "surface-raised"
    "surface-glass"
    "surface-overlay"
    "surface-hover"
    "surface-selected"
    "border-subtle"
    "border-default"
    "border-strong"
    "border-accent"
    "border-focus"
    "text-primary"
    "text-secondary"
    "text-muted"
    "action-primary"
    "action-secondary"
    "action-accent"
    "state-success"
    "state-warning"
    "state-danger"
    "state-info"
)

for theme in cyber-noir odyssey-glass; do
    colors_css="$repo_root/themes/$theme/colors.css"

    require_file "$theme colors.css" "$colors_css"

    if [[ -r "$colors_css" ]]; then
        for token in "${css_tokens[@]}"; do
            require_text \
                "$theme CSS token: $token" \
                "$colors_css" \
                "@define-color $token"
        done
    fi
done

printf '\n==> Waybar semantic consumption\n'

legacy_waybar_regex='@(foreground|foreground-alt|muted|glass|glass-light|glass-hover|glass-border|primary|secondary|accent|green|yellow|red|bg)([^a-zA-Z0-9_-]|$)'

if grep -Eq "$legacy_waybar_regex" "$waybar_css"; then
    fail "legacy Waybar semantic candidates remain"
else
    ok "legacy Waybar semantic candidates removed"
fi

if grep -Eq '#[0-9a-fA-F]{6,8}|rgba?\(' "$waybar_css"; then
    fail "hardcoded Waybar colors remain"
else
    ok "Waybar contains no hardcoded colors"
fi

waybar_semantic_tokens=(
    "@canvas"
    "@surface-glass"
    "@surface-overlay"
    "@surface-hover"
    "@surface-selected"
    "@border-subtle"
    "@text-primary"
    "@text-secondary"
    "@text-muted"
    "@action-primary"
    "@action-secondary"
    "@action-accent"
    "@state-success"
    "@state-warning"
    "@state-danger"
)

for token in "${waybar_semantic_tokens[@]}"; do
    require_text "Waybar token: $token" "$waybar_css" "$token"
done

printf '\n==> Documentation contract\n'

require_text \
    "README marks Phase 2A.1 complete" \
    "$readme" \
    "- [x] **Phase 2A.1 — Design System / Theme API**"

require_text \
    "README documents quickshell.json" \
    "$readme" \
    'quickshell.json'

require_text \
    "architecture documents quickshell.json" \
    "$repo_root/docs/architecture.md" \
    'quickshell.json'

require_text \
    "Quickshell README documents Theme API" \
    "$repo_root/config/quickshell/jc-hyprland/README.md" \
    "## Design System / Theme API"

printf '\nDesign System validation summary: %d error(s)\n' "$errors"

if ((errors > 0)); then
    exit 1
fi

printf 'Design System / Theme API checks passed.\n'
