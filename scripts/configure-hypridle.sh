#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Hypridle integration
#
# - Preserves an existing distro/user hypridle.conf.
# - Updates only general.lock_cmd when configuration already exists.
# - Installs the project template only when no configuration exists.
# - Idempotent.
# ==============================================================================

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "$script_path")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

target_dir="$config_home/hypr"
target="$target_dir/hypridle.conf"

template="$repo_root/config/hypridle/hypridle.conf.template"

backup="${target}.jc-before-dotfiles"

dry_run=false

if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=true
fi


log() {
    printf '[jc-hyprland-dotfiles] %s\n' "$*"
}


run() {

    if [[ "$dry_run" == true ]]; then
        printf '[dry-run] '
        printf '%q ' "$@"
        printf '\n'
        return 0
    fi

    "$@"
}


desired_command="jc-hyprland-dotfiles/bin/lock-session.sh"

desired_line="    lock_cmd = pidof hyprlock || sh -lc '\$HOME/.config/jc-hyprland-dotfiles/bin/lock-session.sh'"


# ==============================================================================
# Validation
# ==============================================================================

if [[ ! -r "$template" ]]; then
    printf 'ERROR: Hypridle template not found:\n' >&2
    printf '  %s\n' "$template" >&2
    exit 1
fi


# ==============================================================================
# Ensure configuration directory
# ==============================================================================

run mkdir -p "$target_dir"


# ==============================================================================
# No configuration exists
# ==============================================================================

if [[ ! -e "$target" ]]; then

    log "Installing default Hypridle configuration"

    run cp "$template" "$target"

    exit 0
fi


# ==============================================================================
# Already configured
# ==============================================================================

if grep -Fq "$desired_command" "$target"; then

    log "Hypridle already uses jc-hyprland-dotfiles lock wrapper"

    exit 0
fi


# ==============================================================================
# Preserve original configuration
# ==============================================================================

if [[ ! -e "$backup" ]]; then

    log "Preserving original Hypridle configuration:"
    log "  $backup"

    run cp -a "$target" "$backup"
fi


if [[ "$dry_run" == true ]]; then

    if grep -Eq '^[[:space:]]*lock_cmd[[:space:]]*=' "$target"; then
        log "[dry-run] replace existing general.lock_cmd"
    else
        log "[dry-run] add general.lock_cmd"
    fi

    exit 0
fi


# ==============================================================================
# Patch existing lock_cmd
# ==============================================================================

tmp="$(mktemp)"

cleanup() {
    rm -f "$tmp"
}

trap cleanup EXIT


if grep -Eq '^[[:space:]]*lock_cmd[[:space:]]*=' "$target"; then

    awk \
        -v replacement="$desired_line" '
        BEGIN {
            replaced = 0
        }

        /^[[:space:]]*lock_cmd[[:space:]]*=/ && replaced == 0 {
            print replacement
            replaced = 1
            next
        }

        {
            print
        }
        ' \
        "$target" > "$tmp"

else

    awk \
        -v replacement="$desired_line" '
        BEGIN {
            inserted = 0
        }

        {
            print

            if (
                inserted == 0 &&
                $0 ~ /^[[:space:]]*general[[:space:]]*\{/
            ) {
                print replacement
                inserted = 1
            }
        }

        END {
            if (inserted == 0) {
                exit 42
            }
        }
        ' \
        "$target" > "$tmp"

fi


install -m 0644 "$tmp" "$target"

log "Hypridle lock integration configured:"
log "  $target"