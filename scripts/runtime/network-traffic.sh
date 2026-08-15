#!/usr/bin/env bash
set -uo pipefail

# ==============================================================================
# jc-hyprland-dotfiles
# Waybar network traffic module
#
# Outputs JSON suitable for:
#   "return-type": "json"
#
# No distro-specific dependencies.
# ==============================================================================

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/jc-hyprland-dotfiles-${UID}"
state_file="$runtime_dir/network-traffic.state"

mkdir -p "$runtime_dir"


# ------------------------------------------------------------------------------
# Detect default network interface
# ------------------------------------------------------------------------------

interface="$(
    ip route show default 2>/dev/null |
        awk '/default/ { print $5; exit }'
)"

if [[ -z "$interface" ]]; then
    printf '{"text":"󰖪","tooltip":"No active network interface","class":"disconnected"}\n'
    exit 0
fi

rx_file="/sys/class/net/$interface/statistics/rx_bytes"
tx_file="/sys/class/net/$interface/statistics/tx_bytes"

if [[ ! -r "$rx_file" || ! -r "$tx_file" ]]; then
    printf '{"text":"󰖪","tooltip":"Unable to read statistics for %s","class":"disconnected"}\n' \
        "$interface"
    exit 0
fi


# ------------------------------------------------------------------------------
# Read counters
# ------------------------------------------------------------------------------

rx_now=$(<"$rx_file")
tx_now=$(<"$tx_file")
time_now=$(date +%s)


# ------------------------------------------------------------------------------
# First invocation: initialize state
# ------------------------------------------------------------------------------

if [[ ! -r "$state_file" ]]; then
    printf '%s %s %s %s\n' \
        "$interface" \
        "$rx_now" \
        "$tx_now" \
        "$time_now" > "$state_file"

    printf '{"text":"󰓅 0 B/s  󰕒 0 B/s","tooltip":"Interface: %s\\nInitializing traffic monitor","class":"normal"}\n' \
        "$interface"

    exit 0
fi


# ------------------------------------------------------------------------------
# Load previous state
# ------------------------------------------------------------------------------

read -r old_interface rx_old tx_old time_old < "$state_file"

# Interface changed: reset the baseline.
if [[ "$old_interface" != "$interface" ]]; then

    printf '%s %s %s %s\n' \
        "$interface" \
        "$rx_now" \
        "$tx_now" \
        "$time_now" > "$state_file"

    printf '{"text":"󰓅 0 B/s  󰕒 0 B/s","tooltip":"Interface changed to %s","class":"normal"}\n' \
        "$interface"

    exit 0
fi


# ------------------------------------------------------------------------------
# Calculate speed
# ------------------------------------------------------------------------------

elapsed=$((time_now - time_old))

if ((elapsed <= 0)); then
    elapsed=1
fi

rx_delta=$((rx_now - rx_old))
tx_delta=$((tx_now - tx_old))

# Counters can reset when the interface reconnects.
if ((rx_delta < 0)); then
    rx_delta=0
fi

if ((tx_delta < 0)); then
    tx_delta=0
fi

rx_rate=$((rx_delta / elapsed))
tx_rate=$((tx_delta / elapsed))


# ------------------------------------------------------------------------------
# Human-readable units
# ------------------------------------------------------------------------------

human_rate() {
    local bytes="$1"

    if ((bytes >= 1073741824)); then
        awk -v b="$bytes" \
            'BEGIN { printf "%.1f GB/s", b / 1073741824 }'

    elif ((bytes >= 1048576)); then
        awk -v b="$bytes" \
            'BEGIN { printf "%.1f MB/s", b / 1048576 }'

    elif ((bytes >= 1024)); then
        awk -v b="$bytes" \
            'BEGIN { printf "%.1f KB/s", b / 1024 }'

    else
        printf '%d B/s' "$bytes"
    fi
}


rx_human=$(human_rate "$rx_rate")
tx_human=$(human_rate "$tx_rate")


# ------------------------------------------------------------------------------
# Store current sample for next execution
# ------------------------------------------------------------------------------

printf '%s %s %s %s\n' \
    "$interface" \
    "$rx_now" \
    "$tx_now" \
    "$time_now" > "$state_file"


# ------------------------------------------------------------------------------
# Waybar JSON
# ------------------------------------------------------------------------------

printf \
    '{"text":"󰓅 %s  󰕒 %s","tooltip":"Interface: %s\\nDownload: %s\\nUpload: %s","class":"normal"}\n' \
    "$rx_human" \
    "$tx_human" \
    "$interface" \
    "$rx_human" \
    "$tx_human"