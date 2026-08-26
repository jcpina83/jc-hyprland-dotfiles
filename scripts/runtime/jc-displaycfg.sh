#!/usr/bin/env bash
set -euo pipefail

umask 077

# ==============================================================================
# jc-hyprland-dotfiles
# Persistent display configuration backend — Lua
#
# Phase 1C.1:
# - local/monitors.lua is the single persistent source owned by the project
# - persists the complete current runtime state of configured monitors
# - preserves desc:<description> selectors
# - preserves monitor extras and workspace rules
# - writes through a same-directory candidate + atomic rename
# - creates a local backup before replacement
# - reloads Hyprland and verifies runtime convergence
# - restores the backup automatically if post-write validation fails
# ==============================================================================

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
base="${JC_DOTFILES_BASE:-$config_home/jc-hyprland-dotfiles}"

monitors_lua="${JC_MONITORS_LUA:-$base/local/monitors.lua}"
backup_dir="${JC_DISPLAY_BACKUP_DIR:-$base/local/backups/displays}"

command_name="${1:-}"
shift || true

candidate=""
live_before=""
matched_outputs_file=""


usage() {
    cat <<'EOF'
Usage:
  jc-displaycfg status
  jc-displaycfg preview
  jc-displaycfg save
  jc-displaycfg backups
  jc-displaycfg restore-last

Phase 1C.1 persists the complete current runtime topology of every explicit
configured monitor that can be matched uniquely to `hyprctl -j monitors all`.

Persistent source:
  ~/.config/jc-hyprland-dotfiles/local/monitors.lua

Safety rules:
  - monitors.lua must be readable and writable.
  - current Hyprland configerrors must be clean before save.
  - explicit monitor selectors must resolve unambiguously.
  - disconnected monitor rules are preserved unchanged.
  - workspace rules, comments and all non-monitor content remain byte-identical.
  - monitor-specific extras such as VRR / bitdepth / color management remain.
  - disabled state is persisted in Lua without discarding active geometry.
  - a backup is created before replacement.
  - replacement uses an atomic same-directory rename.
  - Hyprland is reloaded and verified after the write.
  - validation failure restores the backup automatically.

`preview` never mutates the persistent file.
EOF
}


die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}


trim() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}


require_command() {
    local name="$1"

    command -v "$name" >/dev/null 2>&1 \
        || die "required command not found: $name"
}


require_dependencies() {
    local name

    for name in \
        hyprctl \
        jq \
        awk \
        cmp \
        diff \
        grep \
        mktemp \
        sha256sum \
        cp \
        mv \
        find \
        sort
    do
        require_command "$name"
    done
}


cleanup() {
    [[ -n "$candidate" && -e "$candidate" ]] \
        && rm -f -- "$candidate"

    [[ -n "$live_before" && -e "$live_before" ]] \
        && rm -f -- "$live_before"

    [[ -n "$matched_outputs_file" && -e "$matched_outputs_file" ]] \
        && rm -f -- "$matched_outputs_file"

    return 0
}


trap cleanup EXIT


normalized_description() {
    local description="$1"
    local output="$2"
    local suffix=" ($output)"

    description="$(trim "$description")"

    if [[ "$description" == *"$suffix" ]]; then
        description="${description%"$suffix"}"
        description="$(trim "$description")"
    fi

    printf '%s' "$description"
}


snapshot_live_monitors() {
    live_before="$(mktemp "${TMPDIR:-/tmp}/jc-displaycfg-live.XXXXXX")"

    if ! hyprctl -j monitors all > "$live_before"; then
        die "unable to query Hyprland monitor state"
    fi

    jq -e 'type == "array"' "$live_before" >/dev/null \
        || die "Hyprland monitor state is not a JSON array"
}


