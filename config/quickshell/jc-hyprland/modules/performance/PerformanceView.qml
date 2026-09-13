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
                    )
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
                    value: root.formatBytes(service.memoryUsedBytes)
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
                    )
                },
                {
                    label: "Edge / Junction",
                    value: root.formatTemperature(
                        service.gpuEdgeTemperatureCelsius
                    ) + " / "
                        + root.formatTemperature(
                            service.gpuJunctionTemperatureCelsius
                        )
                },
                {
                    label: "Memory temp",
                    value: root.formatTemperature(
                        service.gpuMemoryTemperatureCelsius
                    )
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
                        )
                }
            ];
        }

        return [
            {
                label: "Root storage",
                value: root.formatUsagePair(
                    service.rootStorageUsedBytes,
                    service.rootStorageTotalBytes
                )
            },
            {
                label: "NVMe max",
                value: root.formatTemperature(
                    service.nvmeMaxTemperatureCelsius
                )
            },
            {
                label: "Load 1 / 5 / 15",
                value: Number(service.loadOneMinute || 0).toFixed(2)
                    + " / "
                    + Number(service.loadFiveMinutes || 0).toFixed(2)
                    + " / "
                    + Number(service.loadFifteenMinutes || 0).toFixed(2)
            },
            {
                label: "Uptime",
                value: root.formatDuration(service.uptimeSeconds)
            }
        ];
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

                    const refreshed =
                        String(root.performanceService.lastRefresh || "");

                    return refreshed.length > 0
                        ? state + " · Updated " + refreshed
                        : state + " · Observed system telemetry";
                }
            }

            Components.JcButton {
                theme: root.theme
                iconName: "refresh"

                text: root.serviceLoading
                    ? "Refreshing…"
                    : "Refresh"

                controlEnabled:
                    root.performanceService
                    && !root.serviceLoading

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
                        model: [
                            {
                                title: "CPU",
                                subtitle:
                                    root.performanceService
                                        ? root.textOrUnavailable(
                                            root.performanceService.cpuModel
                                        )
                                        : "Observed processor telemetry",
                                rows: root.detailRows("cpu")
                            },
                            {
                                title: "Memory",
                                subtitle: "RAM and swap",
                                rows: root.detailRows("memory")
                            },
                            {
                                title: "GPU",
                                subtitle:
                                    root.performanceService
                                    && root.performanceService.gpuAvailable
                                        ? "AMDGPU · "
                                            + root.textOrUnavailable(
                                                root.performanceService.gpuPci
                                            )
                                        : "GPU telemetry unavailable",
                                rows: root.detailRows("gpu")
                            },
                            {
                                title: "System",
                                subtitle:
                                    root.performanceService
                                        ? root.textOrUnavailable(
                                            root.performanceService
                                                .rootStorageFilesystem
                                        ) + " · "
                                            + root.textOrUnavailable(
                                                root.performanceService
                                                    .rootStorageMountPoint
                                            )
                                        : "Observed system telemetry",
                                rows: root.detailRows("system")
                            }
                        ]

                        delegate: Components.JcSurface {
                            id: detailCard

                            required property var modelData

                            Layout.fillWidth: true
                            Layout.minimumWidth:
                                root.theme.controlHeightLarge * 5

                            implicitHeight:
                                detailColumn.implicitHeight
                                + (root.theme.spaceMd * 2)

                            theme: root.theme
                            surfaceRole: "glass"

                            ColumnLayout {
                                id: detailColumn

                                anchors.fill: parent
                                anchors.margins: root.theme.spaceMd
                                spacing: root.theme.spaceSm

                                Components.JcSectionHeader {
                                    Layout.fillWidth: true

                                    theme: root.theme
                                    title: String(detailCard.modelData.title)
                                    subtitle:
                                        String(
                                            detailCard.modelData.subtitle
                                            || ""
                                        )
                                }

                                Components.JcDivider {
                                    Layout.fillWidth: true
                                    theme: root.theme
                                }

                                Repeater {
                                    model: detailCard.modelData.rows || []

                                    delegate: RowLayout {
                                        required property var modelData

                                        Layout.fillWidth: true
                                        spacing: root.theme.spaceMd

                                        Text {
                                            Layout.fillWidth: true

                                            text:
                                                String(modelData.label)
                                            color:
                                                root.theme.textSecondary

                                            font.family:
                                                root.theme.fontFamilySans
                                            font.pixelSize:
                                                root.theme.textSizeCaption
                                        }

                                        Text {
                                            text:
                                                String(modelData.value)
                                            color:
                                                root.theme.textPrimary

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
                    surfaceRole: "sunken"

                    Text {
                        id: footerText

                        anchors.fill: parent
                        anchors.margins: root.theme.spaceSm

                        text:
                            "Read-only observed telemetry · "
                            + "Live refresh every "
                            + (
                                root.performanceService
                                    ? root.performanceService
                                        .refreshIntervalMs / 1000
                                    : 2
                            )
                            + "s while Performance is visible."

                        color: root.theme.textMuted

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
