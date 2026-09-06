import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    required property var theme

    property var quickSettingsService
    property var actionService

    signal refreshRequested()
    signal dndRequested(bool enabled)
    signal nightLightRequested(bool enabled)

    readonly property bool interactionLocked:
        root.actionService
        && Boolean(root.actionService.busy)

    readonly property bool serviceReady:
        root.quickSettingsService
        && Boolean(root.quickSettingsService.ready)

    readonly property bool dndEnabled:
        root.serviceReady
        && Boolean(root.quickSettingsService.dndEnabled)

    readonly property bool dndControlEnabled:
        root.actionService
        && Boolean(root.actionService.canSetDnd)

    readonly property bool nightLightEnabled:
        root.serviceReady
        && root.quickSettingsService.nightLightEnabled === true

    readonly property bool nightLightControlEnabled:
        root.actionService
        && Boolean(root.actionService.canSetNightLight)

    readonly property string nightLightStateLabel: {
        if (!root.quickSettingsService)
            return "Service unavailable";

        if (root.quickSettingsService.loading)
            return "Refreshing…";

        if (!root.quickSettingsService.ready)
            return "Waiting…";

        if (!root.quickSettingsService.nightLightAvailable)
            return "Unavailable";

        if (!root.quickSettingsService.nightLightManaged)
            return "Detected · unmanaged";

        return root.nightLightEnabled
            ? "Enabled"
            : "Disabled";
    }

    readonly property string operationError: {
        if (root.actionService
                && root.actionService.errorMessage.length > 0) {
            return root.actionService.errorMessage;
        }

        if (root.quickSettingsService
                && root.quickSettingsService.errorMessage.length > 0) {
            return root.quickSettingsService.errorMessage;
        }

        return "";
    }

    readonly property string dndStateLabel: {
        if (!root.quickSettingsService)
            return "Service unavailable";

        if (root.quickSettingsService.loading)
            return "Refreshing observed state…";

        if (!root.quickSettingsService.ready)
            return "Waiting for observed state…";

        if (!root.quickSettingsService.dndAvailable)
            return "Unavailable";

        if (!root.quickSettingsService.dndBackendInstalled)
            return "Backend not installed";

        if (!root.quickSettingsService.dndRunning)
            return "Backend not running";

        return root.quickSettingsService.dndEnabled
            ? "Enabled"
            : "Disabled";
    }

    readonly property string capabilitySummary: {
        if (!root.quickSettingsService
                || !root.quickSettingsService.ready) {
            return "Waiting for capability discovery…";
        }

        const lockState =
            root.quickSettingsService.lockAvailable
                ? "Lock ready"
                : "Lock unavailable";

        const nightLightState =
            root.quickSettingsService.nightLightAvailable
                ? "Night Light ready"
                : "Night Light unavailable";

        const suspendState =
            root.quickSettingsService.suspendAvailable
                ? "Suspend ready"
                : "Suspend unavailable";

        return lockState
            + " · "
            + nightLightState
            + " · "
            + suspendState;
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
                title: "Quick Settings"

                subtitle: {
                    if (!root.quickSettingsService)
                        return "Observed-state service unavailable";

                    if (root.quickSettingsService.loading)
                        return "Refreshing desktop capabilities…";

                    if (!root.quickSettingsService.ready)
                        return "Waiting for observed desktop state…";

                    return "Immediate desktop controls backed by observed state";
                }
            }

            Components.JcButton {
                Layout.alignment: Qt.AlignVCenter

                theme: root.theme
                iconName: "refresh"

                text:
                    root.quickSettingsService
                    && root.quickSettingsService.loading
                        ? "Refreshing…"
                        : "Refresh"

                controlEnabled:
                    !root.interactionLocked
                    && root.quickSettingsService
                    && !root.quickSettingsService.loading

                onClicked: root.refreshRequested()
            }
        }

        Components.JcSurface {
            visible: root.operationError.length > 0

            Layout.fillWidth: true

            implicitHeight:
                quickSettingsErrorText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.dangerSurface
            border.color: root.theme.dangerBorder

            Text {
                id: quickSettingsErrorText

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
            id: quickSettingsFlickable

            Layout.fillWidth: true
            Layout.fillHeight: true

            clip: true

            contentWidth: width
            contentHeight: quickSettingsColumn.implicitHeight

            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            pixelAligned: true

            ColumnLayout {
                id: quickSettingsColumn

                width: quickSettingsFlickable.width
                spacing: root.theme.spaceMd

                Components.JcSurface {
                    Layout.fillWidth: true

                    implicitHeight:
                        Math.max(
                            dndContent.implicitHeight,
                            root.theme.controlHeightLarge * 1.70
                        )
                        + (root.theme.spaceMd * 2)

                    theme: root.theme
                    surfaceRole: "glass-raised"
                    fillEnabled: false
                    bordered: false

                    Components.JcHudFrame {
                        id: dndHudFrame

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

                    RowLayout {
                        id: dndContent

                        anchors.fill: parent
                        anchors.margins: root.theme.spaceMd

                        spacing: root.theme.spaceLg

                        Components.JcSettingTile {
                            Layout.alignment: Qt.AlignVCenter

                            theme: root.theme
                            text: "DND"
                            iconName: "notifications"
                            compact: true

                            selected: root.dndEnabled
                            controlEnabled: root.dndControlEnabled

                            onClicked:
                                root.dndRequested(!root.dndEnabled)
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            spacing: root.theme.space2Xs

                            Text {
                                Layout.fillWidth: true

                                text: "Do Not Disturb"
                                color: root.theme.textPrimary

                                font.family: root.theme.fontFamilySans
                                font.pixelSize: root.theme.textSizeBodyLarge
                                font.weight: root.theme.fontWeightSemibold
                            }

                            Text {
                                Layout.fillWidth: true

                                text: root.dndStateLabel
                                color:
                                    root.dndEnabled
                                        ? root.theme.success
                                        : root.theme.textSecondary

                                font.family: root.theme.fontFamilySans
                                font.pixelSize: root.theme.textSizeBody
                                font.weight: root.theme.fontWeightMedium

                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true

                                text:
                                    root.actionService
                                    && root.actionService.busy
                                        ? root.actionService.statusMessage
                                        : "Suppress non-critical desktop "
                                            + "notifications immediately."

                                color: root.theme.textMuted

                                font.family: root.theme.fontFamilySans
                                font.pixelSize: root.theme.textSizeCaption
                                font.weight: root.theme.fontWeightRegular

                                wrapMode: Text.WordWrap
                            }
                        }

                        Components.JcToggle {
                            Layout.alignment: Qt.AlignVCenter

                            theme: root.theme
                            text: root.dndEnabled ? "On" : "Off"

                            checked: root.dndEnabled
                            controlEnabled: root.dndControlEnabled

                            onToggled: value =>
                                root.dndRequested(value)
                        }
                    }
                }

                Components.JcSurface {
                    Layout.fillWidth: true

                    implicitHeight:
                        capabilityColumn.implicitHeight
                        + (root.theme.spaceMd * 2)

                    theme: root.theme
                    surfaceRole: "glass"
                    fillEnabled: false
                    bordered: false

                    Components.JcHudFrame {
                        id: capabilityHudFrame

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
                        showSecondaryAccent: false
                    }

                    ColumnLayout {
                        id: capabilityColumn

                        anchors.fill: parent
                        anchors.margins: root.theme.spaceMd

                        spacing: root.theme.spaceSm

                        Components.JcSectionHeader {
                            Layout.fillWidth: true

                            theme: root.theme
                            title: "Observed capabilities"
                            subtitle:
                                "Read-only discovery for upcoming "
                                + "Quick Settings controls"
                        }

                        Components.JcDivider {
                            Layout.fillWidth: true
                            theme: root.theme
                        }

                        RowLayout {
                            id: capabilityTiles

                            Layout.fillWidth: true
                            spacing: root.theme.spaceMd

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.theme.space2Xs

                                Components.JcSettingTile {
                                    id: lockCapabilityTile

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: implicitHeight

                                    theme: root.theme
                                    text: "Lock"
                                    iconName: "settings"

                                    selected: false
                                    controlEnabled: false
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        !root.quickSettingsService
                                        || !root.quickSettingsService.ready
                                            ? "Checking…"
                                            : root.quickSettingsService.lockAvailable
                                                ? "Available"
                                                : "Unavailable"

                                    color:
                                        root.quickSettingsService
                                        && root.quickSettingsService.ready
                                        && root.quickSettingsService.lockAvailable
                                            ? root.theme.success
                                            : root.theme.textMuted

                                    font.family: root.theme.fontFamilySans
                                    font.pixelSize: root.theme.textSizeCaption
                                    font.weight: root.theme.fontWeightMedium

                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.theme.space2Xs

                                Components.JcSettingTile {
                                    id: nightLightCapabilityTile

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: implicitHeight

                                    theme: root.theme
                                    text: "Night Light"
                                    iconName: "theme"

                                    selected: root.nightLightEnabled
                                    controlEnabled:
                                        root.nightLightControlEnabled

                                    onClicked:
                                        root.nightLightRequested(
                                            !root.nightLightEnabled
                                        )
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text: root.nightLightStateLabel

                                    color:
                                        root.nightLightEnabled
                                            ? root.theme.success
                                            : root.quickSettingsService
                                                && root.quickSettingsService.ready
                                                && root.quickSettingsService.nightLightAvailable
                                                    ? root.theme.textSecondary
                                                    : root.theme.textMuted

                                    font.family: root.theme.fontFamilySans
                                    font.pixelSize: root.theme.textSizeCaption
                                    font.weight: root.theme.fontWeightMedium

                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: root.theme.space2Xs

                                Components.JcSettingTile {
                                    id: suspendCapabilityTile

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: implicitHeight

                                    theme: root.theme
                                    text: "Suspend"
                                    iconName: "power"

                                    selected: false
                                    controlEnabled: false
                                }

                                Text {
                                    Layout.fillWidth: true

                                    text:
                                        !root.quickSettingsService
                                        || !root.quickSettingsService.ready
                                            ? "Checking…"
                                            : root.quickSettingsService.suspendAvailable
                                                ? "Available"
                                                : "Unavailable"

                                    color:
                                        root.quickSettingsService
                                        && root.quickSettingsService.ready
                                        && root.quickSettingsService.suspendAvailable
                                            ? root.theme.success
                                            : root.theme.textMuted

                                    font.family: root.theme.fontFamilySans
                                    font.pixelSize: root.theme.textSizeCaption
                                    font.weight: root.theme.fontWeightMedium

                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true

                            text:
                                "Night Light is interactive in Phase 2D.2. "
                                + "Lock and Suspend remain observed-only."

                            color: root.theme.textMuted

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeCaption
                            font.weight: root.theme.fontWeightRegular

                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