live_match_count_for_selector() {
    local selector="$1"
    local row
    local name
    local description
    local normalized
    local count=0

    while IFS= read -r row; do
        name="$(jq -r '.name // ""' <<< "$row")"
        description="$(jq -r '.description // ""' <<< "$row")"
        normalized="$(normalized_description "$description" "$name")"

        if [[ "$selector" == "$name" \
            || "$selector" == "desc:$normalized" ]]
        then
            ((count += 1))
        fi
    done < <(jq -c '.[]' "$live_before")

    printf '%d' "$count"
}


live_monitor_for_selector() {
    local selector="$1"
    local row
    local name
    local description
    local normalized

    while IFS= read -r row; do
        name="$(jq -r '.name // ""' <<< "$row")"
        description="$(jq -r '.description // ""' <<< "$row")"
        normalized="$(normalized_description "$description" "$name")"

        if [[ "$selector" == "$name" \
            || "$selector" == "desc:$normalized" ]]
        then
            printf '%s' "$row"
            return 0
        fi
    done < <(jq -c '.[]' "$live_before")

    return 1
}


lua_unquote() {
    local value
    value="$(trim "$1")"

    if [[ "$value" =~ ^\"(.*)\"$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' "$value"
    fi
}


monitor_block_selector() {
    local block="$1"
    local line
    local value

    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*output[[:space:]]*=[[:space:]]*(.*),[[:space:]]*$ ]]; then
            value="${BASH_REMATCH[1]}"
            lua_unquote "$value"
            return 0
        fi
    done <<< "$block"

    return 1
}


runtime_mode() {
    local row="$1"
    local width
    local height
    local refresh

    width="$(jq -r '.width // 0' <<< "$row")"
    height="$(jq -r '.height // 0' <<< "$row")"
    refresh="$(jq -r '.refreshRate // 0' <<< "$row")"

    if [[ "$width" =~ ^[0-9]+$ \
        && "$height" =~ ^[0-9]+$ ]] \
        && awk -v refresh="$refresh" 'BEGIN { exit !(refresh > 0) }'
    then
        printf '%sx%s@%s' "$width" "$height" "$refresh"
        return 0
    fi

    return 1
}


number_equal() {
    local left="$1"
    local right="$2"

    awk \
        -v left="$left" \
        -v right="$right" \
        'function abs(v) { return v < 0 ? -v : v }
         BEGIN { exit !(abs(left - right) < 0.0001) }'
}


mode_equal() {
    local left="$1"
    local right="$2"

    [[ "$left" =~ ^([0-9]+)x([0-9]+)@([0-9]+([.][0-9]+)?)$ ]] \
        || return 1

    local left_width="${BASH_REMATCH[1]}"
    local left_height="${BASH_REMATCH[2]}"
    local left_refresh="${BASH_REMATCH[3]}"

    [[ "$right" =~ ^([0-9]+)x([0-9]+)@([0-9]+([.][0-9]+)?)$ ]] \
        || return 1

    local right_width="${BASH_REMATCH[1]}"
    local right_height="${BASH_REMATCH[2]}"
    local right_refresh="${BASH_REMATCH[3]}"

    [[ "$left_width" == "$right_width" \
        && "$left_height" == "$right_height" ]] \
        || return 1

    number_equal "$left_refresh" "$right_refresh"
}


line_indent() {
    local line="$1"
    printf '%s' "${line%%[![:space:]]*}"
}


