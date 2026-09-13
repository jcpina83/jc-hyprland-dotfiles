import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme
    property var performanceService

    signal refreshRequested()

    readonly property bool serviceReady:
        root.performanceService
        && Boolean(root.performanceService.ready)

    readonly property bool serviceLoading:
        root.performanceService
        && Boolean(root.performanceService.loading)

    readonly property string operationError:
        root.performanceService
        && root.performanceService.errorMessage
            ? String(root.performanceService.errorMessage)
            : ""

    readonly property string footerStatusText:
        "Read-only observed telemetry · "
        + "Live refresh every 2s while Performance is visible."

    // CPU k10temp does not expose a critical threshold on every platform.
    // These are UX fallbacks only; hardware-published limits always win.
    readonly property real fallbackCpuWarningCelsius: 80
    readonly property real fallbackCpuCriticalCelsius: 90
    readonly property real fallbackGpuWarningCelsius: 85
    readonly property real fallbackGpuCriticalCelsius: 100
    readonly property real fallbackNvmeWarningCelsius: 70
    readonly property real fallbackNvmeCriticalCelsius: 85

    function isNumeric(value) {
        return typeof value === "number" && isFinite(value);
    }

    function metricNumber(value) {
        return root.isNumeric(value)
            ? Math.max(0, Math.min(100, Number(value)))
            : 0;
    }

    function formatPercent(value, decimals) {
        if (!root.isNumeric(value))
            return "Unavailable";

        return Number(value).toFixed(Math.max(0, decimals)) + "%";
    }

    function formatTemperature(value) {
        if (!root.isNumeric(value))
            return "Unavailable";

        return Number(value).toFixed(1) + " °C";
    }

    function formatFrequency(value) {
        if (!root.isNumeric(value))
            return "Unavailable";

        const mhz = Number(value);

        return mhz >= 1000
            ? (mhz / 1000).toFixed(2) + " GHz"
            : mhz.toFixed(0) + " MHz";
    }

    function formatBytes(value) {
        if (!root.isNumeric(value) || Number(value) < 0)
            return "Unavailable";

        const bytes = Number(value);
        const kib = 1024;
        const mib = kib * 1024;
        const gib = mib * 1024;
        const tib = gib * 1024;

        if (bytes >= tib)
            return (bytes / tib).toFixed(2) + " TiB";

        if (bytes >= gib)
            return (bytes / gib).toFixed(2) + " GiB";

        if (bytes >= mib)
            return (bytes / mib).toFixed(1) + " MiB";

        if (bytes >= kib)
            return (bytes / kib).toFixed(1) + " KiB";

        return bytes.toFixed(0) + " B";
    }

    function formatUsagePair(used, total) {
        if (!root.isNumeric(used) || !root.isNumeric(total))
            return "Unavailable";

        return root.formatBytes(used) + " / " + root.formatBytes(total);
    }

    function formatOptionalNumber(value, suffix, decimals) {
        if (!root.isNumeric(value))
            return "Unavailable";

        return Number(value).toFixed(Math.max(0, decimals))
            + String(suffix || "");
    }

    function formatDuration(value) {
        if (!root.isNumeric(value) || Number(value) < 0)
            return "Unavailable";

        let remaining = Math.floor(Number(value));
        const days = Math.floor(remaining / 86400);

        remaining -= days * 86400;

        const hours = Math.floor(remaining / 3600);

        remaining -= hours * 3600;

        const minutes = Math.floor(remaining / 60);
        const parts = [];

        if (days > 0)
            parts.push(days + "d");

        if (hours > 0 || days > 0)
            parts.push(hours + "h");

        parts.push(minutes + "m");

        return parts.join(" ");
    }

    function utilizationStatus(value) {
        if (!root.isNumeric(value))
            return "info";

        if (Number(value) >= 90)
            return "critical";

        if (Number(value) >= 75)
            return "warning";

        return "normal";
    }

    function temperatureStatus(
        value,
        warningThreshold,
        criticalThreshold,
        fallbackWarning,
        fallbackCritical
    ) {
        if (!root.isNumeric(value))
            return "info";

        const critical = root.isNumeric(criticalThreshold)
            ? Number(criticalThreshold)
            : Number(fallbackCritical);
        const warning = root.isNumeric(warningThreshold)
            ? Number(warningThreshold)
            : Number(fallbackWarning);

        if (Number(value) >= critical)
            return "critical";

        if (Number(value) >= warning)
            return "warning";

        return "normal";
    }

    function derivedGpuWarning(criticalThreshold) {
        if (!root.isNumeric(criticalThreshold))
            return root.fallbackGpuWarningCelsius;

        return Number(criticalThreshold) * 0.85;
    }

    function worstStatus(first, second) {
        const rank = {
            normal: 0,
            success: 0,
            info: 1,
            warning: 2,
            critical: 3,
            danger: 3
        };

        return Number(rank[String(first)] || 0)
            >= Number(rank[String(second)] || 0)
                ? String(first)
                : String(second);
    }

    function statusColor(status, available) {
        if (!available)
            return root.theme.textMuted;

        switch (String(status || "normal")) {
        case "warning":
            return root.theme.warning;

        case "danger":
        case "critical":
            return root.theme.danger;

        case "info":
            return root.theme.info;

        default:
            return root.theme.textPrimary;
        }
    }

    function thresholdPairText(
        warningThreshold,
        criticalThreshold,
        fallbackWarning,
        fallbackCritical
    ) {
        const warning = root.isNumeric(warningThreshold)
            ? Number(warningThreshold)
            : Number(fallbackWarning);
        const critical = root.isNumeric(criticalThreshold)
            ? Number(criticalThreshold)
            : Number(fallbackCritical);

        return warning.toFixed(1)
            + " / "
            + critical.toFixed(1)
            + " °C";
    }

    function textOrUnavailable(value) {
        const text = String(value || "").trim();

        return text.length > 0 ? text : "Unavailable";
    }

    function detailRows(section) {
        const service = root.performanceService;

        if (!service)
            return [];

        if (section === "cpu") {
            return [
                {
                    label: "Temperature",
                    value: root.formatTemperature(
                        service.cpuTemperatureCelsius
                    ),
                    available: root.isNumeric(
                        service.cpuTemperatureCelsius
                    ),
                    status: root.temperatureStatus(
                        service.cpuTemperatureCelsius,
                        service.cpuTemperatureMaxThresholdCelsius,
                        service.cpuTemperatureCriticalThresholdCelsius,
                        root.fallbackCpuWarningCelsius,
                        root.fallbackCpuCriticalCelsius
                    )
                },
                {
                    label: "Thermal policy",
                    value: root.thresholdPairText(
                        service.cpuTemperatureMaxThresholdCelsius,
                        service.cpuTemperatureCriticalThresholdCelsius,
                        root.fallbackCpuWarningCelsius,
                        root.fallbackCpuCriticalCelsius
                    ),
                    available: true,
                    status: "info"
                },
                {
                    label: "Average frequency",
                    value: root.formatFrequency(
                        service.cpuAverageFrequencyMHz
                    )
                },
                {
                    label: "Governor",
                    value: root.textOrUnavailable(service.cpuGovernor)
                },
                {
                    label: "Energy preference",
                    value: root.textOrUnavailable(
                        service.cpuEnergyPerformancePreference
                    )
                }
            ];
        }

        if (section === "memory") {
            return [
                {
                    label: "Used",
                    value: root.formatBytes(service.memoryUsedBytes),
                    available: root.isNumeric(service.memoryUsedBytes),
                    status: root.utilizationStatus(
                        service.memoryUsagePercent
                    )
                },
                {
                    label: "Available",
                    value: root.formatBytes(service.memoryAvailableBytes)
                },
                {
                    label: "Total",
                    value: root.formatBytes(service.memoryTotalBytes)
                },
                {
                    label: "Swap",
                    value: root.formatPercent(
                        service.swapUsagePercent,
                        1
                    ),
                    available: root.isNumeric(service.swapUsagePercent),
                    status: root.utilizationStatus(
                        service.swapUsagePercent
                    )
                }
            ];
        }

        if (section === "gpu") {
            return [
                {
                    label: "VRAM",
                    value: root.formatUsagePair(
                        service.gpuVramUsedBytes,
                        service.gpuVramTotalBytes
                    ),
                    available:
                        root.isNumeric(service.gpuVramUsagePercent),
                    status: root.utilizationStatus(
                        service.gpuVramUsagePercent
                    )
                },
                {
                    label: "Edge / Junction",
                    value: root.formatTemperature(
                        service.gpuEdgeTemperatureCelsius
                    ) + " / "
                        + root.formatTemperature(
                            service.gpuJunctionTemperatureCelsius
                        ),
                    available:
                        root.isNumeric(
                            service.gpuEdgeTemperatureCelsius
                        )
                        || root.isNumeric(
                            service.gpuJunctionTemperatureCelsius
                        ),
                    status: root.worstStatus(
                        root.temperatureStatus(
                            service.gpuEdgeTemperatureCelsius,
                            root.derivedGpuWarning(
                                service.gpuEdgeCriticalTemperatureCelsius
                            ),
                            service.gpuEdgeCriticalTemperatureCelsius,
                            root.fallbackGpuWarningCelsius,
                            root.fallbackGpuCriticalCelsius
                        ),
                        root.temperatureStatus(
                            service.gpuJunctionTemperatureCelsius,
                            root.derivedGpuWarning(
                                service
                                    .gpuJunctionCriticalTemperatureCelsius
                            ),
                            service
                                .gpuJunctionCriticalTemperatureCelsius,
                            root.fallbackGpuWarningCelsius,
                            root.fallbackGpuCriticalCelsius
                        )
                    )
                },
                {
                    label: "Memory temp",
                    value: root.formatTemperature(
                        service.gpuMemoryTemperatureCelsius
                    ),
                    available: root.isNumeric(
                        service.gpuMemoryTemperatureCelsius
                    ),
                    status: root.temperatureStatus(
                        service.gpuMemoryTemperatureCelsius,
                        root.derivedGpuWarning(
                            service.gpuMemoryCriticalTemperatureCelsius
                        ),
                        service.gpuMemoryCriticalTemperatureCelsius,
                        root.fallbackGpuWarningCelsius,
                        root.fallbackGpuCriticalCelsius
                    )
                },
                {
                    label: "Thermal critical",
                    value:
                        root.formatTemperature(
                            service.gpuEdgeCriticalTemperatureCelsius
                        ) + " / "
                        + root.formatTemperature(
                            service
                                .gpuJunctionCriticalTemperatureCelsius
                        ) + " / "
                        + root.formatTemperature(
                            service.gpuMemoryCriticalTemperatureCelsius
                        ),
                    available:
                        root.isNumeric(
                            service.gpuEdgeCriticalTemperatureCelsius
                        )
                        || root.isNumeric(
                            service
                                .gpuJunctionCriticalTemperatureCelsius
                        )
                        || root.isNumeric(
                            service.gpuMemoryCriticalTemperatureCelsius
                        ),
                    status: "info"
                },
                {
                    label: "Power / Fan",
                    value: root.formatOptionalNumber(
                        service.gpuPowerWatts,
                        " W",
                        1
                    ) + " / "
                        + root.formatOptionalNumber(
                            service.gpuFanRpm,
                            " RPM",
                            0
                        ),
                    available:
                        root.isNumeric(service.gpuPowerWatts)
                        || root.isNumeric(service.gpuFanRpm),
                    status: "normal"
                },
                {
                    label: "Cap / Fan max",
                    value: root.formatOptionalNumber(
                        service.gpuPowerCapWatts,
                        " W",
                        1
                    ) + " / "
                        + root.formatOptionalNumber(
                            service.gpuFanMaxRpm,
                            " RPM",
                            0
                        ),
                    available:
                        root.isNumeric(service.gpuPowerCapWatts)
                        || root.isNumeric(service.gpuFanMaxRpm),
                    status: "info"
                }
            ];
        }

        return [
            {
                label: "Root storage",
                value: root.formatUsagePair(
                    service.rootStorageUsedBytes,
                    service.rootStorageTotalBytes
                ),
                available: root.isNumeric(
                    service.rootStorageUsagePercent
                ),
                status: root.utilizationStatus(
                    service.rootStorageUsagePercent
                )
            },
            {
                label: "NVMe max",
                value: root.formatTemperature(
                    service.nvmeMaxTemperatureCelsius
                ),
                available: root.isNumeric(
                    service.nvmeMaxTemperatureCelsius
                ),
                status: root.temperatureStatus(
                    service.nvmeMaxTemperatureCelsius,
                    service.nvmeMaxThresholdCelsius,
                    service.nvmeCriticalThresholdCelsius,
                    root.fallbackNvmeWarningCelsius,
                    root.fallbackNvmeCriticalCelsius
                )
            },
            {
                label: "NVMe max / critical",
                value: root.thresholdPairText(
                    service.nvmeMaxThresholdCelsius,
                    service.nvmeCriticalThresholdCelsius,
                    root.fallbackNvmeWarningCelsius,
                    root.fallbackNvmeCriticalCelsius
                ),
                available: true,
                status: "info"
            },
            {
                label: "Load 1 / 5 / 15",
                value: Number(service.loadOneMinute || 0).toFixed(2)
                    + " / "
                    + Number(service.loadFiveMinutes || 0).toFixed(2)
                    + " / "
                    + Number(service.loadFifteenMinutes || 0).toFixed(2),
                available: service.cpuLogicalProcessors > 0,
                status: service.cpuLogicalProcessors > 0
                    ? root.utilizationStatus(
                        100
                        * Number(service.loadOneMinute || 0)
                        / Number(service.cpuLogicalProcessors)
                    )
                    : "info"
            },
            {
                label: "Uptime",
                value: root.formatDuration(service.uptimeSeconds)
            }
        ];
    }

    function detailSection(cardIndex) {
        switch (Number(cardIndex)) {
        case 0:
            return "cpu";
        case 1:
            return "memory";
        case 2:
            return "gpu";
        case 3:
            return "system";
        default:
            return "";
        }
    }

    function detailTitle(section) {
        switch (String(section || "")) {
        case "cpu":
            return "CPU";
        case "memory":
            return "Memory";
        case "gpu":
            return "GPU";
        case "system":
            return "System";
        default:
            return "";
        }
    }

    function detailSubtitle(section) {
        const service = root.performanceService;

        switch (String(section || "")) {
        case "cpu":
            return service
                ? root.textOrUnavailable(service.cpuModel)
                : "Observed processor telemetry";

        case "memory":
            return "RAM and swap";

        case "gpu":
            return service && service.gpuAvailable
                ? "AMDGPU · " + root.textOrUnavailable(service.gpuPci)
                : "GPU telemetry unavailable";

        case "system":
            return service
                ? root.textOrUnavailable(service.rootStorageFilesystem)
                    + " · "
                    + root.textOrUnavailable(service.rootStorageMountPoint)
                : "Observed system telemetry";

        default:
            return "";
        }
    }

    function detailRowCount(section) {
        return root.detailRows(section).length;
    }

    function detailRow(section, rowIndex) {
        const rows = root.detailRows(section);
        const index = Number(rowIndex);

        return index >= 0 && index < rows.length
            ? rows[index]
            : null;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.theme.spaceMd

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceMd

            Components.JcSectionHeader {
                Layout.fillWidth: true

                theme: root.theme
                title: "Performance"

                subtitle: {
                    if (!root.performanceService)
                        return "Performance service unavailable";

                    if (root.serviceLoading && !root.serviceReady)
                        return "Loading observed telemetry…";

                    if (!root.serviceReady)
                        return "Waiting for observed telemetry…";

                    const state =
                        String(root.performanceService.status || "unknown")
                            .toUpperCase();

                    return state + " · Live observed telemetry";
                }
            }

            Components.JcButton {
                theme: root.theme
                iconName: "refresh"

                text: "Refresh"
                controlEnabled: Boolean(root.performanceService)

                onClicked: root.refreshRequested()
            }
        }

        Components.JcSurface {
            visible: root.operationError.length > 0

            Layout.fillWidth: true
            implicitHeight:
                performanceErrorText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.dangerSurface
            border.color: root.theme.dangerBorder

            Text {
                id: performanceErrorText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text: root.operationError
                color: root.theme.danger

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium

                wrapMode: Text.WordWrap
            }
        }

        Flickable {
            id: performanceFlickable

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true
            contentWidth: width
            contentHeight: performanceColumn.implicitHeight

            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            pixelAligned: true

            ColumnLayout {
                id: performanceColumn

                width: performanceFlickable.width
                spacing: root.theme.spaceMd

                Components.JcSurface {
                    Layout.fillWidth: true
                    implicitHeight:
                        overviewContent.implicitHeight
                        + (root.theme.spaceMd * 2)

                    theme: root.theme
                    surfaceRole: "glass-raised"
                    fillEnabled: false
                    bordered: false

                    Components.JcHudFrame {
                        anchors.fill: parent
                        anchors.margins: root.theme.space2Xs

                        theme: root.theme
                        surfaceRole: "glass-raised"

                        fillEnabled: true
                        fillColor: root.theme.hudSurface
                        contentPadding: 0

                        cutSize: root.theme.spaceMd
                        accentLength: root.theme.controlHeightLarge

                        glowEnabled: false
                        showInnerFrame: true
                        showCornerAccents: true
                        showSecondaryAccent: false
                    }

                    GridLayout {
                        id: overviewContent

                        anchors.fill: parent
                        anchors.margins: root.theme.spaceMd

                        columns: 3
                        columnSpacing: root.theme.spaceLg

                        Components.JcMetricRing {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter

                            theme: root.theme
                            value: root.metricNumber(
                                root.performanceService
                                    ? root.performanceService
                                        .cpuUsagePercent
                                    : null
                            )
                            label: "CPU"
                            unit: "%"
                            status: root.utilizationStatus(
                                root.performanceService
                                    ? root.performanceService
                                        .cpuUsagePercent
                                    : null
                            )
                        }

                        Components.JcMetricRing {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter

                            theme: root.theme
                            value: root.metricNumber(
                                root.performanceService
                                    ? root.performanceService
                                        .memoryUsagePercent
                                    : null
                            )
                            label: "Memory"
                            unit: "%"
                            status: root.utilizationStatus(
                                root.performanceService
                                    ? root.performanceService
                                        .memoryUsagePercent
                                    : null
                            )
                        }

                        Components.JcMetricRing {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter

                            theme: root.theme
                            value: root.metricNumber(
                                root.performanceService
                                    ? root.performanceService
                                        .gpuBusyPercent
                                    : null
                            )
                            label: "GPU"
                            unit: "%"
                            status:
                                root.performanceService
                                && root.performanceService.gpuAvailable
                                    ? root.utilizationStatus(
                                        root.performanceService
                                            .gpuBusyPercent
                                    )
                                    : "info"
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true

                    columns: 2
                    columnSpacing: root.theme.spaceMd
                    rowSpacing: root.theme.spaceMd

                    Repeater {
                        model: 4

                        delegate: Components.JcSurface {
                            id: detailCard

                            required property int index

                            readonly property string section:
                                root.detailSection(detailCard.index)

                            Layout.fillWidth: true
                            Layout.minimumWidth:
                                root.theme.controlHeightLarge * 5

                            implicitHeight:
                                detailColumn.implicitHeight
                                + (root.theme.spaceMd * 2)

                            theme: root.theme
                            surfaceRole: "glass"
                            fillEnabled: false
                            bordered: false

                            Components.JcHudFrame {
                                id: detailCardHudFrame

                                anchors.fill: parent
                                anchors.margins: root.theme.space2Xs

                                theme: root.theme
                                surfaceRole: "glass"

                                fillEnabled: true
                                fillColor: root.theme.hudSurface
                                contentPadding: 0

                                cutSize: root.theme.spaceMd
                                accentLength:
                                    root.theme.controlHeightDefault
                                    + root.theme.spaceMd

                                glowEnabled: false
                                showInnerFrame: true
                                showCornerAccents: true
                                showSecondaryAccent: false
                            }

                            ColumnLayout {
                                id: detailColumn

                                anchors.fill: parent
                                anchors.margins: root.theme.spaceMd
                                spacing: root.theme.spaceSm

                                Components.JcSectionHeader {
                                    Layout.fillWidth: true

                                    theme: root.theme
                                    title: root.detailTitle(
                                        detailCard.section
                                    )
                                    subtitle: root.detailSubtitle(
                                        detailCard.section
                                    )
                                }

                                Components.JcDivider {
                                    Layout.fillWidth: true
                                    theme: root.theme
                                }

                                Repeater {
                                    model: root.detailRowCount(
                                        detailCard.section
                                    )

                                    delegate: RowLayout {
                                        required property int index

                                        readonly property var rowData:
                                            root.detailRow(
                                                detailCard.section,
                                                index
                                            )

                                        Layout.fillWidth: true
                                        spacing: root.theme.spaceMd

                                        Text {
                                            Layout.fillWidth: true

                                            text: rowData
                                                ? String(rowData.label)
                                                : ""
                                            color:
                                                root.theme.textSecondary

                                            font.family:
                                                root.theme.fontFamilySans
                                            font.pixelSize:
                                                root.theme.textSizeCaption
                                        }

                                        Text {
                                            text: rowData
                                                ? String(rowData.value)
                                                : ""
                                            color: root.statusColor(
                                                rowData
                                                    ? rowData.status
                                                    : "info",
                                                rowData
                                                    ? rowData.available
                                                        !== false
                                                    : false
                                            )

                                            font.family:
                                                root.theme.fontFamilyMono
                                            font.pixelSize:
                                                root.theme.textSizeBody
                                            font.weight:
                                                root.theme.fontWeightMedium
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Components.JcSurface {
                    Layout.fillWidth: true
                    implicitHeight:
                        footerText.implicitHeight
                        + (root.theme.spaceSm * 2)

                    theme: root.theme
                    surfaceRole: "glass"
                    fillEnabled: false
                    bordered: false

                    Components.JcHudFrame {
                        id: performanceFooterHudFrame

                        anchors.fill: parent
                        anchors.margins: root.theme.space2Xs

                        theme: root.theme
                        surfaceRole: "glass"

                        fillEnabled: true
                        fillColor: root.theme.hudSurface
                        contentPadding: 0

                        cutSize: root.theme.spaceSm
                        accentLength: root.theme.controlHeightDefault

                        glowEnabled: false
                        showInnerFrame: true
                        showCornerAccents: false
                        showSecondaryAccent: false
                    }

                    Text {
                        id: footerText

                        anchors.fill: parent
                        anchors.margins: root.theme.spaceSm

                        text: root.footerStatusText
                        color: root.theme.textMuted

                        layer.enabled: true
                        layer.smooth: true

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeCaption

                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
