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

    Column {
        id: contentColumn

        width: root.width
        spacing: root.theme.spaceMd

        Components.JcSectionHeader {
            width: parent.width
            theme: root.theme
            title: "Network & Bluetooth"
            subtitle: "Observed state · read-only foundation"
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
            }
        }

        Text {
            width: parent.width
            text:
                "Read-only telemetry · network and Bluetooth mutations "
                + "remain disabled in Phase 2G.1b."
            color: root.theme.textMuted
            font.pixelSize: root.theme.textSizeCaption
            wrapMode: Text.Wrap
        }
    }
}
