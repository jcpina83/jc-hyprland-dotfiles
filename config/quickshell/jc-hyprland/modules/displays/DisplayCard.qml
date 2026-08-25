import QtQuick
import QtQuick.Layouts

import qs.components as Components

Components.JcCard {
    id: root

    property var monitor
    property var draftStore
    property bool editorEnabled: true

    readonly property var draft:
        root.monitor && root.draftStore
            ? root.draftStore.draftFor(root.monitor.output)
            : null

    readonly property var resolutionOptions:
        root.monitor && root.draftStore
            ? root.draftStore.resolutionOptionsFor(root.monitor.output)
            : []

    readonly property var refreshOptions:
        root.monitor && root.draftStore
            ? root.draftStore.refreshOptionsFor(root.monitor.output)
            : []

    readonly property var scaleOptions:
        root.monitor && root.draftStore
            ? root.draftStore.scaleOptionsFor(root.monitor.output)
            : []

    readonly property var transformOptions:
        root.monitor && root.draftStore
            ? root.draftStore.transformOptionsFor(root.monitor.output)
            : []

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
                text: root.monitor && root.monitor.disabled
                    ? "Disabled"
                    : "Active"

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
                    .filter(function(value) {
                        return value.length > 0;
                    })
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
                text: "Current mode"
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
                text: "Orientation"
                color: root.theme ? root.theme.textSecondary : "#b8b8c0"
                font.pixelSize: 12
            }

            Text {
                text: root.monitor && root.draftStore
                    ? root.draftStore.transformLabel(root.monitor.transform)
                    : "—"

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

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: root.theme ? root.theme.border : "#3b3b43"
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true

                text: "Draft settings"
                color: root.theme ? root.theme.textPrimary : "#f2f2f4"
                font.pixelSize: 13
                font.bold: true
            }

            Text {
                text: root.draft && root.draft.dirty
                    ? "Modified"
                    : "Matches current"

                color: root.draft && root.draft.dirty
                    ? (root.theme ? root.theme.warning : "#f9e2af")
                    : (root.theme ? root.theme.success : "#a6e3a1")

                font.pixelSize: 11
                font.bold: true
            }
        }

        Text {
            text: "Resolution"
            color: root.theme ? root.theme.textSecondary : "#b8b8c0"
            font.pixelSize: 11
        }

        Components.JcChoiceGroup {
            Layout.fillWidth: true

            theme: root.theme
            options: root.resolutionOptions
            selectedValue: root.draft ? root.draft.resolutionKey : ""
            controlEnabled: root.editorEnabled
            emptyText: "No valid resolutions reported"

            onValueSelected: value => {
                if (root.monitor && root.draftStore)
                    root.draftStore.setResolution(root.monitor.output, value);
            }
        }

        Text {
            text: "Refresh rate"
            color: root.theme ? root.theme.textSecondary : "#b8b8c0"
            font.pixelSize: 11
        }

        Components.JcChoiceGroup {
            Layout.fillWidth: true

            theme: root.theme
            options: root.refreshOptions
            selectedValue: root.draft ? root.draft.modeRaw : ""
            controlEnabled: root.editorEnabled
            emptyText: "No valid refresh rates reported"

            onValueSelected: value => {
                if (root.monitor && root.draftStore)
                    root.draftStore.setRefreshMode(root.monitor.output, value);
            }
        }

        Text {
            text: "Scale"
            color: root.theme ? root.theme.textSecondary : "#b8b8c0"
            font.pixelSize: 11
        }

        Components.JcChoiceGroup {
            Layout.fillWidth: true

            theme: root.theme
            options: root.scaleOptions
            selectedValue: root.draft ? String(root.draft.scale) : ""
            controlEnabled: root.editorEnabled
            emptyText: "No valid scales for this resolution"

            onValueSelected: value => {
                if (root.monitor && root.draftStore)
                    root.draftStore.setScale(root.monitor.output, value);
            }
        }

        Text {
            text: "Orientation"
            color: root.theme ? root.theme.textSecondary : "#b8b8c0"
            font.pixelSize: 11
        }

        Components.JcChoiceGroup {
            Layout.fillWidth: true

            theme: root.theme
            options: root.transformOptions
            selectedValue: root.draft ? String(root.draft.transform) : ""
            controlEnabled: root.editorEnabled
            emptyText: "No valid orientation options"

            onValueSelected: value => {
                if (root.monitor && root.draftStore)
                    root.draftStore.setTransform(root.monitor.output, value);
            }
        }

        Text {
            Layout.fillWidth: true

            text: {
                if (!root.draft || !root.draftStore)
                    return "Draft unavailable";

                const logical = root.draftStore.logicalSize(
                    root.draft.width,
                    root.draft.height,
                    root.draft.scale,
                    root.draft.transform
                );

                return "Draft: "
                    + root.draft.width + "×" + root.draft.height
                    + " @ " + root.draft.refreshRate.toFixed(2) + " Hz"
                    + " · " + Number(root.draft.scale).toFixed(2) + "×"
                    + " · "
                    + root.draftStore.transformLabel(root.draft.transform)
                    + " · logical "
                    + Math.round(logical.width)
                    + "×" + Math.round(logical.height);
            }

            color: root.theme ? root.theme.accent : "#89b4fa"
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true

            text:
                "Options marked “move required” can be selected. Use the "
                + "visual layout editor to resolve any overlap before Safe Apply."

            color: root.theme ? root.theme.textSecondary : "#b8b8c0"
            font.pixelSize: 10
            wrapMode: Text.Wrap
        }
    }
}
