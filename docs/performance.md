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

## Phase 2E.3 — Navigation and live telemetry lifecycle

Performance is now an enabled Control Center module.

The polling lifecycle is declarative and centralized in Main.qml.
PerformanceService.liveUpdatesEnabled is true only when the Control Center is
logically visible and activeModuleId is "performance". The service Timer keeps
ownership of the 2000 ms cadence.

Entering Performance therefore enables live observed-state updates and triggers
an immediate refresh through the existing onLiveUpdatesEnabledChanged contract.
Switching to another module or closing the Control Center makes
liveUpdatesEnabled false and stops periodic telemetry.

The generic refreshControlCenter() route also refreshes Performance explicitly
when it is the active module.

PerformanceView.qml remains read-only. It owns no Process, kernel path, hardware
identifier or backend command. Its footer reports the live-refresh cadence while
Performance is visible.

The Performance navigation item is enabled in ControlCenterNavigation.qml.
Media, Network and Notifications remain future disabled entries.

## Phase 2E.4 — Telemetry UX and hardware semantics

Phase 2E.4 adds hardware-aware semantic feedback without moving hardware
discovery into presentation QML.

The stable schema remains `schemaVersion: 1`; the change is additive. The
runtime now exposes optional hardware limits alongside observed telemetry:

- CPU temperature max/critical/emergency thresholds when k10temp publishes
  them;
- AMDGPU edge/junction/memory critical and emergency temperatures;
- AMDGPU power cap and maximum fan RPM when exported by HWMON;
- NVMe `temp*_max` and `temp*_crit` thresholds, reduced conservatively to the
  lowest observed threshold when multiple NVMe sensors exist.

Unavailable limits remain `null`. No `hwmonN`, DRM card number or machine-local
PCI address is persisted in the repository.

PerformanceService projects these limit values but continues to consume only
`jc-performance status --json`. PerformanceView still owns no `/proc`, `/sys`
or hardware discovery.

### Severity policy

Utilization-style metrics use the existing UX policy:

```text
normal    < 75%
warning   >= 75%
critical  >= 90%
```

Temperature semantics prefer hardware-published thresholds.

For AMDGPU, the hardware critical temperature is the critical boundary and the
warning boundary is derived at 85% of that critical temperature. If no GPU
critical value is available, the explicit presentation fallback is
85 °C warning / 100 °C critical.

For NVMe, `temp*_max` is the warning boundary and `temp*_crit` is the critical
boundary. If unavailable, the explicit presentation fallback is
70 °C warning / 85 °C critical.

Some AMD k10temp drivers expose Tctl/Tccd readings without max/critical
thresholds. In that case PerformanceView uses an explicit UX fallback of
80 °C warning / 90 °C critical. These values are fallback presentation
semantics, not claims about a processor's vendor-rated thermal limit.

Power draw and fan speed remain informational. Reaching a GPU power cap or a
high fan speed is not classified as a fault by this UI.

Unavailable sensors remain visually muted and display `Unavailable`; missing
optional telemetry does not create a false warning.

Detail-row values reuse the canonical Theme semantic colors. Normal values keep
the ordinary text color, warnings use `theme.warning`, critical values use
`theme.danger`, informational hardware limits use `theme.info`, and unavailable
values use `theme.textMuted`.

### Live-refresh visual stability

Periodic telemetry must update values without reconstructing the Performance
card hierarchy. The CPU, Memory, GPU and System card delegates therefore use a
stable numeric Repeater model, and each row delegate also keeps a stable numeric
model while its displayed value remains bound to PerformanceService.

This prevents the 2 s live refresh from destroying and recreating card/row
objects, which otherwise produces visible flashing and can disturb scrolling.
The Refresh action also keeps a stable label and enabled presentation during
automatic refresh; overlapping refresh requests remain rejected by
PerformanceService.refresh().

### HUD detail cards and stable status chrome

Performance detail cards use the same angular HUD material ownership as the
rest of the production Control Center. The outer JcSurface delegates its visual
material with `fillEnabled: false`, while a presentation-only JcHudFrame owns
the visible `hudSurface`, inner frame and corner accents.

Live telemetry refresh is intentionally limited to metric values and rings.
The Performance header does not rewrite an `Updated <timestamp>` string every
two seconds, and the footer uses a stable status string rendered on a cached
text layer. This keeps non-metric UI chrome visually stationary while observed
telemetry continues to refresh.
