#!/usr/bin/env bash
set -euo pipefail

schema_version=1
json_output=false

base="${XDG_CONFIG_HOME:-$HOME/.config}/jc-hyprland-dotfiles"
host_env="$base/local/host.env"

usage() {
    cat <<'USAGE'
Usage:
  jc-performance status [--json]
  jc-performance --help

Stable Performance / Hardware contract:
  status  Read current CPU, memory, AMD GPU, temperatures, root storage,
          load and uptime telemetry without mutating system state.

GPU selection:
  1. Use machine-local GPU_PCI when it points to an AMDGPU device.
  2. Otherwise select the AMDGPU PCI device with the largest VRAM.
  3. If no supported AMDGPU device exists, return GPU available=false.

Data sources:
  CPU / load / memory  /proc
  CPU frequency         /sys/devices/system/cpu/cpufreq
  AMD GPU               /sys/bus/pci + amdgpu sysfs
  temperatures          /sys/class/hwmon and device hwmon links
  root storage          df

The API is read-only. Optional unavailable telemetry is represented as null
or available=false and does not make the complete status request fail.

Exit codes:
  0  status returned successfully
  2  invalid usage
  3  required runtime dependency unavailable
USAGE
}

die_usage() {
    printf 'ERROR: %s\n\n' "$*" >&2
    usage >&2
    exit 2
}

require_jq() {
    command -v jq >/dev/null 2>&1 || {
        printf 'ERROR: jq is required by jc-performance\n' >&2
        exit 3
    }
}

