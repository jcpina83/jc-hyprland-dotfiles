#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# nwgbar integration
#
# Managed actions:
#   Lock    -> jc lock-session.sh
#   Suspend -> jc suspend-session.sh
#   Logout  -> uwsm stop
# ==============================================================================

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
nwgbar_config="$config_home/nwg-launchers/nwgbar/bar.json"
backup_file="${nwgbar_config}.jc-before-dotfiles"

dry_run=false

if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=true
fi


log() {
    printf '[jc-hyprland-dotfiles] %s\n' "$*"
}


# ------------------------------------------------------------------------------
# Preconditions
# ------------------------------------------------------------------------------

if [[ ! -f "$nwgbar_config" ]]; then
    log "nwgbar configuration not found: $nwgbar_config"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    printf 'ERROR: jq is required to configure nwgbar\n' >&2
    exit 1
fi


# ------------------------------------------------------------------------------
# Desired commands
# ------------------------------------------------------------------------------

lock_command="sh -lc '\$HOME/.config/jc-hyprland-dotfiles/bin/lock-session.sh'"
suspend_command="sh -lc '\$HOME/.config/jc-hyprland-dotfiles/bin/suspend-session.sh'"
logout_command="uwsm stop"


# ------------------------------------------------------------------------------
# Generate patched configuration
#
# Garuda uses mnemonic underscores in labels:
#
#   _Lock screen
#   Suspen_d
#   Logout
#
# Normalize names before matching so the integration does not depend on the
# mnemonic underscore placement.
# ------------------------------------------------------------------------------

tmp_file="$(mktemp)"

cleanup() {
    rm -f "$tmp_file"
}

trap cleanup EXIT


jq \
    --arg lock "$lock_command" \
    --arg suspend "$suspend_command" \
    --arg logout "$logout_command" \
    '
    map(
        (.name // "" | gsub("_"; "") | ascii_downcase) as $name
        |
        if $name == "lock screen" or $name == "lock" then
            .exec = $lock
        elif $name == "suspend" then
            .exec = $suspend
        elif $name == "logout" then
            .exec = $logout
        else
            .
        end
    )
    ' \
    "$nwgbar_config" > "$tmp_file"


# ------------------------------------------------------------------------------
# Idempotency
# ------------------------------------------------------------------------------

if jq -e \
    --slurpfile desired "$tmp_file" \
    '. == $desired[0]' \
    "$nwgbar_config" >/dev/null
then
    log "nwgbar already uses jc-hyprland-dotfiles session actions"
    exit 0
fi


# ------------------------------------------------------------------------------
# Dry run
# ------------------------------------------------------------------------------

if [[ "$dry_run" == true ]]; then
    log "nwgbar configuration would be updated:"
    diff -u "$nwgbar_config" "$tmp_file" || true
    exit 0
fi


# ------------------------------------------------------------------------------
# Backup original configuration once
# ------------------------------------------------------------------------------

if [[ ! -e "$backup_file" ]]; then
    cp -- "$nwgbar_config" "$backup_file"
    log "Backup created: $backup_file"
fi


# ------------------------------------------------------------------------------
# Apply
# ------------------------------------------------------------------------------

install -m 0644 "$tmp_file" "$nwgbar_config"

log "nwgbar session integration configured"