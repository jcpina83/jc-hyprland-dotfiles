# Network / Bluetooth Control Center

## Phase 2G.1a — Native observed-state services

Phase 2G begins with a **read-only native observation boundary**.

The installed Quickshell runtime provides:

```text
Quickshell.Networking
Quickshell.Bluetooth
```

Phase 2G.1a wraps those APIs in project-owned services:

```text
future NetworkView.qml
        |
        +--> NetworkService.qml
        |       `--> Quickshell.Networking / NetworkManager
        |
        `--> BluetoothService.qml
                `--> Quickshell.Bluetooth / BlueZ
```

The presentation layer must not import NetworkManager/BlueZ integration directly.
`NetworkService.qml` and `BluetoothService.qml` translate the native runtime state
into the project boundary.

### Network observed state

`NetworkService.qml` exposes:

- native backend availability/name;
- NetworkManager connectivity state;
- Wi-Fi software and hardware/rfkill state;
- primary Wi-Fi device connection state;
- connected Wi-Fi network name, signal strength and security type;
- primary wired device connection/link state and link speed.

Interface/network names are runtime observations only. Hardware addresses are not
promoted into the project API and must never become tracked selectors.

### Bluetooth observed state

`BluetoothService.qml` exposes:

- default adapter availability and name;
- adapter enabled/power state;
- discoverable/discovering/pairable observed state;
- currently exposed connected-device model;
- primary connected-device name/state;
- paired/trusted flags;
- battery availability and level when reported.

Bluetooth MAC addresses and DBus object paths are intentionally excluded from the
project service API.

## Mutation boundary

Phase 2G.1a performs **no mutations**.

Although the native Quickshell types expose writable properties and methods such
as Wi-Fi enable/disable, network connect/disconnect, adapter enable, Bluetooth
pair/connect/forget, and discovery controls, none are called or written by the
Phase 2G.1a services.

Future Phase 2G mutation work must be gated separately. It may use native
Quickshell actions behind an action service, a stable runtime wrapper, or a hybrid
boundary depending on secret handling and policy requirements.

## Security and privacy

Phase 2G must preserve these constraints:

- no Wi-Fi passwords in QML, logs, tracked config, or status snapshots;
- no NetworkManager secret-agent behavior in Phase 2G.1a;
- no Bluetooth MAC address persisted in Git;
- no Bluetooth DBus path persisted in Git;
- no raw `nmcli`, `bluetoothctl`, `busctl`, or DBus calls from presentation QML;
- no presentation-owned network or Bluetooth mutation.

## Phase 2G.1a status

Phase 2G.1a establishes the service boundary only.

Network navigation remains disabled and `NetworkView.qml` is intentionally
deferred to the next gated Phase 2G step.

## Phase 2G.1b — NetworkView foundation

Phase 2G.1b composes the certified read-only services into `Main.qml` and adds
`modules/network/NetworkView.qml`.

The view presents:

- overall NetworkManager connectivity/backend state;
- Wi-Fi radio, interface, connection, SSID, signal and security state;
- Ethernet interface, link and link-speed state;
- Bluetooth adapter/power state;
- connected Bluetooth device count;
- primary connected-device name/state, pairing/trust flags and battery when
  reported.

The view remains presentation-only. It does not import
`Quickshell.Networking`/`Quickshell.Bluetooth`, execute shell commands, or emit
network/Bluetooth mutation intent.

`showModule("network")` becomes available for controlled IPC/runtime validation,
but the visible Network navigation entry remains disabled until the dedicated
runtime and visual gate passes.

## Phase 2G.1c — Network navigation exposure

Phase 2G.1c exposes the existing read-only Network module in the Control Center
navigation.

This step changes navigation availability only:

- `Network` becomes enabled;
- `Notifications` remains disabled;
- Network/Bluetooth services remain read-only;
- no NetworkManager or BlueZ mutation is introduced.

Runtime and visual acceptance must be repeated after navigation exposure.

### Phase 2G.1d — Navigation availability visual semantics

Network is enabled and routable in the Control Center. Disabled navigation
semantics now attenuate the complete `JcNavItem` (surface, icon and label)
instead of only the background surface, so unavailable modules remain
visually distinct from enabled-but-unselected modules. This is presentation
only; it does not change module routing or Network/Bluetooth state.

### Phase 2G.1e — Network HUD composition

`NetworkView.qml` now uses the canonical `JcHudFrame` presentation primitive
for Connectivity, Wi-Fi, Ethernet and Bluetooth. The four observed-state
sections retain their existing data and read-only behavior while adopting
the same cut-corner frame, inner frame and primary HUD accent language used
by the established Control Center modules.

This phase is presentation-only. It does not change `NetworkService`,
`BluetoothService`, module routing, or any network/Bluetooth mutation
boundary.

## Phase 2G.2b — native action-service foundation

Phase 2G.2b introduces dedicated `NetworkActionService.qml` and
`BluetoothActionService.qml` boundaries for future low-risk connectivity
mutations.

The services use the installed Quickshell native APIs directly and preserve the
observed-state services as the source of truth. Their foundation scope is:

- Wi-Fi radio enable/disable;
- saved/known Wi-Fi network connect/disconnect;
- Bluetooth adapter enable/disable;
- paired Bluetooth device connect/disconnect.

No Network or Bluetooth control is enabled in the UI during Phase 2G.2b, and
the phase runtime/static gate must not invoke a mutation.

Credential-bearing and destructive flows remain deferred:

- new Wi-Fi connection with PSK/password;
- saved network forget;
- Bluetooth pairing;
- Bluetooth forget.

`NetworkView.qml` remains presentation-only. It receives action-service handles
from `Main.qml`, but does not execute `nmcli`, `bluetoothctl`, `busctl`,
`rfkill`, raw DBus, or a `Process` backend.
