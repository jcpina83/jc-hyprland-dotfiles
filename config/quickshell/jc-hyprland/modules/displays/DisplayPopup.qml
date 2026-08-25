import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.components as Components

PanelWindow {
    id: root

    property var targetScreen
    property var monitorService
    property var draftStore
    property var applyService
    property var theme

    signal closeRequested()
    signal refreshRequested()
    signal resetRequested()
    signal applyRequested()

    screen: targetScreen

    implicitWidth: 820
    implicitHeight: 680

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
                        text: {
                            if (!root.monitorService)
                                return "Monitor service unavailable";

                            const base =
                                root.monitorService.activeCount
                                + " active / "
                                + root.monitorService.count
                                + " detected";

                            if (root.draftStore && root.draftStore.hasDirty) {
                                return base
                                    + " · "
                                    + root.draftStore.dirtyCount
                                    + " draft change(s)";
                            }

                            return base;
                        }

                        color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                        font.pixelSize: 12
                    }
                }

                Components.JcButton {
                    visible: root.draftStore && root.draftStore.hasDirty

                    theme: root.theme
                    text: "Reset"
                    controlEnabled:
                        !(root.applyService && root.applyService.applying)

                    onClicked: root.resetRequested()
                }

                Components.JcButton {
                    visible: root.draftStore && root.draftStore.hasDirty

                    theme: root.theme

                    text: root.applyService && root.applyService.applying
                        ? "Applying…"
                        : "Apply"

                    controlEnabled:
                        root.draftStore
                        && root.draftStore.dirtyCount === 1
                        && !root.draftStore.observedChangedWhileDirty
                        && !(root.applyService && root.applyService.applying)

                    onClicked: root.applyRequested()
                }

                Components.JcButton {
                    theme: root.theme

                    text: root.monitorService && root.monitorService.loading
                        ? "Refreshing…"
                        : "Refresh"

                    controlEnabled:
                        !(root.monitorService && root.monitorService.loading)
                        && !(root.draftStore && root.draftStore.hasDirty)
                        && !(root.applyService && root.applyService.applying)

                    onClicked: root.refreshRequested()
                }

                Components.JcButton {
                    theme: root.theme
                    text: "Close"
                    controlEnabled:
                        !(root.applyService && root.applyService.applying)
                    onClicked: root.closeRequested()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
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

            Text {
                visible: root.draftStore
                    && root.draftStore.observedChangedWhileDirty

                Layout.fillWidth: true

                text:
                    "Hyprland monitor state changed while a draft was being "
                    + "edited. Reset the draft before continuing."

                color: root.theme ? root.theme.warning : "#f9e2af"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.draftStore
                    && root.draftStore.dirtyCount > 1

                Layout.fillWidth: true

                text:
                    "Phase 1B.2 applies one monitor at a time. "
                    + "Reset one draft before applying."

                color: root.theme ? root.theme.warning : "#f9e2af"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.applyService
                    && root.applyService.errorMessage.length > 0

                Layout.fillWidth: true
                text: root.applyService ? root.applyService.errorMessage : ""

                color: root.theme ? root.theme.error : "#f38ba8"
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.applyService
                    && root.applyService.statusMessage.length > 0

                Layout.fillWidth: true
                text: root.applyService ? root.applyService.statusMessage : ""

                color: root.theme ? root.theme.success : "#a6e3a1"
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
                            draftStore: root.draftStore
                            editorEnabled:
                                !(root.applyService && root.applyService.applying)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true

                    text: {
                        if (root.draftStore && root.draftStore.hasDirty)
                            return "Draft changes are ready for runtime apply.";

                        if (root.monitorService
                                && root.monitorService.lastRefresh.length > 0) {
                            return "Last refresh: "
                                + root.monitorService.lastRefresh;
                        }

                        return "No persistent monitor configuration is modified.";
                    }

                    color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                    font.pixelSize: 11
                }

                Text {
                    text: "Phase 1B.2 · Runtime only"
                    color: root.theme ? root.theme.accent : "#89b4fa"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
}
