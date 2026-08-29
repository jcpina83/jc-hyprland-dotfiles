import QtQuick
import QtQuick.Layouts

import qs.components as Components

Components.JcSurface {
    id: root

    surfaceRole: "glass"
    bordered: false
    fillEnabled: false
    cornerRadius: root.theme.radiusMd

    property var monitor
    property var draftStore
    property bool editorEnabled: true
    property string outputRole: ""

    readonly property var draft:
        root.monitor && root.draftStore
            ? root.draftStore.draftFor(root.monitor.output)
            : null

    readonly property string disableReason:
        root.monitor && root.draftStore
            ? root.draftStore.enableDisableReason(root.monitor.output)
            : ""

    readonly property var resolutionOptions:
        root.monitor && root.draftStore
            ? root.draftStore.resolutionOptionsFor(root.monitor.output)
            : []

    readonly property var refreshOptions:
        root.monitor && root.draftStore
            ? root.draftStore.refreshOptionsFor(root.monitor.output)
            : []

    readonly property var scaleOptions:
        root.monitor && root.draftStore
            ? root.draftStore.scaleOptionsFor(root.monitor.output)
            : []

    readonly property var transformOptions:
        root.monitor && root.draftStore
            ? root.draftStore.transformOptionsFor(root.monitor.output)
            : []

    readonly property real controlStripMinColumnWidth:
        root.theme.controlHeightLarge * 2.4

    readonly property int controlStripColumns: {
        const availableWidth = Math.max(
            0,
            root.width - (root.theme.spaceMd * 2)
        );

        const twoColumns =
            (root.controlStripMinColumnWidth * 2)
            + root.theme.spaceMd;

        const threeColumns =
            (root.controlStripMinColumnWidth * 3)
            + (root.theme.spaceMd * 2);

        if (availableWidth >= threeColumns)
            return 3;

        if (availableWidth >= twoColumns)
            return 2;

        return 1;
    }

    function scaleIndexForValue(scaleValue) {
        const target = String(scaleValue);

        for (let i = 0; i < root.scaleOptions.length; ++i) {
            const option = root.scaleOptions[i];

            if (option && String(option.value) === target)
                return i;
        }

        return 0;
    }

    implicitHeight: content.implicitHeight + (root.theme.spaceMd * 2)

    Components.JcHudFrame {
        id: displayCardHudFrame

        anchors.fill: parent
        anchors.margins: root.theme.space2Xs

        theme: root.theme
        surfaceRole: "glass"

        fillEnabled: true
        fillColor: root.theme.hudSurface
        contentPadding: 0

        cutSize: root.theme.spaceSm
        accentLength: root.theme.controlHeightDefault

        focused:
            root.monitor
            && root.monitor.focused

        glowEnabled: false
        showInnerFrame: true
        showCornerAccents: true

        showSecondaryAccent:
            root.draft
            && root.draft.dirty
    }

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: root.theme.spaceMd
        spacing: root.theme.spaceSm

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceSm

            Rectangle {
                width: root.theme.spaceSm
                height: root.theme.spaceSm
                radius: root.theme.radiusPill

                color: root.monitor && root.monitor.focused
                    ? root.theme.accent
                    : root.theme.textSecondary
            }

            Text {
                Layout.fillWidth: true

                text: root.monitor && root.monitor.output.length > 0
                    ? root.monitor.output
                        + (root.outputRole.length > 0
                            ? " · " + root.outputRole
                            : "")
                    : "Unknown output"

                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBodyLarge
                font.weight: root.theme.fontWeightSemibold
                elide: Text.ElideRight
            }

            Text {
                text: {
                    if (!root.draft)
                        return root.monitor && root.monitor.disabled
                            ? "Disabled"
                            : "Active";

                    if (root.draft.enabled)
                        return root.monitor && root.monitor.disabled
                            ? "Enable pending"
                            : "Active";

                    return root.monitor && root.monitor.disabled
                        ? "Disabled"
                        : "Disable pending";
                }

                color: root.draft && !root.draft.enabled
                    ? (root.theme.warning)
                    : (root.theme.success)

                font.pixelSize: root.theme.textSizeBody
                font.weight: root.draft && root.draft.dirty
                    ? root.theme.fontWeightSemibold
                    : root.theme.fontWeightMedium
            }
        }

        Text {
            Layout.fillWidth: true

            text: {
                if (!root.monitor)
                    return "";

                if (root.monitor.description.length > 0)
                    return root.monitor.description;

                return [root.monitor.make, root.monitor.model]
                    .filter(function(value) {
                        return value.length > 0;
                    })
                    .join(" ");
            }

            color: root.theme.textSecondary
            font.pixelSize: root.theme.textSizeBody
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: root.theme.spaceLg
            rowSpacing: root.theme.spaceXs

            Text {
                text: "Current mode"
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: root.monitor
                    ? root.monitor.width + "×" + root.monitor.height
                        + " @ " + root.monitor.refreshRate.toFixed(2) + " Hz"
                    : "—"

                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: "Scale"
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: root.monitor ? root.monitor.scale.toFixed(2) : "—"
                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: "Orientation"
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: root.monitor && root.draftStore
                    ? root.draftStore.transformLabel(root.monitor.transform)
                    : "—"

                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: "Logical size"
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: root.monitor
                    ? Math.round(root.monitor.logicalWidth)
                        + "×" + Math.round(root.monitor.logicalHeight)
                    : "—"

                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: "Position"
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: root.monitor
                    ? root.monitor.x + " × " + root.monitor.y
                    : "—"

                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: "Available modes"
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeBody
            }

            Text {
                text: root.monitor && root.monitor.availableModes
                    ? String(root.monitor.availableModes.length)
                    : "0"

                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBody
            }
        }

        Components.JcDivider {
            Layout.fillWidth: true
            theme: root.theme
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true

                text: "Draft settings"
                color: root.theme.textPrimary
                font.pixelSize: root.theme.textSizeBodyLarge
                font.weight: root.theme.fontWeightSemibold
            }

            Text {
                text: root.draft && root.draft.dirty
                    ? "Modified"
                    : "Matches current"

                color: root.draft && root.draft.dirty
                    ? (root.theme.warning)
                    : (root.theme.success)

                font.pixelSize: root.theme.textSizeCaption
                font.weight: root.theme.fontWeightSemibold
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceSm

            Text {
                Layout.fillWidth: true

                text: root.draft && root.draft.enabled
                    ? "Display is enabled in the draft."
                    : "Display is disabled in the draft."

                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeCaption
            }

            Item {
                implicitWidth: disableButton.implicitWidth
                implicitHeight: disableButton.implicitHeight

                Layout.alignment: Qt.AlignVCenter

                Components.JcButton {
                    id: disableButton

                    theme: root.theme
                    compact: true
                    iconName: "power"

                    text: root.draft && root.draft.enabled
                        ? "Disable"
                        : "Enable"

                    controlEnabled: {
                        if (!root.editorEnabled || !root.draftStore || !root.draft)
                            return false;

                        if (!root.draft.enabled)
                            return true;

                        return root.draftStore.canDisable(root.monitor.output);
                    }

                    onClicked: {
                        if (!root.monitor || !root.draftStore || !root.draft)
                            return;

                        root.draftStore.setEnabled(
                            root.monitor.output,
                            !root.draft.enabled
                        );
                    }
                }
                MouseArea {
                    id: disableReasonHover

                    anchors.fill: parent

                    enabled:
                        root.draft
                        && root.draft.enabled
                        && root.disableReason.length > 0

                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                Components.JcTooltip {
                    theme: root.theme

                    controlEnabled: disableReasonHover.enabled
                    visible: disableReasonHover.containsMouse
                    text: root.disableReason
                }
            }
        }


        GridLayout {
            id: displayControlStrip

            Layout.fillWidth: true

            columns: root.controlStripColumns
            columnSpacing: root.theme.spaceMd
            rowSpacing: root.theme.spaceSm

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    Layout.fillWidth: true

                    text: "Resolution"
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                    elide: Text.ElideRight
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    options: root.resolutionOptions
                    selectedValue: root.draft ? root.draft.resolutionKey : ""
                    placeholder: root.draft && !root.draft.enabled
                        ? "Display disabled"
                        : "Select resolution"

                    controlEnabled:
                        root.editorEnabled
                        && root.draft
                        && root.draft.enabled

                    onValueSelected: value => {
                        if (root.monitor && root.draftStore) {
                            root.draftStore.setResolution(root.monitor.output, value);
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    Layout.fillWidth: true

                    text: "Refresh rate"
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                    elide: Text.ElideRight
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    options: root.refreshOptions
                    selectedValue: root.draft ? root.draft.modeRaw : ""
                    placeholder: root.draft && !root.draft.enabled
                        ? "Display disabled"
                        : "Select refresh rate"

                    controlEnabled:
                        root.editorEnabled
                        && root.draft
                        && root.draft.enabled

                    onValueSelected: value => {
                        if (root.monitor && root.draftStore) {
                            root.draftStore.setRefreshMode(root.monitor.output, value);
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    Layout.fillWidth: true

                    text: "Orientation"
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightMedium
                    elide: Text.ElideRight
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    options: root.transformOptions
                    selectedValue: root.draft ? String(root.draft.transform) : ""
                    placeholder: root.draft && !root.draft.enabled
                        ? "Display disabled"
                        : "Select orientation"

                    controlEnabled:
                        root.editorEnabled
                        && root.draft
                        && root.draft.enabled

                    onValueSelected: value => {
                        if (root.monitor && root.draftStore) {
                            root.draftStore.setTransform(root.monitor.output, value);
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceSm

            Text {
                Layout.fillWidth: true

                text: "Scale"
                color: root.theme.textSecondary
                font.pixelSize: root.theme.textSizeCaption
                font.weight: root.theme.fontWeightMedium
            }

            Text {
                Layout.minimumWidth: root.theme.controlHeightLarge

                text: {
                    if (root.scaleOptions.length === 0)
                        return "—";

                    const optionIndex = Math.max(
                        0,
                        Math.min(
                            root.scaleOptions.length - 1,
                            Math.round(scaleSlider.value)
                        )
                    );

                    const option = root.scaleOptions[optionIndex];

                    return option ? String(option.label) : "—";
                }

                color: root.theme.textPrimary
                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightSemibold
                horizontalAlignment: Text.AlignRight
            }
        }

        Components.JcSlider {
            id: scaleSlider

            Layout.fillWidth: true

            theme: root.theme

            from: 0
            to: Math.max(0, root.scaleOptions.length - 1)
            stepSize: 1

            value: root.draft
                ? root.scaleIndexForValue(root.draft.scale)
                : 0

            controlEnabled:
                root.editorEnabled
                && root.draft
                && root.draft.enabled
                && root.scaleOptions.length > 0

            onMoved: {
                const optionIndex = Math.round(value);

                if (optionIndex < 0
                        || optionIndex >= root.scaleOptions.length) {
                    return;
                }

                const option = root.scaleOptions[optionIndex];

                if (root.monitor && root.draftStore && option) {
                    root.draftStore.setScale(
                        root.monitor.output,
                        String(option.value)
                    );
                }
            }
        }


    }
}
