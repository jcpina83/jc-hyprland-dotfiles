import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property bool controlEnabled: true

    property bool enabledValue: false
    property string modeValue: "next"
    property string targetValue: "both"
    property string intervalValue: "30m"

    property bool draftDirty: false

    property bool observedReady: false
    property bool observedEnabled: false
    property string observedMode: ""
    property string observedTarget: ""
    property string observedInterval: ""

    property bool runtimeSynchronized: false

    signal enabledSelected(bool value)
    signal modeSelected(string value)
    signal targetSelected(string value)
    signal intervalSelected(string value)

    readonly property var modeOptions: [
        {
            value: "next",
            label: "Next",
            iconName: "refresh"
        },
        {
            value: "random",
            label: "Random",
            iconName: "all"
        }
    ]

    readonly property var targetOptions: [
        {
            value: "main",
            label: "MAIN",
            iconName: "display"
        },
        {
            value: "secondary",
            label: "SECONDARY",
            iconName: "display"
        },
        {
            value: "both",
            label: "BOTH",
            iconName: "all"
        }
    ]

    readonly property var intervalOptions: {
        const base = [
            { value: "5m", label: "5m" },
            { value: "15m", label: "15m" },
            { value: "30m", label: "30m" },
            { value: "1h", label: "1h" }
        ];

        const current = String(root.intervalValue || "").trim();

        if (current.length === 0)
            return base;

        for (let i = 0; i < base.length; ++i) {
            if (String(base[i].value) === current)
                return base;
        }

        return base.concat([
            {
                value: current,
                label: current
            }
        ]);
    }

    function parseIntervalMinutes(value) {
        const source = String(value || "").trim().toLowerCase();
        const match = /^([0-9]+)(m|h)$/.exec(source);

        if (!match)
            return -1;

        const amount = Number(match[1]);

        if (!Number.isFinite(amount) || amount <= 0)
            return -1;

        return match[2] === "h"
            ? amount * 60
            : amount;
    }

    function intervalFromMinutes(minutes) {
        const normalized = Math.max(
            5,
            Math.min(
                60,
                Math.round(Number(minutes) / 5) * 5
            )
        );

        return normalized === 60
            ? "1h"
            : String(normalized) + "m";
    }

    readonly property real intervalSliderValue: {
        const minutes = root.parseIntervalMinutes(root.intervalValue);

        if (minutes < 5)
            return 5;

        if (minutes > 60)
            return 60;

        return minutes;
    }

    readonly property bool intervalIsPreset:
        ["5m", "15m", "30m", "1h"].indexOf(
            String(root.intervalValue || "").trim()
        ) >= 0

    readonly property string observedSummary: {
        if (!root.observedReady)
            return "Observed state not ready";

        return "Observed "
            + (root.observedEnabled ? "ON" : "OFF")
            + " · "
            + (root.observedMode.length > 0
                ? root.observedMode
                : "unknown")
            + " · "
            + (root.observedTarget.length > 0
                ? root.observedTarget
                : "unknown")
            + " · "
            + (root.observedInterval.length > 0
                ? root.observedInterval
                : "unknown");
    }

    implicitHeight:
        root.theme.controlHeightLarge * 3.70

    opacity:
        root.controlEnabled
            ? root.theme.opacityEnabled
            : root.theme.opacityDisabled

    Components.JcHudFrame {
        id: rotationHudFrame

        anchors.fill: parent
        anchors.margins: root.theme.space2Xs

        theme: root.theme
        surfaceRole: "glass"

        fillEnabled: true
        fillColor: root.theme.hudSurface
        contentPadding: 0

        cutSize: root.theme.spaceMd
        accentLength: root.theme.controlHeightLarge

        glowEnabled: false
        showInnerFrame: true
        showCornerAccents: true
        showSecondaryAccent: root.draftDirty

        secondaryAccentColor:
            root.draftDirty
                ? root.theme.warning
                : root.theme.hudSecondaryAccent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.theme.spaceMd

        spacing: root.theme.spaceXs

        RowLayout {
            Layout.fillWidth: true

            spacing: root.theme.spaceSm

            ColumnLayout {
                Layout.fillWidth: true

                spacing: root.theme.space2Xs

                Text {
                    Layout.fillWidth: true

                    text: "Automatic rotation"
                    color: root.theme.textPrimary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeSection
                    font.weight: root.theme.fontWeightSemibold
                }

                Text {
                    Layout.fillWidth: true

                    text: root.observedSummary
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightRegular

                    elide: Text.ElideRight
                }
            }

            Components.JcChip {
                visible: root.draftDirty

                theme: root.theme
                text: "Draft"

                compact: true
                checked: true
                controlEnabled: false
            }

            Components.JcChip {
                theme: root.theme

                text:
                    root.runtimeSynchronized
                        ? "Runtime synced"
                        : "Runtime check"

                compact: true
                checked: root.runtimeSynchronized
                controlEnabled: false
            }

            Components.JcToggle {
                theme: root.theme

                text: "Enabled"
                checked: root.enabledValue
                controlEnabled: root.controlEnabled

                onToggled: value =>
                    root.enabledSelected(value)
            }
        }

        Components.JcDivider {
            Layout.fillWidth: true

            theme: root.theme
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.bottomMargin: root.theme.spaceSm

            spacing: root.theme.spaceMd

            ColumnLayout {
                Layout.preferredWidth:
                    root.theme.controlHeightLarge * 3.15

                spacing: root.theme.space2Xs

                Text {
                    text: "Mode"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: root.theme.spaceXs

                    Repeater {
                        model: root.modeOptions

                        delegate: Components.JcSettingTile {
                            required property var modelData

                            Layout.fillWidth: true

                            theme: root.theme

                            text: String(modelData.label || "")
                            iconName: String(modelData.iconName || "")

                            selected:
                                String(root.modeValue || "")
                                === String(modelData.value || "")

                            controlEnabled: root.controlEnabled
                            compact: true

                            onClicked:
                                root.modeSelected(
                                    String(modelData.value || "")
                                )
                        }
                    }
                }
            }

            Components.JcDivider {
                Layout.fillHeight: true

                theme: root.theme
                orientation: Qt.Vertical
            }

            ColumnLayout {
                Layout.preferredWidth:
                    root.theme.controlHeightLarge * 5.25

                spacing: root.theme.space2Xs

                Text {
                    text: "Target"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                RowLayout {
                    Layout.fillWidth: true

                    spacing: root.theme.spaceXs

                    Repeater {
                        model: root.targetOptions

                        delegate: Components.JcSettingTile {
                            required property var modelData

                            Layout.fillWidth: true

                            theme: root.theme

                            text: String(modelData.label || "")
                            iconName: String(modelData.iconName || "")

                            selected:
                                String(root.targetValue || "")
                                === String(modelData.value || "")

                            controlEnabled: root.controlEnabled
                            compact: true

                            onClicked:
                                root.targetSelected(
                                    String(modelData.value || "")
                                )
                        }
                    }
                }
            }

            Components.JcDivider {
                Layout.fillHeight: true

                theme: root.theme
                orientation: Qt.Vertical
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth:
                    root.theme.controlHeightLarge * 5.5

                spacing: root.theme.space2Xs

                RowLayout {
                    Layout.fillWidth: true

                    spacing: root.theme.spaceXs

                    Text {
                        text: "Interval"
                        color: root.theme.textSecondary

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeCaption
                        font.weight: root.theme.fontWeightMedium
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Text {
                        text:
                            String(root.intervalValue || "").length > 0
                                ? root.intervalValue
                                    + (
                                        root.intervalIsPreset
                                            ? ""
                                            : " · custom"
                                    )
                                : "—"

                        color: root.theme.accent

                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeCaption
                        font.weight: root.theme.fontWeightSemibold
                    }
                }

                Components.JcSlider {
                    id: intervalSlider

                    Layout.fillWidth: true

                    theme: root.theme
                    controlEnabled: root.controlEnabled

                    from: 5
                    to: 60
                    stepSize: 5
                    value: root.intervalSliderValue

                    onMoved:
                        root.intervalSelected(
                            root.intervalFromMinutes(value)
                        )
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight:
                        root.theme.textSizeCaption
                        + root.theme.space2Xs

                    Repeater {
                        model: root.intervalOptions.slice(0, 4)

                        delegate: Text {
                            required property var modelData

                            readonly property real markerMinutes:
                                root.parseIntervalMinutes(
                                    String(modelData.value || "")
                                )

                            readonly property real markerPosition:
                                Math.max(
                                    0,
                                    Math.min(
                                        1,
                                        (markerMinutes - 5) / 55
                                    )
                                )

                            text: String(modelData.label || "")

                            color:
                                String(root.intervalValue || "")
                                    === String(modelData.value || "")
                                    ? root.theme.accent
                                    : root.theme.textSecondary

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeCaption

                            font.weight:
                                String(root.intervalValue || "")
                                    === String(modelData.value || "")
                                    ? root.theme.fontWeightSemibold
                                    : root.theme.fontWeightMedium

                            x:
                                Math.max(
                                    0,
                                    Math.min(
                                        parent.width - width,
                                        (markerPosition * parent.width)
                                            - (width / 2)
                                    )
                                )
                        }
                    }
                }
            }
        }
    }
}
