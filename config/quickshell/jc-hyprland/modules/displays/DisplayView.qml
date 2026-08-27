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

    ColumnLayout {
        anchors.fill: parent
        spacing: root.theme.spaceMd

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceMd

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

        Components.JcSurface {
            visible:
                root.applyService
                && root.applyService.pendingConfirmation

            Layout.fillWidth: true
            implicitHeight:
                confirmationContent.implicitHeight
                + (root.theme.spaceMd * 2)

            theme: root.theme
            surfaceRole: "base"
            cornerRadius: root.theme.radiusMd

            color: root.theme.warningSurface
            border.color: root.theme.warningBorder

            ColumnLayout {
                id: confirmationContent

                anchors.fill: parent
                anchors.margins: root.theme.spaceMd
                spacing: root.theme.spaceSm

                Components.JcSectionHeader {
                    Layout.fillWidth: true

                    theme: root.theme
                    title: "Safe Apply confirmation"
                    subtitle: root.applyService
                        && root.applyService.pendingOutput.length > 0
                        ? "Temporary runtime state active on "
                            + root.applyService.pendingOutput
                        : "Temporary runtime display state is active."
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.spaceMd

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: root.theme.space2Xs

                        Text {
                            text: root.applyService
                                ? root.applyService.remainingSeconds + "s"
                                : ""

                            color: root.theme.warning

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeSection
                            font.weight: root.theme.fontWeightBold
                        }

                        Text {
                            Layout.fillWidth: true

                            text:
                                "Automatic rollback remains active. "
                                + "Persistent monitors.lua has not been modified."

                            color: root.theme.textSecondary

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeBody
                            font.weight: root.theme.fontWeightRegular

                            wrapMode: Text.WordWrap
                        }
                    }

                    Components.JcButton {
                        theme: root.theme

                        text: root.applyService && root.applyService.keeping
                            ? "Keeping…"
                            : "Keep"

                        controlEnabled:
                            root.applyService
                            && !root.applyService.busy

                        onClicked: root.keepRequested()
                    }

                    Components.JcButton {
                        theme: root.theme

                        text: root.applyService
                                && root.applyService.rollingBack
                            ? "Rolling back…"
                            : "Rollback"

                        controlEnabled:
                            root.applyService
                            && !root.applyService.busy

                        onClicked: root.rollbackRequested()
                    }
                }
            }
        }

        Components.JcSurface {
            visible:
                root.monitorService
                && root.monitorService.errorMessage.length > 0

            Layout.fillWidth: true
            implicitHeight:
                monitorErrorText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.dangerSurface
            border.color: root.theme.dangerBorder

            Text {
                id: monitorErrorText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text: root.monitorService
                    ? root.monitorService.errorMessage
                    : ""

                color: root.theme.danger
                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium
                wrapMode: Text.WordWrap
            }
        }

        Components.JcSurface {
            visible:
                root.draftStore
                && root.draftStore.observedChangedWhileDirty
                && !(root.applyService
                    && root.applyService.pendingConfirmation)

            Layout.fillWidth: true
            implicitHeight:
                observedWarningText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.warningSurface
            border.color: root.theme.warningBorder

            Text {
                id: observedWarningText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text:
                    "Hyprland monitor state changed while a draft was being "
                    + "edited. Reset the draft before continuing."

                color: root.theme.warning
                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium
                wrapMode: Text.WordWrap
            }
        }

        Components.JcSurface {
            visible:
                root.draftStore
                && !root.draftStore.topologyValid
                && !(root.applyService
                    && root.applyService.pendingConfirmation)

            Layout.fillWidth: true
            implicitHeight:
                topologyErrorText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.dangerSurface
            border.color: root.theme.dangerBorder

            Text {
                id: topologyErrorText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text: root.draftStore
                    ? root.draftStore.topologyError
                    : ""

                color: root.theme.danger
                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightSemibold
                wrapMode: Text.WordWrap
            }
        }

        Components.JcSurface {
            visible:
                root.draftStore
                && root.draftStore.dirtyCount > 1
                && !(root.applyService
                    && root.applyService.pendingConfirmation)

            Layout.fillWidth: true
            implicitHeight:
                multiDraftWarningText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.warningSurface
            border.color: root.theme.warningBorder

            Text {
                id: multiDraftWarningText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text:
                    "Safe Apply changes one monitor at a time. "
                    + "Reset one draft before applying."

                color: root.theme.warning
                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium
                wrapMode: Text.WordWrap
            }
        }

        Components.JcSurface {
            visible:
                root.applyService
                && root.applyService.errorMessage.length > 0

            Layout.fillWidth: true
            implicitHeight:
                applyErrorText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.dangerSurface
            border.color: root.theme.dangerBorder

            Text {
                id: applyErrorText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text: root.applyService
                    ? root.applyService.errorMessage
                    : ""

                color: root.theme.danger
                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium
                wrapMode: Text.WordWrap
            }
        }

        Components.JcSurface {
            visible:
                root.applyService
                && root.applyService.statusMessage.length > 0
                && !root.applyService.pendingConfirmation

            Layout.fillWidth: true
            implicitHeight:
                applyStatusText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme

            color: root.applyService && root.applyService.busy
                ? root.theme.infoSurface
                : root.theme.successSurface

            border.color: root.applyService && root.applyService.busy
                ? root.theme.infoBorder
                : root.theme.successBorder

            Text {
                id: applyStatusText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text: root.applyService
                    ? root.applyService.statusMessage
                    : ""

                color: root.applyService && root.applyService.busy
                    ? root.theme.info
                    : root.theme.success

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium
                wrapMode: Text.WordWrap
            }
        }

        Components.JcSurface {
            visible:
                root.persistenceService
                && root.persistenceService.errorMessage.length > 0

            Layout.fillWidth: true
            implicitHeight:
                persistenceErrorText.implicitHeight
                + (root.theme.spaceSm * 2)

            theme: root.theme
            color: root.theme.dangerSurface
            border.color: root.theme.dangerBorder

            Text {
                id: persistenceErrorText

                anchors.fill: parent
                anchors.margins: root.theme.spaceSm

                text: root.persistenceService
                    ? root.persistenceService.errorMessage
                    : ""

                color: root.theme.danger
                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeBody
                font.weight: root.theme.fontWeightMedium
                wrapMode: Text.WordWrap
            }
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
                    visible:
                        root.monitorService
                        && !root.monitorService.loading
                        && root.monitorService.count === 0
                        && root.monitorService.errorMessage.length === 0

                    width: parent.width
                    text: "No monitor information was returned by Hyprland."
                    color: root.theme.textSecondary
                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeBody
                    font.weight: root.theme.fontWeightRegular
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

        Components.JcSurface {
            Layout.fillWidth: true
            implicitHeight:
                persistenceContent.implicitHeight
                + (root.theme.spaceMd * 2)

            theme: root.theme
            surfaceRole: "base"
            cornerRadius: root.theme.radiusMd

            color: {
                if (root.persistenceService
                        && (root.persistenceService.checking
                            || root.persistenceService.saving)) {
                    return root.theme.infoSurface;
                }

                if (root.persistenceService
                        && root.persistenceService.hasPersistentChanges) {
                    return root.theme.warningSurface;
                }

                return root.theme.surfaceSunken;
            }

            border.color: {
                if (root.persistenceService
                        && (root.persistenceService.checking
                            || root.persistenceService.saving)) {
                    return root.theme.infoBorder;
                }

                if (root.persistenceService
                        && root.persistenceService.hasPersistentChanges) {
                    return root.theme.warningBorder;
                }

                return root.theme.borderSubtle;
            }

            RowLayout {
                id: persistenceContent

                anchors.fill: parent
                anchors.margins: root.theme.spaceMd
                spacing: root.theme.spaceMd

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.theme.space2Xs

                    Components.JcSectionHeader {
                        Layout.fillWidth: true

                        theme: root.theme
                        title: "Persistent configuration"

                        subtitle: {
                            if (!root.persistenceService)
                                return "Persistence service unavailable.";

                            if (root.persistenceService.checking)
                                return "Checking persistent display configuration…";

                            if (root.persistenceService.saving)
                                return "Saving persistent display configuration…";

                            if (root.persistenceService.statusMessage.length > 0)
                                return root.persistenceService.statusMessage;

                            return "Persistent display state has not been checked yet.";
                        }
                    }

                    Text {
                        visible:
                            root.persistenceService
                            && root.persistenceService.lastBackup.length > 0

                        Layout.fillWidth: true

                        text: root.persistenceService
                            ? "Last backup: "
                                + root.persistenceService.lastBackup
                            : ""

                        color: root.theme.textSecondary
                        font.family: root.theme.fontFamilySans
                        font.pixelSize: root.theme.textSizeCaption
                        font.weight: root.theme.fontWeightRegular
                        elide: Text.ElideMiddle
                    }
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
}
