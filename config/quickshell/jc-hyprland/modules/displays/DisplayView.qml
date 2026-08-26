import QtQuick
import QtQuick.Layouts

import qs.components as Components

Item {
    id: root

    property var monitorService
    property var draftStore
    property var applyService
    property var persistenceService
    required property var theme

    signal refreshRequested()
    signal resetRequested()
    signal applyRequested()
    signal keepRequested()
    signal rollbackRequested()
    signal saveRequested()

    implicitWidth: 820
    implicitHeight: 700

    ColumnLayout {
        anchors.fill: parent
        spacing: root.theme.spaceMd

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    Layout.fillWidth: true

                    text: {
                        if (!root.monitorService)
                            return "Monitor service unavailable";

                        const base =
                            root.monitorService.activeCount
                            + " active / "
                            + root.monitorService.count
                            + " detected";

                        if (root.applyService
                                && root.applyService.pendingConfirmation) {
                            return base
                                + " · Safe Apply pending on "
                                + root.applyService.pendingOutput;
                        }

                        if (root.draftStore && root.draftStore.hasDirty) {
                            return base
                                + " · "
                                + root.draftStore.dirtyCount
                                + " draft change(s)";
                        }

                        return base;
                    }

                    color: root.theme.textSecondary
                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeBody
                    font.weight: root.theme.fontWeightMedium
                    elide: Text.ElideRight
                }

                Components.JcButton {
                    visible:
                        root.applyService
                        && root.applyService.pendingConfirmation

                    theme: root.theme
                    text: root.applyService
                        ? "Keep (" + root.applyService.remainingSeconds + "s)"
                        : "Keep"

                    controlEnabled:
                        root.applyService
                        && !root.applyService.busy

                    onClicked: root.keepRequested()
                }

                Components.JcButton {
                    visible:
                        root.applyService
                        && root.applyService.pendingConfirmation

                    theme: root.theme
                    text: root.applyService && root.applyService.rollingBack
                        ? "Rolling back…"
                        : "Rollback"

                    controlEnabled:
                        root.applyService
                        && !root.applyService.busy

                    onClicked: root.rollbackRequested()
                }

                Components.JcButton {
                    visible:
                        root.draftStore
                        && root.draftStore.hasDirty
                        && !(root.applyService
                            && root.applyService.pendingConfirmation)

                    theme: root.theme
                    text: "Reset"
                    controlEnabled:
                        !(root.applyService && root.applyService.busy)

                    onClicked: root.resetRequested()
                }

                Components.JcButton {
                    visible:
                        root.draftStore
                        && root.draftStore.hasDirty
                        && !(root.applyService
                            && root.applyService.pendingConfirmation)

                    theme: root.theme

                    text: root.applyService && root.applyService.applying
                        ? "Applying…"
                        : "Safe Apply"

                    controlEnabled:
                        root.draftStore
                        && root.draftStore.dirtyCount === 1
                        && root.draftStore.topologyValid
                        && !root.draftStore.observedChangedWhileDirty
                        && !(root.applyService && root.applyService.busy)

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
                        && !(root.applyService && root.applyService.busy)
                        && !(root.applyService
                            && root.applyService.pendingConfirmation)
                        && !(root.persistenceService
                            && root.persistenceService.busy)

                    onClicked: root.refreshRequested()
                }

            }

            Components.JcDivider {
                Layout.fillWidth: true
                theme: root.theme
            }

            Rectangle {
                visible:
                    root.applyService
                    && root.applyService.pendingConfirmation

                Layout.fillWidth: true
                implicitHeight: confirmationContent.implicitHeight + 24

                radius: root.theme ? root.theme.radiusSmall : 8

                color: root.theme
                    ? Qt.rgba(
                        root.theme.warning.r,
                        root.theme.warning.g,
                        root.theme.warning.b,
                        0.10
                    )
                    : "#302b20"

                border.width: 1
                border.color: root.theme ? root.theme.warning : "#f9e2af"

                ColumnLayout {
                    id: confirmationContent

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    Text {
                        Layout.fillWidth: true

                        text:
                            "Keep this runtime display state?"

                        color: root.theme
                            ? root.theme.textPrimary
                            : "#f2f2f4"

                        font.pixelSize: root.theme.textSizeBodyLarge
                        font.weight: root.theme.fontWeightSemibold
                    }

                    Text {
                        Layout.fillWidth: true

                        text: root.applyService
                            ? "Automatic rollback in "
                                + root.applyService.remainingSeconds
                                + " second(s). Persistent monitors.lua "
                                + "has not been modified."
                            : ""

                        color: root.theme
                            ? root.theme.warning
                            : "#f9e2af"

                        font.pixelSize: root.theme.textSizeBody
                        wrapMode: Text.Wrap
                    }
                }
            }

            Text {
                visible: root.monitorService
                    && root.monitorService.errorMessage.length > 0

                Layout.fillWidth: true
                text: root.monitorService ? root.monitorService.errorMessage : ""
                color: root.theme ? root.theme.danger : "#f38ba8"
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.Wrap
            }

            Text {
                visible:
                    root.draftStore
                    && root.draftStore.observedChangedWhileDirty
                    && !(root.applyService
                        && root.applyService.pendingConfirmation)

                Layout.fillWidth: true

                text:
                    "Hyprland monitor state changed while a draft was being "
                    + "edited. Reset the draft before continuing."

                color: root.theme ? root.theme.warning : "#f9e2af"
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.Wrap
            }


            Text {
                visible:
                    root.draftStore
                    && !root.draftStore.topologyValid
                    && !(root.applyService
                        && root.applyService.pendingConfirmation)

                Layout.fillWidth: true

                text: root.draftStore
                    ? root.draftStore.topologyError
                    : ""

                color: root.theme ? root.theme.danger : "#f38ba8"
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightSemibold
                wrapMode: Text.Wrap
            }

            Text {
                visible:
                    root.draftStore
                    && root.draftStore.dirtyCount > 1
                    && !(root.applyService
                        && root.applyService.pendingConfirmation)

                Layout.fillWidth: true

                text:
                    "Safe Apply changes one monitor at a time. "
                    + "Reset one draft before applying."

                color: root.theme ? root.theme.warning : "#f9e2af"
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.applyService
                    && root.applyService.errorMessage.length > 0

                Layout.fillWidth: true
                text: root.applyService ? root.applyService.errorMessage : ""

                color: root.theme ? root.theme.danger : "#f38ba8"
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.applyService
                    && root.applyService.statusMessage.length > 0

                Layout.fillWidth: true
                text: root.applyService ? root.applyService.statusMessage : ""

                color: root.theme ? root.theme.success : "#a6e3a1"
                font.pixelSize: root.theme.textSizeBody
                wrapMode: Text.Wrap
            }

            Text {
                visible: root.persistenceService
                    && root.persistenceService.errorMessage.length > 0

                Layout.fillWidth: true
                text: root.persistenceService
                    ? root.persistenceService.errorMessage
                    : ""

                color: root.theme ? root.theme.danger : "#f38ba8"
                font.pixelSize: root.theme.textSizeBody
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
                    spacing: root.theme.spaceMd

                    DisplayLayoutEditor {
                        width: contentColumn.width

                        theme: root.theme
                        draftStore: root.draftStore

                        editorEnabled:
                            !(root.applyService && root.applyService.busy)
                            && !(root.applyService
                                && root.applyService.pendingConfirmation)
                            && !(root.persistenceService
                                && root.persistenceService.saving)
                    }

                    Text {
                        visible: root.monitorService
                            && !root.monitorService.loading
                            && root.monitorService.count === 0
                            && root.monitorService.errorMessage.length === 0

                        width: parent.width
                        text: "No monitor information was returned by Hyprland."
                        color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                        font.pixelSize: root.theme.textSizeBody
                    }

                    Repeater {
                        model: root.monitorService
                            ? root.monitorService.monitors
                            : []

                        delegate: DisplayCard {
                            required property var modelData

                            width: contentColumn.width

                            theme: root.theme
                            monitor: modelData
                            draftStore: root.draftStore

                            editorEnabled:
                                !(root.applyService && root.applyService.busy)
                                && !(root.applyService
                                    && root.applyService.pendingConfirmation)
                                && !(root.persistenceService
                                    && root.persistenceService.saving)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.theme.spaceSm

                Text {
                    Layout.fillWidth: true

                    text: {
                        if (root.applyService
                                && root.applyService.pendingConfirmation) {
                            return "Safe Apply is temporary until confirmed.";
                        }

                        if (root.draftStore && root.draftStore.hasDirty)
                            return root.draftStore.topologyValid
                                ? "Draft display state is ready for Safe Apply."
                                : "Resolve the display/topology conflict before Safe Apply.";

                        if (root.persistenceService
                                && root.persistenceService.checking) {
                            return "Checking persistent display configuration…";
                        }

                        if (root.persistenceService
                                && root.persistenceService.statusMessage.length > 0) {
                            return root.persistenceService.statusMessage;
                        }

                        if (root.monitorService
                                && root.monitorService.lastRefresh.length > 0) {
                            return "Last refresh: "
                                + root.monitorService.lastRefresh;
                        }

                        return "Persistent display state has not been checked yet.";
                    }

                    color: root.persistenceService
                            && root.persistenceService.hasPersistentChanges
                        ? (root.theme ? root.theme.warning : "#f9e2af")
                        : (root.theme ? root.theme.textSecondary : "#b8b8c0")

                    font.pixelSize: root.theme.textSizeCaption
                    wrapMode: Text.Wrap
                }

                Components.JcButton {
                    theme: root.theme

                    text: root.persistenceService
                            && root.persistenceService.saving
                        ? "Saving…"
                        : "Save Configuration"

                    controlEnabled:
                        root.persistenceService
                        && root.persistenceService.canSave

                    onClicked: root.saveRequested()
                }

            }
        }
}