json_number() {
    local value="${1:-}"

    if [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        printf '%s' "$value"
    else
        printf 'null'
    fi
}

read_first_line() {
    local path="$1"

    [[ -r "$path" ]] || return 1
    head -n 1 "$path"
}

merge_uniform_value() {
    local current="$1"
    local observed="$2"

    if [[ -z "$observed" ]]; then
        printf '%s' "$current"
    elif [[ -z "$current" ]]; then
        printf '%s' "$observed"
    elif [[ "$current" == "$observed" ]]; then
        printf '%s' "$current"
    else
        printf 'mixed'
    fi
}

read_cpu_ticks() {
    local -a fields=()

    IFS=' ' read -r -a fields < /proc/stat

    if [[ "${fields[0]:-}" != "cpu" || ${#fields[@]} -lt 8 ]]; then
        return 1
    fi

    local user="${fields[1]:-0}"
    local nice="${fields[2]:-0}"
    local system="${fields[3]:-0}"
    local idle="${fields[4]:-0}"
    local iowait="${fields[5]:-0}"
    local irq="${fields[6]:-0}"
    local softirq="${fields[7]:-0}"
    local steal="${fields[8]:-0}"

    local idle_all=$((idle + iowait))
    local non_idle=$((user + nice + system + irq + softirq + steal))

    printf '%d %d\n' "$((idle_all + non_idle))" "$idle_all"
}

sample_cpu_usage() {
    local total_before=0
    local idle_before=0
    local total_after=0
    local idle_after=0

    read -r total_before idle_before < <(read_cpu_ticks) || return 1
    sleep 0.20
    read -r total_after idle_after < <(read_cpu_ticks) || return 1

    local total_delta=$((total_after - total_before))
    local idle_delta=$((idle_after - idle_before))

    if ((total_delta <= 0)); then
        return 1
    fi

    awk \
        -v total="$total_delta" \
        -v idle="$idle_delta" \
        'BEGIN { printf "%.1f", 100.0 * (total - idle) / total }'
}

read_meminfo_kb() {
    local key="$1"

    awk \
        -v wanted="$key" \
        '$1 == wanted ":" { print $2; exit }' \
        /proc/meminfo
}

hwmon_temp_by_label() {
    local root="$1"
    local wanted_label="$2"
    local input=""
    local stem=""
    local label_file=""
    local label=""
    local raw=""

    for input in "$root"/temp*_input; do
        [[ -r "$input" ]] || continue

        stem="${input%_input}"
        label_file="${stem}_label"
        label=""

        if [[ -r "$label_file" ]]; then
            label="$(<"$label_file")"
        fi

        if [[ "${label,,}" == "${wanted_label,,}" ]]; then
            raw="$(<"$input")"

            if [[ "$raw" =~ ^-?[0-9]+$ ]]; then
                awk -v raw="$raw" 'BEGIN { printf "%.1f", raw / 1000.0 }'
                return 0
            fi
        fi
    done

    return 1
}

first_hwmon_temp() {
    local root="$1"
    local input=""
    local raw=""

    for input in "$root"/temp*_input; do
        [[ -r "$input" ]] || continue
        raw="$(<"$input")"

        if [[ "$raw" =~ ^-?[0-9]+$ ]]; then
            awk -v raw="$raw" 'BEGIN { printf "%.1f", raw / 1000.0 }'
            return 0
        fi
    done

    return 1
}

cpu_temperature() {
    local hwmon=""
    local name=""
    local value=""

    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -d "$hwmon" && -r "$hwmon/name" ]] || continue
        name="$(<"$hwmon/name")"

        [[ "$name" == "k10temp" ]] || continue

        if value="$(hwmon_temp_by_label "$hwmon" "Tctl")"; then
            printf '%s' "$value"
            return 0
        fi

        if value="$(first_hwmon_temp "$hwmon")"; then
            printf '%s' "$value"
            return 0
        fi
    done

    return 1
}

nvme_max_temperature() {
    local hwmon=""
    local name=""
    local input=""
    local raw=""
    local max_raw=""

    for hwmon in /sys/class/hwmon/hwmon*; do
        [[ -d "$hwmon" && -r "$hwmon/name" ]] || continue
        name="$(<"$hwmon/name")"

        [[ "$name" == "nvme" ]] || continue

        for input in "$hwmon"/temp*_input; do
            [[ -r "$input" ]] || continue
            raw="$(<"$input")"

            [[ "$raw" =~ ^-?[0-9]+$ ]] || continue

            if [[ -z "$max_raw" ]] || ((raw > max_raw)); then
                max_raw="$raw"
            fi
        done
    done

    [[ -n "$max_raw" ]] || return 1
    awk -v raw="$max_raw" 'BEGIN { printf "%.1f", raw / 1000.0 }'
}

amdgpu_device_valid() {
    local pci="$1"
    local device="/sys/bus/pci/devices/$pci"
    local driver=""

    [[ -d "$device" ]] || return 1
    [[ -e "$device/driver" ]] || return 1

    driver="$(basename "$(readlink -f "$device/driver")")"
    [[ "$driver" == "amdgpu" ]]
}

gpu_selection="none"
gpu_configured_pci=""
selected_gpu_pci=""

select_amdgpu_pci() {
    local configured="${GPU_PCI:-}"
    local device=""
    local pci=""
    local vram=""
    local best_pci=""
    local best_vram=-1

    gpu_selection="none"
    gpu_configured_pci="$configured"

    selected_gpu_pci=""

    if [[ -n "$configured" ]] && amdgpu_device_valid "$configured"; then
        gpu_selection="configured-pci"
        selected_gpu_pci="$configured"
        return 0
    fi

    for device in /sys/bus/pci/drivers/amdgpu/[0-9a-fA-F]*:*:*.*; do
        [[ -e "$device" ]] || continue

        pci="$(basename "$device")"
        vram="0"

        if [[ -r "$device/mem_info_vram_total" ]]; then
            vram="$(<"$device/mem_info_vram_total")"
        fi

        [[ "$vram" =~ ^[0-9]+$ ]] || vram=0

        if ((vram > best_vram)); then
            best_vram="$vram"
            best_pci="$pci"
        fi
    done

    [[ -n "$best_pci" ]] || return 1

    if [[ -n "$configured" ]]; then
        gpu_selection="fallback-largest-vram"
    else
        gpu_selection="largest-vram"
    fi

    selected_gpu_pci="$best_pci"
    return 0
}

gpu_hwmon_root() {
    local device="$1"
    local hwmon=""

    for hwmon in "$device"/hwmon/hwmon*; do
        [[ -d "$hwmon" && -r "$hwmon/name" ]] || continue

        if [[ "$(<"$hwmon/name")" == "amdgpu" ]]; then
            printf '%s' "$hwmon"
            return 0
        fi
    done

    return 1
}

collect_status_json() {
    require_jq

    local cpu_usage=""
    local cpu_model=""
    local cpu_logical=0
    local cpu_driver=""
    local cpu_governor=""
    local cpu_epp=""
    local cpu_freq_count=0
    local cpu_freq_sum_khz=0
    local cpu_freq_avg_mhz=""
    local cpu_freq_min_khz=""
    local cpu_freq_max_khz=""
    local policy=""
    local value=""

    cpu_usage="$(sample_cpu_usage || true)"
    cpu_model="$(
        awk -F: \
            '/^model name[[:space:]]*:/ {
                sub(/^[[:space:]]+/, "", $2);
                print $2;
                exit
            }' \
            /proc/cpuinfo
    )"
    cpu_logical="$(grep -c '^processor[[:space:]]*:' /proc/cpuinfo || true)"

    for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        [[ -d "$policy" ]] || continue

        value="$(read_first_line "$policy/scaling_driver" 2>/dev/null || true)"
        cpu_driver="$(merge_uniform_value "$cpu_driver" "$value")"

        value="$(read_first_line "$policy/scaling_governor" 2>/dev/null || true)"
        cpu_governor="$(merge_uniform_value "$cpu_governor" "$value")"

        value="$(
            read_first_line \
                "$policy/energy_performance_preference" \
                2>/dev/null || true
        )"
        cpu_epp="$(merge_uniform_value "$cpu_epp" "$value")"

        value="$(read_first_line "$policy/scaling_cur_freq" 2>/dev/null || true)"
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            cpu_freq_sum_khz=$((cpu_freq_sum_khz + value))
            cpu_freq_count=$((cpu_freq_count + 1))
        fi

        value="$(read_first_line "$policy/cpuinfo_min_freq" 2>/dev/null || true)"
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            if [[ -z "$cpu_freq_min_khz" ]] || ((value < cpu_freq_min_khz)); then
                cpu_freq_min_khz="$value"
            fi
        fi

        value="$(read_first_line "$policy/cpuinfo_max_freq" 2>/dev/null || true)"
        if [[ "$value" =~ ^[0-9]+$ ]]; then
            if [[ -z "$cpu_freq_max_khz" ]] || ((value > cpu_freq_max_khz)); then
                cpu_freq_max_khz="$value"
            fi
        fi
    done

    if ((cpu_freq_count > 0)); then
        cpu_freq_avg_mhz="$(
            awk \
                -v total="$cpu_freq_sum_khz" \
                -v count="$cpu_freq_count" \
                'BEGIN { printf "%.0f", total / count / 1000.0 }'
        )"
    fi

    local cpu_temp=""
    cpu_temp="$(cpu_temperature || true)"

    local mem_total_kb=""
    local mem_available_kb=""
    local mem_used_kb=0
    local mem_total_bytes=0
    local mem_available_bytes=0
    local mem_used_bytes=0
    local mem_usage=""

    mem_total_kb="$(read_meminfo_kb MemTotal)"
    mem_available_kb="$(read_meminfo_kb MemAvailable)"

    if [[ "$mem_total_kb" =~ ^[0-9]+$ \
        && "$mem_available_kb" =~ ^[0-9]+$ ]]
    then
        mem_used_kb=$((mem_total_kb - mem_available_kb))
        mem_total_bytes=$((mem_total_kb * 1024))
        mem_available_bytes=$((mem_available_kb * 1024))
        mem_used_bytes=$((mem_used_kb * 1024))
        mem_usage="$(
            awk \
                -v used="$mem_used_kb" \
                -v total="$mem_total_kb" \
                'BEGIN {
                    if (total > 0)
                        printf "%.1f", 100.0 * used / total;
                }'
        )"
    fi

    local swap_total_kb=""
    local swap_free_kb=""
    local swap_used_kb=0
    local swap_total_bytes=0
    local swap_used_bytes=0
    local swap_usage=""

    swap_total_kb="$(read_meminfo_kb SwapTotal)"
    swap_free_kb="$(read_meminfo_kb SwapFree)"

    if [[ "$swap_total_kb" =~ ^[0-9]+$ \
        && "$swap_free_kb" =~ ^[0-9]+$ ]]
    then
        swap_used_kb=$((swap_total_kb - swap_free_kb))
        swap_total_bytes=$((swap_total_kb * 1024))
        swap_used_bytes=$((swap_used_kb * 1024))

        if ((swap_total_kb > 0)); then
            swap_usage="$(
                awk \
                    -v used="$swap_used_kb" \
                    -v total="$swap_total_kb" \
                    'BEGIN { printf "%.1f", 100.0 * used / total }'
            )"
        else
            swap_usage="0.0"
        fi
    fi

    local load1=""
    local load5=""
    local load15=""
    read -r load1 load5 load15 _ < /proc/loadavg

    local uptime_seconds=""
    uptime_seconds="$(awk '{ printf "%d", $1 }' /proc/uptime)"

    GPU_PCI=""
    if [[ -r "$host_env" ]]; then
        # shellcheck disable=SC1090
        source "$host_env"
    fi

    local gpu_pci=""
    local gpu_available=false
    local gpu_device=""
    local gpu_vendor=""
    local gpu_device_id=""
    local gpu_busy=""
    local gpu_vram_total=""
    local gpu_vram_used=""
    local gpu_vram_usage=""
    local gpu_gtt_total=""
    local gpu_gtt_used=""
    local gpu_hwmon=""
    local gpu_edge_temp=""
    local gpu_junction_temp=""
    local gpu_memory_temp=""
    local gpu_fan_rpm=""
    local gpu_power_watts=""

    if select_amdgpu_pci; then
        gpu_pci="$selected_gpu_pci"
        gpu_available=true
        gpu_device="/sys/bus/pci/devices/$gpu_pci"

        gpu_vendor="$(read_first_line "$gpu_device/vendor" 2>/dev/null || true)"
        gpu_device_id="$(read_first_line "$gpu_device/device" 2>/dev/null || true)"
        gpu_busy="$(read_first_line "$gpu_device/gpu_busy_percent" 2>/dev/null || true)"
        gpu_vram_total="$(read_first_line "$gpu_device/mem_info_vram_total" 2>/dev/null || true)"
        gpu_vram_used="$(read_first_line "$gpu_device/mem_info_vram_used" 2>/dev/null || true)"
        gpu_gtt_total="$(read_first_line "$gpu_device/mem_info_gtt_total" 2>/dev/null || true)"
        gpu_gtt_used="$(read_first_line "$gpu_device/mem_info_gtt_used" 2>/dev/null || true)"

        if [[ "$gpu_vram_total" =~ ^[0-9]+$ \
            && "$gpu_vram_used" =~ ^[0-9]+$ \
            && "$gpu_vram_total" -gt 0 ]]
        then
            gpu_vram_usage="$(
                awk \
                    -v used="$gpu_vram_used" \
                    -v total="$gpu_vram_total" \
                    'BEGIN { printf "%.1f", 100.0 * used / total }'
            )"
        fi

        if gpu_hwmon="$(gpu_hwmon_root "$gpu_device")"; then
            gpu_edge_temp="$(
                hwmon_temp_by_label "$gpu_hwmon" edge || \
                    first_hwmon_temp "$gpu_hwmon" || true
            )"
            gpu_junction_temp="$(hwmon_temp_by_label "$gpu_hwmon" junction || true)"
            gpu_memory_temp="$(hwmon_temp_by_label "$gpu_hwmon" mem || true)"
            gpu_fan_rpm="$(read_first_line "$gpu_hwmon/fan1_input" 2>/dev/null || true)"

            value="$(read_first_line "$gpu_hwmon/power1_average" 2>/dev/null || true)"
            if [[ "$value" =~ ^[0-9]+$ ]]; then
                gpu_power_watts="$(
                    awk -v raw="$value" 'BEGIN { printf "%.2f", raw / 1000000.0 }'
                )"
            fi
        fi
    fi

    local nvme_temp=""
    nvme_temp="$(nvme_max_temperature || true)"

    local storage_available=false
    local storage_source=""
    local storage_fstype=""
    local storage_total=""
    local storage_used=""
    local storage_available_bytes=""
    local storage_percent_token=""
    local storage_usage=""
    local storage_mount=""

    if read -r \
        storage_source \
        storage_fstype \
        storage_total \
        storage_used \
        storage_available_bytes \
        storage_percent_token \
        storage_mount \
        < <(
            df -B1 --output=source,fstype,size,used,avail,pcent,target / |
                tail -n 1
        )
    then
        storage_available=true
        storage_usage="${storage_percent_token%\%}"
    fi

    local overall_status="ok"

    if [[ "$gpu_available" != true || "$storage_available" != true ]]; then
        overall_status="partial"
    fi

    jq -n \
        --argjson schemaVersion "$schema_version" \
        --arg status "$overall_status" \
        --argjson uptimeSeconds "$(json_number "$uptime_seconds")" \
        --argjson load1 "$(json_number "$load1")" \
        --argjson load5 "$(json_number "$load5")" \
        --argjson load15 "$(json_number "$load15")" \
        --arg cpuModel "$cpu_model" \
        --argjson cpuLogical "$(json_number "$cpu_logical")" \
        --argjson cpuUsage "$(json_number "$cpu_usage")" \
        --arg cpuDriver "$cpu_driver" \
        --arg cpuGovernor "$cpu_governor" \
        --arg cpuEpp "$cpu_epp" \
        --argjson cpuFreqAverageMHz "$(json_number "$cpu_freq_avg_mhz")" \
        --argjson cpuFreqMinKHz "$(json_number "$cpu_freq_min_khz")" \
        --argjson cpuFreqMaxKHz "$(json_number "$cpu_freq_max_khz")" \
        --argjson cpuTemperature "$(json_number "$cpu_temp")" \
        --argjson memoryTotal "$mem_total_bytes" \
        --argjson memoryUsed "$mem_used_bytes" \
        --argjson memoryAvailable "$mem_available_bytes" \
        --argjson memoryUsage "$(json_number "$mem_usage")" \
        --argjson swapTotal "$swap_total_bytes" \
        --argjson swapUsed "$swap_used_bytes" \
        --argjson swapUsage "$(json_number "$swap_usage")" \
        --argjson gpuAvailable "$gpu_available" \
        --arg gpuSelection "$gpu_selection" \
        --arg gpuConfiguredPci "$gpu_configured_pci" \
        --arg gpuPci "$gpu_pci" \
        --arg gpuVendor "$gpu_vendor" \
        --arg gpuDeviceId "$gpu_device_id" \
        --argjson gpuBusy "$(json_number "$gpu_busy")" \
        --argjson gpuVramTotal "$(json_number "$gpu_vram_total")" \
        --argjson gpuVramUsed "$(json_number "$gpu_vram_used")" \
        --argjson gpuVramUsage "$(json_number "$gpu_vram_usage")" \
        --argjson gpuGttTotal "$(json_number "$gpu_gtt_total")" \
        --argjson gpuGttUsed "$(json_number "$gpu_gtt_used")" \
        --argjson gpuEdgeTemperature "$(json_number "$gpu_edge_temp")" \
        --argjson gpuJunctionTemperature "$(json_number "$gpu_junction_temp")" \
        --argjson gpuMemoryTemperature "$(json_number "$gpu_memory_temp")" \
        --argjson gpuFanRpm "$(json_number "$gpu_fan_rpm")" \
        --argjson gpuPowerWatts "$(json_number "$gpu_power_watts")" \
        --argjson nvmeTemperature "$(json_number "$nvme_temp")" \
        --argjson storageAvailable "$storage_available" \
        --arg storageSource "$storage_source" \
        --arg storageFilesystem "$storage_fstype" \
        --arg storageMount "$storage_mount" \
        --argjson storageTotal "$(json_number "$storage_total")" \
        --argjson storageUsed "$(json_number "$storage_used")" \
        --argjson storageFree "$(json_number "$storage_available_bytes")" \
        --argjson storageUsage "$(json_number "$storage_usage")" \
        '{
            schemaVersion: $schemaVersion,
            status: $status,
            readOnly: true,
            system: {
                uptimeSeconds: $uptimeSeconds,
                load: {
                    oneMinute: $load1,
                    fiveMinutes: $load5,
                    fifteenMinutes: $load15
                }
            },
            cpu: {
                available: true,
                model: $cpuModel,
                logicalProcessors: $cpuLogical,
                usagePercent: $cpuUsage,
                scaling: {
                    driver: $cpuDriver,
                    governor: $cpuGovernor,
                    energyPerformancePreference: $cpuEpp
                },
                frequency: {
                    averageMHz: $cpuFreqAverageMHz,
                    minimumKHz: $cpuFreqMinKHz,
                    maximumKHz: $cpuFreqMaxKHz
                },
                temperatureCelsius: $cpuTemperature
            },
            memory: {
                available: true,
                totalBytes: $memoryTotal,
                usedBytes: $memoryUsed,
                availableBytes: $memoryAvailable,
                usagePercent: $memoryUsage,
                swap: {
                    totalBytes: $swapTotal,
                    usedBytes: $swapUsed,
                    usagePercent: $swapUsage
                }
            },
            gpu: {
                available: $gpuAvailable,
                backend: (
                    if $gpuAvailable
                    then "amdgpu-sysfs"
                    else "unsupported-or-unavailable"
                    end
                ),
                selection: $gpuSelection,
                configuredPci: (
                    if $gpuConfiguredPci == ""
                    then null
                    else $gpuConfiguredPci
                    end
                ),
                pci: (
                    if $gpuPci == ""
                    then null
                    else $gpuPci
                    end
                ),
                vendorId: (
                    if $gpuVendor == ""
                    then null
                    else $gpuVendor
                    end
                ),
                deviceId: (
                    if $gpuDeviceId == ""
                    then null
                    else $gpuDeviceId
                    end
                ),
                busyPercent: $gpuBusy,
                vram: {
                    totalBytes: $gpuVramTotal,
                    usedBytes: $gpuVramUsed,
                    usagePercent: $gpuVramUsage
                },
                gtt: {
                    totalBytes: $gpuGttTotal,
                    usedBytes: $gpuGttUsed
                },
                temperature: {
                    edgeCelsius: $gpuEdgeTemperature,
                    junctionCelsius: $gpuJunctionTemperature,
                    memoryCelsius: $gpuMemoryTemperature
                },
                fanRpm: $gpuFanRpm,
                powerWatts: $gpuPowerWatts
            },
            temperatures: {
                cpuCelsius: $cpuTemperature,
                nvmeMaxCelsius: $nvmeTemperature
            },
            storage: {
                root: {
                    available: $storageAvailable,
                    source: (
                        if $storageSource == ""
                        then null
                        else $storageSource
                        end
                    ),
                    filesystem: (
                        if $storageFilesystem == ""
                        then null
                        else $storageFilesystem
                        end
                    ),
                    mountPoint: (
                        if $storageMount == ""
                        then "/"
                        else $storageMount
                        end
                    ),
                    totalBytes: $storageTotal,
                    usedBytes: $storageUsed,
                    availableBytes: $storageFree,
                    usagePercent: $storageUsage
                }
            }
        }'
}