rewrite_monitor_block() {
    local block="$1"
    local row="$2"

    local selector
    selector="$(monitor_block_selector "$block")" \
        || die "hl.monitor block is missing output field"

    local disabled
    local mode
    local x
    local y
    local scale
    local transform

    disabled="$(jq -r '.disabled // false' <<< "$row")"
    x="$(jq -r '.x // 0' <<< "$row")"
    y="$(jq -r '.y // 0' <<< "$row")"
    scale="$(jq -r '.scale // 1' <<< "$row")"
    transform="$(jq -r '.transform // 0' <<< "$row")"

    [[ "$disabled" == "true" || "$disabled" == "false" ]] \
        || die "invalid disabled state for $selector"

    [[ "$x" =~ ^-?[0-9]+$ && "$y" =~ ^-?[0-9]+$ ]] \
        || die "invalid runtime position for $selector"

    awk -v scale="$scale" 'BEGIN { exit !(scale > 0) }' \
        || die "invalid runtime scale for $selector"

    [[ "$transform" =~ ^[0-7]$ ]] \
        || die "invalid runtime transform for $selector"

    mode="$(runtime_mode "$row" || true)"

    # A disabled monitor may retain geometry in `monitors all`; if Hyprland
    # cannot report a reusable mode, keep the persisted geometry unchanged
    # rather than discarding it.
    if [[ "$disabled" == "false" && -z "$mode" ]]; then
        die "active monitor $selector has no reusable runtime mode"
    fi

    local has_disabled=false
    local has_transform=false

    if grep -Eq '^[[:space:]]*disabled[[:space:]]*=' <<< "$block"; then
        has_disabled=true
    fi

    if grep -Eq '^[[:space:]]*transform[[:space:]]*=' <<< "$block"; then
        has_transform=true
    fi

    local line
    local indent
    local stripped_line
    local close_indent=""

    while IFS= read -r line; do
        indent="$(line_indent "$line")"
        stripped_line="$(trim "$line")"

        if [[ "$line" =~ ^[[:space:]]*mode[[:space:]]*=[[:space:]]*(.*),[[:space:]]*$ ]]; then
            if [[ -z "$mode" ]]; then
                printf '%s\n' "$line"
            else
                local persisted_mode
                persisted_mode="$(lua_unquote "${BASH_REMATCH[1]}")"

                if mode_equal "$persisted_mode" "$mode"; then
                    printf '%s\n' "$line"
                else
                    printf '%smode = "%s",\n' "$indent" "$mode"
                fi
            fi
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*position[[:space:]]*= ]]; then
            printf '%sposition = "%sx%s",\n' "$indent" "$x" "$y"
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*scale[[:space:]]*=[[:space:]]*(.*),[[:space:]]*$ ]]; then
            local persisted_scale
            persisted_scale="$(lua_unquote "${BASH_REMATCH[1]}")"

            if [[ "$persisted_scale" =~ ^[0-9]+([.][0-9]+)?$ ]]                 && number_equal "$persisted_scale" "$scale"
            then
                printf '%s\n' "$line"
            else
                printf '%sscale = %s,\n' "$indent" "$scale"
            fi
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*transform[[:space:]]*=[[:space:]]*([0-7])[[:space:]]*,[[:space:]]*$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$transform" ]]; then
                printf '%s\n' "$line"
            else
                printf '%stransform = %s,\n' "$indent" "$transform"
            fi
            continue
        fi

        if [[ "$line" =~ ^[[:space:]]*disabled[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*,[[:space:]]*$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$disabled" ]]; then
                printf '%s\n' "$line"
            else
                printf '%sdisabled = %s,\n' "$indent" "$disabled"
            fi
            continue
        fi

        if [[ "$stripped_line" == "})" || "$stripped_line" == "})," ]]; then
            close_indent="$indent"
            local field_indent="${close_indent}    "

            # Keep enabled configs compact unless a disabled field already
            # exists. A disabled output gets an explicit persistent flag while
            # all geometry fields remain in the same block.
            if [[ "$disabled" == "true" && "$has_disabled" == "false" ]]; then
                printf '%sdisabled = true,\n' "$field_indent"
            fi

            if [[ "$transform" != "0" && "$has_transform" == "false" ]]; then
                printf '%stransform = %s,\n' "$field_indent" "$transform"
            fi

            printf '%s\n' "$line"
            continue
        fi

        printf '%s\n' "$line"
    done < <(printf '%s' "$block")
}


mask_monitor_blocks() {
    local source="$1"

    awk '
        BEGIN {
            in_monitor = 0
        }

        /^[[:space:]]*hl[.]monitor[[:space:]]*[(][[:space:]]*[{][[:space:]]*$/ {
            if (in_monitor) {
                exit 3
            }

            print "__JC_MONITOR_BLOCK__"
            in_monitor = 1
            next
        }

        in_monitor && /^[[:space:]]*[}][)][[:space:]]*,?[[:space:]]*$/ {
            in_monitor = 0
            next
        }

        in_monitor {
            next
        }

        {
            print
        }

        END {
            if (in_monitor) {
                exit 3
            }
        }
    ' "$source"
}


validate_candidate_structure() {
    [[ -s "$candidate" ]] \
        || die "generated monitors.lua candidate is empty"

    local original_masked
    local candidate_masked

    original_masked="$(mktemp "${TMPDIR:-/tmp}/jc-displaycfg-original.XXXXXX")"
    candidate_masked="$(mktemp "${TMPDIR:-/tmp}/jc-displaycfg-candidate.XXXXXX")"

    if ! mask_monitor_blocks "$monitors_lua" > "$original_masked"; then
        rm -f -- "$original_masked" "$candidate_masked"
        die "malformed hl.monitor block in $monitors_lua"
    fi

    if ! mask_monitor_blocks "$candidate" > "$candidate_masked"; then
        rm -f -- "$original_masked" "$candidate_masked"
        die "malformed hl.monitor block in candidate"
    fi

    if ! cmp -s -- "$original_masked" "$candidate_masked"; then
        rm -f -- "$original_masked" "$candidate_masked"
        die \
            "candidate modified comments, workspace rules or other " \
            "non-monitor Lua configuration"
    fi

    rm -f -- "$original_masked" "$candidate_masked"

    local old_count
    local new_count

    old_count="$(
        grep -Ec \
            '^[[:space:]]*hl[.]monitor[[:space:]]*[(][[:space:]]*[{][[:space:]]*$' \
            "$monitors_lua"
    )"

    new_count="$(
        grep -Ec \
            '^[[:space:]]*hl[.]monitor[[:space:]]*[(][[:space:]]*[{][[:space:]]*$' \
            "$candidate"
    )"

    [[ "$old_count" == "$new_count" ]] \
        || die "candidate changed number of hl.monitor blocks"
}


