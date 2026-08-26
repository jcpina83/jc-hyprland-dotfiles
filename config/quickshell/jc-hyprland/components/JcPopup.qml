import QtQuick
import QtQuick.Controls as Controls

Controls.Popup {
    id: root

    required property var theme

    property bool showScrim: root.modal
    property bool dismissOnOutside: true

    modal: false
    dim: root.showScrim
    focus: true

    padding: root.theme.spaceLg

    closePolicy:
        Controls.Popup.CloseOnEscape
        | (root.dismissOnOutside
            ? Controls.Popup.CloseOnPressOutside
            : Controls.Popup.NoAutoClose)

    background: Rectangle {
        radius: root.theme.radiusLg

        color: root.theme.surfaceGlassRaised

        border.width: root.theme.borderWidthThin
        border.color: root.activeFocus
            ? root.theme.borderFocus
            : root.theme.borderStrong

        Behavior on border.color {
            ColorAnimation {
                duration: root.theme.motionControl
                easing.type: root.theme.easingStandard
            }
        }
    }

    Controls.Overlay.modal: Rectangle {
        color: root.theme.scrim
    }

    Controls.Overlay.modeless: Rectangle {
        color: root.theme.scrim
    }

    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0.0
            to: root.theme.opacityEnabled

            duration: root.theme.motionDialog
            easing.type: root.theme.easingEnter
        }
    }

    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: root.theme.opacityEnabled
            to: 0.0

            duration: root.theme.motionDialog
            easing.type: root.theme.easingExit
        }
    }
}
