import QtQuick
import Quickshell

PanelWindow {
    id: root

    property var targetScreen
    property var monitorService
    property var draftStore
    property var applyService
    property var persistenceService
    property var theme

    signal closeRequested()
    signal refreshRequested()
    signal resetRequested()
    signal applyRequested()
    signal keepRequested()
    signal rollbackRequested()
    signal saveRequested()

    screen: root.targetScreen

    implicitWidth: 820
    implicitHeight: 700

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

    DisplayView {
        anchors.fill: parent

        monitorService: root.monitorService
        draftStore: root.draftStore
        applyService: root.applyService
        persistenceService: root.persistenceService
        theme: root.theme

        onCloseRequested: root.closeRequested()
        onRefreshRequested: root.refreshRequested()
        onResetRequested: root.resetRequested()
        onApplyRequested: root.applyRequested()
        onKeepRequested: root.keepRequested()
        onRollbackRequested: root.rollbackRequested()
        onSaveRequested: root.saveRequested()
    }
}