build_candidate() {
    [[ -r "$monitors_lua" ]] \
        || die "monitor configuration is not readable: $monitors_lua"

    snapshot_live_monitors

    candidate="$(mktemp "${monitors_lua}.candidate.XXXXXX")"
    matched_outputs_file="$(mktemp "${TMPDIR:-/tmp}/jc-displaycfg-matched.XXXXXX")"

    local line
    local stripped_line
    local in_monitor=false
    local block=""
    local selector
    local match_count
    local row
    local output
    local matched_count=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        stripped_line="$(trim "$line")"

        if [[ "$in_monitor" == "false" && "$stripped_line" == "hl.monitor({" ]]; then
            in_monitor=true
            block="${line}"$'\n'
            continue
        fi

        if [[ "$in_monitor" == "true" ]]; then
            block+="${line}"$'\n'

            if [[ "$stripped_line" == "})" || "$stripped_line" == "})," ]]; then
                selector="$(monitor_block_selector "$block")" \
                    || die "hl.monitor block is missing output field"

                match_count="$(live_match_count_for_selector "$selector")"

                if ((match_count == 0)); then
                    # Disconnected / unavailable persistent monitor.
                    printf '%s' "$block" >> "$candidate"
                elif ((match_count > 1)); then
                    die \
                        "persistent selector matches multiple live monitors: " \
                        "$selector"
                else
                    row="$(live_monitor_for_selector "$selector")" \
                        || die \
                            "unable to resolve live monitor for selector: " \
                            "$selector"

                    output="$(jq -r '.name // ""' <<< "$row")"

                    [[ -n "$output" ]] \
                        || die "matched monitor has no output name: $selector"

                    if grep -Fxq -- "$output" "$matched_outputs_file"; then
                        die \
                            "multiple persistent hl.monitor blocks resolve to " \
                            "output: $output"
                    fi

                    printf '%s\n' "$output" >> "$matched_outputs_file"
                    rewrite_monitor_block "$block" "$row" >> "$candidate"
                    ((matched_count += 1))
                fi

                in_monitor=false
                block=""
            fi

            continue
        fi

        printf '%s\n' "$line" >> "$candidate"
    done < "$monitors_lua"

    [[ "$in_monitor" == "false" ]] \
        || die "unterminated hl.monitor block in $monitors_lua"

    ((matched_count > 0)) \
        || die "no configured hl.monitor blocks matched live outputs"

    chmod --reference="$monitors_lua" "$candidate"

    validate_candidate_structure
}