status_human() {
    collect_status_json |
        jq -r '
            "Status: \(.status)",
            "CPU: \(.cpu.usagePercent // "?")% · \(.cpu.temperatureCelsius // "?")°C",
            "Memory: \(.memory.usagePercent // "?")%",
            (
                if .gpu.available
                then "GPU: \(.gpu.busyPercent // "?")% · \(.gpu.temperature.edgeCelsius // "?")°C · \(.gpu.pci)"
                else "GPU: unavailable"
                end
            ),
            "Storage /: \(.storage.root.usagePercent // "?")%",
            "Load: \(.system.load.oneMinute // "?") \(.system.load.fiveMinutes // "?") \(.system.load.fifteenMinutes // "?")"
        '
}

args=()

for arg in "$@"; do
    if [[ "$arg" == "--json" ]]; then
        json_output=true
    else
        args+=("$arg")
    fi
done

set -- "${args[@]}"

case "${1:-}" in
    status)
        [[ $# -eq 1 ]] || die_usage "status accepts no extra arguments"

        if [[ "$json_output" == true ]]; then
            collect_status_json
        else
            status_human
        fi
        ;;

    --help|-h|help)
        [[ $# -eq 1 ]] || die_usage "help accepts no extra arguments"
        usage
        ;;

    "")
        die_usage "a command is required"
        ;;

    *)
        die_usage "unknown command: $1"
        ;;
esac
