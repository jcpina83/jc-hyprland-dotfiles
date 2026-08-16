import QtQuick
import QtQuick.Layouts

import qs.components as Components

Components.JcCard {
    id: root

    property var monitor

    implicitHeight: content.implicitHeight + 28

    ColumnLayout {
        id: content

        anchors.fill: parent
        anchors.margins: 14
        spacing: root.theme ? root.theme.spacingSm : 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                width: 10
                height: 10
                radius: 5

                color: root.monitor && root.monitor.focused
                    ? (root.theme ? root.theme.accent : "#89b4fa")
                    : (root.theme ? root.theme.textSecondary : "#b8b8c0")
            }

            Text {
                Layout.fillWidth: true

                text: root.monitor && root.monitor.output.length > 0
                    ? root.monitor.output
                    : "Unknown output"

                color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                font.pixelSize: 16
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                text: root.monitor && root.monitor.disabled ? "Disabled" : "Active"

                color: root.monitor && root.monitor.disabled
                    ? (root.theme ? root.theme.warning : "#f9e2af")
                    : (root.theme ? root.theme.success : "#a6e3a1")

                font.pixelSize: 12
            }
        }

        Text {
            Layout.fillWidth: true

            text: {
                if (!root.monitor)
                    return "";

                if (root.monitor.description.length > 0)
                    return root.monitor.description;

                return [root.monitor.make, root.monitor.model]
                    .filter(value => value.length > 0)
                    .join(" ");
            }

            color: root.theme ? root.theme.textSecondary : "#b8b8c0"
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 6

            Text {
                text: "Mode"
                color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                font.pixelSize: 12
            }

            Text {
                text: root.monitor
                    ? root.monitor.width + "×" + root.monitor.height
                        + " @ " + root.monitor.refreshRate.toFixed(2) + " Hz"
                    : "—"

                color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                font.pixelSize: 12
            }

            Text {
                text: "Scale"
                color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                font.pixelSize: 12
            }

            Text {
                text: root.monitor ? root.monitor.scale.toFixed(2) : "—"
                color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                font.pixelSize: 12
            }

            Text {
                text: "Logical size"
                color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                font.pixelSize: 12
            }

            Text {
                text: root.monitor
                    ? Math.round(root.monitor.logicalWidth)
                        + "×" + Math.round(root.monitor.logicalHeight)
                    : "—"

                color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                font.pixelSize: 12
            }

            Text {
                text: "Position"
                color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                font.pixelSize: 12
            }

            Text {
                text: root.monitor
                    ? root.monitor.x + " × " + root.monitor.y
                    : "—"

                color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                font.pixelSize: 12
            }

            Text {
                text: "Available modes"
                color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                font.pixelSize: 12
            }

            Text {
                text: root.monitor && root.monitor.availableModes
                    ? String(root.monitor.availableModes.length)
                    : "0"

                color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                font.pixelSize: 12
            }
        }
    }
}