config_errors() {
    hyprctl configerrors 2>/dev/null || true
}


require_clean_config() {
    local errors
    errors="$(config_errors)"
    errors="$(trim "$errors")"

    [[ -z "$errors" ]] \
        || die \
            "Hyprland already reports config errors; refusing persistence: " \
            "$errors"
}


backup_current_file() {
    mkdir -p -- "$backup_dir"
    chmod 700 "$backup_dir"

    local timestamp
    local hash
    local backup

    timestamp="$(date +%Y%m%d-%H%M%S)"
    hash="$(sha256sum "$monitors_lua" | awk '{ print substr($1, 1, 12) }')"

    backup="$backup_dir/monitors.lua.${timestamp}.$$.${hash}.bak"

    cp -p -- "$monitors_lua" "$backup"
    chmod 600 "$backup"

    printf '%s' "$backup"
}


prune_backups() {
    local -a backups=()
    local path

    while IFS= read -r path; do
        backups+=("$path")
    done < <(
        find "$backup_dir" \
            -maxdepth 1 \
            -type f \
            -name 'monitors.lua.*.bak' \
            -printf '%T@ %p\n' 2>/dev/null |
        sort -nr |
        awk 'NR > 20 { $1=""; sub(/^ /, ""); print }'
    )

    for path in "${backups[@]}"; do
        [[ -n "$path" ]] && rm -f -- "$path"
    done
}


atomic_replace_from() {
    local source="$1"
    local temporary

    temporary="$(mktemp "${monitors_lua}.replace.XXXXXX")"

    cp -p -- "$source" "$temporary"
    chmod --reference="$monitors_lua" "$temporary"

    mv -f -- "$temporary" "$monitors_lua"
}


