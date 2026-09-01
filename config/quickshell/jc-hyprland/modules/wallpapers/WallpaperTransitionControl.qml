import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property bool controlEnabled: true
    property bool draftDirty: false
    property bool fpsDirty: false

    property string presetValue: "theme"
    property var typeOverrideValue: null
    property var durationOverrideValue: null
    property var fpsOverrideValue: null

    property bool observedReady: false
    property string observedPreset: ""
    property string observedResolvedPreset: ""
    property string observedEffectiveType: ""
    property real observedEffectiveDuration: 0
    property int observedEffectiveFps: 0

    property bool advancedExpanded: false

    readonly property string typeSelectedValue:
        root.typeOverrideValue === null
            || root.typeOverrideValue === undefined
            ? "inherit"
            : String(root.typeOverrideValue)

    readonly property string durationSelectedValue:
        root.optionalNumberString(root.durationOverrideValue)

    readonly property string fpsSelectedValue:
        root.optionalIntegerString(root.fpsOverrideValue)

    readonly property bool showAdvanced:
        root.advancedExpanded
        || root.fpsSelectedValue !== "inherit"
        || root.fpsDirty

    readonly property var presetOptions: [
        {
            "label": "Theme",
            "value": "theme"
        },
        {
            "label": "Default",
            "value": "default"
        },
        {
            "label": "Fade",
            "value": "fade"
        },
        {
            "label": "Cyber Noir",
            "value": "cyber-noir"
        },
        {
            "label": "Odyssey Glass",
            "value": "odyssey-glass"
        }
    ]

    readonly property var effectOptions: [
        {
            "label": "Inherit preset",
            "value": "inherit"
        },
        {
            "label": "None",
            "value": "none"
        },
        {
            "label": "Simple",
            "value": "simple"
        },
        {
            "label": "Fade",
            "value": "fade"
        },
        {
            "label": "Slide left",
            "value": "left"
        },
        {
            "label": "Slide right",
            "value": "right"
        },
        {
            "label": "Slide top",
            "value": "top"
        },
        {
            "label": "Slide bottom",
            "value": "bottom"
        },
        {
            "label": "Wipe",
            "value": "wipe"
        },
        {
            "label": "Wave",
            "value": "wave"
        },
        {
            "label": "Grow",
            "value": "grow"
        },
        {
            "label": "Center",
            "value": "center"
        },
        {
            "label": "Any",
            "value": "any"
        },
        {
            "label": "Outer",
            "value": "outer"
        },
        {
            "label": "Random",
            "value": "random"
        }
    ]

    readonly property var durationOptions:
        root.buildDurationOptions()

    readonly property var fpsOptions:
        root.buildFpsOptions()

    readonly property string observedSummary: {
        if (!root.observedReady)
            return "Observed transition state not ready";

        const configuredPreset =
            root.observedPreset.length > 0
                ? root.observedPreset
                : "unknown";

        const resolvedPreset =
            root.observedResolvedPreset.length > 0
                ? root.observedResolvedPreset
                : "unknown";

        const presetSummary =
            configuredPreset === resolvedPreset
                ? configuredPreset
                : configuredPreset + " → " + resolvedPreset;

        const effect =
            root.observedEffectiveType.length > 0
                ? root.observedEffectiveType
                : "unknown";

        const duration =
            root.observedEffectiveDuration > 0
                ? root.formatSeconds(root.observedEffectiveDuration) + " s"
                : "—";

        const fps =
            root.observedEffectiveFps > 0
                ? root.observedEffectiveFps + " FPS"
                : "—";

        return "Observed "
            + presetSummary
            + " · "
            + effect
            + " · "
            + duration
            + " · "
            + fps;
    }

    signal presetSelected(string value)
    signal typeSelected(string value)
    signal durationSelected(string value)
    signal fpsSelected(string value)

    function formatSeconds(value) {
        const number = Number(value);

        if (!isFinite(number))
            return "—";

        if (Math.abs(number - Math.round(number)) < 0.0001)
            return String(Math.round(number));

        return number.toFixed(2).replace(/0+$/, "").replace(/\.$/, "");
    }

    function optionalNumberString(value) {
        if (value === null || value === undefined)
            return "inherit";

        const number = Number(value);

        if (!isFinite(number) || number <= 0)
            return "inherit";

        return root.formatSeconds(number);
    }

    function optionalIntegerString(value) {
        if (value === null || value === undefined)
            return "inherit";

        const number = Number(value);

        if (!isFinite(number) || number <= 0)
            return "inherit";

        return String(Math.round(number));
    }

    function containsOption(options, value) {
        for (let index = 0; index < options.length; ++index) {
            if (String(options[index].value) === String(value))
                return true;
        }

        return false;
    }

    function buildDurationOptions() {
        const options = [
            {
                "label": "Inherit preset",
                "value": "inherit"
            },
            {
                "label": "0.4 s",
                "value": "0.4"
            },
            {
                "label": "0.6 s",
                "value": "0.6"
            },
            {
                "label": "0.8 s",
                "value": "0.8"
            },
            {
                "label": "1.0 s",
                "value": "1"
            },
            {
                "label": "1.2 s",
                "value": "1.2"
            },
            {
                "label": "1.6 s",
                "value": "1.6"
            },
            {
                "label": "1.8 s",
                "value": "1.8"
            },
            {
                "label": "2.0 s",
                "value": "2"
            }
        ];

        if (root.durationSelectedValue !== "inherit"
                && !root.containsOption(
                    options,
                    root.durationSelectedValue
                )) {
            options.push({
                "label":
                    root.durationSelectedValue + " s · custom",
                "value": root.durationSelectedValue
            });
        }

        return options;
    }

    function buildFpsOptions() {
        const options = [
            {
                "label": "Inherit preset",
                "value": "inherit"
            },
            {
                "label": "30 FPS",
                "value": "30"
            },
            {
                "label": "60 FPS",
                "value": "60"
            },
            {
                "label": "90 FPS",
                "value": "90"
            },
            {
                "label": "120 FPS",
                "value": "120"
            },
            {
                "label": "144 FPS",
                "value": "144"
            },
            {
                "label": "165 FPS",
                "value": "165"
            },
            {
                "label": "180 FPS",
                "value": "180"
            }
        ];

        if (root.fpsSelectedValue !== "inherit"
                && !root.containsOption(
                    options,
                    root.fpsSelectedValue
                )) {
            options.push({
                "label":
                    root.fpsSelectedValue + " FPS · custom",
                "value": root.fpsSelectedValue
            });
        }

        return options;
    }

    implicitHeight:
        transitionContent.implicitHeight
        + (root.theme.spaceMd * 2)

    opacity:
        root.controlEnabled
            ? root.theme.opacityEnabled
            : root.theme.opacityDisabled

    Components.JcHudFrame {
        id: transitionHudFrame

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
        id: transitionContent

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

                    text: "Wallpaper transition"
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
                text: "Advanced"
                iconName: "settings"
                compact: true

                checked: root.advancedExpanded
                controlEnabled: root.controlEnabled

                onClicked:
                    root.advancedExpanded = !root.advancedExpanded
            }
        }

        Components.JcDivider {
            Layout.fillWidth: true
            theme: root.theme
        }

        RowLayout {
            Layout.fillWidth: true

            spacing: root.theme.spaceMd

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    text: "Preset"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    controlEnabled: root.controlEnabled

                    options: root.presetOptions
                    selectedValue: root.presetValue

                    onValueSelected: value =>
                        root.presetSelected(value)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    text: "Effect"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    controlEnabled: root.controlEnabled

                    options: root.effectOptions
                    selectedValue: root.typeSelectedValue

                    onValueSelected: value =>
                        root.typeSelected(value)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    text: "Duration"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    controlEnabled: root.controlEnabled

                    options: root.durationOptions
                    selectedValue: root.durationSelectedValue

                    onValueSelected: value =>
                        root.durationSelected(value)
                }
            }
        }

        RowLayout {
            visible: root.showAdvanced
            Layout.fillWidth: true

            spacing: root.theme.spaceMd

            ColumnLayout {
                Layout.preferredWidth:
                    root.theme.controlHeightLarge * 4.6

                spacing: root.theme.space2Xs

                Text {
                    text: "Transition FPS"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    controlEnabled: root.controlEnabled

                    options: root.fpsOptions
                    selectedValue: root.fpsSelectedValue

                    onValueSelected: value =>
                        root.fpsSelected(value)
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom

                text:
                    "Advanced override. Inherit keeps FPS owned by "
                    + "the selected preset."

                color: root.theme.textSecondary

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeCaption
                font.weight: root.theme.fontWeightRegular

                wrapMode: Text.WordWrap
            }
        }
    }
}
