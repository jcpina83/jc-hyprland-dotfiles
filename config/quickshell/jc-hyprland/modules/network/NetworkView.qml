import QtQuick
import qs.components as Components

Flickable {
    id: root

    required property var theme
    property var networkService
    property var bluetoothService
    property var networkActionService: null
    property var bluetoothActionService: null

    clip: true
    contentWidth: width
    contentHeight: contentColumn.implicitHeight + root.theme.spaceLg
    boundsBehavior: Flickable.StopAtBounds

    function yesNo(value) {
        return value ? "Yes" : "No";
    }

    function statusText(value, available) {
        return available ? String(value || "Unknown") : "Unavailable";
    }

    function wifiSignalText() {
        if (!root.networkService
                || root.networkService.wifiSignalStrength < 0) {
            return "Unavailable";
        }

        return Math.round(
            root.networkService.wifiSignalStrength * 100
        ) + "%";
    }

    function bluetoothBatteryText() {
        if (!root.bluetoothService
                || !root.bluetoothService.primaryDeviceBatteryAvailable) {
            return "Unavailable";
        }

        return Math.round(
            root.bluetoothService.primaryDeviceBattery * 100
        ) + "%";
    }

    function bluetoothDeviceName(device) {
        if (!device)
            return "Paired device";

        return String(device.name || device.deviceName || "Paired device");
    }

    Column {
        id: contentColumn

        width: root.width
        spacing: root.theme.spaceMd

        Components.JcSectionHeader {
            width: parent.width
            theme: root.theme
            title: "Network & Bluetooth"
            subtitle: "Observed state · low-risk connectivity controls"
        }

        Components.JcHudFrame {
            width: parent.width
            implicitHeight:
                connectivityColumn.implicitHeight + root.theme.spaceLg * 2

            theme: root.theme
            surfaceRole: "glass-raised"
            contentPadding: 0
            cutSize: root.theme.spaceMd
            accentLength: root.theme.controlHeightLarge
            glowEnabled: false
            showInnerFrame: true
            showCornerAccents: true
            showSecondaryAccent: false

            Column {
                id: connectivityColumn

                anchors.fill: parent
                anchors.margins: root.theme.spaceLg
                spacing: root.theme.spaceSm

                Components.JcSectionHeader {
                    width: parent.width
                    theme: root.theme
                    title: "Connectivity"
                    subtitle:
                        root.networkService
                            ? root.networkService.connectivityName
                            : "Unavailable"
                }

                Text {
                    width: parent.width
                    text:
                        "Backend: "
                        + (
                            root.networkService
                                ? root.networkService.backendName
                                : "Unavailable"
                        )
                    color: root.theme.textPrimary
                    font.pixelSize: root.theme.textSizeBody
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text:
                        "Connected: "
                        + root.yesNo(
                            root.networkService
                            && root.networkService.connected
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                }
            }
        }

        Components.JcHudFrame {
            width: parent.width
            implicitHeight: wifiColumn.implicitHeight + root.theme.spaceLg * 2

            theme: root.theme
            surfaceRole: "glass"
            contentPadding: 0
            cutSize: root.theme.spaceMd
            accentLength: root.theme.controlHeightLarge
            glowEnabled: false
            showInnerFrame: true
            showCornerAccents: true
            showSecondaryAccent: false

            Column {
                id: wifiColumn

                anchors.fill: parent
                anchors.margins: root.theme.spaceLg
                spacing: root.theme.spaceSm

                Components.JcSectionHeader {
                    width: parent.width
                    theme: root.theme
                    title: "Wi-Fi"
                    subtitle:
                        root.networkService
                            ? root.statusText(
                                root.networkService.wifiStateName,
                                root.networkService.wifiAvailable
                            )
                            : "Unavailable"
                }

                Components.JcToggle {
                    width: parent.width
                    theme: root.theme
                    text:
                        root.networkActionService
                        && root.networkActionService.applyingWifiEnabled
                            ? "Wi-Fi radio · updating…"
                            : "Wi-Fi radio"
                    checked:
                        root.networkService
                        && root.networkService.wifiEnabled
                    controlEnabled:
                        root.networkActionService
                        && root.networkActionService.canSetWifiEnabled

                    onToggled: value => {
                        if (root.networkActionService)
                            root.networkActionService.setWifiEnabled(value);
                    }
                }

                Text {
                    width: parent.width
                    text:
                        "Radio: "
                        + (
                            root.networkService
                            && root.networkService.wifiEnabled
                                ? "Enabled"
                                : "Disabled"
                        )
                        + " · Hardware: "
                        + (
                            root.networkService
                            && root.networkService.wifiHardwareEnabled
                                ? "Enabled"
                                : "Blocked"
                        )
                    color: root.theme.textPrimary
                    font.pixelSize: root.theme.textSizeBody
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text:
                        "Interface: "
                        + (
                            root.networkService
                            && root.networkService.wifiInterface.length > 0
                                ? root.networkService.wifiInterface
                                : "Unavailable"
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text:
                        "Network: "
                        + (
                            root.networkService
                            && root.networkService.wifiNetworkName.length > 0
                                ? root.networkService.wifiNetworkName
                                : "Not connected"
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text:
                        "Signal: "
                        + root.wifiSignalText()
                        + " · Security: "
                        + (
                            root.networkService
                                ? root.networkService.wifiSecurityName
                                : "Unknown"
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    elide: Text.ElideRight
                }

                Components.JcSectionHeader {
                    width: parent.width
                    theme: root.theme
                    title: "Saved networks"
                    subtitle:
                        root.networkService
                            ? root.networkService.knownWifiNetworkCount
                                + " known"
                            : "Unavailable"
                }

                Text {
                    width: parent.width
                    visible:
                        !root.networkService
                        || root.networkService.knownWifiNetworkCount === 0
                    text: "No saved Wi-Fi networks are currently observed."
                    color: root.theme.textMuted
                    font.pixelSize: root.theme.textSizeCaption
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model:
                        root.networkService
                            ? root.networkService.knownWifiNetworkValues
                            : []

                    delegate: Column {
                        id: knownNetworkRow

                        width: wifiColumn.width
                        spacing: root.theme.spaceXs

                        property var networkObject: modelData

                        Row {
                            width: parent.width
                            spacing: root.theme.spaceSm

                            Column {
                                width:
                                    Math.max(
                                        0,
                                        parent.width
                                        - networkConnectButton.width
                                        - parent.spacing
                                    )
                                spacing: root.theme.space2Xs

                                Text {
                                    width: parent.width
                                    text:
                                        knownNetworkRow.networkObject
                                            ? String(
                                                knownNetworkRow.networkObject.name
                                                || "Saved network"
                                            )
                                            : "Saved network"
                                    color: root.theme.textPrimary
                                    font.pixelSize: root.theme.textSizeBody
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text:
                                        knownNetworkRow.networkObject
                                        && knownNetworkRow.networkObject.stateChanging
                                            ? "Updating…"
                                            : (
                                                knownNetworkRow.networkObject
                                                && knownNetworkRow.networkObject.connected
                                                    ? "Connected"
                                                    : "Saved"
                                            )
                                    color: root.theme.textSecondary
                                    font.pixelSize: root.theme.textSizeCaption
                                }
                            }

                            Components.JcButton {
                                id: networkConnectButton

                                theme: root.theme
                                compact: true
                                text:
                                    knownNetworkRow.networkObject
                                    && knownNetworkRow.networkObject.connected
                                        ? "Disconnect"
                                        : "Connect"
                                controlEnabled:
                                    root.networkActionService
                                    && knownNetworkRow.networkObject
                                    && root.networkActionService
                                        .canSetKnownNetworkConnected(
                                            knownNetworkRow.networkObject,
                                            !knownNetworkRow.networkObject.connected
                                        )

                                onClicked: {
                                    if (root.networkActionService
                                            && knownNetworkRow.networkObject) {
                                        root.networkActionService
                                            .setKnownNetworkConnected(
                                                knownNetworkRow.networkObject,
                                                !knownNetworkRow.networkObject.connected
                                            );
                                    }
                                }
                            }
                        }

                        Components.JcDivider {
                            width: parent.width
                            theme: root.theme
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible:
                        root.networkActionService
                        && (
                            root.networkActionService.errorMessage.length > 0
                            || root.networkActionService.statusMessage.length > 0
                        )
                    text:
                        root.networkActionService
                        && root.networkActionService.errorMessage.length > 0
                            ? root.networkActionService.errorMessage
                            : (
                                root.networkActionService
                                    ? root.networkActionService.statusMessage
                                    : ""
                            )
                    color:
                        root.networkActionService
                        && root.networkActionService.errorMessage.length > 0
                            ? root.theme.danger
                            : root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    wrapMode: Text.Wrap
                }
            }
        }

        Components.JcHudFrame {
            width: parent.width
            implicitHeight:
                ethernetColumn.implicitHeight + root.theme.spaceLg * 2

            theme: root.theme
            surfaceRole: "glass"
            contentPadding: 0
            cutSize: root.theme.spaceMd
            accentLength: root.theme.controlHeightLarge
            glowEnabled: false
            showInnerFrame: true
            showCornerAccents: true
            showSecondaryAccent: false

            Column {
                id: ethernetColumn

                anchors.fill: parent
                anchors.margins: root.theme.spaceLg
                spacing: root.theme.spaceSm

                Components.JcSectionHeader {
                    width: parent.width
                    theme: root.theme
                    title: "Ethernet"
                    subtitle:
                        root.networkService
                            ? root.statusText(
                                root.networkService.wiredStateName,
                                root.networkService.wiredAvailable
                            )
                            : "Unavailable"
                }

                Text {
                    width: parent.width
                    text:
                        "Interface: "
                        + (
                            root.networkService
                            && root.networkService.wiredInterface.length > 0
                                ? root.networkService.wiredInterface
                                : "Unavailable"
                        )
                    color: root.theme.textPrimary
                    font.pixelSize: root.theme.textSizeBody
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text:
                        "Link: "
                        + (
                            root.networkService
                            && root.networkService.wiredHasLink
                                ? "Detected"
                                : "No link"
                        )
                        + " · Speed: "
                        + (
                            root.networkService
                            && root.networkService.wiredLinkSpeedMbps > 0
                                ? root.networkService.wiredLinkSpeedMbps
                                    + " Mb/s"
                                : "Unavailable"
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    wrapMode: Text.Wrap
                }
            }
        }

        Components.JcHudFrame {
            width: parent.width
            implicitHeight:
                bluetoothColumn.implicitHeight + root.theme.spaceLg * 2

            theme: root.theme
            surfaceRole: "glass"
            contentPadding: 0
            cutSize: root.theme.spaceMd
            accentLength: root.theme.controlHeightLarge
            glowEnabled: false
            showInnerFrame: true
            showCornerAccents: true
            showSecondaryAccent: false

            Column {
                id: bluetoothColumn

                anchors.fill: parent
                anchors.margins: root.theme.spaceLg
                spacing: root.theme.spaceSm

                Components.JcSectionHeader {
                    width: parent.width
                    theme: root.theme
                    title: "Bluetooth"
                    subtitle:
                        root.bluetoothService
                            ? root.statusText(
                                root.bluetoothService.stateName,
                                root.bluetoothService.adapterAvailable
                            )
                            : "Unavailable"
                }

                Components.JcToggle {
                    width: parent.width
                    theme: root.theme
                    text:
                        root.bluetoothActionService
                        && root.bluetoothActionService.applyingAdapterEnabled
                            ? "Bluetooth adapter · updating…"
                            : "Bluetooth adapter"
                    checked:
                        root.bluetoothService
                        && root.bluetoothService.enabled
                    controlEnabled:
                        root.bluetoothActionService
                        && root.bluetoothActionService.canSetAdapterEnabled

                    onToggled: value => {
                        if (root.bluetoothActionService)
                            root.bluetoothActionService.setAdapterEnabled(value);
                    }
                }

                Text {
                    width: parent.width
                    text:
                        "Adapter: "
                        + (
                            root.bluetoothService
                            && root.bluetoothService.adapterName.length > 0
                                ? root.bluetoothService.adapterName
                                : "Unavailable"
                        )
                        + " · Power: "
                        + (
                            root.bluetoothService
                            && root.bluetoothService.enabled
                                ? "Enabled"
                                : "Disabled"
                        )
                    color: root.theme.textPrimary
                    font.pixelSize: root.theme.textSizeBody
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text:
                        "Connected devices: "
                        + (
                            root.bluetoothService
                                ? root.bluetoothService.connectedDeviceCount
                                : 0
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                }

                Text {
                    width: parent.width
                    text:
                        "Primary device: "
                        + (
                            root.bluetoothService
                            && root.bluetoothService.primaryDeviceName.length > 0
                                ? root.bluetoothService.primaryDeviceName
                                : "None"
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text:
                        "State: "
                        + (
                            root.bluetoothService
                                ? root.bluetoothService.primaryDeviceStateName
                                : "Disconnected"
                        )
                        + " · Battery: "
                        + root.bluetoothBatteryText()
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text:
                        "Paired: "
                        + root.yesNo(
                            root.bluetoothService
                            && root.bluetoothService.primaryDevicePaired
                        )
                        + " · Trusted: "
                        + root.yesNo(
                            root.bluetoothService
                            && root.bluetoothService.primaryDeviceTrusted
                        )
                    color: root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                }

                Components.JcSectionHeader {
                    width: parent.width
                    theme: root.theme
                    title: "Paired devices"
                    subtitle:
                        root.bluetoothService
                            ? root.bluetoothService.pairedDeviceCount
                                + " paired"
                            : "Unavailable"
                }

                Text {
                    width: parent.width
                    visible:
                        !root.bluetoothService
                        || root.bluetoothService.pairedDeviceCount === 0
                    text: "No paired Bluetooth devices are currently observed."
                    color: root.theme.textMuted
                    font.pixelSize: root.theme.textSizeCaption
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model:
                        root.bluetoothService
                            ? root.bluetoothService.pairedDeviceValues
                            : []

                    delegate: Column {
                        id: pairedDeviceRow

                        width: bluetoothColumn.width
                        spacing: root.theme.spaceXs

                        property var deviceObject: modelData

                        Row {
                            width: parent.width
                            spacing: root.theme.spaceSm

                            Column {
                                width:
                                    Math.max(
                                        0,
                                        parent.width
                                        - bluetoothTrustButton.width
                                        - bluetoothConnectButton.width
                                        - parent.spacing
                                    )
                                spacing: root.theme.space2Xs

                                Text {
                                    width: parent.width
                                    text:
                                        root.bluetoothDeviceName(
                                            pairedDeviceRow.deviceObject
                                        )
                                    color: root.theme.textPrimary
                                    font.pixelSize: root.theme.textSizeBody
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text:
                                        pairedDeviceRow.deviceObject
                                        && pairedDeviceRow.deviceObject.pairing
                                            ? "Pairing state busy"
                                            : (
                                                pairedDeviceRow.deviceObject
                                                && pairedDeviceRow.deviceObject.connected
                                                    ? "Connected"
                                                    : "Paired"
                                            )
                                    color: root.theme.textSecondary
                                    font.pixelSize: root.theme.textSizeCaption
                                }
                            }

                            Components.JcButton {
                                id: bluetoothTrustButton

                                theme: root.theme
                                compact: true
                                text:
                                    pairedDeviceRow.deviceObject
                                    && pairedDeviceRow.deviceObject.trusted
                                        ? "Untrust"
                                        : "Trust"
                                controlEnabled:
                                    root.bluetoothActionService
                                    && pairedDeviceRow.deviceObject
                                    && root.bluetoothActionService
                                        .canSetPairedDeviceTrusted(
                                            pairedDeviceRow.deviceObject,
                                            !pairedDeviceRow.deviceObject.trusted
                                        )

                                onClicked: {
                                    if (root.bluetoothActionService
                                            && pairedDeviceRow.deviceObject) {
                                        root.bluetoothActionService
                                            .setPairedDeviceTrusted(
                                                pairedDeviceRow.deviceObject,
                                                !pairedDeviceRow.deviceObject.trusted
                                            );
                                    }
                                }
                            }

                            Components.JcButton {
                                id: bluetoothConnectButton

                                theme: root.theme
                                compact: true
                                text:
                                    pairedDeviceRow.deviceObject
                                    && pairedDeviceRow.deviceObject.connected
                                        ? "Disconnect"
                                        : "Connect"
                                controlEnabled:
                                    root.bluetoothActionService
                                    && pairedDeviceRow.deviceObject
                                    && root.bluetoothActionService
                                        .canSetPairedDeviceConnected(
                                            pairedDeviceRow.deviceObject,
                                            !pairedDeviceRow.deviceObject.connected
                                        )

                                onClicked: {
                                    if (root.bluetoothActionService
                                            && pairedDeviceRow.deviceObject) {
                                        root.bluetoothActionService
                                            .setPairedDeviceConnected(
                                                pairedDeviceRow.deviceObject,
                                                !pairedDeviceRow.deviceObject.connected
                                            );
                                    }
                                }
                            }
                        }

                        Components.JcDivider {
                            width: parent.width
                            theme: root.theme
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible:
                        root.bluetoothActionService
                        && (
                            root.bluetoothActionService.errorMessage.length > 0
                            || root.bluetoothActionService.statusMessage.length > 0
                        )
                    text:
                        root.bluetoothActionService
                        && root.bluetoothActionService.errorMessage.length > 0
                            ? root.bluetoothActionService.errorMessage
                            : (
                                root.bluetoothActionService
                                    ? root.bluetoothActionService.statusMessage
                                    : ""
                            )
                    color:
                        root.bluetoothActionService
                        && root.bluetoothActionService.errorMessage.length > 0
                            ? root.theme.danger
                            : root.theme.textSecondary
                    font.pixelSize: root.theme.textSizeCaption
                    wrapMode: Text.Wrap
                }
            }
        }

        Text {
            width: parent.width
            text:
                "Low-risk controls use native Quickshell action services. "
                + "Credentials, pairing, and forget actions remain deferred."
            color: root.theme.textMuted
            font.pixelSize: root.theme.textSizeCaption
            wrapMode: Text.Wrap
        }
    }
}
