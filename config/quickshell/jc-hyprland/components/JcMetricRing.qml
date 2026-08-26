import QtQuick

Item {
    id: root

    required property var theme

    property real value: 0
    property real minimum: 0
    property real maximum: 100

    property string label: ""
    property string unit: "%"
    property string status: "normal"

    property int decimals: 0

    readonly property real normalizedValue: {
        const span = root.maximum - root.minimum;

        if (span <= 0)
            return 0;

        return Math.max(
            0,
            Math.min(
                1,
                (root.value - root.minimum) / span
            )
        );
    }

    readonly property color metricColor: {
        switch (root.status) {
        case "success":
            return root.theme.success;

        case "warning":
            return root.theme.warning;

        case "danger":
        case "critical":
            return root.theme.danger;

        case "info":
            return root.theme.info;

        case "normal":
        default:
            return root.theme.accent;
        }
    }

    readonly property color trackColor:
        root.theme.borderSubtle

    readonly property int ringThickness:
        root.theme.borderWidthStrong * 3

    readonly property string formattedValue:
        Number(root.value).toFixed(
            Math.max(0, root.decimals)
        )

    property real animatedProgress:
        root.normalizedValue

    implicitWidth: root.theme.controlHeightLarge * 3
    implicitHeight: root.theme.controlHeightLarge * 3

    Behavior on animatedProgress {
        NumberAnimation {
            duration: root.theme.motionEmphasized
            easing.type: root.theme.easingEmphasized
        }
    }

    onAnimatedProgressChanged:
        ringCanvas.requestPaint()

    onMetricColorChanged:
        ringCanvas.requestPaint()

    onTrackColorChanged:
        ringCanvas.requestPaint()

    onRingThicknessChanged:
        ringCanvas.requestPaint()

    Canvas {
        id: ringCanvas

        anchors.fill: parent

        antialiasing: true

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");

            context.clearRect(
                0,
                0,
                width,
                height
            );

            const centerX = width / 2;
            const centerY = height / 2;

            const radius = Math.max(
                0,
                Math.min(width, height) / 2
                    - root.ringThickness
            );

            const startAngle = -Math.PI / 2;
            const fullCircle = Math.PI * 2;

            context.lineWidth = root.ringThickness;
            context.lineCap = "round";

            context.beginPath();
            context.arc(
                centerX,
                centerY,
                radius,
                0,
                fullCircle,
                false
            );

            context.strokeStyle = root.trackColor;
            context.stroke();

            if (root.animatedProgress <= 0)
                return;

            context.beginPath();
            context.arc(
                centerX,
                centerY,
                radius,
                startAngle,
                startAngle
                    + fullCircle
                        * root.animatedProgress,
                false
            );

            context.strokeStyle = root.metricColor;
            context.stroke();
        }
    }

    Column {
        anchors.centerIn: parent

        spacing: root.theme.space2Xs

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text:
                root.formattedValue
                + root.unit

            color: root.metricColor

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeMetric
            font.weight: root.theme.fontWeightBold

            Behavior on color {
                ColorAnimation {
                    duration: root.theme.motionSelection
                    easing.type: root.theme.easingStandard
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            visible: root.label.length > 0

            text: root.label
            color: root.theme.textSecondary

            font.family: root.theme.fontFamilySans
            font.pixelSize: root.theme.textSizeCaption
            font.weight: root.theme.fontWeightMedium
        }
    }
}
