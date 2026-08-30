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
        { value: "next", label: "Next" },
        { value: "random", label: "Random" }
    ]

    readonly property var targetOptions: [
        { value: "main", label: "Main" },
        { value: "secondary", label: "Secondary" },
        { value: "both", label: "Both" }
    ]

    readonly property var intervalOptions: {
        const values = [
            { value: "5m", label: "5m" },
            { value: "15m", label: "15m" },
            { value: "30m", label: "30m" },
            { value: "1h", label: "1h" }
        ];

        const current = String(root.intervalValue || "").trim();

        if (current.length === 0)
            return values;

        for (let i = 0; i < values.length; ++i) {
            if (String(values[i].value) === current)
                return values;
        }

        values.push({
            value: current,
            label: current
        });

        return values;
    }

    readonly property string observedSummary: {
        if (!root.observedReady)
            return "Observed rotation state not ready";

        const enabledText =
            root.observedEnabled ? "ON" : "OFF";

        const modeText =
            root.observedMode.length > 0
                ? root.observedMode
                : "mode unknown";

        const targetText =
            root.observedTarget.length > 0
                ? root.observedTarget
                : "target unknown";

        const intervalText =
            root.observedInterval.length > 0
                ? root.observedInterval
                : "interval unknown";

        return "Observed "
            + enabledText
            + " · "
            + modeText
            + " · "
            + targetText
            + " · "
            + intervalText;
    }

    implicitHeight:
        rotationContent.implicitHeight
        + (root.theme.spaceMd * 2)

    Components.JcHudFrame {
        anchors.fill: parent

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
    }

    ColumnLayout {
        id: rotationContent

        anchors.fill: parent
        anchors.margins: root.theme.spaceMd

        spacing: root.theme.spaceSm

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceSm

            Components.JcSectionHeader {
                Layout.fillWidth: true

                theme: root.theme
                title: "Automatic rotation"
                subtitle: root.observedSummary
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

                onToggled: value => root.enabledSelected(value)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceLg

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 0.85
                spacing: root.theme.space2Xs

                Text {
                    text: "Mode"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                Components.JcChoiceGroup {
                    Layout.fillWidth: true

                    theme: root.theme
                    options: root.modeOptions
                    selectedValue: root.modeValue
                    controlEnabled: root.controlEnabled
                    optionSpacing: root.theme.spaceXs

                    onValueSelected: value =>
                        root.modeSelected(value)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1.15
                spacing: root.theme.space2Xs

                Text {
                    text: "Target"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                Components.JcChoiceGroup {
                    Layout.fillWidth: true

                    theme: root.theme
                    options: root.targetOptions
                    selectedValue: root.targetValue
                    controlEnabled: root.controlEnabled
                    optionSpacing: root.theme.spaceXs

                    onValueSelected: value =>
                        root.targetSelected(value)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1.25
                spacing: root.theme.space2Xs

                Text {
                    text: "Interval"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                Components.JcChoiceGroup {
                    Layout.fillWidth: true

                    theme: root.theme
                    options: root.intervalOptions
                    selectedValue: root.intervalValue
                    controlEnabled: root.controlEnabled
                    optionSpacing: root.theme.spaceXs

                    onValueSelected: value =>
                        root.intervalSelected(value)
                }
            }
        }
    }
}
