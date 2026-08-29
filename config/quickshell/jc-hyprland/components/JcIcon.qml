import QtQuick

Item {
    id: root

    required property var theme

    property string name: ""
    property string glyph: ""
    property color iconColor: root.theme.controlIconDefault
    property int iconSize: root.theme.iconSizeMd
    property bool emphasized: false

    readonly property var vectorNames: [
        "close",
        "refresh",
        "apply",
        "reset",
        "save",
        "keep",
        "revert",
        "fit",
        "fill",
        "stretch",
        "center",
        "left",
        "right",
        "above",
        "below",
        "display",
        "wallpaper",
        "theme",
        "settings",
        "performance",
        "media",
        "network",
        "notifications",
        "all",
        "library",
        "favorite",
        "power"
    ]

    readonly property bool vectorKnown:
        root.vectorNames.indexOf(root.name) >= 0

    readonly property bool useVector:
        root.glyph.length === 0
        && root.vectorKnown

    // Compatibility fallback. Semantic names normally render through Canvas;
    // callers that explicitly provide glyph still get the historical Text path.
    readonly property string resolvedGlyph: {
        if (root.glyph.length > 0)
            return root.glyph;

        switch (root.name) {
        case "close": return "×";
        case "refresh": return "↻";
        case "apply": return "✓";
        case "reset": return "↶";
        case "save": return "◇";
        case "keep": return "✓";
        case "revert": return "↶";
        case "fit": return "⌑";
        case "fill": return "▣";
        case "stretch": return "↔";
        case "center": return "⊙";
        case "left": return "←";
        case "right": return "→";
        case "above": return "↑";
        case "below": return "↓";
        case "display": return "▣";
        case "wallpaper": return "▧";
        case "theme": return "◐";
        case "settings": return "⚙";
        case "performance": return "◇";
        case "media": return "♪";
        case "network": return "⌁";
        case "notifications": return "●";
        case "all": return "▦";
        case "library": return "▰";
        case "favorite": return "★";
        case "power": return "⏻";
        default: return "";
        }
    }

    implicitWidth: root.iconSize
    implicitHeight: root.iconSize

    function lineWidth() {
        const baseWidth = 24 * root.theme.iconStrokeRatio;

        return root.emphasized
            ? baseWidth * root.theme.iconEmphasisStrokeScale
            : baseWidth;
    }

    function beginStroke(ctx) {
        ctx.beginPath();
        ctx.strokeStyle = root.iconColor;
        ctx.fillStyle = root.iconColor;
        ctx.lineWidth = root.lineWidth();
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
    }

    function strokePolyline(ctx, points, closePath) {
        if (!points || points.length < 2)
            return;

        root.beginStroke(ctx);
        ctx.moveTo(points[0][0], points[0][1]);

        for (let i = 1; i < points.length; ++i)
            ctx.lineTo(points[i][0], points[i][1]);

        if (closePath)
            ctx.closePath();

        ctx.stroke();
    }

    function drawArrow(ctx, x1, y1, x2, y2, headSize) {
        const angle = Math.atan2(y2 - y1, x2 - x1);
        const spread = Math.PI * 0.78;

        root.beginStroke(ctx);
        ctx.moveTo(x1, y1);
        ctx.lineTo(x2, y2);
        ctx.moveTo(
            x2 + Math.cos(angle + spread) * headSize,
            y2 + Math.sin(angle + spread) * headSize
        );
        ctx.lineTo(x2, y2);
        ctx.lineTo(
            x2 + Math.cos(angle - spread) * headSize,
            y2 + Math.sin(angle - spread) * headSize
        );
        ctx.stroke();
    }

    function drawRefresh(ctx, reversed) {
        root.beginStroke(ctx);

        if (!reversed) {
            ctx.arc(12, 12, 7.1, -0.78, Math.PI * 1.45, false);
            ctx.stroke();

            root.strokePolyline(
                ctx,
                [[17.1, 4.9], [18.7, 8.1], [15.1, 7.9]],
                false
            );
        } else {
            ctx.arc(12, 12, 7.1, -2.36, Math.PI * 0.78, true);
            ctx.stroke();

            root.strokePolyline(
                ctx,
                [[6.9, 4.9], [5.3, 8.1], [8.9, 7.9]],
                false
            );
        }
    }

    function drawCornerFrame(ctx, inset) {
        const a = inset;
        const b = 7.5;
        const c = 24 - inset;
        const d = 16.5;

        root.strokePolyline(ctx, [[b, a], [a, a], [a, b]], false);
        root.strokePolyline(ctx, [[d, a], [c, a], [c, b]], false);
        root.strokePolyline(ctx, [[a, d], [a, c], [b, c]], false);
        root.strokePolyline(ctx, [[c, d], [c, c], [d, c]], false);
    }

    function drawStar(ctx) {
        const points = [];
        const cx = 12;
        const cy = 12;
        const outer = 8.2;
        const inner = 3.7;

        for (let i = 0; i < 10; ++i) {
            const radius = i % 2 === 0 ? outer : inner;
            const angle = -Math.PI / 2 + i * Math.PI / 5;

            points.push([
                cx + Math.cos(angle) * radius,
                cy + Math.sin(angle) * radius
            ]);
        }

        root.strokePolyline(ctx, points, true);
    }

    function drawIcon(ctx, iconName) {
        switch (iconName) {
        case "close":
            root.strokePolyline(ctx, [[6.5, 6.5], [17.5, 17.5]], false);
            root.strokePolyline(ctx, [[17.5, 6.5], [6.5, 17.5]], false);
            break;

        case "refresh":
            root.drawRefresh(ctx, false);
            break;

        case "reset":
        case "revert":
            root.drawRefresh(ctx, true);
            break;

        case "apply":
        case "keep":
            root.strokePolyline(
                ctx,
                [[4.8, 12.5], [9.5, 17.0], [19.2, 6.8]],
                false
            );
            break;

        case "save":
            root.strokePolyline(
                ctx,
                [[5, 3.5], [17.2, 3.5], [20, 6.3], [20, 20.5], [4, 20.5],
                 [4, 3.5], [5, 3.5]],
                false
            );
            root.strokePolyline(
                ctx,
                [[7.2, 3.7], [7.2, 9], [16.4, 9], [16.4, 3.7]],
                false
            );
            root.strokePolyline(
                ctx,
                [[7.4, 20.2], [7.4, 14], [16.6, 14], [16.6, 20.2]],
                false
            );
            break;

        case "fit":
            root.drawCornerFrame(ctx, 3.6);

            // Contain: content remains fully visible inside the viewport.
            root.beginStroke(ctx);
            ctx.rect(6.7, 8.3, 10.6, 7.4);
            ctx.stroke();
            break;

        case "fill":
            // Fill: content expands toward the viewport boundaries.
            root.beginStroke(ctx);
            ctx.rect(5.0, 5.0, 14.0, 14.0);
            ctx.stroke();

            root.drawArrow(ctx, 10.8, 10.8, 6.4, 6.4, 1.7);
            root.drawArrow(ctx, 13.2, 10.8, 17.6, 6.4, 1.7);
            root.drawArrow(ctx, 10.8, 13.2, 6.4, 17.6, 1.7);
            root.drawArrow(ctx, 13.2, 13.2, 17.6, 17.6, 1.7);
            break;

        case "stretch":
            root.drawArrow(ctx, 11, 12, 4.2, 12, 2.4);
            root.drawArrow(ctx, 13, 12, 19.8, 12, 2.4);
            root.strokePolyline(ctx, [[3.5, 7.5], [3.5, 16.5]], false);
            root.strokePolyline(ctx, [[20.5, 7.5], [20.5, 16.5]], false);
            break;

        case "center":
            root.beginStroke(ctx);
            ctx.arc(12, 12, 5.5, 0, Math.PI * 2, false);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.arc(12, 12, 1.4, 0, Math.PI * 2, false);
            ctx.fill();
            root.strokePolyline(ctx, [[12, 3], [12, 6]], false);
            root.strokePolyline(ctx, [[12, 18], [12, 21]], false);
            root.strokePolyline(ctx, [[3, 12], [6, 12]], false);
            root.strokePolyline(ctx, [[18, 12], [21, 12]], false);
            break;

        case "left":
            root.drawArrow(ctx, 19, 12, 5, 12, 3.0);
            break;

        case "right":
            root.drawArrow(ctx, 5, 12, 19, 12, 3.0);
            break;

        case "above":
            root.drawArrow(ctx, 12, 19, 12, 5, 3.0);
            break;

        case "below":
            root.drawArrow(ctx, 12, 5, 12, 19, 3.0);
            break;

        case "display":
            root.beginStroke(ctx);
            ctx.rect(3.5, 4.5, 17, 11.8);
            ctx.stroke();
            root.strokePolyline(ctx, [[9.2, 20], [14.8, 20]], false);
            root.strokePolyline(ctx, [[12, 16.5], [12, 20]], false);
            break;

        case "wallpaper":
            root.beginStroke(ctx);
            ctx.rect(3.5, 4.5, 17, 15);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.arc(16.5, 8.2, 1.6, 0, Math.PI * 2, false);
            ctx.stroke();
            root.strokePolyline(
                ctx,
                [[5.8, 17.2], [10.1, 12.2], [13.1, 15.2],
                 [15.4, 12.9], [18.5, 17.2]],
                false
            );
            break;

        case "theme":
            root.beginStroke(ctx);
            ctx.arc(12, 12, 8.2, 0, Math.PI * 2, false);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.arc(12, 12, 5.0, -Math.PI / 2, Math.PI / 2, false);
            ctx.stroke();
            root.strokePolyline(ctx, [[12, 3.8], [12, 20.2]], false);
            break;

        case "settings":
            root.beginStroke(ctx);
            ctx.arc(12, 12, 3.4, 0, Math.PI * 2, false);
            ctx.stroke();

            for (let i = 0; i < 8; ++i) {
                const angle = i * Math.PI / 4;
                const inner = 6.6;
                const outer = 9.0;

                root.strokePolyline(
                    ctx,
                    [
                        [
                            12 + Math.cos(angle) * inner,
                            12 + Math.sin(angle) * inner
                        ],
                        [
                            12 + Math.cos(angle) * outer,
                            12 + Math.sin(angle) * outer
                        ]
                    ],
                    false
                );
            }
            break;

        case "performance":
            root.beginStroke(ctx);
            ctx.arc(12, 14, 8, Math.PI, Math.PI * 2, false);
            ctx.stroke();
            root.strokePolyline(ctx, [[4, 14], [4, 17]], false);
            root.strokePolyline(ctx, [[20, 14], [20, 17]], false);
            root.strokePolyline(ctx, [[12, 14], [16.7, 8.3]], false);
            root.beginStroke(ctx);
            ctx.arc(12, 14, 1.3, 0, Math.PI * 2, false);
            ctx.fill();
            break;

        case "media":
            root.strokePolyline(ctx, [[9, 6], [17, 4], [17, 15]], false);
            root.strokePolyline(ctx, [[9, 6], [9, 17]], false);
            root.beginStroke(ctx);
            ctx.arc(6.7, 17.7, 2.5, -0.25, Math.PI * 1.75, false);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.arc(14.7, 15.7, 2.5, -0.25, Math.PI * 1.75, false);
            ctx.stroke();
            break;

        case "network":
            root.beginStroke(ctx);
            ctx.arc(12, 18.2, 2.0, Math.PI * 1.18, Math.PI * 1.82, false);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.arc(12, 18.2, 6.0, Math.PI * 1.18, Math.PI * 1.82, false);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.arc(12, 18.2, 10.0, Math.PI * 1.18, Math.PI * 1.82, false);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.arc(12, 18.2, 1.15, 0, Math.PI * 2, false);
            ctx.fill();
            break;

        case "notifications":
            root.beginStroke(ctx);
            ctx.moveTo(6.3, 16.4);
            ctx.quadraticCurveTo(8.0, 14.5, 8.0, 10.4);
            ctx.quadraticCurveTo(8.0, 6.4, 12.0, 5.4);
            ctx.quadraticCurveTo(16.0, 6.4, 16.0, 10.4);
            ctx.quadraticCurveTo(16.0, 14.5, 17.7, 16.4);
            ctx.lineTo(6.3, 16.4);
            ctx.stroke();
            root.strokePolyline(ctx, [[10.3, 19], [13.7, 19]], false);
            break;

        case "all":
            // All sources: four equal catalog cells.
            root.beginStroke(ctx);
            ctx.rect(4.2, 4.2, 6.1, 6.1);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.rect(13.7, 4.2, 6.1, 6.1);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.rect(4.2, 13.7, 6.1, 6.1);
            ctx.stroke();
            root.beginStroke(ctx);
            ctx.rect(13.7, 13.7, 6.1, 6.1);
            ctx.stroke();
            break;

        case "library":
            // Library: local collection/folder.
            root.beginStroke(ctx);
            ctx.moveTo(3.5, 7.0);
            ctx.lineTo(9.2, 7.0);
            ctx.lineTo(11.0, 9.0);
            ctx.lineTo(20.5, 9.0);
            ctx.lineTo(20.5, 18.8);
            ctx.lineTo(3.5, 18.8);
            ctx.closePath();
            ctx.stroke();
            root.strokePolyline(ctx, [[3.5, 7.0], [3.5, 18.8]], false);
            break;

        case "favorite":
            root.drawStar(ctx);
            break;

        case "power":
            root.beginStroke(ctx);
            ctx.arc(12, 12.5, 7.4, -0.92, Math.PI * 1.92, false);
            ctx.stroke();
            root.strokePolyline(ctx, [[12, 3.3], [12, 11.2]], false);
            break;
        }
    }

    Canvas {
        id: iconCanvas

        anchors.fill: parent
        visible: root.useVector
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");

            ctx.clearRect(0, 0, width, height);

            if (!root.useVector || width <= 0 || height <= 0)
                return;

            ctx.save();
            ctx.scale(width / 24, height / 24);
            root.drawIcon(ctx, root.name);
            ctx.restore();
        }
    }

    Text {
        id: fallbackText

        visible:
            !root.useVector
            && root.resolvedGlyph.length > 0

        anchors.centerIn: parent

        text: root.resolvedGlyph
        color: root.iconColor

        font.family: root.theme.fontFamilySans
        font.pixelSize: root.iconSize
        font.weight: root.emphasized
            ? root.theme.fontWeightSemibold
            : root.theme.fontWeightMedium

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    onNameChanged: iconCanvas.requestPaint()
    onGlyphChanged: iconCanvas.requestPaint()
    onIconColorChanged: iconCanvas.requestPaint()
    onIconSizeChanged: iconCanvas.requestPaint()
    onEmphasizedChanged: iconCanvas.requestPaint()
    onWidthChanged: iconCanvas.requestPaint()
    onHeightChanged: iconCanvas.requestPaint()

    Behavior on iconColor {
        ColorAnimation {
            duration: root.theme.motionControl
            easing.type: root.theme.easingStandard
        }
    }

    Component.onCompleted: iconCanvas.requestPaint()
}
