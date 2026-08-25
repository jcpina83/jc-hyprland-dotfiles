import QtQuick
import QtQuick.Layouts

import qs.components as Components

Components.JcCard {
    id: root

    property var draftStore
    property bool editorEnabled: true

    property string selectedOutput: ""
    property string anchorOutput: ""

    readonly property var projectedMonitors:
        root.draftStore
            ? root.draftStore.projectedMonitors()
            : []

    property real minimumX: 0
    property real minimumY: 0
    property real maximumX: 1
    property real maximumY: 1

    readonly property real topologyWidth:
        Math.max(1, root.maximumX - root.minimumX)
    readonly property real topologyHeight:
        Math.max(1, root.maximumY - root.minimumY)

    readonly property real canvasPadding: 18
    readonly property real usableWidth:
        Math.max(1, canvas.width - root.canvasPadding * 2)
    readonly property real usableHeight:
        Math.max(1, canvas.height - root.canvasPadding * 2)

    readonly property real topologyScale:
        Math.min(
            root.usableWidth / root.topologyWidth,
            root.usableHeight / root.topologyHeight
        )

    readonly property var anchorOptions:
        root.buildAnchorOptions()

    implicitHeight: 390

    function buildAnchorOptions() {
        const options = [];

        for (let i = 0; i < root.projectedMonitors.length; ++i) {
            const monitor = root.projectedMonitors[i];

            if (!monitor
                    || monitor.disabled
                    || monitor.output === root.selectedOutput) {
                continue;
            }

            options.push({
                value: monitor.output,
                label: monitor.output
            });
        }

        return options;
    }

    function ensureSelection() {
        if (root.projectedMonitors.length === 0) {
            root.selectedOutput = "";
            root.anchorOutput = "";
            return;
        }

        let selectedExists = false;

        for (let i = 0; i < root.projectedMonitors.length; ++i) {
            const monitor = root.projectedMonitors[i];

            if (monitor.output === root.selectedOutput) {
                selectedExists = true;
                break;
            }
        }

        if (!selectedExists)
            root.selectedOutput = root.projectedMonitors[0].output;

        let anchorExists = false;

        for (let i = 0; i < root.projectedMonitors.length; ++i) {
            const monitor = root.projectedMonitors[i];

            if (monitor.output === root.anchorOutput
                    && monitor.output !== root.selectedOutput) {
                anchorExists = true;
                break;
            }
        }

        if (!anchorExists) {
            root.anchorOutput = "";

            for (let i = 0; i < root.projectedMonitors.length; ++i) {
                const monitor = root.projectedMonitors[i];

                if (!monitor.disabled
                        && monitor.output !== root.selectedOutput) {
                    root.anchorOutput = monitor.output;
                    break;
                }
            }
        }
    }

    function recalculateBounds() {
        if (!root.projectedMonitors
                || root.projectedMonitors.length === 0) {
            root.minimumX = -1;
            root.minimumY = -1;
            root.maximumX = 1;
            root.maximumY = 1;
            return;
        }

        let minX = Number.POSITIVE_INFINITY;
        let minY = Number.POSITIVE_INFINITY;
        let maxX = Number.NEGATIVE_INFINITY;
        let maxY = Number.NEGATIVE_INFINITY;
        let activeFound = false;

        for (let i = 0; i < root.projectedMonitors.length; ++i) {
            const monitor = root.projectedMonitors[i];

            if (!monitor
                    || monitor.disabled
                    || monitor.logicalWidth <= 0
                    || monitor.logicalHeight <= 0) {
                continue;
            }

            activeFound = true;

            minX = Math.min(minX, monitor.x);
            minY = Math.min(minY, monitor.y);
            maxX = Math.max(
                maxX,
                monitor.x + monitor.logicalWidth
            );
            maxY = Math.max(
                maxY,
                monitor.y + monitor.logicalHeight
            );
        }

        if (!activeFound) {
            root.minimumX = -1;
            root.minimumY = -1;
            root.maximumX = 1;
            root.maximumY = 1;
            return;
        }

        const width = Math.max(1, maxX - minX);
        const height = Math.max(1, maxY - minY);

        // Keep enough world around the current topology to make dragging
        // above/left (negative coordinates) practical without resizing the
        // canvas during the active gesture.
        const marginX = Math.max(360, width * 0.14);
        const marginY = Math.max(260, height * 0.14);

        root.minimumX = minX - marginX;
        root.minimumY = minY - marginY;
        root.maximumX = maxX + marginX;
        root.maximumY = maxY + marginY;
    }

    function canvasX(worldX) {
        return root.canvasPadding
            + (Number(worldX) - root.minimumX) * root.topologyScale;
    }

    function canvasY(worldY) {
        return root.canvasPadding
            + (Number(worldY) - root.minimumY) * root.topologyScale;
    }

    function commitDrag(output, startX, startY, translationX, translationY) {
        if (!root.draftStore || root.topologyScale <= 0)
            return;

        const proposedX =
            Number(startX) + Number(translationX) / root.topologyScale;

        const proposedY =
            Number(startY) + Number(translationY) / root.topologyScale;

        const snapped = root.draftStore.snapPosition(
            output,
            proposedX,
            proposedY,
            42
        );

        root.draftStore.setPosition(
            output,
            snapped.x,
            snapped.y
        );
    }

    function selectOutput(output) {
        root.selectedOutput = String(output);
        root.ensureSelection();
    }

    function snapSelected(relation) {
        if (!root.draftStore
                || root.selectedOutput.length === 0
                || root.anchorOutput.length === 0) {
            return;
        }

        root.draftStore.snapRelative(
            root.selectedOutput,
            root.anchorOutput,
            relation
        );
    }

    onProjectedMonitorsChanged: {
        root.ensureSelection();
        root.recalculateBounds();
    }

    onSelectedOutputChanged: root.ensureSelection()

    Component.onCompleted: {
        root.ensureSelection();
        root.recalculateBounds();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: root.theme ? root.theme.spacingSm : 10

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "Visual layout"
                    color: root.theme
                        ? root.theme.textPrimary
                        : "#f2f2f4"

                    font.pixelSize: 14
                    font.bold: true
                }

                Text {
                    text:
                        "Drag a display. Nearby edges and centers snap "
                        + "automatically."

                    color: root.theme
                        ? root.theme.textSecondary
                        : "#b8b8c0"

                    font.pixelSize: 10
                }
            }

            Text {
                text: root.draftStore && root.draftStore.topologyValid
                    ? "Topology valid"
                    : "Layout conflict"

                color: root.draftStore && root.draftStore.topologyValid
                    ? (root.theme ? root.theme.success : "#a6e3a1")
                    : (root.theme ? root.theme.error : "#f38ba8")

                font.pixelSize: 11
                font.bold: true
            }
        }

        Rectangle {
            id: canvas

            Layout.fillWidth: true
            Layout.preferredHeight: 250

            clip: true

            radius: root.theme ? root.theme.radiusSmall : 8

            color: root.theme
                ? root.theme.background
                : "#1b1b1f"

            border.width: 1
            border.color: root.theme
                ? root.theme.border
                : "#3b3b43"

            Repeater {
                model: root.projectedMonitors

                delegate: Rectangle {
                    id: monitorRect

                    required property var modelData

                    property var monitor: modelData
                    property real dragStartWorldX: 0
                    property real dragStartWorldY: 0
                    property bool dragWasActive: false

                    readonly property bool selected:
                        monitor.output === root.selectedOutput

                    readonly property bool overlapping:
                        root.draftStore
                        && root.draftStore.outputHasOverlap(monitor.output)

                    visible:
                        monitor
                        && !monitor.disabled
                        && monitor.logicalWidth > 0
                        && monitor.logicalHeight > 0

                    x: root.canvasX(monitor.x)
                        + (dragHandler.active
                            ? dragHandler.activeTranslation.x
                            : 0)

                    y: root.canvasY(monitor.y)
                        + (dragHandler.active
                            ? dragHandler.activeTranslation.y
                            : 0)

                    width: Math.max(
                        56,
                        monitor.logicalWidth * root.topologyScale
                    )

                    height: Math.max(
                        38,
                        monitor.logicalHeight * root.topologyScale
                    )

                    radius: root.theme ? root.theme.radiusSmall : 8

                    color: {
                        if (monitorRect.overlapping) {
                            return root.theme
                                ? Qt.rgba(
                                    root.theme.error.r,
                                    root.theme.error.g,
                                    root.theme.error.b,
                                    0.18
                                )
                                : "#40242d";
                        }

                        if (monitorRect.selected) {
                            return root.theme
                                ? root.theme.surfaceAlt
                                : "#2d2d33";
                        }

                        return root.theme
                            ? root.theme.surface
                            : "#242429";
                    }

                    border.width: monitorRect.selected ? 2 : 1

                    border.color: {
                        if (monitorRect.overlapping) {
                            return root.theme
                                ? root.theme.error
                                : "#f38ba8";
                        }

                        if (monitorRect.selected) {
                            return root.theme
                                ? root.theme.accent
                                : "#89b4fa";
                        }

                        return root.theme
                            ? root.theme.border
                            : "#3b3b43";
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 2

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter

                            text: monitor.output

                            color: root.theme
                                ? root.theme.textPrimary
                                : "#f2f2f4"

                            font.pixelSize: 12
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter

                            text:
                                Math.round(monitor.logicalWidth)
                                + "×"
                                + Math.round(monitor.logicalHeight)

                            color: root.theme
                                ? root.theme.textSecondary
                                : "#b8b8c0"

                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter

                            text:
                                Math.round(monitor.x)
                                + ", "
                                + Math.round(monitor.y)

                            color: monitor.dirty
                                ? (root.theme
                                    ? root.theme.warning
                                    : "#f9e2af")
                                : (root.theme
                                    ? root.theme.textSecondary
                                    : "#b8b8c0")

                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }

                    TapHandler {
                        enabled: root.editorEnabled
                        onTapped: root.selectOutput(monitor.output)
                    }

                    DragHandler {
                        id: dragHandler

                        enabled: root.editorEnabled
                        target: null

                        cursorShape: active
                            ? Qt.ClosedHandCursor
                            : Qt.OpenHandCursor

                        onActiveChanged: {
                            if (active) {
                                monitorRect.dragWasActive = true;
                                monitorRect.dragStartWorldX = monitor.x;
                                monitorRect.dragStartWorldY = monitor.y;
                                root.selectOutput(monitor.output);
                                return;
                            }

                            if (!monitorRect.dragWasActive)
                                return;

                            monitorRect.dragWasActive = false;

                            root.commitDrag(
                                monitor.output,
                                monitorRect.dragStartWorldX,
                                monitorRect.dragStartWorldY,
                                activeTranslation.x,
                                activeTranslation.y
                            );
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.selectedOutput.length > 0
                    ? "Move " + root.selectedOutput + " relative to"
                    : "Select a display"

                color: root.theme
                    ? root.theme.textSecondary
                    : "#b8b8c0"

                font.pixelSize: 10
            }

            Components.JcChoiceGroup {
                Layout.fillWidth: true

                theme: root.theme
                options: root.anchorOptions
                selectedValue: root.anchorOutput
                controlEnabled:
                    root.editorEnabled
                    && root.anchorOptions.length > 0

                emptyText: "No anchor display"

                onValueSelected: value => {
                    root.anchorOutput = value;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Components.JcButton {
                theme: root.theme
                text: "← Left"
                compact: true

                controlEnabled:
                    root.editorEnabled
                    && root.anchorOutput.length > 0

                onClicked: root.snapSelected("left")
            }

            Components.JcButton {
                theme: root.theme
                text: "Right →"
                compact: true

                controlEnabled:
                    root.editorEnabled
                    && root.anchorOutput.length > 0

                onClicked: root.snapSelected("right")
            }

            Components.JcButton {
                theme: root.theme
                text: "↑ Above"
                compact: true

                controlEnabled:
                    root.editorEnabled
                    && root.anchorOutput.length > 0

                onClicked: root.snapSelected("above")
            }

            Components.JcButton {
                theme: root.theme
                text: "↓ Below"
                compact: true

                controlEnabled:
                    root.editorEnabled
                    && root.anchorOutput.length > 0

                onClicked: root.snapSelected("below")
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text:
                    "Negative coordinates are allowed."

                color: root.theme
                    ? root.theme.textSecondary
                    : "#b8b8c0"

                font.pixelSize: 9
            }
        }
    }
}
