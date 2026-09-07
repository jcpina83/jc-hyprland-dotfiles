# Performance / Hardware

## Phase 2E.1a — Stable runtime API

Phase 2E begins with a stable, read-only telemetry boundary.

Public contract:

```bash
jc-performance status
jc-performance status --json
```

The JSON schema starts at `schemaVersion: 1` and returns:

- system uptime and 1/5/15-minute load;
- CPU model, logical processor count, utilization, frequency policy and
  temperature when available;
- memory and swap capacity/utilization;
- AMD GPU utilization, VRAM/GTT, temperatures, fan and power values when
  exposed by sysfs;
- maximum observed NVMe temperature when available;
- root filesystem capacity and utilization.

## Data-source policy

The runtime prefers kernel interfaces that already exist on a normal Linux
system:

```text
/proc/stat
/proc/loadavg
/proc/uptime
/proc/cpuinfo
/proc/meminfo
/sys/devices/system/cpu/cpufreq/
/sys/bus/pci/
/sys/class/hwmon/
df
```

`sensors` remains useful for diagnostics but is not the stable API backend.
`amdgpu_top`, `radeontop`, `nvtop`, `sysstat` and `smartmontools` are not
required by Phase 2E.1a.

## GPU selection

The runtime does not hardcode a DRM card number or HWMON index.

Selection order:

1. `GPU_PCI` from machine-local `local/host.env`, when it resolves to an
   AMDGPU-backed PCI device;
2. otherwise the AMDGPU device with the largest `mem_info_vram_total`;
3. otherwise `gpu.available=false`.

The response records the selection strategy so diagnostics can distinguish
explicit host configuration from automatic discovery.

## Failure semantics

The status request is best-effort and read-only.

Optional telemetry that cannot be read is represented with `null` or
`available=false`. The overall response may report `status: "partial"` while
still exiting successfully when core telemetry is available.

Exit codes:

```text
0  status returned successfully
2  invalid CLI usage
3  required runtime dependency unavailable
```

Phase 2E.1a performs no governor change, GPU tuning, service action, storage
mutation, Quickshell change or Control Center navigation enablement.

## Next boundary

The next implementation step is an observed-state `PerformanceService.qml`
that consumes only:

```bash
jc-performance status --json
```

Presentation QML must not read `/proc`, `/sys`, `GPU_PCI`, `hwmonN`, `cardN` or
invoke diagnostic utilities directly.

## Phase 2E.1b — Observed-state service

`PerformanceService.qml` is the read-only QML projection of:

```bash
jc-performance status --json
```

The service atomically commits one validated schema-v1 snapshot containing
system load/uptime, CPU, memory, AMD GPU, temperature and root-storage state.
Both `status: "ok"` and `status: "partial"` are accepted because optional
telemetry is allowed to degrade without invalidating the complete snapshot.

The QML service does not read `/proc`, `/sys`, `GPU_PCI`, `hwmonN` or `cardN`
directly and does not invoke hardware diagnostic tools. Those details remain
behind `jc-performance`.

The service exposes:

- `loading`, `ready`, `errorMessage`, `lastRefresh`;
- normalized CPU, memory, GPU, temperature and root-storage properties;
- `observedHealthy`;
- `refresh()`;
- opt-in live refresh through `liveUpdatesEnabled`;
- `refreshIntervalMs`, defaulting to 2000 ms.

Live refresh is intentionally disabled by default. `Main.qml` composes the
service and exposes `performanceServiceHandle`, but Phase 2E.1b does not enable
the Performance navigation entry or create `PerformanceView.qml`.

The first snapshot is requested on service completion. A later Performance
view can enable live updates only while the module is visible, avoiding
continuous telemetry polling while the feature is inactive.

## Phase 2E.2 — PerformanceView foundation

PerformanceView.qml introduces the read-only visual projection of
PerformanceService.qml.

The foundation presents CPU, memory and GPU utilization through canonical
JcMetricRing components, plus detail surfaces for CPU policy/temperature,
memory and swap, AMD GPU VRAM/temperature/power/fan telemetry, and system
storage/load/uptime.

Formatting helpers for bytes, frequency, temperature and uptime remain local
to PerformanceView.qml because the repository does not yet have a shared
formatter contract for these values.

The view owns no runtime or hardware discovery. It consumes only
performanceService properties and emits refreshRequested() for a manual
observed-state refresh.

Main.qml imports the Performance module and defines shellPerformanceComponent.
The content host can resolve that component, but moduleIsAvailable("performance")
and the Performance navigation entry remain disabled in Phase 2E.2. The view is
therefore available for runtime validation without becoming user-accessible.

Live polling also remains disabled. Activation and deactivation of
PerformanceService.liveUpdatesEnabled is deferred to the navigation lifecycle
phase after the foundation passes cold-runtime validation.
