import QtQuick

Item {
    id: root

    required property var theme

    // JcHudFrame is a presentation primitive.
    // It owns no feature state and executes no runtime commands.
    default property alias contentData: contentItem.data

    property string surfaceRole: "glass"

    property bool selected: false
    property bool focused: false
    property bool bordered: true

    property bool showInnerFrame: true
    property bool showCornerAccents: true
    property bool showSecondaryAccent: true
    property bool glowEnabled: true
    property bool fillEnabled: true

    property color primaryAccentColor:
        root.theme.primary

    property color secondaryAccentColor:
        root.theme.hudSecondaryAccent

    property color fillColor:
        root.resolvedSurfaceColor

    property color frameColor:
        root.resolvedFrameColor

    property int cutSize: root.theme.spaceMd
    property int contentPadding: root.theme.spaceMd
    property int frameWidth: root.theme.borderWidthThin
    property int accentLength:
        root.theme.controlHeightDefault + root.theme.spaceLg

    // Optical glints are deliberately short and tapered. They live on the
    // perimeter itself instead of appearing as independent overlay bars.
    property real glintIntensity: {
        if (root.focused)
            return 1.0;

        if (root.selected)
            return 0.84;

        return 0.66;
    }

    property real glintCoreWidth:
        Math.max(
            root.theme.borderWidthStrong,
            root.frameWidth
        )

    property real glintHaloWidth:
        root.theme.borderWidthStrong * 4.0

    readonly property color resolvedSurfaceColor: {
        switch (root.surfaceRole) {
        case "raised":
        case "glass-raised":
            return root.theme.hudSurfaceRaised;
        case "glass":
        case "base":
        default:
            return root.theme.hudSurface;
        }
    }

    readonly property color resolvedFrameColor: {
        if (root.focused)
            return root.theme.borderFocus;

        if (root.selected)
            return root.theme.borderAccent;

        return root.theme.hudFrame;
    }

    readonly property color resolvedInnerFrameColor:
        root.theme.hudInnerFrame

    implicitWidth:
        Math.max(
            contentItem.implicitWidth + (root.contentPadding * 2),
            root.theme.controlHeightLarge * 4
        )

    implicitHeight:
        Math.max(
            contentItem.implicitHeight + (root.contentPadding * 2),
            root.theme.controlHeightLarge * 2
        )

    function traceFrame(ctx, inset, cut) {
        const left = inset;
        const top = inset;
        const right = Math.max(left, root.width - inset);
        const bottom = Math.max(top, root.height - inset);

        const usableCut = Math.max(
            0,
            Math.min(
                cut,
                Math.max(0, (right - left) / 3),
                Math.max(0, (bottom - top) / 3)
            )
        );

        ctx.beginPath();
        ctx.moveTo(left + usableCut, top);
        ctx.lineTo(right - usableCut, top);
        ctx.lineTo(right, top + usableCut);
        ctx.lineTo(right, bottom - usableCut);
        ctx.lineTo(right - usableCut, bottom);
        ctx.lineTo(left + usableCut, bottom);
        ctx.lineTo(left, bottom - usableCut);
        ctx.lineTo(left, top + usableCut);
        ctx.closePath();
    }

    function colorToCss(colorValue, alphaScale) {
        const r = Math.round(colorValue.r * 255);
        const g = Math.round(colorValue.g * 255);
        const b = Math.round(colorValue.b * 255);
        const a = Math.max(
            0.0,
            Math.min(
                1.0,
                colorValue.a * alphaScale
            )
        );

        return "rgba("
            + r + ","
            + g + ","
            + b + ","
            + a + ")";
    }

    function drawGlint(
        ctx,
        startX,
        endX,
        y,
        colorValue,
        intensity,
        haloWidth,
        coreWidth
    ) {
        if (endX <= startX)
            return;

        // Wide low-alpha pass: optical bloom attached to the border.
        let haloGradient =
            ctx.createLinearGradient(
                startX,
                y,
                endX,
                y
            );

        haloGradient.addColorStop(
            0.0,
            root.colorToCss(colorValue, 0.0)
        );
        haloGradient.addColorStop(
            0.18,
            root.colorToCss(
                colorValue,
                0.18 * intensity
            )
        );
        haloGradient.addColorStop(
            0.48,
            root.colorToCss(
                colorValue,
                0.42 * intensity
            )
        );
        haloGradient.addColorStop(
            0.72,
            root.colorToCss(
                colorValue,
                0.20 * intensity
            )
        );
        haloGradient.addColorStop(
            1.0,
            root.colorToCss(colorValue, 0.0)
        );

        ctx.beginPath();
        ctx.moveTo(startX, y);
        ctx.lineTo(endX, y);

        ctx.strokeStyle = haloGradient;
        ctx.lineWidth = haloWidth;
        ctx.lineCap = "round";
        ctx.stroke();

        // Thin bright core: concentrated near the center, with no hard ends.
        let coreGradient =
            ctx.createLinearGradient(
                startX,
                y,
                endX,
                y
            );

        coreGradient.addColorStop(
            0.0,
            root.colorToCss(colorValue, 0.0)
        );
        coreGradient.addColorStop(
            0.20,
            root.colorToCss(
                colorValue,
                0.42 * intensity
            )
        );
        coreGradient.addColorStop(
            0.48,
            root.colorToCss(
                colorValue,
                1.0 * intensity
            )
        );
        coreGradient.addColorStop(
            0.68,
            root.colorToCss(
                colorValue,
                0.58 * intensity
            )
        );
        coreGradient.addColorStop(
            1.0,
            root.colorToCss(colorValue, 0.0)
        );

        ctx.beginPath();
        ctx.moveTo(startX, y);
        ctx.lineTo(endX, y);

        ctx.strokeStyle = coreGradient;
        ctx.lineWidth = coreWidth;
        ctx.lineCap = "round";
        ctx.stroke();
    }

    function repaintFrames() {
        glowCanvas.requestPaint();
        frameCanvas.requestPaint();
    }

    onWidthChanged: root.repaintFrames()
    onHeightChanged: root.repaintFrames()
    onResolvedSurfaceColorChanged: root.repaintFrames()
    onResolvedFrameColorChanged: root.repaintFrames()
    onResolvedInnerFrameColorChanged: root.repaintFrames()
    onCutSizeChanged: root.repaintFrames()
    onFrameWidthChanged: root.repaintFrames()
    onAccentLengthChanged: root.repaintFrames()
    onBorderedChanged: root.repaintFrames()
    onSelectedChanged: root.repaintFrames()
    onFocusedChanged: root.repaintFrames()
    onShowInnerFrameChanged: root.repaintFrames()
    onShowCornerAccentsChanged: root.repaintFrames()
    onShowSecondaryAccentChanged: root.repaintFrames()
    onGlowEnabledChanged: root.repaintFrames()
    onFillEnabledChanged: root.repaintFrames()
    onPrimaryAccentColorChanged: root.repaintFrames()
    onSecondaryAccentColorChanged: root.repaintFrames()
    onFillColorChanged: root.repaintFrames()
    onFrameColorChanged: root.repaintFrames()
    onGlintIntensityChanged: root.repaintFrames()
    onGlintCoreWidthChanged: root.repaintFrames()
    onGlintHaloWidthChanged: root.repaintFrames()

    Canvas {
        id: glowCanvas

        anchors.fill: parent
        anchors.margins: -root.theme.spaceSm

        visible: root.glowEnabled
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");

            ctx.clearRect(0, 0, width, height);

            ctx.save();
            ctx.translate(
                root.theme.spaceSm,
                root.theme.spaceSm
            );

            // Very restrained full-frame haze. Local glints in frameCanvas
            // provide the bright energy; this layer only separates the frame
            // from the wallpaper.
            const passes = [
                {
                    width:
                        root.theme.borderWidthStrong * 4,
                    color:
                        root.theme.hudGlowSoft
                },
                {
                    width:
                        root.theme.borderWidthStrong * 2,
                    color:
                        root.theme.hudGlowMedium
                }
            ];

            for (let i = 0; i < passes.length; ++i) {
                root.traceFrame(
                    ctx,
                    passes[i].width / 2,
                    root.cutSize
                );

                ctx.strokeStyle = passes[i].color;
                ctx.lineWidth = passes[i].width;
                ctx.stroke();
            }

            ctx.restore();
        }
    }

    Canvas {
        id: frameCanvas

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");

            ctx.clearRect(0, 0, width, height);

            root.traceFrame(
                ctx,
                root.frameWidth / 2,
                root.cutSize
            );

            if (root.fillEnabled) {
                ctx.fillStyle = root.fillColor;
                ctx.fill();
            }

            if (root.selected && root.fillEnabled) {
                root.traceFrame(
                    ctx,
                    root.frameWidth / 2,
                    root.cutSize
                );

                ctx.fillStyle =
                    root.theme.hudSelectedSurface;
                ctx.fill();
            }

            if (root.bordered) {
                root.traceFrame(
                    ctx,
                    root.frameWidth / 2,
                    root.cutSize
                );

                ctx.strokeStyle = root.frameColor;
                ctx.lineWidth = root.frameWidth;
                ctx.stroke();
            }

            if (root.showInnerFrame) {
                const inset =
                    root.theme.space2Xs
                    + root.frameWidth;

                root.traceFrame(
                    ctx,
                    inset,
                    Math.max(
                        root.theme.spaceXs,
                        root.cutSize - root.theme.space2Xs
                    )
                );

                ctx.strokeStyle =
                    root.resolvedInnerFrameColor;
                ctx.lineWidth =
                    root.theme.borderWidthThin;
                ctx.stroke();
            }

            if (root.showCornerAccents) {
                const topY =
                    root.frameWidth / 2;

                const topStart =
                    root.cutSize
                    + root.theme.spaceSm;

                const topMaxLength =
                    Math.min(
                        root.accentLength,
                        root.width * 0.20
                    );

                const topEnd =
                    Math.min(
                        root.width
                            - root.cutSize
                            - root.theme.spaceMd,
                        topStart + topMaxLength
                    );

                root.drawGlint(
                    ctx,
                    topStart,
                    topEnd,
                    topY,
                    root.primaryAccentColor,
                    root.glintIntensity,
                    root.glintHaloWidth,
                    root.glintCoreWidth
                );

                if (root.showSecondaryAccent) {
                    const bottomY =
                        root.height
                        - (root.frameWidth / 2);

                    const amberLength =
                        Math.min(
                            root.accentLength * 0.34,
                            root.width * 0.08
                        );

                    const amberEnd =
                        root.width
                        - root.cutSize
                        - root.theme.spaceSm;

                    const amberStart =
                        Math.max(
                            root.cutSize
                                + root.theme.spaceSm,
                            amberEnd - amberLength
                        );

                    root.drawGlint(
                        ctx,
                        amberStart,
                        amberEnd,
                        bottomY,
                        root.secondaryAccentColor,
                        root.glintIntensity * 0.58,
                        root.glintHaloWidth * 0.55,
                        root.theme.borderWidthThin
                    );
                }
            }
        }
    }

    Item {
        id: contentItem

        anchors.fill: parent
        anchors.margins: root.contentPadding

        z: 1
    }
}