verify_runtime_snapshot_once() {
    local live_after="$1"
    local output
    local before_row
    local after_row
    local expected_disabled

    while IFS= read -r output; do
        [[ -n "$output" ]] || continue

        before_row="$(
            jq -c \
                --arg output "$output" \
                '.[] | select(.name == $output)' \
                "$live_before"
        )"

        after_row="$(
            jq -c \
                --arg output "$output" \
                '.[] | select(.name == $output)' \
                "$live_after"
        )"

        if [[ -z "$before_row" || -z "$after_row" ]]; then
            return 1
        fi

        expected_disabled="$(jq -r '.disabled // false' <<< "$before_row")"

        if [[ "$expected_disabled" == "true" ]]; then
            jq -ne \
                --argjson after "$after_row" \
                '(($after.disabled // false) == true)' >/dev/null \
                || return 1

            continue
        fi

        if ! jq -ne \
            --argjson before "$before_row" \
            --argjson after "$after_row" \
            '
            def close($a; $b):
                (($a - $b) | if . < 0 then -. else . end) < 0.05;

            (($after.disabled // false) == false)
            and (($before.width // 0) == ($after.width // 0))
            and (($before.height // 0) == ($after.height // 0))
            and close(($before.refreshRate // 0); ($after.refreshRate // 0))
            and (($before.x // 0) == ($after.x // 0))
            and (($before.y // 0) == ($after.y // 0))
            and close(($before.scale // 1); ($after.scale // 1))
            and (($before.transform // 0) == ($after.transform // 0))
            ' >/dev/null
        then
            return 1
        fi
    done < "$matched_outputs_file"

    return 0
}


runtime_snapshot_diagnostics() {
    local live_after="$1"
    local output

    printf 'Expected vs current runtime monitor state:\n' >&2

    while IFS= read -r output; do
        [[ -n "$output" ]] || continue

        printf '  %s\n' "$output" >&2

        jq -n \
            --arg output "$output" \
            --slurpfile before "$live_before" \
            --slurpfile after "$live_after" \
            '
            def state($items):
                ($items[0]
                 | .[]
                 | select(.name == $output)
                 | {
                     disabled: (.disabled // false),
                     width: (.width // 0),
                     height: (.height // 0),
                     refreshRate: (.refreshRate // 0),
                     x: (.x // 0),
                     y: (.y // 0),
                     scale: (.scale // 1),
                     transform: (.transform // 0)
                   });

            {
                expected: state($before),
                current: state($after)
            }
            ' >&2 || true
    done < "$matched_outputs_file"
}


verify_runtime_matches_snapshot() {
    local live_after
    local attempt
    local max_attempts=40
    local delay_seconds=0.10

    live_after="$(mktemp "${TMPDIR:-/tmp}/jc-displaycfg-after.XXXXXX")"

    for ((attempt = 1; attempt <= max_attempts; attempt += 1)); do
        if hyprctl -j monitors all > "$live_after" 2>/dev/null \
            && verify_runtime_snapshot_once "$live_after"
        then
            rm -f -- "$live_after"
            return 0
        fi

        if ((attempt < max_attempts)); then
            sleep "$delay_seconds"
        fi
    done

    runtime_snapshot_diagnostics "$live_after"
    rm -f -- "$live_after"

    return 1
}


run_status() {
    require_dependencies

    printf 'Configuration: %s\n' "$monitors_lua"
    printf 'Backups:       %s\n' "$backup_dir"

    if [[ -r "$monitors_lua" ]]; then
        printf 'Readable:      yes\n'
        printf 'SHA256:        %s\n' \
            "$(sha256sum "$monitors_lua" | awk '{ print $1 }')"
    else
        printf 'Readable:      no\n'
    fi

    if [[ -w "$monitors_lua" ]]; then
        printf 'Writable:      yes\n'
    else
        printf 'Writable:      no\n'
    fi

    local errors
    errors="$(config_errors)"
    errors="$(trim "$errors")"

    if [[ -z "$errors" ]]; then
        printf 'Config errors: clean\n'
    else
        printf 'Config errors: present\n'
        printf '%s\n' "$errors"
    fi
}


run_preview() {
    require_dependencies
    build_candidate

    if cmp -s -- "$monitors_lua" "$candidate"; then
        printf 'No persistent display changes.\n'
        return 0
    fi

    diff -u \
        --label "monitors.lua (current)" \
        --label "monitors.lua (candidate)" \
        "$monitors_lua" \
        "$candidate" \
        || true
}


run_save() {
    require_dependencies

    [[ -w "$monitors_lua" ]] \
        || die "monitor configuration is not writable: $monitors_lua"

    require_clean_config
    build_candidate

    if cmp -s -- "$monitors_lua" "$candidate"; then
        printf '{"status":"unchanged","config":%s}\n' \
            "$(jq -Rn --arg value "$monitors_lua" '$value')"
        return 0
    fi

    local backup
    backup="$(backup_current_file)"

    local candidate_for_replace="$candidate"
    candidate=""

    # Candidate lives beside monitors.lua, therefore rename is same-filesystem
    # and atomic.
    mv -f -- "$candidate_for_replace" "$monitors_lua"

    if ! hyprctl reload >/dev/null 2>&1; then
        atomic_replace_from "$backup"
        hyprctl reload >/dev/null 2>&1 || true
        die \
            "Hyprland reload failed; original monitors.lua restored from " \
            "$backup"
    fi

    local errors
    errors="$(config_errors)"
    errors="$(trim "$errors")"

    if [[ -n "$errors" ]]; then
        atomic_replace_from "$backup"
        hyprctl reload >/dev/null 2>&1 || true
        die \
            "new Hyprland config errors detected; original monitors.lua " \
            "restored from $backup: $errors"
    fi

    if ! verify_runtime_matches_snapshot; then
        atomic_replace_from "$backup"
        hyprctl reload >/dev/null 2>&1 || true
        die \
            "runtime state changed unexpectedly after persistence; original " \
            "monitors.lua restored from $backup"
    fi

    prune_backups

    printf '{"status":"saved","config":%s,"backup":%s,"sha256":%s}\n' \
        "$(jq -Rn --arg value "$monitors_lua" '$value')" \
        "$(jq -Rn --arg value "$backup" '$value')" \
        "$(jq -Rn --arg value "$(sha256sum "$monitors_lua" | awk '{ print $1 }')" '$value')"
}


latest_backup() {
    [[ -d "$backup_dir" ]] || return 1

    find "$backup_dir" \
        -maxdepth 1 \
        -type f \
        -name 'monitors.lua.*.bak' \
        -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
}


run_backups() {
    require_dependencies

    if [[ ! -d "$backup_dir" ]]; then
        printf 'No display configuration backups.\n'
        return 0
    fi

    local found=false
    local path

    while IFS= read -r path; do
        [[ -n "$path" ]] || continue
        found=true
        printf '%s  %s\n' \
            "$(sha256sum "$path" | awk '{ print substr($1, 1, 12) }')" \
            "$path"
    done < <(
        find "$backup_dir" \
            -maxdepth 1 \
            -type f \
            -name 'monitors.lua.*.bak' \
            -printf '%T@ %p\n' 2>/dev/null |
        sort -nr |
        cut -d' ' -f2-
    )

    if [[ "$found" == "false" ]]; then
        printf 'No display configuration backups.\n'
    fi
}


run_restore_last() {
    require_dependencies
    require_clean_config

    local backup
    backup="$(latest_backup || true)"

    [[ -n "$backup" && -r "$backup" ]] \
        || die "no Lua display configuration backup is available"

    local safety_backup
    safety_backup="$(backup_current_file)"

    atomic_replace_from "$backup"

    if ! hyprctl reload >/dev/null 2>&1; then
        atomic_replace_from "$safety_backup"
        hyprctl reload >/dev/null 2>&1 || true
        die \
            "restored Lua backup failed to reload; previous current file " \
            "restored"
    fi

    local errors
    errors="$(config_errors)"
    errors="$(trim "$errors")"

    if [[ -n "$errors" ]]; then
        atomic_replace_from "$safety_backup"
        hyprctl reload >/dev/null 2>&1 || true
        die \
            "restored Lua backup produced config errors; previous current " \
            "file restored: $errors"
    fi

    printf '{"status":"restored","backup":%s,"safety_backup":%s}\n' \
        "$(jq -Rn --arg value "$backup" '$value')" \
        "$(jq -Rn --arg value "$safety_backup" '$value')"
}


case "$command_name" in
    status)
        (($# == 0)) || die "status does not accept arguments"
        run_status
        ;;

    preview)
        (($# == 0)) || die "preview does not accept arguments"
        run_preview
        ;;

    save)
        (($# == 0)) || die "save does not accept arguments"
        run_save
        ;;

    backups)
        (($# == 0)) || die "backups does not accept arguments"
        run_backups
        ;;

    restore-last)
        (($# == 0)) || die "restore-last does not accept arguments"
        run_restore_last
        ;;

    --help|-h|"")
        usage
        ;;

    *)
        die "unknown command: $command_name"
        ;;
esac
