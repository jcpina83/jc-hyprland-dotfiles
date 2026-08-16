import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.components as Components

PanelWindow {
    id: root

    property var targetScreen
    property var monitorService
    property var theme

    signal closeRequested()
    signal refreshRequested()

    screen: targetScreen

    implicitWidth: 760
    implicitHeight: 600

    color: "transparent"
    focusable: true
    exclusiveZone: 0

    anchors {
        top: true
        right: true
    }

    margins {
        top: 14
        right: 14
    }

    Rectangle {
        anchors.fill: parent

        radius: root.theme ? root.theme.radiusLarge : 18
        color: root.theme ? root.theme.background : "#1b1b1f"
        border.width: 1
        border.color: root.theme ? root.theme.border : "#3b3b43"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.theme ? root.theme.spacingLg : 24
            spacing: root.theme ? root.theme.spacingMd : 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Displays"
                        color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                        font.pixelSize: 22
                        font.bold: true
                    }

                    Text {
                        text: root.monitorService
                            ? root.monitorService.activeCount
                                + " active / "
                                + root.monitorService.count
                                + " detected"
                            : "Monitor service unavailable"

                        color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                        font.pixelSize: 12
                    }
                }

                Components.JcButton {
                    theme: root.theme

                    text: root.monitorService && root.monitorService.loading
                        ? "Refreshing…"
                        : "Refresh"

                    controlEnabled:
                        !(root.monitorService && root.monitorService.loading)

                    onClicked: root.refreshRequested()
                }

                Components.JcButton {
                    theme: root.theme
                    text: "Close"
                    onClicked: root.closeRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.theme ? root.theme.border : "#3b3b43"
            }

            Text {
                visible: root.monitorService
                    && root.monitorService.errorMessage.length > 0

                Layout.fillWidth: true
                text: root.monitorService ? root.monitorService.errorMessage : ""
                color: root.theme ? root.theme.error : "#f38ba8"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true

                clip: true
                contentWidth: width
                contentHeight: contentColumn.implicitHeight

                Column {
                    id: contentColumn

                    width: parent.width
                    spacing: root.theme ? root.theme.spacingMd : 16

                    DisplayLayout {
                        width: contentColumn.width
                        theme: root.theme
                        monitors: root.monitorService
                            ? root.monitorService.monitors
                            : []
                    }

                    Text {
                        visible: root.monitorService
                            && !root.monitorService.loading
                            && root.monitorService.count === 0
                            && root.monitorService.errorMessage.length === 0

                        width: parent.width
                        text: "No monitor information was returned by Hyprland."
                        color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                        font.pixelSize: 13
                    }

                    Repeater {
                        model: root.monitorService
                            ? root.monitorService.monitors
                            : []

                        delegate: DisplayCard {
                            width: contentColumn.width
                            theme: root.theme
                            monitor: modelData
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true

                    text: root.monitorService
                            && root.monitorService.lastRefresh.length > 0
                        ? "Last refresh: " + root.monitorService.lastRefresh
                        : "Read-only mode"

                    color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                    font.pixelSize: 11
                }

                Text {
                    text: "Phase 1A · Read only"
                    color: root.theme ? root.theme.accent : "#89b4fa"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
