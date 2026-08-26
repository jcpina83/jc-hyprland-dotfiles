import QtQuick
import QtQuick.Controls as Controls

Controls.ToolTip {
    id: root

    required property var theme

    property bool controlEnabled: true

    enabled: root.controlEnabled

    delay: root.theme.motionEmphasized

    padding: root.theme.spaceSm

    opacity: root.controlEnabled
        ? root.theme.opacityEnabled
        : root.theme.opacityDisabled

    contentItem: Text {
        text: root.text

        color: root.theme.textPrimary

        font.family: root.theme.fontFamilySans
        font.pixelSize: root.theme.textSizeCaption
        font.weight: root.theme.fontWeightMedium

        wrapMode: Text.WordWrap
    }

    background: Rectangle {
        radius: root.theme.radiusSm

        color: root.theme.surfaceGlassRaised

        border.width: root.theme.borderWidthThin
        border.color: root.theme.borderStrong
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: root.controlEnabled
                ? root.theme.opacityEnabled
                : root.theme.opacityDisabled

            duration: root.theme.motionHover
            easing.type: root.theme.easingEnter
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: root.opacity
            to: 0.0

            duration: root.theme.motionHover
            easing.type: root.theme.easingExit
        }
    }
}
