import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // -------------------------------------------------------------------------
    // SDDM runtime contract
    // -------------------------------------------------------------------------

    property var userModelRef
    property var sessionModelRef

    signal loginRequested(
        string user,
        string password,
        int sessionIndex
    )

    signal suspendRequested()
    signal rebootRequested()
    signal powerOffRequested()

    signal authenticationFailed()

    // -------------------------------------------------------------------------
    // Theme contract
    // -------------------------------------------------------------------------

    property url backgroundSource: ""

    property color backgroundColor: "#090b10"

    property color panelColor: "#dd050b16"
    property color panelBorderColor: "#6600e5ff"

    property color primaryColor: "#00e5ff"
    property color secondaryColor: "#ff3cac"

    property color textColor: "#eaf6ff"
    property color mutedColor: "#88a8c8"

    property date currentDate: new Date()

    property int sessionIndex: root.sessionModelRef
        ? root.sessionModelRef.lastIndex
        : 0


    // -------------------------------------------------------------------------
    // Authentication behavior
    // -------------------------------------------------------------------------

    onAuthenticationFailed: {
        passwordInput.text = ""
        passwordInput.forceActiveFocus()
    }


    // -------------------------------------------------------------------------
    // Clock
    // -------------------------------------------------------------------------

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: root.currentDate = new Date()
    }


    // -------------------------------------------------------------------------
    // Background
    // -------------------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
    }

    Image {
        anchors.fill: parent

        source: root.backgroundSource

        fillMode: Image.PreserveAspectCrop

        asynchronous: true
        cache: true
        smooth: true
    }


    // -------------------------------------------------------------------------
    // Dark cinematic overlay
    // -------------------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: "#33000000"
    }


    // -------------------------------------------------------------------------
    // HUD decoration
    //
    // Pure QML; no additional image assets.
    // -------------------------------------------------------------------------

    Item {
        id: hud

        anchors {
            left: parent.left
            leftMargin: parent.width * 0.07

            verticalCenter: parent.verticalCenter
        }

        width: Math.min(520, parent.width * 0.36)
        height: width

        opacity: 0.42


        Rectangle {
            anchors.centerIn: parent

            width: parent.width * 0.78
            height: width

            radius: width / 2

            color: "transparent"

            border.width: 2
            border.color: root.primaryColor
        }


        Rectangle {
            anchors.centerIn: parent

            width: parent.width * 0.60
            height: width

            radius: width / 2

            color: "transparent"

            border.width: 1
            border.color: root.secondaryColor
        }


        Rectangle {
            anchors.centerIn: parent

            width: parent.width * 0.42
            height: width

            radius: width / 2

            color: "#0800e5ff"

            border.width: 1
            border.color: root.primaryColor
        }


        Rectangle {
            anchors.centerIn: parent

            width: 8
            height: parent.height * 0.88

            radius: 4

            color: root.primaryColor

            opacity: 0.10
        }


        Rectangle {
            anchors.centerIn: parent

            width: parent.width * 0.88
            height: 2

            color: root.primaryColor

            opacity: 0.18
        }


        Rectangle {
            anchors.centerIn: parent

            width: 16
            height: 16

            radius: 8

            color: root.primaryColor
        }
    }


    // -------------------------------------------------------------------------
    // Readability gradient behind panel
    // -------------------------------------------------------------------------

    Rectangle {
        anchors {
            top: parent.top
            bottom: parent.bottom
            right: parent.right
        }

        width: parent.width * 0.48

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0.0
                color: "#00050b16"
            }

            GradientStop {
                position: 0.28
                color: "#66050b16"
            }

            GradientStop {
                position: 1.0
                color: "#ee050b16"
            }
        }
    }


    // -------------------------------------------------------------------------
    // Login panel
    // -------------------------------------------------------------------------

    Rectangle {
        id: loginPanel

        anchors {
            right: parent.right
            rightMargin: Math.max(36, parent.width * 0.045)

            verticalCenter: parent.verticalCenter
        }

        width: Math.min(550, parent.width * 0.36)
        height: Math.min(790, parent.height * 0.90)

        radius: 20

        color: root.panelColor

        border.width: 1
        border.color: root.panelBorderColor


        // ---------------------------------------------------------------------
        // Neon accent line
        // ---------------------------------------------------------------------

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }

            width: 2

            color: root.primaryColor

            opacity: 0.72
        }


        ColumnLayout {
            anchors {
                fill: parent

                leftMargin: 54
                rightMargin: 54
                topMargin: 48
                bottomMargin: 42
            }

            spacing: 15


            // -----------------------------------------------------------------
            // Header
            // -----------------------------------------------------------------

            Text {
                text: "WELCOME"
                color: root.primaryColor

                font.pixelSize: 13
                font.weight: Font.Medium
                font.letterSpacing: 6
            }

            Text {
                text: "CYBER NOIR"

                color: root.textColor

                font.pixelSize: 40
                font.weight: Font.DemiBold
                font.letterSpacing: 4
            }

            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 2

                color: root.primaryColor

                opacity: 0.85
            }


            Item {
                Layout.preferredHeight: 8
            }


            // -----------------------------------------------------------------
            // Username
            // -----------------------------------------------------------------

            Text {
                text: "USERNAME"

                color: root.mutedColor

                font.pixelSize: 12
                font.letterSpacing: 2
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                radius: 8

                color: "#88070e19"

                border.width: 1
                border.color: "#5500e5ff"

                TextInput {
                    id: usernameInput

                    anchors {
                        fill: parent

                        leftMargin: 18
                        rightMargin: 18
                    }

                    verticalAlignment: TextInput.AlignVCenter

                    color: root.textColor
                    selectionColor: root.primaryColor

                    font.pixelSize: 15

                    clip: true

                    Keys.onReturnPressed: {
                        passwordInput.forceActiveFocus()
                    }

                    Keys.onEnterPressed: {
                        passwordInput.forceActiveFocus()
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: usernameInput.text.length === 0

                        text: "Enter your username"

                        color: root.mutedColor

                        font.pixelSize: 15
                    }
                }
            }


            // -----------------------------------------------------------------
            // Password
            // -----------------------------------------------------------------

            Text {
                text: "PASSWORD"

                color: root.mutedColor

                font.pixelSize: 12
                font.letterSpacing: 2
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                radius: 8

                color: "#88070e19"

                border.width: 1
                border.color: "#5500e5ff"

                TextInput {
                    id: passwordInput

                    anchors {
                        fill: parent

                        leftMargin: 18
                        rightMargin: 18
                    }

                    verticalAlignment: TextInput.AlignVCenter

                    echoMode: TextInput.Password

                    color: root.textColor
                    selectionColor: root.primaryColor

                    font.pixelSize: 15

                    clip: true

                    Keys.onReturnPressed: {
                        root.loginRequested(
                            usernameInput.text,
                            passwordInput.text,
                            root.sessionIndex
                        )
                    }

                    Keys.onEnterPressed: {
                        root.loginRequested(
                            usernameInput.text,
                            passwordInput.text,
                            root.sessionIndex
                        )
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter

                        visible: passwordInput.text.length === 0

                        text: "Enter your password"

                        color: root.mutedColor

                        font.pixelSize: 15
                    }
                }
            }


            // -----------------------------------------------------------------
            // Session
            // -----------------------------------------------------------------

            Text {
                text: "SESSION"

                color: root.mutedColor

                font.pixelSize: 12
                font.letterSpacing: 2
            }

            Item {
                id: sessionArea

                Layout.fillWidth: true
                Layout.preferredHeight: 54

                // Hidden adapter provides SDDM's displayText without allowing
                // a native ComboBox to alter the custom Cyber Noir styling.
                ComboBox {
                    id: sessionAdapter

                    visible: false

                    model: root.sessionModelRef
                    textRole: "name"
                    currentIndex: root.sessionIndex
                }

                Rectangle {
                    id: sessionField

                    anchors.fill: parent

                    radius: 8

                    color: "#88070e19"

                    border.width: 1
                    border.color: sessionPopup.opened
                        ? root.primaryColor
                        : "#5500e5ff"

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 18
                            right: sessionChevron.left
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }

                        text: sessionAdapter.displayText.length > 0
                            ? sessionAdapter.displayText
                            : "Hyprland"

                        color: root.textColor

                        elide: Text.ElideRight

                        font.pixelSize: 15
                    }

                    Text {
                        id: sessionChevron

                        anchors {
                            right: parent.right
                            rightMargin: 18
                            verticalCenter: parent.verticalCenter
                        }

                        text: sessionPopup.opened ? "⌃" : "⌄"

                        color: root.primaryColor

                        font.pixelSize: 22
                    }

                    MouseArea {
                        anchors.fill: parent

                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            if (sessionPopup.opened) {
                                sessionPopup.close()
                            } else {
                                sessionPopup.open()
                            }
                        }
                    }
                }

                Popup {
                    id: sessionPopup

                    x: 0
                    y: sessionArea.height + 6

                    width: sessionArea.width
                    height: Math.min(sessionList.contentHeight + 12, 250)

                    padding: 6

                    closePolicy: Popup.CloseOnEscape
                        | Popup.CloseOnPressOutside

                    contentItem: ListView {
                        id: sessionList

                        clip: true

                        model: root.sessionModelRef

                        currentIndex: root.sessionIndex

                        delegate: Rectangle {
                            width: sessionList.width
                            height: 42

                            radius: 6

                            color: index === root.sessionIndex
                                ? "#4400e5ff"
                                : "transparent"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: 12
                                    right: parent.right
                                    rightMargin: 12
                                    verticalCenter: parent.verticalCenter
                                }

                                text: model.name

                                color: index === root.sessionIndex
                                    ? root.textColor
                                    : root.mutedColor

                                elide: Text.ElideRight

                                font.pixelSize: 14
                            }

                            MouseArea {
                                anchors.fill: parent

                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.sessionIndex = index
                                    sessionAdapter.currentIndex = index
                                    sessionPopup.close()
                                }
                            }
                        }

                        ScrollIndicator.vertical: ScrollIndicator {}
                    }

                    background: Rectangle {
                        radius: 9

                        color: "#f0050b16"

                        border.width: 1
                        border.color: root.panelBorderColor
                    }
                }
            }


            Item {
                Layout.preferredHeight: 10
            }


            // -----------------------------------------------------------------
            // Login
            // -----------------------------------------------------------------

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                radius: 8

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0.0
                        color: "#0077bb"
                    }

                    GradientStop {
                        position: 0.55
                        color: root.primaryColor
                    }

                    GradientStop {
                        position: 1.0
                        color: root.secondaryColor
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: "LOGIN  →"

                    color: "#ffffff"

                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    font.letterSpacing: 3
                }

                MouseArea {
                    anchors.fill: parent

                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        root.loginRequested(
                            usernameInput.text,
                            passwordInput.text,
                            root.sessionIndex
                        )
                    }
                }
            }


            Item {
                Layout.fillHeight: true
            }


            // -----------------------------------------------------------------
            // Clock
            // -----------------------------------------------------------------

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: Qt.formatDateTime(
                        root.currentDate,
                        "HH:mm"
                    )

                    color: root.textColor

                    font.pixelSize: 28
                    font.weight: Font.Light
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Qt.formatDateTime(
                        root.currentDate,
                        "dd MMM yyyy"
                    )

                    color: root.mutedColor

                    font.pixelSize: 13
                }
            }


            // -----------------------------------------------------------------
            // System actions
            // -----------------------------------------------------------------

            RowLayout {
                Layout.fillWidth: true

                spacing: 12

                Repeater {
                    model: [
                        {
                            symbol: "◐",
                            label: "SLEEP"
                        },
                        {
                            symbol: "↻",
                            label: "REBOOT"
                        },
                        {
                            symbol: "⏻",
                            label: "POWER"
                        }
                    ]

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44

                        radius: 7

                        color: "#66070e19"

                        border.width: 1
                        border.color: "#4400e5ff"

                        Text {
                            anchors.centerIn: parent

                            text: modelData.symbol + "  " + modelData.label

                            color: root.mutedColor

                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }

                        MouseArea {
                            anchors.fill: parent

                            enabled: modelData.label === "SLEEP"
                                || modelData.label === "REBOOT"
                                || modelData.label === "POWER"

                            cursorShape: enabled
                                ? Qt.PointingHandCursor
                                : Qt.ArrowCursor

                            onClicked: {
                                if (modelData.label === "SLEEP") {
                                    root.suspendRequested()
                                } else if (modelData.label === "REBOOT") {
                                    root.rebootRequested()
                                }  else if (modelData.label === "POWER") {
                                    root.powerOffRequested()
                                }
                            }
                        }
                    }
                }
            }
        }
    }



    // -------------------------------------------------------------------------
    // Initial user / focus
    // -------------------------------------------------------------------------

    Repeater {
        model: root.userModelRef

        delegate: Item {
            Component.onCompleted: {
                if (
                    root.userModelRef &&
                    index === root.userModelRef.lastIndex
                ) {
                    usernameInput.text = model.name

                    Qt.callLater(function() {
                        passwordInput.forceActiveFocus()
                    })
                }
            }
        }
    }

    Component.onCompleted: {
        // Fallback only if SDDM does not provide any selectable user.
        if (!root.userModelRef || root.userModelRef.count === 0) {
            Qt.callLater(function() {
                usernameInput.forceActiveFocus()
            })
        }
    }
}
