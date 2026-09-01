import QtQuick

Item {
    id: root

    required property var theme
    property var themeData

    readonly property var colorData:
        root.themeData
        && root.themeData.colors
        ? root.themeData.colors
        : null

    readonly property var opacityData:
        root.themeData
        && root.themeData.opacity
        ? root.themeData.opacity
        : null

    readonly property string previewName:
        root.themeData
        ? String(root.themeData.name || root.themeData.id || "Theme")
        : "Theme"

    readonly property bool tokenDataReady:
        root.themeData
        && Number(root.themeData.schemaVersion || 0) === 1
        && root.colorData !== null
        && root.opacityData !== null

    function colorToken(name, fallback) {
        if (root.colorData
                && root.colorData[name] !== undefined
                && root.colorData[name] !== "")
            return root.colorData[name];

        return fallback;
    }

    function opacityToken(name, fallback) {
        if (!root.opacityData || root.opacityData[name] === undefined)
            return fallback;

        const value = Number(root.opacityData[name]);

        if (!Number.isFinite(value))
            return fallback;

        return Math.max(0.0, Math.min(1.0, value));
    }

    readonly property color canvas:
        root.colorToken("canvas", root.theme.canvas)

    readonly property color canvasAlt:
        root.colorToken("canvasAlt", root.theme.canvasAlt)

    readonly property color surfaceBase:
        root.colorToken("surfaceBase", root.theme.surfaceBase)

    readonly property color surfaceRaised:
        root.colorToken("surfaceRaised", root.theme.surfaceRaised)

    readonly property color surfaceInteractive:
        root.colorToken(
            "surfaceInteractive",
            root.theme.surfaceInteractive
        )

    readonly property color textPrimary:
        root.colorToken("textPrimary", root.theme.textPrimary)

    readonly property color textSecondary:
        root.colorToken("textSecondary", root.theme.textSecondary)

    readonly property color textMuted:
        root.colorToken("textMuted", root.theme.textMuted)

    readonly property color primary:
        root.colorToken("primary", root.theme.primary)

    readonly property color secondary:
        root.colorToken("secondary", root.theme.secondary)

    readonly property color accent:
        root.colorToken("accent", root.theme.accent)

    readonly property color success:
        root.colorToken("success", root.theme.success)

    readonly property color warning:
        root.colorToken("warning", root.theme.warning)

    readonly property color danger:
        root.colorToken("danger", root.theme.danger)

    readonly property color info:
        root.colorToken("info", root.theme.info)

    readonly property color surfaceGlass: Qt.rgba(
        root.canvas.r,
        root.canvas.g,
        root.canvas.b,
        root.opacityToken("surfaceGlass", 0.78)
    )

    readonly property color surfaceGlassRaised: Qt.rgba(
        root.surfaceBase.r,
        root.surfaceBase.g,
        root.surfaceBase.b,
        root.opacityToken("surfaceGlassRaised", 0.86)
    )

    readonly property color surfaceSelected: Qt.rgba(
        root.accent.r,
        root.accent.g,
        root.accent.b,
        root.opacityToken("surfaceSelected", 0.16)
    )

    readonly property color borderStrong: Qt.rgba(
        root.primary.r,
        root.primary.g,
        root.primary.b,
        root.opacityToken("borderStrong", 0.38)
    )

    readonly property color borderAccent: Qt.rgba(
        root.accent.r,
        root.accent.g,
        root.accent.b,
        root.opacityToken("borderAccent", 0.34)
    )

    Rectangle {
        anchors.fill: parent

        color: root.surfaceGlass
        radius: root.theme.radiusMd

        border {
            width: root.theme.borderWidthThin
            color: root.borderStrong
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                margins: root.theme.spaceSm
            }

            width: Math.max(
                root.theme.controlHeightLarge,
                parent.width * 0.22
            )

            radius: root.theme.radiusSm
            color: root.surfaceGlassRaised

            border {
                width: root.theme.borderWidthThin
                color: root.borderStrong
            }

            Column {
                anchors {
                    fill: parent
                    margins: root.theme.spaceXs
                }

                spacing: root.theme.spaceXs

                Rectangle {
                    width: parent.width
                    height: root.theme.spaceXs
                    radius: root.theme.radiusPill
                    color: root.primary
                }

                Rectangle {
                    width: parent.width
                    height: root.theme.controlHeightCompact
                    radius: root.theme.radiusSm
                    color: root.surfaceSelected

                    border {
                        width: root.theme.borderWidthThin
                        color: root.borderAccent
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "UI"
                        color: root.accent
                        font.pixelSize: root.theme.textSizeCaption
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    width: parent.width
                    height: root.theme.controlHeightCompact
                    radius: root.theme.radiusSm
                    color: root.surfaceInteractive

                    Text {
                        anchors.centerIn: parent

                        text: "Aa"
                        color: root.textSecondary
                        font.pixelSize: root.theme.textSizeCaption
                    }
                }
            }
        }

        Column {
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                leftMargin:
                    Math.max(
                        root.theme.controlHeightLarge,
                        parent.width * 0.22
                    )
                    + root.theme.spaceMd
                rightMargin: root.theme.spaceSm
                topMargin: root.theme.spaceSm
                bottomMargin: root.theme.spaceSm
            }

            spacing: root.theme.spaceXs

            Text {
                width: parent.width

                text: root.previewName
                color: root.textPrimary
                font.pixelSize: root.theme.textSizeBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width

                text: "Semantic token preview"
                color: root.textMuted
                font.pixelSize: root.theme.textSizeCaption
                elide: Text.ElideRight
            }

            Row {
                width: parent.width
                spacing: root.theme.spaceXs

                Repeater {
                    model: [
                        root.primary,
                        root.secondary,
                        root.accent
                    ]

                    Rectangle {
                        required property var modelData

                        width:
                            (parent.width - root.theme.spaceXs * 2)
                            / 3

                        height: root.theme.spaceXs
                        radius: root.theme.radiusPill
                        color: modelData
                    }
                }
            }

            Row {
                width: parent.width
                height: root.theme.controlHeightLarge
                spacing: root.theme.spaceXs

                Rectangle {
                    width:
                        (parent.width - root.theme.spaceXs)
                        * 0.58

                    height: parent.height
                    radius: root.theme.radiusSm
                    color: root.surfaceRaised

                    border {
                        width: root.theme.borderWidthThin
                        color: root.borderStrong
                    }

                    Column {
                        anchors {
                            fill: parent
                            margins: root.theme.spaceXs
                        }

                        spacing: root.theme.space2Xs

                        Rectangle {
                            width: parent.width * 0.72
                            height: root.theme.space2Xs
                            radius: root.theme.radiusPill
                            color: root.textPrimary
                        }

                        Rectangle {
                            width: parent.width
                            height: root.theme.space2Xs
                            radius: root.theme.radiusPill
                            color: root.textSecondary
                        }

                        Rectangle {
                            width: parent.width * 0.62
                            height: root.theme.space2Xs
                            radius: root.theme.radiusPill
                            color: root.textMuted
                        }
                    }
                }

                Rectangle {
                    width:
                        (parent.width - root.theme.spaceXs)
                        * 0.42

                    height: parent.height
                    radius: root.theme.radiusSm
                    color: root.surfaceSelected

                    border {
                        width: root.theme.borderWidthThin
                        color: root.borderAccent
                    }

                    Text {
                        anchors.centerIn: parent

                        text: "ACTIVE"
                        color: root.accent
                        font.pixelSize: root.theme.textSizeCaption
                        font.weight: Font.DemiBold
                    }
                }
            }

            Row {
                spacing: root.theme.spaceSm

                Repeater {
                    model: [
                        root.success,
                        root.warning,
                        root.danger,
                        root.info
                    ]

                    Rectangle {
                        required property var modelData

                        width: root.theme.spaceSm
                        height: root.theme.spaceSm
                        radius: width / 2
                        color: modelData
                    }
                }
            }
        }
    }
}
