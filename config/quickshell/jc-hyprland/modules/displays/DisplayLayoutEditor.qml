import QtQuick
import QtQuick.Layouts

import qs.components as Components

Components.JcSurface {
    id: root

    surfaceRole: "glass"
    bordered: false
    fillEnabled: false
    cornerRadius: root.theme.radiusMd

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

    readonly property real canvasPadding: root.theme.spaceLg
    readonly property real dpadButtonSize:

        root.theme.controlHeightCompact

    readonly property real dpadGap:

        root.theme.space2Xs

    readonly property real dpadPadding:

        root.theme.spaceSm

    readonly property real dpadPanelSize:

        (root.dpadButtonSize * 3)

        + (root.dpadGap * 2)

        + (root.dpadPadding * 2)

    readonly property real dpadReservedWidth:

        root.dpadPanelSize + root.theme.spaceMd


    readonly property real usableWidth:

        Math.max(

            1,

            canvas.width

                - (root.canvasPadding * 2)

                - root.dpadReservedWidth

        )

    readonly property real usableHeight:

        Math.max(1, canvas.height - root.canvasPadding * 2)


    readonly property real topologyScale:
        Math.min(
            root.usableWidth / root.topologyWidth,
            root.usableHeight / root.topologyHeight
        )

    readonly property var selectedOptions:
        root.buildSelectedOptions()

    readonly property var anchorOptions:
        root.buildAnchorOptions()

    // Two canonical ComboBoxes need four large-control units each.
    // Add content margins/spacing to derive the compact breakpoint from
    // semantic geometry rather than a physical-pixel magic number.
    readonly property real compactLayoutThreshold:
        (root.theme.controlHeightLarge * 8)
        + (root.theme.spaceMd * 3)

    readonly property bool compactLayout:
        root.width > 0
        && root.width < root.compactLayoutThreshold

    implicitHeight:
        contentColumn.implicitHeight
        + (root.theme.spaceMd * 2)

    function buildSelectedOptions() {
        const options = [];

        for (let i = 0; i < root.projectedMonitors.length; ++i) {
            const monitor = root.projectedMonitors[i];

            if (!monitor || monitor.disabled)
                continue;

            options.push({
                value: monitor.output,
                label: monitor.output
            });
        }

        return options;
    }

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

            if (monitor
                    && !monitor.disabled
                    && monitor.output === root.selectedOutput) {
                selectedExists = true;
                break;
            }
        }

        if (!selectedExists) {
            let nextSelectedOutput = "";

            for (let i = 0; i < root.projectedMonitors.length; ++i) {
                const monitor = root.projectedMonitors[i];

                if (monitor && !monitor.disabled) {
                    nextSelectedOutput = monitor.output;
                    break;
                }
            }

            root.selectedOutput = nextSelectedOutput;
        }

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

    Components.JcHudFrame {
        id: layoutHudFrame

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
        id: contentColumn

        anchors.fill: parent
        anchors.margins: root.theme.spaceMd
        spacing: root.theme.spaceSm

        RowLayout {
            Layout.fillWidth: true
            spacing: root.theme.spaceSm

            Components.JcSectionHeader {
                Layout.fillWidth: true

                theme: root.theme
                title: "Layout & position"
                subtitle:
                    "Drag a display or use the keyboard selectors below. "
                    + "Nearby edges and centers snap automatically."
            }

            Text {
                text: {
                    if (!root.draftStore)
                        return "Topology unavailable";

                    return root.draftStore.topologyValid
                        ? "Topology valid"
                        : "Layout conflict";
                }

                color: {
                    if (!root.draftStore)
                        return root.theme.textSecondary;

                    return root.draftStore.topologyValid
                        ? root.theme.success
                        : root.theme.danger;
                }

                font.family: root.theme.fontFamilySans
                font.pixelSize: root.theme.textSizeCaption
                font.weight: root.theme.fontWeightMedium
            }
        }

        Rectangle {
            id: canvas

            Layout.fillWidth: true
            Layout.preferredHeight: root.theme.controlHeightLarge * 5

            clip: true

            radius: root.theme.radiusMd
            color: root.theme.hudSurface

            border.width: root.theme.borderWidthThin
            border.color: root.theme.hudInnerFrame

            Item {
                id: topologyDPad

                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: root.theme.spaceMd
                anchors.rightMargin: root.theme.spaceMd

                width: root.dpadPanelSize
                height: root.dpadPanelSize

                z: 50

                Components.JcHudFrame {
                    anchors.fill: parent

                    theme: root.theme
                    surfaceRole: "glass-raised"

                    fillEnabled: true
                    fillColor: root.theme.hudSurfaceRaised
                    contentPadding: 0

                    cutSize: root.theme.spaceSm
                    accentLength: root.theme.controlHeightCompact

                    glowEnabled: true
                    showInnerFrame: true
                    showCornerAccents: true
                    showSecondaryAccent: false
                }

                GridLayout {
                    anchors.centerIn: parent

                    columns: 3
                    rows: 3

                    columnSpacing: root.dpadGap
                    rowSpacing: root.dpadGap

                    Components.JcIconButton {
                        Layout.row: 0
                        Layout.column: 1
                        Layout.preferredWidth: root.dpadButtonSize
                        Layout.preferredHeight: root.dpadButtonSize

                        theme: root.theme
                        compact: true

                        iconName: "above"
                        accessibleName: "Position display above"

                        controlEnabled:
                            root.editorEnabled
                            && root.anchorOutput.length > 0

                        onClicked: root.snapSelected("above")
                    }

                    Components.JcIconButton {
                        Layout.row: 1
                        Layout.column: 0
                        Layout.preferredWidth: root.dpadButtonSize
                        Layout.preferredHeight: root.dpadButtonSize

                        theme: root.theme
                        compact: true

                        iconName: "left"
                        accessibleName: "Position display left"

                        controlEnabled:
                            root.editorEnabled
                            && root.anchorOutput.length > 0

                        onClicked: root.snapSelected("left")
                    }

                    Components.JcIconButton {
                        id: recenterTopologyButton

                        Layout.row: 1
                        Layout.column: 1
                        Layout.preferredWidth: root.dpadButtonSize
                        Layout.preferredHeight: root.dpadButtonSize

                        theme: root.theme
                        compact: true

                        iconName: "center"
                        accessibleName: "Recenter topology"

                        controlEnabled:
                            root.projectedMonitors.length > 0

                        onClicked: root.recalculateBounds()
                    }

                    Components.JcIconButton {
                        Layout.row: 1
                        Layout.column: 2
                        Layout.preferredWidth: root.dpadButtonSize
                        Layout.preferredHeight: root.dpadButtonSize

                        theme: root.theme
                        compact: true

                        iconName: "right"
                        accessibleName: "Position display right"

                        controlEnabled:
                            root.editorEnabled
                            && root.anchorOutput.length > 0

                        onClicked: root.snapSelected("right")
                    }

                    Components.JcIconButton {
                        Layout.row: 2
                        Layout.column: 1
                        Layout.preferredWidth: root.dpadButtonSize
                        Layout.preferredHeight: root.dpadButtonSize

                        theme: root.theme
                        compact: true

                        iconName: "below"
                        accessibleName: "Position display below"

                        controlEnabled:
                            root.editorEnabled
                            && root.anchorOutput.length > 0

                        onClicked: root.snapSelected("below")
                    }
                }
            }

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

                    radius: root.theme.radiusSm

                    color: {
                        if (monitorRect.overlapping)
                            return root.theme.surfacePressed;

                        if (monitorRect.selected)
                            return root.theme.surfaceSelected;

                        return root.theme.surfaceInteractive;
                    }

                    border.width: monitorRect.selected
                        ? root.theme.borderWidthStrong
                        : root.theme.borderWidthThin

                    border.color: {
                        if (monitorRect.overlapping)
                            return root.theme.danger;

                        if (monitorRect.selected)
                            return root.theme.borderAccent;

                        return root.theme.borderDefault;
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: root.theme.motionSelection
                            easing.type: root.theme.easingStandard
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: root.theme.motionSelection
                            easing.type: root.theme.easingStandard
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - (root.theme.spaceSm * 2)
                        spacing: root.theme.space2Xs

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter

                            text: monitor.output
                            color: root.theme.textPrimary

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeBody
                            font.weight: root.theme.fontWeightSemibold

                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter

                            text:
                                Math.round(monitor.logicalWidth)
                                + "×"
                                + Math.round(monitor.logicalHeight)

                            color: root.theme.textSecondary

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeCaption
                            font.weight: root.theme.fontWeightRegular

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
                                ? root.theme.warning
                                : root.theme.textSecondary

                            font.family: root.theme.fontFamilySans
                            font.pixelSize: root.theme.textSizeCaption
                            font.weight: root.theme.fontWeightRegular

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

        GridLayout {
            id: topologySelectorGrid

            Layout.fillWidth: true

            columns: root.compactLayout ? 1 : 2
            columnSpacing: root.theme.spaceSm
            rowSpacing: root.theme.space2Xs

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    Layout.fillWidth: true

                    text: "Selected display"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightRegular
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    options: root.selectedOptions
                    selectedValue: root.selectedOutput
                    placeholder: root.selectedOptions.length > 0
                        ? "Select display"
                        : "No active display"

                    controlEnabled:
                        root.editorEnabled
                        && root.selectedOptions.length > 0

                    onValueSelected: value =>
                        root.selectOutput(value)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.theme.space2Xs

                Text {
                    Layout.fillWidth: true

                    text: "Relative to"
                    color: root.theme.textSecondary

                    font.family: root.theme.fontFamilySans
                    font.pixelSize: root.theme.textSizeCaption
                    font.weight: root.theme.fontWeightRegular
                }

                Components.JcComboBox {
                    Layout.fillWidth: true

                    theme: root.theme
                    compact: true
                    options: root.anchorOptions
                    selectedValue: root.anchorOutput
                    placeholder: root.anchorOptions.length > 0
                        ? "Select reference display"
                        : "No reference display"

                    controlEnabled:
                        root.editorEnabled
                        && root.anchorOptions.length > 0

                    onValueSelected: value => {
                        root.anchorOutput = value;
                    }
                }
            }
        }


        Text {
            Layout.fillWidth: true

            text: "Negative coordinates are allowed."
            color: root.theme.textMuted

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeCaption
            font.weight: root.theme.fontWeightRegular
            wrapMode: Text.WordWrap
        }
    }
}
