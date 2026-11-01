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

## Phase 2G.2c — low-risk connectivity controls

Phase 2G.2c exposes the reversible connectivity actions established by the
Phase 2G.2b action-service foundation.

The observed model now exposes native-object collections for:

- known Wi-Fi networks (`NetworkService.knownWifiNetworkValues`);
- paired Bluetooth devices (`BluetoothService.pairedDeviceValues`).

Native object identity is preserved so mutation ownership remains in
`NetworkActionService` and `BluetoothActionService`.

The Network view may now invoke only these low-risk actions:

- Wi-Fi radio enable/disable;
- known/saved Wi-Fi network connect/disconnect;
- Bluetooth adapter enable/disable;
- paired Bluetooth device connect/disconnect.

The presentation layer still owns no backend process or raw DBus access.
`Process`, `nmcli`, `bluetoothctl`, `busctl`, and `rfkill` remain outside
`NetworkView.qml`.

New-network PSK/password entry, network forget, Bluetooth pair/forget, and
trusted/block mutation remain deferred to later separately certified scopes.

The implementation/static gate does not execute a connectivity mutation.
Runtime mutation certification is performed separately with explicit human
authorization and before/after observed-state verification.

## Phase 2G.2d — Wi-Fi radio observed-state reconciliation fix

Runtime mutation certification exposed a false-negative feedback race in the
Wi-Fi radio action path. `NetworkActionService` received the native
`Networking.wifiEnabledChanged` signal and immediately reconciled against the
authoritative observed `NetworkService.wifiEnabled` binding. When that derived
binding had not propagated in the same event turn, no later reconciliation was
scheduled and the otherwise successful mutation could expire at the existing
6-second timeout.

The fix preserves the mutation and observation boundaries and adds a second
reconciliation trigger on `NetworkService.wifiEnabledChanged`. The native
trigger remains in place, the 6000 ms timeout is unchanged, and mutation success
still requires the authoritative observed state to match the requested radio
state. Known-network, credential/PSK, forget, Bluetooth, and presentation
boundaries are unchanged.

### Phase 2G.2d — synchronous notify timeout rearm correction

Further runtime certification proved that both the observed-state listener and
the temporary 100 ms reconciliation poll could still end with a false timeout
even when NetworkManager had already applied the requested Wi-Fi radio state.

The root cause was reentrant ordering inside `setWifiEnabled()`: the service
wrote `Networking.wifiEnabled` before arming `mutationTimeout`. The native
property is writable and exposes `wifiEnabledChanged`; if that notification is
delivered synchronously during the write, `reconcileWifiEnabled()` can complete,
call `resetPending()`, and stop the timer before `setWifiEnabled()` returns.
Control then returned to the setter, which restarted the timer after the
operation had already succeeded. Six seconds later that orphan timer surfaced a
false timeout.

The final correction arms the existing 6000 ms fail-closed timer before writing
the native Wi-Fi property. A synchronous successful reconciliation can therefore
stop an already-running timer, and no later statement rearms it. The temporary
100 ms poll has been removed. The native and observed-state event listeners
remain as reconciliation triggers.

This correction is scoped only to Wi-Fi radio timeout/reentrancy behavior.
Known-network connect/disconnect, credentials/PSK, forget actions, Bluetooth,
and Media remain unchanged.
