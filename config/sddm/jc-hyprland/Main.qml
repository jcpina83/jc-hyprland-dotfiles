import QtQuick 2.15

Item {
    id: root

    width: 1600
    height: 900

    Timer {
        id: suspendDelay

        interval: 1000
        repeat: false

        onTriggered: {
            if (sddm.canSuspend) {
                sddm.suspend()
            }
        }
    }

    Loader {
        id: themeLoader

        anchors.fill: parent

        source: config.Variant === "cyber-noir"
            ? "components/CyberNoir.qml"
            : "components/OdysseyGlass.qml"

        onLoaded: {
            item.backgroundSource = Qt.resolvedUrl(config.Background)

            item.backgroundColor = config.BackgroundColor
            item.panelColor = config.PanelColor
            item.panelBorderColor = config.PanelBorder

            item.primaryColor = config.PrimaryColor
            item.secondaryColor = config.SecondaryColor

            item.textColor = config.TextColor
            item.mutedColor = config.MutedColor

            item.userModelRef = userModel
            item.sessionModelRef = sessionModel

        }
    }

    Connections {
        target: themeLoader.item

        function onLoginRequested(user, password, sessionIndex) {
            sddm.login(user, password, sessionIndex)
        }

        function onSuspendRequested() {
            suspendDelay.restart()
        }

        function onRebootRequested() {
            if (sddm.canReboot) {
                sddm.reboot()
            }
        }

        function onPowerOffRequested() {
            if (sddm.canPowerOff) {
                sddm.powerOff()
            }
        }
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            if (themeLoader.item) {
                themeLoader.item.authenticationFailed()
            }
        }

        function onLoginSucceeded() {
        }
    }
}