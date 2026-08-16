import QtQuick

import qs.components as Components

Components.JcCard {
    id: root

    property var monitors: []

    property real minimumX: 0
    property real minimumY: 0
    property real maximumX: 1
    property real maximumY: 1

    readonly property real topologyWidth:
        Math.max(1, maximumX - minimumX)
    readonly property real topologyHeight:
        Math.max(1, maximumY - minimumY)

    readonly property real canvasPadding: 18
    readonly property real usableWidth:
        Math.max(1, width - canvasPadding * 2)
    readonly property real usableHeight:
        Math.max(1, height - canvasPadding * 2)

    readonly property real topologyScale:
        Math.min(usableWidth / topologyWidth, usableHeight / topologyHeight)

    implicitHeight: 210

    function recalculateBounds(): void {
        if (!root.monitors || root.monitors.length === 0) {
            root.minimumX = 0;
            root.minimumY = 0;
            root.maximumX = 1;
            root.maximumY = 1;
            return;
        }

        let minX = Number.POSITIVE_INFINITY;
        let minY = Number.POSITIVE_INFINITY;
        let maxX = Number.NEGATIVE_INFINITY;
        let maxY = Number.NEGATIVE_INFINITY;

        let activeFound = false;

        for (let i = 0; i < root.monitors.length; ++i) {
            const monitor = root.monitors[i];

            if (monitor.disabled || monitor.logicalWidth <= 0
                    || monitor.logicalHeight <= 0)
                continue;

            activeFound = true;

            minX = Math.min(minX, monitor.x);
            minY = Math.min(minY, monitor.y);
            maxX = Math.max(maxX, monitor.x + monitor.logicalWidth);
            maxY = Math.max(maxY, monitor.y + monitor.logicalHeight);
        }

        if (!activeFound) {
            root.minimumX = 0;
            root.minimumY = 0;
            root.maximumX = 1;
            root.maximumY = 1;
            return;
        }

        root.minimumX = minX;
        root.minimumY = minY;
        root.maximumX = maxX;
        root.maximumY = maxY;
    }

    onMonitorsChanged: recalculateBounds()
    Component.onCompleted: recalculateBounds()

    Repeater {
        model: root.monitors || []

        delegate: Rectangle {
            property var monitor: modelData

            visible: monitor
                && !monitor.disabled
                && monitor.logicalWidth > 0
                && monitor.logicalHeight > 0

            x: root.canvasPadding
                + (monitor.x - root.minimumX) * root.topologyScale

            y: root.canvasPadding
                + (monitor.y - root.minimumY) * root.topologyScale

            width: Math.max(50, monitor.logicalWidth * root.topologyScale)
            height: Math.max(32, monitor.logicalHeight * root.topologyScale)

            radius: root.theme ? root.theme.radiusSmall : 8

            color: monitor.focused
                ? (root.theme ? root.theme.surfaceAlt : "#2d2d33")
                : (root.theme ? root.theme.surface : "#242429")

            border.width: monitor.focused ? 2 : 1

            border.color: monitor.focused
                ? (root.theme ? root.theme.accent : "#89b4fa")
                : (root.theme ? root.theme.border : "#3b3b43")

            Column {
                anchors.centerIn: parent
                width: parent.width - 12
                spacing: 2

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: monitor.output
                    color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                    font.pixelSize: 12
                    font.bold: true
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter

                    text: Math.round(monitor.logicalWidth)
                        + "×" + Math.round(monitor.logicalHeight)

                    color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }
        }
    }
}
