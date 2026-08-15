#!/usr/bin/env bash

set -uo pipefail

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
host_env="$base/local/host.env"

if [[ ! -r "$host_env" ]]; then
    printf '{"text":"GPU ?","tooltip":"host.env not found","class":"unavailable"}\n'
    exit 0
fi

# Machine-local hardware configuration.
# This file is intentionally outside the repository and resolved at runtime.
# shellcheck disable=SC1090
source "$host_env"

if [[ -z "${GPU_PCI:-}" ]]; then
    printf '{"text":"GPU ?","tooltip":"GPU_PCI is not configured","class":"unavailable"}\n'
    exit 0
fi

device="/sys/bus/pci/devices/$GPU_PCI"

if [[ ! -d "$device" ]]; then
    printf '{"text":"GPU ?","tooltip":"PCI device %s not found","class":"unavailable"}\n' \
        "$GPU_PCI"
    exit 0
fi

busy=0

if [[ -r "$device/gpu_busy_percent" ]]; then
    busy=$(<"$device/gpu_busy_percent")
fi

temperature="?"

for hwmon in "$device"/hwmon/hwmon*; do
    [[ -d "$hwmon" ]] || continue

    if [[ -r "$hwmon/name" ]] && [[ "$(<"$hwmon/name")" == "amdgpu" ]]; then
        if [[ -r "$hwmon/temp1_input" ]]; then
            temp_raw=$(<"$hwmon/temp1_input")
            temperature=$((temp_raw / 1000))
            break
        fi
    fi
done

vram_used_mb=0
vram_total_mb=0

if [[ -r "$device/mem_info_vram_used" ]]; then
    vram_used=$(<"$device/mem_info_vram_used")
    vram_used_mb=$((vram_used / 1024 / 1024))
fi

if [[ -r "$device/mem_info_vram_total" ]]; then
    vram_total=$(<"$device/mem_info_vram_total")
    vram_total_mb=$((vram_total / 1024 / 1024))
fi

class="normal"

if [[ "$temperature" =~ ^[0-9]+$ ]]; then
    if (( temperature >= 85 )); then
        class="critical"
    elif (( temperature >= 75 )); then
        class="warning"
    fi
fi

text="󰢮 ${busy}%"

if [[ "$temperature" != "?" ]]; then
    text+=" ${temperature}°C"
fi

tooltip="AMD GPU\nPCI: ${GPU_PCI}\nUsage: ${busy}%"

if [[ "$temperature" != "?" ]]; then
    tooltip+="\nTemperature: ${temperature}°C"
fi

if (( vram_total_mb > 0 )); then
    tooltip+="\nVRAM: ${vram_used_mb} / ${vram_total_mb} MiB"
fi

printf '{"text":"%s","tooltip":"%s","class":"%s","percentage":%d}\n' \
    "$text" \
    "${tooltip//$'\n'/\\n}" \
    "$class" \
    "$busy"