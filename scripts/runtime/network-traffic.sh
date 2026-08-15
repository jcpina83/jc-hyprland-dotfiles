#!/usr/bin/env bash
set -euo pipefail
iface=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')
[[ -n "${iface:-}" ]] || { printf 'offline\n'; exit 0; }
rx=$(cat "/sys/class/net/$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
tx=$(cat "/sys/class/net/$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
printf '%s  ↓%sMiB ↑%sMiB\n' "$iface" "$((rx/1024/1024))" "$((tx/1024/1024))"
