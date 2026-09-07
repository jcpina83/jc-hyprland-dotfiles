import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // -------------------------------------------------------------------------
    // Phase 2E.1b — read-only Performance / Hardware observed state.
    //
    // This service knows only the stable runtime boundary:
    //
    //   jc-performance status --json
    //
    // Presentation QML must not read kernel interfaces or hardware identifiers
    // directly. Live updates are opt-in and remain disabled until a consumer
    // explicitly requests them.
    // -------------------------------------------------------------------------

    property int snapshotSchemaVersion: 0
    property string status: "unknown"
    property bool readOnly: true

    property real uptimeSeconds: 0
    property real loadOneMinute: 0
    property real loadFiveMinutes: 0
    property real loadFifteenMinutes: 0

    property bool cpuAvailable: false
    property string cpuModel: ""
    property int cpuLogicalProcessors: 0
    property var cpuUsagePercent: null
    property string cpuScalingDriver: ""
    property string cpuGovernor: ""
    property string cpuEnergyPerformancePreference: ""
    property var cpuAverageFrequencyMHz: null
    property var cpuMinimumFrequencyKHz: null
    property var cpuMaximumFrequencyKHz: null
    property var cpuTemperatureCelsius: null

    property bool memoryAvailable: false
    property real memoryTotalBytes: 0
    property real memoryUsedBytes: 0
    property real memoryAvailableBytes: 0
    property var memoryUsagePercent: null
    property real swapTotalBytes: 0
    property real swapUsedBytes: 0
    property var swapUsagePercent: null

    property bool gpuAvailable: false
    property string gpuBackend: ""
    property string gpuSelection: ""
    property var gpuConfiguredPci: null
    property var gpuPci: null
    property var gpuVendorId: null
    property var gpuDeviceId: null
    property var gpuBusyPercent: null
    property var gpuVramTotalBytes: null
    property var gpuVramUsedBytes: null
    property var gpuVramUsagePercent: null
    property var gpuGttTotalBytes: null
    property var gpuGttUsedBytes: null
    property var gpuEdgeTemperatureCelsius: null
    property var gpuJunctionTemperatureCelsius: null
    property var gpuMemoryTemperatureCelsius: null
    property var gpuFanRpm: null
    property var gpuPowerWatts: null

    property var nvmeMaxTemperatureCelsius: null

    property bool rootStorageAvailable: false
    property var rootStorageSource: null
    property var rootStorageFilesystem: null
    property string rootStorageMountPoint: "/"
    property var rootStorageTotalBytes: null
    property var rootStorageUsedBytes: null
    property var rootStorageAvailableBytes: null
    property var rootStorageUsagePercent: null

    property bool loading: false
    property bool ready: false
    property string errorMessage: ""
    property string lastRefresh: ""

    property bool liveUpdatesEnabled: false
    property int refreshIntervalMs: 2000

    readonly property bool observedHealthy:
        root.ready
        && (root.status === "ok" || root.status === "partial")
        && root.errorMessage.length === 0

    signal refreshed()
    signal refreshFailed(string message)

    function configHome() {
        const configured = Quickshell.env("XDG_CONFIG_HOME");

        if (configured !== null && String(configured).length > 0)
            return String(configured);

        const home = Quickshell.env("HOME");

        return String(home || "") + "/.config";
    }

    function performanceCommandPath() {
        return root.configHome()
            + "/jc-hyprland-dotfiles/bin/jc-performance";
    }

    function parseResponse(text) {
        const source = String(text || "").trim();

        if (source.length === 0)
            return null;

        try {
            return JSON.parse(source);
        } catch (error) {
            return null;
        }
    }

    function numberOrNull(value) {
        return value === null || typeof value === "number";
    }

    function stringOrNull(value) {
        return value === null || typeof value === "string";
    }

    function validStatus(payload) {
        if (!payload || typeof payload !== "object")
            return false;

        if (Number(payload.schemaVersion) !== 1
                || (payload.status !== "ok" && payload.status !== "partial")
                || payload.readOnly !== true) {
            return false;
        }

        if (!payload.system
                || typeof payload.system !== "object"
                || !payload.system.load
                || typeof payload.system.load !== "object"
                || !payload.cpu
                || typeof payload.cpu !== "object"
                || !payload.cpu.scaling
                || typeof payload.cpu.scaling !== "object"
                || !payload.cpu.frequency
                || typeof payload.cpu.frequency !== "object"
                || !payload.memory
                || typeof payload.memory !== "object"
                || !payload.memory.swap
                || typeof payload.memory.swap !== "object"
                || !payload.gpu
                || typeof payload.gpu !== "object"
                || !payload.gpu.vram
                || typeof payload.gpu.vram !== "object"
                || !payload.gpu.gtt
                || typeof payload.gpu.gtt !== "object"
                || !payload.gpu.temperature
                || typeof payload.gpu.temperature !== "object"
                || !payload.temperatures
                || typeof payload.temperatures !== "object"
                || !payload.storage
                || typeof payload.storage !== "object"
                || !payload.storage.root
                || typeof payload.storage.root !== "object") {
            return false;
        }

        if (typeof payload.cpu.available !== "boolean"
                || typeof payload.cpu.model !== "string"
                || typeof payload.cpu.logicalProcessors !== "number"
                || !root.numberOrNull(payload.cpu.usagePercent)
                || typeof payload.cpu.scaling.driver !== "string"
                || typeof payload.cpu.scaling.governor !== "string"
                || typeof payload.cpu.scaling.energyPerformancePreference
                    !== "string"
                || !root.numberOrNull(payload.cpu.frequency.averageMHz)
                || !root.numberOrNull(payload.cpu.frequency.minimumKHz)
                || !root.numberOrNull(payload.cpu.frequency.maximumKHz)
                || !root.numberOrNull(payload.cpu.temperatureCelsius)) {
            return false;
        }

        if (typeof payload.memory.available !== "boolean"
                || typeof payload.memory.totalBytes !== "number"
                || typeof payload.memory.usedBytes !== "number"
                || typeof payload.memory.availableBytes !== "number"
                || !root.numberOrNull(payload.memory.usagePercent)
                || typeof payload.memory.swap.totalBytes !== "number"
                || typeof payload.memory.swap.usedBytes !== "number"
                || !root.numberOrNull(payload.memory.swap.usagePercent)) {
            return false;
        }

        if (typeof payload.gpu.available !== "boolean"
                || typeof payload.gpu.backend !== "string"
                || typeof payload.gpu.selection !== "string"
                || !root.stringOrNull(payload.gpu.configuredPci)
                || !root.stringOrNull(payload.gpu.pci)
                || !root.stringOrNull(payload.gpu.vendorId)
                || !root.stringOrNull(payload.gpu.deviceId)
                || !root.numberOrNull(payload.gpu.busyPercent)
                || !root.numberOrNull(payload.gpu.vram.totalBytes)
                || !root.numberOrNull(payload.gpu.vram.usedBytes)
                || !root.numberOrNull(payload.gpu.vram.usagePercent)
                || !root.numberOrNull(payload.gpu.gtt.totalBytes)
                || !root.numberOrNull(payload.gpu.gtt.usedBytes)
                || !root.numberOrNull(payload.gpu.temperature.edgeCelsius)
                || !root.numberOrNull(payload.gpu.temperature.junctionCelsius)
                || !root.numberOrNull(payload.gpu.temperature.memoryCelsius)
                || !root.numberOrNull(payload.gpu.fanRpm)
                || !root.numberOrNull(payload.gpu.powerWatts)) {
            return false;
        }

        if (!root.numberOrNull(payload.temperatures.cpuCelsius)
                || !root.numberOrNull(payload.temperatures.nvmeMaxCelsius)) {
            return false;
        }

        const storage = payload.storage.root;

        return typeof storage.available === "boolean"
            && root.stringOrNull(storage.source)
            && root.stringOrNull(storage.filesystem)
            && typeof storage.mountPoint === "string"
            && root.numberOrNull(storage.totalBytes)
            && root.numberOrNull(storage.usedBytes)
            && root.numberOrNull(storage.availableBytes)
            && root.numberOrNull(storage.usagePercent);
    }

    function fail(message) {
        root.loading = false;
        root.errorMessage =
            String(message || "Performance refresh failed.");
        root.refreshFailed(root.errorMessage);
    }

    function commitSnapshot(payload) {
        root.snapshotSchemaVersion = Number(payload.schemaVersion);
        root.status = String(payload.status || "unknown");
        root.readOnly = Boolean(payload.readOnly);

        root.uptimeSeconds = Number(payload.system.uptimeSeconds || 0);
        root.loadOneMinute = Number(payload.system.load.oneMinute || 0);
        root.loadFiveMinutes = Number(payload.system.load.fiveMinutes || 0);
        root.loadFifteenMinutes =
            Number(payload.system.load.fifteenMinutes || 0);

        root.cpuAvailable = Boolean(payload.cpu.available);
        root.cpuModel = String(payload.cpu.model || "");
        root.cpuLogicalProcessors =
            Number(payload.cpu.logicalProcessors || 0);
        root.cpuUsagePercent = payload.cpu.usagePercent;
        root.cpuScalingDriver =
            String(payload.cpu.scaling.driver || "");
        root.cpuGovernor =
            String(payload.cpu.scaling.governor || "");
        root.cpuEnergyPerformancePreference =
            String(
                payload.cpu.scaling.energyPerformancePreference
                || ""
            );
        root.cpuAverageFrequencyMHz =
            payload.cpu.frequency.averageMHz;
        root.cpuMinimumFrequencyKHz =
            payload.cpu.frequency.minimumKHz;
        root.cpuMaximumFrequencyKHz =
            payload.cpu.frequency.maximumKHz;
        root.cpuTemperatureCelsius =
            payload.cpu.temperatureCelsius;

        root.memoryAvailable = Boolean(payload.memory.available);
        root.memoryTotalBytes = Number(payload.memory.totalBytes || 0);
        root.memoryUsedBytes = Number(payload.memory.usedBytes || 0);
        root.memoryAvailableBytes =
            Number(payload.memory.availableBytes || 0);
        root.memoryUsagePercent = payload.memory.usagePercent;
        root.swapTotalBytes =
            Number(payload.memory.swap.totalBytes || 0);
        root.swapUsedBytes =
            Number(payload.memory.swap.usedBytes || 0);
        root.swapUsagePercent = payload.memory.swap.usagePercent;

        root.gpuAvailable = Boolean(payload.gpu.available);
        root.gpuBackend = String(payload.gpu.backend || "");
        root.gpuSelection = String(payload.gpu.selection || "");
        root.gpuConfiguredPci = payload.gpu.configuredPci;
        root.gpuPci = payload.gpu.pci;
        root.gpuVendorId = payload.gpu.vendorId;
        root.gpuDeviceId = payload.gpu.deviceId;
        root.gpuBusyPercent = payload.gpu.busyPercent;
        root.gpuVramTotalBytes = payload.gpu.vram.totalBytes;
        root.gpuVramUsedBytes = payload.gpu.vram.usedBytes;
        root.gpuVramUsagePercent = payload.gpu.vram.usagePercent;
        root.gpuGttTotalBytes = payload.gpu.gtt.totalBytes;
        root.gpuGttUsedBytes = payload.gpu.gtt.usedBytes;
        root.gpuEdgeTemperatureCelsius =
            payload.gpu.temperature.edgeCelsius;
        root.gpuJunctionTemperatureCelsius =
            payload.gpu.temperature.junctionCelsius;
        root.gpuMemoryTemperatureCelsius =
            payload.gpu.temperature.memoryCelsius;
        root.gpuFanRpm = payload.gpu.fanRpm;
        root.gpuPowerWatts = payload.gpu.powerWatts;

        root.nvmeMaxTemperatureCelsius =
            payload.temperatures.nvmeMaxCelsius;

        root.rootStorageAvailable =
            Boolean(payload.storage.root.available);
        root.rootStorageSource = payload.storage.root.source;
        root.rootStorageFilesystem =
            payload.storage.root.filesystem;
        root.rootStorageMountPoint =
            String(payload.storage.root.mountPoint || "/");
        root.rootStorageTotalBytes =
            payload.storage.root.totalBytes;
        root.rootStorageUsedBytes =
            payload.storage.root.usedBytes;
        root.rootStorageAvailableBytes =
            payload.storage.root.availableBytes;
        root.rootStorageUsagePercent =
            payload.storage.root.usagePercent;

        root.loading = false;
        root.ready = true;
        root.errorMessage = "";
        root.lastRefresh = new Date().toLocaleTimeString();
        root.refreshed();
    }

    function refresh(): void {
        if (root.loading)
            return;

        root.loading = true;
        root.errorMessage = "";

        statusProcess.command = [
            root.performanceCommandPath(),
            "status",
            "--json"
        ];
        statusProcess.running = true;
    }

    onLiveUpdatesEnabledChanged: {
        if (root.liveUpdatesEnabled && !root.loading)
            root.refresh();
    }

    Process {
        id: statusProcess

        stdout: StdioCollector {
            id: statusOutput
        }

        stderr: StdioCollector {
            id: statusError
        }

        onExited: (exitCode, exitStatus) => {
            const stdoutText = String(statusOutput.text || "").trim();
            const stderrText = String(statusError.text || "").trim();

            if (exitCode !== 0) {
                const details = stderrText.length > 0
                    ? stderrText
                    : stdoutText;

                root.fail(
                    "Unable to inspect Performance state"
                    + (details.length > 0 ? ": " + details : "")
                );
                return;
            }

            const response = root.parseResponse(stdoutText);

            if (!root.validStatus(response)) {
                root.fail(
                    "Unexpected jc-performance status response."
                );
                return;
            }

            root.commitSnapshot(response);
        }
    }

    Timer {
        id: liveRefreshTimer
        interval: root.refreshIntervalMs
        repeat: true
        running: root.liveUpdatesEnabled
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()
}
